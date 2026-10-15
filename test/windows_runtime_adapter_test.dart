import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';
import 'package:meow_client/platform/windows/desktop_preferences.dart';
import 'package:meow_client/platform/windows/desktop_transport.dart';
import 'package:meow_client/platform/windows/desktop_runtime_client.dart';
import 'package:meow_client/platform/windows/windows_runtime_adapter.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'dart:convert';
import 'dart:io';

class TestTransport implements DesktopTransport {
  final controller = StreamController<Uint8List>();
  final requests = <RuntimeEnvelope>[];
  int opens = 0;
  bool closed = false;
  void Function(RuntimeEnvelope)? handle;
  @override
  Stream<Uint8List> get frames => controller.stream;
  @override
  Future<void> open() async {
    opens++;
  }

  @override
  Future<void> close() {
    closed = true;
    return controller.close();
  }

  @override
  Future<void> send(Uint8List frame) async {
    final request = DesktopFrameDecoder().add(frame).single;
    requests.add(request);
    handle?.call(request);
  }

  void respond(
    RuntimeEnvelope request,
    Object? payload, {
    DesktopRuntimeError? error,
  }) {
    controller.add(
      DesktopFrameCodec.encode(
        RuntimeEnvelope(
          kind: RuntimeEnvelopeKind.response,
          id: request.id,
          sessionId: request.sessionId,
          configGeneration: request.configGeneration,
          networkGeneration: request.networkGeneration,
          method: request.method,
          payload: payload,
          error: error,
        ),
      ),
    );
  }

  void event(
    RuntimeEnvelope request,
    Object? payload, {
    String method = 'snapshot',
  }) {
    controller.add(
      DesktopFrameCodec.encode(
        RuntimeEnvelope(
          kind: RuntimeEnvelopeKind.event,
          id: '',
          sessionId: request.sessionId,
          configGeneration: request.configGeneration,
          networkGeneration: request.networkGeneration,
          method: method,
          payload: payload,
        ),
      ),
    );
  }
}

class DelayedOpenTransport implements DesktopTransport {
  final opening = Completer<void>();
  final controller = StreamController<Uint8List>.broadcast();
  final requests = <Uint8List>[];
  int opens = 0;
  bool acquired = false;
  bool resourceOpen = false;
  int closes = 0;
  @override
  Stream<Uint8List> get frames => controller.stream;
  @override
  Future<void> open() async {
    opens++;
    await opening.future;
    acquired = true;
    resourceOpen = true;
  }

  @override
  Future<void> close() async {
    closes++;
    resourceOpen = false;
    await controller.close();
  }

  @override
  Future<void> send(Uint8List frame) async {
    requests.add(frame);
  }
}

Map<String, Object?> snapshot(
  RuntimeEnvelope request,
  String phase, {
  bool tun = true,
}) => {
  'sessionId': request.sessionId,
  'configGeneration': request.configGeneration,
  'networkGeneration': request.networkGeneration,
  'phase': phase,
  'modes': DesktopModePreferences.defaults.toMap(),
  'selectedTag': 'proxy-a',
  'coreVersion': 'test',
  'daemonApiVersion': 1,
  'serviceVersion': 'test',
  'capabilities': {
    'localProxy': true,
    'tun': tun,
    'systemProxy': true,
    'processRouting': true,
  },
};

