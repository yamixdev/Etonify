import 'dart:convert';

/// Extracts outbounds from a sing-box JSON configuration.
///
/// If the subscription server returns a full sing-box config, this parser
/// extracts the relevant outbounds (filtering out meta types like
/// `direct`, `block`, `dns`, `selector`, `urltest`).
class SingboxConfigParser {
  SingboxConfigParser._();

  static const _metaTypes = {'direct', 'block', 'dns', 'selector', 'urltest'};

  /// Returns `true` if [content] looks like a sing-box configuration.
  static bool canParse(String content) {
    try {
      final json = jsonDecode(content);
      if (json is Map) {
        return _isSingboxConfigMap(Map<String, dynamic>.from(json));
      }
      if (json is List) {
        return json.any((entry) {
          if (entry is! Map) return false;
          return _isSingboxConfigMap(Map<String, dynamic>.from(entry));
        });
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Parses sing-box JSON config and returns proxy outbound maps.
  /// Each returned map has `_name` set from the outbound `tag`.
  /// Invalid outbounds (missing required fields) are skipped.
  static List<Map<String, dynamic>> parse(String content) {
    final results = <Map<String, dynamic>>[];
    final json = jsonDecode(content);

    if (json is Map) {
      _appendParsedConfig(Map<String, dynamic>.from(json), results);
      return results;
    }

    if (json is List) {
      for (final entry in json) {
        if (entry is! Map) continue;
        _appendParsedConfig(Map<String, dynamic>.from(entry), results);
      }
    }

    return results;
  }

  static bool _isSingboxConfigMap(Map<String, dynamic> json) {
    if (!json.containsKey('outbounds') || json['outbounds'] is! List) {
      return false;
    }
    final outbounds = json['outbounds'] as List;
    if (outbounds.isEmpty) {
      return false;
    }
    final first = outbounds.first;
    return first is Map && first.containsKey('type');
  }

  static void _appendParsedConfig(
    Map<String, dynamic> json,
    List<Map<String, dynamic>> results,
  ) {
    final outbounds = json['outbounds'];
    if (outbounds is! List) {
      return;
    }

    for (final entry in outbounds) {
      if (entry is! Map) continue;
      final ob = Map<String, dynamic>.from(entry);

      final type = (ob['type'] ?? '') as String;
      if (_metaTypes.contains(type)) continue;
      if (type.isEmpty) continue;
      _normalizePort(ob);
      if (!_validate(ob, type)) continue;

      final tag = (ob['tag'] ?? '') as String;
      ob['_name'] = tag.isNotEmpty ? tag : '$type-${results.length}';
      results.add(ob);
    }
  }

  /// Validates that an outbound has the minimum required fields for its type.
  static bool _validate(Map<String, dynamic> ob, String type) {
    switch (type) {
      case 'vless':
        return _hasString(ob, 'server') &&
            _hasPort(ob) &&
            _hasString(ob, 'uuid');
      case 'vmess':
        return _hasString(ob, 'server') &&
            _hasPort(ob) &&
            _hasString(ob, 'uuid');
      case 'trojan':
        return _hasString(ob, 'server') &&
            _hasPort(ob) &&
            _hasString(ob, 'password');
      case 'shadowsocks':
        return _hasString(ob, 'server') &&
            _hasPort(ob) &&
            _hasString(ob, 'method') &&
            _hasString(ob, 'password');
      case 'shadowsocksr':
        return _hasString(ob, 'server') &&
            _hasPort(ob) &&
            _hasString(ob, 'method') &&
            _hasString(ob, 'password');
      case 'hysteria2':
        return _hasString(ob, 'server') && _hasPort(ob);
      case 'hysteria':
        return _hasString(ob, 'server') && _hasPort(ob);
      case 'tuic':
        return _hasString(ob, 'server') &&
            _hasPort(ob) &&
            _hasString(ob, 'uuid');
      case 'wireguard':
        return _hasString(ob, 'private_key');
      case 'anytls':
        return _hasString(ob, 'server') &&
            _hasPort(ob) &&
            _hasString(ob, 'password');
      case 'socks':
      case 'http':
        return _hasString(ob, 'server') && _hasPort(ob);
      default:
        // Unknown types pass through — be lenient
        return true;
    }
  }

  static bool _hasString(Map<String, dynamic> ob, String key) {
    final v = ob[key];
    return v is String && v.isNotEmpty;
  }

  static void _normalizePort(Map<String, dynamic> ob) {
    final v = ob['server_port'];
    if (v is int) return;
    if (v is String) {
      final parsed = int.tryParse(v.trim());
      if (parsed != null && parsed > 0 && parsed <= 65535) {
        ob['server_port'] = parsed;
      }
    }
  }

  static bool _hasPort(Map<String, dynamic> ob) {
    final v = ob['server_port'];
    return v is int && v > 0 && v <= 65535;
  }
}
