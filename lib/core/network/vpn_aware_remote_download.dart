import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:meow_client/core/network/remote_download_timeout.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

enum RemoteDownloadRoute { outbound, app, underlying }

typedef RemoteDownloadRouteAttemptCallback =
    void Function(RemoteDownloadRoute route, bool isFallback);

@immutable
class RemoteDownloadResult {
  const RemoteDownloadResult({
    required this.statusCode,
    required this.headers,
    required this.finalUri,
    required this.route,
    required this.downloadedBytes,
    this.bytes,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Uri finalUri;
  final RemoteDownloadRoute route;
  final int downloadedBytes;
  final Uint8List? bytes;
}

class RemoteDownloadHttpException extends HttpException {
  RemoteDownloadHttpException(this.statusCode, {required Uri uri})
    : super('Remote server returned HTTP $statusCode', uri: uri);

  final int statusCode;
}

@visibleForTesting
List<RemoteDownloadRoute> remoteDownloadRouteOrderForTest({
  required bool android,
  required bool? vpnActive,
  bool supportsOutboundFetch = false,
  bool requiresAppFallback = false,
}) {
  if (!android) {
    return const <RemoteDownloadRoute>[RemoteDownloadRoute.app];
  }
  if (vpnActive == false) {
    // Etonify is not the VPN owner, but Android's default app route can still
    // be another VPN. Preserve that working route first; only bind explicitly
    // to Wi-Fi/LTE after the system route actually fails.
    return const <RemoteDownloadRoute>[
      RemoteDownloadRoute.app,
      RemoteDownloadRoute.underlying,
    ];
  }
  if (vpnActive == true && supportsOutboundFetch) {
    return <RemoteDownloadRoute>[
      RemoteDownloadRoute.outbound,
      if (requiresAppFallback) RemoteDownloadRoute.app,
      RemoteDownloadRoute.underlying,
    ];
  }
  // A null state is deliberately treated like an active VPN. If the runtime
  // status bridge is temporarily unavailable, preserving the tunnel-first
  // privacy policy is safer than silently bypassing it.
  return const <RemoteDownloadRoute>[
    RemoteDownloadRoute.app,
    RemoteDownloadRoute.underlying,
  ];
}

@visibleForTesting
Future<T> runRemoteDownloadRouteAttemptsForTest<T>({
  required List<RemoteDownloadRoute> routes,
  required Future<T> Function(RemoteDownloadRoute route) attempt,
  RemoteDownloadRouteAttemptCallback? onAttempt,
  void Function(RemoteDownloadRoute route, Object error)? onFailure,
}) async {
  if (routes.isEmpty) {
    throw StateError('No remote download routes are available');
  }
  Object? lastError;
  StackTrace? lastStackTrace;
  for (var index = 0; index < routes.length; index++) {
    final route = routes[index];
    onAttempt?.call(route, index > 0);
    try {
      return await attempt(route);
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      onFailure?.call(route, error);
    }
  }
  Error.throwWithStackTrace(lastError!, lastStackTrace!);
}

/// Downloads Etonify-owned remote data without pinning it to one Android path.
///
/// When the Etonify VPN is active, small bounded responses are fetched directly
/// through the selected core outbound. This avoids routing an app-owned HTTP
/// connection back through its own TUN. The regular Android app route remains a
/// fallback for responses larger than the RPC limit, followed by an explicitly
/// selected physical network. Every route fully terminates before the next one
/// starts, so late callbacks cannot overwrite a newer attempt's progress.
class VpnAwareRemoteDownloader {
  VpnAwareRemoteDownloader._();

  static final VpnAwareRemoteDownloader instance = VpnAwareRemoteDownloader._();

  static const responseStartTimeout = Duration(seconds: 5);
  static const _runtimeStatusTimeout = Duration(seconds: 1);
  static const _outboundFetchMaximumBytes = 3 * 1024 * 1024;
  static const _maxRedirects = 5;
  static const _redirectStatusCodes = <int>{301, 302, 303, 307, 308};

  int _temporaryFileGeneration = 0;
  Future<bool>? _outboundFetchCapability;

  Future<RemoteDownloadResult> fetchBytes({
    required Uri uri,
    required int maximumBytes,
    Map<String, String> headers = const <String, String>{},
    Set<int> acceptedStatusCodes = const <int>{HttpStatus.ok},
    void Function(int completed, int total)? onProgress,
    RemoteDownloadRouteAttemptCallback? onRouteAttempt,
  }) async {
    if (maximumBytes <= 0) {
      throw ArgumentError.value(maximumBytes, 'maximumBytes');
    }
    final routeState = await _resolveRouteState();
    final routes = remoteDownloadRouteOrderForTest(
      android: Platform.isAndroid,
      vpnActive: routeState.vpnActive,
      supportsOutboundFetch: routeState.supportsOutboundFetch,
      requiresAppFallback: maximumBytes > _outboundFetchMaximumBytes,
    );
    AppLogStore.info(
      'remote download',
      'host=${uri.host} vpnActive=${routeState.vpnActive} '
          'routeOrder=${routes.map((route) => route.name).join('->')}',
    );
    var attemptGeneration = 0;
    return runRemoteDownloadRouteAttemptsForTest<RemoteDownloadResult>(
      routes: routes,
      onAttempt: (route, isFallback) {
        attemptGeneration++;
        onProgress?.call(0, 0);
        onRouteAttempt?.call(route, isFallback);
      },
      attempt: (route) async {
        final generation = attemptGeneration;
        void reportProgress(int completed, int total) {
          if (generation == attemptGeneration) {
            onProgress?.call(completed, total);
          }
        }

        final result = switch (route) {
          RemoteDownloadRoute.outbound => await _fetchBytesViaOutbound(
            uri: uri,
            headers: headers,
            maximumBytes: maximumBytes,
            onProgress: reportProgress,
          ),
          RemoteDownloadRoute.app => await _fetchBytesViaApp(
            uri: uri,
            headers: headers,
            maximumBytes: maximumBytes,
            onProgress: reportProgress,
          ),
          RemoteDownloadRoute.underlying => await _fetchBytesViaUnderlying(
            uri: uri,
            headers: headers,
            maximumBytes: maximumBytes,
            onProgress: reportProgress,
          ),
        };
        if (!acceptedStatusCodes.contains(result.statusCode)) {
          throw RemoteDownloadHttpException(
            result.statusCode,
            uri: result.finalUri,
          );
        }
        return result;
      },
      onFailure: (route, error) {
        AppLogStore.warning(
          'remote download',
          'path=${route.name} failed host=${uri.host}: $error',
        );
      },
    );
  }

  Future<RemoteDownloadResult> downloadToFile({
    required Uri uri,
    required String destinationPath,
    required int maximumBytes,
    Map<String, String> headers = const <String, String>{},
    Set<int> acceptedStatusCodes = const <int>{HttpStatus.ok},
    void Function(int completed, int total)? onProgress,
    RemoteDownloadRouteAttemptCallback? onRouteAttempt,
  }) async {
    if (maximumBytes <= 0) {
      throw ArgumentError.value(maximumBytes, 'maximumBytes');
    }
    final destination = File(destinationPath);
    await destination.parent.create(recursive: true);
    final routeState = await _resolveRouteState();
    final routes = remoteDownloadRouteOrderForTest(
      android: Platform.isAndroid,
      vpnActive: routeState.vpnActive,
      supportsOutboundFetch: routeState.supportsOutboundFetch,
      requiresAppFallback: maximumBytes > _outboundFetchMaximumBytes,
    );
    AppLogStore.info(
      'remote download',
      'host=${uri.host} vpnActive=${routeState.vpnActive} '
          'routeOrder=${routes.map((route) => route.name).join('->')}',
    );
    var attemptGeneration = 0;
    return runRemoteDownloadRouteAttemptsForTest<RemoteDownloadResult>(
      routes: routes,
      onAttempt: (route, isFallback) {
        attemptGeneration++;
        onProgress?.call(0, 0);
        onRouteAttempt?.call(route, isFallback);
      },
      attempt: (route) async {
        final generation = attemptGeneration;
        void reportProgress(int completed, int total) {
          if (generation == attemptGeneration) {
            onProgress?.call(completed, total);
          }
        }

        final attemptFile = File(_nextAttemptPath(destination.path));
        try {
          final result = switch (route) {
            RemoteDownloadRoute.outbound => await _downloadFileViaOutbound(
              uri: uri,
              headers: headers,
              destination: attemptFile,
              maximumBytes: maximumBytes,
              onProgress: reportProgress,
            ),
            RemoteDownloadRoute.app => await _downloadFileViaApp(
              uri: uri,
              headers: headers,
              destination: attemptFile,
              maximumBytes: maximumBytes,
              onProgress: reportProgress,
            ),
            RemoteDownloadRoute.underlying => await _downloadFileViaUnderlying(
              uri: uri,
              headers: headers,
              destination: attemptFile,
              maximumBytes: maximumBytes,
              onProgress: reportProgress,
            ),
          };
          if (!acceptedStatusCodes.contains(result.statusCode)) {
            throw RemoteDownloadHttpException(
              result.statusCode,
              uri: result.finalUri,
            );
          }
          await _replaceDestination(attemptFile, destination);
          return result;
        } catch (_) {
          if (await attemptFile.exists()) {
            await attemptFile.delete();
          }
          rethrow;
        }
      },
      onFailure: (route, error) {
        AppLogStore.warning(
          'remote download',
          'path=${route.name} failed host=${uri.host}: $error',
        );
      },
    );
  }

  Future<({bool? vpnActive, bool supportsOutboundFetch})>
  _resolveRouteState() async {
    if (!Platform.isAndroid) {
      return (vpnActive: false, supportsOutboundFetch: false);
    }
    try {
      final status = await SingboxRuntime.instance.status().timeout(
        _runtimeStatusTimeout,
      );
      final vpnActive =
          status['running'] == true &&
          status['mode']?.toString().toLowerCase() == 'vpn';
      if (!vpnActive) {
        return (vpnActive: false, supportsOutboundFetch: false);
      }
      _outboundFetchCapability ??= SingboxRuntime.instance
          .getCoreCapabilities()
          .then((value) => value.supportsOutboundHttpFetch);
      final supported = await _outboundFetchCapability!.timeout(
        _runtimeStatusTimeout,
        onTimeout: () => false,
      );
      return (vpnActive: true, supportsOutboundFetch: supported);
    } catch (error) {
      AppLogStore.warning(
        'remote download',
        'runtime status unavailable before download: $error',
      );
      return (vpnActive: null, supportsOutboundFetch: false);
    }
  }

  Future<RemoteDownloadResult> _fetchBytesViaOutbound({
    required Uri uri,
    required Map<String, String> headers,
    required int maximumBytes,
    void Function(int completed, int total)? onProgress,
  }) async {
    final native = await SingboxRuntime.instance.fetchUrlViaOutbound(
      outboundTag: 'select',
      uri: uri,
      headers: headers,
      maxBytes: maximumBytes.clamp(1, _outboundFetchMaximumBytes).toInt(),
      timeout: responseStartTimeout,
    );
    final bodyValue = native['body'];
    final bytes = switch (bodyValue) {
      Uint8List value => value,
      List<int> value => Uint8List.fromList(value),
      _ => Uint8List(0),
    };
    onProgress?.call(bytes.length, bytes.length);
    final headersValue = native['headersJson']?.toString() ?? '';
    final decodedHeaders = headersValue.isEmpty
        ? const <String, Object?>{}
        : (jsonDecode(headersValue) as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          );
    return RemoteDownloadResult(
      statusCode: (native['statusCode'] as num?)?.toInt() ?? 0,
      headers: <String, String>{
        for (final entry in decodedHeaders.entries)
          entry.key.toLowerCase(): entry.value.toString(),
      },
      finalUri: Uri.tryParse(native['finalUrl']?.toString() ?? '') ?? uri,
      route: RemoteDownloadRoute.outbound,
      downloadedBytes: bytes.length,
      bytes: bytes,
    );
  }

  Future<RemoteDownloadResult> _downloadFileViaOutbound({
    required Uri uri,
    required Map<String, String> headers,
    required File destination,
    required int maximumBytes,
    void Function(int completed, int total)? onProgress,
  }) async {
    final result = await _fetchBytesViaOutbound(
      uri: uri,
      headers: headers,
      maximumBytes: maximumBytes,
      onProgress: onProgress,
    );
    await destination.writeAsBytes(result.bytes ?? Uint8List(0), flush: true);
    return RemoteDownloadResult(
      statusCode: result.statusCode,
      headers: result.headers,
      finalUri: result.finalUri,
      route: result.route,
      downloadedBytes: result.downloadedBytes,
    );
  }

  String _nextAttemptPath(String destinationPath) =>
      '$destinationPath.attempt-$pid-${DateTime.now().microsecondsSinceEpoch}-'
      '${_temporaryFileGeneration++}';

  static Future<void> _replaceDestination(
    File attempt,
    File destination,
  ) async {
    if (await destination.exists()) {
      await destination.delete();
    }
    try {
      await attempt.rename(destination.path);
    } on FileSystemException {
      await attempt.copy(destination.path);
      await attempt.delete();
    }
  }

  Future<RemoteDownloadResult> _fetchBytesViaApp({
    required Uri uri,
    required Map<String, String> headers,
    required int maximumBytes,
    void Function(int completed, int total)? onProgress,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = responseStartTimeout
      ..idleTimeout = remoteDownloadIdleTimeout;
    try {
      final opened = await _openAppResponse(client, uri, headers);
      final response = opened.response;
      final declaredLength = response.contentLength;
      if (declaredLength > maximumBytes) {
        throw RemoteDownloadTooLargeException(
          uri: uri,
          maximumBytes: maximumBytes,
        );
      }
      final builder = BytesBuilder(copy: false);
      var completed = 0;
      await for (final chunk in limitRemoteDownloadIdle(response, uri: uri)) {
        completed += chunk.length;
        if (completed > maximumBytes) {
          throw RemoteDownloadTooLargeException(
            uri: uri,
            maximumBytes: maximumBytes,
          );
        }
        builder.add(chunk);
        onProgress?.call(completed, declaredLength > 0 ? declaredLength : 0);
      }
      final bytes = builder.takeBytes();
      return RemoteDownloadResult(
        statusCode: response.statusCode,
        headers: _dartResponseHeaders(response),
        finalUri: opened.finalUri,
        route: RemoteDownloadRoute.app,
        downloadedBytes: bytes.length,
        bytes: bytes,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<RemoteDownloadResult> _downloadFileViaApp({
    required Uri uri,
    required Map<String, String> headers,
    required File destination,
    required int maximumBytes,
    void Function(int completed, int total)? onProgress,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = responseStartTimeout
      ..idleTimeout = remoteDownloadIdleTimeout;
    try {
      final opened = await _openAppResponse(client, uri, headers);
      final response = opened.response;
      final declaredLength = response.contentLength;
      if (declaredLength > maximumBytes) {
        throw RemoteDownloadTooLargeException(
          uri: uri,
          maximumBytes: maximumBytes,
        );
      }
      var completed = 0;
      final sink = destination.openWrite();
      try {
        await for (final chunk in limitRemoteDownloadIdle(response, uri: uri)) {
          completed += chunk.length;
          if (completed > maximumBytes) {
            throw RemoteDownloadTooLargeException(
              uri: uri,
              maximumBytes: maximumBytes,
            );
          }
          sink.add(chunk);
          onProgress?.call(completed, declaredLength > 0 ? declaredLength : 0);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      return RemoteDownloadResult(
        statusCode: response.statusCode,
        headers: _dartResponseHeaders(response),
        finalUri: opened.finalUri,
        route: RemoteDownloadRoute.app,
        downloadedBytes: completed,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<RemoteDownloadResult> _fetchBytesViaUnderlying({
    required Uri uri,
    required Map<String, String> headers,
    required int maximumBytes,
    void Function(int completed, int total)? onProgress,
  }) async {
    final temp = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'etonify-remote-$pid-${DateTime.now().microsecondsSinceEpoch}-'
      '${_temporaryFileGeneration++}.tmp',
    );
    try {
      final result = await _downloadFileViaUnderlying(
        uri: uri,
        headers: headers,
        destination: temp,
        maximumBytes: maximumBytes,
        onProgress: onProgress,
      );
      final bytes = await temp.exists()
          ? await temp.readAsBytes()
          : Uint8List(0);
      return RemoteDownloadResult(
        statusCode: result.statusCode,
        headers: result.headers,
        finalUri: result.finalUri,
        route: result.route,
        downloadedBytes: result.downloadedBytes,
        bytes: bytes,
      );
    } finally {
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }

  Future<RemoteDownloadResult> _downloadFileViaUnderlying({
    required Uri uri,
    required Map<String, String> headers,
    required File destination,
    required int maximumBytes,
    void Function(int completed, int total)? onProgress,
  }) async {
    final native = await SingboxRuntime.instance.downloadUrlOnUnderlyingNetwork(
      uri: uri,
      headers: headers,
      destinationPath: destination.path,
      maxBytes: maximumBytes,
      responseStartTimeout: responseStartTimeout,
      idleTimeout: remoteDownloadIdleTimeout,
    );
    final downloadedBytes = (native['downloadedBytes'] as num?)?.toInt() ?? 0;
    onProgress?.call(downloadedBytes, downloadedBytes);
    return RemoteDownloadResult(
      statusCode: (native['statusCode'] as num?)?.toInt() ?? 0,
      headers: <String, String>{
        for (final entry in (native['headers'] as Map? ?? const {}).entries)
          entry.key.toString().toLowerCase(): entry.value.toString(),
      },
      finalUri: Uri.tryParse(native['finalUrl']?.toString() ?? '') ?? uri,
      route: RemoteDownloadRoute.underlying,
      downloadedBytes: downloadedBytes,
    );
  }

  Future<({HttpClientResponse response, Uri finalUri})> _openAppResponse(
    HttpClient client,
    Uri initialUri,
    Map<String, String> initialHeaders,
  ) async {
    var uri = initialUri;
    var headers = Map<String, String>.from(initialHeaders);
    for (var redirectCount = 0; ; redirectCount++) {
      _validateRemoteUri(uri);
      final request = await awaitRemoteDownload(
        client.getUrl(uri),
        uri: uri,
        phase: RemoteDownloadTimeoutPhase.connecting,
        timeout: responseStartTimeout,
      );
      request.followRedirects = false;
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await awaitRemoteDownload(
        request.close(),
        uri: uri,
        phase: RemoteDownloadTimeoutPhase.awaitingResponse,
        timeout: responseStartTimeout,
      );
      if (!_redirectStatusCodes.contains(response.statusCode)) {
        return (response: response, finalUri: uri);
      }
      if (redirectCount >= _maxRedirects) {
        throw HttpException('Too many remote download redirects', uri: uri);
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || location.trim().isEmpty) {
        throw HttpException('Remote redirect has no Location header', uri: uri);
      }
      final redirectedUri = uri.resolve(location.trim());
      if (uri.scheme.toLowerCase() == 'https' &&
          redirectedUri.scheme.toLowerCase() == 'http') {
        throw HttpException(
          'HTTPS to HTTP remote redirect is not allowed',
          uri: redirectedUri,
        );
      }
      if (!_sameOrigin(uri, redirectedUri)) {
        headers = <String, String>{
          for (final entry in headers.entries)
            if (_safeCrossOriginHeader(entry.key)) entry.key: entry.value,
        };
      }
      await response.drain<void>();
      uri = redirectedUri;
    }
  }

  static Map<String, String> _dartResponseHeaders(HttpClientResponse response) {
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      headers[name.toLowerCase()] = values.join(', ');
    });
    return headers;
  }

  static void _validateRemoteUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
      throw HttpException('Only HTTP and HTTPS URLs are supported', uri: uri);
    }
    if (scheme == 'https' || _literalLoopbackHost(uri.host)) {
      return;
    }
    throw HttpException(
      'Remote downloads must use HTTPS outside the local device',
      uri: uri,
    );
  }

  static bool _literalLoopbackHost(String host) {
    final value = host.trim().toLowerCase();
    return value == 'localhost' || value == '127.0.0.1' || value == '::1';
  }

  static bool _safeCrossOriginHeader(String name) {
    final normalized = name.toLowerCase();
    return normalized == 'user-agent' || normalized == 'accept';
  }

  static bool _sameOrigin(Uri first, Uri second) {
    return first.scheme.toLowerCase() == second.scheme.toLowerCase() &&
        first.host.toLowerCase() == second.host.toLowerCase() &&
        first.port == second.port;
  }
}
