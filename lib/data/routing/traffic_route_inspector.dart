import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meow_client/data/routing/traffic_rule_override.dart';

part 'traffic_route_srs.dart';

typedef _RuleMap = Map<Object?, Object?>;

class TrafficRoutePreview {
  const TrafficRoutePreview({
    required this.target,
    required this.route,
    this.dns,
    this.dnsIpv6,
  });

  final String target;
  final TrafficRuleMatch route;
  final TrafficRuleMatch? dns;
  final TrafficRuleMatch? dnsIpv6;
}

class TrafficRuleMatch {
  const TrafficRuleMatch({
    required this.tag,
    required this.ruleIndex,
    required this.label,
    this.resolver,
    this.detour,
    this.resolverType,
    this.customRule,
  });

  final String? tag;
  final int? ruleIndex;
  final String label;
  final String? resolver;
  final String? detour;
  final String? resolverType;
  final TrafficRuleOverride? customRule;

  bool get isUnknown => tag == null;
}

/// Evaluates the generated configuration for a destination-only preview.
/// DNS results describe A and, where enabled, AAAA queries.
class TrafficRouteInspector {
  TrafficRouteInspector._(this._config, this._domain, this._ip) {
    final route = _config['route'];
    for (final ruleSet in _maps(route is _RuleMap ? route['rule_set'] : null)) {
      if (ruleSet['tag'] case final String tag) {
        _ruleSets[tag] = ruleSet;
      }
    }
  }

  static Future<TrafficRoutePreview> inspect({
    required String target,
    required Map<String, dynamic> config,
    Map<int, TrafficRuleOverride> customRouteRules = const {},
    Map<int, TrafficRuleOverride> customDnsRules = const {},
  }) async {
    var host = target.trim().toLowerCase();
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    if (host.endsWith('.')) host = host.substring(0, host.length - 1);
    final address = InternetAddress.tryParse(host);
    if (address == null && !_validDomain.hasMatch(host)) {
      throw const FormatException('Invalid domain or IP address');
    }

    final inspector = TrafficRouteInspector._(
      config,
      address == null ? host : null,
      address?.rawAddress,
    );
    final dnsSection = config['dns'];
    final route = await inspector._inspectSection(
      'route',
      customRules: customRouteRules,
    );
    final dns = address == null
        ? await inspector._inspectSection(
            'dns',
            queryType: 1,
            customRules: customDnsRules,
          )
        : null;
    final dnsIpv6 =
        address == null &&
            dnsSection is _RuleMap &&
            dnsSection['strategy'] != 'ipv4_only'
        ? await inspector._inspectSection(
            'dns',
            queryType: 28,
            customRules: customDnsRules,
          )
        : null;
    return TrafficRoutePreview(
      target: address?.address ?? host,
      route: route,
      dns: dns,
      dnsIpv6: dnsIpv6,
    );
  }

  final Map<String, dynamic> _config;
  final String? _domain;
  final Uint8List? _ip;
  final _ruleSets = <String, _RuleMap>{};
  final _loaded = <String, Future<Object?>>{};

  Future<TrafficRuleMatch> _inspectSection(
    String name, {
    int? queryType,
    required Map<int, TrafficRuleOverride> customRules,
  }) async {
    final section = _config[name];
    final isDns = queryType != null;
    final outputKey = isDns ? 'server' : 'outbound';
    if (section is _RuleMap) {
      final rules = section['rules'];
      if (rules != null && rules is! List<Object?>) {
        return TrafficRuleMatch(
          tag: null,
          ruleIndex: null,
          label: '$name.rules',
        );
      }
      if (rules is List<Object?>) {
        for (var index = 0; index < rules.length; index++) {
          final rule = rules[index];
          if (rule is! _RuleMap) {
            return TrafficRuleMatch(
              tag: null,
              ruleIndex: index,
              label: '$name.rules',
            );
          }
          final action = rule['action'] ?? 'route';
          if (action == 'route-options' ||
              action == 'sniff' ||
              (!isDns && _isGeneratedInfrastructureRule(rule))) {
            continue;
          }
          final matched = await _matchRule(rule, queryType);
          if (matched == _Match.no) continue;
          final tag = matched == _Match.unknown
              ? null
              : switch (action) {
                  'route' => _tag(rule[outputKey]),
                  'reject' => 'reject',
                  _ => null,
                };
          return _result(
            name,
            section,
            tag,
            index,
            _label(rule, '$name.rules'),
            customRule: customRules[index],
          );
        }
      }
      final fallback =
          _tag(section['final']) ??
          _firstTag(isDns ? section['servers'] : _config['outbounds']);
      return _result(name, section, fallback, null, '$name.final');
    }
    return TrafficRuleMatch(tag: null, ruleIndex: null, label: '$name.final');
  }

