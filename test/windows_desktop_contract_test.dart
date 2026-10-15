import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';
import 'package:meow_client/platform/windows/desktop_transport.dart';
import 'support/desktop_fakes.dart';

Uint8List rawFrame(List<int> body) {
  final bytes = Uint8List(body.length + 4);
  ByteData.sublistView(bytes).setUint32(0, body.length, Endian.little);
  bytes.setRange(4, bytes.length, body);
  return bytes;
}

void main() {
  test('shared Go corpus is byte-identical and supports every fragmentation', () {
    final corpus =
        jsonDecode(
              File(
                'etonify-core/experimental/etonifydesktop/fixtures/envelopes.json',
              ).readAsStringSync(),
            )
            as List;
    for (final item in corpus.cast<Map<String, dynamic>>()) {
      final hex = item['frameHex'] as String;
      final bytes = Uint8List.fromList([
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ]);
      final expected = item['envelope'] as Map<String, dynamic>;
      expect(
        DesktopFrameCodec.encode(RuntimeEnvelope.fromMap(expected)),
        bytes,
      );
      for (var split = 0; split <= bytes.length; split++) {
        final decoder = DesktopFrameDecoder();
        final decoded = [
          ...decoder.add(Uint8List.sublistView(bytes, 0, split)),
          ...decoder.add(Uint8List.sublistView(bytes, split)),
        ];
        decoder.finish();
        expect(decoded.single.toMap(), expected);
      }
    }
  });

  test('invalid envelopes reject version, kind and non-int64 generations', () {
    final valid = {
      'version': 1,
      'kind': 'request',
      'id': '1',
      'sessionId': 's',
      'configGeneration': 0,
      'networkGeneration': 0,
      'method': 'start',
      'payload': null,
    };
    for (final entry in [
      const MapEntry('version', 2),
      const MapEntry('version', 1.0),
      const MapEntry('configGeneration', -1),
      const MapEntry('configGeneration', 0.5),
      const MapEntry('networkGeneration', '0'),
      const MapEntry('kind', 'unknown'),
      const MapEntry('sessionId', null),
    ]) {
      expect(
        () => RuntimeEnvelope.fromMap({...valid, entry.key: entry.value}),
        throwsFormatException,
      );
    }
    expect(
      () => RuntimeEnvelope.fromMap({
        ...valid,
        'error': {'code': 'bad', 'message': 'bad'},
      }),
      throwsFormatException,
    );
    final error = {
      ...valid,
      'kind': 'response',
      'error': {'code': 'bad', 'message': 'bad'},
    }..remove('payload');
    expect(RuntimeEnvelope.fromMap(error).toMap(), error);
    expect(
      () => RuntimeEnvelope.fromMap({...error, 'payload': null}),
      throwsFormatException,
    );
  });

  test(
    'invalid UTF-8, JSON, oversized and truncated frames poison decoder',
    () {
      for (final bytes in [
        rawFrame([0xff]),
        rawFrame(utf8.encode('{')),
        Uint8List.fromList([1, 0, 0, 1]),
        rawFrame([]),
      ]) {
        final decoder = DesktopFrameDecoder();
        expect(() => decoder.add(bytes), throwsFormatException);
        expect(
          () => decoder.add(rawFrame(utf8.encode('{}'))),
          throwsFormatException,
        );
      }
      for (final bytes in [
        Uint8List.fromList([1]),
        Uint8List.fromList([4, 0, 0, 0, 123]),
      ]) {
        final decoder = DesktopFrameDecoder()..add(bytes);
        expect(decoder.finish, throwsFormatException);
        expect(() => decoder.add(Uint8List(0)), throwsFormatException);
      }
    },
  );

  test('codec is stateless across repeated response identifiers', () {
    final envelope = RuntimeEnvelope.fromMap({
      'version': 1,
      'kind': 'response',
      'id': 'same',
      'sessionId': 's',
      'configGeneration': 0,
      'networkGeneration': 0,
      'method': 'status',
      'payload': {},
    });
    final decoder = DesktopFrameDecoder();
    expect(
      decoder
          .add(
            Uint8List.fromList([
              ...DesktopFrameCodec.encode(envelope),
              ...DesktopFrameCodec.encode(envelope),
            ]),
          )
          .length,
      2,
    );
    decoder.finish();
  });

  test('capabilities fail closed and snapshot preserves actual modes', () {
    final snapshot = DesktopRuntimeSnapshot.fromMap({
      'sessionId': 's',
      'configGeneration': 3,
      'networkGeneration': 4,
      'phase': 'connected',
      'modes': {'tunEnabled': true},
      'selectedTag': 'test',
      'coreVersion': 'core-test',
      'daemonApiVersion': 1,
      'serviceVersion': 'service-test',
      'capabilities': {'localProxy': true, 'tun': false, 'future': true},
    });
    expect(snapshot.capabilities.supports('localProxy'), true);
    expect(snapshot.capabilities.supports('tun'), false);
    expect(snapshot.capabilities.supports('future'), false);
    expect(snapshot.capabilities.supports('systemProxy'), false);
    expect(snapshot.modes.tunEnabled, true);
    expect(snapshot.toMap()['phase'], 'connected');
  });

  test('launch context round trips without platform calls', () {
    final map = {
      'installationId': 'test',
      'distribution': 'portable',
      'dataRoot': 'C:\\Data',
      'startedAtLogin': false,
      'minimized': true,
      'ownerPid': 42,
    };
    expect(DesktopLaunchContext.fromMap(map).toMap(), map);
  });

  test(
    'transport fake feeds chunked bytes into real decoder and close error',
    () async {
      final fake = FakeDesktopTransport();
      final decoder = DesktopFrameDecoder();
      final received = <RuntimeEnvelope>[];
      final errors = <Object>[];
      final subscription = fake.frames.listen(
        (chunk) => received.addAll(decoder.add(chunk)),
        onError: errors.add,
      );
      await fake.open();
      final frame = DesktopFrameCodec.encode(
        RuntimeEnvelope.fromMap({
          'version': 1,
          'kind': 'event',
          'id': '',
          'sessionId': 's',
          'configGeneration': 0,
          'networkGeneration': 0,
          'method': 'changed',
          'payload': {'phase': 'stopped'},
        }),
      );
      await fake.send(frame);
      fake.inject(frame, chunkSize: 1);
      final error = StateError('connection closed');
      fake.injectCloseError(error);
      await Future<void>.delayed(Duration.zero);
      expect(received.single.method, 'changed');
      expect(errors.single, same(error));
      expect(fake.sentFrames.single, frame);
      await fake.close();
      await subscription.cancel();
    },
  );
}
