import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

import 'subscription_failure.dart';
import 'subscription_parser.dart';

/// Result returned by [SubscriptionFetcher.fetch].
class FetchResult {
  const FetchResult({
    required this.rawContent,
    required this.headerInfo,
    required this.parseResult,
    required this.url,
  });

  /// The raw response body.
  final String rawContent;

  /// Subscription metadata extracted from HTTP headers + body comment lines.
  final SubscriptionInfo headerInfo;

  /// Parsed outbound configs.
  final ParseResult parseResult;

  /// The original URL used for the request.
  final String url;
}

/// Fetches a subscription from a URL, parses HTTP response headers for
/// metadata (subscription-userinfo, profile-title, support-url, etc.),
/// and then parses the response body into sing-box outbound configs.
class SubscriptionFetcher {
  SubscriptionFetcher._();

  static const fallbackAppVersion = '0.2.3';
  static String _appVersion = fallbackAppVersion;
  static String get defaultUserAgent => 'Etonify/$_appVersion';
  static const _maxSubscriptionResponseBytes = 16 * 1024 * 1024;
  static const _maxRedirects = 5;
  static const _redirectStatusCodes = <int>{301, 302, 303, 307, 308};

  static void configureAppVersion(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^v'), '');
    _appVersion = normalized.isEmpty ? fallbackAppVersion : normalized;
  }

