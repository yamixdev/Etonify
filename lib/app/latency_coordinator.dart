import 'dart:async';
import 'dart:math';

import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';

enum LatencySessionKind { full, targeted }

enum LatencySessionPhase { idle, startingRpc, collectingEvents, settled }

class LatencyUiPolicy {
  const LatencyUiPolicy({
    this.rpcAckTimeout = const Duration(seconds: 5),
    this.initialEventTimeout = const Duration(seconds: 12),
    this.eventInactivityTimeout = const Duration(seconds: 12),
    this.hardWatchdog = const Duration(minutes: 30),
  });

  /// These values bound UI state only. They never delay command dispatch or
  /// fresh native results.
  final Duration rpcAckTimeout;
  final Duration initialEventTimeout;
  final Duration eventInactivityTimeout;
  final Duration hardWatchdog;
}

class LatencyTestRequest {
  const LatencyTestRequest({
    this.groupTag = 'select',
    this.targetOutboundTag = '',
    this.priorityOutboundTag = '',
    this.excludeOutboundTag = '',
    required this.url,
    this.timeoutMillis = 3000,
    this.concurrency = 0,
    this.deadlineMillis = 10000,
    this.force = true,
    this.mode = 'background',
    this.includeOutboundTags = const <String>[],
    this.logicalSessionId = '',
    this.physicalNetworkEpoch = 0,
  });

  final String groupTag;
  final String targetOutboundTag;
  final String priorityOutboundTag;
  final String excludeOutboundTag;
  final String url;
  final int timeoutMillis;
  final int concurrency;
  final int deadlineMillis;
  final bool force;
  final String mode;
  final List<String> includeOutboundTags;
  final String logicalSessionId;
  final int physicalNetworkEpoch;
}

typedef LatencyTestRunner = Future<void> Function(LatencyTestRequest request);
typedef LatencyCancelRunner =
    Future<void> Function(String groupTag, String targetOutboundTag);
typedef LatencyBoolReader = bool Function();
typedef LatencyStringReader = String Function();
typedef LatencyIntReader = int Function();
typedef LatencyEventTimesReader = Map<String, int> Function();
typedef LatencyExpectedTagsReader = Iterable<String> Function();
typedef LatencySessionChanged =
    void Function(bool running, LatencySessionKind? kind, String targetTag);

class _ActiveTargetCheck {
  _ActiveTargetCheck({
    required this.startedAtSeconds,
    required this.baselineTimeSeconds,
  });

  final int startedAtSeconds;
  final int baselineTimeSeconds;
  Timer? timeoutTimer;
}

class LatencyCoordinator {
  LatencyCoordinator({
    required LatencyTestRunner runTest,
    LatencyCancelRunner? cancelTest,
    required LatencyBoolReader isConnected,
    required LatencyBoolReader isForeground,
    required LatencyStringReader activeOutboundTag,
    required LatencyStringReader testUrl,
    required LatencyIntReader outboundCount,
    required LatencyIntReader timeoutSeconds,
    required LatencyIntReader concurrency,
    required LatencySessionChanged onSessionChanged,
    LatencyBoolReader? canRunDiagnostics,
    LatencyIntReader? operationGeneration,
    LatencyEventTimesReader? eventBaselineTimes,
    LatencyExpectedTagsReader? expectedTags,
    LibboxCapabilities capabilities = LibboxCapabilities.bundledLegacy,
    this.uiPolicy = const LatencyUiPolicy(),
  }) : _runTest = runTest,
       _cancelTest = cancelTest,
       _isConnected = isConnected,
       _isForeground = isForeground,
       _activeOutboundTag = activeOutboundTag,
       _testUrl = testUrl,
       _outboundCount = outboundCount,
       _timeoutSeconds = timeoutSeconds,
       _concurrency = concurrency,
       _onSessionChanged = onSessionChanged,
       _canRunDiagnostics = canRunDiagnostics ?? _alwaysReady,
       _operationGeneration = operationGeneration ?? _zeroGeneration,
       _eventBaselineTimes = eventBaselineTimes ?? _emptyEventTimes,
       _expectedTags = expectedTags ?? _emptyExpectedTags,
       _capabilities = capabilities;

