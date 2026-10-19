import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/runtime_intent_controller.dart';

void main() {
  test(
    'external stop cancels user intent, queued restart and deferred retry',
    () {
      final controller = RuntimeIntentController()
        ..markRuntimeDesired()
        ..queueStartAfterStop()
        ..deferRetryUntilResume();
      final generation = controller.beginManualStart();

      expect(controller.observeExternalStop(1), isTrue);

      expect(controller.desiredByUser, isFalse);
      expect(controller.isManualStartCurrent(generation), isFalse);
      expect(controller.consumeRetryOnResume(connected: false), isFalse);
      expect(controller.completeSuccessfulStop(), isFalse);
    },
  );

  test('already observed external stop cannot cancel a newer manual start', () {
    final controller = RuntimeIntentController();
    controller.observeExternalStop(4);
    final generation = controller.beginManualStart();
    controller.markRuntimeDesired();

    expect(controller.observeExternalStop(4), isFalse);
    expect(controller.observeExternalStop(3), isFalse);
    expect(controller.isManualStartCurrent(generation), isTrue);
    expect(controller.externalStopRevision, 4);
  });

  test(
    'new manual start releases external stop queued restart suppression',
    () {
      final controller = RuntimeIntentController();
      controller.observeExternalStop(1);
      controller.beginManualStart();
      controller.markRuntimeDesired();
      controller.beginExplicitStop();
      controller.queueStartAfterStop();

      expect(controller.completeSuccessfulStop(), isTrue);
    },
  );

  test('manual start generations reject stale asynchronous work', () {
    final controller = RuntimeIntentController();

    final first = controller.beginManualStart();
    controller.markRuntimeDesired();
    expect(controller.isManualStartCurrent(first), isTrue);

    controller.invalidateManualStart();
    expect(controller.isManualStartCurrent(first), isFalse);

    final second = controller.beginManualStart();
    expect(second, greaterThan(first));
    expect(controller.isManualStartCurrent(second), isTrue);

    controller.clearRuntimeDesired();
    expect(controller.isManualStartCurrent(second), isFalse);
  });

  test('queued restart is consumed once after a successful stop', () {
    final controller = RuntimeIntentController()
      ..markRuntimeDesired()
      ..queueStartAfterStop()
      ..beginExplicitStop();

    expect(controller.completeSuccessfulStop(), isTrue);
    expect(controller.completeSuccessfulStop(), isFalse);
  });

  test('explicit stop suppresses an already queued restart', () {
    final controller = RuntimeIntentController()
      ..markRuntimeDesired()
      ..queueStartAfterStop()
      ..suppressQueuedRestart();

    expect(controller.startAfterStopRequested, isFalse);
    expect(controller.completeSuccessfulStop(), isFalse);

    controller.clearQueuedRestartSuppression();
    controller.queueStartAfterStop();
    expect(controller.completeSuccessfulStop(), isTrue);
  });

  test('failed stop restores intent without preserving queued restart', () {
    final controller = RuntimeIntentController()
      ..markRuntimeDesired()
      ..queueStartAfterStop()
      ..beginExplicitStop()
      ..restoreAfterStopFailure();

    expect(controller.desiredByUser, isTrue);
    expect(controller.startAfterStopRequested, isFalse);
    expect(controller.explicitStopInProgress, isFalse);
    expect(controller.completeSuccessfulStop(), isFalse);
  });

  test('observed running state cannot override an explicit stop', () {
    final controller = RuntimeIntentController()
      ..markRuntimeDesired()
      ..beginExplicitStop()
      ..restoreDesiredFromObservedRuntime();

    expect(controller.desiredByUser, isFalse);
    expect(controller.explicitStopInProgress, isTrue);

    controller.completeSuccessfulStop();
    controller.restoreDesiredFromObservedRuntime();
    expect(controller.desiredByUser, isTrue);
  });

  test(
    'resume retry requires desired disconnected runtime and is one-shot',
    () {
      final controller = RuntimeIntentController()
        ..markRuntimeDesired()
        ..deferRetryUntilResume();

      expect(controller.consumeRetryOnResume(connected: false), isTrue);
      expect(controller.consumeRetryOnResume(connected: false), isFalse);

      controller.deferRetryUntilResume();
      expect(controller.consumeRetryOnResume(connected: true), isFalse);
      expect(controller.retryOnResume, isFalse);

      controller
        ..clearRuntimeDesired()
        ..deferRetryUntilResume();
      expect(controller.consumeRetryOnResume(connected: false), isFalse);
      expect(controller.retryOnResume, isFalse);
    },
  );
}
