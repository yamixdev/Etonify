import 'dart:convert';
import 'dart:math';

import 'link_parser.dart';

/// Result of parsing an HTML subscription landing page.
class HtmlSubscriptionParseResult {
  const HtmlSubscriptionParseResult({
    required this.outbounds,
    this.bodyMeta = const {},
  });

  final List<Map<String, dynamic>> outbounds;
  final Map<String, String> bodyMeta;
}

/// Parses HTML subscription landing pages (e.g. web dashboards from panels
/// like 3X-UI, Marzban, Remnawave, or PinkVPN) that contain embedded
/// JavaScript DATA objects or proxy links.
class HtmlSubscriptionParser {
  HtmlSubscriptionParser._();

  static final RegExp _dataPattern = RegExp(
    r'(?:const|let|var|window\.)\s*DATA\s*=',
    caseSensitive: false,
  );

  static final RegExp _proxyLinkPattern = RegExp(
    r'(?:vless|vmess|trojan|ss|ssr|socks[45]?|naive\+(?:https|quic)|hysteria2?|hy2?|tuic|anytls)://[^\s"<>]+',
    caseSensitive: false,
  );

  static final RegExp _htmlTitlePattern = RegExp(
    r'<title[^>]*>(.*?)</title>',
    caseSensitive: false,
    dotAll: true,
  );

  static bool looksLikeHtml(String content) {
    final trimmed = content.trimLeft();
    if (trimmed.isEmpty) return false;
    final prefix = trimmed
        .substring(0, min(trimmed.length, 1024))
        .toLowerCase();
    return prefix.startsWith('<!doctype html') ||
        prefix.startsWith('<html') ||
        (prefix.contains('<html') && prefix.contains('<body'));
  }

  static bool canParse(String content) {
    if (!looksLikeHtml(content)) return false;
    final result = parse(content);
    return result.outbounds.isNotEmpty;
  }

  static HtmlSubscriptionParseResult parse(String content) {
    final bodyMeta = <String, String>{};
    final candidateLinks = <String>[];

    // 1. Try extracting JavaScript DATA object
    final jsonObjectStr = _extractJsonObjectAfter(content, _dataPattern);
    if (jsonObjectStr != null) {
      try {
        final decoded = jsonDecode(jsonObjectStr);
        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);
          final title = data['profileTitle'];
          if (title is String && title.trim().isNotEmpty) {
            bodyMeta['profile-title'] = title.trim();
          }

          final userinfo = data['userinfo'];
          if (userinfo is Map) {
            final upload = userinfo['upload'] ?? 0;
            final download = userinfo['download'] ?? 0;
            final total = userinfo['total'] ?? 0;
            final expire = userinfo['expire'] ?? 0;
            bodyMeta['subscription-userinfo'] =
                'upload=$upload; download=$download; total=$total; expire=$expire';
          }

          final links = data['links'];
          if (links is List) {
            for (final link in links) {
              if (link is String && link.trim().isNotEmpty) {
                candidateLinks.add(link.trim());
              }
            }
          }

          final configs = data['configs'];
          if (configs is List) {
            for (final cfg in configs) {
              if (cfg is Map) {
                final raw = cfg['raw'];
                if (raw is String && raw.trim().isNotEmpty) {
                  candidateLinks.add(raw.trim());
                }
              }
            }
          }
        }
      } catch (_) {
        // Ignored, fallback to regex scanning
      }
    }

    // 2. Scan entire HTML for any proxy links
    for (final match in _proxyLinkPattern.allMatches(content)) {
      final link = match.group(0);
      if (link != null && link.isNotEmpty) {
        candidateLinks.add(link);
      }
    }

    // 3. Fallback title from <title> tag
    if (!bodyMeta.containsKey('profile-title')) {
      final titleMatch = _htmlTitlePattern.firstMatch(content);
      if (titleMatch != null) {
        final title = _decodeHtmlEntities(titleMatch.group(1) ?? '').trim();
        if (title.isNotEmpty &&
            !title.toLowerCase().contains('404') &&
            !title.toLowerCase().contains('error') &&
            !title.toLowerCase().contains('not found')) {
          bodyMeta['profile-title'] = title;
        }
      }
    }

    // 4. Parse links and deduplicate
    final outbounds = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    for (final rawLink in candidateLinks) {
      final parsed = LinkParser.tryParse(rawLink);
      if (parsed == null) continue;

      final dedupKey = _dedupKey(parsed, rawLink);
      if (seenKeys.add(dedupKey)) {
        outbounds.add(parsed);
      }
    }

    return HtmlSubscriptionParseResult(
      outbounds: outbounds,
      bodyMeta: bodyMeta,
    );
  }

  static String _dedupKey(Map<String, dynamic> ob, String rawLink) {
    final type = ob['type'] ?? '';
    final server = ob['server'] ?? '';
    final port = ob['server_port'] ?? '';
    final name = ob['_name'] ?? '';
    if (server.toString().isNotEmpty) {
      return '$type:$server:$port:$name';
    }
    return rawLink;
  }

  static String? _extractJsonObjectAfter(String source, Pattern pattern) {
    final match = pattern.allMatches(source).firstOrNull;
    if (match == null) return null;
    final start = source.indexOf('{', match.end);
    if (start == -1) return null;

    var depth = 0;
    var inString = false;
    var quoteChar = '';
    var escape = false;

    for (var i = start; i < source.length; i++) {
      final char = source[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (char == r'\') {
        escape = true;
        continue;
      }
      if (char == '"' || char == "'") {
        if (!inString) {
          inString = true;
          quoteChar = char;
        } else if (char == quoteChar) {
          inString = false;
          quoteChar = '';
        }
        continue;
      }
      if (!inString) {
        if (char == '{') {
          depth++;
        } else if (char == '}') {
          depth--;
          if (depth == 0) {
            return source.substring(start, i + 1);
          }
        }
      }
    }
    return null;
  }

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