  /// Fetches and parses a subscription from [url].
  ///
  /// Throws [HttpException] or [SocketException] on network errors.
  static Future<FetchResult> fetch(
    String url, {
    SubscriptionInfo? requestInfo,
    Duration? operationTimeout,
  }) async {
    final uri = parseRequestUri(url);
    _logFetchStart(uri, requestInfo);

    try {
      final headers = await _requestHeaders(requestInfo);
      _validateRequestSecurity(uri);
      if (Platform.isAndroid) {
        try {
          final native = await SingboxRuntime.instance
              .fetchUrlOnUnderlyingNetwork(
                uri: uri,
                headers: headers,
                maxBytes: _maxSubscriptionResponseBytes,
                timeout: operationTimeout ?? const Duration(seconds: 20),
              );
          final statusCode =
              int.tryParse(native['statusCode']?.toString() ?? '') ?? 0;
          if (statusCode != HttpStatus.ok) {
            throw SubscriptionHttpStatusException(statusCode, uri: uri);
          }
          final rawContent = native['body']?.toString() ?? '';
          final responseHeaders = <String, String>{
            for (final entry in (native['headers'] as Map? ?? const {}).entries)
              entry.key.toString().toLowerCase(): entry.value.toString(),
          };
          AppLogStore.info(
            'subscription',
            'fetch complete path=underlying_network bytes=${utf8.encode(rawContent).length}',
          );
          return await _buildResult(
            url: url,
            rawContent: rawContent,
            headerValue: (name) => responseHeaders[name.toLowerCase()],
          );
        } on SubscriptionContentException {
          rethrow;
        } on HttpException {
          rethrow;
        } catch (error) {
          AppLogStore.warning(
            'subscription',
            'underlying-network fetch unavailable, falling back to app route: $error',
          );
        }
      }

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      Timer? operationTimeoutTimer;
      var operationTimedOut = false;
      if (operationTimeout != null && operationTimeout > Duration.zero) {
        operationTimeoutTimer = Timer(operationTimeout, () {
          operationTimedOut = true;
          client.close(force: true);
        });
      }
      try {
        final response = await _openWithSafeRedirects(client, uri, headers);

        if (response.statusCode != 200) {
          throw SubscriptionHttpStatusException(response.statusCode, uri: uri);
        }

        // Read body
        final rawContent = await _readUtf8Body(response);
        return await _buildResult(
          url: url,
          rawContent: rawContent,
          headerValue: (name) {
            final values = response.headers[name];
            return values == null || values.isEmpty ? null : values.first;
          },
        );
      } catch (error) {
        if (operationTimedOut) {
          throw TimeoutException('Subscription request timed out');
        }
        rethrow;
      } finally {
        operationTimeoutTimer?.cancel();
        client.close(force: true);
      }
    } catch (error, stackTrace) {
      await _logFetchFailure(uri: uri, error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<Map<String, String>> _requestHeaders(
    SubscriptionInfo? requestInfo,
  ) async {
    final customHeaders = _parseCustomHeaders(requestInfo?.customRequestHeader);
    final headers = <String, String>{
      'User-Agent': requestInfo?.customUserAgent?.trim().isNotEmpty == true
          ? requestInfo!.customUserAgent!.trim()
          : defaultUserAgent,
      'Accept': '*/*',
      ...customHeaders,
    };
    if (requestInfo?.requireHwid == true) {
      final hwidHeaders = await _resolveHwidHeaders(requestInfo);
      for (final entry in hwidHeaders.entries) {
        if (!_hasHeader(customHeaders, entry.key)) {
          headers[entry.key] = entry.value;
        }
      }
    }
    return headers;
  }

  static Future<HttpClientResponse> _openWithSafeRedirects(
    HttpClient client,
    Uri initialUri,
    Map<String, String> initialHeaders,
  ) async {
    var uri = initialUri;
    var headers = Map<String, String>.from(initialHeaders);
    for (var redirects = 0; ; redirects++) {
      _validateRequestSecurity(uri);
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close();
      if (!_redirectStatusCodes.contains(response.statusCode)) {
        return response;
      }
      if (redirects >= _maxRedirects) {
        throw HttpException('Too many subscription redirects', uri: uri);
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || location.trim().isEmpty) {
        throw HttpException(
          'Subscription redirect has no Location header',
          uri: uri,
        );
      }
      final redirectedUri = uri.resolve(location.trim());
      if (uri.scheme.toLowerCase() == 'https' &&
          redirectedUri.scheme.toLowerCase() == 'http') {
        throw HttpException(
          'HTTPS to HTTP subscription redirect is not allowed',
          uri: redirectedUri,
        );
      }
      if (!_sameOrigin(uri, redirectedUri)) {
        headers = _headersForCrossOriginRedirect(headers);
      }
      await response.listen((_) {}).cancel();
      uri = redirectedUri;
    }
  }

  static void _validateRequestSecurity(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
      throw HttpException('Only HTTP and HTTPS URLs are supported', uri: uri);
    }
    if (scheme == 'https') {
      return;
    }
    if (!_isLiteralLoopbackHost(uri.host)) {
      throw HttpException(
        'Subscription URLs must use HTTPS. Plain HTTP is allowed only for '
        'localhost, 127.0.0.1, or [::1].',
        uri: uri,
      );
    }
  }

  static bool _isLiteralLoopbackHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }

  static Map<String, String> _headersForCrossOriginRedirect(
    Map<String, String> headers,
  ) => <String, String>{
    for (final entry in headers.entries)
      if (entry.key.toLowerCase() == 'user-agent' ||
          entry.key.toLowerCase() == 'accept')
        entry.key: entry.value,
  };

  static bool _sameOrigin(Uri first, Uri second) =>
      first.scheme.toLowerCase() == second.scheme.toLowerCase() &&
      first.host.toLowerCase() == second.host.toLowerCase() &&
      first.port == second.port;

  @visibleForTesting
  static void validateRequestSecurityForTest(Uri uri) =>
      _validateRequestSecurity(uri);

  @visibleForTesting
  static Map<String, String> headersForCrossOriginRedirectForTest(
    Map<String, String> headers,
  ) => _headersForCrossOriginRedirect(headers);

  static Future<FetchResult> _buildResult({
    required String url,
    required String rawContent,
    required String? Function(String name) headerValue,
  }) async {
    _validateResponseContent(rawContent);
    final headerInfo = _parseHeaderValues(headerValue);
    final parseResult = await SubscriptionParser.parseInBackground(rawContent);
    return FetchResult(
      rawContent: rawContent,
      headerInfo: _mergeBodyMeta(headerInfo, parseResult.bodyMeta),
      parseResult: parseResult,
      url: url,
    );
  }

  static void _validateResponseContent(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) {
      throw const SubscriptionContentException(
        SubscriptionContentFailureKind.emptyResponse,
      );
    }
    final prefix = trimmed
        .substring(0, min(trimmed.length, 1024))
        .toLowerCase();
    final looksLikeHtml =
        prefix.startsWith('<!doctype html') ||
        prefix.startsWith('<html') ||
        (prefix.contains('<html') && prefix.contains('<body'));
    if (looksLikeHtml) {
      throw const SubscriptionContentException(
        SubscriptionContentFailureKind.htmlResponse,
      );
    }
  }

