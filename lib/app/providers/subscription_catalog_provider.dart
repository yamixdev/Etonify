import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';

class SubscriptionCatalogState {
  const SubscriptionCatalogState({
    this.subscriptions = const <Subscription>[],
    this.activeProfileId = '',
    this.selectedProxyTag = '',
    this.activeProfileRefreshing = false,
    this.catalogRevision = 0,
  });

  final List<Subscription> subscriptions;
  final String activeProfileId;
  final String selectedProxyTag;
  final bool activeProfileRefreshing;

  /// Changes to profile/configuration data that require rebuilding the shell.
  /// Per-outbound measurements have their own visual listeners.
  final int catalogRevision;

  Subscription? get activeSubscription {
    for (final subscription in subscriptions) {
      if (subscription.id == activeProfileId) {
        return subscription;
      }
    }
    return null;
  }

  SubscriptionCatalogState copyWith({
    List<Subscription>? subscriptions,
    String? activeProfileId,
    String? selectedProxyTag,
    bool? activeProfileRefreshing,
    int? catalogRevision,
  }) {
    return SubscriptionCatalogState(
      subscriptions: subscriptions ?? this.subscriptions,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      selectedProxyTag: selectedProxyTag ?? this.selectedProxyTag,
      activeProfileRefreshing:
          activeProfileRefreshing ?? this.activeProfileRefreshing,
      catalogRevision: catalogRevision ?? this.catalogRevision,
    );
  }
}

class SubscriptionCatalogNotifier extends Notifier<SubscriptionCatalogState> {
  @override
  SubscriptionCatalogState build() => const SubscriptionCatalogState();

  void replaceSubscriptions(List<Subscription> subscriptions) {
    if (identical(subscriptions, state.subscriptions)) {
      return;
    }
    state = state.copyWith(
      subscriptions: subscriptions,
      catalogRevision: state.catalogRevision + 1,
    );
  }

  void updateLatestPings(
    String profileId,
    Map<String, int> pings, {
    required Map<String, String> expectedOutboundKeys,
  }) {
    if (pings.isEmpty) return;
    final index = state.subscriptions.indexWhere((s) => s.id == profileId);
    if (index < 0) return;
    final subscription = state.subscriptions[index];
    List<Outbound>? updated;
    for (var i = 0; i < subscription.outbounds.length; i++) {
      final outbound = subscription.outbounds[i];
      final ping = pings[outbound.tag];
      if (ping == null ||
          ping <= 0 ||
          outbound.info.latestPing == ping ||
          expectedOutboundKeys[outbound.tag] !=
              SubscriptionStore.outboundIdentityKey(outbound.config)) {
        continue;
      }
      updated ??= List<Outbound>.of(subscription.outbounds);
      updated[i] = outbound.copyWith(
        info: outbound.info.copyWith(latestPing: ping),
      );
    }
    if (updated == null) return;
    final subscriptions = List<Subscription>.of(state.subscriptions);
    subscriptions[index] = subscription.copyWith(outbounds: updated);
    // Retain catalogRevision: only the ping changed, not the profile or its
    // configuration. The runtime visual store already notified the ping row.
    state = state.copyWith(subscriptions: subscriptions);
  }

  void selectProfile(String profileId) {
    if (profileId == state.activeProfileId) {
      return;
    }
    state = state.copyWith(activeProfileId: profileId);
  }

  void selectProxy(String proxyTag) {
    if (proxyTag == state.selectedProxyTag) {
      return;
    }
    state = state.copyWith(selectedProxyTag: proxyTag);
  }

  void setActiveProfileRefreshing(bool refreshing) {
    if (refreshing == state.activeProfileRefreshing) {
      return;
    }
    state = state.copyWith(activeProfileRefreshing: refreshing);
  }

  void replace({
    required List<Subscription> subscriptions,
    required String activeProfileId,
    required String selectedProxyTag,
    bool? activeProfileRefreshing,
  }) {
    state = SubscriptionCatalogState(
      subscriptions: subscriptions,
      activeProfileId: activeProfileId,
      selectedProxyTag: selectedProxyTag,
      activeProfileRefreshing:
          activeProfileRefreshing ?? state.activeProfileRefreshing,
      catalogRevision: state.catalogRevision + 1,
    );
  }
}

final subscriptionCatalogProvider =
    NotifierProvider<SubscriptionCatalogNotifier, SubscriptionCatalogState>(
      SubscriptionCatalogNotifier.new,
      name: 'subscriptionCatalogProvider',
    );
