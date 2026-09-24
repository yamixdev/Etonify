import 'dart:async';

typedef GroupUrlTestReadiness = bool Function();
typedef GroupUrlTestAction = Future<bool> Function();
typedef GroupUrlTestSettled = void Function(bool success);

/// Owns the single debounced automatic URLTest slot.
///
/// Manual checks bypass this scheduler. A later automatic reason replaces an
/// earlier one. Temporary runtime transitions retain the latest request for a
/// bounded period instead of losing the only probe owned by the client.
class GroupUrlTestScheduler {
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  bool _hasPendingWork = false;
  String? _pendingReason;

  bool get isScheduled => _timer?.isActive ?? false;
  bool get hasPendingWork => _hasPendingWork;
  String? get pendingReason => _hasPendingWork ? _pendingReason : null;

  void schedule({
    String? reason,
    required Duration delay,
    required GroupUrlTestReadiness canRun,
    required GroupUrlTestAction run,
    Duration readinessRetryDelay = const Duration(milliseconds: 500),
    Duration readinessTimeout = const Duration(seconds: 30),
    Duration runRetryDelay = const Duration(seconds: 3),
    Duration retryFailedRunWithin = const Duration(seconds: 30),
    int maxRunAttempts = 1,
    GroupUrlTestSettled? onSettled,
  }) {
    if (_disposed) return;
    final generation = ++_generation;
    _timer?.cancel();
    _hasPendingWork = true;
    _pendingReason = reason;
    _arm(
      generation: generation,
      delay: delay,
      readinessWait: Stopwatch(),
      readinessRetryDelay: readinessRetryDelay,
      readinessTimeout: readinessTimeout,
      runRetryDelay: runRetryDelay,
      retryFailedRunWithin: retryFailedRunWithin,
      maxRunAttempts: maxRunAttempts < 1 ? 1 : maxRunAttempts,
      runAttempt: 1,
      canRun: canRun,
      run: run,
      onSettled: onSettled,
    );
  }

  void _arm({
    required int generation,
    required Duration delay,
    required Stopwatch readinessWait,
    required Duration readinessRetryDelay,
    required Duration readinessTimeout,
    required Duration runRetryDelay,
    required Duration retryFailedRunWithin,
    required int maxRunAttempts,
    required int runAttempt,
    required GroupUrlTestReadiness canRun,
    required GroupUrlTestAction run,
    required GroupUrlTestSettled? onSettled,
  }) {
    if (!_isCurrent(generation)) return;
    _timer = Timer(delay, () async {
      _timer = null;
      if (!_isCurrent(generation)) return;
      if (!canRun()) {
        if (!readinessWait.isRunning) {
          readinessWait.start();
        }
        if (readinessWait.elapsed < readinessTimeout) {
          final remaining = readinessTimeout - readinessWait.elapsed;
          final nextDelay = readinessRetryDelay < remaining
              ? readinessRetryDelay
              : remaining;
          _arm(
            generation: generation,
            delay: nextDelay,
            readinessWait: readinessWait,
            readinessRetryDelay: readinessRetryDelay,
            readinessTimeout: readinessTimeout,
            runRetryDelay: runRetryDelay,
            retryFailedRunWithin: retryFailedRunWithin,
            maxRunAttempts: maxRunAttempts,
            runAttempt: runAttempt,
            canRun: canRun,
            run: run,
            onSettled: onSettled,
          );
          return;
        }
        _finish(generation, success: false, onSettled: onSettled);
        return;
      }

      var success = false;
      final runWatch = Stopwatch()..start();
      try {
        success = await run();
      } catch (_) {
        success = false;
      }
      if (!_isCurrent(generation)) return;
      if (!success &&
          runAttempt < maxRunAttempts &&
          runWatch.elapsed <= retryFailedRunWithin) {
        _arm(
          generation: generation,
          delay: runRetryDelay,
          readinessWait: Stopwatch(),
          readinessRetryDelay: readinessRetryDelay,
          readinessTimeout: readinessTimeout,
          runRetryDelay: runRetryDelay,
          retryFailedRunWithin: retryFailedRunWithin,
          maxRunAttempts: maxRunAttempts,
          runAttempt: runAttempt + 1,
          canRun: canRun,
          run: run,
          onSettled: onSettled,
        );
        return;
      }
      _finish(generation, success: success, onSettled: onSettled);
    });
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _generation && _hasPendingWork;

  void _finish(
    int generation, {
    required bool success,
    required GroupUrlTestSettled? onSettled,
  }) {
    if (!_isCurrent(generation)) return;
    _timer = null;
    _hasPendingWork = false;
    _pendingReason = null;
    onSettled?.call(success);
  }

  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _hasPendingWork = false;
    _pendingReason = null;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
