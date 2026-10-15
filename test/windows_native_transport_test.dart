import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';
import 'package:meow_client/platform/windows/desktop_transport.dart';
import 'package:meow_client/platform/windows/desktop_wire_decoder.dart';
import 'package:meow_client/platform/windows/desktop_runtime_client.dart';
import 'package:meow_client/platform/windows/method_channel_desktop_transport.dart';

class _DecodedTransport implements DecodedDesktopTransport {
  final controller = StreamController<RuntimeEnvelope>.broadcast();
  @override
  Stream<RuntimeEnvelope> get envelopes => controller.stream;
  @override
  Stream<Uint8List> get frames => throw StateError('Raw decoder must not run');
  @override
  Future<void> open() async {}
  @override
  Future<void> close() => controller.close();
  @override
  Future<void> send(Uint8List frame) async {
    final request = DesktopFrameDecoder().add(frame).single;
    controller.add(
      RuntimeEnvelope(
        kind: RuntimeEnvelopeKind.response,
        id: request.id,
        sessionId: request.sessionId,
        configGeneration: request.configGeneration,
        networkGeneration: request.networkGeneration,
        method: request.method,
        payload: {
          'groups': [
            for (var i = 0; i < 4505; i++) {'tag': '$i'},
          ],
        },
      ),
    );
  }
}

RuntimeEnvelope message(String method, Object? payload, {String id = ''}) =>
    RuntimeEnvelope(
      kind: id.isEmpty
          ? RuntimeEnvelopeKind.event
          : RuntimeEnvelopeKind.response,
      id: id,
      sessionId: 'session',
      configGeneration: 7,
      networkGeneration: 3,
      method: method,
      payload: payload,
    );

List<RuntimeEnvelope> chunks(
  Object? payload, {
  String id = '',
  String stream = 's',
}) {
  final bytes = utf8.encode(jsonEncode(payload));
  final total = (bytes.length + 45055) ~/ 45056;
  return [
    for (var i = 0; i < total; i++)
      RuntimeEnvelope(
        kind: RuntimeEnvelopeKind.event,
        id: id,
        sessionId: 'session',
        configGeneration: 7,
        networkGeneration: 3,
        method: 'streamChunk',
        payload: {
          'streamId': stream,
          'method': 'groups',
          'encoding': 'base64-json',
          'index': i,
          'total': total,
          'totalBytes': bytes.length,
          'data': base64Encode(
            bytes.sublist(i * 45056, ((i + 1) * 45056).clamp(0, bytes.length)),
          ),
        },
      ),
  ];
}

