import 'dart:async';
import 'dart:typed_data';

/// A short, user-visible deadline for remote metadata and rule downloads.
///
/// This is intentionally an *idle* deadline: a large APK or rule archive may
/// take longer than seven seconds overall, but a server that does not connect,
/// send response headers, or transfer another byte is treated as unavailable.
const remoteDownloadIdleTimeout = Duration(seconds: 7);

enum RemoteDownloadTimeoutPhase { connecting, awaitingResponse, receiving }

class RemoteDownloadTimeoutException extends TimeoutException {
  RemoteDownloadTimeoutException({
    required this.uri,
    required this.phase,
    this.timeout = remoteDownloadIdleTimeout,
  }) : super('Remote download timed out while ${phase.name}', timeout);

  final Uri uri;
  final RemoteDownloadTimeoutPhase phase;
  final Duration timeout;

  @override
  String toString() {
    final seconds = timeout.inSeconds;
    return switch (phase) {
      RemoteDownloadTimeoutPhase.connecting =>
        'Download failed: the server did not accept a connection within $seconds seconds.',
      RemoteDownloadTimeoutPhase.awaitingResponse =>
        'Download failed: the server did not send a response within $seconds seconds.',
      RemoteDownloadTimeoutPhase.receiving =>
        'Download failed: transfer stopped for $seconds seconds.',
    };
  }
}

class RemoteDownloadTooLargeException implements Exception {
  const RemoteDownloadTooLargeException({
    required this.uri,
    required this.maximumBytes,
  });

  final Uri uri;
  final int maximumBytes;

  @override
  String toString() =>
      'Download failed: the response exceeded the $maximumBytes byte limit.';
}

Future<T> awaitRemoteDownload<T>(
  Future<T> future, {
  required Uri uri,
  required RemoteDownloadTimeoutPhase phase,
  Duration timeout = remoteDownloadIdleTimeout,
}) async {
  try {
    return await future.timeout(timeout);
  } on TimeoutException {
    throw RemoteDownloadTimeoutException(
      uri: uri,
      phase: phase,
      timeout: timeout,
    );
  }
}

Stream<T> limitRemoteDownloadIdle<T>(
  Stream<T> source, {
  required Uri uri,
  Duration timeout = remoteDownloadIdleTimeout,
}) {
  return source.timeout(
    timeout,
    onTimeout: (sink) {
      sink.addError(
        RemoteDownloadTimeoutException(
          uri: uri,
          phase: RemoteDownloadTimeoutPhase.receiving,
          timeout: timeout,
        ),
      );
      sink.close();
    },
  );
}

Future<Uint8List> readRemoteDownloadBytes(
  Stream<List<int>> source, {
  required Uri uri,
  required int maximumBytes,
  Duration timeout = remoteDownloadIdleTimeout,
}) async {
  if (maximumBytes < 0) {
    throw ArgumentError.value(maximumBytes, 'maximumBytes');
  }
  final bytes = BytesBuilder(copy: false);
  var receivedBytes = 0;
  await for (final chunk in limitRemoteDownloadIdle(
    source,
    uri: uri,
    timeout: timeout,
  )) {
    receivedBytes += chunk.length;
    if (receivedBytes > maximumBytes) {
      throw RemoteDownloadTooLargeException(
        uri: uri,
        maximumBytes: maximumBytes,
      );
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
