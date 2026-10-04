import '../models/url_test_progress.dart';

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
    Set<String>? visibleTags,
    Map<String, bool> initialResults = const {},
  }) : _tags = Set<String>.of(tags),
       _visibleTags = Set<String>.of(visibleTags ?? tags)..addAll(tags) {
    for (final entry in initialResults.entries) {
      if (!_visibleTags.contains(entry.key)) continue;
      _latestResults[entry.key] = entry.value;
      if (entry.value) {
        _working++;
      } else {
        _failed++;
      }
    }
  }

  final String id;
  final String fingerprint;
  final Set<String> _tags;
  // A runtime can skip an unusable leaf without changing the catalog size.
  // Only _tags own queue completion; the header uses the full visible set.
  final Set<String> _visibleTags;
  final Map<String, OfflineUrlTestMeasurement> _measurements = {};
  final Map<String, bool> _latestResults = {};
  int _working = 0;
  int _failed = 0;
  int physicalNetworkEpoch;
  OfflineUrlTestPhase phase = OfflineUrlTestPhase.preparing;
  String? failureReason;

  int get total => _visibleTags.length;
  int get completed => _measurements.length;
  int get working => _working;
  int get failed => _failed;
  Map<String, bool> get latestResults => Map.unmodifiable(_latestResults);
  bool get isTerminal =>
      phase == OfflineUrlTestPhase.completed ||
      phase == OfflineUrlTestPhase.cancelled ||
      phase == OfflineUrlTestPhase.failed;
  Set<String> get pendingTags => _tags.difference(_measurements.keys.toSet());
  Map<String, OfflineUrlTestMeasurement> get measurements =>
      Map<String, OfflineUrlTestMeasurement>.unmodifiable(_measurements);

  /// Results belong to the logical sweep, even after its native probe and
  /// temporary config have been disposed.
  UrlTestProgressState get progress => UrlTestProgressState(
    isRunning: !isTerminal,
    isCancelled: phase == OfflineUrlTestPhase.cancelled,
    isPaused: phase == OfflineUrlTestPhase.pausingForVpn,
    isOfflineSession: true,
    showCheckProgress: !isTerminal,
    total: total,
    working: working,
    failed: failed,
    completed: completed,
  );

  bool suppressesAutomaticCheck({
    required String reason,
    required int physicalNetworkEpoch,
  }) =>
      phase == OfflineUrlTestPhase.completed &&
      this.physicalNetworkEpoch == physicalNetworkEpoch &&
      (reason == 'runtime_diagnostics_ready' ||
          reason == 'network_changed' ||
          reason == 'selection' ||
          reason == 'resume_deferred');

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
    final previous = _latestResults[tag];
    if (previous == true) _working--;
    if (previous == false) _failed--;
    _latestResults[tag] = available;
    if (available) {
      _working++;
    } else {
      _failed++;
    }
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
    _latestResults.clear();
    _working = 0;
    _failed = 0;
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
