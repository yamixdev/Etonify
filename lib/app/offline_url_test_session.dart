enum OfflineUrlTestPhase {
  preparing,
  runningOffline,
  pausingForVpn,
  runningVpn,
  completed,
  cancelled,
  failed,
}

class OfflineUrlTestMeasurement {
  const OfflineUrlTestMeasurement({
    required this.delayMillis,
    required this.available,
  });

  final int delayMillis;
  final bool available;
}

/// One user-initiated sweep can span two separate native runtimes. The
/// completed measurements live here, never in the lifetime of either runtime.
class OfflineUrlTestSession {
  OfflineUrlTestSession({
    required this.id,
    required this.fingerprint,
    required this.physicalNetworkEpoch,
    required Set<String> tags,
  }) : _tags = Set<String>.of(tags);

  final String id;
  final String fingerprint;
  final Set<String> _tags;
  final Map<String, OfflineUrlTestMeasurement> _measurements = {};
  int _working = 0;
  int physicalNetworkEpoch;
  OfflineUrlTestPhase phase = OfflineUrlTestPhase.preparing;
  String? failureReason;

  int get total => _tags.length;
  int get completed => _measurements.length;
  int get working => _working;
  int get failed => completed - working;
  bool get isTerminal =>
      phase == OfflineUrlTestPhase.completed ||
      phase == OfflineUrlTestPhase.cancelled ||
      phase == OfflineUrlTestPhase.failed;
  Set<String> get pendingTags => _tags.difference(_measurements.keys.toSet());
  Map<String, OfflineUrlTestMeasurement> get measurements =>
      Map<String, OfflineUrlTestMeasurement>.unmodifiable(_measurements);

  bool accept({
    required String tag,
    required int delayMillis,
    required bool available,
    required String logicalSessionId,
    required int physicalNetworkEpoch,
  }) {
    if (isTerminal ||
        phase == OfflineUrlTestPhase.pausingForVpn ||
        logicalSessionId != id ||
        physicalNetworkEpoch != this.physicalNetworkEpoch ||
        !_tags.contains(tag) ||
        _measurements.containsKey(tag)) {
      return false;
    }
    _measurements[tag] = OfflineUrlTestMeasurement(
      delayMillis: delayMillis,
      available: available,
    );
    if (available) _working++;
    if (_measurements.length == _tags.length) {
      phase = OfflineUrlTestPhase.completed;
    }
    return true;
  }

  void runOffline() {
    if (!isTerminal) phase = OfflineUrlTestPhase.runningOffline;
  }

  void pauseForVpn() {
    if (!isTerminal) phase = OfflineUrlTestPhase.pausingForVpn;
  }

  void resumeOnVpn() {
    if (!isTerminal) phase = OfflineUrlTestPhase.runningVpn;
  }

  /// Returns whether prior measurements still describe the current route.
  /// An actual physical handover resets measurements; a TUN appearance does not
  /// change the app-owned epoch and therefore keeps them.
  bool reconcile({
    required String fingerprint,
    required int physicalNetworkEpoch,
  }) {
    if (fingerprint != this.fingerprint) {
      fail('probe_config_changed');
      return false;
    }
    if (physicalNetworkEpoch == this.physicalNetworkEpoch) return true;
    this.physicalNetworkEpoch = physicalNetworkEpoch;
    _measurements.clear();
    _working = 0;
    if (!isTerminal) phase = OfflineUrlTestPhase.preparing;
    return false;
  }

  void cancel() {
    if (!isTerminal) phase = OfflineUrlTestPhase.cancelled;
  }

  void fail(String reason) {
    if (isTerminal) return;
    failureReason = reason;
    phase = OfflineUrlTestPhase.failed;
  }
}