  static const _defaultTimeoutMillis = 15000;
  static const _minimumTimeoutMillis = 500;
  static const _maximumTimeoutMillis = 30000;
  static const _defaultConcurrency = 10;
  static const _maximumConcurrency = 16;
  static const _maximumDeadlineMillis = 1800000;

  final LatencyTestRunner _runTest;
  final LatencyCancelRunner? _cancelTest;
  final LatencyBoolReader _isConnected;
  final LatencyBoolReader _isForeground;
  final LatencyStringReader _activeOutboundTag;
  final LatencyStringReader _testUrl;
  final LatencyIntReader _outboundCount;
  final LatencyIntReader _timeoutSeconds;
  final LatencyIntReader _concurrency;
  final LatencySessionChanged _onSessionChanged;
  final LatencyBoolReader _canRunDiagnostics;
  final LatencyIntReader _operationGeneration;
  final LatencyEventTimesReader _eventBaselineTimes;
  final LatencyExpectedTagsReader _expectedTags;
  LibboxCapabilities _capabilities;
  final LatencyUiPolicy uiPolicy;

  static bool _alwaysReady() => true;
  static int _zeroGeneration() => 0;
  static Map<String, int> _emptyEventTimes() => const <String, int>{};
  static Iterable<String> _emptyExpectedTags() => const <String>[];

  Timer? _firstEventTimer;
  Timer? _settleTimer;
  Timer? _watchdogTimer;
  bool _disposed = false;
  int _generation = 0;
  int _sessionOperationGeneration = 0;
  int _sessionStartedAtSeconds = 0;
  LatencySessionPhase _phase = LatencySessionPhase.idle;
  LatencySessionKind? _kind;
  String _targetTag = '';
  Map<String, int> _baselineEventTimes = const <String, int>{};
  Set<String> _sessionExpectedTags = const <String>{};
  final Map<String, int> _acceptedEventTimes = <String, int>{};
  final Set<String> _successfulTags = <String>{};
  final Map<String, int> _acceptedResultRevisions = <String, int>{};
  final Set<String> _provisionalResultTags = <String>{};
  final Set<String> _rejectedProvisionalTags = <String>{};
  final Map<String, _ActiveTargetCheck> _activeTargetChecks =
      <String, _ActiveTargetCheck>{};
  Completer<bool>? _sessionResult;
  Completer<void>? _nativeSessionFinished;
  int _nativeSessionId = 0;

  /// True when [_nativeSessionId] was inferred from a result rather than from
  /// the session's own `running` event. Only meaningful while the identifier is
  /// non-zero: every write of an identifier also sets or clears this flag.
  bool _nativeSessionIdPinnedByResult = false;
  String _sessionMode = '';
  String _sessionReason = '';

  bool get _usesSessionEvents =>
      _capabilities.urlTestCompletionModel ==
          UrlTestCompletionModel.sessionEvents &&
      _capabilities.supportsUrlTestDeltaStream &&
      _capabilities.supportsUrlTestSessionStatus;

  bool get isRunning =>
      _phase == LatencySessionPhase.startingRpc ||
      _phase == LatencySessionPhase.collectingEvents;
  bool get awaitingCoreSession =>
      _usesSessionEvents && isRunning && _nativeSessionId == 0;
  bool hasActiveTargetCheck(String tag) =>
      _activeTargetChecks.containsKey(tag.trim());
  bool get canStartSession =>
      !_disposed && !isRunning && _nativeSessionFinished == null;
  bool get isCurrentSessionManual =>
      isRunning && _sessionReason.startsWith('manual');
  bool get isCurrentSessionAutomatic =>
      isRunning && !_sessionReason.startsWith('manual');

  void cancelAutomaticSession() {
    if (isCurrentSessionAutomatic) {
      cancel();
    }
  }

  LatencySessionKind? get kind => isRunning ? _kind : null;
  LatencySessionPhase get phase => _phase;
  int get sessionStartedAtSeconds => _sessionStartedAtSeconds;
  LibboxCapabilities get capabilities => _capabilities;

  void updateCapabilities(LibboxCapabilities value) {
    if (identical(_capabilities, value)) return;
    if (isRunning) {
      cancel();
    }
    _capabilities = value;
  }

