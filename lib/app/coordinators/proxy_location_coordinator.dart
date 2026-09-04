import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

class ResolvedExternalIpInfo {
  const ResolvedExternalIpInfo({required this.ip, this.countryCode});

  final String ip;
  final String? countryCode;

  static ResolvedExternalIpInfo? fromResponse(
    Map<String, dynamic> response, {
    required String Function(String? value) normalizeCountryCode,
  }) {
    final ip =
        (response['ip']?.toString() ?? response['query']?.toString() ?? '')
            .trim();
    if (ip.isEmpty) {
      return null;
    }
    final normalizedCountry = normalizeCountryCode(
      response['countryCode']?.toString() ??
          response['country_code']?.toString() ??
          response['cc']?.toString(),
    );
    return ResolvedExternalIpInfo(
      ip: ip,
      countryCode: normalizedCountry.isEmpty ? null : normalizedCountry,
    );
  }

  static String normalizeCountryCode(String? countryCode) {
    final normalized = countryCode?.trim().toUpperCase() ?? '';
    return RegExp(r'^[A-Z]{2}$').hasMatch(normalized) ? normalized : '';
  }
}

class LocationLookupSlot {
  LocationLookupSlot(this._onRelease);

  final VoidCallback _onRelease;
  bool _released = false;

  void release() {
    if (_released) {
      return;
    }
    _released = true;
    _onRelease();
  }
}

typedef ApplyResolvedExternalIpInfosCallback =
    Future<void> Function({
      required String subscriptionId,
      required Map<String, ResolvedExternalIpInfo> resolvedByTag,
    });

class ProxyLocationCoordinator {
  ProxyLocationCoordinator({
    required SingboxRuntime runtime,
    required ValueGetter<int> getLocationLookupLimit,
    required ValueGetter<int> getLocationLookupTimeoutSeconds,
    required ValueGetter<int> getLocationLookupConcurrency,
    required ValueGetter<bool> isConnected,
    required ValueGetter<bool> isForegroundLifecycleActive,
    required ValueGetter<bool> isMarkAllServersRussia,
    required ValueGetter<bool> isProxyPanelInteractionActive,
    required ValueGetter<int> getDiagnosticGeneration,
    required ValueGetter<Subscription?> getActiveSubscription,
    required ValueGetter<List<Outbound>> getBestOutbounds,
    required bool Function(Outbound outbound) hasResolvedExternalLocation,
    required int? Function(Outbound outbound) getEffectiveOutboundLatency,
    required ApplyResolvedExternalIpInfosCallback onApplyResolvedInfos,
  })  : _runtime = runtime,
        _getLocationLookupLimit = getLocationLookupLimit,
        _getLocationLookupTimeoutSeconds = getLocationLookupTimeoutSeconds,
        _getLocationLookupConcurrency = getLocationLookupConcurrency,
        _isConnected = isConnected,
        _isForegroundLifecycleActive = isForegroundLifecycleActive,
        _isMarkAllServersRussia = isMarkAllServersRussia,
        _isProxyPanelInteractionActive = isProxyPanelInteractionActive,
        _getDiagnosticGeneration = getDiagnosticGeneration,
        _getActiveSubscription = getActiveSubscription,
        _getBestOutbounds = getBestOutbounds,
        _hasResolvedExternalLocation = hasResolvedExternalLocation,
        _getEffectiveOutboundLatency = getEffectiveOutboundLatency,
        _onApplyResolvedInfos = onApplyResolvedInfos;

  final SingboxRuntime _runtime;
  final ValueGetter<int> _getLocationLookupLimit;
  final ValueGetter<int> _getLocationLookupTimeoutSeconds;
  final ValueGetter<int> _getLocationLookupConcurrency;
  final ValueGetter<bool> _isConnected;
  final ValueGetter<bool> _isForegroundLifecycleActive;
  final ValueGetter<bool> _isMarkAllServersRussia;
  final ValueGetter<bool> _isProxyPanelInteractionActive;
  final ValueGetter<int> _getDiagnosticGeneration;
  final ValueGetter<Subscription?> _getActiveSubscription;
  final ValueGetter<List<Outbound>> _getBestOutbounds;
  final bool Function(Outbound outbound) _hasResolvedExternalLocation;
  final int? Function(Outbound outbound) _getEffectiveOutboundLatency;
  final ApplyResolvedExternalIpInfosCallback _onApplyResolvedInfos;

