import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
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
