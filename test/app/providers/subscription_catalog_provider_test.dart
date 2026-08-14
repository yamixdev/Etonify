import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/providers/subscription_catalog_provider.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test('replaces catalog and resolves the active subscription', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(subscriptionCatalogProvider.notifier);
    final subscriptions = <Subscription>[
      _subscription('first'),
      _subscription('second'),
    ];

    notifier.replace(
      subscriptions: subscriptions,
      activeProfileId: 'second',
      selectedProxyTag: 'proxy-2',
    );

    final state = container.read(subscriptionCatalogProvider);
    expect(identical(state.subscriptions, subscriptions), isTrue);
    expect(state.activeSubscription?.id, 'second');
    expect(state.selectedProxyTag, 'proxy-2');
  });

  test('refresh state changes without replacing a large catalog', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(subscriptionCatalogProvider.notifier);
    final subscriptions = <Subscription>[_subscription('first')];
    notifier.replace(
      subscriptions: subscriptions,
      activeProfileId: 'first',
      selectedProxyTag: 'proxy-1',
    );

    notifier.setActiveProfileRefreshing(true);

    final state = container.read(subscriptionCatalogProvider);
    expect(state.activeProfileRefreshing, isTrue);
    expect(identical(state.subscriptions, subscriptions), isTrue);
  });
}

Subscription _subscription(String id) {
  return Subscription(
    id: id,
    name: id,
    url: 'https://example.com/$id',
    outbounds: const <Outbound>[],
  );
}
