import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/startup_latency_deadline_controller.dart';

void main() {
  group('startupLatencyDeadlineDelay', () {
    test('uses a default for invalid values', () {
      expect(startupLatencyDeadlineDelay(0), const Duration(seconds: 20));
    });

    test('clamps short and long configured timeouts', () {
      expect(startupLatencyDeadlineDelay(1), const Duration(seconds: 8));
      expect(startupLatencyDeadlineDelay(60), const Duration(seconds: 35));
    });
  });

  group('StartupLatencyDeadlineController', () {
    test('arms only once for a VPN service lifetime', () async {
      final controller = StartupLatencyDeadlineController();
      addTearDown(controller.dispose);
      var firstCalls = 0;
      var duplicateCalls = 0;

      expect(
        controller.armOnce(delay: Duration.zero, onExpired: () => firstCalls++),
        isTrue,
      );
      expect(
        controller.armOnce(
          delay: Duration.zero,
          onExpired: () => duplicateCalls++,
        ),
        isFalse,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(firstCalls, 1);
      expect(duplicateCalls, 0);
      expect(controller.isArmedForService, isTrue);
      expect(controller.isScheduled, isFalse);
    });

    test('reset cancels pending work and allows the next service', () async {
      final controller = StartupLatencyDeadlineController();
      addTearDown(controller.dispose);
      var calls = 0;

      controller.armOnce(
        delay: const Duration(milliseconds: 20),
        onExpired: () => calls++,
      );
      controller.resetForNextService();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(calls, 0);
      expect(controller.isArmedForService, isFalse);
      expect(
        controller.armOnce(delay: Duration.zero, onExpired: () => calls++),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(calls, 1);
    });
  });
}
