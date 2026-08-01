import 'package:meow_client/app/runtime_connection_controller.dart';
import 'package:meow_client/app/runtime_lifecycle_controller.dart';

enum RuntimeStartDisposition {
  success,
  failed,
  cancelled,
  cancelledNeedsCleanup,
}

class RuntimeStateDecision {
  const RuntimeStateDecision({
    required this.phase,
    required this.keepConnecting,
    required this.clearDisconnectedState,
    required this.retryScheduled,
  });

  final AppConnectionPhase phase;
  final bool keepConnecting;
  final bool clearDisconnectedState;
  final bool retryScheduled;
}

class RuntimeSyncDecision {
  const RuntimeSyncDecision({
    required this.phase,
    required this.retryScheduled,
  });

  final AppConnectionPhase phase;
  final bool retryScheduled;
}

/// Coordinates root-level runtime operations that must have a single owner.
///
/// Native lifecycle work remains in [RuntimeLifecycleController]. This class
/// deduplicates stop requests and turns native/event state into deterministic
/// UI decisions without depending on a widget.
class RuntimeSessionCoordinator {
  Future<bool>? _stopInFlight;
  DateTime? _lastRecoveryStatusLogAt;

  Future<bool> stop({
    required bool activeOrRequested,
    required bool allowQueuedRestart,
    required void Function() suppressQueuedRestart,
    required void Function() clearQueuedRestartSuppression,
    required Future<bool> Function() performStop,
  }) {
    if (!allowQueuedRestart) {
      suppressQueuedRestart();
    }
    final inFlight = _stopInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    if (!activeOrRequested) {
      clearQueuedRestartSuppression();
      return Future<bool>.value(true);
    }

    late final Future<bool> operation;
    operation = Future<bool>.sync(performStop).whenComplete(() {
      if (identical(_stopInFlight, operation)) {
        _stopInFlight = null;
        clearQueuedRestartSuppression();
      }
    });
    _stopInFlight = operation;
    return operation;
  }

  RuntimeStartDisposition classifyStartResult({
    required RuntimeLifecycleResult result,
    required bool manualStartCancelled,
    required bool automaticRecoveryCancelled,
    required bool runtimeDesiredByUser,
  }) {
    if (manualStartCancelled || automaticRecoveryCancelled) {
      return result.success && !runtimeDesiredByUser
          ? RuntimeStartDisposition.cancelledNeedsCleanup
          : RuntimeStartDisposition.cancelled;
    }
    return result.success
        ? RuntimeStartDisposition.success
        : RuntimeStartDisposition.failed;
  }

  RuntimeStateDecision decideStateEvent({
    required bool running,
    required bool hasError,
    required bool transitionInProgress,
    required bool retryScheduled,
    required bool starting,
    required bool stopping,
  }) {
    // A native `running=false` event is expected while an explicit stop is in
    // flight. `transitionInProgress` is shared by startup and shutdown, so it
    // cannot decide the visual state by itself: otherwise a normal stop is
    // briefly rendered as "starting core".
    if (!running && stopping) {
      return const RuntimeStateDecision(
        phase: AppConnectionPhase.stopping,
        keepConnecting: false,
        clearDisconnectedState: false,
        retryScheduled: false,
      );
    }
    final keepStateDuringError =
        hasError && (transitionInProgress || retryScheduled || starting);
    final keepConnecting =
        !running &&
        (!hasError || keepStateDuringError) &&
        (transitionInProgress || retryScheduled || starting);
    final phase = switch ((running, hasError, keepStateDuringError)) {
      (true, _, _) => AppConnectionPhase.connected,
      (false, true, true) => AppConnectionPhase.recovering,
      (false, true, false) => AppConnectionPhase.failed,
      (false, false, _) when keepConnecting && retryScheduled =>
        AppConnectionPhase.recovering,
      (false, false, _) when keepConnecting => AppConnectionPhase.starting,
      _ => AppConnectionPhase.idle,
    };
    return RuntimeStateDecision(
      phase: phase,
      keepConnecting: keepConnecting,
      clearDisconnectedState: !running && !keepConnecting,
      retryScheduled: phase == AppConnectionPhase.recovering && retryScheduled,
    );
  }

  RuntimeSyncDecision decideStatus({
    required bool running,
    required bool nativeRecoveryPending,
    required bool localTransitionPending,
    required bool retryScheduled,
    required bool stopping,
  }) {
    final phase = !running && stopping
        ? AppConnectionPhase.stopping
        : (running
              ? AppConnectionPhase.connected
              : (nativeRecoveryPending || localTransitionPending
                    ? AppConnectionPhase.recovering
                    : AppConnectionPhase.idle));
    return RuntimeSyncDecision(
      phase: phase,
      retryScheduled: phase == AppConnectionPhase.recovering && retryScheduled,
    );
  }

  bool shouldLogRecoveryStatus({
    required DateTime now,
    required Duration interval,
  }) {
    final previous = _lastRecoveryStatusLogAt;
    if (previous != null && now.difference(previous) < interval) {
      return false;
    }
    _lastRecoveryStatusLogAt = now;
    return true;
  }
}
