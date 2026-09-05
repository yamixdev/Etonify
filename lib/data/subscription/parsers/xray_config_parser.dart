import 'dart:convert';

/// Extracts outbounds from an Xray / V2Ray JSON configuration and
/// converts them to sing-box outbound format.
class XrayConfigParseResult {
  const XrayConfigParseResult({
    required this.outbounds,
    this.groups = const [],
  });

  final List<Map<String, dynamic>> outbounds;
  final List<Map<String, dynamic>> groups;
}

class XrayConfigParser {
  XrayConfigParser._();

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
    final json = jsonDecode(content);

    if (json is Map) {
      _appendParsedConfig(
        Map<String, dynamic>.from(json),
        outbounds,
        groups,
        sourceScope: _sourceScope(0),
      );
      return XrayConfigParseResult(outbounds: outbounds, groups: groups);
    }

    if (json is List) {
      for (var i = 0; i < json.length; i++) {
        final entry = json[i];
        if (entry is! Map) continue;
        _appendParsedConfig(
          Map<String, dynamic>.from(entry),
          outbounds,
          groups,
          sourceScope: _sourceScope(i),
        );
      }
    }

    return XrayConfigParseResult(outbounds: outbounds, groups: groups);
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
    List<Map<String, dynamic>> groups, {
    required String sourceScope,
  }) {
    final outbounds = json['outbounds'];
    if (outbounds is! List) {
      return;
    }

    final remarks = (json['remarks'] as String?)?.trim();
    final proxyEntries = outbounds
        .where((entry) {
          if (entry is! Map) return false;
          final protocol = (entry['protocol'] ?? '') as String;
          return !_skipProtocols.contains(protocol);
        })
        .toList(growable: false);
    final singleProxyDisplayName =
        proxyEntries.length == 1 && remarks != null && remarks.isNotEmpty
        ? remarks
        : null;

    final convertedSourceTags = <String>[];
    var proxyIndex = 0;
    for (final entry in outbounds) {
      if (entry is! Map) continue;
      final ob = Map<String, dynamic>.from(entry);

      final protocol = (ob['protocol'] ?? '') as String;
      if (_skipProtocols.contains(protocol)) continue;

      final sourceTag = _sourceTag(ob, proxyIndex, sourceScope);
      proxyIndex++;
      final converted = _convert(ob);
      if (converted != null) {
        converted['_source_tag'] = sourceTag;
        converted['_source_scope'] = sourceScope;
        if (remarks != null && remarks.isNotEmpty) {
          converted['_source_profile_name'] = remarks;
        }
        convertedSourceTags.add(sourceTag);
        if (singleProxyDisplayName != null) {
          converted['_name'] = singleProxyDisplayName;
        }
        results.add(converted);
      }
    }

    _appendParsedGroups(
      json,
      groups,
      convertedSourceTags: convertedSourceTags,
      remarks: remarks,
      sourceScope: sourceScope,
    );
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
        if (parsedName.countryCode != null) 'country': parsedName.countryCode,
        'outbounds': memberTags,
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
    final sourceTag = _s(outbound['tag']);
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
    final protocol = (ob['protocol'] ?? '') as String;
    final tag = (ob['tag'] ?? '') as String;
    final settings = _map(ob['settings']);
    final stream = _map(ob['streamSettings']);

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

    final flow = _s(user['flow']);
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
      final fp = _s(rs['fingerprint']);
      if (fp.isNotEmpty) {
        tls['utls'] = {'enabled': true, 'fingerprint': fp};
      }
      final reality = <String, dynamic>{'enabled': true};
      final pbk = _s(rs['publicKey']);
      if (pbk.isNotEmpty) reality['public_key'] = pbk;
      final sid = _s(rs['shortId']);
      if (sid.isNotEmpty) reality['short_id'] = sid;
      final spiderX = _s(rs['spiderX']);
      if (spiderX.isNotEmpty) reality['spider_x'] = spiderX;
      tls['reality'] = reality;
    } else {
      final ts = _map(stream['tlsSettings']);
      final sni = _s(ts['serverName']);
      if (sni.isNotEmpty) tls['server_name'] = sni;
      if (ts['allowInsecure'] == true) tls['insecure'] = true;
      final alpn = ts['alpn'];
      if (alpn is List) tls['alpn'] = alpn.map((e) => e.toString()).toList();
      final fp = _s(ts['fingerprint']);
      if (fp.isNotEmpty) {
        tls['utls'] = {'enabled': true, 'fingerprint': fp};
      }
    }

    return tls;
  }

  // ━━━━━━━━━━━━━━━━━━ Transport ━━━━━━━━━━━━━━━━━━

  static void _addTransport(
    Map<String, dynamic> r,
    Map<String, dynamic> stream,
  ) {
    final network = _s(stream['network'], 'tcp').toLowerCase();

    switch (network) {
      case 'ws':
        final ws = _map(stream['wsSettings']);
        final t = <String, dynamic>{'type': 'ws'};
        final path = _s(ws['path']);
        if (path.isNotEmpty) t['path'] = path;
        final headers = ws['headers'];
        if (headers is Map) {
          t['headers'] = Map<String, dynamic>.from(headers);
        }
        r['transport'] = t;

      case 'grpc':
        final gs = _map(stream['grpcSettings']);
        final t = <String, dynamic>{'type': 'grpc'};
        final sn = _s(gs['serviceName']);
        if (sn.isNotEmpty) t['service_name'] = sn;
        r['transport'] = t;

      case 'h2':
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
        r['transport'] = t;

      case 'splithttp':
      case 'xhttp':
        final sh = _map(stream['splithttpSettings'] ?? stream['xhttpSettings']);
        final t = <String, dynamic>{
          'type': 'xhttp',
          ..._xhttpExtra(sh['extra']),
        };
        final host = _s(sh['host']);
        if (host.isNotEmpty) t['host'] = host;
        final path = _s(sh['path']);
        if (path.isNotEmpty) t['path'] = path;
        final mode = _s(sh['mode']);
        if (mode.isNotEmpty) t['mode'] = mode;
        final headers = sh['headers'];
        if (headers is Map) {
          t['headers'] = Map<String, dynamic>.from(headers);
        }
        // xmux settings
        final xmux = sh['xmux'];
        if (xmux is Map) {
          t['xmux'] = Map<String, dynamic>.from(xmux);
        }
        r['transport'] = t;

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
        // tcp with header type "http" → sing-box http transport
        final tcp = _map(stream['tcpSettings']);
        final header = _map(tcp['header']);
        if (_s(header['type']) == 'http') {
          final t = <String, dynamic>{'type': 'http'};
          final req = _map(header['request']);
          final path = req['path'];
          if (path is List && path.isNotEmpty) {
            t['path'] = path.first.toString();
          }
          final headers = _map(req['headers']);
          final host = headers['Host'];
          if (host is List) {
            t['host'] = host.map((e) => e.toString()).toList();
          }
          r['transport'] = t;
        }
    }
  }

  // ━━━━━━━━━━━━━━━━━━ Utility ━━━━━━━━━━━━━━━━━━

  static String _s(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    return v.toString();
  }

  static int _i(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static Map<String, dynamic> _xhttpExtra(dynamic rawValue) {
    dynamic value = rawValue;
    if (value is String && value.trim().isNotEmpty) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const <String, dynamic>{};
      }
    }
    if (value is! Map) {
      return const <String, dynamic>{};
    }

    final extra = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = _camelToSnake(entry.key.toString());
      final item = entry.value;
      extra[key] = key == 'xmux' && item is Map
          ? {
              for (final xmuxEntry in item.entries)
                _camelToSnake(xmuxEntry.key.toString()): xmuxEntry.value,
            }
          : item;
    }
    return extra;
  }

  static String _camelToSnake(String value) {
    return value.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
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