  TrafficRuleMatch _result(
    String sectionName,
    _RuleMap section,
    String? tag,
    int? ruleIndex,
    String label, {
    TrafficRuleOverride? customRule,
  }) {
    _RuleMap? resolver;
    if (sectionName == 'dns' && tag != null && tag != 'reject') {
      for (final server in _maps(section['servers'])) {
        if (server['tag'] == tag) {
          resolver = server;
          break;
        }
      }
    }
    return TrafficRuleMatch(
      tag: tag,
      ruleIndex: ruleIndex,
      label: label,
      resolver: _tag(resolver?['server']),
      detour:
          _tag(resolver?['detour']) ??
          (resolver?['server'] is String ? 'direct' : null),
      resolverType: _tag(resolver?['type']),
      customRule: customRule,
    );
  }

  Future<_Match> _matchRule(
    _RuleMap rule,
    int? queryType, {
    int depth = 0,
  }) async {
    if (depth > 100) return _Match.unknown;
    final type = rule['type'] ?? 'default';
    _Match result;
    if (type == 'logical') {
      final children = rule['rules'];
      final mode = rule['mode'];
      if (children is! List<Object?> ||
          children.isEmpty ||
          (mode != 'and' && mode != 'or')) {
        return _Match.unknown;
      }
      result = mode == 'and' ? _Match.yes : _Match.no;
      for (final child in children) {
        final match = child is _RuleMap
            ? await _matchRule(child, queryType, depth: depth + 1)
            : _Match.unknown;
        result = mode == 'and' ? result.and(match) : result.or(match);
        if (mode == 'and' ? result == _Match.no : result == _Match.yes) {
          break;
        }
      }
    } else if (type == 'default') {
      result = await _matchDefault(rule, queryType);
    } else {
      return _Match.unknown;
    }
    return switch (rule['invert']) {
      true => result.inverted,
      false || null => result,
      _ => _Match.unknown,
    };
  }

