import 'dart:async';

typedef StartupLatencyDeadlineAction = void Function();

/// Gives native URLTest telemetry time to settle after a VPN service starts.
///
/// The configured probe timeout remains the main input. A small grace period
/// covers event delivery and UI scheduling without making a missing result stay
/// in the indeterminate state indefinitely.
Duration startupLatencyDeadlineDelay(int configuredTimeoutSeconds) {
  final timeoutSeconds =
      (configuredTimeoutSeconds <= 0 ? 15 : configuredTimeoutSeconds)
          .clamp(3, 30)
          .toInt();
  return Duration(seconds: timeoutSeconds + 5);
}

/// Owns the one-shot latency deadline for a single VPN service lifetime.
class StartupLatencyDeadlineController {
  Timer? _timer;
  int _generation = 0;
  bool _armedForService = false;
  bool _disposed = false;

  bool get isArmedForService => _armedForService;
  bool get isScheduled => _timer?.isActive ?? false;

  bool armOnce({
    required Duration delay,
    required StartupLatencyDeadlineAction onExpired,
  }) {
    if (_disposed || _armedForService) {
      return false;
    }
    _armedForService = true;
    final generation = ++_generation;
    _timer = Timer(delay, () {
      _timer = null;
      if (_disposed || generation != _generation || !_armedForService) {
        return;
      }
      onExpired();
    });
    return true;
  }

  void resetForNextService() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _armedForService = false;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    resetForNextService();
  }
}