  bool isChecking(String rawTag) {
    final tag = rawTag.trim();
    if (tag.isEmpty) return false;
    if (_activeTargetChecks.containsKey(tag)) {
      return true;
    }
    if (!isRunning) return false;
    if (_targetTag.isNotEmpty) {
      return _targetTag == tag && !_acceptedEventTimes.containsKey(tag);
    }
    if (_sessionExpectedTags.isEmpty) {
      return !_acceptedEventTimes.containsKey(tag);
    }
    return _sessionExpectedTags.contains(tag) &&
        !_acceptedEventTimes.containsKey(tag);
  }

  bool shouldIgnoreGroupResult(String rawTag, int timeSeconds) {
    final tag = rawTag.trim();
    if (tag.isEmpty || timeSeconds <= 0) {
      return false;
    }
    final activeCheck = _activeTargetChecks[tag];
    if (activeCheck != null) {
      final baseline = activeCheck.baselineTimeSeconds;
      return timeSeconds < activeCheck.startedAtSeconds ||
          (baseline > 0 && timeSeconds <= baseline);
    }
    if (!isRunning || !_sessionExpectedTags.contains(tag)) {
      return false;
    }
    final baseline = _baselineEventTimes[tag] ?? 0;
    return timeSeconds < _sessionStartedAtSeconds ||
        (baseline > 0 && timeSeconds <= baseline) ||
        timeSeconds <= (_acceptedEventTimes[tag] ?? 0);
  }

  Future<bool> runFull({
    required String reason,
    String mode = 'manual',
    List<String> includeOutboundTags = const <String>[],
    String logicalSessionId = '',
    int physicalNetworkEpoch = 0,
  }) {
    return _runGroupSession(
      kind: LatencySessionKind.full,
      reason: reason,
      mode: mode,
      includeOutboundTags: includeOutboundTags,
      logicalSessionId: logicalSessionId,
      physicalNetworkEpoch: physicalNetworkEpoch,
    );
  }

  Future<bool> runTarget({
    required String targetOutboundTag,
    required String reason,
    bool force = true,
  }) {
    final targetTag = targetOutboundTag.trim();
    if (targetTag.isEmpty || !_capabilities.supportsTargetedUrlTest) {
      AppLogStore.warning(
        'latency',
        'targeted URLTest skipped reason=$reason target=$targetTag '
            'supported=${_capabilities.supportsTargetedUrlTest}',
      );
      return Future<bool>.value(false);
    }
    if (isRunning) {
      if (_kind != LatencySessionKind.full ||
          !_isConnected() ||
          !_isForeground() ||
          !_canRunDiagnostics()) {
        return Future<bool>.value(false);
      }
      return _runParallelTarget(
        targetTag: targetTag,
        reason: reason,
        force: force,
      );
    }
    return _runSession(
      kind: LatencySessionKind.targeted,
      reason: reason,
      targetTag: targetTag,
      request: LatencyTestRequest(
        // Resolve targets under the root selector, including a node outside
        // the currently selected provider group. The core refreshes nested
        // URLTest selections without changing the user's root selection.
        groupTag: 'select',
        targetOutboundTag: targetTag,
        priorityOutboundTag: targetTag,
        url: _testUrl(),
        timeoutMillis: _configuredTimeoutMillis,
        concurrency: 1,
        deadlineMillis: _targetDeadlineMillis,
        force: force,
        mode: 'targeted',
      ),
    );
  }

  Future<bool> _runParallelTarget({
    required String targetTag,
    required String reason,
    required bool force,
  }) async {
    if (_activeTargetChecks.containsKey(targetTag)) {
      return true;
    }
    final generation = _generation;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final check = _ActiveTargetCheck(
      startedAtSeconds: nowSeconds,
      baselineTimeSeconds: _eventBaselineTimes()[targetTag] ?? 0,
    );
    check.timeoutTimer = Timer(
      Duration(milliseconds: _targetDeadlineMillis),
      () {
        if (_activeTargetChecks[targetTag] == check) {
          _activeTargetChecks.remove(targetTag);
          _onSessionChanged(isRunning, _kind, _targetTag);
        }
      },
    );
    _activeTargetChecks[targetTag] = check;
    _onSessionChanged(isRunning, _kind, _targetTag);

    try {
      await _runTest(
        LatencyTestRequest(
          groupTag: 'select',
          targetOutboundTag: targetTag,
          priorityOutboundTag: targetTag,
          url: _testUrl(),
          timeoutMillis: _configuredTimeoutMillis,
          concurrency: 1,
          deadlineMillis: _targetDeadlineMillis,
          force: force,
          mode: 'targeted',
        ),
      ).timeout(uiPolicy.rpcAckTimeout);
      return _isActiveGeneration(generation);
    } catch (error) {
      AppLogStore.warning(
        'latency',
        'parallel targeted URLTest failed: $error',
      );
      check.timeoutTimer?.cancel();
      if (_activeTargetChecks[targetTag] == check) {
        _activeTargetChecks.remove(targetTag);
        _onSessionChanged(isRunning, _kind, _targetTag);
      }
      return false;
    }
  }

