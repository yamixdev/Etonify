import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'lifecycle listeners cannot replace or cancel UI event delivery',
    () async {
      const name = 'meow_client/singbox_events';
      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(const MethodChannel(name), (
        call,
      ) async {
        calls.add(call.method);
        return null;
      });
      final runtime = SingboxRuntime.instance;
      final uiEvents = <Map<String, dynamic>>[];
      final lifecycleEvents = <Map<String, dynamic>>[];
      final ui = runtime.events.listen(uiEvents.add);
      final lifecycle = runtime.events.listen(lifecycleEvents.add);
      addTearDown(() async {
        await lifecycle.cancel();
        await ui.cancel();
        messenger.setMockMethodCallHandler(const MethodChannel(name), null);
      });

      Future<void> emit(Map<String, Object?> event) async {
        await messenger.handlePlatformMessage(
          name,
          codec.encodeSuccessEnvelope(event),
          (_) {},
        );
        await Future<void>.delayed(Duration.zero);
      }

      await Future<void>.delayed(Duration.zero);
      expect(calls, ['listen']);
      await emit({
        'type': 'state',
        'running': true,
        'mode': 'vpn',
        'runtimeGeneration': 1,
      });
      expect(uiEvents.single['running'], isTrue);
      expect(lifecycleEvents.single['running'], isTrue);
      await lifecycle.cancel();
      expect(calls, ['listen']);
      await emit({
        'type': 'groups',
        'groups': <Object?>[],
        'runtimeGeneration': 1,
      });
      expect(uiEvents.last['type'], 'groups');
      final stopEvents = <Map<String, dynamic>>[];
      final stop = runtime.events.listen(stopEvents.add);
      await emit({'type': 'state', 'running': false});
      expect(stopEvents.single['running'], isFalse);
      expect(uiEvents.last['running'], isFalse);
      await stop.cancel();
      await ui.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['listen', 'cancel']);
    },
  );
}
