import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'outbound_schema.dart';
import 'outbound_support.dart';
import 'parsers/clash_parser.dart';
import 'parsers/link_parser.dart';
import 'parsers/singbox_config_parser.dart';
import 'parsers/sip008_parser.dart';
import 'parsers/wireguard_config_parser.dart';
import 'parsers/xray_config_parser.dart';

/// The format that was detected during parsing.
enum SubscriptionFormat {
  singboxConfig,
  xrayConfig,
  sip008,
  clashYaml,
  base64Links,
  rawLinks,
  wireguardConfig,
  unknown,
}

/// Result of parsing subscription content.
class ParseResult {
  const ParseResult({
    required this.format,
    required this.outbounds,
    this.groups = const [],
    this.bodyMeta = const {},
    this.unsupportedWireGuardCount = 0,
  });

  final SubscriptionFormat format;

  /// List of sing-box outbound JSON maps.
  /// Each map may contain a `_name` key with the display name.
  final List<Map<String, dynamic>> outbounds;

  /// Proxy groups extracted from container formats such as Xray balancers.
  final List<ParsedOutboundGroup> groups;

  /// Metadata extracted from subscription body comment lines
  /// (e.g. `#profile-title`, `#subscription-userinfo`, etc.)
  final Map<String, String> bodyMeta;

  /// WireGuard entries detected and intentionally excluded from the result.
  final int unsupportedWireGuardCount;

  bool get hasUnsupportedWireGuard => unsupportedWireGuardCount > 0;

  Map<String, dynamic> toMap() => {
    'format': format.name,
    'outbounds': outbounds,
    if (groups.isNotEmpty) 'groups': groups.map((g) => g.toMap()).toList(),
    'bodyMeta': bodyMeta,
    if (unsupportedWireGuardCount > 0)
      'unsupportedWireGuardCount': unsupportedWireGuardCount,
  };