  /// Records one timestamped result from the command client's group stream.
  /// Cached snapshots from before this session and duplicate events are
  /// ignored, so they cannot keep the progress UI alive indefinitely.
  bool handleGroupEvent({
    required String tag,
    required int timeSeconds,
    required bool available,
  }) {
    final normalizedTag = tag.trim();
    if (normalizedTag.isEmpty || timeSeconds <= 0) {
      return false;
    }
    final activeCheck = _activeTargetChecks[normalizedTag];
    if (activeCheck == null &&
        (!isRunning ||
            (_sessionExpectedTags.isNotEmpty &&
                !_sessionExpectedTags.contains(normalizedTag)))) {
      return false;
    }
    final baseline =
        activeCheck?.baselineTimeSeconds ??
        (_baselineEventTimes[normalizedTag] ?? 0);
    final startedAt = activeCheck?.startedAtSeconds ?? _sessionStartedAtSeconds;
    if (timeSeconds < startedAt || (baseline > 0 && timeSeconds <= baseline)) {
      return false;
    }
    if (activeCheck != null) {
      activeCheck.timeoutTimer?.cancel();
      _activeTargetChecks.remove(normalizedTag);
      _onSessionChanged(isRunning, _kind, _targetTag);
    }
    if (!isRunning) {
      return activeCheck != null;
    }
    if (_operationGeneration() != _sessionOperationGeneration ||
        !_isConnected() ||
        !_canRunDiagnostics()) {
      _settleCurrent(success: false, reason: 'stale_runtime');
      return false;
    }
    if (activeCheck == null &&
        timeSeconds <= (_acceptedEventTimes[normalizedTag] ?? 0)) {
      return false;
    }
    _acceptedEventTimes[normalizedTag] = timeSeconds;
    if (available) {
      _successfulTags.add(normalizedTag);
    } else {
      _successfulTags.remove(normalizedTag);
    }
    _phase = LatencySessionPhase.collectingEvents;
    _firstEventTimer?.cancel();
    _firstEventTimer = null;
    if (_sessionExpectedTags.isNotEmpty &&
        _sessionExpectedTags.every(_acceptedEventTimes.containsKey)) {
      _settleCurrent(
        success: _successfulTags.isNotEmpty,
        reason: 'all_expected_results',
      );
      return true;
    }
    // Silence does not mean completion while known targets are still queued.
    // A slow batch may take longer than the inactivity timeout; retain its
    // checking state until results arrive or the bounded session deadline.
    if (_sessionExpectedTags.isNotEmpty) return true;
    _settleTimer?.cancel();
    final generation = _generation;
    _settleTimer = Timer(uiPolicy.eventInactivityTimeout, () {
      if (generation != _generation) return;
      _settleCurrent(
        success: _successfulTags.isNotEmpty,
        reason: 'event_stream_settled',
      );
    });
    return true;
  }

