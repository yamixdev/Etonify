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
  test('legacy enabled payload is rejected and cannot resurrect routing', () {
    expect(
      RootModeStatus.fromMap(statusMap(enabled: true)).reason,
      'invalid_response',
    );
    expect(
      RootModeStatus.fromMap(statusMap()).moduleState,
      RootModuleState.ready,
    );
  });
  test('malformed status and unsafe diagnostic codes fail closed', () {
    for (final value in [
      null,
      {...statusMap(), 'reason': '/private/path'},
      {...statusMap(), 'moduleState': 'downloading'},
      {...statusMap(), 'busy': 'yes'},
    ]) {
      expect(RootModeStatus.fromMap(value).reason, 'invalid_response');
    }
  });
  test('snapshot and explicit removal use migration channel only', () async {
    const channel = MethodChannel('meow_client/root_mode');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return statusMap();
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final client = RootModeClient();
    expect(calls, isEmpty);
    await client.snapshot();
    await client.remove();
    expect(calls.map((call) => call.method), ['snapshot', 'remove']);
    expect(calls.every((call) => call.arguments == null), isTrue);
  });
}
