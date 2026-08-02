import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/network/remote_download_timeout.dart';

void main() {
  test('connection deadline reports a typed timeout reason', () async {
    final operation = awaitRemoteDownload(
      Completer<void>().future,
      uri: Uri.parse('https://updates.example.invalid/release.json'),
      phase: RemoteDownloadTimeoutPhase.connecting,
      timeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      operation,
      throwsA(
        isA<RemoteDownloadTimeoutException>()
            .having(
              (error) => error.phase,
              'phase',
              RemoteDownloadTimeoutPhase.connecting,
            )
            .having(
              (error) => error.timeout,
              'timeout',
              const Duration(milliseconds: 1),
            ),
      ),
    );
  });

  test('bounded reader accepts a response at the byte limit', () async {
    final uri = Uri.parse('https://updates.example.invalid/release.json');

    final bytes = await readRemoteDownloadBytes(
      Stream<List<int>>.fromIterable(const [
        [1, 2],
        [3, 4],
      ]),
      uri: uri,
      maximumBytes: 4,
    );

    expect(bytes, <int>[1, 2, 3, 4]);
  });

  test('bounded reader rejects a response above the byte limit', () async {
    final uri = Uri.parse('https://updates.example.invalid/release.json');

    await expectLater(
      readRemoteDownloadBytes(
        Stream<List<int>>.fromIterable(const [
          [1, 2],
          [3, 4, 5],
        ]),
        uri: uri,
        maximumBytes: 4,
      ),
      throwsA(
        isA<RemoteDownloadTooLargeException>()
            .having((error) => error.uri, 'uri', uri)
            .having((error) => error.maximumBytes, 'maximumBytes', 4),
      ),
    );
  });
}