  /// Accepts a URLTest v3 result by monotonic native revision. Unlike the
  /// legacy group stream, this path never compares wall-clock seconds.
  bool handleCoreResult({
    required String tag,
    required int sessionId,
    required int revision,
    required bool available,
  }) {
    final normalizedTag = tag.trim();
    if (!_usesSessionEvents ||
        normalizedTag.isEmpty ||
        sessionId <= 0 ||
        revision <= 0) {
      return false;
    }
    final activeCheck = _activeTargetChecks[normalizedTag];
    if (isRunning && _nativeSessionId == 0 && activeCheck == null) {
      // Results can reach the client before the session's `running` event does.
      // Pin the identifier from the first one so those measurements are not
      // discarded; the `running` event still overrides this guess below.
      _nativeSessionId = sessionId;
      _nativeSessionIdPinnedByResult = true;
    }
    final belongsToMainSession = isRunning && sessionId == _nativeSessionId;

    if (!belongsToMainSession && activeCheck == null) {
      return false;
    }
    if (revision <= (_acceptedResultRevisions[normalizedTag] ?? 0)) {
      return false;
    }
    _acceptedResultRevisions[normalizedTag] = revision;
    if (belongsToMainSession) {
      if (_nativeSessionIdPinnedByResult) {
        _provisionalResultTags.add(normalizedTag);
      } else {
        _rejectedProvisionalTags.remove(normalizedTag);
      }
    }
    if (activeCheck != null) {
      activeCheck.timeoutTimer?.cancel();
      _activeTargetChecks.remove(normalizedTag);
      _onSessionChanged(isRunning, _kind, _targetTag);
    }
    if (isRunning) {
      _acceptedEventTimes[normalizedTag] = revision;
      if (available) {
        _successfulTags.add(normalizedTag);
      } else {
        _successfulTags.remove(normalizedTag);
      }
      _phase = LatencySessionPhase.collectingEvents;
      if (belongsToMainSession && _sessionMode == 'manual') {
        // An exhaustive sweep can outlive the absolute UI watchdog on large
        // subscriptions. Only silence, not total elapsed time, is a stall.
        _armWatchdog(uiPolicy.hardWatchdog);
      }
    }
    return true;
  }

  bool handleCoreSession({
    required int sessionId,
    required String groupTag,
    required String targetTag,
    required String mode,
    required String state,
    required String terminalReason,
    required int available,
  }) {
    if (!_usesSessionEvents || !isRunning || groupTag != 'select') {
      return false;
    }
    if (_kind == LatencySessionKind.targeted &&
        targetTag.trim() != _targetTag) {
      return false;
    }
    if (_kind == LatencySessionKind.full && mode != _sessionMode) {
      return false;
    }
    if (state == 'running') {
      if (sessionId <= 0) return false;
      if (_nativeSessionId != 0 &&
          _nativeSessionId != sessionId &&
          !_nativeSessionIdPinnedByResult) {
        return false;
      }
      if (_nativeSessionIdPinnedByResult && _nativeSessionId != sessionId) {
        for (final tag in _provisionalResultTags) {
          _acceptedEventTimes.remove(tag);
          _successfulTags.remove(tag);
          _acceptedResultRevisions.remove(tag);
        }
        _rejectedProvisionalTags.addAll(_provisionalResultTags);
      }
      _provisionalResultTags.clear();
      _nativeSessionId = sessionId;
      _nativeSessionIdPinnedByResult = false;
      _phase = LatencySessionPhase.collectingEvents;
      return true;
    }
    if (_nativeSessionId == 0 ||
        sessionId <= 0 ||
        sessionId != _nativeSessionId) {
      return false;
    }
    if (state != 'completed' && state != 'cancelled') {
      return false;
    }
    _settleCurrent(
      success: available > 0 || _successfulTags.isNotEmpty,
      reason: terminalReason.isEmpty ? state : terminalReason,
    );
    return true;
  }

  void cancel() {
    _generation++;
    for (final check in _activeTargetChecks.values) {
      check.timeoutTimer?.cancel();
    }
    _activeTargetChecks.clear();
    final wasRunning = isRunning;
    final previousKind = _kind;
    final previousTarget = _targetTag;
    final previousReason = _sessionReason;
    final receivedCount = _acceptedEventTimes.length;
    final successfulCount = _successfulTags.length;
    final expectedCount = _sessionExpectedTags.length;
    _cancelSessionTimers();
    _phase = LatencySessionPhase.idle;
    _kind = null;
    _targetTag = '';
    _baselineEventTimes = const <String, int>{};
    _sessionExpectedTags = const <String>{};
    _acceptedEventTimes.clear();
    _successfulTags.clear();
    _acceptedResultRevisions.clear();
    _provisionalResultTags.clear();
    _rejectedProvisionalTags.clear();
    _nativeSessionId = 0;
    _sessionMode = '';
    _sessionReason = '';
    final result = _sessionResult;
    _sessionResult = null;
    if (result != null && !result.isCompleted) {
      result.complete(false);
    }
    if (wasRunning) {
      AppLogStore.info(
        'latency',
        'latency session cancelled kind=${previousKind?.name ?? 'unknown'} '
            'reason=$previousReason target=$previousTarget '
            'received=$receivedCount successful=$successfulCount '
            'expected=$expectedCount',
      );
      _onSessionChanged(false, previousKind, previousTarget);
      if (_usesSessionEvents && _capabilities.supportsUrlTestCancel) {
        final cancelTest = _cancelTest;
        if (cancelTest != null) {
          unawaited(cancelTest('select', previousTarget));
        }
      }
    }
  }

