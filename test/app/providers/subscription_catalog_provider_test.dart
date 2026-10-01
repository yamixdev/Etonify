import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app.dart';
import 'package:meow_client/app/app_root_shell.dart';
import 'package:meow_client/app/providers/subscription_catalog_provider.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  testWidgets('a new ping does not rebuild the real application shell', (
    tester,
  ) async {
    final container = ProviderContainer();
    final store = MemoryAppSettingsStore();
    final initial = await store.loadState();
    await store.saveState(
      initial.copyWith(
        onboardingCompleted: true,
        acceptedLegalVersion: '0.2.1',
        autoCheckNoticeAcknowledged: true,
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MeowClient(store: store),
      ),
    );
    await tester.pumpAndSettle();
    final notifier = container.read(subscriptionCatalogProvider.notifier);
    final outbounds = List.generate(
      3000,
      (i) => Outbound(
        tag: 'proxy-$i',
        name: 'Proxy $i',
        config: {
          'type': 'vless',
          'server': 'server-$i.example',
          'server_port': 443,
        },
      ),
    );
    notifier.replace(
      subscriptions: [_subscription('first').copyWith(outbounds: outbounds)],
      activeProfileId: 'first',
      selectedProxyTag: 'proxy-2',
    );
    await tester.pump();
    final shell = tester.widget<AppRootShell>(find.byType(AppRootShell));
    final key = SubscriptionStore.outboundIdentityKey(outbounds[2].config);
    for (final ping in [118, 95]) {
      notifier.updateLatestPings(
        'first',
        {'proxy-2': ping},
        expectedOutboundKeys: {'proxy-2': key},
      );
      await tester.pump();
      expect(
        tester.widget<AppRootShell>(find.byType(AppRootShell)),
        same(shell),
      );
      expect(
        container
            .read(subscriptionCatalogProvider)
            .activeSubscription!
            .outbounds[2]
            .info
            .latestPing,
        ping,
      );
    }
    notifier.replaceSubscriptions([
      container
          .read(subscriptionCatalogProvider)
          .activeSubscription!
          .copyWith(name: 'Renamed'),
    ]);
    await tester.pump();
    expect(
      tester.widget<AppRootShell>(find.byType(AppRootShell)),
      isNot(same(shell)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
  });

  test('saving a ping preserves shell revision and historical latency', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(subscriptionCatalogProvider.notifier);
    final outbound = Outbound(
      tag: 'proxy-1',
      name: 'One',
      config: {'type': 'vless', 'server': 'one.example', 'server_port': 443},
    );
    notifier.replace(
      subscriptions: [
        _subscription('first').copyWith(outbounds: [outbound]),
      ],
      activeProfileId: 'first',
      selectedProxyTag: 'proxy-1',
    );
    final before = container.read(subscriptionCatalogProvider);
    var shellChanges = 0;
    container.listen(
      subscriptionCatalogProvider.select((state) => state.catalogRevision),
      (_, _) => shellChanges++,
    );

    notifier.updateLatestPings(
      'first',
      {'proxy-1': 118},
      expectedOutboundKeys: {
        'proxy-1': SubscriptionStore.outboundIdentityKey(outbound.config),
      },
    );

    final after = container.read(subscriptionCatalogProvider);
    expect(after.activeSubscription!.outbounds.single.info.latestPing, 118);
    expect(after.catalogRevision, before.catalogRevision);
    expect(shellChanges, 0);
    expect(after.selectedProxyTag, 'proxy-1');
    notifier.updateLatestPings(
      'first',
      {'proxy-1': 118},
      expectedOutboundKeys: {
        'proxy-1': SubscriptionStore.outboundIdentityKey(outbound.config),
      },
    );
    expect(container.read(subscriptionCatalogProvider), same(after));

    notifier.replaceSubscriptions([
      after.activeSubscription!.copyWith(name: 'Renamed'),
    ]);
    expect(shellChanges, 1);
  });

  test('an old ping cannot update a replaced server under the same tag', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(subscriptionCatalogProvider.notifier);
    final old = Outbound(
      tag: 'proxy-1',
      name: 'Old',
      config: {'type': 'vless', 'server': 'old.example', 'server_port': 443},
    );
    final current = Outbound(
      tag: 'proxy-1',
      name: 'New',
      config: {'type': 'vless', 'server': 'new.example', 'server_port': 443},
    );
    notifier.replace(
      subscriptions: [
        _subscription('first').copyWith(outbounds: [current]),
      ],
      activeProfileId: 'first',
      selectedProxyTag: 'proxy-1',
    );
    final before = container.read(subscriptionCatalogProvider);
    notifier.updateLatestPings(
      'first',
      {'proxy-1': 118},
      expectedOutboundKeys: {
        'proxy-1': SubscriptionStore.outboundIdentityKey(old.config),
      },
    );
    expect(
      identical(container.read(subscriptionCatalogProvider), before),
      isTrue,
    );
    expect(before.activeSubscription!.outbounds.single.info.latestPing, isNull);
  });

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
