import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/subscription_coordinator.dart';
import 'package:meow_client/app/subscription_runtime_controller.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/data/subscription/subscription_failure.dart';

void main() {
  test(
    'partial automatic refresh keeps successes and classified HTTP errors',
    () async {
      final coordinator = SubscriptionCoordinator(
        runtime: SubscriptionRuntimeController(),
        payloadSnapshotFor: (_) => null,
        refreshSubscription: (id) async {
          if (id == 'failed') throw SubscriptionHttpStatusException(502);
          return _subscription(id);
        },
      );
      final result = await coordinator.refreshDue(
        subscriptions: [_subscription('ok'), _subscription('failed')],
        activeSubscription: null,
        concurrency: 1,
      );
      expect(result.entries, hasLength(2));
      expect(result.entries.first.succeeded, isTrue);
      expect(result.entries.last.failure?.httpStatus, 502);
      expect(
        result.entries.last.failure?.kind,
        SubscriptionFailureKind.httpStatus,
      );
    },
  );
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

  test(
    'auto refresh does not report a skipped source old failure again',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final first = SubscriptionSource(
        id: 'one',
        snapshot: _subscription('one'),
      );
      final skipped = SubscriptionSource(
        id: 'two',
        snapshot: _subscription('two'),
        lastAttempt: now - 1000,
        lastError: 'timeout',
      );
      final original = _subscription(
        'combined',
      ).copyWith(sources: [first, skipped]);
      final updated = original.copyWith(
        sources: [
          first.copyWith(lastAttempt: now),
          skipped,
        ],
      );
      final coordinator = SubscriptionCoordinator(
        runtime: SubscriptionRuntimeController(),
        payloadSnapshotFor: (_) => null,
        refreshSubscription: (_) async => updated,
      );
      final result = await coordinator.refreshDue(
        subscriptions: [original],
        activeSubscription: original,
        concurrency: 1,
      );
      expect(result.entries.map((e) => e.sourceId), ['one']);
      expect(result.entries.single.succeeded, isTrue);
      expect(result.activeRuntimeChanged, isFalse);
    },
  );

  test(
    'all attempted sources failing does not postpone a different source due soon',
    () async {
      final now = DateTime.now();
      final stamp = now.millisecondsSinceEpoch;
      final first = SubscriptionSource(
        id: 'one',
        snapshot: _subscription('one'),
      );
      final soon = SubscriptionSource(
        id: 'two',
        snapshot: _subscription('two').copyWith(lastUpdated: stamp - 30000),
      );
      final original = _subscription(
        'combined',
      ).copyWith(sources: [first, soon]);
      final updated = original.copyWith(
        sources: [
          first.copyWith(lastAttempt: stamp, lastError: 'httpStatus:503'),
          soon,
        ],
      );
      final runtime = SubscriptionRuntimeController(now: () => now);
      final coordinator = SubscriptionCoordinator(
        runtime: runtime,
        payloadSnapshotFor: (_) => null,
        loadSubscription: (_) async => updated,
        refreshSubscription: (_) async =>
            throw SubscriptionHttpStatusException(503),
      );
      final result = await coordinator.refreshDue(
        subscriptions: [original],
        activeSubscription: original,
        concurrency: 1,
      );
      expect(result.entries.map((e) => e.sourceId), ['one']);
      expect(result.entries.single.failure?.httpStatus, 503);
      expect(result.activeRuntimeChanged, isFalse);
      expect(
        coordinator.nextAutoRefreshDelay([updated]),
        const Duration(seconds: 30),
      );
    },
  );
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