  static Uri parseRequestUri(String url) {
    final trimmed = url.trim();
    try {
      final parsed = Uri.parse(trimmed);
      final scheme = parsed.scheme.toLowerCase();
      if ((scheme == 'http' || scheme == 'https') &&
          (parsed.host.contains('%') || !_isAscii(parsed.host))) {
        return _parseUnicodeHttpUri(trimmed);
      }
      return parsed;
    } on FormatException {
      return _parseUnicodeHttpUri(trimmed);
    }
  }

  @visibleForTesting
  static Uri parseRequestUriForTest(String url) {
    return parseRequestUri(url);
  }

  static void _logFetchStart(Uri uri, SubscriptionInfo? requestInfo) {
    final port = uri.hasPort ? uri.port : _defaultPort(uri);
    AppLogStore.info(
      'subscription',
      'fetch start host=${uri.host} port=$port scheme=${uri.scheme} '
          'path=${uri.path.isEmpty ? "/" : uri.path} '
          'requireHwid=${requestInfo?.requireHwid == true} '
          'customHeaders=${_parseCustomHeaders(requestInfo?.customRequestHeader).length}',
    );
  }

  static Future<void> _logFetchFailure({
    required Uri uri,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    final port = uri.hasPort ? uri.port : _defaultPort(uri);
    AppLogStore.error(
      'subscription',
      'fetch failed host=${uri.host} port=$port scheme=${uri.scheme} '
          'error=${error.runtimeType}: $error',
    );
  }

  static Future<String> _readUtf8Body(HttpClientResponse response) async {
    final declaredLength = response.contentLength;
    if (declaredLength > _maxSubscriptionResponseBytes) {
      throw const SubscriptionContentException(
        SubscriptionContentFailureKind.responseTooLarge,
      );
    }
    final builder = BytesBuilder(copy: false);
    var totalBytes = 0;
    await for (final chunk in response) {
      totalBytes += chunk.length;
      if (totalBytes > _maxSubscriptionResponseBytes) {
        throw const SubscriptionContentException(
          SubscriptionContentFailureKind.responseTooLarge,
        );
      }
      builder.add(chunk);
    }
    try {
      return utf8.decode(builder.takeBytes());
    } on FormatException {
      throw const SubscriptionContentException(
        SubscriptionContentFailureKind.invalidContent,
      );
    }
  }

  @visibleForTesting
  static String decodeResponseUtf8ForTest(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const SubscriptionContentException(
        SubscriptionContentFailureKind.invalidContent,
      );
    }
  }

  static int _defaultPort(Uri uri) {
    return switch (uri.scheme.toLowerCase()) {
      'https' => 443,
      'http' => 80,
      _ => 0,
    };
  }

  static Uri _parseUnicodeHttpUri(String rawUrl) {
    final match = RegExp(
      r'^([A-Za-z][A-Za-z0-9+.\-]*):\/\/([^\/?#]*)([^?#]*)(?:\?([^#]*))?(?:#(.*))?$',
    ).firstMatch(rawUrl);
    if (match == null) {
      throw FormatException('Invalid URL', rawUrl);
    }

    final scheme = match.group(1) ?? '';
    if (scheme != 'http' && scheme != 'https') {
      throw FormatException('Unsupported URL scheme', rawUrl);
    }

    final authority = match.group(2) ?? '';
    final path = match.group(3) ?? '';
    final query = match.group(4);
    final fragment = match.group(5);

    String userInfo = '';
    String hostPort = authority;
    final atIndex = authority.lastIndexOf('@');
    if (atIndex >= 0) {
      userInfo = authority.substring(0, atIndex);
      hostPort = authority.substring(atIndex + 1);
    }

    String host = hostPort;
    int? port;
    if (hostPort.startsWith('[')) {
      final closingIndex = hostPort.indexOf(']');
      if (closingIndex <= 0) {
        throw FormatException('Invalid IPv6 host', rawUrl);
      }
      host = hostPort.substring(1, closingIndex);
      final portPart = hostPort.substring(closingIndex + 1);
      if (portPart.isNotEmpty) {
        if (!portPart.startsWith(':')) {
          throw FormatException('Invalid port', rawUrl);
        }
        port = int.tryParse(portPart.substring(1));
        if (port == null) {
          throw FormatException('Invalid port', rawUrl);
        }
      }
    } else {
      final colonIndex = hostPort.lastIndexOf(':');
      if (colonIndex > 0 && hostPort.indexOf(':') == colonIndex) {
        final portCandidate = hostPort.substring(colonIndex + 1);
        final parsedPort = int.tryParse(portCandidate);
        if (parsedPort != null) {
          host = hostPort.substring(0, colonIndex);
          port = parsedPort;
        }
      }
    }

    final normalizedHost = _normalizeHostToAscii(host);
    return Uri(
      scheme: scheme,
      userInfo: userInfo.isEmpty ? null : userInfo,
      host: normalizedHost,
      port: port,
      path: path,
      query: query,
      fragment: fragment,
    );
  }

