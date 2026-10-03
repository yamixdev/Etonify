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

  int get tested =>
      (completed == null || completed! < working + failed
              ? working + failed
              : completed!)
          .clamp(0, total);
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
  Object? _catalogKey;
  Object? _scopeKey;
  bool _catalogInitialized = false;

  /// Hydration can arrive after the first targeted probe. Initialize the
  /// catalog independently of full sweeps, and scan it only when it changes.
  void synchronizeCatalog({
    Object? scopeKey,
    bool catalogComplete = true,
    required Object? catalogKey,
    required Iterable<String> Function() visibleTags,
    required Set<String> Function() testableTags,
    required bool? Function(String tag) resultForTag,
  }) {
    // A same-profile reload first exposes metadata, not an empty payload.
    // Keep this sweep intact until hydration supplies the actual membership.
    if (_catalogInitialized && _scopeKey == scopeKey && !catalogComplete) {
      return;
    }
    if (_catalogInitialized &&
        _scopeKey == scopeKey &&
        _catalogKey == catalogKey) {
      return;
    }
    final nextVisibleTags = visibleTags().toSet();
    // Outbound metadata (ping, IP or country) can replace the source list
    // during a sweep. Membership, not list identity, owns its progress.
    if (_catalogInitialized &&
        _scopeKey == scopeKey &&
        nextVisibleTags.length == _visibleTags.length &&
        nextVisibleTags.containsAll(_visibleTags)) {
      _catalogKey = catalogKey;
      return;
    }
    reset(
      visibleTags: nextVisibleTags,
      testableTags: testableTags(),
      resultForTag: resultForTag,
      includeKnownVisibleResults: true,
    );
    _catalogKey = catalogKey;
    _scopeKey = scopeKey;
    _catalogInitialized = true;
  }

  Set<String> _visibleTags = const <String>{};
  Set<String> _tags = const <String>{};
  final Map<String, bool> _results = <String, bool>{};
  final Set<String> _additionalCompletedTags = <String>{};
  int _working = 0;
  int _failed = 0;
  int? _coreTotal;
  int _coreCompleted = 0;

  void reset({
    required Iterable<String> visibleTags,
    required Set<String> testableTags,
    required bool? Function(String tag) resultForTag,
    bool includeKnownVisibleResults = false,
  }) {
    _visibleTags = visibleTags.toSet();
    _tags = _visibleTags.where(testableTags.contains).toSet();
    _results.clear();
    _additionalCompletedTags.clear();
    _working = 0;
    _failed = 0;
    _coreTotal = null;
    _coreCompleted = 0;
    update(_tags, resultForTag);
    if (includeKnownVisibleResults) {
      update(_visibleTags, resultForTag);
    }
  }

  /// The core reports completed concrete probes. The header can include more
  /// visible nodes than the queue, so skipped nodes remain pending.
  void applyCoreSessionSnapshot({required int total, required int completed}) {
    _coreTotal = total < 0 ? 0 : total;
    _coreCompleted = completed.clamp(0, _coreTotal!);
  }

  void update(
    Iterable<String> changedTags,
    bool? Function(String tag) resultForTag,
  ) {
    for (final tag in changedTags) {
      if (!_tags.contains(tag)) {
        if (!_visibleTags.contains(tag) || resultForTag(tag) == null) continue;
        _tags.add(tag);
        _additionalCompletedTags.add(tag);
      }
      final previous = _results[tag];
      final next = resultForTag(tag);
      if (previous == next) continue;
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
    total: _coreTotal == null
        ? _visibleTags.length
        : (_coreTotal! > _visibleTags.length
              ? _coreTotal!
              : _visibleTags.length),
    // Count only individually measured nodes, not synthetic group rows.
    working: _working,
    failed: _failed,
    completed: _coreTotal == null
        ? null
        : _coreCompleted + _additionalCompletedTags.length,
  );
}
