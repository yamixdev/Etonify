import 'dart:async';

typedef GroupUrlTestReadiness = bool Function();
typedef GroupUrlTestAction = Future<bool> Function();

/// Owns the single debounced automatic URLTest slot.
///
/// Manual checks bypass this scheduler. A later automatic reason replaces an
/// earlier one, and a check that is no longer safe at fire time is discarded
/// instead of being queued behind the current native command.
class GroupUrlTestScheduler {
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  bool get isScheduled => _timer?.isActive ?? false;

  void schedule({
    required Duration delay,
    required GroupUrlTestReadiness canRun,
    required GroupUrlTestAction run,
  }) {
    if (_disposed) return;
    final generation = ++_generation;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      if (_disposed || generation != _generation || !canRun()) {
        return;
      }
      unawaited(run());
    });
  }

  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
