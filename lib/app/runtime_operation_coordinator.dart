class RuntimeOperationKey {
  const RuntimeOperationKey({
    required this.runtimeGeneration,
    required this.networkGeneration,
    required this.selectionGeneration,
    required this.diagnosticGeneration,
  });

  final int runtimeGeneration;
  final int networkGeneration;
  final int selectionGeneration;
  final int diagnosticGeneration;

  @override
  bool operator ==(Object other) =>
      other is RuntimeOperationKey &&
      other.runtimeGeneration == runtimeGeneration &&
      other.networkGeneration == networkGeneration &&
      other.selectionGeneration == selectionGeneration &&
      other.diagnosticGeneration == diagnosticGeneration;

  @override
  int get hashCode => Object.hash(
    runtimeGeneration,
    networkGeneration,
    selectionGeneration,
    diagnosticGeneration,
  );
}

/// Owns the generations shared by control and diagnostic runtime operations.
///
/// Native RPCs cannot always be physically cancelled. A generation change
/// therefore makes their eventual result stale and prevents it from updating
/// UI state, failure counters, backoff, or recovery decisions.
class RuntimeOperationCoordinator {
  int _runtimeGeneration = 0;
  int _networkGeneration = 0;
  int _selectionGeneration = 0;
  int _diagnosticGeneration = 0;
  int _urlTestGeneration = 0;
  int _nativeRuntimeGeneration = 0;
  bool _transitioning = false;
  bool _running = false;
  bool _networkUsable = false;
  bool _networkStateKnown = false;
  bool _groupsReady = false;
  String _selectedTag = '';

  int get diagnosticGeneration => _diagnosticGeneration;
  int get urlTestGeneration => _urlTestGeneration;
  int get nativeRuntimeGeneration => _nativeRuntimeGeneration;
  String get selectedTag => _selectedTag;
  bool get transitioning => _transitioning;
  bool get networkUsable => _networkUsable;
  bool get networkStateKnown => _networkStateKnown;
  bool get diagnosticsReady =>
      _running &&
      !_transitioning &&
      _networkUsable &&
      _groupsReady &&
      _selectedTag.isNotEmpty;
  bool get urlTestReady => _running && !_transitioning && _networkUsable;

  RuntimeOperationKey get currentKey => RuntimeOperationKey(
    runtimeGeneration: _runtimeGeneration,
    networkGeneration: _networkGeneration,
    selectionGeneration: _selectionGeneration,
    diagnosticGeneration: _diagnosticGeneration,
  );

  void beginRuntimeTransition() {
    if (!_transitioning) {
      _runtimeGeneration++;
    }
    _transitioning = true;
    _groupsReady = false;
    invalidateDiagnostics();
    invalidateUrlTests();
  }

  void updateRuntimeState({
    required bool running,
    required int nativeRuntimeGeneration,
  }) {
    _running = running;
    if (nativeRuntimeGeneration > 0 &&
        nativeRuntimeGeneration != _nativeRuntimeGeneration) {
      _nativeRuntimeGeneration = nativeRuntimeGeneration;
      _runtimeGeneration++;
      _groupsReady = false;
      invalidateDiagnostics();
      invalidateUrlTests();
    }
    if (!running) {
      _groupsReady = false;
      invalidateDiagnostics();
      invalidateUrlTests();
    }
  }

  void finishRuntimeTransition({required bool running}) {
    _transitioning = false;
    _running = running;
    if (!running) {
      _groupsReady = false;
    }
  }

  void updateNetwork({required int generation, required bool usable}) {
    final changed = generation != _networkGeneration;
    _networkGeneration = generation;
    _networkStateKnown = true;
    _networkUsable = usable;
    if (changed || !usable) {
      invalidateDiagnostics();
      invalidateUrlTests();
    }
  }

  void beginSelection(String tag) {
    _selectionGeneration++;
    _selectedTag = tag.trim();
    _groupsReady = false;
    invalidateDiagnostics();
  }

  void synchronizeSelection(String tag) {
    final normalized = tag.trim();
    if (normalized == _selectedTag) {
      return;
    }
    beginSelection(normalized);
  }

  /// Returns false only for a snapshot known to belong to an old runtime.
  bool acceptGroupsSnapshot({
    required int nativeRuntimeGeneration,
    required String selectedTag,
  }) {
    if (nativeRuntimeGeneration > 0 &&
        _nativeRuntimeGeneration > 0 &&
        nativeRuntimeGeneration != _nativeRuntimeGeneration) {
      return false;
    }
    if (!_running || _transitioning) {
      return false;
    }
    final canonicalSelected = selectedTag.trim();
    _groupsReady = _selectedTag.isNotEmpty && canonicalSelected == _selectedTag;
    return true;
  }

  void invalidateDiagnostics() {
    _diagnosticGeneration++;
  }

  void invalidateUrlTests() {
    _urlTestGeneration++;
  }

  bool isCurrent(RuntimeOperationKey key) => key == currentKey;
}