  /// Invalidates UI state immediately, then waits for the issued native RPC
  /// to leave libbox's serialized command lane.
  Future<void> cancelAndWait({
    Duration maxWait = const Duration(seconds: 8),
  }) async {
    final pending = _nativeSessionFinished?.future;
    cancel();
    if (pending == null) return;
    try {
      await pending.timeout(maxWait);
    } on TimeoutException {
      // The UI generation is already stale; a late completion cannot revive it.
    }
  }

  void dispose() {
    _disposed = true;
    cancel();
  }

  int get _configuredTimeoutMillis {
    final seconds = _timeoutSeconds();
    final milliseconds = seconds <= 0
        ? _defaultTimeoutMillis
        : seconds * Duration.millisecondsPerSecond;
    return milliseconds
        .clamp(_minimumTimeoutMillis, _maximumTimeoutMillis)
        .toInt();
  }

  int get _configuredConcurrency {
    final value = _concurrency();
    return (value <= 0 ? _defaultConcurrency : value)
        .clamp(1, _maximumConcurrency)
        .toInt();
  }

  int get _targetDeadlineMillis => (_configuredTimeoutMillis + 5000)
      .clamp(_configuredTimeoutMillis, _maximumDeadlineMillis)
      .toInt();

  int _fullDeadlineMillisForConcurrency(int concurrency) {
    final timeoutMillis = _configuredTimeoutMillis;
    final outboundCount = _outboundCount().clamp(1, 100000).toInt();
    final batchCount = (outboundCount + concurrency - 1) ~/ concurrency;
    final headroomMillis = max(10000, batchCount * 1000);
    return (batchCount * timeoutMillis + headroomMillis)
        .clamp(timeoutMillis, _maximumDeadlineMillis)
        .toInt();
  }

  LatencyTestRequest _groupRequest(
    String mode, {
    List<String> includeOutboundTags = const <String>[],
    String logicalSessionId = '',
    int physicalNetworkEpoch = 0,
  }) {
    final manual = mode == 'manual' && _capabilities.supportsUrlTestExhaustive;
    final effectiveConcurrency = _configuredConcurrency;
    return LatencyTestRequest(
      groupTag: 'select',
      priorityOutboundTag: _activeOutboundTag().trim(),
      url: _testUrl(),
      timeoutMillis: _configuredTimeoutMillis,
      concurrency: effectiveConcurrency,
      deadlineMillis: manual
          ? 0
          : _fullDeadlineMillisForConcurrency(effectiveConcurrency),
      mode: manual ? 'manual' : 'background',
      includeOutboundTags: includeOutboundTags,
      logicalSessionId: logicalSessionId,
      physicalNetworkEpoch: physicalNetworkEpoch,
    );
  }

  Future<bool> _runGroupSession({
    required LatencySessionKind kind,
    required String reason,
    required String mode,
    List<String> includeOutboundTags = const <String>[],
    String logicalSessionId = '',
    int physicalNetworkEpoch = 0,
  }) => _runSession(
    kind: kind,
    reason: reason,
    targetTag: '',
    request: _groupRequest(
      mode,
      includeOutboundTags: includeOutboundTags,
      logicalSessionId: logicalSessionId,
      physicalNetworkEpoch: physicalNetworkEpoch,
    ),
  );

