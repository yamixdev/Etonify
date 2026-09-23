class UrlTestProgressState {
  const UrlTestProgressState({
    this.isRunning = false,
    this.isCancelled = false,
    this.total = 0,
    this.working = 0,
    this.failed = 0,
  });

  static const idle = UrlTestProgressState();

  final bool isRunning;
  final bool isCancelled;
  final int total;
  final int working;
  final int failed;

  int get tested => (working + failed).clamp(0, total);
  int get pending => (total - tested).clamp(0, total);

  bool get hasResults => total > 0 && (isRunning || isCancelled || tested > 0);

  UrlTestProgressState copyWith({
    bool? isRunning,
    bool? isCancelled,
    int? total,
    int? working,
    int? failed,
  }) {
    return UrlTestProgressState(
      isRunning: isRunning ?? this.isRunning,
      isCancelled: isCancelled ?? this.isCancelled,
      total: total ?? this.total,
      working: working ?? this.working,
      failed: failed ?? this.failed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlTestProgressState &&
          runtimeType == other.runtimeType &&
          isRunning == other.isRunning &&
          isCancelled == other.isCancelled &&
          total == other.total &&
          working == other.working &&
          failed == other.failed;

  @override
  int get hashCode =>
      Object.hash(isRunning, isCancelled, total, working, failed);
}

/// Keeps the proxy header totals current without rescanning a subscription for
/// every URLTest result. A full scan is needed only when the active testable
/// server set changes.
class UrlTestProgressCounter {
  Set<String> _tags = const <String>{};
  final Map<String, bool> _results = <String, bool>{};
  int _working = 0;
  int _failed = 0;

  void reset({
    required Iterable<String> visibleTags,
    required Set<String> testableTags,
    required bool? Function(String tag) resultForTag,
  }) {
    _tags = visibleTags.where(testableTags.contains).toSet();
    _results.clear();
    _working = 0;
    _failed = 0;
    update(_tags, resultForTag);
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
    total: _tags.length,
    working: _working,
    failed: _failed,
  );
}
