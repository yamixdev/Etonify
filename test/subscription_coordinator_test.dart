import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/subscription_coordinator.dart';
import 'package:meow_client/app/subscription_runtime_controller.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test(
    'metadata and runtime fingerprints are loaded through one boundary',
    () async {
      final stored = _subscription('active');
      final coordinator = SubscriptionCoordinator(
        runtime: SubscriptionRuntimeController(),
        loadMetadata: () async => [stored],
        loadSubscription: (id) async => id == stored.id ? stored : null,
        payloadSnapshotFor: (_) => null,
      );

      final resolved = await coordinator.resolveMetadata(
        activeSubscriptionId: stored.id,
        selectedProxyTag: stored.selectedProxyTag,
      );

      expect(resolved.normalized.activeSubscriptionId, stored.id);
      expect(
        await coordinator.runtimeFingerprintFromStore(stored.id),
        coordinator.runtimeFingerprint(stored),
      );
      expect(await coordinator.metadataFingerprint(), isNotEmpty);
    },
  );

  test(
    'concurrent active hydration requests share the same operation',
    () async {
      final coordinator = SubscriptionCoordinator(
        runtime: SubscriptionRuntimeController(),
        loadMetadata: () async => const [],
        loadSubscription: (_) async => null,
        payloadSnapshotFor: (_) => null,
      );
      final completer = Completer<bool>();
      var calls = 0;

      Future<bool> hydrate(int generation) {
        calls++;
        expect(coordinator.isHydrationCurrent(generation), isTrue);
        return completer.future;
      }

      final first = coordinator.ensureActiveHydrated(hydrate);
      final second = coordinator.ensureActiveHydrated(hydrate);
      expect(identical(first, second), isTrue);
      expect(calls, 1);

      completer.complete(true);
      expect(await first, isTrue);
      expect(await second, isTrue);
    },
  );

  test('new hydration generation invalidates an older result', () {
    final coordinator = SubscriptionCoordinator(
      runtime: SubscriptionRuntimeController(),
      loadMetadata: () async => const [],
      loadSubscription: (_) async => null,
      payloadSnapshotFor: (_) => null,
    );

    final first = coordinator.beginHydration();
    final second = coordinator.beginHydration();

    expect(coordinator.isHydrationCurrent(first), isFalse);
    expect(coordinator.isHydrationCurrent(second), isTrue);
  });

  test(
    'active hydration waits for payload storage before reading a proxy',
    () async {
      final stored = _subscription('active');
      var payloadReady = false;
      final coordinator = SubscriptionCoordinator(
        runtime: SubscriptionRuntimeController(),
        loadMetadata: () async => [stored.copyWith(outbounds: const [])],
        loadSubscription: (_) async => stored,
        ensurePayloadReady: () async {
          await Future<void>.delayed(Duration.zero);
          payloadReady = true;
        },
        payloadSnapshotFor: (id) {
          expect(id, stored.id);
          expect(payloadReady, isTrue);
          return jsonEncode(stored.toPayloadMap());
        },
      );

      final hydrated = await coordinator.hydrateActiveSubscription(
        metadata: stored.copyWith(outbounds: const []),
        selectedProxyTag: 'proxy-1',
        preferSelectedProxyTag: true,
        preserveRuntimeState: false,
        runtimeSnapshot: const SubscriptionRuntimeSnapshot(),
        buildFullProxyList: false,
      );

      expect(hydrated.subscription.outbounds, hasLength(1));
      expect(hydrated.proxyCache.includesFullProxyList, isFalse);
      expect(hydrated.proxyCache.activeProxies, isEmpty);
      expect(hydrated.proxyCache.displayProxy?.tag, 'proxy-1');
    },
  );

  test('auto refresh reports an active runtime change', () async {
    final original = _subscription('active');
    final refreshed = original.copyWith(
      outbounds: [
        Outbound(
          tag: 'proxy-2',
          name: 'proxy-2',
          config: const {
            'type': 'vless',
            'server': 'changed.example.test',
            'server_port': 443,
          },
        ),
      ],
    );
    final refreshedIds = <String>[];
    final coordinator = SubscriptionCoordinator(
      runtime: SubscriptionRuntimeController(
        now: () => DateTime.fromMillisecondsSinceEpoch(10_000_000),
      ),
      loadMetadata: () async => [original],
      loadSubscription: (_) async => original,
      refreshSubscription: (id) async {
        refreshedIds.add(id);
        return refreshed;
      },
      payloadSnapshotFor: (_) => null,
    );

    final result = await coordinator.refreshDue(
      subscriptions: [original],
      activeSubscription: original,
      concurrency: 2,
    );

    expect(refreshedIds, [original.id]);
    expect(result.dueCount, 1);
    expect(result.refreshedActiveSubscription, refreshed);
    expect(result.activeRuntimeChanged, isTrue);
  });
}

Subscription _subscription(String id) {
  return Subscription(
    id: id,
    name: id,
    url: 'https://example.test/$id',
    selectedProxyTag: 'proxy-1',
    lastUpdated: 0,
    autoRefreshMinutes: 1,
    outbounds: [
      Outbound(
        tag: 'proxy-1',
        name: 'proxy-1',
        config: const {
          'type': 'vless',
          'server': 'example.test',
          'server_port': 443,
        },
      ),
    ],
  );
}
