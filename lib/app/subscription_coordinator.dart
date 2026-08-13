import 'dart:math';

import 'package:meow_client/app/subscription_runtime_controller.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/models/subscription.dart';

typedef SubscriptionMetadataLoader = Future<List<Subscription>> Function();
typedef SubscriptionLoader = Future<Subscription?> Function(String id);
typedef SubscriptionRefresher = Future<Subscription> Function(String id);
typedef SubscriptionPayloadSnapshotLoader = String? Function(String id);
typedef SubscriptionPayloadPreloader = Future<void> Function();

class SubscriptionAutoRefreshResult {
  const SubscriptionAutoRefreshResult({
    required this.dueCount,
    this.refreshedActiveSubscription,
    this.activeRuntimeChanged = false,
  });

  final int dueCount;
  final Subscription? refreshedActiveSubscription;
  final bool activeRuntimeChanged;
}

class SubscriptionCoordinator {
  SubscriptionCoordinator({
    required SubscriptionRuntimeController runtime,
    SubscriptionMetadataLoader? loadMetadata,
    SubscriptionLoader? loadSubscription,
    SubscriptionRefresher? refreshSubscription,
    SubscriptionPayloadSnapshotLoader? payloadSnapshotFor,
    SubscriptionPayloadPreloader? ensurePayloadReady,
  }) : _runtime = runtime,
       _loadMetadata =
           loadMetadata ?? SubscriptionStore.getAllMetadataInBackground,
       _loadSubscription =
           loadSubscription ?? SubscriptionStore.getInBackground,
       _refreshSubscription =
           refreshSubscription ?? ((id) => SubscriptionStore.refresh(id)),
       _payloadSnapshotFor =
           payloadSnapshotFor ?? SubscriptionStore.payloadSnapshotFor,
       _ensurePayloadReady =
           ensurePayloadReady ??
           (payloadSnapshotFor == null
               ? SubscriptionStore.ensurePayloadReady
               : null);

  final SubscriptionRuntimeController _runtime;
  final SubscriptionMetadataLoader _loadMetadata;
  final SubscriptionLoader _loadSubscription;
  final SubscriptionRefresher _refreshSubscription;
  final SubscriptionPayloadSnapshotLoader _payloadSnapshotFor;
  final SubscriptionPayloadPreloader? _ensurePayloadReady;

  int _hydrationGeneration = 0;
  Future<bool>? _activeHydrationInFlight;

  Duration? nextAutoRefreshDelay(List<Subscription> subscriptions) {
    return _runtime.nextAutoRefreshDelay(subscriptions);
  }

  String runtimeFingerprint(Subscription subscription) {
    return _runtime.subscriptionRuntimeFingerprint(subscription);
  }

  Future<String?> runtimeFingerprintFromStore(String subscriptionId) async {
    final id = subscriptionId.trim();
    if (id.isEmpty) {
      return null;
    }
    final subscription = await _loadSubscription(id);
    return subscription == null ? null : runtimeFingerprint(subscription);
  }

  Future<String> metadataFingerprint() async {
    return _runtime.subscriptionsMetadataFingerprint(await _loadMetadata());
  }

  Future<ResolvedSubscriptions> resolveMetadata({
    required String activeSubscriptionId,
    required String selectedProxyTag,
    bool preferSelectedProxyTag = false,
  }) async {
    return _runtime.resolveMetadata(
      metadataSubscriptions: await _loadMetadata(),
      activeSubscriptionId: activeSubscriptionId,
      selectedProxyTag: selectedProxyTag,
      preferSelectedProxyTag: preferSelectedProxyTag,
    );
  }

  Future<ResolvedSubscriptions> resolveSubscriptions({
    required String activeSubscriptionId,
    required String selectedProxyTag,
    required bool preserveRuntimeState,
    required SubscriptionRuntimeSnapshot runtimeSnapshot,
    bool buildFullProxyList = true,
  }) async {
    await _ensurePayloadReady?.call();
    return _runtime.resolveSubscriptions(
      metadataSubscriptions: await _loadMetadata(),
      activeSubscriptionId: activeSubscriptionId,
      selectedProxyTag: selectedProxyTag,
      preserveRuntimeState: preserveRuntimeState,
      runtimeSnapshot: runtimeSnapshot,
      payloadSnapshotFor: _payloadSnapshotFor,
      buildFullProxyList: buildFullProxyList,
    );
  }