  Future<_Match> _matchDefault(_RuleMap rule, int? queryType) async {
    _Match? address;
    var result = _Match.yes;
    var hasRuleSet = false;
    for (final entry in rule.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is List<Object?> && value.isEmpty) continue;
      if (_ruleOptions.contains(key)) continue;
      if (_addressMatchers.contains(key)) {
        if (key == 'ip_is_private' && value == false) continue;
        address = (address ?? _Match.no).or(
          _matchAddress(key, value, queryType),
        );
      } else if (key == 'rule_set') {
        hasRuleSet = true;
      } else if (key == 'query_type') {
        result = result.and(_matchQueryTypes(value, queryType));
      } else if (key != null) {
        result = result.and(_Match.unknown);
      }
    }
    if (result == _Match.no) return result;
    if (!hasRuleSet) return result.and(address ?? _Match.yes);
    if (address != null ||
        rule['rule_set_ip_cidr_match_source'] == true ||
        rule['rule_set_ipcidr_match_source'] == true ||
        rule['rule_set_ip_cidr_accept_empty'] == true) {
      // sing-box can merge the address group with a headless rule, including
      // address groups that failed on the outer rule.
      return _Match.unknown;
    }
    final tags = _strings(rule['rule_set']);
    if (tags == null) return _Match.unknown;
    var setMatch = _Match.no;
    for (final tag in tags) {
      setMatch = setMatch.or(await _matchLocalRuleSet(tag, queryType));
      if (setMatch == _Match.yes) break;
    }
    return result.and(setMatch);
  }

  _Match _matchAddress(Object? key, Object? value, int? queryType) {
    if (key == 'ip_is_private') {
      if (value != true) return _Match.unknown;
      if (queryType != null) return _Match.unknown;
      final ip = _ip;
      return _Match.of(ip != null && _isPrivateAddress(ip));
    }
    final patterns = _strings(value);
    if (patterns == null) return _Match.unknown;
    return _matchesAny(patterns, (pattern) {
      if (key == 'ip_cidr') {
        if (queryType != null) return _Match.unknown;
        final ip = _ip;
        return ip == null ? _Match.no : _matchCidr(ip, pattern);
      }
      final domain = _domain;
      if (domain == null) return _Match.no;
      return switch (key) {
        'domain' => _Match.of(domain == pattern),
        'domain_suffix' => _Match.of(
          pattern.startsWith('.')
              ? domain.endsWith(pattern)
              : domain == pattern || domain.endsWith('.$pattern'),
        ),
        'domain_keyword' => _Match.of(domain.contains(pattern)),
        'domain_regex' => _matchRegex(domain, pattern),
        _ => _Match.unknown,
      };
    });
  }

  Future<_Match> _matchLocalRuleSet(String tag, int? queryType) async {
    final loaded = await _loaded.putIfAbsent(tag, () => _loadRuleSet(tag));
    if (loaded is Uint8List) {
      try {
        return _SrsReader(loaded, _domain, _ip, queryType).match();
      } on FormatException {
        return _Match.unknown;
      }
    }
    if (loaded is List<Object?>) {
      var result = _Match.no;
      for (final rule in loaded) {
        // Headless source rule sets cannot include other rule sets.
        final match = rule is _RuleMap && !_hasNestedRuleSet(rule)
            ? await _matchRule(rule, queryType)
            : _Match.unknown;
        result = result.or(match);
        if (result == _Match.yes) break;
      }
      return result;
    }
    return _Match.unknown;
  }

  bool _hasNestedRuleSet(Object? rule, [int depth = 0]) {
    if (depth > 100 || rule is! _RuleMap || rule.containsKey('rule_set')) {
      return true;
    }
    final children = rule['rules'];
    return children is List<Object?> &&
        children.any((child) => _hasNestedRuleSet(child, depth + 1));
  }

  Future<Object?> _loadRuleSet(String tag) async {
    final config = _ruleSets[tag];
    final path = config?['path'];
    if (config?['type'] != 'local' || path is! String || path.trim().isEmpty) {
      return null;
    }
    final format =
        config?['format'] ??
        (path.endsWith('.srs')
            ? 'binary'
            : path.endsWith('.json')
            ? 'source'
            : null);
    if (format != 'binary' && format != 'source') return null;
    try {
      final file = File(path);
      if (await file.length() > _SrsReader.maxBytes) return null;
      final bytes = await file.readAsBytes();
      if (format == 'binary') return _SrsReader.decode(bytes);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded case {
        'version': final int version,
        'rules': final List<Object?> rules,
      } when version >= 1 && version <= 5) {
        return rules;
      }
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
    return null;
  }

  static final _validDomain = RegExp(
    r'^(?=.{1,253}$)[a-z0-9_](?:[a-z0-9_-]{0,62})(?:\.[a-z0-9_][a-z0-9_-]{0,62})*$',
  );

  static const _addressMatchers = {
    'domain',
    'domain_suffix',
    'domain_keyword',
    'domain_regex',
    'ip_cidr',
    'ip_is_private',
  };

  static const _ruleOptions = {
    'type',
    'invert',
    'action',
    'outbound',
    'server',
    'method',
    'no_drop',
    'rule_set_ip_cidr_match_source',
    'rule_set_ipcidr_match_source',
    'rule_set_ip_cidr_accept_empty',
  };

  static bool _isGeneratedInfrastructureRule(_RuleMap rule) {
    if (rule.length == 2 &&
        rule['action'] == 'reject' &&
        rule['protocol'] == 'stun') {
      return true;
    }
    if (rule.length == 5 &&
        rule['action'] == 'reject' &&
        rule['inbound'] == 'tun-in' &&
        rule['network'] == 'icmp' &&
        rule['method'] == 'drop' &&
        rule['ip_cidr'] == '172.19.0.2/32') {
      return true;
    }
    if (rule.length != 4 ||
        rule['action'] != 'hijack-dns' ||
        rule['type'] != 'logical' ||
        rule['mode'] != 'or') {
      return false;
    }
    final children = rule['rules'];
    if (children case [final _RuleMap protocol, final _RuleMap port]) {
      return protocol.length == 1 &&
          protocol['protocol'] == 'dns' &&
          port.length == 1 &&
          port['port'] == 53;
    }
    return false;
  }

  static String _label(_RuleMap rule, String fallback, [int depth = 0]) {
    if (depth > 100) return fallback;
    final tags = _strings(rule['rule_set']);
    if (tags != null && tags.isNotEmpty) return tags.join(', ');
    final children = rule['rules'];
    if (rule['type'] == 'logical' && children is List<Object?>) {
      final labels = [
        for (final child in children)
          if (child is _RuleMap) _label(child, fallback, depth + 1),
      ].where((label) => label != fallback).toSet();
      if (labels.isNotEmpty) return labels.join(', ');
    }
    for (final key in rule.keys) {
      if (key is String &&
          !_ruleOptions.contains(key) &&
          key != 'mode' &&
          key != 'rules') {
        return key;
      }
    }
    return fallback;
  }
}

