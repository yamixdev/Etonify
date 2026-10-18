/// Serializes ownership of the temporary runtime and coalesces row taps that
/// are already covered by its active request. Cancellation invalidates waiters,
/// while the owner still performs its normal native teardown.
class OfflineUrlTestRequests {
  Future<void>? _active;
  Set<String>? _activeTags;
  int _generation = 0;
  int _activeGeneration = 0;

  void cancelPending() => _generation++;

  Future<void> run({
    required Set<String>? tags,
    required bool Function() isCurrent,
    required Future<void> Function() execute,
  }) async {
    final generation = _generation;
    while (_active != null) {
      final active = _active!;
      if (generation == _activeGeneration &&
          tags != null &&
          (_activeTags == null || _activeTags!.containsAll(tags))) {
        await active;
        return;
      }
      await active;
      if (generation != _generation || !isCurrent()) return;
    }
    if (generation != _generation || !isCurrent()) return;
    _activeTags = tags == null ? null : Set.of(tags);
    _activeGeneration = generation;
    final active = Future<void>.sync(execute);
    _active = active;
    try {
      await active;
    } finally {
      if (identical(_active, active)) {
        _active = null;
        _activeTags = null;
      }
    }
  }
}