  Future<HydratedActiveSubscription> hydrateActiveSubscription({
    required Subscription metadata,
    required String selectedProxyTag,
    required bool preferSelectedProxyTag,
    required bool preserveRuntimeState,
    required SubscriptionRuntimeSnapshot runtimeSnapshot,
    bool buildFullProxyList = true,
  }) async {
    await _ensurePayloadReady?.call();
    return _runtime.hydrateActiveSubscriptionAndBuildProxyCache(
      metadata: metadata,
      selectedProxyTag: selectedProxyTag,
      preferSelectedProxyTag: preferSelectedProxyTag,
      preserveRuntimeState: preserveRuntimeState,
      runtimeSnapshot: runtimeSnapshot,
      payloadSnapshot: _payloadSnapshotFor(metadata.id),
      buildFullProxyList: buildFullProxyList,
    );
  }

  int beginHydration() => ++_hydrationGeneration;

  bool isHydrationCurrent(int generation) {
    return generation == _hydrationGeneration;
  }

  Future<bool> ensureActiveHydrated(
    Future<bool> Function(int generation) hydrate,
  ) {
    final inFlight = _activeHydrationInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final generation = beginHydration();
    late final Future<bool> hydration;
    hydration = hydrate(generation).whenComplete(() {
      if (identical(_activeHydrationInFlight, hydration)) {
        _activeHydrationInFlight = null;
      }
    });
    _activeHydrationInFlight = hydration;
    return hydration;
  }

  Future<SubscriptionAutoRefreshResult> refreshDue({
    required List<Subscription> subscriptions,
    required Subscription? activeSubscription,
    required int concurrency,
  }) async {
    final dueSubscriptions = _runtime.dueAutoRefreshSubscriptions(
      subscriptions,
    );
    if (dueSubscriptions.isEmpty) {
      return const SubscriptionAutoRefreshResult(dueCount: 0);
    }

    AppLogStore.info(
      'subscription refresh',
      'auto-refresh begin due=${dueSubscriptions.length} '
          'ids=${dueSubscriptions.map((subscription) => subscription.id).take(6).join(', ')}',
    );
    final activeBeforeFingerprint = activeSubscription == null
        ? null
        : runtimeFingerprint(activeSubscription);
    Subscription? refreshedActiveSubscription;
    final refreshLimit = max(1, min(concurrency, dueSubscriptions.length));

    for (
      var offset = 0;
      offset < dueSubscriptions.length;
      offset += refreshLimit
    ) {
      final batch = dueSubscriptions.skip(offset).take(refreshLimit);
      await Future.wait(
        batch.map((subscription) async {
          try {
            AppLogStore.info(
              'subscription refresh',
              'refreshing id=${subscription.id} name=${subscription.name}',
            );
            final updated = await _refreshSubscription(subscription.id);
            _runtime.clearAutoRefreshFailure(subscription.id);
            if (updated.id == activeSubscription?.id) {
              refreshedActiveSubscription = updated;
            }
          } catch (error) {
            final backoff = _runtime.recordAutoRefreshFailure(subscription.id);
            AppLogStore.warning(
              'subscription refresh',
              'refresh failed id=${subscription.id} name=${subscription.name} '
                  'failures=${backoff.failures} '
                  'backoff=${backoff.backoffMinutes}m: $error',
            );
          }
        }),
      );
    }

    final refreshedActive = refreshedActiveSubscription;
    return SubscriptionAutoRefreshResult(
      dueCount: dueSubscriptions.length,
      refreshedActiveSubscription: refreshedActive,
      activeRuntimeChanged:
          refreshedActive != null &&
          activeBeforeFingerprint != null &&
          activeBeforeFingerprint != runtimeFingerprint(refreshedActive),
    );
  }
}
