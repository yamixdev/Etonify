import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/active_proxy_ip_controller.dart';

void main() {
  test(
    'active lookup target changes when configuration changes under same tag',
    () {
      final before = _target(outboundIdentityKey: 'old-config');
      final after = _target(outboundIdentityKey: 'new-config');
      expect(before.key, isNot(after.key));
    },
  );

  test('literal endpoint IP is published before runtime diagnostics', () {
    final controller = ActiveProxyIpController();
    addTearDown(controller.dispose);

    final snapshots = <ActiveProxyIpSnapshot>[];
    var endpointCalls = 0;
    var externalCalls = 0;

    controller.schedule(
      delay: Duration.zero,
      externalLookupReady: false,
      isConnected: () => true,
      isForegroundActive: () => true,
      currentTarget: () =>
          _target(endpointHost: '198.51.100.20', endpointIp: '198.51.100.20'),
      networkUsable: (_) async => true,
      resolveEndpointIp: (_) async {
        endpointCalls++;
        return null;
      },
      resolveExternalIp: (_) async {
        externalCalls++;
        return null;
      },
      persistResult: (_, _) async {},
      onSnapshot: snapshots.add,
    );

    expect(snapshots, hasLength(1));
    expect(snapshots.single.state, ActiveProxyIpState.known);
    expect(snapshots.single.source, ActiveProxyIpSource.endpoint);
    expect(snapshots.single.ip, '198.51.100.20');
    expect(endpointCalls, 0);
    expect(externalCalls, 0);
  });

  test(
    'hostname endpoint appears before external IP and is then refined',
    () async {
      final controller = ActiveProxyIpController();
      addTearDown(controller.dispose);

      final snapshots = <ActiveProxyIpSnapshot>[];
      final endpointLookup = Completer<String?>();
      final externalLookup = Completer<ActiveProxyIpResolveResult?>();
      var persistCalls = 0;

      controller.schedule(
        delay: Duration.zero,
        isConnected: () => true,
        isForegroundActive: () => true,
        currentTarget: () => _target(endpointHost: 'proxy.example.com'),
        networkUsable: (_) async => true,
        resolveEndpointIp: (_) => endpointLookup.future,
        resolveExternalIp: (_) => externalLookup.future,
        persistResult: (_, _) async {
          persistCalls++;
        },
        onSnapshot: snapshots.add,
      );

      expect(snapshots.single.state, ActiveProxyIpState.checking);
      endpointLookup.complete('198.51.100.30');
      await _waitUntil(
        () => controller.snapshot.source == ActiveProxyIpSource.endpoint,
      );
      expect(controller.snapshot.ip, '198.51.100.30');
      expect(persistCalls, 0);

      externalLookup.complete(
        const ActiveProxyIpResolveResult(ip: '203.0.113.30'),
      );
      await _waitUntil(
        () => controller.snapshot.source == ActiveProxyIpSource.external,
      );
      expect(controller.snapshot.ip, '203.0.113.30');
      expect(persistCalls, 1);
    },
  );

  test('late endpoint result cannot overwrite an external IP', () async {
    final controller = ActiveProxyIpController();
    addTearDown(controller.dispose);

    final endpointLookup = Completer<String?>();
    final externalLookup = Completer<ActiveProxyIpResolveResult?>();

    controller.schedule(
      delay: Duration.zero,
      isConnected: () => true,
      isForegroundActive: () => true,
      currentTarget: () => _target(endpointHost: 'proxy.example.com'),
      networkUsable: (_) async => true,
      resolveEndpointIp: (_) => endpointLookup.future,
      resolveExternalIp: (_) => externalLookup.future,
      persistResult: (_, _) async {},
      onSnapshot: (_) {},
    );

    await Future<void>.delayed(Duration.zero);
    externalLookup.complete(
      const ActiveProxyIpResolveResult(ip: '203.0.113.31'),
    );
    await _waitUntil(
      () => controller.snapshot.source == ActiveProxyIpSource.external,
    );

    endpointLookup.complete('198.51.100.31');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.snapshot.source, ActiveProxyIpSource.external);
    expect(controller.snapshot.ip, '203.0.113.31');
  });

  test('network generation prevents reuse of stale endpoint DNS', () async {
    final controller = ActiveProxyIpController();
    addTearDown(controller.dispose);

    final firstLookup = Completer<String?>();
    var target = _target(
      endpointHost: 'proxy.example.com',
      networkGeneration: 1,
    );
    var calls = 0;

    Future<String?> resolveEndpoint(String _) {
      calls++;
      if (calls == 1) {
        return firstLookup.future;
      }
      return Future<String?>.value('198.51.100.42');
    }

    void schedule() {
      controller.schedule(
        delay: Duration.zero,
        externalLookupReady: false,
        isConnected: () => true,
        isForegroundActive: () => true,
        currentTarget: () => target,
        networkUsable: (_) async => true,
        resolveEndpointIp: resolveEndpoint,
        resolveExternalIp: (_) async => null,
        persistResult: (_, _) async {},
        onSnapshot: (_) {},
      );
    }

    schedule();
    target = _target(endpointHost: 'proxy.example.com', networkGeneration: 2);
    schedule();
    await _waitUntil(() => controller.snapshot.ip == '198.51.100.42');

    firstLookup.complete('198.51.100.41');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(calls, 2);
    expect(controller.snapshot.ip, '198.51.100.42');
  });

  test(
    'endpoint fallback remains visible when external lookup fails',
    () async {
      final controller = ActiveProxyIpController(
        retryDelay: const Duration(days: 1),
      );
      addTearDown(controller.dispose);

      final snapshots = <ActiveProxyIpSnapshot>[];
      var externalCalls = 0;

      controller.schedule(
        delay: Duration.zero,
        isConnected: () => true,
        isForegroundActive: () => true,
        currentTarget: () =>
            _target(endpointHost: '198.51.100.40', endpointIp: '198.51.100.40'),
        networkUsable: (_) async => true,
        resolveExternalIp: (_) async {
          externalCalls++;
          return null;
        },
        persistResult: (_, _) async {},
        onSnapshot: snapshots.add,
      );

      await _waitUntil(() => externalCalls == 1);
      await Future<void>.delayed(Duration.zero);

      expect(controller.snapshot.state, ActiveProxyIpState.known);
      expect(controller.snapshot.source, ActiveProxyIpSource.endpoint);
      expect(controller.snapshot.ip, '198.51.100.40');
    },
  );

  test('schedule publishes checking then known snapshot', () async {
    final controller = ActiveProxyIpController();
    addTearDown(controller.dispose);

    final snapshots = <ActiveProxyIpSnapshot>[];
    final persisted = <String>[];
    var resolveCalls = 0;

    controller.schedule(
      delay: Duration.zero,
      isConnected: () => true,
      isForegroundActive: () => true,
      currentTarget: () => _target(),
      networkUsable: (_) async => true,
      resolveExternalIp: (tag) async {
        resolveCalls++;
        return const ActiveProxyIpResolveResult(ip: '203.0.113.10');
      },
      persistResult: (target, result) async {
        persisted.add('${target.outboundTag}:${result.ip}');
      },
      onSnapshot: snapshots.add,
    );

    await _waitUntil(() => snapshots.length >= 2);

    expect(resolveCalls, 1);
    expect(snapshots.map((snapshot) => snapshot.state), [
      ActiveProxyIpState.checking,
      ActiveProxyIpState.known,
    ]);
    expect(snapshots.last.ip, '203.0.113.10');
    expect(persisted, ['vless-1:203.0.113.10']);
  });

  test('recent cached location avoids duplicate core lookup', () async {
    final controller = ActiveProxyIpController();
    addTearDown(controller.dispose);

    final snapshots = <ActiveProxyIpSnapshot>[];
    var target = _target();
    var resolveCalls = 0;

    Future<ActiveProxyIpResolveResult?> resolve(String tag) async {
      resolveCalls++;
      return const ActiveProxyIpResolveResult(ip: '203.0.113.10');
    }

    controller.schedule(
      delay: Duration.zero,
      isConnected: () => true,
      isForegroundActive: () => true,
      currentTarget: () => target,
      networkUsable: (_) async => true,
      resolveExternalIp: resolve,
      persistResult: (_, _) async {},
      onSnapshot: snapshots.add,
    );
    await _waitUntil(
      () =>
          snapshots.isNotEmpty &&
          snapshots.last.state == ActiveProxyIpState.known,
    );

    target = _target(cachedIp: '203.0.113.10', cachedCountryCode: 'FR');
    controller.schedule(
      delay: Duration.zero,
      isConnected: () => true,
      isForegroundActive: () => true,
      currentTarget: () => target,
      networkUsable: (_) async => true,
      resolveExternalIp: resolve,
      persistResult: (_, _) async {},
      onSnapshot: snapshots.add,
    );
    await _waitUntil(
      () =>
          snapshots.isNotEmpty &&
          snapshots.last.state == ActiveProxyIpState.known &&
          snapshots.last.countryCode == 'FR',
    );

    expect(resolveCalls, 1);
    expect(snapshots.last.ip, '203.0.113.10');
    expect(snapshots.last.countryCode, 'FR');
  });

  test('cached IP is shown immediately and kept when refresh fails', () async {
    final controller = ActiveProxyIpController();
    addTearDown(controller.dispose);

    final snapshots = <ActiveProxyIpSnapshot>[];
    var resolveCalls = 0;

    controller.schedule(
      delay: Duration.zero,
      isConnected: () => true,
      isForegroundActive: () => true,
      currentTarget: () => _target(cachedIp: '203.0.113.10'),
      networkUsable: (_) async => true,
      resolveExternalIp: (_) async {
        resolveCalls++;
        return null;
      },
      persistResult: (_, _) async => fail('failed refresh must not persist'),
      onSnapshot: snapshots.add,
    );

    expect(snapshots.single.state, ActiveProxyIpState.known);
    expect(snapshots.single.ip, '203.0.113.10');

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(resolveCalls, 1);
    expect(controller.snapshot.state, ActiveProxyIpState.known);
    expect(controller.snapshot.ip, '203.0.113.10');
  });

  test('force refresh bypasses recent cached location', () async {
    final controller = ActiveProxyIpController();
    addTearDown(controller.dispose);

    final snapshots = <ActiveProxyIpSnapshot>[];
    var target = _target();
    var resolveCalls = 0;

    Future<ActiveProxyIpResolveResult?> resolve(String tag) async {
      resolveCalls++;
      return ActiveProxyIpResolveResult(ip: '203.0.113.${10 + resolveCalls}');
    }

    controller.schedule(
      delay: Duration.zero,
      isConnected: () => true,
      isForegroundActive: () => true,
      currentTarget: () => target,
      networkUsable: (_) async => true,
      resolveExternalIp: resolve,
      persistResult: (_, _) async {},
      onSnapshot: snapshots.add,
    );
    await _waitUntil(
      () =>
          snapshots.isNotEmpty &&
          snapshots.last.state == ActiveProxyIpState.known,
    );

    target = _target(cachedIp: '203.0.113.11', cachedCountryCode: 'FR');
    controller.schedule(
      delay: Duration.zero,
      forceRefresh: true,
      isConnected: () => true,
      isForegroundActive: () => true,
      currentTarget: () => target,
      networkUsable: (_) async => true,
      resolveExternalIp: resolve,
      persistResult: (_, _) async {},
      onSnapshot: snapshots.add,
    );
    expect(snapshots.last.state, ActiveProxyIpState.known);
    expect(snapshots.last.ip, '203.0.113.11');
    await _waitUntil(
      () =>
          snapshots.isNotEmpty &&
          snapshots.last.state == ActiveProxyIpState.known &&
          snapshots.last.ip == '203.0.113.12',
    );

    expect(resolveCalls, 2);
    expect(snapshots.last.countryCode, isNull);
  });

  test('disconnected schedule does not publish or resolve', () async {
    final controller = ActiveProxyIpController();
    addTearDown(controller.dispose);

    final snapshots = <ActiveProxyIpSnapshot>[];
    var resolveCalls = 0;

    controller.schedule(
      delay: Duration.zero,
      isConnected: () => false,
      isForegroundActive: () => true,
      currentTarget: () => _target(),
      networkUsable: (_) async => true,
      resolveExternalIp: (_) async {
        resolveCalls++;
        return const ActiveProxyIpResolveResult(ip: '203.0.113.10');
      },
      persistResult: (_, _) async {},
      onSnapshot: snapshots.add,
    );

    await Future<void>.delayed(Duration.zero);

    expect(resolveCalls, 0);
    expect(snapshots, isEmpty);
  });

  test('reset cancels pending lookup and publishes idle', () async {
    final controller = ActiveProxyIpController();
    addTearDown(controller.dispose);

    final snapshots = <ActiveProxyIpSnapshot>[];
    var resolveCalls = 0;

    controller.schedule(
      delay: const Duration(milliseconds: 30),
      isConnected: () => true,
      isForegroundActive: () => true,
      currentTarget: () => _target(),
      networkUsable: (_) async => true,
      resolveExternalIp: (_) async {
        resolveCalls++;
        return const ActiveProxyIpResolveResult(ip: '203.0.113.10');
      },
      persistResult: (_, _) async {},
      onSnapshot: snapshots.add,
    );
    controller.reset(onSnapshot: snapshots.add);

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(resolveCalls, 0);
    expect(snapshots.map((snapshot) => snapshot.state), [
      ActiveProxyIpState.checking,
      ActiveProxyIpState.idle,
    ]);
  });

  test('stale result is ignored after active target changes', () async {
    final controller = ActiveProxyIpController();
    addTearDown(controller.dispose);

    final snapshots = <ActiveProxyIpSnapshot>[];
    var currentTarget = _target();

    controller.schedule(
      delay: Duration.zero,
      isConnected: () => true,
      isForegroundActive: () => true,
      currentTarget: () => currentTarget,
      networkUsable: (_) async => true,
      resolveExternalIp: (_) async {
        currentTarget = _target(outboundTag: 'vless-2');
        return const ActiveProxyIpResolveResult(ip: '203.0.113.10');
      },
      persistResult: (_, _) async => fail('stale result must not persist'),
      onSnapshot: snapshots.add,
    );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(snapshots.map((snapshot) => snapshot.state), [
      ActiveProxyIpState.checking,
      ActiveProxyIpState.idle,
    ]);
    expect(controller.snapshot.state, ActiveProxyIpState.idle);
    expect(controller.snapshot.errorCode, isNull);
  });

  test('repeated refreshes share one in-flight lookup', () async {
    final controller = ActiveProxyIpController();
    addTearDown(controller.dispose);

    final snapshots = <ActiveProxyIpSnapshot>[];
    final lookup = Completer<ActiveProxyIpResolveResult?>();
    var resolveCalls = 0;
    var persistCalls = 0;

    void schedule() {
      controller.schedule(
        delay: Duration.zero,
        forceRefresh: true,
        isConnected: () => true,
        isForegroundActive: () => true,
        currentTarget: () => _target(cachedIp: '203.0.113.10'),
        networkUsable: (_) async => true,
        resolveExternalIp: (_) {
          resolveCalls++;
          return lookup.future;
        },
        persistResult: (_, _) async {
          persistCalls++;
        },
        onSnapshot: snapshots.add,
      );
    }

    schedule();
    await Future<void>.delayed(Duration.zero);
    schedule();
    await Future<void>.delayed(Duration.zero);

    expect(resolveCalls, 1);
    expect(controller.snapshot.ip, '203.0.113.10');

    lookup.complete(const ActiveProxyIpResolveResult(ip: '203.0.113.20'));
    await _waitUntil(() => controller.snapshot.ip == '203.0.113.20');

    expect(resolveCalls, 1);
    expect(persistCalls, 1);
  });

  test(
    'stale failed lookup does not publish failure or retain backoff',
    () async {
      final controller = ActiveProxyIpController(
        retryDelay: Duration.zero,
        maxFailuresBeforeBackoff: 1,
      );
      addTearDown(controller.dispose);

      final snapshots = <ActiveProxyIpSnapshot>[];
      var generation = 1;
      final lookupCompleter = Completer<ActiveProxyIpResolveResult?>();

      ActiveProxyIpTarget target() => _target(operationGeneration: generation);

      controller.schedule(
        delay: Duration.zero,
        isConnected: () => true,
        isForegroundActive: () => true,
        currentTarget: target,
        networkUsable: (_) async => true,
        resolveExternalIp: (_) => lookupCompleter.future,
        persistResult: (_, _) async {},
        onSnapshot: snapshots.add,
      );
      await Future<void>.delayed(Duration.zero);
      generation = 2;
      lookupCompleter.complete(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(snapshots.map((snapshot) => snapshot.state), [
        ActiveProxyIpState.checking,
        ActiveProxyIpState.idle,
      ]);

      controller.schedule(
        delay: Duration.zero,
        isConnected: () => true,
        isForegroundActive: () => true,
        currentTarget: target,
        networkUsable: (_) async => true,
        resolveExternalIp: (_) async =>
            const ActiveProxyIpResolveResult(ip: '203.0.113.20'),
        persistResult: (_, _) async {},
        onSnapshot: snapshots.add,
      );
      await _waitUntil(() => controller.snapshot.hasKnownIp);

      expect(controller.snapshot.ip, '203.0.113.20');
    },
  );
}

ActiveProxyIpTarget _target({
  String outboundTag = 'vless-1',
  String outboundIdentityKey = '',
  String cachedIp = '',
  String cachedCountryCode = '',
  String endpointHost = '',
  String endpointIp = '',
  String endpointCountryCode = '',
  int operationGeneration = 0,
  int networkGeneration = 0,
}) {
  return ActiveProxyIpTarget(
    subscriptionId: 'sub-1',
    outboundTag: outboundTag,
    outboundIdentityKey: outboundIdentityKey,
    cachedIp: cachedIp,
    cachedCountryCode: cachedCountryCode,
    endpointHost: endpointHost,
    endpointIp: endpointIp,
    endpointCountryCode: endpointCountryCode,
    hasCachedLocation: cachedIp.isNotEmpty && cachedCountryCode.isNotEmpty,
    operationGeneration: operationGeneration,
    networkGeneration: networkGeneration,
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('condition was not met before timeout');
}