  Timer? _locationLookupTimer;
  bool _locationLookupInFlight = false;
  int _locationLookupActiveRequests = 0;
  int _locationLookupGeneration = 0;
  bool _locationLookupRefreshRequested = false;
  final Queue<Completer<bool>> _locationLookupWaiters =
      Queue<Completer<bool>>();
  String _lastLocationLookupSignature = '';
  final Map<String, Future<Map<String, dynamic>>> _externalInfoLookups =
      <String, Future<Map<String, dynamic>>>{};
  bool _disposed = false;

  void invalidateSignature() {
    _lastLocationLookupSignature = '';
  }

  void pumpLocationLookupWaiters() {
    _pumpLocationLookupWaiters();
  }

  void reset() {
    _locationLookupTimer?.cancel();
    _locationLookupTimer = null;
    _locationLookupGeneration++;
    _locationLookupInFlight = false;
    _locationLookupRefreshRequested = false;
    _cancelQueuedLocationLookups();
  }

  void dispose() {
    _disposed = true;
    _locationLookupTimer?.cancel();
    _locationLookupTimer = null;
    _locationLookupRefreshRequested = false;
    _cancelQueuedLocationLookups();
    _externalInfoLookups.clear();
  }

  void scheduleBestOutboundLocationRefresh({
    Duration delay = const Duration(seconds: 1),
  }) {
    if (_disposed || !_isForegroundLifecycleActive()) {
      _locationLookupTimer?.cancel();
      _locationLookupRefreshRequested = false;
      return;
    }
    if (_locationLookupInFlight) {
      _locationLookupRefreshRequested = true;
      return;
    }
    _locationLookupTimer?.cancel();
    final generation = ++_locationLookupGeneration;
    if (!_isConnected() ||
        _getLocationLookupLimit() <= 0 ||
        _isMarkAllServersRussia()) {
      _locationLookupRefreshRequested = false;
      return;
    }
    final effectiveDelay = _isProxyPanelInteractionActive()
        ? delay + const Duration(seconds: 3)
        : delay;
    _locationLookupTimer = Timer(effectiveDelay, () {
      unawaited(_refreshBestOutboundLocations(generation: generation));
    });
  }

