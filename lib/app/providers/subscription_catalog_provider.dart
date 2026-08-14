import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/models/subscription.dart';

class SubscriptionCatalogState {
  const SubscriptionCatalogState({
    this.subscriptions = const <Subscription>[],
    this.activeProfileId = '',
    this.selectedProxyTag = '',
    this.activeProfileRefreshing = false,
  });

  final List<Subscription> subscriptions;
  final String activeProfileId;
  final String selectedProxyTag;
  final bool activeProfileRefreshing;

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
  }) {
    return SubscriptionCatalogState(
      subscriptions: subscriptions ?? this.subscriptions,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      selectedProxyTag: selectedProxyTag ?? this.selectedProxyTag,
      activeProfileRefreshing:
          activeProfileRefreshing ?? this.activeProfileRefreshing,
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
    );
  }
}

final subscriptionCatalogProvider =
    NotifierProvider<SubscriptionCatalogNotifier, SubscriptionCatalogState>(
      SubscriptionCatalogNotifier.new,
      name: 'subscriptionCatalogProvider',
    );