  static String _normalizeHostToAscii(String host) {
    if (host.isEmpty || _isAscii(host) || host.contains(':')) {
      return host;
    }

    final normalized = host
        .replaceAll('\u3002', '.')
        .replaceAll('\uFF0E', '.')
        .replaceAll('\uFF61', '.');
    return normalized
        .split('.')
        .map(
          (label) => label.isEmpty || _isAscii(label)
              ? label
              : 'xn--${_punycodeEncode(label)}',
        )
        .join('.');
  }

  static bool _isAscii(String value) {
    return value.codeUnits.every((unit) => unit <= 0x7F);
  }

  static String _punycodeEncode(String input) {
    const base = 36;
    const tMin = 1;
    const tMax = 26;
    const initialBias = 72;
    const initialN = 128;

    final inputCodePoints = input.runes.toList(growable: false);
    final output = StringBuffer();

    var n = initialN;
    var delta = 0;
    var bias = initialBias;

    var basicCount = 0;
    for (final codePoint in inputCodePoints) {
      if (codePoint < 0x80) {
        output.writeCharCode(codePoint);
        basicCount++;
      }
    }

    var handledCount = basicCount;
    if (basicCount > 0) {
      output.write('-');
    }

    while (handledCount < inputCodePoints.length) {
      var nextCodePoint = 0x10FFFF;
      for (final codePoint in inputCodePoints) {
        if (codePoint >= n && codePoint < nextCodePoint) {
          nextCodePoint = codePoint;
        }
      }

      delta += (nextCodePoint - n) * (handledCount + 1);
      n = nextCodePoint;

      for (final codePoint in inputCodePoints) {
        if (codePoint < n) {
          delta++;
        }
        if (codePoint != n) {
          continue;
        }

        var q = delta;
        for (var k = base; ; k += base) {
          final t = switch (true) {
            _ when k <= bias => tMin,
            _ when k >= bias + tMax => tMax,
            _ => k - bias,
          };
          if (q < t) {
            break;
          }
          output.writeCharCode(
            _punycodeDigitToCodePoint(t + ((q - t) % (base - t))),
          );
          q = (q - t) ~/ (base - t);
        }

        output.writeCharCode(_punycodeDigitToCodePoint(q));
        bias = _adaptPunycodeDelta(
          delta,
          handledCount + 1,
          handledCount == basicCount,
        );
        delta = 0;
        handledCount++;
      }

      delta++;
      n++;
    }

    return output.toString();
  }

  static int _adaptPunycodeDelta(int delta, int numPoints, bool firstTime) {
    const base = 36;
    const tMin = 1;
    const tMax = 26;
    const skew = 38;
    const damp = 700;

    delta = firstTime ? delta ~/ damp : delta ~/ 2;
    delta += delta ~/ numPoints;

    var k = 0;
    while (delta > ((base - tMin) * tMax) ~/ 2) {
      delta ~/= base - tMin;
      k += base;
    }

    return k + (((base - tMin + 1) * delta) ~/ (delta + skew));
  }

  static int _punycodeDigitToCodePoint(int digit) {
    return digit < 26 ? 0x61 + digit : 0x30 + (digit - 26);
  }

  // ─────────────────── Header parsing ───────────────────

