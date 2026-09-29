enum AutomaticUrlTestScope { none, selected, full }

/// A disabled full sweep still permits a cheap probe of the active route.
/// Never turn a missing targeted API into a full sweep behind the user's back.
AutomaticUrlTestScope automaticUrlTestScope({
  required String reason,
  required bool autoCheckServers,
  required bool supportsTargeted,
  required String selectedTag,
}) {
  if (reason == 'selection') {
    if (!supportsTargeted || selectedTag.trim().isEmpty) {
      return AutomaticUrlTestScope.none;
    }
    return AutomaticUrlTestScope.selected;
  }
  if (autoCheckServers) return AutomaticUrlTestScope.full;
  if (reason == 'periodic' || !supportsTargeted || selectedTag.trim().isEmpty) {
    return AutomaticUrlTestScope.none;
  }
  return AutomaticUrlTestScope.selected;
}

/// Holds one automatic check while the UI is backgrounded. Repeated native
/// network callbacks collapse into a single foreground request.
class DeferredAutomaticUrlTest {
  bool _pending = false;

  void defer() => _pending = true;

  /// A periodic timer is not a missed event, and an active core sweep does
  /// not need a duplicate foreground request.
  void deferPending({
    required String? reason,
    required bool fullSessionRunning,
  }) {
    if (reason != null && reason != 'periodic' && !fullSessionRunning) {
      defer();
    }
  }

  bool take({bool fullSessionRunning = false}) {
    final pending = _pending;
    _pending = false;
    return pending && !fullSessionRunning;
  }

  void clear() => _pending = false;
}

/// Keeps the next periodic check anchored while it is pending. A check missed
/// while the UI was backgrounded starts a fresh interval on resume instead of
/// immediately repeating a long full sweep.
class PeriodicUrlTestDeadline {
  DateTime? _dueAt;

  Duration remaining({required DateTime now, required Duration interval}) {
    final dueAt = _dueAt;
    if (dueAt == null || !now.isBefore(dueAt)) {
      _dueAt = now.add(interval);
      return interval;
    }
    return dueAt.difference(now);
  }

  void reset({required DateTime now, required Duration interval}) {
    _dueAt = now.add(interval);
  }

  void clear() => _dueAt = null;
}