  factory ParseResult.fromMap(Map<String, dynamic> map) {
    final formatName = map['format']?.toString() ?? '';
    return ParseResult(
      format: SubscriptionFormat.values.firstWhere(
        (value) => value.name == formatName,
        orElse: () => SubscriptionFormat.unknown,
      ),
      outbounds: (map['outbounds'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                Map<String, dynamic>.from(entry as Map<dynamic, dynamic>),
          )
          .toList(growable: false),
      groups: (map['groups'] as List<dynamic>? ?? const [])
          .map(
            (entry) => ParsedOutboundGroup.fromMap(
              Map<String, dynamic>.from(entry as Map<dynamic, dynamic>),
            ),
          )
          .where((group) => group.sourceOutboundTags.isNotEmpty)
          .toList(growable: false),
      bodyMeta: (map['bodyMeta'] as Map? ?? const <String, dynamic>{}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      unsupportedWireGuardCount:
          (map['unsupportedWireGuardCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ParsedOutboundGroup {
  const ParsedOutboundGroup({
    required this.sourceTag,
    required this.name,
    required this.sourceOutboundTags,
    this.sourceFallbackTag,
    this.type = 'urltest',
    this.sourceScope = '',
    this.countryCode,
    this.url,
    this.method,
    this.intervalSeconds,
    this.timeoutSeconds,
    this.concurrency,
    this.unavailableCheckIntervalSeconds,
  });

  final String sourceTag;
  final String name;
  final String type;
  final String sourceScope;
  final String? countryCode;
  final List<String> sourceOutboundTags;
  final String? sourceFallbackTag;
  final String? url;
  final String? method;
  final int? intervalSeconds;
  final int? timeoutSeconds;
  final int? concurrency;
  final int? unavailableCheckIntervalSeconds;

  Map<String, dynamic> toMap() => {
    'tag': sourceTag,
    'name': name,
    'type': type,
    if (sourceScope.isNotEmpty) 'source_scope': sourceScope,
    if (countryCode != null) 'country': countryCode,
    'outbounds': sourceOutboundTags,
    if (sourceFallbackTag != null) 'fallback_tag': sourceFallbackTag,
    if (url != null) 'url': url,
    if (method != null) 'method': method,
    if (intervalSeconds != null) 'interval': intervalSeconds,
    if (timeoutSeconds != null) 'timeout': timeoutSeconds,
    if (concurrency != null) 'concurrency': concurrency,
    if (unavailableCheckIntervalSeconds != null)
      'unavailable_check_interval': unavailableCheckIntervalSeconds,
  };

  factory ParsedOutboundGroup.fromMap(Map<String, dynamic> map) {
    return ParsedOutboundGroup(
      sourceTag: map['tag']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? 'urltest',
      sourceScope:
          map['source_scope']?.toString() ??
          map['_source_scope']?.toString() ??
          '',
      countryCode:
          map['country']?.toString() ?? map['country_code']?.toString(),
      sourceOutboundTags: (map['outbounds'] as List? ?? const [])
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false),
      sourceFallbackTag: map['fallback_tag']?.toString().trim(),
      url: map['url']?.toString(),
      method: map['method']?.toString(),
      intervalSeconds: (map['interval'] as num?)?.toInt(),
      timeoutSeconds: (map['timeout'] as num?)?.toInt(),
      concurrency: (map['concurrency'] as num?)?.toInt(),
      unavailableCheckIntervalSeconds:
          (map['unavailable_check_interval'] as num?)?.toInt(),
    );
  }
}

/// Detects the format of subscription content and parses it into
/// a list of sing-box outbound configurations.
class SubscriptionParser {
  SubscriptionParser._();

  static final RegExp _base64WhitespacePattern = RegExp(r'\s');
  static final RegExp _base64AlphabetPattern = RegExp(r'^[A-Za-z0-9+/=_-]+$');
  static final RegExp _proxyChainSeparatorPattern = RegExp(r'\s+->\s+');
  static const List<String> _proxyLinkSchemes = <String>[
    'vless://',
    'vmess://',
    'trojan://',
    'ss://',
    'ssr://',
    'socks://',
    'socks4://',
    'socks4a://',
    'socks5://',
    'socks5h://',
    'naive+https://',
    'naive+quic://',
    'http://',
    'https://',
    'hysteria2://',
    'hy2://',
    'hysteria://',
    'hy://',
    'tuic://',
    'anytls://',
  ];
  static final RegExp _proxyLinkSchemePattern = RegExp(
    _proxyLinkSchemes.map(RegExp.escape).join('|'),
    caseSensitive: false,
  );

  static Future<ParseResult> parseInBackground(String content) async {
    final payload = await compute(_parseSubscriptionContent, content);
    return ParseResult.fromMap(Map<String, dynamic>.from(payload));
  }

  /// Parses [content] by trying all known formats in priority order.
  ///
  /// Priority:
  /// 1. Sing-box JSON config (has "outbounds" with "type")
  /// 2. Xray JSON config (has "outbounds" with "protocol")
  /// 3. SIP008 JSON (has "servers" array)
  /// 4. Clash YAML (has "proxies:" key)
  /// 5. WireGuard .conf (has [Interface] + [Peer])
  /// 6. Base64-decoded proxy links
  /// 7. Raw proxy links (one per line)
  static ParseResult parse(String content) {
    content = content.trim();
    if (content.isEmpty) {
      return const ParseResult(
        format: SubscriptionFormat.unknown,
        outbounds: [],
      );
    }

    // ── 1. Try JSON-based formats ──
    if (_looksLikeJson(content)) {
      // Sing-box config
      if (SingboxConfigParser.canParse(content)) {
        return _buildResult(
          format: SubscriptionFormat.singboxConfig,
          parsedOutbounds: SingboxConfigParser.parse(content),
        );
      }

      // Xray config
      if (XrayConfigParser.canParse(content)) {
        final parsed = XrayConfigParser.parseWithGroups(content);
        return _buildResult(
          format: SubscriptionFormat.xrayConfig,
          parsedOutbounds: parsed.outbounds,
          groups: parsed.groups
              .map(ParsedOutboundGroup.fromMap)
              .toList(growable: false),
        );
      }

      // SIP008
      if (Sip008Parser.canParse(content)) {
        return _buildResult(
          format: SubscriptionFormat.sip008,
          parsedOutbounds: Sip008Parser.parse(content),
        );
      }
    }

    // ── 2. Clash YAML ──
    if (ClashParser.canParse(content)) {
      return _buildResult(
        format: SubscriptionFormat.clashYaml,
        parsedOutbounds: ClashParser.parse(content),
      );
    }

    // ── 3. WireGuard config ──
    if (WireGuardConfigParser.canParse(content)) {
      return _buildResult(
        format: SubscriptionFormat.wireguardConfig,
        parsedOutbounds: WireGuardConfigParser.parse(content),
      );
    }

    // ── 4. Try base64 decode → then parse links ──
    final decoded = _tryBase64Decode(content);
    if (decoded != null) {
      final bodyMeta = _extractBodyMeta(decoded);
      final links = _parseLinks(decoded);
      if (links.isNotEmpty) {
        return _buildResult(
          format: SubscriptionFormat.base64Links,
          parsedOutbounds: links,
          bodyMeta: bodyMeta,
        );
      }
    }

    // ── 5. Raw links (one per line) ──
    final bodyMeta = _extractBodyMeta(content);
    final links = _parseLinks(content);
    if (links.isNotEmpty) {
      return _buildResult(
        format: SubscriptionFormat.rawLinks,
        parsedOutbounds: links,
        bodyMeta: bodyMeta,
      );
    }

    return const ParseResult(format: SubscriptionFormat.unknown, outbounds: []);
  }

  // ─────────────────── helpers ───────────────────

  static ParseResult _buildResult({
    required SubscriptionFormat format,
    required List<Map<String, dynamic>> parsedOutbounds,
    List<ParsedOutboundGroup> groups = const [],
    Map<String, String> bodyMeta = const {},
  }) {
    final unsupportedWireGuardCount = parsedOutbounds
        .where(isWireGuardOutboundConfig)
        .length;
    return ParseResult(
      format: format,
      outbounds: _normalizeOutbounds(
        parsedOutbounds
            .where(isSupportedOutboundConfig)
            .toList(growable: false),
      ),
      groups: groups,
      bodyMeta: bodyMeta,
      unsupportedWireGuardCount: unsupportedWireGuardCount,
    );
  }

  static bool _looksLikeJson(String s) {
    return s.startsWith('{') || s.startsWith('[');
  }

  /// Tries to base64-decode the entire content.
  /// Returns the decoded string or null if it fails or produces garbage.
  static String? _tryBase64Decode(String input) {
    // Remove whitespace (base64 can be multi-line)
    final clean = input.replaceAll(_base64WhitespacePattern, '');

    // Quick heuristic: valid base64 chars only
    if (!_base64AlphabetPattern.hasMatch(clean)) return null;

    try {
      String s = clean.replaceAll('-', '+').replaceAll('_', '/');
      switch (s.length % 4) {
        case 2:
          s += '==';
        case 3:
          s += '=';
      }
      final bytes = base64Decode(s);
      final decoded = utf8.decode(bytes, allowMalformed: true);

      // Sanity check: decoded should contain at least one known proxy scheme
      // or comment lines
      if (_containsProxyScheme(decoded) || decoded.contains('#profile-')) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _containsProxyScheme(String s) {
    return s.contains('://') &&
        (s.contains('vless://') ||
            s.contains('vmess://') ||
            s.contains('trojan://') ||
            s.contains('ss://') ||
            s.contains('ssr://') ||
            s.contains('socks://') ||
            s.contains('socks4://') ||
            s.contains('socks4a://') ||
            s.contains('socks5://') ||
            s.contains('socks5h://') ||
            s.contains('naive+https://') ||
            s.contains('naive+quic://') ||
            s.contains('http://') ||
            s.contains('https://') ||
            s.contains('hysteria2://') ||
            s.contains('hy2://') ||
            s.contains('hysteria://') ||
            s.contains('hy://') ||
            s.contains('tuic://') ||
            s.contains('anytls://'));
  }

  /// Parses each line as a proxy link, skipping comment lines and blanks.
  static List<Map<String, dynamic>> _parseLinks(String content) {
    final results = <Map<String, dynamic>>[];
    var proxyChainIndex = 0;
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) continue; // comment / metadata line

      final chainParts = _splitProxyChainLinks(trimmed);
      if (chainParts.length > 1) {
        final chainOutbounds = _parseProxyChainLinks(
          chainParts,
          'proxy-chain-${proxyChainIndex++}',
        );
        if (chainOutbounds != null) {
          results.addAll(chainOutbounds);
          continue;
        }
      }

      for (final candidate in _splitConcatenatedLinks(trimmed)) {
        final parsed = LinkParser.tryParse(candidate);
        if (parsed != null) {
          results.add(parsed);
        }
      }
    }
    return results;
  }

  static List<String> _splitProxyChainLinks(String line) {
    if (!line.contains('->')) {
      return <String>[line];
    }
    return line
        .split(_proxyChainSeparatorPattern)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  static List<Map<String, dynamic>>? _parseProxyChainLinks(
    List<String> parts,
    String sourceScope,
  ) {
    final parsed = <Map<String, dynamic>>[];
    final names = <String>[];
    for (var i = 0; i < parts.length; i++) {
      final outbound = LinkParser.tryParse(parts[i]);
      if (outbound == null) {
        return null;
      }
      final sourceTag = 'hop-$i';
      final name = outbound['_name']?.toString().trim() ?? '';
      if (name.isNotEmpty) {
        names.add(name);
      }
      outbound['_source_scope'] = sourceScope;
      outbound['_source_tag'] = sourceTag;
      if (i > 0) {
        outbound['_detour_source_tag'] = 'hop-${i - 1}';
      }
      if (i < parts.length - 1) {
        outbound['_group_only'] = true;
      } else if (names.length > 1) {
        outbound['_name'] = names.join(' -> ');
      }
      parsed.add(outbound);
    }
    return parsed;
  }

  static List<Map<String, dynamic>> _normalizeOutbounds(
    List<Map<String, dynamic>> outbounds,
  ) {
    return outbounds
        .map(_normalizeOutbound)
        .map(ParsedOutboundSchema.sanitize)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  static Map<String, dynamic> _normalizeOutbound(
    Map<String, dynamic> outbound,
  ) {
    final normalized = Map<String, dynamic>.from(outbound);
    final transport = normalized['transport'];
    if (transport is Map) {
      final transportMap = Map<String, dynamic>.from(transport);
      normalized['transport'] = transportMap;
      final transportType = transportMap['type']
          ?.toString()
          .trim()
          .toLowerCase();
      if (transportType == 'grpc') {
        final tls = normalized['tls'];
        if (tls is Map) {
          final tlsMap = Map<String, dynamic>.from(tls);
          tlsMap['alpn'] = const ['h2'];
          normalized['tls'] = tlsMap;
        }
      }

      final headers = transportMap['headers'];
      if (headers is Map) {
        final sanitizedHeaders = _sanitizeHeaders(headers);
        if (sanitizedHeaders.isEmpty) {
          transportMap.remove('headers');
        } else {
          transportMap['headers'] = sanitizedHeaders;
        }
      }
    }

    if (normalized['type'] == 'hysteria2') {
      final tls = normalized['tls'];
      if (tls is Map) {
        final tlsMap = Map<String, dynamic>.from(tls);
        tlsMap.remove('utls');
        normalized['tls'] = tlsMap;
      }
    }
    return normalized;
  }

  static Map<String, dynamic> _sanitizeHeaders(Map<dynamic, dynamic> headers) {
    final sanitized = <String, dynamic>{};

    for (final entry in headers.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          sanitized[key] = trimmed;
        }
        continue;
      }

      if (value is List) {
        final items = value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
        if (items.isNotEmpty) {
          sanitized[key] = items;
        }
        continue;
      }

      if (value != null) {
        sanitized[key] = value;
      }
    }

    return sanitized;
  }

  static List<String> _splitConcatenatedLinks(String line) {
    final matches = _proxyLinkSchemePattern.allMatches(line).iterator;
    if (!matches.moveNext()) {
      return [line];
    }
    final firstStart = matches.current.start;
    if (!matches.moveNext()) {
      return [line];
    }

    final parts = <String>[];
    var start = firstStart;
    do {
      final nextStart = matches.current.start;
      final part = line.substring(start, nextStart).trim();
      if (part.isNotEmpty) {
        parts.add(part);
      }
      start = nextStart;
    } while (matches.moveNext());
    final lastPart = line.substring(start).trim();
    if (lastPart.isNotEmpty) {
      parts.add(lastPart);
    }
    return parts;
  }

  /// Extracts metadata from comment lines in the subscription body.
  /// Lines like `#profile-title: My VPN` or `#subscription-userinfo: ...`
  static Map<String, String> _extractBodyMeta(String content) {
    final meta = <String, String>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('#')) continue;

      // Format: #key: value  or  #key value
      final withoutHash = trimmed.substring(1).trim();
      final colonIdx = withoutHash.indexOf(':');
      if (colonIdx > 0) {
        final key = withoutHash.substring(0, colonIdx).trim().toLowerCase();
        final value = withoutHash.substring(colonIdx + 1).trim();
        if (_knownMetaKeys.contains(key)) {
          meta[key] = value;
        }
      } else {
        // Try space separator: #key value
        final spaceIdx = withoutHash.indexOf(' ');
        if (spaceIdx > 0) {
          final key = withoutHash.substring(0, spaceIdx).trim().toLowerCase();
          final value = withoutHash.substring(spaceIdx + 1).trim();
          if (_knownMetaKeys.contains(key)) {
            meta[key] = value;
          }
        }
      }
    }
    return meta;
  }

  static const _knownMetaKeys = {
    'profile-title',
    'profile-update-interval',
    'subscription-userinfo',
    'support-url',
    'profile-web-page-url',
    'new-url',
    'per-app-proxy-mode',
    'per-app-proxy-list',
  };
}

Map<String, dynamic> _parseSubscriptionContent(String content) {
  return SubscriptionParser.parse(content).toMap();
}
