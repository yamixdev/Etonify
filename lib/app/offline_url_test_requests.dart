/// Serializes ownership of the temporary runtime and coalesces row taps that
/// are already covered by its active request. Cancellation invalidates waiters,
/// while the owner still performs its normal native teardown.
class OfflineUrlTestRequests {
  Future<void>? _active;
  Set<String>? _activeTags;
  bool Function(Set<String>)? _extendActive;
  int _generation = 0;
  int _activeGeneration = 0;

  void cancelPending() => _generation++;

  Future<void> run({
    required Set<String>? tags,
    required bool Function() isCurrent,
    required Future<void> Function() execute,
    bool Function(Set<String>)? extend,
  }) async {
    final generation = _generation;
    while (_active != null) {
      final active = _active!;
      if (generation != _generation || !isCurrent()) return;
      if (generation == _activeGeneration &&
          tags != null &&
          (_activeTags == null ||
              _activeTags!.containsAll(tags) ||
              (tags.length == 1 && _extendActive?.call(tags) == true))) {
        _activeTags?.addAll(tags);
        await active;
        return;
      }
      await active;
      if (generation != _generation || !isCurrent()) return;
    }
    if (generation != _generation || !isCurrent()) return;
    _activeTags = tags == null ? null : Set.of(tags);
    _extendActive = extend;
    _activeGeneration = generation;
    final active = Future<void>.sync(execute);
    _active = active;
    try {
      await active;
    } finally {
      if (identical(_active, active)) {
        _active = null;
        _activeTags = null;
        _extendActive = null;
      }
    }
  }
}

/// Requests made during probe startup accumulate here. Once ready, the
/// owner forwards new tags to the same runtime and closes the batch on exit.
class OfflineUrlTestRowBatch {
  OfflineUrlTestRowBatch(Set<String> tags) : tags = Set.of(tags);

  final Set<String> tags;
  bool Function(Set<String>)? onAdditionalTags;
  bool _closed = false;

  bool add(Set<String> requested) {
    if (_closed) return false;
    final additional = requested.difference(tags);
    if (onAdditionalTags?.call(additional) == false) return false;
    tags.addAll(additional);
    return true;
  }

  void close() => _closed = true;
}
