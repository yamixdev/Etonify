import 'dart:async';

import 'package:meow_client/logging/app_log_store.dart';

enum ActiveProxyIpState { idle, checking, known, failed }

enum ActiveProxyIpSource { none, endpoint, external }

class ActiveProxyIpSnapshot {
  const ActiveProxyIpSnapshot({
    required this.state,
    required this.outboundTag,
    this.ip,
    this.countryCode,
    this.errorCode,
    this.source = ActiveProxyIpSource.none,
    required this.updatedAt,
  });

  const ActiveProxyIpSnapshot.idle()
    : state = ActiveProxyIpState.idle,
      outboundTag = '',
      ip = null,
      countryCode = null,
      errorCode = null,
      source = ActiveProxyIpSource.none,
      updatedAt = null;

  final ActiveProxyIpState state;
  final String outboundTag;
  final String? ip;
  final String? countryCode;
  final String? errorCode;
  final ActiveProxyIpSource source;
  final DateTime? updatedAt;

  bool get hasKnownIp =>
      state == ActiveProxyIpState.known && (ip?.trim().isNotEmpty ?? false);
}

class ActiveProxyIpTarget {
  const ActiveProxyIpTarget({
    required this.subscriptionId,
    required this.outboundTag,
    this.outboundIdentityKey = '',
    this.cachedIp,
    this.cachedCountryCode,
    this.endpointHost,
    this.endpointIp,
    this.endpointCountryCode,
    this.hasCachedLocation = false,
    this.operationGeneration = 0,
    this.networkGeneration = 0,
  });

  final String subscriptionId;
  final String outboundTag;
  final String outboundIdentityKey;
  final String? cachedIp;
  final String? cachedCountryCode;
  final String? endpointHost;
  final String? endpointIp;
  final String? endpointCountryCode;
  final bool hasCachedLocation;
  final int operationGeneration;
  final int networkGeneration;

  String get key =>
      '$subscriptionId\n$outboundTag\n$outboundIdentityKey\n${endpointHost?.trim().toLowerCase() ?? ''}'
      '\n$operationGeneration\n$networkGeneration';
  String get endpointLookupKey =>
      '$networkGeneration\n${endpointHost?.trim().toLowerCase() ?? ''}';
  bool get hasCachedIp => cachedIp?.trim().isNotEmpty ?? false;
  bool get hasEndpointHost => endpointHost?.trim().isNotEmpty ?? false;
  bool get hasEndpointIp => endpointIp?.trim().isNotEmpty ?? false;
}

class ActiveProxyIpResolveResult {
  const ActiveProxyIpResolveResult({required this.ip, this.countryCode});

  final String ip;
  final String? countryCode;
}

class ActiveProxyIpController {
  ActiveProxyIpController({
    this.lookupMinInterval = const Duration(minutes: 5),
    this.failureBackoff = const Duration(minutes: 2),
    this.retryDelay = const Duration(seconds: 10),
    this.maxFailuresBeforeBackoff = 2,
    this.endpointCacheTtl = const Duration(minutes: 10),
  });

  final Duration lookupMinInterval;
  final Duration failureBackoff;
  final Duration retryDelay;
  final int maxFailuresBeforeBackoff;
  final Duration endpointCacheTtl;

  final Map<String, DateTime> _attempts = <String, DateTime>{};
  final Map<String, int> _failureCounts = <String, int>{};
  final Map<String, DateTime> _suppressedUntil = <String, DateTime>{};
  final Map<String, Future<ActiveProxyIpResolveResult?>> _inFlightLookups =
      <String, Future<ActiveProxyIpResolveResult?>>{};
  final Map<String, _EndpointIpCacheEntry> _endpointCache =
      <String, _EndpointIpCacheEntry>{};
  final Map<String, Future<String?>> _inFlightEndpointLookups =
      <String, Future<String?>>{};