enum _Match {
  yes,
  no,
  unknown;

  static _Match of(bool value) => value ? yes : no;

  _Match get inverted => switch (this) {
    yes => no,
    no => yes,
    unknown => unknown,
  };

  _Match and(_Match other) {
    if (this == no || other == no) return no;
    return this == yes && other == yes ? yes : unknown;
  }

  _Match or(_Match other) {
    if (this == yes || other == yes) return yes;
    return this == no && other == no ? no : unknown;
  }
}

String? _tag(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

Iterable<_RuleMap> _maps(Object? value) =>
    value is List<Object?> ? value.whereType<_RuleMap>() : const [];

String? _firstTag(Object? value) {
  final maps = _maps(value);
  return maps.isEmpty ? null : _tag(maps.first['tag']);
}

List<String>? _strings(Object? value) {
  if (value is String) return [value];
  if (value is List<Object?> && value.every((item) => item is String)) {
    return value.cast<String>();
  }
  return null;
}

_Match _matchesAny<T>(Iterable<T> values, _Match Function(T) match) {
  var result = _Match.no;
  for (final value in values) {
    result = result.or(match(value));
    if (result == _Match.yes) break;
  }
  return result;
}

_Match _matchQueryTypes(Object? value, int? queryType) {
  if (queryType == null) return _Match.no;
  return _matchesAny(value is List<Object?> ? value : [value], (type) {
    final code = switch (type) {
      'A' => 1,
      'AAAA' => 28,
      final int code => code,
      String() => 0,
      _ => null,
    };
    return code == null ? _Match.unknown : _Match.of(code == queryType);
  });
}

_Match _matchCidr(Uint8List address, String pattern) {
  final parts = pattern.split('/');
  final prefix = InternetAddress.tryParse(parts.first)?.rawAddress;
  if (prefix == null || parts.length > 2) return _Match.unknown;
  final bits = parts.length == 1 ? prefix.length * 8 : int.tryParse(parts.last);
  if (bits == null || bits < 0 || bits > prefix.length * 8) {
    return _Match.unknown;
  }
  if (address.length != prefix.length) return _Match.no;
  for (var offset = 0; offset * 8 < bits; offset++) {
    final remaining = bits - offset * 8;
    final mask = remaining >= 8 ? 0xff : (0xff << (8 - remaining)) & 0xff;
    if ((address[offset] & mask) != (prefix[offset] & mask)) return _Match.no;
  }
  return _Match.yes;
}

bool _isPrivateAddress(Uint8List ip) =>
    _privateNetworks.any((prefix) => _matchCidr(ip, prefix) == _Match.yes);

const _privateNetworks = [
  '0.0.0.0/32',
  '10.0.0.0/8',
  '127.0.0.0/8',
  '169.254.0.0/16',
  '172.16.0.0/12',
  '192.168.0.0/16',
  '224.0.0.0/4',
  '::/128',
  '::1/128',
  'fc00::/7',
  'fe80::/10',
  'ff00::/8',
  '::ffff:0:0/128',
  '::ffff:10.0.0.0/104',
  '::ffff:127.0.0.0/104',
  '::ffff:169.254.0.0/112',
  '::ffff:172.16.0.0/108',
  '::ffff:192.168.0.0/112',
  '::ffff:224.0.0.0/100',
];

// The route engine uses Go's regexp package. Support patterns in the common
// subset and preserve uncertainty for Go-specific constructs.
_Match _matchRegex(String domain, String expression) {
  final insensitive = expression.startsWith('(?i)');
  final pattern = insensitive ? expression.substring(4) : expression;
  if (_ambiguousRegex.hasMatch(pattern) || pattern.length > 1024) {
    return _Match.unknown;
  }
  try {
    return _Match.of(
      RegExp(
        pattern,
        caseSensitive: !insensitive,
        unicode: true,
      ).hasMatch(domain),
    );
  } on FormatException {
    return _Match.unknown;
  }
}

final _ambiguousRegex = RegExp(
  r'\(\?(?!:)|\[\[:|\\(?:[^dDsSwWbB.^$*+?()\[\]{}|\\/]|$)',
);
