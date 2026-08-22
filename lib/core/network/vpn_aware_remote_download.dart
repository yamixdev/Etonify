import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:meow_client/core/network/remote_download_timeout.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

enum RemoteDownloadRoute { app, underlying }

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
}) => android
    ? const <RemoteDownloadRoute>[
        RemoteDownloadRoute.app,
        RemoteDownloadRoute.underlying,
      ]
    : const <RemoteDownloadRoute>[RemoteDownloadRoute.app];

@visibleForTesting
bool vpnRemoteRouteReadyForTest({
  required Map<String, dynamic> status,
  required bool interfaceAvailable,
  bool interfaceSettled = true,
}) {
  return status['running'] == true &&
      status['mode']?.toString().toLowerCase() == 'vpn' &&
      status['nativeRecoveryPending'] != true &&
      interfaceAvailable &&
      interfaceSettled;
}

@visibleForTesting
Future<T> runRemoteDownloadRouteAttemptsForTest<T>({
  required List<RemoteDownloadRoute> routes,
  required Future<T> Function(RemoteDownloadRoute route) attempt,
  void Function(RemoteDownloadRoute route, Object error)? onFailure,
}) async {
  if (routes.isEmpty) {
    throw StateError('No remote download routes are available');
  }
  Object? lastError;
  StackTrace? lastStackTrace;
  for (final route in routes) {
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
/// When the VPN is active the regular Dart HTTP client is tried first, so the
/// request follows the tunnel. Android's explicitly selected physical network
/// is used only after that path fails. A network handover gets a short settling
/// window, but the downloader never waits for user traffic: an idle VPN can be
/// perfectly healthy while its traffic counters remain at zero.
class VpnAwareRemoteDownloader {
  VpnAwareRemoteDownloader._();

  static final VpnAwareRemoteDownloader instance = VpnAwareRemoteDownloader._();

  static const vpnSettleTimeout = Duration(seconds: 5);
  static const responseStartTimeout = Duration(seconds: 5);
  static const _runtimeStatusTimeout = Duration(seconds: 1);
  static const _settlePollInterval = Duration(milliseconds: 250);
  static const _networkHandoverSettleWindow = Duration(milliseconds: 750);
  static const _maxRedirects = 5;
  static const _redirectStatusCodes = <int>{301, 302, 303, 307, 308};

  int _temporaryFileGeneration = 0;

  Future<RemoteDownloadResult> fetchBytes({
    required Uri uri,
    required int maximumBytes,
    Map<String, String> headers = const <String, String>{},
    Set<int> acceptedStatusCodes = const <int>{HttpStatus.ok},
    void Function(int completed, int total)? onProgress,
  }) async {
    if (maximumBytes <= 0) {
      throw ArgumentError.value(maximumBytes, 'maximumBytes');
    }
    await _waitForActiveVpnToSettle();
    final routes = remoteDownloadRouteOrderForTest(android: Platform.isAndroid);
    return runRemoteDownloadRouteAttemptsForTest<RemoteDownloadResult>(
      routes: routes,
      attempt: (route) async {
        final result = switch (route) {
          RemoteDownloadRoute.app => await _fetchBytesViaApp(
            uri: uri,
            headers: headers,
            maximumBytes: maximumBytes,
            onProgress: onProgress,
          ),
          RemoteDownloadRoute.underlying => await _fetchBytesViaUnderlying(
            uri: uri,
            headers: headers,
            maximumBytes: maximumBytes,
            onProgress: onProgress,
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
  }) async {
    if (maximumBytes <= 0) {
      throw ArgumentError.value(maximumBytes, 'maximumBytes');
    }
    final destination = File(destinationPath);
    await destination.parent.create(recursive: true);
    await _waitForActiveVpnToSettle();
    final routes = remoteDownloadRouteOrderForTest(android: Platform.isAndroid);
    try {
      return await runRemoteDownloadRouteAttemptsForTest<RemoteDownloadResult>(
        routes: routes,
        attempt: (route) async {
          if (await destination.exists()) {
            await destination.delete();
          }
          final result = switch (route) {
            RemoteDownloadRoute.app => await _downloadFileViaApp(
              uri: uri,
              headers: headers,
              destination: destination,
              maximumBytes: maximumBytes,
              onProgress: onProgress,
            ),
            RemoteDownloadRoute.underlying => await _downloadFileViaUnderlying(
              uri: uri,
              headers: headers,
              destination: destination,
              maximumBytes: maximumBytes,
              onProgress: onProgress,
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
    } catch (_) {
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }
  }

  Future<void> _waitForActiveVpnToSettle() async {
    if (!Platform.isAndroid) {
      return;
    }
    Map<String, dynamic> status;
    try {
      status = await SingboxRuntime.instance.status().timeout(
        _runtimeStatusTimeout,
      );
    } catch (error) {
      AppLogStore.warning(
        'remote download',
        'runtime status unavailable before download: $error',
      );
      return;
    }
    final vpnActive =
        status['running'] == true &&
        status['mode']?.toString().toLowerCase() == 'vpn';
    if (!vpnActive) {
      return;
    }

    final stopwatch = Stopwatch()..start();
    while (true) {
      var interfaceAvailable = false;
      var interfaceSettled = true;
      try {
        final interfaceState = await SingboxRuntime.instance
            .getNetworkInterfaceState()
            .timeout(_runtimeStatusTimeout);
        interfaceAvailable = interfaceState.available;
        final updatedAtMillis = interfaceState.updatedAtMillis;
        if (updatedAtMillis > 0) {
          final ageMillis =
              DateTime.now().millisecondsSinceEpoch - updatedAtMillis;
          interfaceSettled =
              ageMillis >= _networkHandoverSettleWindow.inMilliseconds;
        }
      } catch (_) {}
      if (vpnRemoteRouteReadyForTest(
        status: status,
        interfaceAvailable: interfaceAvailable,
        interfaceSettled: interfaceSettled,
      )) {
        return;
      }
      if (stopwatch.elapsed >= vpnSettleTimeout) {
        AppLogStore.warning(
          'remote download',
          'VPN settle wait elapsed; trying tunnel before physical fallback',
        );
        return;
      }
      await Future<void>.delayed(_settlePollInterval);
      try {
        status = await SingboxRuntime.instance.status().timeout(
          _runtimeStatusTimeout,
        );
      } catch (_) {
        return;
      }
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