  static Map<String, String> _parseCustomHeaders(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const {};
    }
    final result = <String, String>{};
    for (final line in const LineSplitter().convert(rawValue)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final separatorIndex = trimmed.indexOf(':');
      if (separatorIndex <= 0) {
        continue;
      }
      final name = trimmed.substring(0, separatorIndex).trim();
      final value = trimmed.substring(separatorIndex + 1).trim();
      if (name.isEmpty || value.isEmpty) {
        continue;
      }
      result[name] = value;
    }
    return result;
  }

  static bool _hasHeader(Map<String, String> headers, String name) {
    return headers.keys.any((key) => key.toLowerCase() == name.toLowerCase());
  }

  static Future<Map<String, String>> _resolveHwidHeaders(
    SubscriptionInfo? requestInfo,
  ) async {
    try {
      final deviceInfo = await SingboxRuntime.instance
          .getSubscriptionRequestDeviceInfo();
      final locale = (deviceInfo['locale'] as String?)?.trim() ?? '';
      final os = (deviceInfo['os'] as String?)?.trim() ?? 'Android';
      final osVersion = (deviceInfo['osVersion'] as String?)?.trim() ?? '';
      final model = (deviceInfo['model'] as String?)?.trim() ?? '';
      final resolvedHwid =
          (requestInfo?.customHwid?.trim().isNotEmpty == true
              ? requestInfo!.customHwid!.trim()
              : (deviceInfo['androidId'] as String?)?.trim()) ??
          '';
      return {
        if (locale.isNotEmpty) 'X-Device-Locale': locale,
        if (resolvedHwid.isNotEmpty) 'X-HWID': resolvedHwid,
        'X-Device-Os': os,
        if (osVersion.isNotEmpty) 'X-Ver-Os': osVersion,
        if (model.isNotEmpty) 'X-Device-Model': model,
      };
    } catch (_) {
      return {
        if (requestInfo?.customHwid?.trim().isNotEmpty == true)
          'X-HWID': requestInfo!.customHwid!.trim(),
        'X-Device-Os': 'Android',
      };
    }
  }

  /// Extracts subscription metadata from HTTP response headers.
  static SubscriptionInfo _parseHeaderValues(
    String? Function(String name) headerValue,
  ) {
    String? title;
    int? upload;
    int? download;
    int? total;
    int? expire;
    String? happCryptoLink;
    String? supportUrl;
    String? webPageUrl;
    String? newUrl;
    int? updateIntervalHours;
    String? perAppProxyMode;
    List<String>? perAppProxyList;

    // profile-title (can be plain text or base64)
    final rawTitle = headerValue('profile-title');
    if (rawTitle != null) {
      title = _normalizeTitle(_tryBase64DecodeOrPlain(rawTitle));
    }

    // content-disposition filename as fallback title
    if (title == null) {
      final cd = headerValue('content-disposition');
      if (cd != null) {
        title = _titleFromContentDisposition(cd);
      }
    }

    // subscription-userinfo
    final userInfo = headerValue('subscription-userinfo');
    if (userInfo != null) {
      final parts = _parseKeyValuePairs(userInfo);
      upload = int.tryParse(parts['upload'] ?? '');
      download = int.tryParse(parts['download'] ?? '');
      total = int.tryParse(parts['total'] ?? '');
      expire = int.tryParse(parts['expire'] ?? '');
    }

    // support-url
    happCryptoLink = headerValue('happ-crypto-link');

    // support-url
    supportUrl = headerValue('support-url');

    // profile-web-page-url
    webPageUrl = headerValue('profile-web-page-url');

    // new-url
    newUrl = headerValue('new-url');

    // profile-update-interval
    final updateStr = headerValue('profile-update-interval');
    if (updateStr != null) {
      updateIntervalHours = int.tryParse(updateStr);
    }

    // per-app-proxy-mode / per-app-proxy-list
    perAppProxyMode = headerValue('per-app-proxy-mode');
    final proxyListStr = headerValue('per-app-proxy-list');
    if (proxyListStr != null && proxyListStr.isNotEmpty) {
      perAppProxyList = proxyListStr.split(',').map((s) => s.trim()).toList();
    }

    return SubscriptionInfo(
      title: title,
      upload: upload,
      download: download,
      total: total,
      expire: expire,
      happCryptoLink: happCryptoLink,
      supportUrl: supportUrl,
      webPageUrl: webPageUrl,
      newUrl: newUrl,
      updateIntervalHours: updateIntervalHours,
      perAppProxyMode: perAppProxyMode,
      perAppProxyList: perAppProxyList,
    );
  }

  /// Merges body comment metadata into header info.
  /// Header values take priority; body values fill in gaps.
  static SubscriptionInfo _mergeBodyMeta(
    SubscriptionInfo header,
    Map<String, String> bodyMeta,
  ) {
    if (bodyMeta.isEmpty) return header;

    String? title = header.title;
    int? upload = header.upload;
    int? download = header.download;
    int? total = header.total;
    int? expire = header.expire;
    String? happCryptoLink = header.happCryptoLink;
    String? supportUrl = header.supportUrl;
    String? webPageUrl = header.webPageUrl;
    String? newUrl = header.newUrl;
    int? updateIntervalHours = header.updateIntervalHours;
    String? perAppProxyMode = header.perAppProxyMode;
    List<String>? perAppProxyList = header.perAppProxyList;

    title ??= _normalizeTitle(
      _tryBase64DecodeOrPlain(bodyMeta['profile-title'] ?? ''),
    );

    if (upload == null || download == null || total == null || expire == null) {
      final userInfoStr = bodyMeta['subscription-userinfo'];
      if (userInfoStr != null) {
        final parts = _parseKeyValuePairs(userInfoStr);
        upload ??= int.tryParse(parts['upload'] ?? '');
        download ??= int.tryParse(parts['download'] ?? '');
        total ??= int.tryParse(parts['total'] ?? '');
        expire ??= int.tryParse(parts['expire'] ?? '');
      }
    }

    happCryptoLink ??= bodyMeta['happ-crypto-link'];
    supportUrl ??= bodyMeta['support-url'];
    webPageUrl ??= bodyMeta['profile-web-page-url'];
    newUrl ??= bodyMeta['new-url'];

    if (updateIntervalHours == null) {
      final s = bodyMeta['profile-update-interval'];
      if (s != null) updateIntervalHours = int.tryParse(s);
    }

    perAppProxyMode ??= bodyMeta['per-app-proxy-mode'];
    if (perAppProxyList == null) {
      final s = bodyMeta['per-app-proxy-list'];
      if (s != null && s.isNotEmpty) {
        perAppProxyList = s.split(',').map((e) => e.trim()).toList();
      }
    }

    return SubscriptionInfo(
      title: title,
      upload: upload,
      download: download,
      total: total,
      expire: expire,
      happCryptoLink: happCryptoLink,
      supportUrl: supportUrl,
      webPageUrl: webPageUrl,
      newUrl: newUrl,
      updateIntervalHours: updateIntervalHours,
      perAppProxyMode: perAppProxyMode,
      perAppProxyList: perAppProxyList,
    );
  }

  // ─────────────────── Utility ───────────────────

  /// Gets the first value for a header (case-insensitive).
  static String? _titleFromContentDisposition(String value) {
    final encodedMatch = RegExp(
      r'''filename\*\s*=\s*UTF-8''([^;]+)''',
      caseSensitive: false,
    ).firstMatch(value);
    if (encodedMatch != null) {
      return _normalizeTitle(Uri.decodeComponent(encodedMatch.group(1)!));
    }

    final plainMatch = RegExp(
      r'filename\s*=\s*"([^"]+)"|filename\s*=\s*([^";\s]+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (plainMatch != null) {
      return _normalizeTitle(plainMatch.group(1) ?? plainMatch.group(2) ?? '');
    }

    return null;
  }

  /// Parses key=value pairs separated by `;` or `&`.
  static Map<String, String> _parseKeyValuePairs(String input) {
    final result = <String, String>{};
    final parts = input.split(RegExp(r'[;&]'));
    for (final part in parts) {
      final trimmed = part.trim();
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx > 0) {
        final key = trimmed.substring(0, eqIdx).trim().toLowerCase();
        final value = trimmed.substring(eqIdx + 1).trim();
        result[key] = value;
      }
    }
    return result;
  }

  /// Tries to base64-decode [input]; returns plain text on failure.
  static String _tryBase64DecodeOrPlain(String input) {
    try {
      var source = input.trim();
      if (source.toLowerCase().startsWith('base64:')) {
        source = source.substring(7).trim();
      }

      String s = source.replaceAll('-', '+').replaceAll('_', '/');
      switch (s.length % 4) {
        case 2:
          s += '==';
        case 3:
          s += '=';
      }
      return utf8.decode(base64Decode(s));
    } catch (_) {
      return input;
    }
  }

  static String? _normalizeTitle(String input) {
    var normalized = input.trim().replaceAll(RegExp(r'^"+|"+$'), '');
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length > 25) {
      normalized = normalized.substring(0, 25);
    }
    return normalized;
  }

  /// Generates a random subscription ID.
  static String generateId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
