import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/runtime_connection_controller.dart';
import 'package:meow_client/app/runtime_lifecycle_controller.dart';
import 'package:meow_client/app/runtime_session_coordinator.dart';

void main() {
  test('concurrent stop requests share one native operation', () async {
    final coordinator = RuntimeSessionCoordinator();
    final completer = Completer<bool>();
    var stopCalls = 0;
    var suppressionClears = 0;

    Future<bool> stop() {
      stopCalls++;
      return completer.future;
    }

    final first = coordinator.stop(
      activeOrRequested: true,
      allowQueuedRestart: true,
      suppressQueuedRestart: () {},
      clearQueuedRestartSuppression: () => suppressionClears++,
      performStop: stop,
    );
    final second = coordinator.stop(
      activeOrRequested: true,
      allowQueuedRestart: true,
      suppressQueuedRestart: () {},
      clearQueuedRestartSuppression: () => suppressionClears++,
      performStop: stop,
    );

    expect(identical(first, second), isTrue);
    expect(stopCalls, 1);
    completer.complete(true);
    expect(await first, isTrue);
    expect(suppressionClears, 1);
  });

  test(
    'inactive stop clears restart suppression without native work',
    () async {
      final coordinator = RuntimeSessionCoordinator();
      var suppressed = 0;
      var cleared = 0;
      var stopCalls = 0;

      final result = await coordinator.stop(
        activeOrRequested: false,
        allowQueuedRestart: false,
        suppressQueuedRestart: () => suppressed++,
        clearQueuedRestartSuppression: () => cleared++,
        performStop: () async {
          stopCalls++;
          return true;
        },
      );

      expect(result, isTrue);
      expect(suppressed, 1);
      expect(cleared, 1);
      expect(stopCalls, 0);
    },
  );

  test('state event keeps retrying runtime in recovery', () {
    final decision = RuntimeSessionCoordinator().decideStateEvent(
      running: false,
      hasError: true,
      transitionInProgress: false,
      retryScheduled: true,
      starting: false,
      stopping: false,
    );

    expect(decision.phase, AppConnectionPhase.recovering);
    expect(decision.keepConnecting, isTrue);
    expect(decision.clearDisconnectedState, isFalse);
    expect(decision.retryScheduled, isTrue);
  });

  test('stable disconnect clears runtime presentation state', () {
    final decision = RuntimeSessionCoordinator().decideStateEvent(
      running: false,
      hasError: false,
      transitionInProgress: false,
      retryScheduled: false,
      starting: false,
      stopping: false,
    );

    expect(decision.phase, AppConnectionPhase.idle);
    expect(decision.keepConnecting, isFalse);
    expect(decision.clearDisconnectedState, isTrue);
  });

  test('status sync keeps an explicit stop out of recovery', () {
    final decision = RuntimeSessionCoordinator().decideStatus(
      running: false,
      nativeRecoveryPending: true,
      localTransitionPending: true,
      retryScheduled: true,
      stopping: true,
    );

    expect(decision.phase, AppConnectionPhase.stopping);
    expect(decision.retryScheduled, isFalse);
  });

  test('explicit stop is never rendered as a core start', () {
    final decision = RuntimeSessionCoordinator().decideStateEvent(
      running: false,
      hasError: false,
      transitionInProgress: true,
      retryScheduled: false,
      starting: false,
      stopping: true,
    );

    expect(decision.phase, AppConnectionPhase.stopping);
    expect(decision.keepConnecting, isFalse);
    expect(decision.clearDisconnectedState, isFalse);
    expect(decision.retryScheduled, isFalse);
  });

  test('late successful cancelled start requires native cleanup', () {
    final disposition = RuntimeSessionCoordinator().classifyStartResult(
      result: const RuntimeLifecycleResult.success(
        policy: RuntimeApplyPolicy.fullServiceRestart,
      ),
      manualStartCancelled: true,
      automaticRecoveryCancelled: false,
      runtimeDesiredByUser: false,
    );

    expect(disposition, RuntimeStartDisposition.cancelledNeedsCleanup);
  });

  test('recovery status logs are throttled', () {
    final coordinator = RuntimeSessionCoordinator();
    final now = DateTime(2026, 7, 28);

    expect(
      coordinator.shouldLogRecoveryStatus(
        now: now,
        interval: const Duration(seconds: 5),
      ),
      isTrue,
    );
    expect(
      coordinator.shouldLogRecoveryStatus(
        now: now.add(const Duration(seconds: 4)),
        interval: const Duration(seconds: 5),
      ),
      isFalse,
    );
    expect(
      coordinator.shouldLogRecoveryStatus(
        now: now.add(const Duration(seconds: 5)),
        interval: const Duration(seconds: 5),
      ),
      isTrue,
    );
  });
}