  Timer? _timer;
  Timer? _retryTimer;
  int _token = 0;
  bool _disposed = false;
  ActiveProxyIpSnapshot snapshot = const ActiveProxyIpSnapshot.idle();

  void dispose() {
    _disposed = true;
    cancelPending();
    _inFlightLookups.clear();
    _endpointCache.clear();
    _inFlightEndpointLookups.clear();
  }

  void cancelPending() {
    _timer?.cancel();
    _timer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _token++;
  }

  void cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void reset({
    required void Function(ActiveProxyIpSnapshot snapshot) onSnapshot,
  }) {
    if (_disposed) {
      return;
    }
    cancelPending();
    _attempts.clear();
    _failureCounts.clear();
    _suppressedUntil.clear();
    _setSnapshot(const ActiveProxyIpSnapshot.idle(), onSnapshot);
  }

  void schedule({
    Duration delay = const Duration(milliseconds: 120),
    bool forceRefresh = false,
    bool externalLookupReady = true,
    required bool Function() isConnected,
    required bool Function() isForegroundActive,
    required ActiveProxyIpTarget? Function() currentTarget,
    required Future<bool> Function(String reason) networkUsable,
    Future<String?> Function(String host)? resolveEndpointIp,
    required Future<ActiveProxyIpResolveResult?> Function(String outboundTag)
    resolveExternalIp,
    required Future<void> Function(
      ActiveProxyIpTarget target,
      ActiveProxyIpResolveResult result,
    )
    persistResult,
    required void Function(ActiveProxyIpSnapshot snapshot) onSnapshot,
  }) {
    if (_disposed) {
      return;
    }
    _timer?.cancel();
    final token = ++_token;
    if (!isConnected() || !isForegroundActive()) {
      return;
    }

    final target = currentTarget();
    if (target == null) {
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = null;

    final now = DateTime.now();
    if (forceRefresh) {
      _failureCounts.remove(target.key);
      _suppressedUntil.remove(target.key);
    }
    final immediateSnapshot = _immediateSnapshot(target, now);
    // Refreshing must never hide a value that is already known. A cached exit
    // IP wins, otherwise the proxy endpoint is shown while the slower outbound
    // lookup continues in the background.
    final showKnownImmediately = immediateSnapshot != null;
    if (immediateSnapshot != null) {
      _setSnapshot(immediateSnapshot, onSnapshot);
    } else {
      _setSnapshot(
        ActiveProxyIpSnapshot(
          state: ActiveProxyIpState.checking,
          outboundTag: target.outboundTag,
          updatedAt: now,
        ),
        onSnapshot,
      );
    }

    if (!target.hasCachedIp &&
        !target.hasEndpointIp &&
        target.hasEndpointHost &&
        resolveEndpointIp != null) {
      unawaited(
        _resolveEndpointFallback(
          token: token,
          target: target,
          externalLookupReady: externalLookupReady,
          isConnected: isConnected,
          isForegroundActive: isForegroundActive,
          currentTarget: currentTarget,
          resolveEndpointIp: resolveEndpointIp,
          onSnapshot: onSnapshot,
        ),
      );
    }

    if (!externalLookupReady) {
      return;
    }

    final suppressedUntil = _suppressedUntil[target.key];
    if (!forceRefresh &&
        suppressedUntil != null &&
        now.isBefore(suppressedUntil)) {
      if (!showKnownImmediately && !target.hasEndpointHost) {
        _setSnapshot(
          ActiveProxyIpSnapshot(
            state: ActiveProxyIpState.failed,
            outboundTag: target.outboundTag,
            errorCode: 'lookup_backoff',
            updatedAt: now,
          ),
          onSnapshot,
        );
      }
      AppLogStore.warning(
        'proxy',
        'active_ip_lookup_result tag=${target.outboundTag} '
            'error=lookup_backoff',
      );
      return;
    }
    _timer = Timer(delay, () {
      unawaited(
        _runLookup(
          token: token,
          target: target,
          allowRetry: true,
          forceRefresh: forceRefresh,
          keepStaleOnFailure: showKnownImmediately,
          isConnected: isConnected,
          isForegroundActive: isForegroundActive,
          currentTarget: currentTarget,
          networkUsable: networkUsable,
          resolveExternalIp: resolveExternalIp,
          persistResult: persistResult,
          onSnapshot: onSnapshot,
        ),
      );
    });
  }

  Future<void> _runLookup({
    required int token,
    required ActiveProxyIpTarget target,
    required bool allowRetry,
    required bool forceRefresh,
    required bool keepStaleOnFailure,
    required bool Function() isConnected,
    required bool Function() isForegroundActive,
    required ActiveProxyIpTarget? Function() currentTarget,
    required Future<bool> Function(String reason) networkUsable,
    required Future<ActiveProxyIpResolveResult?> Function(String outboundTag)
    resolveExternalIp,
    required Future<void> Function(
      ActiveProxyIpTarget target,
      ActiveProxyIpResolveResult result,
    )
    persistResult,
    required void Function(ActiveProxyIpSnapshot snapshot) onSnapshot,
  }) async {
    if (!_isCurrent(
      token,
      target,
      isConnected,
      isForegroundActive,
      currentTarget,
    )) {
      _clearOwnedCheckingSnapshot(token, target, onSnapshot);
      return;
    }
    if (!await networkUsable('active_ip_lookup')) {
      final preserveKnown = keepStaleOnFailure || _hasKnownSnapshotFor(target);
      if (_isCurrent(
            token,
            target,
            isConnected,
            isForegroundActive,
            currentTarget,
          ) &&
          !preserveKnown) {
        _setSnapshot(
          ActiveProxyIpSnapshot(
            state: ActiveProxyIpState.failed,
            outboundTag: target.outboundTag,
            errorCode: 'no_interface',
            updatedAt: DateTime.now(),
          ),
          onSnapshot,
        );
      }
      AppLogStore.warning(
        'proxy',
        'active_ip_lookup_result tag=${target.outboundTag} error=no_interface',
      );
      _clearOwnedCheckingSnapshot(token, target, onSnapshot);
      return;
    }
    if (!_isCurrent(
      token,
      target,
      isConnected,
      isForegroundActive,
      currentTarget,
    )) {
      _clearOwnedCheckingSnapshot(token, target, onSnapshot);
      return;
    }

    final now = DateTime.now();
    final lastAttempt = _attempts[target.key];
    if (!forceRefresh &&
        lastAttempt != null &&
        now.difference(lastAttempt) < lookupMinInterval &&
        target.hasCachedLocation) {
      if (_isCurrent(
        token,
        target,
        isConnected,
        isForegroundActive,
        currentTarget,
      )) {
        _setSnapshot(
          ActiveProxyIpSnapshot(
            state: ActiveProxyIpState.known,
            outboundTag: target.outboundTag,
            ip: target.cachedIp?.trim(),
            countryCode: target.cachedCountryCode,
            source: ActiveProxyIpSource.external,
            updatedAt: DateTime.now(),
          ),
          onSnapshot,
        );
      }
      return;
    }
    _attempts[target.key] = now;

    final resolved = await _resolveCoalesced(target, resolveExternalIp);
    if (resolved == null) {
      if (!_isCurrent(
        token,
        target,
        isConnected,
        isForegroundActive,
        currentTarget,
      )) {
        AppLogStore.debug(
          'proxy',
          'discarded stale active IP failure tag=${target.outboundTag} '
              'generation=${target.operationGeneration}',
        );
        _clearOwnedCheckingSnapshot(token, target, onSnapshot);
        return;
      }
      _markLookupFailed(
        token: token,
        target: target,
        allowRetry: allowRetry,
        keepStaleOnFailure: keepStaleOnFailure,
        isConnected: isConnected,
        isForegroundActive: isForegroundActive,
        currentTarget: currentTarget,
        networkUsable: networkUsable,
        resolveExternalIp: resolveExternalIp,
        persistResult: persistResult,
        onSnapshot: onSnapshot,
      );
      return;
    }
    if (!_isCurrent(
      token,
      target,
      isConnected,
      isForegroundActive,
      currentTarget,
    )) {
      _clearOwnedCheckingSnapshot(token, target, onSnapshot);
      return;
    }

    _failureCounts.remove(target.key);
    _suppressedUntil.remove(target.key);
    _setSnapshot(
      ActiveProxyIpSnapshot(
        state: ActiveProxyIpState.known,
        outboundTag: target.outboundTag,
        ip: resolved.ip,
        countryCode: resolved.countryCode,
        source: ActiveProxyIpSource.external,
        updatedAt: DateTime.now(),
      ),
      onSnapshot,
    );
    AppLogStore.info(
      'proxy',
      'active_ip_lookup_result tag=${target.outboundTag} status=known',
    );
    await persistResult(target, resolved);
  }

  Future<ActiveProxyIpResolveResult?> _resolveCoalesced(
    ActiveProxyIpTarget target,
    Future<ActiveProxyIpResolveResult?> Function(String outboundTag)
    resolveExternalIp,
  ) {
    final existing = _inFlightLookups[target.key];
    if (existing != null) {
      return existing;
    }
    final lookup = Future<ActiveProxyIpResolveResult?>.sync(
      () => resolveExternalIp(target.outboundTag),
    );
    _inFlightLookups[target.key] = lookup;
    unawaited(
      lookup
          .whenComplete(() {
            if (identical(_inFlightLookups[target.key], lookup)) {
              _inFlightLookups.remove(target.key);
            }
          })
          .then<void>((_) {}, onError: (_) {}),
    );
    return lookup;
  }

  Future<void> _resolveEndpointFallback({
    required int token,
    required ActiveProxyIpTarget target,
    required bool externalLookupReady,
    required bool Function() isConnected,
    required bool Function() isForegroundActive,
    required ActiveProxyIpTarget? Function() currentTarget,
    required Future<String?> Function(String host) resolveEndpointIp,
    required void Function(ActiveProxyIpSnapshot snapshot) onSnapshot,
  }) async {
    final stopwatch = Stopwatch()..start();
    String? resolved;
    Object? lookupError;
    try {
      resolved = await _resolveEndpointCoalesced(target, resolveEndpointIp);
    } catch (error) {
      lookupError = error;
    }
    final normalized = resolved?.trim() ?? '';
    if (!_isCurrent(
      token,
      target,
      isConnected,
      isForegroundActive,
      currentTarget,
    )) {
      _clearOwnedCheckingSnapshot(token, target, onSnapshot);
      return;
    }
    if (normalized.isEmpty) {
      AppLogStore.debug(
        'proxy',
        'endpoint_ip_lookup_result tag=${target.outboundTag} status=failed '
            'durationMs=${stopwatch.elapsedMilliseconds} '
            'error=${lookupError ?? 'empty_result'}',
      );
      if (!externalLookupReady &&
          snapshot.state == ActiveProxyIpState.checking &&
          snapshot.outboundTag == target.outboundTag) {
        _setSnapshot(
          ActiveProxyIpSnapshot(
            state: ActiveProxyIpState.failed,
            outboundTag: target.outboundTag,
            errorCode: 'endpoint_lookup_failed',
            updatedAt: DateTime.now(),
          ),
          onSnapshot,
        );
      }
      return;
    }

    _cacheEndpointIp(target, normalized);
    if (snapshot.source == ActiveProxyIpSource.external &&
        snapshot.outboundTag == target.outboundTag) {
      return;
    }
    _setSnapshot(
      _endpointSnapshot(target, normalized, DateTime.now()),
      onSnapshot,
    );
    AppLogStore.info(
      'proxy',
      'endpoint_ip_lookup_result tag=${target.outboundTag} status=known '
          'durationMs=${stopwatch.elapsedMilliseconds}',
    );
  }

  Future<String?> _resolveEndpointCoalesced(
    ActiveProxyIpTarget target,
    Future<String?> Function(String host) resolveEndpointIp,
  ) {
    final key = target.endpointLookupKey;
    final existing = _inFlightEndpointLookups[key];
    if (existing != null) {
      return existing;
    }
    final lookup = Future<String?>.sync(
      () => resolveEndpointIp(target.endpointHost!.trim()),
    );
    _inFlightEndpointLookups[key] = lookup;
    unawaited(
      lookup
          .whenComplete(() {
            if (identical(_inFlightEndpointLookups[key], lookup)) {
              _inFlightEndpointLookups.remove(key);
            }
          })
          .then<void>((_) {}, onError: (_) {}),
    );
    return lookup;
  }

  void _markLookupFailed({
    required int token,
    required ActiveProxyIpTarget target,
    required bool allowRetry,
    required bool keepStaleOnFailure,
    required bool Function() isConnected,
    required bool Function() isForegroundActive,
    required ActiveProxyIpTarget? Function() currentTarget,
    required Future<bool> Function(String reason) networkUsable,
    required Future<ActiveProxyIpResolveResult?> Function(String outboundTag)
    resolveExternalIp,
    required Future<void> Function(
      ActiveProxyIpTarget target,
      ActiveProxyIpResolveResult result,
    )
    persistResult,
    required void Function(ActiveProxyIpSnapshot snapshot) onSnapshot,
  }) {
    final preserveKnown = keepStaleOnFailure || _hasKnownSnapshotFor(target);
    final failures = (_failureCounts[target.key] ?? 0) + 1;
    _failureCounts[target.key] = failures;
    final suppressLookups = failures >= maxFailuresBeforeBackoff;
    if (suppressLookups) {
      _suppressedUntil[target.key] = DateTime.now().add(failureBackoff);
    }
    if (!preserveKnown &&
        _isCurrent(
          token,
          target,
          isConnected,
          isForegroundActive,
          currentTarget,
        )) {
      _setSnapshot(
        ActiveProxyIpSnapshot(
          state: ActiveProxyIpState.failed,
          outboundTag: target.outboundTag,
          errorCode: 'lookup_failed',
          updatedAt: DateTime.now(),
        ),
        onSnapshot,
      );
    }
    AppLogStore.warning(
      'proxy',
      'active_ip_lookup_result tag=${target.outboundTag} error=lookup_failed '
          'failures=$failures suppressed=$suppressLookups',
    );
    if (!allowRetry ||
        suppressLookups ||
        !_isCurrent(
          token,
          target,
          isConnected,
          isForegroundActive,
          currentTarget,
        )) {
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = Timer(retryDelay, () {
      unawaited(
        _runLookup(
          token: token,
          target: target,
          allowRetry: false,
          forceRefresh: false,
          keepStaleOnFailure: preserveKnown,
          isConnected: isConnected,
          isForegroundActive: isForegroundActive,
          currentTarget: currentTarget,
          networkUsable: networkUsable,
          resolveExternalIp: resolveExternalIp,
          persistResult: persistResult,
          onSnapshot: onSnapshot,
        ),
      );
    });
  }

  bool _isCurrent(
    int token,
    ActiveProxyIpTarget target,
    bool Function() isConnected,
    bool Function() isForegroundActive,
    ActiveProxyIpTarget? Function() currentTarget,
  ) {
    if (_disposed ||
        !isConnected() ||
        !isForegroundActive() ||
        token != _token) {
      return false;
    }
    final current = currentTarget();
    return current != null && current.key == target.key;
  }

  void _setSnapshot(
    ActiveProxyIpSnapshot next,
    void Function(ActiveProxyIpSnapshot snapshot) onSnapshot,
  ) {
    if (_disposed) {
      return;
    }
    snapshot = next;
    onSnapshot(next);
  }

  void _clearOwnedCheckingSnapshot(
    int token,
    ActiveProxyIpTarget target,
    void Function(ActiveProxyIpSnapshot snapshot) onSnapshot,
  ) {
    if (_disposed ||
        token != _token ||
        snapshot.state != ActiveProxyIpState.checking ||
        snapshot.outboundTag != target.outboundTag) {
      return;
    }
    final immediate = _immediateSnapshot(target, DateTime.now());
    if (immediate != null) {
      _setSnapshot(immediate, onSnapshot);
      return;
    }
    _setSnapshot(
      ActiveProxyIpSnapshot(
        state: ActiveProxyIpState.idle,
        outboundTag: target.outboundTag,
        updatedAt: DateTime.now(),
      ),
      onSnapshot,
    );
  }

  ActiveProxyIpSnapshot _cachedSnapshot(
    ActiveProxyIpTarget target,
    DateTime updatedAt,
  ) {
    return ActiveProxyIpSnapshot(
      state: ActiveProxyIpState.known,
      outboundTag: target.outboundTag,
      ip: target.cachedIp?.trim(),
      countryCode: target.cachedCountryCode,
      source: ActiveProxyIpSource.external,
      updatedAt: updatedAt,
    );
  }

  ActiveProxyIpSnapshot? _immediateSnapshot(
    ActiveProxyIpTarget target,
    DateTime now,
  ) {
    if (target.hasCachedIp) {
      return _cachedSnapshot(target, now);
    }
    final endpointIp = target.hasEndpointIp
        ? target.endpointIp!.trim()
        : _cachedEndpointIp(target, now);
    if (endpointIp == null || endpointIp.isEmpty) {
      return null;
    }
    return _endpointSnapshot(target, endpointIp, now);
  }

  ActiveProxyIpSnapshot _endpointSnapshot(
    ActiveProxyIpTarget target,
    String endpointIp,
    DateTime updatedAt,
  ) {
    return ActiveProxyIpSnapshot(
      state: ActiveProxyIpState.known,
      outboundTag: target.outboundTag,
      ip: endpointIp,
      countryCode: target.endpointCountryCode,
      source: ActiveProxyIpSource.endpoint,
      updatedAt: updatedAt,
    );
  }

  bool _hasKnownSnapshotFor(ActiveProxyIpTarget target) {
    return snapshot.outboundTag == target.outboundTag && snapshot.hasKnownIp;
  }

  String? _cachedEndpointIp(ActiveProxyIpTarget target, DateTime now) {
    if (!target.hasEndpointHost) {
      return null;
    }
    final entry = _endpointCache[target.endpointLookupKey];
    if (entry == null) {
      return null;
    }
    if (now.difference(entry.resolvedAt) > endpointCacheTtl) {
      _endpointCache.remove(target.endpointLookupKey);
      return null;
    }
    return entry.ip;
  }

  void _cacheEndpointIp(ActiveProxyIpTarget target, String ip) {
    if (_endpointCache.length >= 64 &&
        !_endpointCache.containsKey(target.endpointLookupKey)) {
      String? oldestKey;
      DateTime? oldestAt;
      for (final entry in _endpointCache.entries) {
        if (oldestAt == null || entry.value.resolvedAt.isBefore(oldestAt)) {
          oldestKey = entry.key;
          oldestAt = entry.value.resolvedAt;
        }
      }
      if (oldestKey != null) {
        _endpointCache.remove(oldestKey);
      }
    }
    _endpointCache[target.endpointLookupKey] = _EndpointIpCacheEntry(
      ip: ip,
      resolvedAt: DateTime.now(),
    );
  }
}

class _EndpointIpCacheEntry {
  const _EndpointIpCacheEntry({required this.ip, required this.resolvedAt});

  final String ip;
  final DateTime resolvedAt;
}