RuntimeEnvelope descriptor(RuntimeEnvelope chunk) {
  final payload = objectMap(chunk.payload)
    ..remove('data')
    ..remove('index');
  return message('groups', payload, id: chunk.id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('com.etonify.desktop/runtime');
  test(
    'stopped snapshot retires cancelled subscription but not missing chunks',
    () {
      var clock = 0;
      final assembler = DesktopWireAssembler(clockMillis: () => clock);
      final parts = chunks({'groups': List<String>.filled(30000, 'server')});
      expect(assembler.accept(parts.first), isEmpty);
      assembler.accept(
        message('snapshot', {
          'sessionId': 'session',
          'configGeneration': 7,
          'networkGeneration': 3,
          'phase': 'stopped',
        }),
      );
      clock = 16000;
      expect(() => assembler.expire(), returnsNormally);
      expect(assembler.accept(parts[1]), isEmpty);
      assembler.finish();
    },
  );
  test('RPC failure retires partial reply and already queued late chunks', () {
    var clock = 0;
    final assembler = DesktopWireAssembler(clockMillis: () => clock);
    final parts = chunks({
      'groups': List<String>.filled(30000, 'server'),
    }, id: 'pending');
    assembler.accept(parts.first);
    final failed = RuntimeEnvelope(
      kind: RuntimeEnvelopeKind.response,
      id: 'pending',
      sessionId: 'session',
      configGeneration: 7,
      networkGeneration: 3,
      method: 'groups',
      error: const DesktopRuntimeError(code: 'cancelled', message: 'Cancelled'),
    );
    expect(assembler.accept(failed), [failed]);
    clock = 16000;
    expect(() => assembler.expire(), returnsNormally);
    expect(assembler.accept(parts[1]), isEmpty);
    assembler.finish();
  });
  test(
    'native pull transport decodes split frames and completes once',
    () async {
      final reads = <Completer<Uint8List?>>[];
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(native, (call) async {
        calls.add(call.method);
        if (call.method == 'open') return 17;
        final args = call.arguments as Map<Object?, Object?>;
        expect(args['lease'], 17);
        if (call.method == 'read') {
          final pending = Completer<Uint8List?>();
          reads.add(pending);
          return pending.future;
        }
        if (call.method == 'write') {
          final request = DesktopFrameDecoder()
              .add(args['frame']! as Uint8List)
              .single;
          final frame = DesktopFrameCodec.encode(
            RuntimeEnvelope(
              kind: RuntimeEnvelopeKind.response,
              id: request.id,
              sessionId: request.sessionId,
              configGeneration: request.configGeneration,
              networkGeneration: request.networkGeneration,
              method: request.method,
              payload: {'groups': <Object?>[]},
            ),
          );
          unawaited(() async {
            while (reads.isEmpty) {
              await Future<void>.delayed(Duration.zero);
            }
            reads.removeAt(0).complete(frame.sublist(0, 2));
            while (reads.isEmpty) {
              await Future<void>.delayed(Duration.zero);
            }
            reads
                .removeAt(0)
                .complete(Uint8List.fromList([...frame.sublist(2), ...frame]));
          }());
        }
        if (call.method == 'close') {
          for (final pending in reads) {
            pending.complete(null);
          }
          reads.clear();
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(native, null));
      final client = DesktopRuntimeClient(
        transport: MethodChannelDesktopTransport(),
      );
      expect(await client.call('groups', {}), {'groups': <Object?>[]});
      await client.close();
      expect(calls.where((method) => method == 'close'), hasLength(1));
      expect(calls.first, 'open');
    },
  );

  test(
    'closing while native open is pending releases its late lease',
    () async {
      final opened = Completer<int>();
      final entering = Completer<void>();
      final closed = Completer<void>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(native, (call) async {
        if (call.method == 'open') {
          entering.complete();
          return opened.future;
        }
        if (call.method == 'close') {
          expect((call.arguments as Map<Object?, Object?>)['lease'], 23);
          closed.complete();
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(native, null));
      final transport = MethodChannelDesktopTransport();
      final opening = transport.open();
      await entering.future;
      await transport.close();
      opened.complete(23);
      await expectLater(opening, throwsStateError);
      await closed.future.timeout(const Duration(seconds: 2));
    },
  );

  test('worker materializes JSON download bytes off UI isolate', () async {
    final decoder = await DesktopWireDecoder.create();
    addTearDown(decoder.close);
    final response = await decoder.decode(
      DesktopFrameCodec.encode(
        message('fetchUrlViaOutbound', {
          'body': [0, 255],
          'statusCode': 200,
        }, id: 'download'),
      ),
    );
    expect(objectMap(response.single.payload)['body'], isA<Uint8List>());
    expect(objectMap(response.single.payload)['body'], [0, 255]);
    await expectLater(
      decoder.decode(
        DesktopFrameCodec.encode(
          message('fetchUrlViaOutbound', {
            'body': [256],
          }, id: 'invalid'),
        ),
      ),
      throwsFormatException,
    );
  });
  test('intentional decoder close does not emit a protocol failure', () async {
    final decoder = await DesktopWireDecoder.create();
    final errors = <Object>[];
    final subscription = decoder.errors.listen(errors.add);
    await decoder.close();
    await subscription.cancel();
    expect(errors, isEmpty);
  });
  test(
    'runtime consumes already decoded envelopes without UI frame parsing',
    () async {
      final transport = _DecodedTransport();
      final client = DesktopRuntimeClient(transport: transport);
      addTearDown(client.close);
      final response = await client.call('groups', {});
      expect(response['groups'], hasLength(4505));
    },
  );
  test('worker decodes split header and preserves envelope order', () async {
    final decoder = await DesktopWireDecoder.create();
    addTearDown(decoder.close);
    final frame = DesktopFrameCodec.encode(message('traffic', {'uplink': 12}));
    expect(await decoder.decode(Uint8List.sublistView(frame, 0, 2)), isEmpty);
    final result = await decoder.decode(Uint8List.sublistView(frame, 2));
    expect(result.single.method, 'traffic');
    expect(objectMap(result.single.payload)['uplink'], 12);
    expect(result.single.networkGeneration, 3);
    await decoder.finish();
  });
  test(
    'worker assembles 4505 rows without exposing chunks to consumer',
    () async {
      final decoder = await DesktopWireDecoder.create();
      addTearDown(decoder.close);
      final payload = {
        'groups': [
          for (var i = 0; i < 4505; i++) {'tag': 'server-$i', 'delay': i},
        ],
      };
      final all = <RuntimeEnvelope>[];
      for (final chunk in chunks(payload)) {
        all.addAll(await decoder.decode(DesktopFrameCodec.encode(chunk)));
      }
      expect(all, hasLength(1));
      expect(all.single.method, 'groups');
      expect(objectMap(all.single.payload)['groups'], hasLength(4505));
      expect(all.single.configGeneration, 7);
      await decoder.finish();
    },
  );
  for (final descriptorFirst in [true, false]) {
    test(
      'RPC chunk assembly handles descriptor first=$descriptorFirst',
      () async {
        final decoder = await DesktopWireDecoder.create();
        addTearDown(decoder.close);
        final pieces = chunks({
          'groups': List.filled(20000, 'node'),
        }, id: 'rpc1');
        final input = descriptorFirst
            ? [descriptor(pieces.first), ...pieces]
            : [...pieces, descriptor(pieces.first)];
        final all = <RuntimeEnvelope>[];
        for (final item in input) {
          all.addAll(await decoder.decode(DesktopFrameCodec.encode(item)));
        }
        expect(all, hasLength(1));
        expect(all.single.kind, RuntimeEnvelopeKind.response);
        expect(all.single.id, 'rpc1');
        expect(objectMap(all.single.payload)['groups'], hasLength(20000));
        await decoder.finish();
      },
    );
  }
  test('duplicate and cross-generation chunks fail instead of mixing data', () {
    final pieces = chunks({'groups': List.filled(20000, 'node')});
    final assembler = DesktopWireAssembler();
    expect(assembler.accept(pieces.first), isEmpty);
    expect(() => assembler.accept(pieces.first), throwsFormatException);
    final second = DesktopWireAssembler()..accept(pieces.first);
    final changed = pieces[1].toMap()..['networkGeneration'] = 4;
    expect(
      () => second.accept(RuntimeEnvelope.fromMap(changed)),
      throwsFormatException,
    );
  });
  test('missing chunks and expired assemblies are explicit failures', () {
    var now = 0;
    final assembler = DesktopWireAssembler(clockMillis: () => now);
    assembler.accept(chunks({'groups': List.filled(20000, 'node')}).first);
    expect(assembler.finish, throwsFormatException);
    now = 15001;
    expect(assembler.expire, throwsFormatException);
  });
  test(
    'receiver rejects a fifth active assembly before allocating its body',
    () {
      final assembler = DesktopWireAssembler();
      for (var i = 0; i < 4; i++) {
        final part = chunks({
          'groups': List.filled(20000, 'node'),
        }, stream: '$i').first;
        expect(assembler.accept(part), isEmpty);
      }
      expect(
        () => assembler.accept(
          chunks({'groups': List.filled(20000, 'node')}, stream: '5').first,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'worker rejects oversized headers before body and terminalizes errors',
    () async {
      final decoder = await DesktopWireDecoder.create();
      addTearDown(decoder.close);
      final header = Uint8List(4);
      ByteData.sublistView(header).setUint32(0, 16777217, Endian.little);
      await expectLater(decoder.decode(header), throwsFormatException);
      await expectLater(
        decoder.decode(Uint8List(0)),
        throwsA(isA<StateError>()),
      );
    },
  );
  test('worker EOF rejects truncated frame', () async {
    final decoder = await DesktopWireDecoder.create();
    addTearDown(decoder.close);
    await decoder.decode(Uint8List.fromList([3, 0, 0]));
    await expectLater(decoder.finish(), throwsFormatException);
  });
}
