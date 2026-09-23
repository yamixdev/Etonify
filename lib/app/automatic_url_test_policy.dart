enum AutomaticUrlTestScope { none, selected, full }

/// A disabled full sweep still permits a cheap probe of the active route.
/// Never turn a missing targeted API into a full sweep behind the user's back.
AutomaticUrlTestScope automaticUrlTestScope({
  required String reason,
  required bool autoCheckServers,
  required bool supportsTargeted,
  required String selectedTag,
}) {
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

  bool take() {
    final pending = _pending;
    _pending = false;
    return pending;
  }

  void clear() => _pending = false;
}
