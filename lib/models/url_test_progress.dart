class UrlTestProgressState {
  const UrlTestProgressState({
    this.isRunning = false,
    this.isCancelled = false,
    this.isPaused = false,
    this.isOfflineSession = false,
    this.total = 0,
    this.working = 0,
    this.failed = 0,
    this.completed,
  });

  static const idle = UrlTestProgressState();

  final bool isRunning;
  final bool isCancelled;
  final bool isPaused;
  final bool isOfflineSession;
  final int total;
  final int working;
  final int failed;
  final int? completed;

  int get tested => (completed ?? working + failed).clamp(0, total);
  int get pending => (total - tested).clamp(0, total);

  bool get hasResults => total > 0 && (isRunning || isCancelled || tested > 0);

  UrlTestProgressState copyWith({
    bool? isRunning,
    bool? isCancelled,
    bool? isPaused,
    bool? isOfflineSession,
    int? total,
    int? working,
    int? failed,
    int? completed,
  }) {
    return UrlTestProgressState(
      isRunning: isRunning ?? this.isRunning,
      isCancelled: isCancelled ?? this.isCancelled,
      isPaused: isPaused ?? this.isPaused,
      isOfflineSession: isOfflineSession ?? this.isOfflineSession,
      total: total ?? this.total,
      working: working ?? this.working,
      failed: failed ?? this.failed,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlTestProgressState &&
          runtimeType == other.runtimeType &&
          isRunning == other.isRunning &&
          isCancelled == other.isCancelled &&
          isPaused == other.isPaused &&
          isOfflineSession == other.isOfflineSession &&
          total == other.total &&
          working == other.working &&
          failed == other.failed &&
          completed == other.completed;

  @override
  int get hashCode => Object.hash(
    isRunning,
    isCancelled,
    isPaused,
    isOfflineSession,
    total,
    working,
    failed,
    completed,
  );
}

/// Keeps the proxy header totals current without rescanning a subscription for
/// every URLTest result. A full scan is needed only when the active testable
/// server set changes.
class UrlTestProgressCounter {
  Set<String> _tags = const <String>{};
  final Map<String, bool> _results = <String, bool>{};
  int _working = 0;
  int _failed = 0;
  int? _coreTotal;
  int _coreCompleted = 0;
  int _coreAvailable = 0;
  int _coreUnavailable = 0;
  bool _coreTerminal = false;

  void reset({
    required Iterable<String> visibleTags,
    required Set<String> testableTags,
    required bool? Function(String tag) resultForTag,
  }) {
    _tags = visibleTags.where(testableTags.contains).toSet();
    _results.clear();
    _working = 0;
    _failed = 0;
    _coreTotal = null;
    _coreCompleted = 0;
    _coreAvailable = 0;
    _coreUnavailable = 0;
    _coreTerminal = false;
    update(_tags, resultForTag);
  }

  /// The core counts concrete outbound probes. Its queue size is authoritative
  /// for a full run; subscription rows may include groups or skipped nodes.
  void applyCoreSessionSnapshot({
    required int total,
    required int completed,
    required int available,
    required int unavailable,
    bool terminal = false,
  }) {
    _coreTotal = total < 0 ? 0 : total;
    _coreCompleted = completed.clamp(0, _coreTotal!);
    _coreAvailable = available.clamp(0, _coreCompleted);
    _coreUnavailable = unavailable.clamp(0, _coreCompleted - _coreAvailable);
    _coreTerminal = terminal;
  }

  void update(
    Iterable<String> changedTags,
    bool? Function(String tag) resultForTag,
  ) {
    for (final tag in changedTags) {
      if (!_tags.contains(tag)) continue;
      final previous = _results[tag];
      final next = resultForTag(tag);
      if (previous == next) continue;
      if (_coreTerminal) {
        if (previous == true) _coreAvailable--;
        if (previous == false) _coreUnavailable--;
        if (next != null &&
            previous == null &&
            _coreCompleted < (_coreTotal ?? 0)) {
          _coreCompleted++;
        }
        if (next == true) _coreAvailable++;
        if (next == false) _coreUnavailable++;
        _coreAvailable = _coreAvailable.clamp(0, _coreCompleted);
        _coreUnavailable = _coreUnavailable.clamp(
          0,
          _coreCompleted - _coreAvailable,
        );
      }
      if (previous == true) _working--;
      if (previous == false) _failed--;
      if (next == null) {
        _results.remove(tag);
      } else {
        _results[tag] = next;
      }
      if (next == true) _working++;
      if (next == false) _failed++;
    }
  }

  UrlTestProgressState state({
    bool isRunning = false,
    bool isCancelled = false,
  }) => UrlTestProgressState(
    isRunning: isRunning,
    isCancelled: isCancelled,
    total: _coreTotal ?? _tags.length,
    working: _coreTotal == null ? _working : _coreAvailable,
    failed: _coreTotal == null ? _failed : _coreUnavailable,
    completed: _coreTotal == null ? null : _coreCompleted,
  );
}
