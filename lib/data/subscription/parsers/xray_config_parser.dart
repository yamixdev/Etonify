import 'dart:convert';
import 'package:meow_client/data/subscription/import_key_normalizer.dart';
import 'package:meow_client/data/subscription/outbound_schema.dart';
import 'package:meow_client/data/subscription/parsers/cert_pin_utils.dart';

/// Extracts outbounds from an Xray / V2Ray JSON configuration and
/// converts them to sing-box outbound format.
class XrayConfigParseResult {
  const XrayConfigParseResult({
    required this.outbounds,
    this.groups = const [],
    this.warnings = const [],
  });

  final List<Map<String, dynamic>> outbounds;
  final List<Map<String, dynamic>> groups;
  final List<String> warnings;
}

class XrayConfigParser {
  XrayConfigParser._();

  static final _safeOptionPattern = RegExp(r'^[a-z0-9_-]{1,32}$');

  /// Returns `true` if [content] looks like an Xray/V2Ray config.
  static bool canParse(String content) {
    try {
      final json = jsonDecode(content);
      if (json is Map) {
        return _isXrayConfigMap(Map<String, dynamic>.from(json));
      }
      if (json is List) {
        return json.any((entry) {
          if (entry is! Map) return false;
          return _isXrayConfigMap(Map<String, dynamic>.from(entry));
        });
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Parses Xray JSON config and returns sing-box outbound maps.
  static List<Map<String, dynamic>> parse(String content) {
    return parseWithGroups(content).outbounds;
  }

  static XrayConfigParseResult parseWithGroups(String content) {
    final outbounds = <Map<String, dynamic>>[];
    final groups = <Map<String, dynamic>>[];
    final warnings = <String>[];
    final json = jsonDecode(content);

    if (json is Map) {
      _appendParsedConfig(
        Map<String, dynamic>.from(json),
        outbounds,
        groups,
        warnings,
        sourceScope: _sourceScope(0),
      );
    }

    if (json is List) {
      for (var i = 0; i < json.length; i++) {
        final entry = json[i];
        if (entry is! Map) continue;
        _appendParsedConfig(
          Map<String, dynamic>.from(entry),
          outbounds,
          groups,
          warnings,
          sourceScope: _sourceScope(i),
        );
      }
    }

    return XrayConfigParseResult(
      outbounds: outbounds,
      groups: groups,
      warnings: warnings,
    );
  }

  static const _skipProtocols = {'freedom', 'blackhole', 'dns', 'loopback'};

  static bool _isXrayConfigMap(Map<String, dynamic> json) {
    if (!json.containsKey('outbounds') || json['outbounds'] is! List) {
      return false;
    }
    final outbounds = json['outbounds'] as List;
    if (outbounds.isEmpty) return false;
    final first = outbounds.first;
    return first is Map && first.containsKey('protocol');
  }

  static void _appendParsedConfig(
    Map<String, dynamic> json,
    List<Map<String, dynamic>> results,
    List<Map<String, dynamic>> groups,
    List<String> warnings, {
    required String sourceScope,
  }) {
    final outbounds = json['outbounds'];
    if (outbounds is! List) {
      return;
    }

    final remarks = _s(json['remarks']).trim();
    final proxyEntries = outbounds
        .where((entry) {
          if (entry is! Map) return false;
          final protocol = _s(entry['protocol']).toLowerCase();
          return !_skipProtocols.contains(protocol);
        })
        .toList(growable: false);
    final singleProxyDisplayName =
        proxyEntries.length == 1 && remarks.isNotEmpty ? remarks : null;

    final candidates = <(int, String, Map<String, dynamic>)>[];
    final tagCounts = <String, int>{};
    for (final entry in outbounds.whereType<Map<String, dynamic>>()) {
      final tag = _s(entry['tag']).trim();
      if (tag.isNotEmpty) {
        tagCounts.update(tag, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    var proxyIndex = 0;
    for (final entry in outbounds) {
      if (entry is! Map) continue;
      final ob = Map<String, dynamic>.from(entry);

      final protocol = _s(ob['protocol']).toLowerCase();
      if (_skipProtocols.contains(protocol)) continue;

      final sourceTag = _sourceTag(ob, proxyIndex, sourceScope);
      proxyIndex++;
      try {
        final converted = _convert(ob);
        if (converted == null) {
          throw const FormatException(
            'Unsupported or incomplete Xray outbound',
          );
        }
        final detour = _detour(ob, converted);
        if (detour.isNotEmpty) converted['detour'] = detour;
        converted['_source_tag'] = sourceTag;
        converted['_source_scope'] = sourceScope;
        converted['_source_order'] = int.tryParse(sourceScope.substring(5));
        if (remarks.isNotEmpty) {
          converted['_source_profile_name'] = remarks;
        }
        if (singleProxyDisplayName != null) {
          converted['_name'] = singleProxyDisplayName;
        }
        candidates.add((proxyIndex, sourceTag, converted));
      } on FormatException catch (error) {
        warnings.add('Outbound $proxyIndex: ${error.message}');
      }
    }

    final checkDetour = _detourValidator(candidates, tagCounts);
    final convertedSourceTags = <String>[];
    for (final (index, tag, converted) in candidates) {
      final problem = checkDetour(converted);
      if (problem != null) {
        warnings.add('Outbound $index: $problem');
        continue;
      }
      convertedSourceTags.add(tag);
      results.add(converted);
    }

    _appendParsedGroups(
      json,
      groups,
      convertedSourceTags: convertedSourceTags,
      remarks: remarks,
      sourceScope: sourceScope,
    );
  }

  static String _detour(
    Map<String, dynamic> ob,
    Map<String, dynamic> converted,
  ) {
    final stream = _map(ob['streamSettings']);
    final socketOptions = _map(stream['sockopt']);
    final dialerTag = _detourTag(socketOptions['dialerProxy']);
    final rawLegacy = ob['proxySettings'];
    if (rawLegacy == null) return dialerTag;
    final legacy = _map(rawLegacy);
    final legacyTag = _detourTag(legacy['tag']);
    if (legacyTag.isEmpty) {
      throw const FormatException('Missing Xray proxySettings tag');
    }
    if (dialerTag.isNotEmpty && dialerTag != legacyTag) {
      throw const FormatException(
        'Conflicting Xray proxySettings and dialerProxy',
      );
    }
    if (legacy['transportLayer'] != true) {
      if (!const {'tcp', 'raw'}.contains(_network(stream)) ||
          converted['transport'] != null ||
          converted['type'] == 'hysteria2' ||
          dialerTag.isNotEmpty ||
          _s(stream['security']).toLowerCase() == 'reality') {
        throw const FormatException(
          'Legacy Xray proxySettings requires transportLayer for this transport or TLS mode',
        );
      }
      final tls = converted['tls'];
      // The old protocol-level detour wraps the upstream pipe with Go TLS.
      if (tls is Map<String, dynamic>) tls.remove('utls');
    }
    return legacyTag;
  }

  static String _detourTag(Object? value) {
    if (value == null || value == '') return '';
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Invalid Xray proxy chain tag');
    }
    return value.trim();
  }

  static String? Function(Map<String, dynamic>) _detourValidator(
    List<(int, String, Map<String, dynamic>)> candidates,
    Map<String, int> tagCounts,
  ) {
    final tagged = {
      for (final (_, tag, config) in candidates)
        if (tagCounts[tag] == 1) tag: config,
    };
    final checked = <String, String?>{};
    return (config) {
      final visited = <String>{};
      var target = _s(config['detour']);
      String? problem;
      while (target.isNotEmpty) {
        if (checked.containsKey(target)) {
          problem = checked[target];
          break;
        }
        if (!visited.add(target)) {
          problem = 'Xray proxy chain contains a cycle';
          break;
        }
        final next = tagged[target];
        if (next == null) {
          problem = (tagCounts[target] ?? 0) > 1
              ? 'Xray proxy chain refers to a duplicate outbound tag'
              : 'Xray proxy chain refers to a missing or unsupported outbound';
          break;
        }
        target = _s(next['detour']);
      }
      for (final tag in visited) {
        checked[tag] = problem;
      }
      return problem;
    };
  }

  static void _appendParsedGroups(
    Map<String, dynamic> json,
    List<Map<String, dynamic>> groups, {
    required List<String> convertedSourceTags,
    required String? remarks,
    required String sourceScope,
  }) {
    if (convertedSourceTags.isEmpty) {
      return;
    }
    final routing = _map(json['routing']);
    final balancers = _list(json['balancers']).isNotEmpty
        ? _list(json['balancers'])
        : _list(routing['balancers']);
    if (balancers.isEmpty) {
      return;
    }

    final pingConfig = _map(_map(json['burstObservatory'])['pingConfig']);
    final destination = _s(pingConfig['destination']);
    final intervalSeconds = _durationSeconds(pingConfig['interval']);

    for (final rawBalancer in balancers) {
      final balancer = _map(rawBalancer);
      if (balancer.isEmpty) {
        continue;
      }
      final sourceTag = _s(balancer['tag']);
      final selectors = _list(balancer['selector'])
          .map(_s)
          .where((selector) => selector.isNotEmpty)
          .toList(growable: false);
      if (selectors.isEmpty) {
        continue;
      }
      final memberTags = convertedSourceTags
          .where(
            (tag) =>
                selectors.any((selector) => _tagMatchesSelector(tag, selector)),
          )
          .toList(growable: false);
      if (memberTags.isEmpty) {
        continue;
      }
      final strategy = _map(balancer['strategy']);
      final strategyType = _s(strategy['type'], 'urltest').toLowerCase();
      final rawName = _groupName(
        remarks: remarks,
        balancerTag: sourceTag,
        balancerCount: balancers.length,
      );
      final parsedName = _extractCountryFromName(rawName);
      groups.add({
        'tag': sourceTag,
        'name': parsedName.name,
        'type': strategyType.isEmpty ? 'urltest' : strategyType,
        'source_scope': sourceScope,
        'config': {'_source_order': int.tryParse(sourceScope.substring(5))},
        if (parsedName.countryCode != null) 'country': parsedName.countryCode,
        'outbounds': memberTags,
        // Keep the exact fallback reference separate: it is not a selector
        // prefix and must not compete with ordinary URLTest members.
        if (_s(balancer['fallbackTag']).isNotEmpty)
          'fallback_tag': _s(balancer['fallbackTag']),
        if (destination.isNotEmpty) 'url': destination,
        ...intervalSeconds == null
            ? const <String, dynamic>{}
            : {'interval': intervalSeconds},
      });
    }
  }

  static String _sourceScope(int index) => 'xray-$index';

  static String _sourceTag(
    Map<String, dynamic> outbound,
    int proxyIndex,
    String sourceScope,
  ) {
    final sourceTag = _s(outbound['tag']).trim();
    if (sourceTag.isNotEmpty) {
      return sourceTag;
    }
    return '$sourceScope-outbound-$proxyIndex';
  }

  static String _groupName({
    required String? remarks,
    required String balancerTag,
    required int balancerCount,
  }) {
    final normalizedRemarks = remarks?.trim() ?? '';
    if (normalizedRemarks.isNotEmpty && balancerCount == 1) {
      return normalizedRemarks;
    }
    if (normalizedRemarks.isNotEmpty && balancerTag.isNotEmpty) {
      return '$normalizedRemarks · $balancerTag';
    }
    return balancerTag.isNotEmpty ? balancerTag : 'Auto group';
  }

  static ({String name, String? countryCode}) _extractCountryFromName(
    String rawName,
  ) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return (name: trimmed, countryCode: null);
    }
    final match = RegExp(
      r'([\u{1F1E6}-\u{1F1FF}]{2})',
      unicode: true,
    ).firstMatch(trimmed);
    if (match == null) {
      return (name: trimmed, countryCode: null);
    }
    final flag = match.group(1)!;
    final remainder =
        '${trimmed.substring(0, match.start)} '
                '${trimmed.substring(match.end)}'
            .trim()
            .replaceAll(RegExp(r'\s{2,}'), ' ');
    return (
      name: remainder.isNotEmpty ? remainder : trimmed,
      countryCode: _countryCodeFromFlag(flag),
    );
  }

  static String? _countryCodeFromFlag(String flag) {
    final runes = flag.runes.toList(growable: false);
    if (runes.length != 2) {
      return null;
    }
    final first = runes[0] - 0x1F1E6;
    final second = runes[1] - 0x1F1E6;
    if (first < 0 || first > 25 || second < 0 || second > 25) {
      return null;
    }
    return String.fromCharCodes([65 + first, 65 + second]);
  }

  static bool _tagMatchesSelector(String tag, String selector) {
    if (tag == selector) {
      return true;
    }
    return tag.startsWith(selector);
  }

  static int? _durationSeconds(dynamic value) {
    final text = _s(value).trim().toLowerCase();
    if (text.isEmpty) {
      return null;
    }
    if (text.endsWith('ms')) {
      final number = num.tryParse(text.substring(0, text.length - 2));
      if (number == null) return null;
      return (number / 1000).ceil().clamp(1, 1 << 30).toInt();
    }
    if (text.endsWith('s')) {
      return int.tryParse(text.substring(0, text.length - 1));
    }
    if (text.endsWith('m')) {
      final minutes = int.tryParse(text.substring(0, text.length - 1));
      return minutes == null ? null : minutes * 60;
    }
    return int.tryParse(text);
  }

  // ─────────────────── Converter ───────────────────

  static Map<String, dynamic>? _convert(Map<String, dynamic> ob) {
    final protocol = _s(ob['protocol']).toLowerCase();
    final tag = _s(ob['tag']);
    final settings = _map(ob['settings']);
    final stream = _map(ob['streamSettings']);
    final network = _network(stream);
    final security = _s(stream['security']).toLowerCase();
    if (security != '' &&
        security != 'none' &&
        security != 'tls' &&
        security != 'reality') {
      throw FormatException(
        'Unsupported Xray security: ${_safeOption(security)}',
      );
    }
    if (security == 'reality' &&
        !const {'tcp', 'raw', 'xhttp', 'splithttp', 'grpc'}.contains(network)) {
      throw FormatException(
        'Unsupported Xray REALITY transport: ${_safeOption(network)}',
      );
    }
    if (protocol != 'vmess' &&
        protocol != 'vless' &&
        protocol != 'trojan' &&
        !(protocol == 'hysteria' && network == 'hysteria') &&
        network != 'tcp' &&
        network != 'raw') {
      throw FormatException(
        'Unsupported Xray transport: ${_safeOption(network)}',
      );
    }
    for (final entry in stream.entries) {
      if (entry.key.toLowerCase() != 'finalmask' || entry.value == null) {
        continue;
      }
      final mask = entry.value;
      if (mask is! Map ||
          mask.entries.any(
            (option) => switch (option.key.toString().toLowerCase()) {
              'tcp' || 'udp' => !_isEmptyMaskList(option.value),
              'quicparams' => option.value != null,
              _ => false,
            },
          )) {
        throw const FormatException('Xray finalmask is unsupported');
      }
    }
    if ((protocol == 'shadowsocks' || protocol == 'socks') &&
        security != '' &&
        security != 'none') {
      throw const FormatException(
        'Xray stream security is unsupported for this protocol',
      );
    }

    switch (protocol) {
      case 'vmess':
        return _convertVmess(tag, settings, stream);
      case 'vless':
        return _convertVless(tag, settings, stream);
      case 'trojan':
        return _convertTrojan(tag, settings, stream);
      case 'hysteria':
        return _convertHysteria(tag, settings, stream);
      case 'shadowsocks':
        return _convertShadowsocks(tag, settings, stream);
      case 'socks':
        return _convertSocks(tag, settings, stream);
      case 'http':
        return _convertHttp(tag, settings, stream);
      default:
        return null;
    }
  }

  // ━━━━━━━━━━━━━━━━━━ VMess ━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _convertVmess(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
  ) {
    final vnext = _list(settings['vnext']);
    if (vnext.isEmpty) return null;
    final node = _map(vnext.first);
    final users = _list(node['users']);
    if (users.isEmpty) return null;
    final user = _map(users.first);

    final r = <String, dynamic>{
      'type': 'vmess',
      'tag': '',
      'server': _s(node['address']),
      'server_port': _i(node['port']),
      'uuid': _s(user['id']),
      'security': _s(user['security'], 'auto'),
      'alter_id': _i(user['alterId']),
    };

    _addTls(r, stream);
    _addTransport(r, stream);

    r['_name'] = tag.isNotEmpty ? tag : '${r['server']}:${r['server_port']}';
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━ VLESS ━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _convertVless(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
  ) {
    // Current Xray uses flat address/port/id settings. Keep the legacy
    // vnext/users representation without mixing fields from both formats.
    final Map<String, dynamic> node;
    final Map<String, dynamic> user;
    if (settings.containsKey('address')) {
      node = settings;
      user = settings;
    } else {
      final vnext = _list(settings['vnext']);
      if (vnext.isEmpty) return null;
      node = _map(vnext.first);
      final users = _list(node['users']);
      if (users.isEmpty) return null;
      user = _map(users.first);
    }

    final r = <String, dynamic>{
      'type': 'vless',
      'tag': '',
      'server': _s(node['address']),
      'server_port': _i(node['port']),
      'uuid': _s(user['id']),
    };

    final flow = ParsedOutboundSchema.normalizeXrayVlessFlow(_s(user['flow']));
    if (flow.isNotEmpty) r['flow'] = flow;
    final encryption = _s(user['encryption']);
    if (encryption.isNotEmpty) r['encryption'] = encryption;

    _addTls(r, stream);
    _addTransport(r, stream);

    r['_name'] = tag.isNotEmpty ? tag : '${r['server']}:${r['server_port']}';
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━ Trojan ━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _convertTrojan(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
  ) {
    final servers = _list(settings['servers']);
    if (servers.isEmpty) return null;
    final node = _map(servers.first);

    final r = <String, dynamic>{
      'type': 'trojan',
      'tag': '',
      'server': _s(node['address']),
      'server_port': _i(node['port']),
      'password': _s(node['password']),
    };

    _addTls(r, stream);
    _addTransport(r, stream);

    r['_name'] = tag.isNotEmpty ? tag : '${r['server']}:${r['server_port']}';
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━ Shadowsocks ━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _convertShadowsocks(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
  ) {
    final servers = _list(settings['servers']);
    if (servers.isEmpty) return null;
    final node = _map(servers.first);

    final r = <String, dynamic>{
      'type': 'shadowsocks',
      'tag': '',
      'server': _s(node['address']),
      'server_port': _i(node['port']),
      'method': _s(node['method']),
      'password': _s(node['password']),
    };

    r['_name'] = tag.isNotEmpty ? tag : '${r['server']}:${r['server_port']}';
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━ SOCKS ━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _convertSocks(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
  ) {
    final servers = _list(settings['servers']);
    if (servers.isEmpty) return null;
    final node = _map(servers.first);
    final users = _list(node['users']);
    final user = users.isNotEmpty ? _map(users.first) : <String, dynamic>{};

    final r = <String, dynamic>{
      'type': 'socks',
      'tag': '',
      'server': _s(node['address']),
      'server_port': _i(node['port']),
    };

    final username = _s(user['user']);
    final password = _s(user['pass']);
    if (username.isNotEmpty) r['username'] = username;
    if (password.isNotEmpty) r['password'] = password;

    r['_name'] = tag.isNotEmpty ? tag : '${r['server']}:${r['server_port']}';
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━ HTTP ━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _convertHttp(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
  ) {
    final servers = _list(settings['servers']);
    if (servers.isEmpty) return null;
    final node = _map(servers.first);
    final users = _list(node['users']);
    final user = users.isNotEmpty ? _map(users.first) : <String, dynamic>{};

    final r = <String, dynamic>{
      'type': 'http',
      'tag': '',
      'server': _s(node['address']),
      'server_port': _i(node['port']),
    };

    final username = _s(user['user']);
    final password = _s(user['pass']);
    if (username.isNotEmpty) r['username'] = username;
    if (password.isNotEmpty) r['password'] = password;

    _addTls(r, stream);

    r['_name'] = tag.isNotEmpty ? tag : '${r['server']}:${r['server_port']}';
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━ Hysteria2 ━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _convertHysteria(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
  ) {
    final hysteria = _map(stream['hysteriaSettings']);
    final version = _i(settings['version'], _i(hysteria['version'], 2));
    if (version != 2) {
      return null;
    }

    final tls = _buildTls(stream) ?? <String, dynamic>{'enabled': true};

    final r = <String, dynamic>{
      'type': 'hysteria2',
      'tag': '',
      'server': _s(settings['address']),
      'server_port': _i(settings['port']),
      'tls': tls,
    };

    final password = _s(hysteria['auth'], _s(settings['auth']));
    if (password.isNotEmpty) {
      r['password'] = password;
    }

    r['_name'] = tag.isNotEmpty ? tag : '${r['server']}:${r['server_port']}';
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━ TLS ━━━━━━━━━━━━━━━━━━

  static void _addTls(Map<String, dynamic> r, Map<String, dynamic> stream) {
    final tls = _buildTls(stream);
    if (tls == null) return;
    r['tls'] = tls;
  }

  static Map<String, dynamic>? _buildTls(Map<String, dynamic> stream) {
    final security = _s(stream['security']).toLowerCase();
    if (security != 'tls' && security != 'reality') return null;

    final tls = <String, dynamic>{'enabled': true};

    if (security == 'reality') {
      final rs = _map(stream['realitySettings']);
      final sni = _s(rs['serverName']);
      if (sni.isNotEmpty) tls['server_name'] = sni;
      if (_s(rs['mldsa65Verify']).isNotEmpty) {
        throw const FormatException(
          'Xray REALITY mldsa65Verify is unsupported',
        );
      }
      final fp = _s(rs['fingerprint']).toLowerCase();
      tls['utls'] = {
        'enabled': true,
        'fingerprint': fp.isEmpty ? 'chrome' : fp,
      };
      final reality = <String, dynamic>{'enabled': true};
      final password = _s(rs['password']);
      final pbk = password.isNotEmpty ? password : _s(rs['publicKey']);
      if (pbk.isNotEmpty) reality['public_key'] = pbk;
      final sid = _s(rs['shortId']);
      if (sid.isNotEmpty) reality['short_id'] = sid;
      final spiderX = _s(rs['spiderX']);
      if (spiderX.isNotEmpty) reality['spider_x'] = spiderX;
      tls['reality'] = reality;
    } else {
      final ts = _map(stream['tlsSettings']);
      if (_s(ts['verifyPeerCertByName']).isNotEmpty ||
          ts['disableSystemRoot'] == true ||
          _list(ts['certificates']).isNotEmpty ||
          _s(ts['echConfigList']).isNotEmpty) {
        throw const FormatException(
          'Unsupported Xray TLS certificate policy or ECH',
        );
      }
      final sni = _s(ts['serverName']);
      if (sni.isNotEmpty) tls['server_name'] = sni;
      final allowInsecure = ts['allowInsecure'] ?? ts['allow_insecure'];
      if (allowInsecure == true ||
          allowInsecure == 'true' ||
          allowInsecure == 1 ||
          allowInsecure == '1') {
        tls['insecure'] = true;
      }
      final alpn = ts['alpn'];
      if (alpn is String || alpn is List) tls['alpn'] = _stringList(alpn);
      for (final (key, target) in const [
        ('minVersion', 'min_version'),
        ('maxVersion', 'max_version'),
      ]) {
        final version = _s(ts[key]);
        if (version.isNotEmpty) tls[target] = version;
      }
      final fp = _s(ts['fingerprint']).toLowerCase();
      final raw = const {'tcp', 'raw'}.contains(_network(stream));
      if ((fp.isNotEmpty || raw) && fp != 'unsafe' && fp != 'hellogolang') {
        tls['utls'] = {
          'enabled': true,
          'fingerprint': fp.isEmpty ? 'chrome' : fp,
        };
      }
      final rawPins =
          ts['pinnedPeerCertSha256'] ??
          ts['pinnedPeerCertificateSha256'] ??
          ts['pinSHA256'] ??
          ts['certificate_sha256'];
      final pins = normalizeCertPins(rawPins);
      if (pins.isNotEmpty) {
        tls['certificate_sha256'] = pins;
      }
    }

    return tls;
  }

  // ━━━━━━━━━━━━━━━━━━ Transport ━━━━━━━━━━━━━━━━━━

  static String _network(Map<String, dynamic> stream) =>
      _s(stream['method'] ?? stream['network'], 'tcp').toLowerCase();

  static String _safeOption(String value) =>
      _safeOptionPattern.hasMatch(value) ? value : '(invalid value)';

  static void _addTransport(
    Map<String, dynamic> r,
    Map<String, dynamic> stream,
  ) {
    final network = _network(stream);

    switch (network) {
      case 'ws':
      case 'websocket':
        final ws = _map(stream['wsSettings']);
        final t = <String, dynamic>{'type': 'ws'};
        final path = _s(ws['path']);
        if (path.isNotEmpty) t['path'] = path;
        final headers = ws['headers'];
        final requestHeaders = _map(headers);
        final host = _s(ws['host']);
        if (host.isNotEmpty) {
          requestHeaders.removeWhere((key, _) => key.toLowerCase() == 'host');
          requestHeaders['Host'] = host;
        }
        if (requestHeaders.isNotEmpty) t['headers'] = requestHeaders;
        r['transport'] = t;

      case 'grpc':
        final gs = _map(stream['grpcSettings']);
        final t = <String, dynamic>{'type': 'grpc'};
        final sn = _s(
          gs['serviceName'] ?? gs['service_name'] ?? gs['service-name'],
        );
        if (sn.isNotEmpty) t['service_name'] = sn;
        r['transport'] = t;

      case 'h2':
      case 'http':
        final hs = _map(stream['httpSettings']);
        final t = <String, dynamic>{'type': 'http'};
        final host = hs['host'];
        if (host is List) t['host'] = host.map((e) => e.toString()).toList();
        final path = _s(hs['path']);
        if (path.isNotEmpty) t['path'] = path;
        r['transport'] = t;

      case 'httpupgrade':
        final hu = _map(stream['httpupgradeSettings']);
        final t = <String, dynamic>{'type': 'httpupgrade'};
        final host = _s(hu['host']);
        if (host.isNotEmpty) t['host'] = host;
        final path = _s(hu['path']);
        if (path.isNotEmpty) t['path'] = path;
        final headers = _map(hu['headers']);
        if (headers.isNotEmpty) t['headers'] = headers;
        r['transport'] = t;

      case 'splithttp':
      case 'xhttp':
        r['transport'] = _xhttpTransport(
          _map(stream['xhttpSettings'] ?? stream['splithttpSettings']),
        );

      case 'kcp':
      case 'mkcp':
        final ks = _map(stream['kcpSettings']);
        final t = <String, dynamic>{'type': 'mkcp'};
        final seed = _s(ks['seed']);
        if (seed.isNotEmpty) t['seed'] = seed;
        final header = _map(ks['header']);
        final ht = _s(header['type']);
        if (ht.isNotEmpty && ht != 'none') t['header_type'] = ht;
        r['transport'] = t;

      case 'quic':
        r['transport'] = <String, dynamic>{'type': 'quic'};

      case 'tcp':
      case 'raw':
        final tcp = _map(stream['rawSettings'] ?? stream['tcpSettings']);
        final header = _map(tcp['header']);
        final headerType = _s(header['type']);
        if (headerType.isEmpty || headerType == 'none') break;
        if (headerType != 'http') {
          throw FormatException(
            'Unsupported Xray RAW header: ${_safeOption(headerType)}',
          );
        }

        final t = <String, dynamic>{'type': 'http', 'raw_tcp': true};
        final request = _map(header['request']);
        final version = _s(request['version']);
        if (version.isNotEmpty && version != '1.1') {
          throw const FormatException('Xray RAW HTTP only supports HTTP/1.1');
        }
        final method = _s(request['method']);
        if (method.isNotEmpty) t['method'] = method;
        final paths = _stringList(request['path']);
        if (paths.isNotEmpty) t['path'] = paths.first;

        final headers = <String, dynamic>{};
        final requestHeaders = _map(request['headers']);
        if (requestHeaders.isEmpty) {
          t['host'] = const ['www.baidu.com', 'www.bing.com'];
          headers['Connection'] = const ['keep-alive'];
        }
        for (final entry in requestHeaders.entries) {
          final values = _stringList(entry.value);
          if (values.isEmpty) continue;
          if (entry.key.toLowerCase() == 'host') {
            t['host'] = values;
          } else {
            headers[entry.key] = values;
          }
        }
        if (headers.isNotEmpty) t['headers'] = headers;
        r['transport'] = t;
      default:
        throw FormatException(
          'Unsupported Xray transport: ${_safeOption(network)}',
        );
    }
  }

  // ━━━━━━━━━━━━━━━━━━ Utility ━━━━━━━━━━━━━━━━━━

  static String _s(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    return v.toString();
  }

  static List<String> _stringList(dynamic value) => switch (value) {
    String text => text.split(','),
    List<dynamic> items => items.whereType<String>().toList(growable: false),
    _ => const [],
  };

  static bool _isEmptyMaskList(Object? value) =>
      value == null || (value is List && value.isEmpty);

  static int _i(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static Map<String, dynamic> _xhttpTransport(Map<String, dynamic> settings) {
    final rawExtra = settings['extra'];
    dynamic effective = rawExtra ?? settings;
    if (effective is String) {
      try {
        effective = jsonDecode(effective);
      } on FormatException {
        throw const FormatException('Invalid Xray XHTTP extra');
      }
    }
    if (effective is! Map) {
      throw const FormatException('Invalid Xray XHTTP extra');
    }
    final transport = <String, dynamic>{'type': 'xhttp'};
    for (final key in const ['host', 'path', 'mode']) {
      final value = _s(settings[key]);
      if (value.isNotEmpty) transport[key] = value;
    }
    transport.putIfAbsent('mode', () => 'auto');
    if (!const {
      'auto',
      'packet-up',
      'stream-up',
      'stream-one',
    }.contains(transport['mode'])) {
      throw const FormatException('Unsupported Xray XHTTP mode');
    }
    if (_map(
      effective['headers'],
    ).keys.any((key) => key.toLowerCase() == 'host')) {
      throw const FormatException('Xray XHTTP requires host outside headers');
    }

    for (final entry in effective.entries) {
      final key = normalizeImportedKey(entry.key.toString());
      final item = entry.value;
      if (key == 'download_settings' && item != null) {
        throw const FormatException(
          'Xray XHTTP downloadSettings is unsupported',
        );
      }
      if (key == 'h2_params' && item != null) {
        throw const FormatException('Xray XHTTP h2Params is unsupported');
      }
      if (const {
        'type',
        'host',
        'path',
        'mode',
        'extra',
        'download_settings',
      }.contains(key)) {
        continue;
      }
      transport[key] = key == 'xmux' && item is Map
          ? {
              for (final xmuxEntry in item.entries)
                normalizeImportedKey(xmuxEntry.key.toString()): xmuxEntry.value,
            }
          : item;
    }
    return transport;
  }

  static Map<String, dynamic> _map(dynamic v) {
    if (v is Map<dynamic, dynamic>) return Map<String, dynamic>.from(v);
    return {};
  }

  static List<dynamic> _list(dynamic v) {
    if (v is List<dynamic>) return v;
    return [];
  }
}
