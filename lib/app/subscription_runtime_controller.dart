import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/app/proxy_selection_controller.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';

class SubscriptionRuntimeSelection {
  const SubscriptionRuntimeSelection({
    required this.activeSubscriptionId,
    required this.selectedProxyTag,
  });

  final String activeSubscriptionId;
  final String selectedProxyTag;
}

class ResolvedSubscriptions {
  const ResolvedSubscriptions({
    required this.subscriptions,
    required this.normalized,
    this.proxyCache,
  });

  final List<Subscription> subscriptions;
  final SubscriptionRuntimeSelection normalized;
  final ProxyCacheBuildResult? proxyCache;
}

class HydratedActiveSubscription {
  const HydratedActiveSubscription({
    required this.subscription,
    required this.normalized,
    required this.proxyCache,
    this.presentationSnapshot,
  });

  final Subscription subscription;
  final Subscription? presentationSnapshot;
  final SubscriptionRuntimeSelection normalized;
  final ProxyCacheBuildResult proxyCache;
}

class SubscriptionRuntimeSnapshot {
  const SubscriptionRuntimeSnapshot({
    this.lowestLatency,
    this.runtimeLowestOutboundTag,
    this.runtimeLowestSelections = const <String, String>{},
    this.urlTestInFlight = false,
    this.runtimeLatencies = const <String, int>{},
    this.unavailableLatencyTags = const <String>{},
    this.latencyErrors = const <String, String>{},
    this.runtimeGroupSelections = const <String, String>{},
  });

  final int? lowestLatency;
  final String? runtimeLowestOutboundTag;
  final Map<String, String> runtimeLowestSelections;
  final bool urlTestInFlight;
  final Map<String, int> runtimeLatencies;
  final Set<String> unavailableLatencyTags;
  final Map<String, String> latencyErrors;
  final Map<String, String> runtimeGroupSelections;
}

class SubscriptionAutoRefreshFailureBackoff {
  const SubscriptionAutoRefreshFailureBackoff({
    required this.failures,
    required this.backoffMinutes,
    required this.backoffUntilMillis,
  });

  final int failures;
  final int backoffMinutes;
  final int backoffUntilMillis;
}

