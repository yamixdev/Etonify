import 'dart:async';

import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';

enum LatencySessionKind { full, targeted }

enum LatencySessionPhase { idle, startingRpc, collectingEvents, settled }

class LatencyUiPolicy {
  const LatencyUiPolicy({
    this.nativeCommandTimeout = const Duration(seconds: 5),
    this.initialEventTimeout = const Duration(seconds: 12),
    this.eventInactivityTimeout = const Duration(seconds: 12),
    this.hardWatchdog = const Duration(seconds: 125),
  });

  /// These values bound UI state only. They never delay command dispatch or
  /// fresh native results.
  final Duration nativeCommandTimeout;
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
}

typedef LatencyTestRunner = Future<void> Function(LatencyTestRequest request);
typedef LatencyBoolReader = bool Function();
typedef LatencyStringReader = String Function();
typedef LatencyIntReader = int Function();
typedef LatencyEventTimesReader = Map<String, int> Function();
typedef LatencyExpectedTagsReader = Iterable<String> Function();
typedef LatencySessionChanged =
    void Function(bool running, LatencySessionKind? kind, String targetTag);

class LatencyCoordinator {
  LatencyCoordinator({
    required LatencyTestRunner runTest,
    required LatencyBoolReader isConnected,
    required LatencyBoolReader isForeground,
    required LatencyStringReader activeOutboundTag,
    LatencyStringReader? activeGroupTag,
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
       _isConnected = isConnected,
       _isForeground = isForeground,
       _activeOutboundTag = activeOutboundTag,
       _activeGroupTag = activeGroupTag ?? _defaultGroupTag,
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
  static const _defaultConcurrency = 4;
  static const _maximumConcurrency = 16;
  static const _maximumDeadlineMillis = 120000;

  final LatencyTestRunner _runTest;
  final LatencyBoolReader _isConnected;
  final LatencyBoolReader _isForeground;
  final LatencyStringReader _activeOutboundTag;
  final LatencyStringReader _activeGroupTag;
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
  static String _defaultGroupTag() => 'select';
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
  Completer<bool>? _sessionResult;
  Completer<void>? _nativeSessionFinished;

  bool get isRunning =>
      _phase == LatencySessionPhase.startingRpc ||
      _phase == LatencySessionPhase.collectingEvents;
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
    if (!isRunning || tag.isEmpty) return false;
    if (_targetTag.isNotEmpty) {
      return _targetTag == tag;
    }
    if (_sessionExpectedTags.isEmpty) {
      return true;
    }
    return _sessionExpectedTags.contains(tag) &&
        !_acceptedEventTimes.containsKey(tag);
  }

  bool shouldIgnoreGroupResult(String rawTag, int timeSeconds) {
    final tag = rawTag.trim();
    if (!isRunning ||
        tag.isEmpty ||
        timeSeconds <= 0 ||
        !_sessionExpectedTags.contains(tag)) {
      return false;
    }
    final baseline = _baselineEventTimes[tag] ?? 0;
    return timeSeconds < _sessionStartedAtSeconds ||
        (baseline > 0 && timeSeconds <= baseline) ||
        timeSeconds <= (_acceptedEventTimes[tag] ?? 0);
  }

  Future<bool> runFull({required String reason}) {
    return _runGroupSession(kind: LatencySessionKind.full, reason: reason);
  }

  Future<bool> runTarget({
    required String targetOutboundTag,
    required String reason,
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
    final groupTag = _activeGroupTag().trim();
    return _runSession(
      kind: LatencySessionKind.targeted,
      reason: reason,
      targetTag: targetTag,
      request: LatencyTestRequest(
        groupTag: groupTag.isEmpty ? 'select' : groupTag,
        targetOutboundTag: targetTag,
        priorityOutboundTag: targetTag,
        url: _testUrl(),
        timeoutMillis: _configuredTimeoutMillis,
        concurrency: 1,
        deadlineMillis: _targetDeadlineMillis,
      ),
    );
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
    if (!isRunning || normalizedTag.isEmpty || timeSeconds <= 0) {
      return false;
    }
    if (_operationGeneration() != _sessionOperationGeneration ||
        !_isConnected() ||
        !_canRunDiagnostics()) {
      _settleCurrent(success: false, reason: 'stale_runtime');
      return false;
    }
    final baseline = _baselineEventTimes[normalizedTag] ?? 0;
    if (timeSeconds < _sessionStartedAtSeconds ||
        (baseline > 0 && timeSeconds <= baseline) ||
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

  void cancel() {
    _generation++;
    final wasRunning = isRunning;
    final previousKind = _kind;
    final previousTarget = _targetTag;
    _cancelSessionTimers();
    _phase = LatencySessionPhase.idle;
    _kind = null;
    _targetTag = '';
    _baselineEventTimes = const <String, int>{};
    _sessionExpectedTags = const <String>{};
    _acceptedEventTimes.clear();
    _successfulTags.clear();
    final result = _sessionResult;
    _sessionResult = null;
    if (result != null && !result.isCompleted) {
      result.complete(false);
    }
    if (wasRunning) {
      _onSessionChanged(false, previousKind, previousTarget);
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

  int get _fullDeadlineMillis {
    final timeoutMillis = _configuredTimeoutMillis;
    final concurrency = _configuredConcurrency;
    final outboundCount = _outboundCount().clamp(1, 100000).toInt();
    final batchCount = (outboundCount + concurrency - 1) ~/ concurrency;
    return (batchCount * timeoutMillis + 5000)
        .clamp(timeoutMillis, _maximumDeadlineMillis)
        .toInt();
  }

  LatencyTestRequest _groupRequest() {
    final groupTag = _activeGroupTag().trim();
    return LatencyTestRequest(
      groupTag: groupTag.isEmpty ? 'select' : groupTag,
      priorityOutboundTag: _activeOutboundTag().trim(),
      url: _testUrl(),
      timeoutMillis: _configuredTimeoutMillis,
      concurrency: _configuredConcurrency,
      deadlineMillis: _fullDeadlineMillis,
    );
  }

  Future<bool> _runGroupSession({
    required LatencySessionKind kind,
    required String reason,
  }) => _runSession(
    kind: kind,
    reason: reason,
    targetTag: '',
    request: _groupRequest(),
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
        : _expectedTags()
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toSet();
    _acceptedEventTimes.clear();
    _successfulTags.clear();
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

    _watchdogTimer = Timer(uiPolicy.hardWatchdog, () {
      if (generation != _generation) return;
      _settleCurrent(
        success: _successfulTags.isNotEmpty,
        reason: 'hard_watchdog',
      );
    });
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
      await nativeCall.timeout(uiPolicy.nativeCommandTimeout);
      if (!_isActiveGeneration(generation)) return;
      if (_sessionOperationGeneration != _operationGeneration() ||
          !_isConnected() ||
          !_canRunDiagnostics()) {
        _settleCurrent(success: false, reason: 'stale_runtime');
        return;
      }
      _phase = LatencySessionPhase.collectingEvents;
      if (_acceptedEventTimes.isNotEmpty) {
        return;
      }
      _firstEventTimer?.cancel();
      _firstEventTimer = Timer(uiPolicy.initialEventTimeout, () {
        if (generation != _generation) return;
        _settleCurrent(success: false, reason: 'no_fresh_events');
      });
    } on TimeoutException {
      if (!_isActiveGeneration(generation)) return;
      AppLogStore.warning(
        'latency',
        'native URLTest command timed out kind=${kind.name} reason=$reason '
            'uiTimeoutMs=${uiPolicy.nativeCommandTimeout.inMilliseconds}',
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

  void _settleCurrent({required bool success, required String reason}) {
    if (!isRunning) return;
    final previousKind = _kind;
    final previousTarget = _targetTag;
    final result = _sessionResult;
    final expectedCount = _sessionExpectedTags.length;
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