void main() {
  for (final timeout in [false, true]) {
    test(
      'late transport open after ${timeout ? "timeout" : "close"} releases resource',
      () async {
        final delayed = DelayedOpenTransport();
        final openingClient = DesktopRuntimeClient(
          transport: delayed,
          requestTimeout: const Duration(milliseconds: 30),
        );
        final observed = <RuntimeEnvelope>[];
        final listener = openingClient.events.listen(
          observed.add,
          onError: (Object _) {},
        );
        final operation = openingClient.call('status', {});
        final assertion = expectLater(
          operation,
          throwsA(isA<DesktopRuntimeException>()),
        );
        await Future<void>.delayed(Duration.zero);
        if (timeout) {
          await assertion;
        } else {
          await openingClient.close();
        }
        delayed.opening.complete();
        await assertion;
        await Future<void>.delayed(Duration.zero);
        expect(delayed.acquired, true);
        expect(delayed.closes, 1);
        expect(delayed.resourceOpen, false);
        expect(delayed.requests, isEmpty);
        expect(observed, isEmpty);
        await listener.cancel();
        await openingClient.close();
      },
    );
  }
  test('missing bridge fails immediately in each caller error zone', () async {
    final unavailable = DesktopRuntimeClient.unavailable();
    addTearDown(unavailable.close);
    Future<Object> requestInErrorZone() {
      final result = Completer<Object>();
      runZonedGuarded(
        () async {
          try {
            await unavailable.snapshot();
            result.complete('unexpected success');
          } on Object catch (error) {
            result.complete(error);
          }
        },
        (error, stack) {
          if (!result.isCompleted) result.complete(error);
        },
      );
      return result.future.timeout(const Duration(milliseconds: 100));
    }

    for (var caller = 0; caller < 2; caller++) {
      expect(
        await requestInErrorZone(),
        isA<DesktopRuntimeException>().having(
          (e) => e.code,
          'code',
          'unavailable',
        ),
      );
    }
  });
  late TestTransport transport;
  late DesktopRuntimeClient client;
  setUp(() {
    transport = TestTransport();
    client = DesktopRuntimeClient(
      transport: transport,
      requestTimeout: const Duration(milliseconds: 500),
    );
    transport.handle = (r) {
      if (r.method == 'snapshot') transport.respond(r, snapshot(r, 'stopped'));
    };
  });
  tearDown(() async {
    await client.close();
  });

  test(
    'Windows fetch materializes real JSON bytes for download consumers',
    () async {
      transport.handle = (r) => transport.respond(r, {
        'statusCode': 200,
        'body': [0, 127, 255],
        'headersJson': '{}',
        'finalUrl': 'https://example.invalid/file',
      });
      final adapter = WindowsRuntimeAdapter(
        client: client,
        modes: () => DesktopModePreferences.defaults,
      );
      final result = await adapter.invoke('fetchUrlViaOutbound', {
        'maxBytes': 3,
      });
      expect(result['body'], isA<Uint8List>());
      expect(result['body'], [0, 127, 255]);
      expect(result['statusCode'], 200);
    },
  );
  for (final invalid in <Object?>[-1, 256, 1.5, '1', null]) {
    test('Windows fetch rejects invalid JSON byte $invalid', () async {
      transport.handle = (r) => transport.respond(r, {
        'statusCode': 200,
        'body': [invalid],
        'headersJson': '{}',
        'finalUrl': 'https://example.invalid/file',
      });
      final adapter = WindowsRuntimeAdapter(
        client: client,
        modes: () => DesktopModePreferences.defaults,
      );
      await expectLater(
        adapter.invoke('fetchUrlViaOutbound', {'maxBytes': 3}),
        throwsFormatException,
      );
    });
  }
  test('Windows fetch rejects a body exceeding requested byte limit', () async {
    transport.handle = (r) => transport.respond(r, {
      'body': [1, 2, 3],
    });
    final adapter = WindowsRuntimeAdapter(
      client: client,
      modes: () => DesktopModePreferences.defaults,
    );
    await expectLater(
      adapter.invoke('fetchUrlViaOutbound', {'maxBytes': 2}),
      throwsFormatException,
    );
  });

  for (final method in ['start', 'applyModes']) {
    test(
      '$method rejected proposal resyncs actual old state and retries with fresh identity',
      () async {
        Map<String, Object?>? actual;
        RuntimeEnvelope? rejected;
        transport.handle = (r) {
          if (r.method == 'snapshot') {
            actual ??= {
              ...snapshot(r, 'connected'),
              'sessionId': 'existing',
              'configGeneration': 7,
              'networkGeneration': 3,
            };
            transport.respond(r, actual);
          } else if (rejected == null) {
            rejected = r;
            transport.respond(
              r,
              null,
              error: const DesktopRuntimeError(
                code: 'rejected',
                message: 'old runtime preserved',
              ),
            );
          } else {
            transport.event(rejected!, snapshot(rejected!, 'connected'));
            actual = snapshot(r, 'connected');
            transport.respond(r, actual);
          }
        };
        Future<DesktopRuntimeSnapshot> transition() => method == 'start'
            ? client.start(config: '{}', modes: DesktopModePreferences.defaults)
            : client.applyModes(
                config: '{}',
                modes: DesktopModePreferences.defaults,
              );
        await expectLater(
          transition(),
          throwsA(
            isA<DesktopRuntimeException>().having(
              (e) => e.code,
              'code',
              'rejected',
            ),
          ),
        );
        final current = await client.snapshot();
        expect(current.sessionId, 'existing');
        expect(current.configGeneration, 7);
        final delivered = <RuntimeEnvelope>[];
        final listener = client.events.listen(delivered.add);
        final retry = await transition();
        expect(retry.phase, DesktopRuntimePhase.connected);
        expect(retry.configGeneration, greaterThan(rejected!.configGeneration));
        await Future<void>.delayed(Duration.zero);
        expect(
          delivered.any(
            (e) => e.configGeneration == rejected!.configGeneration,
          ),
          false,
        );
        await listener.cancel();
      },
    );
  }
  test(
    'timed out proposal resyncs host accepted state before apply retry',
    () async {
      Map<String, Object?>? actual;
      transport.handle = (r) {
        if (r.method == 'snapshot') {
          actual ??= {
            ...snapshot(r, 'stopped'),
            'sessionId': 'old',
            'configGeneration': 5,
          };
          transport.respond(r, actual);
        } else if (r.method == 'start') {
          actual = snapshot(r, 'connected');
        } else {
          actual = snapshot(r, 'connected');
          transport.respond(r, actual);
        }
      };
      await expectLater(
        client.start(config: '{}', modes: DesktopModePreferences.defaults),
        throwsA(isA<TimeoutException>()),
      );
      final current = await client.snapshot();
      expect(current.phase, DesktopRuntimePhase.connected);
      expect(current.configGeneration, 6);
      final applied = await client.applyModes(
        config: '{}',
        modes: DesktopModePreferences.defaults,
      );
      expect(applied.configGeneration, 7);
      expect(applied.sessionId, current.sessionId);
    },
  );
  test(
    'local stop fence rejects pending start and ignores late candidate connected',
    () async {
      final proposed = Completer<RuntimeEnvelope>();
      transport.handle = (r) {
        if (r.method == 'snapshot') {
          transport.respond(r, snapshot(r, 'stopped'));
        }
        if (r.method == 'start') proposed.complete(r);
        if (r.method == 'stop') transport.respond(r, <String, Object?>{});
      };
      final events = <RuntimeEnvelope>[];
      final listener = client.events.listen(events.add);
      final starting = client.start(
        config: '{}',
        modes: DesktopModePreferences.defaults,
      );
      final assertion = expectLater(
        starting,
        throwsA(
          isA<DesktopRuntimeException>().having(
            (e) => e.code,
            'code',
            'cancelled',
          ),
        ),
      );
      final candidate = await proposed.future;
      await client.stop(reason: 'user');
      transport.event(candidate, snapshot(candidate, 'connected'));
      transport.respond(candidate, snapshot(candidate, 'connected'));
      await assertion;
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.sessionId == candidate.sessionId), isEmpty);
      await listener.cancel();
    },
  );
  test(
    'snapshot response older than stop fence cannot restore pre-stop state',
    () async {
      final pending = Completer<RuntimeEnvelope>();
      transport.handle = (r) {
        if (r.method == 'snapshot') pending.complete(r);
        if (r.method == 'stop') transport.respond(r, <String, Object?>{});
      };
      final reading = client.snapshot();
      final assertion = expectLater(
        reading,
        throwsA(
          isA<DesktopRuntimeException>().having(
            (e) => e.code,
            'code',
            'superseded',
          ),
        ),
      );
      final request = await pending.future;
      await client.stop(reason: 'user');
      transport.respond(request, snapshot(request, 'connected'));
      await assertion;
    },
  );

  test(
    'stop fence also ignores candidate after starting acknowledgement',
    () async {
      final acknowledged = Completer<RuntimeEnvelope>();
      transport.handle = (r) {
        if (r.method == 'snapshot') {
          transport.respond(r, snapshot(r, 'stopped'));
        }
        if (r.method == 'start') {
          transport.respond(r, snapshot(r, 'starting'));
          acknowledged.complete(r);
        }
        if (r.method == 'stop') transport.respond(r, <String, Object?>{});
      };
      final delivered = <RuntimeEnvelope>[];
      final listener = client.events.listen(delivered.add);
      addTearDown(listener.cancel);
      final assertion = expectLater(
        client.start(config: '{}', modes: DesktopModePreferences.defaults),
        throwsA(
          isA<DesktopRuntimeException>().having(
            (e) => e.code,
            'code',
            'cancelled',
          ),
        ),
      );
      final candidate = await acknowledged.future;
      await Future<void>.delayed(Duration.zero);
      await client.stop(reason: 'user');
      transport.event(candidate, snapshot(candidate, 'connected'));
      await assertion;
      await Future<void>.delayed(Duration.zero);
      expect(delivered, isEmpty);
    },
  );

  test('candidate events cannot move network generation backwards', () async {
    final proposed = Completer<RuntimeEnvelope>();
    transport.handle = (r) {
      if (r.method == 'snapshot') transport.respond(r, snapshot(r, 'stopped'));
      if (r.method == 'start') {
        transport.respond(r, snapshot(r, 'starting'));
        proposed.complete(r);
      }
    };
    final delivered = <RuntimeEnvelope>[];
    final listener = client.events.listen(delivered.add);
    addTearDown(listener.cancel);
    final starting = client.start(
      config: '{}',
      modes: DesktopModePreferences.defaults,
    );
    final candidate = await proposed.future;
    await Future<void>.delayed(Duration.zero);
    final newer = RuntimeEnvelope(
      kind: RuntimeEnvelopeKind.event,
      id: '',
      sessionId: candidate.sessionId,
      configGeneration: candidate.configGeneration,
      networkGeneration: 2,
      method: 'snapshot',
    );
    transport.event(newer, {
      ...snapshot(candidate, 'starting'),
      'networkGeneration': 2,
    });
    await Future<void>.delayed(Duration.zero);
    transport.event(candidate, snapshot(candidate, 'connected'));
    await Future<void>.delayed(Duration.zero);
    transport.event(newer, {
      ...snapshot(candidate, 'connected'),
      'networkGeneration': 2,
    });
    expect((await starting).networkGeneration, 2);
    expect(delivered.every((e) => e.networkGeneration == 2), true);
  });

  for (final method in ['start', 'applyModes']) {
    for (final source in ['event', 'response']) {
      test(
        '$method stale candidate $source cannot cross shared network floor',
        () async {
          final proposed = Completer<RuntimeEnvelope>();
          transport.handle = (r) {
            if (r.method == 'snapshot') {
              transport.respond(r, {
                ...snapshot(r, 'connected'),
                'sessionId': 'existing',
                'configGeneration': 7,
                'networkGeneration': 0,
              });
            } else if (r.method == method) {
              proposed.complete(r);
            } else {
              transport.respond(r, <String, Object?>{});
            }
          };
          final delivered = <RuntimeEnvelope>[];
          final listener = client.events.listen(delivered.add);
          addTearDown(listener.cancel);
          final result = method == 'start'
              ? client.start(
                  config: '{}',
                  modes: DesktopModePreferences.defaults,
                )
              : client.applyModes(
                  config: '{}',
                  modes: DesktopModePreferences.defaults,
                );
          var completed = false;
          unawaited(
            result.then<void>((_) {
              completed = true;
            }, onError: (Object _) {}),
          );
          final candidate = await proposed.future;
          final confirmed = RuntimeEnvelope(
            kind: RuntimeEnvelopeKind.event,
            id: '',
            sessionId: 'existing',
            configGeneration: 7,
            networkGeneration: 2,
            method: method == 'start' ? 'snapshot' : 'traffic',
          );
          transport.event(
            confirmed,
            snapshot(confirmed, 'connected'),
            method: confirmed.method,
          );
          await Future<void>.delayed(Duration.zero);
          expect(delivered.single.networkGeneration, 2);

          if (source == 'response') {
            final assertion = expectLater(
              result,
              throwsA(isA<FormatException>()),
            );
            // Header still matches the original network=0 request exactly.
            transport.respond(candidate, snapshot(candidate, 'connected'));
            await assertion;
          } else {
            transport.event(candidate, snapshot(candidate, 'connected'));
            await Future<void>.delayed(Duration.zero);
            expect(completed, false);
            // Accepted connected event must not contaminate confirmed RPC identity.
            await client.call('status', {});
            expect(transport.requests.last.sessionId, 'existing');
            expect(transport.requests.last.configGeneration, 7);
            expect(transport.requests.last.networkGeneration, 2);
            expect(delivered, hasLength(1));
            transport.respond(candidate, {
              ...snapshot(candidate, 'starting'),
              'networkGeneration': 2,
            });
            await Future<void>.delayed(Duration.zero);
            expect(completed, false);
            final fresh = RuntimeEnvelope(
              kind: RuntimeEnvelopeKind.event,
              id: '',
              sessionId: candidate.sessionId,
              configGeneration: candidate.configGeneration,
              networkGeneration: 2,
              method: 'snapshot',
            );
            transport.event(fresh, snapshot(fresh, 'connected'));
            expect((await result).networkGeneration, 2);
          }
          await client.call('status', {});
          expect(transport.requests.last.networkGeneration, 2);
          expect(completed, source == 'event');
          expect(delivered.every((e) => e.networkGeneration == 2), true);
        },
      );
    }
  }

  test('fresh authoritative snapshot may reset shared network floor', () async {
    transport.handle = (r) => transport.respond(
      r,
      r.method == 'snapshot'
          ? {
              ...snapshot(r, 'connected'),
              'sessionId': 'existing',
              'configGeneration': 7,
              'networkGeneration': 0,
            }
          : <String, Object?>{},
    );
    await client.snapshot();
    final delivered = <RuntimeEnvelope>[];
    final listener = client.events.listen(delivered.add);
    addTearDown(listener.cancel);
    final newer = RuntimeEnvelope(
      kind: RuntimeEnvelopeKind.event,
      id: '',
      sessionId: 'existing',
      configGeneration: 7,
      networkGeneration: 2,
      method: 'snapshot',
    );
    transport.event(newer, snapshot(newer, 'connected'));
    await Future<void>.delayed(Duration.zero);
    await client.call('status', {});
    expect(transport.requests.last.networkGeneration, 2);
    expect((await client.snapshot()).networkGeneration, 0);
    final actual = RuntimeEnvelope(
      kind: RuntimeEnvelopeKind.event,
      id: '',
      sessionId: 'existing',
      configGeneration: 7,
      networkGeneration: 0,
      method: 'snapshot',
    );
    transport.event(actual, snapshot(actual, 'connected'));
    await Future<void>.delayed(Duration.zero);
    await client.call('status', {});
    expect(transport.requests.last.networkGeneration, 0);
    expect(delivered.map((e) => e.networkGeneration), [2, 0]);
  });

  test('failed candidate is discarded before a late connected event', () async {
    final proposed = Completer<RuntimeEnvelope>();
    transport.handle = (r) {
      if (r.method == 'snapshot') transport.respond(r, snapshot(r, 'stopped'));
      if (r.method == 'start') {
        transport.respond(r, snapshot(r, 'starting'));
        proposed.complete(r);
      }
    };
    final delivered = <RuntimeEnvelope>[];
    final listener = client.events.listen(delivered.add);
    addTearDown(listener.cancel);
    final assertion = expectLater(
      client.start(config: '{}', modes: DesktopModePreferences.defaults),
      throwsA(
        isA<DesktopRuntimeException>().having(
          (e) => e.code,
          'code',
          'runtime_failed',
        ),
      ),
    );
    final candidate = await proposed.future;
    await Future<void>.delayed(Duration.zero);
    transport.event(candidate, snapshot(candidate, 'failed'));
    await assertion;
    transport.event(candidate, snapshot(candidate, 'connected'));
    await Future<void>.delayed(Duration.zero);
    expect(delivered.map((e) => objectMap(e.payload)['phase']), ['failed']);
  });

  test(
    'start completes only after connected snapshot, not starting acknowledgement',
    () async {
      transport.handle = (r) {
        if (r.method == 'snapshot') {
          transport.respond(r, snapshot(r, 'stopped'));
        }
        if (r.method == 'start') transport.respond(r, snapshot(r, 'starting'));
      };
      var completed = false;
      final result = client.start(
        config: '{}',
        modes: DesktopModePreferences.defaults,
      );
      unawaited(
        result.then((_) {
          completed = true;
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(completed, false);
      final request = transport.requests.last;
      expect(request.method, 'start');
      expect((request.payload as Map)['sessionId'], request.sessionId);
      transport.event(request, snapshot(request, 'connected'));
      expect((await result).phase, DesktopRuntimePhase.connected);
    },
  );
  test('host error rejects start', () async {
    transport.handle = (r) {
      if (r.method == 'snapshot') transport.respond(r, snapshot(r, 'stopped'));
      if (r.method == 'start') {
        transport.respond(
          r,
          null,
          error: const DesktopRuntimeError(
            code: 'start_failed',
            message: 'cannot start',
          ),
        );
      }
    };
    await expectLater(
      client.start(config: '{}', modes: DesktopModePreferences.defaults),
      throwsA(
        isA<DesktopRuntimeException>().having(
          (e) => e.code,
          'code',
          'start_failed',
        ),
      ),
    );
  });
  test('snapshot error cannot be masked by connected phase', () async {
    transport.handle = (r) {
      final value = snapshot(r, r.method == 'start' ? 'connected' : 'stopped');
      if (r.method == 'start') {
        value['error'] = {'code': 'start_failed', 'message': 'cannot start'};
      }
      transport.respond(r, value);
    };
    await expectLater(
      client.start(config: '{}', modes: DesktopModePreferences.defaults),
      throwsA(
        isA<DesktopRuntimeException>().having(
          (e) => e.code,
          'code',
          'start_failed',
        ),
      ),
    );
  });
  test(
    'connected event error rejects operation and preserves actual host state',
    () async {
      transport.handle = (r) {
        if (r.method == 'start') {
          transport.event(
            r,
            snapshot(r, 'connected')
              ..['error'] = {'code': 'start_failed', 'message': 'cannot start'},
          );
          transport.respond(r, snapshot(r, 'starting'));
        } else {
          transport.respond(r, snapshot(r, 'stopped'));
        }
      };
      final runtime = SingboxRuntime.windows(
        client: client,
        modes: () => DesktopModePreferences.defaults,
      );
      final observed = <Map<String, dynamic>>[];
      final listener = runtime.events.listen(observed.add);
      addTearDown(listener.cancel);
      await expectLater(
        runtime.start(config: '{}', useVpn: false),
        throwsA(
          isA<DesktopRuntimeException>().having(
            (e) => e.code,
            'code',
            'start_failed',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(observed.single['running'], true);
      expect(observed.single['phase'], 'connected');
      expect(observed.single['error'], 'cannot start');
    },
  );
  test('transport loss cancels pending RPC immediately', () async {
    final pending = client.call('status', {});
    final assertion = expectLater(
      pending,
      throwsA(isA<DesktopRuntimeException>()),
    );
    await Future<void>.delayed(Duration.zero);
    unawaited(transport.close());
    await assertion;
  });
  test('two event listeners share one transport source', () async {
    final first = <RuntimeEnvelope>[];
    final second = <RuntimeEnvelope>[];
    final a = client.events.listen(first.add);
    final b = client.events.listen(second.add);
    await client.snapshot();
    transport.event(transport.requests.last, {
      'upload': 123,
    }, method: 'traffic');
    await Future<void>.delayed(Duration.zero);
    expect(first.single.method, 'traffic');
    expect(second.single.payload, {'upload': 123});
    expect(transport.opens, 1);
    await a.cancel();
    await b.cancel();
  });
  test(
    'wrong generation and duplicate responses cannot complete another request',
    () async {
      final result = client.call('status', {});
      await Future<void>.delayed(Duration.zero);
      final request = transport.requests.last;
      transport.controller.add(
        DesktopFrameCodec.encode(
          RuntimeEnvelope(
            kind: RuntimeEnvelopeKind.response,
            id: request.id,
            sessionId: request.sessionId,
            configGeneration: request.configGeneration + 1,
            networkGeneration: request.networkGeneration,
            method: request.method,
            payload: {'wrong': true},
          ),
        ),
      );
      transport.respond(request, {'ok': true});
      transport.respond(request, {'duplicate': true});
      expect(await result, {'ok': true});
      final next = client.call('groups', {});
      await Future<void>.delayed(Duration.zero);
      transport.respond(request, {'stale': true});
      transport.respond(transport.requests.last, {'groups': <Object?>[]});
      expect(await next, {'groups': <Object?>[]});
    },
  );
  test('malformed stream rejects pending calls and is terminal', () async {
    final result = client.call('status', {});
    final assertion = expectLater(
      result,
      throwsA(isA<DesktopRuntimeException>()),
    );
    await Future<void>.delayed(Duration.zero);
    transport.controller.add(Uint8List(4));
    await assertion;
    await Future<void>.delayed(Duration.zero);
    expect(
      transport.closed,
      true,
      reason: 'malformed native stream is terminal',
    );
    await expectLater(
      client.call('status', {}),
      throwsA(isA<DesktopRuntimeException>()),
    );
  });
  test('TUN capability is required before start command', () async {
    transport.handle = (r) =>
        transport.respond(r, snapshot(r, 'stopped', tun: false));
    await expectLater(
      client.start(
        config: '{}',
        modes: const DesktopModePreferences(tunEnabled: true),
      ),
      throwsUnsupportedError,
    );
    expect(transport.requests.map((r) => r.method), ['snapshot']);
  });
  test(
    'Windows TUN preparation fails visibly without capability; local proxy does not probe',
    () async {
      transport.handle = (r) =>
          transport.respond(r, snapshot(r, 'stopped', tun: false));
      final tunRuntime = SingboxRuntime.windows(
        client: client,
        modes: () => const DesktopModePreferences(tunEnabled: true),
      );
      await expectLater(
        tunRuntime.prepareVpn(requiresVpn: true),
        throwsUnsupportedError,
      );
      await expectLater(
        tunRuntime.prepareVpn(requiresVpn: false),
        throwsUnsupportedError,
      );
      final reads = transport.requests.length;
      final proxyRuntime = SingboxRuntime.windows(
        client: client,
        modes: () => DesktopModePreferences.defaults,
      );
      expect(await proxyRuntime.prepareVpn(requiresVpn: true), true);
      expect(transport.requests.length, reads);
      expect(transport.requests.every((r) => r.method == 'snapshot'), true);
    },
  );
  test(
    'adapter maps selection, probe and prepared calls without no-op',
    () async {
      transport.handle = (r) => transport.respond(r, {'method': r.method});
      final adapter = WindowsRuntimeAdapter(
        client: client,
        modes: () => DesktopModePreferences.defaults,
      );
      expect(
        await adapter.invoke('selectOutbound', {
          'groupTag': 'select',
          'outboundTag': 'p',
        }),
        {'method': 'selectOutbound'},
      );
      expect(transport.requests.last.payload, {
        'groupTag': 'select',
        'outboundTag': 'p',
      });
      await expectLater(
        adapter.invoke('startPrepared', {'useVpn': true}),
        throwsA(isA<DesktopRuntimeException>()),
      );
      expect(transport.requests.last.method, 'getConfigPath');
      await adapter.invoke('startProbe', {'config': '{}'});
      expect(transport.requests.last.method, 'startProbe');
    },
  );
  test(
    'runtime delegates production calls using live Windows modes not Android useVpn',
    () async {
      var modes = DesktopModePreferences.defaults;
      final runtime = SingboxRuntime.windows(
        client: client,
        modes: () => modes,
      );
      transport.handle = (r) {
        if (r.method == 'snapshot') {
          transport.respond(r, snapshot(r, 'stopped'));
        } else if (r.method == 'start' || r.method == 'applyModes') {
          transport.respond(r, snapshot(r, 'connected'));
        } else if (r.method == 'fetchUrlViaOutbound') {
          transport.respond(r, {
            'statusCode': 200,
            'body': <int>[],
            'headersJson': '{}',
            'finalUrl': 'https://example.test',
          });
        } else {
          transport.respond(r, {'ok': true});
        }
      };
      await runtime.start(config: '{}', useVpn: true);
      final start = transport.requests.last;
      expect(start.method, 'start');
      final inbounds =
          (jsonDecode((start.payload as Map)['config'] as String)
                  as Map)['inbounds']
              as List;
      expect(inbounds.map((v) => v['type']), ['mixed']);
      modes = const DesktopModePreferences(tunEnabled: true);
      await runtime.applyConfig(config: '{}', useVpn: false);
      expect(transport.requests.last.method, 'applyModes');
      expect(
        (transport.requests.last.payload as Map)['modes']['tunEnabled'],
        true,
      );
      await runtime.selectOutbound(groupTag: 'select', outboundTag: 'chosen');
      expect(transport.requests.last.payload, {
        'groupTag': 'select',
        'outboundTag': 'chosen',
      });
      await runtime.urlTest(
        groupTag: 'g',
        targetOutboundTag: 'p',
        includeOutboundTags: ['p'],
        logicalSessionId: 'logical',
        timeoutMillis: 2000,
      );
      expect(transport.requests.last.method, 'urlTest');
      expect(
        (transport.requests.last.payload as Map)['logicalSessionId'],
        'logical',
      );
      await runtime.cancelUrlTest(groupTag: 'g');
      expect(transport.requests.last.method, 'cancelUrlTest');
      await runtime.lookupOutboundExternalInfo(outboundTag: 'p');
      expect(transport.requests.last.method, 'lookupOutboundExternalInfo');
      await runtime.fetchUrlViaOutbound(
        outboundTag: 'p',
        uri: Uri.parse('https://example.test'),
        headers: {'X-Test': 'yes'},
        maxBytes: 2000,
        timeout: const Duration(seconds: 2),
      );
      expect((transport.requests.last.payload as Map)['timeoutMillis'], 2000);
      await runtime.stop(reason: 'user');
      expect(transport.requests.last.payload, {'reason': 'user'});
    },
  );
  test('saving stopped mode values performs no runtime request', () async {
    var modes = DesktopModePreferences.defaults;
    SingboxRuntime.windows(client: client, modes: () => modes);
    modes = modes.copyWith(tunEnabled: true, systemProxyEnabled: true);
    expect(transport.requests, isEmpty);
    expect(transport.opens, 0);
  });
  test(
    'transport close while awaiting connected state rejects instead of timing out',
    () async {
      transport.handle = (r) => transport.respond(
        r,
        snapshot(r, r.method == 'start' ? 'starting' : 'stopped'),
      );
      final started = client.start(
        config: '{}',
        modes: DesktopModePreferences.defaults,
      );
      final assertion = expectLater(
        started,
        throwsA(
          isA<DesktopRuntimeException>().having(
            (e) => e.code,
            'code',
            'transport_lost',
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await transport.close();
      await assertion;
    },
  );
  test(
    'authoritative connected response reaches both runtime event consumers',
    () async {
      transport.handle = (r) => transport.respond(
        r,
        snapshot(r, r.method == 'start' ? 'connected' : 'stopped'),
      );
      final runtime = SingboxRuntime.windows(
        client: client,
        modes: () => DesktopModePreferences.defaults,
      );
      final a = <Map<String, dynamic>>[];
      final b = <Map<String, dynamic>>[];
      final first = runtime.events.listen(a.add);
      final second = runtime.events.listen(b.add);
      await runtime.start(config: '{}', useVpn: true);
      await Future<void>.delayed(Duration.zero);
      expect(
        a.where((v) => v['type'] == 'state' && v['running'] == true),
        hasLength(1),
      );
      expect(
        b.where((v) => v['type'] == 'state' && v['running'] == true),
        hasLength(1),
      );
      await first.cancel();
      await second.cancel();
    },
  );
  test(
    'prepared config is read and Windows policy applied before actual start RPC',
    () async {
      final folder = await Directory.systemTemp.createTemp('etonify-a3-');
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/prepared.json');
      await file.writeAsString(
        '{"inbounds":[{"type":"tun","include_package":["android.app"]}]}',
      );
      transport.handle = (r) {
        if (r.method == 'getConfigPath') {
          transport.respond(r, {'path': file.path});
        } else {
          transport.respond(
            r,
            snapshot(r, r.method == 'start' ? 'connected' : 'stopped'),
          );
        }
      };
      final runtime = SingboxRuntime.windows(
        client: client,
        modes: () => DesktopModePreferences.defaults,
      );
      await runtime.startPrepared(useVpn: true);
      expect(transport.requests.map((r) => r.method), [
        'getConfigPath',
        'snapshot',
        'start',
      ]);
      final config =
          jsonDecode(
                (transport.requests.last.payload as Map)['config'] as String,
              )
              as Map;
      expect((config['inbounds'] as List).map((v) => v['type']), ['mixed']);
      expect(await file.readAsString(), contains('android.app'));
    },
  );
  test(
    'unbound production native bridge reports unavailable, never connected',
    () async {
      final unavailable = DesktopRuntimeClient.unavailable();
      await expectLater(
        unavailable.start(config: '{}', modes: DesktopModePreferences.defaults),
        throwsA(
          isA<DesktopRuntimeException>().having(
            (e) => e.code,
            'code',
            'unavailable',
          ),
        ),
      );
      await unavailable.close();
    },
  );
  test('wire modes exclude presentation and unknown storage fields', () async {
    transport.handle = (r) => transport.respond(
      r,
      snapshot(r, r.method == 'start' ? 'connected' : 'stopped'),
    );
    final runtime = SingboxRuntime.windows(
      client: client,
      modes: () => const DesktopModePreferences(
        unknown: {'proxyListStyle': 'comfortable', 'futureStorage': true},
      ),
    );
    await runtime.start(config: '{}', useVpn: false);
    expect((transport.requests.last.payload as Map)['modes'], {
      'tunEnabled': false,
      'systemProxyEnabled': false,
      'launchAtLogin': false,
      'launchMinimized': true,
      'connectOnLaunch': false,
      'processRoutingMode': 'allExceptSelected',
      'processPaths': <String>[],
    });
    await runtime.startProbe('{}');
  });
  test(
    'intermediate snapshots do not fabricate disconnected controller state',
    () async {
      final runtime = SingboxRuntime.windows(
        client: client,
        modes: () => DesktopModePreferences.defaults,
      );
      final observed = <Map<String, dynamic>>[];
      final subscription = runtime.events.listen(observed.add);
      await client.snapshot();
      final request = transport.requests.last;
      for (final phase in ['starting', 'applying', 'stopping']) {
        transport.event(request, snapshot(request, phase));
      }
      await Future<void>.delayed(Duration.zero);
      expect(observed, isEmpty);
      transport.event(request, snapshot(request, 'stopped'));
      await Future<void>.delayed(Duration.zero);
      expect(observed.single['running'], false);
      await subscription.cancel();
    },
  );
  test(
    'production provider reads the existing settings controller live without auto-start',
    () async {
      final container = ProviderContainer(
        overrides: [desktopRuntimeClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final runtime = container.read(singboxRuntimeProvider);
      final settings = container.read(appSettingsProvider).controller;
      expect(settings, same(container.read(appSettingsControllerProvider)));
      settings.windowsModes = const DesktopModePreferences(tunEnabled: true);
      expect(transport.requests, isEmpty);
      expect(transport.opens, 0);
      transport.handle = (r) => transport.respond(
        r,
        snapshot(r, r.method == 'start' ? 'connected' : 'stopped'),
      );
      await runtime.start(config: '{}', useVpn: false);
      expect(
        (transport.requests.last.payload as Map)['modes']['tunEnabled'],
        true,
      );
    },
    skip: !Platform.isWindows ? 'Windows production platform branch' : false,
  );
}
