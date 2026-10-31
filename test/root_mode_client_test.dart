import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/platform/android/root_mode_client.dart';

Map<String, Object?> statusMap({
  String root = 'granted',
  String module = 'ready',
  bool enabled = false,
  bool busy = false,
}) => {
  'rootAvailability': root,
  'moduleState': module,
  'moduleVersion': '1.2.3',
  'enabled': enabled,
  'busy': busy,
  'progress': 0.0,
};

class RootTransportFake implements RootModeTransport {
  final calls = <(String, Map<String, Object?>?)>[];
  final controller = StreamController<Object?>.broadcast();
  Object? response = statusMap();
  Object? error;
  Future<Object?> Function(String)? handler;

  Future<void> close() => controller.close();

  @override
  Stream<Object?> get events => controller.stream;

  @override
  Future<Object?> invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    calls.add((method, arguments));
    if (error case final error?) throw error;
    return handler == null ? response : handler!(method);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'malformed update metadata is rejected rather than shown as a result',
    () {
      for (final fields in <Map<String, Object?>>[
        {'updateAvailable': 'yes'},
        {'updateAvailable': true},
        {'updateAvailable': true, 'availableModuleVersion': '../invalid'},
      ]) {
        final status = RootModeStatus.fromMap({...statusMap(), ...fields});
        expect(status.reason, 'invalid_response');
        expect(status.canEnable, isFalse);
      }
    },
  );

  test('saved root preference remains visible before fresh authorization', () {
    final status = RootModeStatus.fromMap(
      statusMap(root: 'unknown', enabled: true),
    );
    expect(status.enabled, isTrue);
    expect(status.canEnable, isFalse);
  });

  test(
    'default transport uses fixed root channel and an explicit boolean only',
    () async {
      const channel = MethodChannel('meow_client/root_mode');
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return statusMap(enabled: true);
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final client = RootModeClient();
      expect(received, isNull);
      final status = await client.setEnabled(true);
      expect(status.enabled, isTrue);
      expect(received?.method, 'setEnabled');
      expect(received?.arguments, {'enabled': true});
    },
  );

  test('only granted verified ready status permits enabling', () {
    expect(RootModeStatus.fromMap(statusMap()).canEnable, isTrue);
    for (final change in [
      {'rootAvailability': 'unknown'},
      {'rootAvailability': 'noSu'},
      {'rootAvailability': 'denied'},
      {'rootAvailability': 'futureRoot'},
      {'moduleState': 'incompatible'},
      {'moduleState': 'futureModule'},
      {'busy': true},
      {'progress': double.nan},
      {'progress': 1.1},
      {'enabled': 'true'},
    ]) {
      final status = RootModeStatus.fromMap({...statusMap(), ...change});
      expect(status.canEnable, isFalse, reason: '$change');
    }
  });

  test('extra native metadata cannot replace validated required fields', () {
    final status = RootModeStatus.fromMap({
      ...statusMap(),
      'authorizationCached': true,
      'futureMetadata': {'path': '/not-exposed'},
    });
    expect(status.canEnable, isTrue);
    expect(status.reason, isNull);
  });

  test(
    'malformed and unknown statuses fail closed without claiming enabled',
    () {
      for (final value in [
        null,
        'ready',
        <String, Object?>{},
        {...statusMap(enabled: true), 'moduleState': 'unrecognized'},
      ]) {
        final status = RootModeStatus.fromMap(value);
        expect(status.enabled, isFalse);
        expect(status.canEnable, isFalse);
        expect(status.reason, 'invalid_response');
      }
    },
  );

  test(
    'client is inert until invoked and exposes only fixed commands',
    () async {
      final transport = RootTransportFake();
      final client = RootModeClient(transport: transport);
      expect(transport.calls, isEmpty);
      await client.snapshot();
      await client.requestAuthorization();
      await client.install();
      await client.remove();
      await client.checkUpdate();
      await client.setEnabled(true);
      await client.cancel();
      expect(transport.calls.map((call) => call.$1), [
        'snapshot',
        'requestAuthorization',
        'install',
        'remove',
        'checkUpdate',
        'setEnabled',
        'cancel',
      ]);
      expect(transport.calls[5].$2, {'enabled': true});
      expect(
        transport.calls
            .where((call) => call.$1 != 'setEnabled')
            .map((call) => call.$2),
        everyElement(isNull),
      );
      await transport.controller.close();
    },
  );

  test('channel error details never become a visible status reason', () async {
    final transport = RootTransportFake()
      ..error = PlatformException(
        code: 'download_failed',
        message: '/private/path secret arbitrary native text',
      );
    final status = await RootModeClient(transport: transport).install();
    expect(status.reason, 'download_failed');
    expect(status.canEnable, isFalse);
    expect(status.moduleState, RootModuleState.failed);
    await transport.controller.close();
  });

  test(
    'event parsing rejects malformed data and sanitizes stream failures',
    () async {
      final transport = RootTransportFake();
      final statuses = <RootModeStatus>[];
      final subscription = RootModeClient(
        transport: transport,
      ).events.listen(statuses.add);
      transport.controller.add(statusMap(enabled: true));
      transport.controller.add({'enabled': true});
      transport.controller.addError(PlatformException(code: 'bad code /path'));
      await Future<void>.delayed(Duration.zero);
      expect(statuses[0].enabled, isTrue);
      expect(statuses[1].reason, 'invalid_response');
      expect(statuses[2].reason, 'service_unavailable');
      await subscription.cancel();
      await transport.controller.close();
    },
  );
}