class SubscriptionRuntimeController {
  SubscriptionRuntimeController({
    this.autoRefreshMinDelay = const Duration(seconds: 30),
    this.autoRefreshMaxDelay = const Duration(hours: 6),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration autoRefreshMinDelay;
  final Duration autoRefreshMaxDelay;
  final DateTime Function() _now;

  final Map<String, int> _autoRefreshBackoffUntil = <String, int>{};
  final Map<String, int> _autoRefreshFailures = <String, int>{};

  void clearAutoRefreshFailure(String subscriptionId) {
    _autoRefreshFailures.remove(subscriptionId);
    _autoRefreshBackoffUntil.remove(subscriptionId);
  }

  SubscriptionAutoRefreshFailureBackoff recordAutoRefreshFailure(
    String subscriptionId,
  ) {
    final failures = (_autoRefreshFailures[subscriptionId] ?? 0) + 1;
    _autoRefreshFailures[subscriptionId] = failures;
    final backoffMinutes = switch (failures) {
      1 => 15,
      2 => 60,
      3 => 180,
      _ => 360,
    };
    final backoffUntilMillis = _now()
        .add(Duration(minutes: backoffMinutes))
        .millisecondsSinceEpoch;
    _autoRefreshBackoffUntil[subscriptionId] = backoffUntilMillis;
    return SubscriptionAutoRefreshFailureBackoff(
      failures: failures,
      backoffMinutes: backoffMinutes,
      backoffUntilMillis: backoffUntilMillis,
    );
  }

  Duration? nextAutoRefreshDelay(List<Subscription> subscriptions) {
    final nowMillis = _now().millisecondsSinceEpoch;
    int? nextDueAt;
    for (final subscription in subscriptions) {
      if (subscription.disableAutoUpdate ||
          subscription.autoRefreshMinutes <= 0) {
        continue;
      }
      final dueAt =
          subscription.lastUpdated +
          subscription.autoRefreshMinutes * Duration.millisecondsPerMinute;
      final backoffUntil = _autoRefreshBackoffUntil[subscription.id];
      final effectiveDueAt = backoffUntil == null
          ? dueAt
          : max(dueAt, backoffUntil);
      if (nextDueAt == null || effectiveDueAt < nextDueAt) {
        nextDueAt = effectiveDueAt;
      }
    }
    if (nextDueAt == null) {
      return null;
    }
    final delayMs = (nextDueAt - nowMillis)
        .clamp(
          autoRefreshMinDelay.inMilliseconds,
          autoRefreshMaxDelay.inMilliseconds,
        )
        .toInt();
    return Duration(milliseconds: delayMs);
  }

  List<Subscription> dueAutoRefreshSubscriptions(
    List<Subscription> subscriptions,
  ) {
    final nowMillis = _now().millisecondsSinceEpoch;
    return subscriptions
        .where((subscription) {
          if (!subscription.needsRefresh) {
            return false;
          }
          final backoffUntil = _autoRefreshBackoffUntil[subscription.id];
          return backoffUntil == null || backoffUntil <= nowMillis;
        })
        .toList(growable: false);
  }

  ResolvedSubscriptions resolveMetadata({
    required List<Subscription> metadataSubscriptions,
    required String activeSubscriptionId,
    required String selectedProxyTag,
    bool preferSelectedProxyTag = false,
  }) {
    if (metadataSubscriptions.isEmpty) {
      return const ResolvedSubscriptions(
        subscriptions: <Subscription>[],
        normalized: SubscriptionRuntimeSelection(
          activeSubscriptionId: '',
          selectedProxyTag: '',
        ),
      );
    }

    var resolvedActiveSubscription = metadataSubscriptions.first;
    for (final subscription in metadataSubscriptions) {
      if (subscription.id == activeSubscriptionId) {
        resolvedActiveSubscription = subscription;
        break;
      }
    }
    final resolvedSelectedProxyTag =
        ProxySelectionController.effectiveSelectedProxyTag(
          metadataSelectedProxyTag: resolvedActiveSubscription.selectedProxyTag,
          preferredSelectedProxyTag: selectedProxyTag,
          preferPreferred: preferSelectedProxyTag,
        );
    return ResolvedSubscriptions(
      subscriptions: metadataSubscriptions,
      normalized: SubscriptionRuntimeSelection(
        activeSubscriptionId: resolvedActiveSubscription.id,
        selectedProxyTag: resolvedSelectedProxyTag,
      ),
    );
  }

  Future<ResolvedSubscriptions> resolveSubscriptions({
    required List<Subscription> metadataSubscriptions,
    required String activeSubscriptionId,
    required String selectedProxyTag,
    required bool preserveRuntimeState,
    required SubscriptionRuntimeSnapshot runtimeSnapshot,
    required String? Function(String subscriptionId) payloadSnapshotFor,
    bool buildFullProxyList = true,
  }) async {
    if (metadataSubscriptions.isEmpty) {
      return const ResolvedSubscriptions(
        subscriptions: <Subscription>[],
        normalized: SubscriptionRuntimeSelection(
          activeSubscriptionId: '',
          selectedProxyTag: '',
        ),
      );
    }

    String hydratedSubscriptionId = activeSubscriptionId;
    if (!metadataSubscriptions.any(
      (subscription) => subscription.id == hydratedSubscriptionId,
    )) {
      hydratedSubscriptionId = metadataSubscriptions.first.id;
    }

    final activeMetadata = metadataSubscriptions.firstWhere(
      (subscription) => subscription.id == hydratedSubscriptionId,
    );
    final hydrated = await hydrateActiveSubscriptionAndBuildProxyCache(
      metadata: activeMetadata,
      selectedProxyTag: selectedProxyTag,
      preferSelectedProxyTag: selectedProxyTag.trim().isNotEmpty,
      preserveRuntimeState: preserveRuntimeState,
      runtimeSnapshot: runtimeSnapshot,
      payloadSnapshot: payloadSnapshotFor(activeMetadata.id),
      buildFullProxyList: buildFullProxyList,
    );
    final subscriptions = metadataSubscriptions
        .map(
          (subscription) => subscription.id == hydrated.subscription.id
              ? hydrated.subscription
              : subscription,
        )
        .toList(growable: false);

    return ResolvedSubscriptions(
      subscriptions: subscriptions,
      normalized: hydrated.normalized,
      proxyCache: hydrated.proxyCache,
    );
  }

  Future<HydratedActiveSubscription>
  hydrateActiveSubscriptionAndBuildProxyCache({
    required Subscription metadata,
    required String selectedProxyTag,
    required bool preferSelectedProxyTag,
    required bool preserveRuntimeState,
    required SubscriptionRuntimeSnapshot runtimeSnapshot,
    required String? payloadSnapshot,
    bool buildFullProxyList = true,
  }) {
    final metadataMap = metadata.toMetadataMap();
    final lowestLatency = preserveRuntimeState
        ? runtimeSnapshot.lowestLatency
        : null;
    final runtimeLowestOutboundTag = preserveRuntimeState
        ? runtimeSnapshot.runtimeLowestOutboundTag
        : null;
    final runtimeLowestSelections = preserveRuntimeState
        ? Map<String, String>.from(runtimeSnapshot.runtimeLowestSelections)
        : <String, String>{};
    final urlTestInFlight = preserveRuntimeState
        ? runtimeSnapshot.urlTestInFlight
        : false;
    final runtimeLatencies = preserveRuntimeState
        ? Map<String, int>.from(runtimeSnapshot.runtimeLatencies)
        : <String, int>{};
    final unavailableLatencyTags = preserveRuntimeState
        ? Set<String>.from(runtimeSnapshot.unavailableLatencyTags)
        : <String>{};
    final latencyErrors = preserveRuntimeState
        ? Map<String, String>.from(runtimeSnapshot.latencyErrors)
        : <String, String>{};
    final runtimeGroupSelections = preserveRuntimeState
        ? Map<String, String>.from(runtimeSnapshot.runtimeGroupSelections)
        : <String, String>{};
    final markAllServersRussia = metadata.markAllServersRussia;

    return Isolate.run(() {
      final metadataSubscription = Subscription.fromMetadataMap(metadataMap);
      final subscription = payloadSnapshot == null
          ? metadataSubscription
          : SubscriptionStore.hydratePayloadJson(
              metadataSubscription,
              payloadSnapshot,
            );
      final normalized = normalizeActiveSubscriptionSelection(
        subscription,
        selectedProxyTag: selectedProxyTag,
        preferSelectedProxyTag: preferSelectedProxyTag,
      );
      final normalizedSubscription = subscription.copyWith(
        selectedProxyTag: normalized.selectedProxyTag,
      );
      final cacheInput = ProxyCacheBuildInput(
        subscription: normalizedSubscription,
        selectedProxyTag: normalized.selectedProxyTag,
        lowestLatency: lowestLatency,
        runtimeLowestOutboundTag: runtimeLowestOutboundTag,
        runtimeLowestSelections: runtimeLowestSelections,
        urlTestInFlight: urlTestInFlight,
        runtimeLatencies: runtimeLatencies,
        unavailableLatencyTags: unavailableLatencyTags,
        latencyErrors: latencyErrors,
        runtimeGroupSelections: runtimeGroupSelections,
        markAllServersRussia: markAllServersRussia,
      );
      final proxyCache = buildFullProxyList
          ? buildProxyCache(cacheInput)
          : buildHomeProxyCache(cacheInput);
      return HydratedActiveSubscription(
        subscription: normalizedSubscription.withoutRawContentForRuntime(),
        presentationSnapshot: compactSubscriptionForProxyCache(
          normalizedSubscription,
        ),
        normalized: normalized,
        proxyCache: proxyCache,
      );
    }, debugName: 'meow-active-subscription');
  }

  String subscriptionRuntimeFingerprint(Subscription subscription) {
    return jsonEncode(
      stableRuntimeFingerprintValue({
        'selected': subscription.selectedProxyTag,
        'outbounds': [
          for (final outbound in subscription.outbounds)
            if (!outbound.info.deleted)
              {'tag': outbound.tag, 'config': outbound.config},
        ],
        'groups': [for (final group in subscription.groups) group.toMap()],
      }),
    );
  }

  String? subscriptionRuntimeFingerprintFromStore({
    required String subscriptionId,
    required Subscription? Function(String subscriptionId) loadSubscription,
  }) {
    final id = subscriptionId.trim();
    if (id.isEmpty) {
      return null;
    }
    final subscription = loadSubscription(id);
    return subscription == null
        ? null
        : subscriptionRuntimeFingerprint(subscription);
  }

  String subscriptionsMetadataFingerprint(
    List<Subscription> metadataSubscriptions,
  ) {
    return jsonEncode(
      stableRuntimeFingerprintValue([
        for (final subscription in metadataSubscriptions)
          subscription.toMetadataMap(),
      ]),
    );
  }
}

SubscriptionRuntimeSelection normalizeActiveSubscriptionSelection(
  Subscription activeSubscription, {
  required String selectedProxyTag,
  required bool preferSelectedProxyTag,
}) {
  Outbound? selectedOutbound;
  final visibleOutbounds = <Outbound>[];
  final visibleOutboundTags = <String>{};
  for (final outbound in activeSubscription.outbounds) {
    if (outbound.info.deleted || outbound.config['_group_only'] == true) {
      continue;
    }
    visibleOutbounds.add(outbound);
    visibleOutboundTags.add(outbound.tag);
  }
  final effectiveSelectedProxyTag =
      ProxySelectionController.effectiveSelectedProxyTag(
        metadataSelectedProxyTag: activeSubscription.selectedProxyTag,
        preferredSelectedProxyTag: selectedProxyTag,
        preferPreferred: preferSelectedProxyTag,
      );
  final proxyChainTags = activeSubscription.proxyChains
      .map((chain) => chain.tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet();
  if (proxyChainTags.contains(effectiveSelectedProxyTag)) {
    return SubscriptionRuntimeSelection(
      activeSubscriptionId: activeSubscription.id,
      selectedProxyTag: effectiveSelectedProxyTag,
    );
  }
  if (visibleOutbounds.length == 1) {
    final singleTag = visibleOutbounds.single.tag;
    if (effectiveSelectedProxyTag.isEmpty ||
        isSyntheticProxyTag(effectiveSelectedProxyTag) ||
        !visibleOutboundTags.contains(effectiveSelectedProxyTag)) {
      return SubscriptionRuntimeSelection(
        activeSubscriptionId: activeSubscription.id,
        selectedProxyTag: singleTag,
      );
    }
  }
  if (isLowestProxyTag(effectiveSelectedProxyTag) &&
      visibleOutbounds.isNotEmpty) {
    return SubscriptionRuntimeSelection(
      activeSubscriptionId: activeSubscription.id,
      selectedProxyTag: effectiveSelectedProxyTag,
    );
  }
  for (final group in activeSubscription.groups) {
    if (group.tag == effectiveSelectedProxyTag &&
        group.outboundTags.any(visibleOutboundTags.contains)) {
      return SubscriptionRuntimeSelection(
        activeSubscriptionId: activeSubscription.id,
        selectedProxyTag: group.tag,
      );
    }
  }
  for (final outbound in visibleOutbounds) {
    if (outbound.tag == effectiveSelectedProxyTag) {
      selectedOutbound = outbound;
      break;
    }
  }
  if (selectedOutbound == null && visibleOutbounds.length > 1) {
    return SubscriptionRuntimeSelection(
      activeSubscriptionId: activeSubscription.id,
      selectedProxyTag: lowestProxyTag,
    );
  }
  selectedOutbound ??= visibleOutbounds.isEmpty
      ? null
      : visibleOutbounds.single;

  return SubscriptionRuntimeSelection(
    activeSubscriptionId: activeSubscription.id,
    selectedProxyTag: selectedOutbound?.tag ?? '',
  );
}

Object? stableRuntimeFingerprintValue(Object? value) {
  if (value is Map) {
    final result = <String, Object?>{};
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList(growable: false)
          ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      result[entry.key] = stableRuntimeFingerprintValue(entry.value);
    }
    return result;
  }
  if (value is Iterable) {
    return value.map(stableRuntimeFingerprintValue).toList(growable: false);
  }
  return value;
}