  Future<void> _refreshBestOutboundLocations({required int generation}) async {
    if (_disposed ||
        _locationLookupInFlight ||
        !_isConnected() ||
        !_isForegroundLifecycleActive() ||
        generation != _locationLookupGeneration ||
        _getLocationLookupLimit() <= 0 ||
        _isMarkAllServersRussia()) {
      return;
    }
    if (_isProxyPanelInteractionActive()) {
      scheduleBestOutboundLocationRefresh(delay: const Duration(seconds: 3));
      return;
    }
    final activeSubscription = _getActiveSubscription();
    if (activeSubscription == null) {
      return;
    }
    final targets = _getBestOutbounds();
    if (targets.isEmpty) {
      return;
    }
    final limit = _getLocationLookupLimit();
    final targetTags = targets
        .take(limit)
        .where((outbound) => !_hasResolvedExternalLocation(outbound))
        .map((outbound) => outbound.tag)
        .toList(growable: false);
    if (targetTags.isEmpty) {
      return;
    }
    final outboundsByTag = <String, Outbound>{
      for (final o in targets) o.tag: o,
    };
    final signature =
        '${activeSubscription.id}|$limit|'
        '${targetTags.map((tag) {
          final outbound = outboundsByTag[tag];
          return '$tag:${outbound == null ? '' : _getEffectiveOutboundLatency(outbound) ?? ''}';
        }).join('|')}';
    if (signature == _lastLocationLookupSignature) {
      return;
    }
    _lastLocationLookupSignature = signature;
    _locationLookupInFlight = true;
    try {
      final resolvedByTag = await _fetchExternalIpInfoBatch(
        targetTags,
        subscriptionId: activeSubscription.id,
        generation: generation,
      );
      if (resolvedByTag.isEmpty ||
          _disposed ||
          !_isConnected() ||
          generation != _locationLookupGeneration) {
        return;
      }
      await _onApplyResolvedInfos(
        subscriptionId: activeSubscription.id,
        resolvedByTag: resolvedByTag,
      );
    } finally {
      final refreshRequested = _locationLookupRefreshRequested;
      _locationLookupRefreshRequested = false;
      _locationLookupInFlight = false;
      if (!_disposed &&
          _isConnected() &&
          (refreshRequested || generation != _locationLookupGeneration) &&
          _getLocationLookupLimit() > 0) {
        scheduleBestOutboundLocationRefresh(
          delay: _isProxyPanelInteractionActive()
              ? const Duration(seconds: 3)
              : Duration.zero,
        );
      }
    }
  }

  Future<Map<String, ResolvedExternalIpInfo>> _fetchExternalIpInfoBatch(
    List<String> outboundTags, {
    required String subscriptionId,
    required int generation,
  }) async {
    final resolvedByTag = <String, ResolvedExternalIpInfo>{};
    var nextIndex = 0;
    final concurrency = _getLocationLookupConcurrency();
    final workerCount = min(outboundTags.length, concurrency);
    Future<void> worker() async {
      while (!_disposed &&
          _isConnected() &&
          generation == _locationLookupGeneration &&
          _getActiveSubscription()?.id == subscriptionId) {
        final index = nextIndex;
        nextIndex++;
        if (index >= outboundTags.length) {
          return;
        }
        final tag = outboundTags[index];
        final resolved = await fetchExternalIpInfo(outboundTag: tag);
        if (resolved != null) {
          resolvedByTag[tag] = resolved;
        }
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));
    return resolvedByTag;
  }

  Future<ResolvedExternalIpInfo?> fetchExternalIpInfo({
    required String outboundTag,
    bool highPriority = false,
  }) async {
    LocationLookupSlot? slot;
    if (!highPriority) {
      slot = await _acquireLocationLookupSlot();
      if (slot == null) {
        return null;
      }
    }
    final lookup = _sharedExternalInfoLookup(outboundTag);
    if (slot != null) {
      unawaited(
        lookup.whenComplete(slot.release).then<void>((_) {}, onError: (_) {}),
      );
    }
    try {
      final timeoutSeconds = _getLocationLookupTimeoutSeconds();
      final response = await lookup.timeout(Duration(seconds: timeoutSeconds));
      return ResolvedExternalIpInfo.fromResponse(
        response,
        normalizeCountryCode: ResolvedExternalIpInfo.normalizeCountryCode,
      );
    } on TimeoutException {
      AppLogStore.debug(
        'proxy',
        'outbound_ip_rpc tag=$outboundTag error=timeout',
      );
      return null;
    } catch (error) {
      AppLogStore.debug(
        'proxy',
        'outbound_ip_rpc tag=$outboundTag error=core_error '
            'detail=$error',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>> _sharedExternalInfoLookup(String outboundTag) {
    final normalizedTag = outboundTag.trim();
    final key = '${_getDiagnosticGeneration()}\n$normalizedTag';
    final existing = _externalInfoLookups[key];
    if (existing != null) {
      return existing;
    }
    final lookup = _runtime.lookupOutboundExternalInfo(
      outboundTag: normalizedTag,
    );
    _externalInfoLookups[key] = lookup;
    unawaited(
      lookup
          .whenComplete(() {
            if (identical(_externalInfoLookups[key], lookup)) {
              _externalInfoLookups.remove(key);
            }
          })
          .then<void>((_) {}, onError: (_) {}),
    );
    return lookup;
  }

  Future<LocationLookupSlot?> _acquireLocationLookupSlot() async {
    final concurrency = _getLocationLookupConcurrency();
    if (_locationLookupActiveRequests >= concurrency) {
      final waiter = Completer<bool>();
      _locationLookupWaiters.add(waiter);
      final acquired = await waiter.future;
      if (!acquired || _disposed) {
        return null;
      }
    } else {
      _locationLookupActiveRequests++;
    }
    return LocationLookupSlot(_releaseLocationLookupSlot);
  }

  void _releaseLocationLookupSlot() {
    _locationLookupActiveRequests = max(0, _locationLookupActiveRequests - 1);
    _pumpLocationLookupWaiters();
  }

  void _pumpLocationLookupWaiters() {
    final concurrency = _getLocationLookupConcurrency();
    while (_locationLookupWaiters.isNotEmpty &&
        _locationLookupActiveRequests < concurrency) {
      final waiter = _locationLookupWaiters.removeFirst();
      if (waiter.isCompleted) {
        continue;
      }
      _locationLookupActiveRequests++;
      waiter.complete(true);
    }
  }

  void _cancelQueuedLocationLookups() {
    while (_locationLookupWaiters.isNotEmpty) {
      final waiter = _locationLookupWaiters.removeFirst();
      if (!waiter.isCompleted) {
        waiter.complete(false);
      }
    }
  }
}