  Future<bool> _runSession({
    required LatencySessionKind kind,
    required String reason,
    required String targetTag,
    required LatencyTestRequest request,
  }) {
    if (_disposed ||
        !_isConnected() ||
        !_isForeground() ||
        !_canRunDiagnostics()) {
      return Future<bool>.value(false);
    }
    if (isRunning || _nativeSessionFinished != null) {
      AppLogStore.info(
        'latency',
        'group session skipped reason=$reason phase=${_phase.name} '
            'nativeCommandPending=${_nativeSessionFinished != null}',
      );
      return Future<bool>.value(false);
    }

    final generation = ++_generation;
    _sessionOperationGeneration = _operationGeneration();
    _sessionStartedAtSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _baselineEventTimes = Map<String, int>.from(_eventBaselineTimes());
    _sessionExpectedTags = targetTag.isNotEmpty
        ? <String>{targetTag}
        : (request.includeOutboundTags.isNotEmpty
                  ? request.includeOutboundTags
                  : _expectedTags())
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toSet();
    _acceptedEventTimes.clear();
    _successfulTags.clear();
    _acceptedResultRevisions.clear();
    _provisionalResultTags.clear();
    _rejectedProvisionalTags.clear();
    _nativeSessionId = 0;
    _sessionMode = request.mode;
    _sessionReason = reason;
    _phase = LatencySessionPhase.startingRpc;
    _kind = kind;
    _targetTag = targetTag;
    final result = Completer<bool>();
    _sessionResult = result;
    _onSessionChanged(true, kind, targetTag);
    AppLogStore.info(
      'latency',
      'latency session start kind=${kind.name} reason=$reason '
          'target=$targetTag '
          'outbounds=${_outboundCount()} expected=${_sessionExpectedTags.length} '
          'completion='
          '${capabilities.urlTestCompletionModel.name}',
    );

    // Every session needs a backstop. Manual session-event runs settle from
    // core events, so a core that accepts the URLTest and then never emits a
    // terminal event — a service reload mid-test is enough — would otherwise
    // leave isRunning true forever, pinning the spinner and blocking every
    // automatic check. Whatever did arrive still counts as success.
    final nativeBudget =
        Duration(milliseconds: request.deadlineMillis) +
        const Duration(seconds: 5);
    final sessionBudget =
        capabilities.supportsUrlTestDeadline && request.deadlineMillis > 0
        ? (nativeBudget < uiPolicy.hardWatchdog
              ? nativeBudget
              : uiPolicy.hardWatchdog)
        : uiPolicy.hardWatchdog;
    _armWatchdog(sessionBudget);
    unawaited(
      _invokeNativeTest(
        generation: generation,
        kind: kind,
        reason: reason,
        request: request,
      ),
    );
    return result.future;
  }

  Future<void> _invokeNativeTest({
    required int generation,
    required LatencySessionKind kind,
    required String reason,
    required LatencyTestRequest request,
  }) async {
    final nativeFinished = Completer<void>();
    _nativeSessionFinished = nativeFinished;
    late final Future<void> nativeCall;
    try {
      nativeCall = _runTest(request);
    } catch (error, stackTrace) {
      nativeCall = Future<void>.error(error, stackTrace);
    }
    unawaited(
      nativeCall.then<void>(
        (_) => _markNativeFinished(nativeFinished),
        onError: (Object _, StackTrace _) =>
            _markNativeFinished(nativeFinished),
      ),
    );

    try {
      await nativeCall.timeout(uiPolicy.rpcAckTimeout);
      if (!_isActiveGeneration(generation)) return;
      if (_sessionOperationGeneration != _operationGeneration() ||
          !_isConnected() ||
          !_canRunDiagnostics()) {
        _settleCurrent(success: false, reason: 'stale_runtime');
        return;
      }
      _phase = LatencySessionPhase.collectingEvents;
      if (_usesSessionEvents) {
        return;
      }
      if (_acceptedEventTimes.isNotEmpty) {
        return;
      }
      _firstEventTimer?.cancel();
      final nativeResultWindow = Duration(
        milliseconds: request.timeoutMillis + 5000,
      );
      final firstEventTimeout =
          nativeResultWindow > uiPolicy.initialEventTimeout
          ? nativeResultWindow
          : uiPolicy.initialEventTimeout;
      _firstEventTimer = Timer(firstEventTimeout, () {
        if (generation != _generation) return;
        _settleCurrent(success: false, reason: 'no_fresh_events');
      });
    } on TimeoutException {
      if (!_isActiveGeneration(generation)) return;
      AppLogStore.warning(
        'latency',
        'native URLTest command timed out kind=${kind.name} reason=$reason '
            'rpcAckTimeoutMs=${uiPolicy.rpcAckTimeout.inMilliseconds}',
      );
      _settleCurrent(success: false, reason: 'native_command_timeout');
    } catch (error, stackTrace) {
      if (!_isActiveGeneration(generation)) return;
      AppLogStore.warning(
        'latency',
        'native URLTest command failed kind=${kind.name} reason=$reason '
            'error=$error\n$stackTrace',
      );
      _settleCurrent(success: false, reason: 'native_command_error');
    }
  }

