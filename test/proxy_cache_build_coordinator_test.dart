import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test(
    'metadata worker preserves configs and indexes updated visible nodes',
    () async {
      final source = Subscription(
        id: 'metadata',
        name: 'Metadata',
        url: '',
        outbounds: const [
          Outbound(
            tag: 'a',
            name: 'A',
            config: {'type': 'vless', 'uuid': 'secret'},
          ),
          Outbound(
            tag: 'helper',
            name: 'Helper',
            config: {'type': 'vless', '_group_only': true},
          ),
          Outbound(
            tag: 'deleted',
            name: 'Deleted',
            config: {'type': 'vless'},
            info: OutboundInfo(deleted: true),
          ),
        ],
      );
      final result = await replaceProxyMetadataInBackground(source, {
        'a': const OutboundInfo(exitCountry: 'SE', externalIp: '203.0.113.1'),
      });
      expect(result.subscription.outbounds.first.config['uuid'], 'secret');
      expect(result.subscription.outbounds.first.info.exitCountry, 'SE');
      expect(source.outbounds.first.info.exitCountry, isNull);
      expect(result.visibleOutbounds.map((node) => node.tag), ['a']);
      expect(result.outboundByTag.keys, ['a', 'helper']);
      expect(
        identical(
          result.outboundByTag['a'],
          result.subscription.outbounds.first,
        ),
        isTrue,
      );
    },
  );
  test(
    'background result indexes nested children and selected display',
    () async {
      final source = Subscription(
        id: 'indexed',
        name: 'Indexed',
        url: '',
        selectedProxyTag: 'a',
        outbounds: const [
          Outbound(tag: 'a', name: 'A', config: {'type': 'vless'}),
          Outbound(tag: 'b', name: 'B', config: {'type': 'vless'}),
        ],
        groups: const [
          SubscriptionGroup(
            tag: 'auto',
            name: 'Auto',
            outboundTags: ['a', 'b'],
          ),
        ],
      );
      final result = await buildProxyCacheInBackground(_input(source));
      expect(result.summariesByTag.keys, containsAll(['a', 'b', 'auto']));
      expect(
        identical(result.summariesByTag['a'], result.displayProxy),
        isTrue,
      );
      expect(result.summariesByTag['b']?.parentGroupTag, 'auto');
      final home = await buildHomeProxyCacheInBackground(_input(source));
      expect(home.summariesByTag.keys, ['a']);
      expect(home.activeProxies, isEmpty);
    },
  );
  test(
    'large presentation snapshots are reused and invalidated by identity',
    () async {
      final cache = ProxyPresentationSnapshotCache();
      final source = Subscription(
        id: 'large',
        name: 'Large',
        url: '',
        outbounds: List.generate(
          10000,
          (i) => Outbound(
            tag: 'proxy-$i',
            name: 'Proxy $i',
            config: {'type': 'vless', 'uuid': 'secret-$i'},
          ),
        ),
      );
      final pending = cache.get(source);
      expect(identical(pending, cache.get(source)), isTrue);
      final compact = (await pending)!;
      expect(compact.outbounds.length, 10000);
      expect(compact.outbounds.last.config, {'type': 'vless'});
      expect(identical(await cache.get(source), compact), isTrue);
      await cache.releaseStrongReference();
      expect(identical(await cache.get(source), compact), isTrue);
      final release = cache.releaseStrongReference();
      cache.seed(source, compact);
      await release;
      expect(identical(await cache.get(source), compact), isTrue);
      final changed = source.copyWith(name: 'Updated');
      expect((await cache.get(changed))!.name, 'Updated');
      cache.seed(source, compact);
      expect(identical(await cache.get(source), compact), isTrue);
      expect(await cache.get(null), isNull);
      expect(identical(await cache.get(source), compact), isFalse);
    },
  );

  group('ProxyCacheBuildCoordinator', () {
    test('coalesces repeated work and preserves a pending full build', () {
      final coordinator = ProxyCacheBuildCoordinator();

      expect(coordinator.beginOrQueue(ProxyCacheBuildScope.home), isTrue);
      expect(coordinator.inFlight, isTrue);
      expect(coordinator.beginOrQueue(ProxyCacheBuildScope.home), isFalse);
      expect(coordinator.pendingScope, ProxyCacheBuildScope.home);

      expect(coordinator.beginOrQueue(ProxyCacheBuildScope.full), isFalse);
      expect(coordinator.beginOrQueue(ProxyCacheBuildScope.home), isFalse);
      expect(coordinator.pendingScope, ProxyCacheBuildScope.full);

      expect(coordinator.complete(), ProxyCacheBuildScope.full);
      expect(coordinator.inFlight, isFalse);
      expect(coordinator.pendingScope, isNull);
    });

    test('cancelPending does not pretend to cancel active isolate work', () {
      final coordinator = ProxyCacheBuildCoordinator();

      expect(coordinator.beginOrQueue(ProxyCacheBuildScope.home), isTrue);
      expect(coordinator.beginOrQueue(ProxyCacheBuildScope.home), isFalse);
      coordinator.cancelPending();

      expect(coordinator.inFlight, isTrue);
      expect(coordinator.pendingScope, isNull);
      expect(coordinator.complete(), isNull);
    });
  });

  test('proxy cache snapshot drops config data not used by presentation', () {
    const outbound = Outbound(
      tag: 'proxy-1',
      name: 'Amsterdam',
      config: <String, dynamic>{
        'type': 'vless',
        'server': 'example.com',
        'server_port': 443,
        'uuid': 'secret-user-id',
        'tls': <String, dynamic>{
          'enabled': true,
          'server_name': 'private.example.com',
          'reality': <String, dynamic>{
            'enabled': true,
            'public_key': 'large-public-key',
          },
          'utls': <String, dynamic>{'enabled': true, 'fingerprint': 'chrome'},
        },
        'transport': <String, dynamic>{
          'type': 'xhttp',
          'headers': <String, dynamic>{'Authorization': 'secret'},
        },
      },
      info: OutboundInfo(
        country: 'NL',
        externalIp: '203.0.113.1',
        latestPing: 81,
      ),
    );
    final subscription = Subscription(
      id: 'sub-1',
      name: 'Test subscription',
      url: 'https://example.com/sub',
      selectedProxyTag: 'proxy-1',
      rawContent: 'a very large encrypted-at-rest source payload',
      outbounds: const <Outbound>[outbound],
      proxyChains: <SubscriptionProxyChain>[
        SubscriptionProxyChain(
          tag: 'chain-1',
          name: 'Chain',
          targetTag: 'proxy-1',
          detourTag: 'proxy-1',
          targetConfig: outbound.config,
        ),
      ],
    );

    final compact = compactSubscriptionForProxyCache(subscription);
    final config = compact.outbounds.single.config;

    expect(compact.rawContent, isEmpty);
    expect(config['type'], 'vless');
    expect(config['server'], 'example.com');
    expect(config['server_port'], 443);
    expect((config['tls'] as Map)['enabled'], isTrue);
    expect(((config['tls'] as Map)['reality'] as Map)['enabled'], isTrue);
    expect((config['transport'] as Map)['type'], 'xhttp');
    expect(config, isNot(contains('uuid')));
    expect(config['tls'] as Map, isNot(contains('server_name')));
    expect(config['transport'] as Map, isNot(contains('headers')));
    expect(compact.proxyChains.single.targetConfig, equals(config));

    final originalResult = buildHomeProxyCache(_input(subscription));
    final compactResult = buildHomeProxyCache(_input(compact));
    expect(
      compactResult.activeProfile?.name,
      originalResult.activeProfile?.name,
    );
    expect(
      compactResult.totalTopLevelProxyCount,
      originalResult.totalTopLevelProxyCount,
    );
    expect(compactResult.displayProxy?.tag, originalResult.displayProxy?.tag);
    expect(
      compactResult.displayProxy?.protocolLabel,
      originalResult.displayProxy?.protocolLabel,
    );
    expect(
      compactResult.displayProxy?.endpointLabel,
      originalResult.displayProxy?.endpointLabel,
    );
  });
}

ProxyCacheBuildInput _input(Subscription subscription) {
  return ProxyCacheBuildInput(
    subscription: subscription,
    selectedProxyTag: subscription.selectedProxyTag,
    lowestLatency: null,
    runtimeLowestOutboundTag: null,
    runtimeLowestSelections: const <String, String>{},
    urlTestInFlight: false,
    runtimeLatencies: const <String, int>{},
    unavailableLatencyTags: const <String>{},
    latencyErrors: const <String, String>{},
    runtimeGroupSelections: const <String, String>{},
    markAllServersRussia: false,
  );
}