  void _markNativeFinished(Completer<void> nativeFinished) {
    if (!nativeFinished.isCompleted) {
      nativeFinished.complete();
    }
    if (identical(_nativeSessionFinished, nativeFinished)) {
      _nativeSessionFinished = null;
    }
  }

  bool _isActiveGeneration(int generation) {
    return !_disposed && generation == _generation && isRunning;
  }

  void _armWatchdog(Duration budget) {
    _watchdogTimer?.cancel();
    final generation = _generation;
    _watchdogTimer = Timer(budget, () {
      if (!_isActiveGeneration(generation)) return;
      unawaited(_expireWatchdog(generation));
    });
  }

  Future<void> _expireWatchdog(int generation) async {
    final cancelTest = _cancelTest;
    if (_usesSessionEvents &&
        _capabilities.supportsUrlTestCancel &&
        cancelTest != null) {
      try {
        await cancelTest('select', _targetTag).timeout(uiPolicy.rpcAckTimeout);
      } catch (error) {
        AppLogStore.warning('latency', 'native URLTest cancel failed: $error');
      }
    }
    if (!_isActiveGeneration(generation)) return;
    _settleCurrent(
      success: _successfulTags.isNotEmpty,
      reason: 'hard_watchdog',
    );
  }

  /// Counts servers the core measured but this session never recorded.
  ///
  /// The runtime's own latency map is the authoritative tally of what the core
  /// probed. A result can reach the client while a runtime transition freezes
  /// updates, or be dropped because it left the visible state unchanged, and
  /// counting only the events that survived would report those servers as
  /// never tested.
  void _adoptCoreMeasurements() {
    if (_sessionExpectedTags.isEmpty) return;
    final measuredAt = _eventBaselineTimes();
    for (final tag in _sessionExpectedTags) {
      if (_acceptedEventTimes.containsKey(tag)) continue;
      if (_rejectedProvisionalTags.contains(tag)) continue;
      final seconds = measuredAt[tag] ?? 0;
      if (seconds >= _sessionStartedAtSeconds &&
          seconds > (_baselineEventTimes[tag] ?? 0)) {
        _acceptedEventTimes[tag] = seconds;
      }
    }
  }

  void _settleCurrent({required bool success, required String reason}) {
    if (!isRunning) return;
    final previousKind = _kind;
    final previousTarget = _targetTag;
    final result = _sessionResult;
    final expectedCount = _sessionExpectedTags.length;
    _adoptCoreMeasurements();
    final receivedCount = _acceptedEventTimes.keys
        .where(_sessionExpectedTags.contains)
        .length;
    final successfulCount = _successfulTags.length;
    _cancelSessionTimers();
    _phase = LatencySessionPhase.settled;
    _kind = null;
    _targetTag = '';
    _baselineEventTimes = const <String, int>{};
    _sessionExpectedTags = const <String>{};
    _acceptedEventTimes.clear();
    _successfulTags.clear();
    _provisionalResultTags.clear();
    _rejectedProvisionalTags.clear();
    _nativeSessionId = 0;
    _sessionMode = '';
    _sessionReason = '';
    _sessionResult = null;
    _onSessionChanged(false, previousKind, previousTarget);
    if (result != null && !result.isCompleted) {
      result.complete(success);
    }
    AppLogStore.info(
      'latency',
      'latency session settled kind=${previousKind?.name ?? 'unknown'} '
          'reason=$reason success=$success '
          'received=$receivedCount successful=$successfulCount '
          'expected=$expectedCount',
    );
  }

  void _cancelSessionTimers() {
    _firstEventTimer?.cancel();
    _firstEventTimer = null;
    _settleTimer?.cancel();
    _settleTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }
}
