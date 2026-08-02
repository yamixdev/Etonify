import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/data/subscription/subscription_parser.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/singbox/singbox_config_builder.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';

void main() {
  test('parses Xray balancer as a proxy group', () {
    final content = jsonEncode({
      'remarks': '🇪🇺 Авто | Самый быстрый',
      'routing': {
        'balancers': [
          {
            'tag': 'Auto_Balancer',
            'selector': ['proxy'],
            'strategy': {
              'type': 'leastPing',
              'settings': {'maxRTT': '500ms'},
            },
            'fallbackTag': 'direct',
          },
        ],
      },
      'burstObservatory': {
        'pingConfig': {
          'timeout': '5s',
          'interval': '30s',
          'concurrency': 12,
          'destination': 'http://www.gstatic.com/generate_204',
        },
        'subjectSelector': ['proxy'],
      },
      'outbounds': [
        _xrayVlessOutbound('proxy', 'one.example.com'),
        _xrayVlessOutbound('proxy-2', 'two.example.com'),
        _xrayVlessOutbound('other', 'other.example.com'),
        {'protocol': 'freedom', 'tag': 'direct'},
      ],
    });

    final result = SubscriptionParser.parse(content);

    expect(result.outbounds, hasLength(3));
    expect(result.groups, hasLength(1));
    expect(result.groups.single.name, 'Авто | Самый быстрый');
    expect(result.groups.single.countryCode, 'EU');
    expect(result.groups.single.sourceTag, 'Auto_Balancer');
    expect(result.groups.single.sourceOutboundTags, ['proxy', 'proxy-2']);
    expect(result.groups.single.url, 'http://www.gstatic.com/generate_204');
    expect(result.groups.single.intervalSeconds, 30);
    expect(result.groups.single.timeoutSeconds, isNull);
    expect(result.groups.single.concurrency, isNull);
    expect(result.groups.single.unavailableCheckIntervalSeconds, isNull);

    final payload = SubscriptionStore.buildSubscriptionPayloadForTest(result);
    expect(payload.groups.single['name'], 'Авто | Самый быстрый');
    expect(payload.groups.single['country'], 'EU');
  });

  test('parses grouped Xray subscription array', () {
    final content = jsonEncode([
      {
        'remarks': 'EU Auto Balancer',
        'balancers': [
          {
            'tag': 'Auto_EU_Balancer',
            'selector': ['eu-proxy'],
            'strategy': {'type': 'leastPing'},
          },
        ],
        'outbounds': [
          _xrayVlessOutbound('eu-proxy', 'eu1.example.com'),
          _xrayVlessOutbound('eu-proxy-2', 'eu2.example.com'),
          _xrayVlessOutbound('eu-proxy-3', 'eu3.example.com'),
          _xrayVlessOutbound('eu-proxy-4', 'eu4.example.com'),
          {'protocol': 'freedom', 'tag': 'direct'},
        ],
      },
      {
        'remarks': 'US Auto Balancer',
        'routing': {
          'balancers': [
            {
              'tag': 'Auto_US_Balancer',
              'selector': ['us-proxy'],
              'strategy': {'type': 'leastPing'},
            },
          ],
        },
        'outbounds': [
          _xrayVlessOutbound('us-proxy', 'us1.example.com'),
          _xrayVlessOutbound('us-proxy-2', 'us2.example.com'),
          _xrayVlessOutbound('us-proxy-3', 'us3.example.com'),
          _xrayVlessOutbound('us-proxy-4', 'us4.example.com'),
          {'protocol': 'freedom', 'tag': 'direct'},
        ],
      },
      {
        'remarks': 'DE Single',
        'outbounds': [_xrayVlessOutbound('de-single', 'de.example.com')],
      },
      {
        'remarks': 'JP Single',
        'outbounds': [_xrayVlessOutbound('jp-single', 'jp.example.com')],
      },
    ]);

    final result = SubscriptionParser.parse(content);
    final payload = SubscriptionStore.buildSubscriptionPayloadForTest(result);

    expect(result.outbounds, hasLength(10));
    expect(result.groups, hasLength(2));
    expect(result.groups.map((group) => group.name), [
      'EU Auto Balancer',
      'US Auto Balancer',
    ]);
    expect(payload.groups, hasLength(2));
    expect(payload.groups.first['outbounds'], hasLength(4));
    expect(payload.groups.last['outbounds'], hasLength(4));
  });

  test('keeps Xray balancer members scoped to their source config', () {
    final content = jsonEncode([
      {
        'remarks': 'Auto group',
        'routing': {
          'balancers': [
            {
              'tag': 'Auto_Balancer',
              'selector': ['proxy'],
              'strategy': {'type': 'leastPing'},
            },
          ],
        },
        'outbounds': [
          _xrayVlessOutbound('proxy', 'group-1.example.com'),
          _xrayVlessOutbound('proxy-2', 'group-2.example.com'),
        ],
      },
      {
        'remarks': 'Single one',
        'outbounds': [_xrayVlessOutbound('proxy', 'single-1.example.com')],
      },
      {
        'remarks': 'Single two',
        'outbounds': [_xrayVlessOutbound('proxy', 'single-2.example.com')],
      },
    ]);

    final result = SubscriptionParser.parse(content);
    final payload = SubscriptionStore.buildSubscriptionPayloadForTest(result);

    expect(result.outbounds, hasLength(4));
    expect(result.groups, hasLength(1));
    expect(result.groups.single.sourceOutboundTags, ['proxy', 'proxy-2']);
    expect(payload.groups, hasLength(1));
    expect(payload.groups.single['outbounds'], hasLength(2));
  });

  test('does not mix duplicate Xray source tags across separate groups', () {
    final content = jsonEncode([
      {
        'remarks': 'EU Auto',
        'routing': {
          'balancers': [
            {
              'tag': 'Auto_Balancer',
              'selector': ['proxy'],
              'strategy': {'type': 'leastPing'},
            },
          ],
        },
        'outbounds': [
          _xrayVlessOutbound('proxy-1', 'eu1.example.com'),
          _xrayVlessOutbound('proxy-2', 'eu2.example.com'),
        ],
      },
      {
        'remarks': 'US Auto',
        'routing': {
          'balancers': [
            {
              'tag': 'Auto_Balancer',
              'selector': ['proxy'],
              'strategy': {'type': 'leastPing'},
            },
          ],
        },
        'outbounds': [
          _xrayVlessOutbound('proxy-1', 'us1.example.com'),
          _xrayVlessOutbound('proxy-2', 'us2.example.com'),
        ],
      },
    ]);

    final result = SubscriptionParser.parse(content);
    final payload = SubscriptionStore.buildSubscriptionPayloadForTest(result);
    final serverByTag = {
      for (final outbound in payload.outbounds)
        outbound['tag'] as String:
            (outbound['config'] as Map)['server'] as String,
    };

    expect(result.groups, hasLength(2));
    expect(payload.groups, hasLength(2));

    final firstGroupServers = (payload.groups.first['outbounds'] as List)
        .map((tag) => serverByTag[tag])
        .toList(growable: false);
    final secondGroupServers = (payload.groups.last['outbounds'] as List)
        .map((tag) => serverByTag[tag])
        .toList(growable: false);

    expect(firstGroupServers, ['eu1.example.com', 'eu2.example.com']);
    expect(secondGroupServers, ['us1.example.com', 'us2.example.com']);
    expect(
      (payload.groups.first['outbounds'] as List).toSet().intersection(
        (payload.groups.last['outbounds'] as List).toSet(),
      ),
      isEmpty,
    );
  });

  test('resolves parsed group source tags to generated outbound tags', () {
    final result = SubscriptionParser.parse(
      jsonEncode({
        'remarks': 'Auto fastest',
        'routing': {
          'balancers': [
            {
              'tag': 'Auto_Balancer',
              'selector': ['proxy'],
              'strategy': {'type': 'leastPing'},
            },
          ],
        },
        'outbounds': [
          _xrayVlessOutbound('proxy', 'one.example.com'),
          _xrayVlessOutbound('proxy-2', 'two.example.com'),
        ],
      }),
    );

    final payload = SubscriptionStore.buildSubscriptionPayloadForTest(result);

    expect(payload.warnings, isEmpty);
    expect(payload.outbounds, hasLength(2));
    expect(payload.groups, hasLength(1));
    final outboundTags = payload.outbounds
        .map((entry) => entry['tag'])
        .toList(growable: false);
    expect(payload.groups.single['outbounds'], outboundTags);
    expect(payload.groups.single['tag'], 'group-auto-balancer');
  });

  test('builds global lowest over setback group urltest', () {
    const group = SubscriptionGroup(
      tag: 'group-auto',
      name: 'Auto group',
      outboundTags: ['leaf-1', 'leaf-2'],
      urlTestConfig: UrlTestConfig(
        url: 'http://www.gstatic.com/generate_204',
        method: 'setback',
        intervalSeconds: 30,
        timeoutSeconds: 6,
        concurrency: 4,
        unavailableCheckIntervalSeconds: 5,
      ),
    );
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'group-auto',
      groups: [group],
      urlTestConfig: UrlTestConfig(
        url: 'https://subscription.example/generate_204',
        intervalSeconds: 77,
        timeoutSeconds: 8,
        concurrency: 9,
        unavailableCheckIntervalSeconds: 11,
      ),
      outbounds: [
        Outbound(
          tag: 'leaf-1',
          name: 'Leaf 1',
          config: {
            'type': 'vless',
            'tag': 'leaf-1',
            'server': 'one.example.com',
            'server_port': 443,
            'uuid': 'uuid-1',
          },
        ),
        Outbound(
          tag: 'leaf-2',
          name: 'Leaf 2',
          config: {
            'type': 'vless',
            'tag': 'leaf-2',
            'server': 'two.example.com',
            'server_port': 443,
            'uuid': 'uuid-2',
          },
        ),
      ],
    );

    final plan = SingboxConfigBuilder(
      activeSubscription: subscription,
      selectedProxyTag: 'group-auto',
      vpnInboundEnabled: false,
      vpnMtu: 3400,
      vpnStrictRoute: true,
      vpnTunImplementation: TunImplementationPreference.mixed,
      proxyInboundEnabled: false,
      proxyMixedListen: '127.0.0.1',
      proxyMixedPort: 1080,
      dnsDirectResolver: 'udp://1.1.1.1',
      dnsProxyResolver: 'https://dns.cloudflare.com/dns-query',
      dnsPreferIpv6: false,
      urlTestUrl: 'https://www.gstatic.com/generate_204',
      urlTestIntervalSeconds: 180,
      urlTestTimeoutSeconds: 15,
      urlTestConcurrency: 30,
      urlTestUnavailableCheckIntervalSeconds: 5,
      blockLeaks: false,
      adBlockEnabled: false,
      useRussiaRouteData: false,
      bypassLocalNetwork: true,
      splitRoutingMode: SplitRoutingMode.disabled,
      splitRoutingPackages: const <String>[],
      logLevel: 'warning',
      tcpFastOpenEnabled: true,
      tcpMultiPathEnabled: false,
      tlsFragmentationMode: TlsFragmentationMode.disabled,
      interruptExistingConnections: true,
      urlTestStrictTolerance: true,
      markAllServersRussia: false,
    ).buildPlan();

    expect(plan.config['global'], {'urltest_concurrency_limit': 8});
    final outbounds = (plan.config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final selector = outbounds.firstWhere((entry) => entry['tag'] == 'select');
    final lowest = outbounds.firstWhere((entry) => entry['tag'] == 'lowest');
    final groupUrltest = outbounds.firstWhere(
      (entry) => entry['tag'] == 'group-auto',
    );

    expect(selector['outbounds'], ['lowest', 'group-auto', 'leaf-1', 'leaf-2']);
    expect(selector['default'], 'group-auto');
    expect(lowest['outbounds'], ['group-auto']);
    expect(lowest['timeout'], '8s');
    expect(lowest['idle_timeout'], '77s');
    expect(lowest['concurrency'], 8);
    expect(lowest['tolerance'], 1);
    expect(lowest['interrupt_exist_connections'], isFalse);
    expect(lowest['interrupt_delay_threshold'], 300);
    expect(
      outbounds.map((entry) => entry['tag']).toSet().intersection({
        'lowest-open',
        'lowest-free',
        'mixed',
      }),
      isEmpty,
    );
    expect(groupUrltest['outbounds'], ['leaf-1', 'leaf-2']);
    expect(groupUrltest['method'], 'setback');
    expect(groupUrltest['url'], 'https://subscription.example/generate_204');
    expect(groupUrltest['interval'], '77s');
    expect(groupUrltest['idle_timeout'], '77s');
    expect(groupUrltest['timeout'], '8s');
    expect(groupUrltest['concurrency'], 8);
    expect(groupUrltest['unavailable_check_interval'], '120s');
    expect(groupUrltest['tolerance'], 1);
    expect(groupUrltest['interrupt_exist_connections'], isFalse);
    expect(groupUrltest['interrupt_delay_threshold'], 300);

    final stableConfig = _defaultBuilder(
      subscription,
      capabilities: LibboxCapabilities.parseOrLegacy(
        '{"api_version":1,"core_version":"1.13.14-etonify",'
        '"supports_url_test_timeout":true,'
        '"supports_url_test_concurrency":true,'
        '"supports_url_test_deadline":true,'
        '"supports_url_test_force":true,'
        '"supports_config_check":true,'
        '"tun_stacks":["system","gvisor","mixed"]}',
      ),
    ).build();
    expect(stableConfig, isNot(contains('global')));
    final stableOutbounds = (stableConfig['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      stableOutbounds.any((entry) => entry['tag'] == mixedProxyTag),
      isFalse,
    );
    final stableLowest = stableOutbounds.firstWhere(
      (entry) => entry['tag'] == lowestProxyTag,
    );
    final stableGroup = stableOutbounds.firstWhere(
      (entry) => entry['tag'] == 'group-auto',
    );
    for (final legacyKey in const <String>[
      'timeout',
      'concurrency',
      'unavailable_check_interval',
      'interrupt_delay_threshold',
    ]) {
      expect(stableLowest, isNot(contains(legacyKey)));
      expect(stableGroup, isNot(contains(legacyKey)));
    }
    expect(stableGroup, isNot(contains('method')));
    expect(stableLowest['url'], isNotEmpty);
    expect(stableLowest['interval'], isNotEmpty);
    expect(stableLowest['idle_timeout'], isNotEmpty);
    expect(stableLowest['tolerance'], 1);
  });

  test('keeps group-only detour clone out of top-level selector', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'lagom-server-0',
      groups: [
        SubscriptionGroup(
          tag: 'lagom-server-0',
          name: 'Lagom server',
          outboundTags: ['direct-leaf', 'wl-clone'],
          urlTestConfig: UrlTestConfig(method: 'setback'),
        ),
        SubscriptionGroup(
          tag: 'whitelist',
          name: 'Whitelist',
          outboundTags: ['wl-real-1', 'wl-real-2'],
        ),
      ],
      outbounds: [
        Outbound(
          tag: 'direct-leaf',
          name: 'Direct',
          config: {
            'type': 'vless',
            'tag': 'direct-leaf',
            'server': 'direct.example.com',
            'server_port': 443,
            'uuid': 'direct-uuid',
          },
        ),
        Outbound(
          tag: 'wl-clone',
          name: 'WL',
          config: {
            'type': 'vless',
            'tag': 'wl-clone',
            'server': 'direct.example.com',
            'server_port': 443,
            'uuid': 'direct-uuid',
            'detour': 'whitelist',
            '_group_only': true,
          },
        ),
        Outbound(
          tag: 'wl-real-1',
          name: 'WL Real 1',
          config: {
            'type': 'vless',
            'tag': 'wl-real-1',
            'server': 'wl1.example.com',
            'server_port': 443,
            'uuid': 'wl-1-uuid',
          },
        ),
        Outbound(
          tag: 'wl-real-2',
          name: 'WL Real 2',
          config: {
            'type': 'vless',
            'tag': 'wl-real-2',
            'server': 'wl2.example.com',
            'server_port': 443,
            'uuid': 'wl-2-uuid',
          },
        ),
      ],
    );

    final plan = _defaultBuilder(
      subscription,
      selectedProxyTag: 'lagom-server-0',
    ).buildPlan();
    final outbounds = (plan.config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final selector = outbounds.firstWhere((entry) => entry['tag'] == 'select');
    final group = outbounds.firstWhere(
      (entry) => entry['tag'] == 'lagom-server-0',
    );
    final clone = outbounds.firstWhere((entry) => entry['tag'] == 'wl-clone');

    expect(selector['outbounds'], isNot(contains('wl-clone')));
    expect(selector['outbounds'], contains('lagom-server-0'));
    expect(selector['outbounds'], contains('whitelist'));
    expect(group['outbounds'], ['direct-leaf', 'wl-clone']);
    expect(clone, isNot(contains('_group_only')));
    expect(clone['detour'], 'whitelist');
  });

  test('subscription group urltest falls back to global settings', () {
    const group = SubscriptionGroup(
      tag: 'group-auto',
      name: 'Auto group',
      outboundTags: ['leaf-1', 'leaf-2'],
      urlTestConfig: UrlTestConfig(
        url: 'http://ignored-from-import.example/generate_204',
        intervalSeconds: 30,
        timeoutSeconds: 6,
        concurrency: 4,
        unavailableCheckIntervalSeconds: 5,
      ),
    );
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'group-auto',
      groups: [group],
      outbounds: [
        Outbound(
          tag: 'leaf-1',
          name: 'Leaf 1',
          config: {
            'type': 'vless',
            'tag': 'leaf-1',
            'server': 'one.example.com',
            'server_port': 443,
            'uuid': 'uuid-1',
          },
        ),
        Outbound(
          tag: 'leaf-2',
          name: 'Leaf 2',
          config: {
            'type': 'vless',
            'tag': 'leaf-2',
            'server': 'two.example.com',
            'server_port': 443,
            'uuid': 'uuid-2',
          },
        ),
      ],
    );

    final plan = _defaultBuilder(
      subscription,
      selectedProxyTag: 'group-auto',
      urlTestUrl: 'https://global.example/generate_204',
      urlTestIntervalSeconds: 3600,
      urlTestTimeoutSeconds: 16,
      urlTestConcurrency: 31,
      urlTestUnavailableCheckIntervalSeconds: 12,
      urlTestStrictTolerance: true,
    ).buildPlan();

    final outbounds = (plan.config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final groupUrltest = outbounds.firstWhere(
      (entry) => entry['tag'] == 'group-auto',
    );

    expect(groupUrltest['url'], 'https://global.example/generate_204');
    expect(groupUrltest['interval'], '3600s');
    expect(groupUrltest['idle_timeout'], '3600s');
    expect(groupUrltest['timeout'], '16s');
    expect(groupUrltest['concurrency'], 8);
    expect(groupUrltest['unavailable_check_interval'], '120s');
    expect(groupUrltest['tolerance'], 1);
  });

  test('does not build lowest proxies for a single outbound subscription', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'lowest',
      outbounds: [
        Outbound(
          tag: 'leaf-only',
          name: 'Leaf Only',
          config: {
            'type': 'vless',
            'tag': 'leaf-only',
            'server': 'one.example.com',
            'server_port': 443,
            'uuid': 'uuid-only',
          },
          info: OutboundInfo(latestPing: 124),
        ),
      ],
    );

    final cache = buildProxyCache(
      ProxyCacheBuildInput(
        subscription: subscription,
        selectedProxyTag: lowestProxyTag,
        lowestLatency: null,
        runtimeLowestOutboundTag: null,
        runtimeLowestSelections: const <String, String>{},
        urlTestInFlight: false,
        runtimeLatencies: const <String, int>{},
        unavailableLatencyTags: const <String>{},
        latencyErrors: const <String, String>{},
        runtimeGroupSelections: const <String, String>{},
        markAllServersRussia: false,
      ),
    );
    final plan = _defaultBuilder(
      subscription,
      selectedProxyTag: 'leaf-only',
    ).buildPlan();
    final outbounds = (plan.config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final selector = outbounds.firstWhere((entry) => entry['tag'] == 'select');
    expect(cache.displayProxy?.tag, 'leaf-only');
    expect(cache.displayProxy?.latency, 124);
    expect(cache.activeProxies.map((proxy) => proxy.tag), ['leaf-only']);
    expect(selector['outbounds'], ['leaf-only']);
    expect(selector['default'], 'leaf-only');
    expect(
      outbounds.any((entry) => isLowestProxyTag(entry['tag'] as String)),
      isFalse,
    );
    expect(outbounds.any((entry) => entry['tag'] == mixedProxyTag), isFalse);
  });

  test('applies TLS record fragmentation only to TLS proxy outbounds', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'tls-node',
      outbounds: [
        Outbound(
          tag: 'tls-node',
          name: 'TLS Node',
          config: {
            'type': 'vless',
            'tag': 'tls-node',
            'server': 'tls.example.com',
            'server_port': 443,
            'uuid': 'tls-uuid',
            'tls': {'enabled': true, 'server_name': 'tls.example.com'},
          },
        ),
        Outbound(
          tag: 'plain-node',
          name: 'Plain Node',
          config: {
            'type': 'vless',
            'tag': 'plain-node',
            'server': 'plain.example.com',
            'server_port': 80,
            'uuid': 'plain-uuid',
          },
        ),
      ],
    );

    final config = _defaultBuilder(
      subscription,
      selectedProxyTag: 'tls-node',
      tlsFragmentationMode: TlsFragmentationMode.record,
    ).build();
    final outbounds = (config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final tlsNode = outbounds.firstWhere((entry) => entry['tag'] == 'tls-node');
    final plainNode = outbounds.firstWhere(
      (entry) => entry['tag'] == 'plain-node',
    );
    final direct = outbounds.firstWhere((entry) => entry['tag'] == 'direct');
    final tls = (tlsNode['tls'] as Map).cast<String, dynamic>();

    expect(tls['record_fragment'], isTrue);
    expect(tls.containsKey('fragment'), isFalse);
    expect(plainNode.containsKey('tls'), isFalse);
    expect(direct.containsKey('tls_fragment'), isFalse);
    expect(direct.containsKey('tls'), isFalse);
  });

  test('TLS fragment mode replaces record fragmentation', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'tls-node',
      outbounds: [
        Outbound(
          tag: 'tls-node',
          name: 'TLS Node',
          config: {
            'type': 'vless',
            'tag': 'tls-node',
            'server': 'tls.example.com',
            'server_port': 443,
            'uuid': 'tls-uuid',
            'tls': {'enabled': true, 'record_fragment': true},
          },
        ),
      ],
    );

    final config = _defaultBuilder(
      subscription,
      selectedProxyTag: 'tls-node',
      tlsFragmentationMode: TlsFragmentationMode.fragment,
    ).build();
    final outbounds = (config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final tlsNode = outbounds.firstWhere((entry) => entry['tag'] == 'tls-node');
    final tls = (tlsNode['tls'] as Map).cast<String, dynamic>();

    expect(tls['fragment'], isTrue);
    expect(tls['fragment_fallback_delay'], '300ms');
    expect(tls.containsKey('record_fragment'), isFalse);
  });

  test('FakeIP is generated only for the full VPN TUN', () {
    const subscription = Subscription(
      id: 'fakeip-sub',
      name: 'FakeIP',
      url: 'file:///fakeip.json',
      outbounds: [
        Outbound(
          tag: 'node',
          name: 'Node',
          config: {
            'type': 'vless',
            'tag': 'node',
            'server': 'node.example.com',
            'server_port': 443,
            'uuid': 'node-uuid',
          },
        ),
      ],
    );

    final fullTunConfig = _defaultBuilder(
      subscription,
      vpnInboundEnabled: true,
      experimentalFakeIpEnabled: true,
    ).build();
    final fullTunDns = (fullTunConfig['dns'] as Map).cast<String, dynamic>();
    final fullTunServers = (fullTunDns['servers'] as List).cast<Map>();
    final fullTunRules = (fullTunDns['rules'] as List).cast<Map>();

    expect(
      fullTunServers.any(
        (server) =>
            server['type'] == 'fakeip' &&
            server['tag'] == 'dns-fakeip' &&
            server['inet4_range'] == '198.18.0.0/15',
      ),
      isTrue,
    );
    final fakeIpRule = fullTunRules.firstWhere(
      (rule) => rule['server'] == 'dns-fakeip',
    );
    expect(fakeIpRule['query_type'], ['A', 'AAAA']);
    expect(fullTunDns['final'], 'dns-remote');

    final splitTunConfig = _defaultBuilder(
      subscription,
      vpnInboundEnabled: true,
      experimentalFakeIpEnabled: true,
      splitRoutingMode: SplitRoutingMode.proxySelected,
      splitRoutingPackages: const ['com.example.app'],
    ).build();
    final splitTunDns = (splitTunConfig['dns'] as Map).cast<String, dynamic>();
    final splitTunServers = (splitTunDns['servers'] as List).cast<Map>();

    expect(
      splitTunServers.any((server) => server['tag'] == 'dns-fakeip'),
      isFalse,
    );
    expect(splitTunDns.containsKey('rules'), isFalse);
  });

  test('hides group-only chain hop from proxy list and lowest', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'chain-exit',
      outbounds: [
        Outbound(
          tag: 'first-hop',
          name: 'First Hop',
          config: {
            'type': 'vless',
            'tag': 'first-hop',
            'server': 'first.example.com',
            'server_port': 443,
            'uuid': 'first-uuid',
            '_group_only': true,
          },
        ),
        Outbound(
          tag: 'chain-exit',
          name: 'Chain Exit',
          config: {
            'type': 'socks',
            'tag': 'chain-exit',
            'server': 'exit.example.com',
            'server_port': 9909,
            'version': '5',
            'username': 'user',
            'password': 'pass',
            'detour': 'first-hop',
          },
        ),
      ],
    );

    final cache = buildProxyCache(
      const ProxyCacheBuildInput(
        subscription: subscription,
        selectedProxyTag: 'chain-exit',
        lowestLatency: null,
        runtimeLowestOutboundTag: null,
        runtimeLowestSelections: <String, String>{},
        urlTestInFlight: false,
        runtimeLatencies: <String, int>{},
        unavailableLatencyTags: <String>{},
        latencyErrors: <String, String>{},
        runtimeGroupSelections: <String, String>{},
        markAllServersRussia: false,
      ),
    );
    final plan = _defaultBuilder(
      subscription,
      selectedProxyTag: 'chain-exit',
    ).buildPlan();
    final outbounds = (plan.config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final selector = outbounds.firstWhere((entry) => entry['tag'] == 'select');

    expect(cache.activeProxies.map((proxy) => proxy.tag), ['chain-exit']);
    expect(cache.totalTopLevelProxyCount, 1);
    expect(selector['outbounds'], ['chain-exit']);
    expect(outbounds.any((entry) => entry['tag'] == lowestProxyTag), isFalse);
    expect(outbounds.firstWhere((entry) => entry['tag'] == 'first-hop'), {
      'type': 'vless',
      'tag': 'first-hop',
      'server': 'first.example.com',
      'server_port': 443,
      'uuid': 'first-uuid',
      'tcp_fast_open': true,
      'tcp_multi_path': false,
    });
  });

  test('legacy filtered lowest selection becomes the single lowest', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'lowest-free',
      outbounds: [
        Outbound(
          tag: 'leaf-fi',
          name: 'Leaf FI',
          config: {
            'type': 'vless',
            'tag': 'leaf-fi',
            'server': 'fi.example.com',
            'server_port': 443,
            'uuid': 'uuid-fi',
          },
          info: OutboundInfo(country: 'FI'),
        ),
        Outbound(
          tag: 'leaf-ru',
          name: 'Leaf RU',
          config: {
            'type': 'vless',
            'tag': 'leaf-ru',
            'server': 'ru.example.com',
            'server_port': 443,
            'uuid': 'uuid-ru',
          },
          info: OutboundInfo(country: 'RU'),
        ),
        Outbound(
          tag: 'leaf-kz',
          name: 'Leaf KZ',
          config: {
            'type': 'vless',
            'tag': 'leaf-kz',
            'server': 'kz.example.com',
            'server_port': 443,
            'uuid': 'uuid-kz',
          },
          info: OutboundInfo(country: 'KZ'),
        ),
        Outbound(
          tag: 'leaf-us',
          name: 'Leaf US',
          config: {
            'type': 'vless',
            'tag': 'leaf-us',
            'server': 'us.example.com',
            'server_port': 443,
            'uuid': 'uuid-us',
          },
          info: OutboundInfo(country: 'US'),
        ),
      ],
    );

    final plan = _defaultBuilder(
      subscription,
      selectedProxyTag: 'lowest-free',
      useRussiaRouteData: true,
    ).buildPlan();
    final outbounds = (plan.config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final selector = outbounds.firstWhere((entry) => entry['tag'] == 'select');
    final lowest = outbounds.firstWhere((entry) => entry['tag'] == 'lowest');

    expect(selector['outbounds'].first, lowestProxyTag);
    expect(selector['default'], lowestProxyTag);
    expect(lowest['outbounds'], ['leaf-fi', 'leaf-ru', 'leaf-kz', 'leaf-us']);
    expect(
      outbounds.map((entry) => entry['tag']).toSet().intersection({
        'lowest-open',
        'lowest-free',
        'mixed',
      }),
      isEmpty,
    );
  });

  test('mark all servers as Russia still uses the single lowest', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'lowest-open',
      markAllServersRussia: true,
      outbounds: [
        Outbound(
          tag: 'leaf-fi',
          name: 'Leaf FI',
          config: {
            'type': 'vless',
            'tag': 'leaf-fi',
            'server': 'fi.example.com',
            'server_port': 443,
            'uuid': 'uuid-fi',
          },
          info: OutboundInfo(country: 'FI'),
        ),
        Outbound(
          tag: 'leaf-us',
          name: 'Leaf US',
          config: {
            'type': 'vless',
            'tag': 'leaf-us',
            'server': 'us.example.com',
            'server_port': 443,
            'uuid': 'uuid-us',
          },
          info: OutboundInfo(country: 'US'),
        ),
      ],
    );

    final plan = _defaultBuilder(
      subscription,
      selectedProxyTag: 'lowest-open',
      useRussiaRouteData: true,
      markAllServersRussia: subscription.markAllServersRussia,
    ).buildPlan();
    final outbounds = (plan.config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final selector = outbounds.firstWhere((entry) => entry['tag'] == 'select');
    final lowest = outbounds.firstWhere(
      (entry) => entry['tag'] == lowestProxyTag,
    );

    expect(selector['default'], lowestProxyTag);
    expect(lowest['outbounds'], ['leaf-fi', 'leaf-us']);

    final cache = buildProxyCache(
      ProxyCacheBuildInput(
        subscription: subscription,
        selectedProxyTag: 'leaf-fi',
        lowestLatency: null,
        runtimeLowestOutboundTag: null,
        runtimeLowestSelections: <String, String>{},
        urlTestInFlight: false,
        runtimeLatencies: <String, int>{},
        unavailableLatencyTags: <String>{},
        latencyErrors: <String, String>{},
        runtimeGroupSelections: <String, String>{},
        markAllServersRussia: subscription.markAllServersRussia,
      ),
    );
    final leafFi = cache.activeProxies.firstWhere(
      (proxy) => proxy.tag == 'leaf-fi',
    );

    expect(leafFi.countryCode, 'RU');
  });

  test('legacy mixed selection becomes lowest without mixed routing data', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'mixed',
      outbounds: [
        Outbound(
          tag: 'leaf-fi',
          name: 'Leaf FI',
          config: {
            'type': 'vless',
            'tag': 'leaf-fi',
            'server': 'fi.example.com',
            'server_port': 443,
            'uuid': 'uuid-fi',
          },
          info: OutboundInfo(country: 'FI'),
        ),
        Outbound(
          tag: 'leaf-ru',
          name: 'Leaf RU',
          config: {
            'type': 'vless',
            'tag': 'leaf-ru',
            'server': 'ru.example.com',
            'server_port': 443,
            'uuid': 'uuid-ru',
          },
          info: OutboundInfo(country: 'RU'),
        ),
        Outbound(
          tag: 'leaf-kz',
          name: 'Leaf KZ',
          config: {
            'type': 'vless',
            'tag': 'leaf-kz',
            'server': 'kz.example.com',
            'server_port': 443,
            'uuid': 'uuid-kz',
          },
          info: OutboundInfo(country: 'KZ'),
        ),
      ],
    );

    final plan = _defaultBuilder(
      subscription,
      selectedProxyTag: 'mixed',
      useRussiaRouteData: true,
    ).buildPlan();
    final config = plan.config;
    final outbounds = (config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final selector = outbounds.firstWhere((entry) => entry['tag'] == 'select');
    final route = (config['route'] as Map).cast<String, dynamic>();
    final routeRules = (route['rules'] as List).cast<Map<String, dynamic>>();
    final ruleSets =
        (route['rule_set'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    expect(selector['default'], lowestProxyTag);
    expect(outbounds.any((entry) => entry['tag'] == mixedProxyTag), isFalse);
    expect(route['final'], 'select');
    expect(
      ruleSets.map((entry) => entry['tag']).toSet().intersection({
        'telegram-services',
        'ru-ai-services',
      }),
      isEmpty,
    );
    expect(
      routeRules,
      isNot(
        contains(
          allOf([
            containsPair('rule_set', 'ru-ai-services'),
            containsPair('outbound', lowestProxyTag),
          ]),
        ),
      ),
    );
    expect(
      routeRules,
      contains(
        allOf([
          containsPair('rule_set', [
            'ru-geosite-ru-blocked',
            'ru-geoip-ru-blocked',
          ]),
          containsPair('outbound', 'select'),
        ]),
      ),
    );
  });

  test('uses group flag as fallback and selected child flag as priority', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'group-auto',
      groups: [
        SubscriptionGroup(
          tag: 'group-auto',
          name: 'Auto',
          country: 'EU',
          outboundTags: ['leaf-fi', 'leaf-us'],
        ),
      ],
      outbounds: [
        Outbound(
          tag: 'leaf-fi',
          name: 'Leaf FI',
          config: {
            'type': 'vless',
            'tag': 'leaf-fi',
            'server': 'fi.example.com',
            'server_port': 443,
            'uuid': 'uuid-fi',
          },
        ),
        Outbound(
          tag: 'leaf-us',
          name: 'Leaf US',
          config: {
            'type': 'vless',
            'tag': 'leaf-us',
            'server': 'us.example.com',
            'server_port': 443,
            'uuid': 'uuid-us',
          },
          info: OutboundInfo(country: 'US'),
        ),
      ],
    );

    final fallback = buildProxyCache(
      const ProxyCacheBuildInput(
        subscription: subscription,
        selectedProxyTag: 'group-auto',
        lowestLatency: null,
        runtimeLowestOutboundTag: null,
        runtimeLowestSelections: <String, String>{},
        urlTestInFlight: false,
        runtimeLatencies: <String, int>{},
        unavailableLatencyTags: <String>{},
        latencyErrors: <String, String>{},
        runtimeGroupSelections: <String, String>{},
        markAllServersRussia: false,
      ),
    );
    final fallbackGroup = fallback.activeProxies.firstWhere(
      (proxy) => proxy.tag == 'group-auto',
    );
    expect(fallbackGroup.countryCode, 'EU');

    final selectedChild = buildProxyCache(
      const ProxyCacheBuildInput(
        subscription: subscription,
        selectedProxyTag: 'group-auto',
        lowestLatency: null,
        runtimeLowestOutboundTag: null,
        runtimeLowestSelections: <String, String>{},
        urlTestInFlight: false,
        runtimeLatencies: <String, int>{},
        unavailableLatencyTags: <String>{},
        latencyErrors: <String, String>{},
        runtimeGroupSelections: <String, String>{'group-auto': 'leaf-us'},
        markAllServersRussia: false,
      ),
    );
    final selectedGroup = selectedChild.activeProxies.firstWhere(
      (proxy) => proxy.tag == 'group-auto',
    );
    expect(selectedGroup.countryCode, 'US');
  });

  test('lowest follows the runtime-selected child inside a group', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: lowestProxyTag,
      groups: [
        SubscriptionGroup(
          tag: 'group-auto',
          name: 'Auto',
          country: 'EU',
          outboundTags: ['leaf-fi', 'leaf-us'],
          urlTestConfig: UrlTestConfig(method: 'setback'),
        ),
      ],
      outbounds: [
        Outbound(
          tag: 'leaf-fi',
          name: 'Leaf FI',
          config: {
            'type': 'vless',
            'tag': 'leaf-fi',
            'server': 'fi.example.com',
            'server_port': 443,
            'uuid': 'uuid-fi',
          },
          info: OutboundInfo(country: 'FI'),
        ),
        Outbound(
          tag: 'leaf-us',
          name: 'Leaf US',
          config: {
            'type': 'vless',
            'tag': 'leaf-us',
            'server': 'us.example.com',
            'server_port': 443,
            'uuid': 'uuid-us',
          },
          info: OutboundInfo(country: 'US'),
        ),
      ],
    );

    final cache = buildProxyCache(
      const ProxyCacheBuildInput(
        subscription: subscription,
        selectedProxyTag: lowestProxyTag,
        lowestLatency: null,
        runtimeLowestOutboundTag: null,
        runtimeLowestSelections: <String, String>{lowestProxyTag: 'group-auto'},
        urlTestInFlight: false,
        runtimeLatencies: <String, int>{'leaf-us': 42},
        unavailableLatencyTags: <String>{},
        latencyErrors: <String, String>{},
        runtimeGroupSelections: <String, String>{'group-auto': 'leaf-us'},
        markAllServersRussia: false,
      ),
    );

    final lowest = cache.activeProxies.firstWhere(
      (proxy) => proxy.tag == lowestProxyTag,
    );

    expect(lowest.selectedChildTag, 'group-auto');
    expect(lowest.countryCode, 'US');
    expect(lowest.latency, 42);
  });

  test('lowest never borrows another child latency', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: lowestProxyTag,
      outbounds: [
        Outbound(
          tag: 'leaf-fi',
          name: 'Finland',
          config: {
            'type': 'vless',
            'tag': 'leaf-fi',
            'server': 'fi.example.com',
            'server_port': 443,
            'uuid': 'uuid-fi',
          },
          info: OutboundInfo(country: 'FI'),
        ),
        Outbound(
          tag: 'leaf-fr',
          name: 'France',
          config: {
            'type': 'vless',
            'tag': 'leaf-fr',
            'server': 'fr.example.com',
            'server_port': 443,
            'uuid': 'uuid-fr',
          },
          info: OutboundInfo(country: 'FR'),
        ),
      ],
    );

    final cache = buildProxyCache(
      const ProxyCacheBuildInput(
        subscription: subscription,
        selectedProxyTag: lowestProxyTag,
        lowestLatency: 42,
        runtimeLowestOutboundTag: 'leaf-fr',
        runtimeLowestSelections: <String, String>{lowestProxyTag: 'leaf-fr'},
        urlTestInFlight: false,
        runtimeLatencies: <String, int>{'leaf-fi': 42},
        unavailableLatencyTags: <String>{},
        latencyErrors: <String, String>{},
        runtimeGroupSelections: <String, String>{},
        markAllServersRussia: false,
      ),
    );
    final lowest = cache.activeProxies.firstWhere(
      (proxy) => proxy.tag == lowestProxyTag,
    );

    expect(lowest.selectedChildTag, 'leaf-fr');
    expect(lowest.latency, isNull);
    expect(lowest.latencyFresh, isFalse);
  });

  test('normalizes stored reality uTLS fingerprint before startup', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      outbounds: [
        Outbound(
          tag: 'leaf',
          name: 'Leaf',
          config: {
            'type': 'vless',
            'tag': 'leaf',
            'server': 'one.example.com',
            'server_port': 443,
            'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
            'encryption': 'none',
            'tls': {
              'enabled': true,
              'utls': {'enabled': true, 'fingerprint': 'QQ'},
              'reality': {
                'enabled': true,
                'public_key': 'thwa3P0vSbbPNr0n94LqAzpFJGwTX3bpIlTyrIis7S8',
              },
            },
          },
        ),
      ],
    );

    final plan = _defaultBuilder(
      subscription,
      selectedProxyTag: 'leaf',
    ).buildPlan();
    final outbounds = (plan.config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final leaf = outbounds.firstWhere((entry) => entry['tag'] == 'leaf');

    expect(leaf['tls']['utls']['fingerprint'], 'qq');
    expect(leaf, isNot(contains('encryption')));
  });

  test('startup config normalizes comma separated reality short id', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      outbounds: [
        Outbound(
          tag: 'leaf',
          name: 'Leaf',
          config: {
            'type': 'vless',
            'tag': 'leaf',
            'server': 'one.example.com',
            'server_port': 443,
            'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
            'tls': {
              'enabled': true,
              'utls': {'enabled': true, 'fingerprint': 'chrome'},
              'reality': {
                'enabled': true,
                'public_key': 'thwa3P0vSbbPNr0n94LqAzpFJGwTX3bpIlTyrIis7S8',
                'short_id': 'ab01,cd02',
              },
            },
          },
        ),
      ],
    );

    final validation = validateStartupOutbounds(
      const StartupValidationInput(
        subscription: subscription,
        excludedOutboundTags: <String>{},
      ),
    );

    expect(validation.startableCount, 1);
    expect(validation.invalidOutbounds, isEmpty);

    final plan = _defaultBuilder(
      subscription,
      selectedProxyTag: 'leaf',
    ).buildPlan();
    final outbounds = (plan.config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final leaf = outbounds.firstWhere((entry) => entry['tag'] == 'leaf');

    expect(leaf['tls']['reality']['short_id'], 'ab01');
  });

  test('startup config gates reality spider_x by core capability', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      outbounds: [
        Outbound(
          tag: 'leaf',
          name: 'Leaf',
          config: {
            'type': 'vless',
            'tag': 'leaf',
            'server': 'one.example.com',
            'server_port': 443,
            'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
            'tls': {
              'enabled': true,
              'utls': {'enabled': true, 'fingerprint': 'chrome'},
              'reality': {
                'enabled': true,
                'public_key': 'thwa3P0vSbbPNr0n94LqAzpFJGwTX3bpIlTyrIis7S8',
                'short_id': 'ab01',
                'spider_x': '/assets?ed=2560',
              },
            },
          },
        ),
      ],
    );

    Map<String, dynamic> realityFor(LibboxCapabilities capabilities) {
      final plan = _defaultBuilder(
        subscription,
        selectedProxyTag: 'leaf',
        capabilities: capabilities,
      ).buildPlan();
      final outbounds = (plan.config['outbounds'] as List)
          .cast<Map<String, dynamic>>();
      final leaf = outbounds.firstWhere((entry) => entry['tag'] == 'leaf');
      return Map<String, dynamic>.from((leaf['tls'] as Map)['reality'] as Map);
    }

    final unsupported = LibboxCapabilities.parseOrLegacy('{"api_version":1}');
    final supported = LibboxCapabilities.parseOrLegacy(
      '{"api_version":1,"supports_reality_spider_x":true}',
    );

    expect(realityFor(unsupported), isNot(contains('spider_x')));
    expect(realityFor(supported)['spider_x'], '/assets?ed=2560');
    expect(
      realityFor(LibboxCapabilities.bundledLegacy)['spider_x'],
      '/assets?ed=2560',
    );
  });

  test('proxy chain strips inherited domain resolver', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      proxyChains: [
        SubscriptionProxyChain(
          tag: 'chain',
          name: 'Chain',
          targetTag: 'leaf',
          detourTag: 'first-hop',
        ),
      ],
      outbounds: [
        Outbound(
          tag: 'leaf',
          name: 'Leaf',
          config: {
            'type': 'vless',
            'tag': 'leaf',
            'server': 'target.example.com',
            'server_port': 443,
            'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
            'encryption': 'none',
            'domain_resolver': 'dns-remote',
          },
        ),
        Outbound(
          tag: 'first-hop',
          name: 'First Hop',
          config: {
            'type': 'hysteria2',
            'tag': 'first-hop',
            'server': 'first.example.com',
            'server_port': 443,
            'password': 'secret',
          },
        ),
      ],
    );

    final plan = _defaultBuilder(
      subscription,
      selectedProxyTag: 'chain',
    ).buildPlan();
    final outbounds = (plan.config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final chain = outbounds.firstWhere((entry) => entry['tag'] == 'chain');

    expect(chain['detour'], 'first-hop');
    expect(chain.containsKey('domain_resolver'), isFalse);
  });

  test('proxy chain uses cross subscription snapshot on tag collision', () {
    const subscription = Subscription(
      id: 'active',
      name: 'Active',
      url: 'file:///active.json',
      proxyChains: [
        SubscriptionProxyChain(
          tag: 'chain',
          name: 'Chain',
          targetTag: 'same-tag',
          detourTag: 'first-hop',
          targetSubscriptionId: 'other',
          targetName: 'Germany HTTPS',
          targetConfig: {
            'type': 'vless',
            'tag': 'same-tag',
            'server': 'stream.burger-vpn.ru',
            'server_port': 443,
            'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
            'encryption': 'none',
            'tls': {'enabled': true, 'server_name': 'stream.burger-vpn.ru'},
            'transport': {
              'type': 'ws',
              'path': '/stream/ws',
              'headers': {'Host': 'stream.burger-vpn.ru'},
            },
          },
        ),
      ],
      outbounds: [
        Outbound(
          tag: 'same-tag',
          name: 'Local UDP With Same Tag',
          config: {
            'type': 'hysteria2',
            'tag': 'same-tag',
            'server': 'finland.burger-vpn.ru',
            'server_port': 443,
            'password': 'secret',
          },
        ),
        Outbound(
          tag: 'first-hop',
          name: 'First Hop',
          config: {
            'type': 'hysteria2',
            'tag': 'first-hop',
            'server': 'first.example.com',
            'server_port': 443,
            'password': 'secret',
          },
        ),
      ],
    );

    final plan = _defaultBuilder(
      subscription,
      selectedProxyTag: 'chain',
    ).buildPlan();
    final outbounds = (plan.config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final chain = outbounds.firstWhere((entry) => entry['tag'] == 'chain');

    expect(chain['type'], 'vless');
    expect(chain['detour'], 'first-hop');
    expect(chain['server'], 'stream.burger-vpn.ru');
    expect(chain['transport']['type'], 'ws');
  });

  test('proxy chain cache uses chain runtime latency and can be selected', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'chain',
      proxyChains: [
        SubscriptionProxyChain(
          tag: 'chain',
          name: 'First -> Exit',
          targetTag: 'exit',
          detourTag: 'first',
        ),
      ],
      outbounds: [
        Outbound(
          tag: 'first',
          name: 'First',
          config: {
            'type': 'vless',
            'tag': 'first',
            'server': 'first.example.com',
            'server_port': 443,
            'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
            'encryption': 'none',
          },
          info: OutboundInfo(latestPing: 44),
        ),
        Outbound(
          tag: 'exit',
          name: 'Exit',
          config: {
            'type': 'vless',
            'tag': 'exit',
            'server': 'exit.example.com',
            'server_port': 443,
            'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
            'encryption': 'none',
          },
          info: OutboundInfo(latestPing: 222),
        ),
      ],
    );

    final cache = buildProxyCache(
      const ProxyCacheBuildInput(
        subscription: subscription,
        selectedProxyTag: 'chain',
        lowestLatency: null,
        runtimeLowestOutboundTag: null,
        runtimeLowestSelections: <String, String>{},
        urlTestInFlight: false,
        runtimeLatencies: <String, int>{'chain': 91},
        unavailableLatencyTags: <String>{},
        latencyErrors: <String, String>{},
        runtimeGroupSelections: <String, String>{},
        markAllServersRussia: false,
      ),
    );

    expect(cache.displayProxy?.tag, 'chain');
    expect(cache.displayProxy?.latency, 91);
    expect(cache.displayProxy?.latencyFresh, isTrue);
    expect(
      cache.activeProxies.firstWhere((proxy) => proxy.tag == 'chain').latency,
      91,
    );
  });

  test('proxy chain stays pinned when preview list is limited', () {
    final outbounds = [
      const Outbound(
        tag: 'first',
        name: 'First',
        config: {
          'type': 'vless',
          'tag': 'first',
          'server': 'first.example.com',
          'server_port': 443,
          'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
          'encryption': 'none',
        },
      ),
      const Outbound(
        tag: 'exit',
        name: 'Exit',
        config: {
          'type': 'vless',
          'tag': 'exit',
          'server': 'exit.example.com',
          'server_port': 443,
          'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
          'encryption': 'none',
        },
      ),
      for (var i = 0; i < 80; i++)
        Outbound(
          tag: 'z-$i',
          name: 'Node $i',
          config: {
            'type': 'vless',
            'tag': 'z-$i',
            'server': 'node-$i.example.com',
            'server_port': 443,
            'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
            'encryption': 'none',
          },
        ),
    ];
    final subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      proxyChains: const [
        SubscriptionProxyChain(
          tag: 'chain',
          name: 'zzzz chain',
          targetTag: 'exit',
          detourTag: 'first',
        ),
      ],
      outbounds: outbounds,
    );

    final cache = buildProxyCache(
      ProxyCacheBuildInput(
        subscription: subscription,
        selectedProxyTag: 'z-0',
        lowestLatency: null,
        runtimeLowestOutboundTag: null,
        runtimeLowestSelections: const <String, String>{},
        urlTestInFlight: false,
        runtimeLatencies: const <String, int>{},
        unavailableLatencyTags: const <String>{},
        latencyErrors: const <String, String>{},
        runtimeGroupSelections: const <String, String>{},
        markAllServersRussia: false,
      ),
    );

    expect(cache.activeProxies.map((proxy) => proxy.tag), contains('chain'));
  });

  test('mark all servers as Russia does not rewrite proxy chain country', () {
    const subscription = Subscription(
      id: 'sub',
      name: 'Sub',
      url: 'file:///sub.json',
      selectedProxyTag: 'chain',
      markAllServersRussia: true,
      proxyChains: [
        SubscriptionProxyChain(
          tag: 'chain',
          name: 'First -> Exit',
          targetTag: 'exit',
          detourTag: 'first',
        ),
      ],
      outbounds: [
        Outbound(
          tag: 'first',
          name: 'First',
          config: {
            'type': 'vless',
            'tag': 'first',
            'server': 'first.example.com',
            'server_port': 443,
            'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
            'encryption': 'none',
          },
          info: OutboundInfo(country: 'RU'),
        ),
        Outbound(
          tag: 'exit',
          name: 'Exit',
          config: {
            'type': 'vless',
            'tag': 'exit',
            'server': 'exit.example.com',
            'server_port': 443,
            'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
            'encryption': 'none',
          },
          info: OutboundInfo(country: 'FI'),
        ),
      ],
    );

    final cache = buildProxyCache(
      const ProxyCacheBuildInput(
        subscription: subscription,
        selectedProxyTag: 'chain',
        lowestLatency: null,
        runtimeLowestOutboundTag: null,
        runtimeLowestSelections: <String, String>{},
        urlTestInFlight: false,
        runtimeLatencies: <String, int>{},
        unavailableLatencyTags: <String>{},
        latencyErrors: <String, String>{},
        runtimeGroupSelections: <String, String>{},
        markAllServersRussia: true,
      ),
    );

    final chain = cache.activeProxies.firstWhere(
      (proxy) => proxy.tag == 'chain',
    );
    final exit = cache.activeProxies.firstWhere((proxy) => proxy.tag == 'exit');

    expect(exit.countryCode, 'RU');
    expect(chain.countryCode, 'FI');
  });

  test('split proxy-selected uses only Android TUN include packages', () {
    const subscription = Subscription(
      id: 'split-sub',
      name: 'Split',
      url: 'https://example.com/sub',
      outbounds: [
        Outbound(
          tag: 'node',
          name: 'Node',
          config: {
            'type': 'vless',
            'tag': 'node',
            'server': 'node.example.com',
            'server_port': 443,
            'uuid': 'node-uuid',
          },
        ),
      ],
    );
    final config = _defaultBuilder(
      subscription,
      vpnInboundEnabled: true,
      splitRoutingMode: SplitRoutingMode.proxySelected,
      splitRoutingPackages: const [
        'Telegram',
        'com.example.app',
        'bad package',
        'com.example.app',
        '',
      ],
    ).build();

    final tunInbound = (config['inbounds'] as List).cast<Map>().firstWhere(
      (inbound) => inbound['type'] == 'tun',
    );
    expect(tunInbound['include_package'], [
      'com.example.app',
      'com.etonify.meow_client',
    ]);
    expect(tunInbound.containsKey('exclude_package'), isFalse);
    expect(tunInbound['address'], ['172.19.0.1/30', 'fdfe:dcba:9876::1/126']);

    final route = (config['route'] as Map).cast<String, dynamic>();
    final routeRules = (route['rules'] as List).cast<Map>();
    expect(route['final'], 'select');
    expect(routeRules.any((rule) => rule.containsKey('package_name')), isFalse);
    expect(
      routeRules.any(
        (rule) =>
            rule['action'] == 'hijack-dns' &&
            rule['type'] == 'logical' &&
            rule['mode'] == 'or',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (rule) =>
            rule['inbound'] == 'tun-in' &&
            rule['network'] == 'icmp' &&
            rule['ip_cidr'] == '172.19.0.2/32' &&
            rule['action'] == 'reject' &&
            rule['method'] == 'drop',
      ),
      isTrue,
    );
  });

  test('split, local, adblock and Russia route rules keep stable priority', () {
    const subscription = Subscription(
      id: 'route-priority',
      name: 'Route priority',
      url: 'https://example.com/sub',
      outbounds: [
        Outbound(
          tag: 'node',
          name: 'Node',
          config: {
            'type': 'vless',
            'tag': 'node',
            'server': 'node.example.com',
            'server_port': 443,
            'uuid': 'node-uuid',
          },
        ),
      ],
    );
    final config = _defaultBuilder(
      subscription,
      vpnInboundEnabled: true,
      splitRoutingMode: SplitRoutingMode.proxySelected,
      splitRoutingPackages: const ['com.example.proxy'],
      useRussiaRouteData: true,
      adBlockEnabled: true,
      adBlockBlockRuleSetPath: _russiaRuleSetPath('geosite-ru-blocked.srs'),
      adBlockAllowRuleSetPath: _russiaRuleSetPath(
        'geosite-ru-available-only-inside.srs',
      ),
    ).build();

    final routeRules = ((config['route'] as Map)['rules'] as List).cast<Map>();
    final privateIndex = routeRules.indexWhere(
      (rule) => rule.containsKey('ip_is_private'),
    );
    final adBlockIndex = routeRules.indexWhere(
      (rule) => rule['rule_set'] == 'adblock-block',
    );
    final russiaSuffixIndex = routeRules.indexWhere(
      (rule) => rule.containsKey('domain_suffix'),
    );
    final russiaDirectIndex = routeRules.indexWhere(
      (rule) => rule['rule_set'] == 'ru-geosite-ru-available-only-inside',
    );
    final russiaBlockedIndex = routeRules.indexWhere(
      (rule) =>
          rule['rule_set'] is List &&
          (rule['rule_set'] as List).contains('ru-geosite-ru-blocked'),
    );
    final russiaGeoipDirectIndex = routeRules.indexWhere(
      (rule) =>
          rule['rule_set'] is List &&
          (rule['rule_set'] as List).contains('ru-geoip-ru'),
    );

    expect(routeRules.any((rule) => rule.containsKey('package_name')), isFalse);
    expect(privateIndex, greaterThanOrEqualTo(0));
    expect(adBlockIndex, greaterThan(privateIndex));
    expect(russiaSuffixIndex, greaterThan(adBlockIndex));
    expect(russiaBlockedIndex, greaterThan(adBlockIndex));
    expect(russiaBlockedIndex, lessThan(russiaSuffixIndex));
    expect(russiaDirectIndex, greaterThan(adBlockIndex));
    expect(russiaGeoipDirectIndex, greaterThan(russiaBlockedIndex));

    final dns = (config['dns'] as Map).cast<String, dynamic>();
    final dnsServers = (dns['servers'] as List).cast<Map>();
    expect(
      dnsServers.any((server) => server['tag'] == 'dns-ru-direct'),
      isTrue,
    );
    final dnsRules = (dns['rules'] as List).cast<Map>();
    expect(
      dnsRules.first,
      allOf([
        containsPair('rule_set', 'ru-geosite-ru-blocked'),
        containsPair('server', 'dns-remote'),
      ]),
    );
    expect(
      dnsRules,
      contains(
        allOf([
          containsPair('domain_suffix', ['ru', 'su', 'рф']),
          containsPair('server', 'dns-ru-direct'),
        ]),
      ),
    );
    expect(
      dnsRules,
      contains(
        allOf([
          containsPair('rule_set', 'ru-geosite-category-ru'),
          containsPair('server', 'dns-ru-direct'),
        ]),
      ),
    );
  });

  test(
    'split routing is ignored without VPN TUN so proxy-only stays proxied',
    () {
      const subscription = Subscription(
        id: 'split-proxy-only',
        name: 'Split proxy only',
        url: 'https://example.com/sub',
        outbounds: [
          Outbound(
            tag: 'node',
            name: 'Node',
            config: {
              'type': 'vless',
              'tag': 'node',
              'server': 'node.example.com',
              'server_port': 443,
              'uuid': 'node-uuid',
            },
          ),
        ],
      );
      final config = _defaultBuilder(
        subscription,
        vpnInboundEnabled: false,
        proxyInboundEnabled: true,
        proxyPassword: 'LocalOnlyPassword123456',
        splitRoutingMode: SplitRoutingMode.proxySelected,
        splitRoutingPackages: const ['com.example.app'],
      ).build();

      final route = (config['route'] as Map).cast<String, dynamic>();
      final routeRules = (route['rules'] as List).cast<Map>();
      expect(route['final'], 'select');
      expect(
        routeRules.any((rule) => rule.containsKey('package_name')),
        isFalse,
      );
      expect(
        (config['inbounds'] as List).cast<Map>().any(
          (inbound) => inbound['tag'] == 'mixed-in',
        ),
        isTrue,
      );
    },
  );

  test('split routing writes Android TUN exclude packages for bypass mode', () {
    const subscription = Subscription(
      id: 'split-sub',
      name: 'Split',
      url: 'https://example.com/sub',
      outbounds: [
        Outbound(
          tag: 'node',
          name: 'Node',
          config: {
            'type': 'vless',
            'tag': 'node',
            'server': 'node.example.com',
            'server_port': 443,
            'uuid': 'node-uuid',
          },
        ),
      ],
    );
    final config = _defaultBuilder(
      subscription,
      vpnInboundEnabled: true,
      splitRoutingMode: SplitRoutingMode.bypassSelected,
      splitRoutingPackages: const ['com.example.bypass'],
    ).build();

    final tunInbound = (config['inbounds'] as List).cast<Map>().firstWhere(
      (inbound) => inbound['type'] == 'tun',
    );
    expect(tunInbound['exclude_package'], ['com.example.bypass']);
    expect(tunInbound.containsKey('include_package'), isFalse);

    final routeRules = ((config['route'] as Map)['rules'] as List).cast<Map>();
    expect(routeRules.any((rule) => rule.containsKey('package_name')), isFalse);
  });

  test('default VPN config does not expose permanent speedtest inbound', () {
    const subscription = Subscription(
      id: 'speedtest-inbound',
      name: 'Speedtest inbound',
      url: 'https://example.com/sub',
      outbounds: [
        Outbound(
          tag: 'node',
          name: 'Node',
          config: {
            'type': 'vless',
            'tag': 'node',
            'server': 'node.example.com',
            'server_port': 443,
            'uuid': 'node-uuid',
          },
        ),
      ],
    );
    final config = _defaultBuilder(
      subscription,
      vpnInboundEnabled: true,
    ).build();

    final inbounds = (config['inbounds'] as List).cast<Map>();
    expect(
      inbounds.any((inbound) => inbound['tag'] == 'speedtest-in'),
      isFalse,
    );
  });

  test('VPN TUN captures both IPv4 and IPv6', () {
    const subscription = Subscription(
      id: 'dual-stack-tun',
      name: 'Dual stack',
      url: 'https://example.com/sub',
      outbounds: [],
    );
    final config = _defaultBuilder(
      subscription,
      vpnInboundEnabled: true,
    ).build();
    final tun = (config['inbounds'] as List).cast<Map>().firstWhere(
      (inbound) => inbound['type'] == 'tun',
    );

    expect(tun['address'], contains('172.19.0.1/30'));
    expect(tun['address'], contains('fdfe:dcba:9876::1/126'));
  });

  test('VPN TUN and local proxy can run in the same service config', () {
    const subscription = Subscription(
      id: 'vpn-with-local-proxy',
      name: 'VPN with local proxy',
      url: 'https://example.com/sub',
      outbounds: [],
    );
    final config = _defaultBuilder(
      subscription,
      vpnInboundEnabled: true,
      proxyInboundEnabled: true,
      proxyPassword: 'LocalOnlyPassword123456',
    ).build();
    final inbounds = (config['inbounds'] as List).cast<Map>();

    expect(inbounds.where((inbound) => inbound['type'] == 'tun'), hasLength(1));
    expect(
      inbounds.where((inbound) => inbound['type'] == 'mixed'),
      hasLength(1),
    );
    expect(inbounds.map((inbound) => inbound['tag']).toSet(), {
      'tun-in',
      'mixed-in',
    });
  });

  test('local proxy always requires and writes credentials', () {
    const subscription = Subscription(
      id: 'lan-proxy',
      name: 'LAN proxy',
      url: 'https://example.com/sub',
      outbounds: [],
    );
    final config = _defaultBuilder(
      subscription,
      proxyInboundEnabled: true,
      proxyMixedListen: '0.0.0.0',
      proxyUsername: 'sergey',
      proxyPassword: 'LocalOnlyPassword123456',
    ).build();
    final mixed = (config['inbounds'] as List).cast<Map>().firstWhere(
      (inbound) => inbound['type'] == 'mixed',
    );

    expect(mixed['users'], [
      {'username': 'sergey', 'password': 'LocalOnlyPassword123456'},
    ]);
    expect(
      () => _defaultBuilder(
        subscription,
        proxyInboundEnabled: true,
        proxyMixedListen: '0.0.0.0',
      ).build(),
      throwsStateError,
    );

    final loopbackConfig = _defaultBuilder(
      subscription,
      proxyInboundEnabled: true,
      proxyMixedListen: '127.0.0.1',
      proxyPassword: 'LocalOnlyPassword123456',
    ).build();
    final loopbackMixed = (loopbackConfig['inbounds'] as List)
        .cast<Map>()
        .firstWhere((inbound) => inbound['type'] == 'mixed');
    expect(loopbackMixed['users'], [
      {'username': defaultProxyUsername, 'password': 'LocalOnlyPassword123456'},
    ]);
  });

  test('invalid Russia route paths do not activate route rule sets', () {
    const subscription = Subscription(
      id: 'invalid-russia',
      name: 'Invalid Russia',
      url: 'https://example.com/sub',
      outbounds: [
        Outbound(
          tag: 'node',
          name: 'Node',
          config: {
            'type': 'vless',
            'tag': 'node',
            'server': 'node.example.com',
            'server_port': 443,
            'uuid': 'node-uuid',
          },
        ),
      ],
    );
    final config = SingboxConfigBuilder(
      activeSubscription: subscription,
      selectedProxyTag: '',
      vpnInboundEnabled: true,
      vpnMtu: 1500,
      vpnStrictRoute: true,
      vpnTunImplementation: TunImplementationPreference.mixed,
      proxyInboundEnabled: false,
      proxyMixedListen: '127.0.0.1',
      proxyMixedPort: 1080,
      dnsDirectResolver: 'udp://1.1.1.1',
      dnsProxyResolver: 'https://dns.cloudflare.com/dns-query',
      dnsPreferIpv6: false,
      urlTestUrl: 'https://www.gstatic.com/generate_204',
      urlTestIntervalSeconds: 900,
      urlTestTimeoutSeconds: 15,
      urlTestConcurrency: 4,
      urlTestUnavailableCheckIntervalSeconds: 30,
      blockLeaks: false,
      adBlockEnabled: false,
      useRussiaRouteData: true,
      russiaGeositeRuBlockedPath: '/definitely/missing/geosite.srs',
      russiaGeositeRuAvailableOnlyInsidePath: '/definitely/missing/inside.srs',
      russiaGeositeCategoryRuPath: '/definitely/missing/category-ru.srs',
      russiaGeoipRuBlockedPath: '/definitely/missing/geoip.srs',
      russiaGeoipRuWhitelistPath: '/definitely/missing/whitelist.srs',
      russiaGeoipRuPath: '/definitely/missing/ru.srs',
      russiaCuratedDirectServicesPath: '/definitely/missing/direct.srs',
      bypassLocalNetwork: true,
      splitRoutingMode: SplitRoutingMode.disabled,
      splitRoutingPackages: const <String>[],
      logLevel: 'warning',
      tcpFastOpenEnabled: true,
      tcpMultiPathEnabled: false,
      tlsFragmentationMode: TlsFragmentationMode.disabled,
      interruptExistingConnections: true,
      urlTestStrictTolerance: true,
      markAllServersRussia: false,
    ).build();

    final route = (config['route'] as Map).cast<String, dynamic>();
    final routeRules = (route['rules'] as List).cast<Map>();
    expect(route.containsKey('rule_set'), isFalse);
    expect(
      routeRules.any((rule) => rule['rule_set'] == 'ru-direct-services'),
      isFalse,
    );
    expect(
      routeRules.any((rule) => rule['rule_set'] == 'ru-geosite-ru-blocked'),
      isFalse,
    );
  });

  test('DNS builder supports udp tcp tls https and device resolvers', () {
    const subscription = Subscription(
      id: 'dns-sub',
      name: 'DNS',
      url: 'https://example.com/sub',
      outbounds: [
        Outbound(
          tag: 'node',
          name: 'Node',
          config: {
            'type': 'vless',
            'tag': 'node',
            'server': 'node.example.com',
            'server_port': 443,
            'uuid': 'node-uuid',
          },
        ),
      ],
    );

    Map<String, dynamic> remoteDns(String proxyResolver) {
      final config = _defaultBuilder(
        subscription,
        dnsDirectResolver: 'device://network',
        dnsProxyResolver: proxyResolver,
      ).build();
      final servers = (config['dns'] as Map)['servers'] as List;
      return servers.cast<Map<String, dynamic>>().firstWhere(
        (server) => server['tag'] == 'dns-remote',
      );
    }

    expect(remoteDns('udp://1.1.1.1')['type'], 'udp');
    expect(remoteDns('1.1.1.1'), {
      'type': 'udp',
      'tag': 'dns-remote',
      'server': '1.1.1.1',
      'server_port': 53,
      'detour': 'select',
    });
    expect(remoteDns('tcp://1.1.1.1')['type'], 'tcp');
    expect(remoteDns('tls://dns.google')['server_port'], 853);
    expect(remoteDns('https://dns.google/dns-query'), {
      'type': 'https',
      'tag': 'dns-remote',
      'server': 'dns.google',
      'server_port': 443,
      'path': '/dns-query',
      'detour': 'select',
    });

    Map<String, dynamic> directDns(String directResolver) {
      final config = _defaultBuilder(
        subscription,
        dnsDirectResolver: directResolver,
      ).build();
      final servers = (config['dns'] as Map)['servers'] as List;
      return servers.cast<Map<String, dynamic>>().firstWhere(
        (server) => server['tag'] == 'dns-direct',
      );
    }

    for (final resolver in const [
      'udp://dns.example',
      'tcp://dns.example',
      'tls://dns.example',
      'https://dns.example/dns-query',
    ]) {
      expect(
        directDns(resolver)['domain_resolver'],
        'dns-local',
        reason: '$resolver needs a non-circular bootstrap resolver',
      );
    }
    expect(directDns('1.1.1.1'), {
      'type': 'udp',
      'tag': 'dns-direct',
      'server': '1.1.1.1',
      'server_port': 53,
    });

    final config = _defaultBuilder(
      subscription,
      dnsDirectResolver: 'device://network',
    ).build();
    final servers = (config['dns'] as Map)['servers'] as List;
    final direct = servers.cast<Map<String, dynamic>>().firstWhere(
      (server) => server['tag'] == 'dns-direct',
    );
    expect(direct['type'], 'local');
    expect(
      (config['route'] as Map)['default_domain_resolver'],
      'dns-local',
      reason: 'proxy endpoint resolution must not depend on custom DNS',
    );

    expect(
      () => _defaultBuilder(
        subscription,
        dnsProxyResolver: 'dot://1.1.1.1',
      ).build(),
      throwsFormatException,
    );
  });

  test('Russia routes use configured direct RU DNS resolver', () {
    const subscription = Subscription(
      id: 'ru-dns-sub',
      name: 'RU DNS',
      url: 'https://example.com/sub',
      outbounds: [
        Outbound(
          tag: 'node',
          name: 'Node',
          config: {
            'type': 'vless',
            'tag': 'node',
            'server': 'node.example.com',
            'server_port': 443,
            'uuid': 'node-uuid',
          },
        ),
      ],
    );

    final config = _defaultBuilder(
      subscription,
      useRussiaRouteData: true,
      russiaDnsDirectResolver: '77.88.8.1',
    ).build();

    final servers = ((config['dns'] as Map)['servers'] as List)
        .cast<Map<String, dynamic>>();
    final ruDirect = servers.firstWhere(
      (server) => server['tag'] == 'dns-ru-direct',
    );
    expect(ruDirect['type'], 'udp');
    expect(ruDirect['server'], '77.88.8.1');
  });

  test(
    'routes only AI categories through VPN when the AI preset is active',
    () {
      const subscription = Subscription(
        id: 'ai-rule',
        name: 'AI rule',
        url: 'https://example.com/sub',
        outbounds: [
          Outbound(
            tag: 'node',
            name: 'Node',
            config: {
              'type': 'vless',
              'tag': 'node',
              'server': 'node.example.com',
              'server_port': 443,
              'uuid': 'node-uuid',
            },
          ),
        ],
      );

      final config = _defaultBuilder(
        subscription,
        trafficRulePreset: TrafficRulePreset.aiViaVpn,
        russiaAiServicesPath: _russiaRuleSetPath('geosite-ru-blocked.srs'),
      ).build();

      final route = config['route'] as Map<String, dynamic>;
      final dns = config['dns'] as Map<String, dynamic>;
      final ruleSets = (route['rule_set'] as List).cast<Map<String, dynamic>>();
      final rules = (route['rules'] as List).cast<Map<String, dynamic>>();

      expect(route['final'], 'direct');
      expect(dns['final'], 'dns-direct');
      expect(ruleSets.any((item) => item['tag'] == 'ai-services'), isTrue);
      expect(
        rules.any(
          (item) =>
              item['rule_set'] == 'ai-services' && item['outbound'] == 'select',
        ),
        isTrue,
      );
    },
  );

  test(
    'keeps the usual proxy route when selected social rule data is missing',
    () {
      const subscription = Subscription(
        id: 'social-rule',
        name: 'Social rule',
        url: 'https://example.com/sub',
        outbounds: [
          Outbound(
            tag: 'node',
            name: 'Node',
            config: {
              'type': 'vless',
              'tag': 'node',
              'server': 'node.example.com',
              'server_port': 443,
              'uuid': 'node-uuid',
            },
          ),
        ],
      );

      final config = _defaultBuilder(
        subscription,
        trafficRulePreset: TrafficRulePreset.socialViaVpn,
      ).build();

      final route = config['route'] as Map<String, dynamic>;
      final ruleSets =
          (route['rule_set'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];

      expect(route['final'], 'select');
      expect(ruleSets.any((item) => item['tag'] == 'social-services'), isFalse);
    },
  );
}

SingboxConfigBuilder _defaultBuilder(
  Subscription subscription, {
  String selectedProxyTag = '',
  bool useRussiaRouteData = false,
  TrafficRulePreset trafficRulePreset = TrafficRulePreset.none,
  bool markAllServersRussia = false,
  String urlTestUrl = 'https://www.gstatic.com/generate_204',
  int urlTestIntervalSeconds = 180,
  int urlTestTimeoutSeconds = 15,
  int urlTestConcurrency = 30,
  int urlTestUnavailableCheckIntervalSeconds = 5,
  bool urlTestStrictTolerance = true,
  bool experimentalFakeIpEnabled = false,
  TlsFragmentationMode tlsFragmentationMode = TlsFragmentationMode.disabled,
  bool vpnInboundEnabled = false,
  bool proxyInboundEnabled = false,
  String proxyMixedListen = '127.0.0.1',
  String proxyUsername = defaultProxyUsername,
  String proxyPassword = '',
  SplitRoutingMode splitRoutingMode = SplitRoutingMode.disabled,
  List<String> splitRoutingPackages = const <String>[],
  bool adBlockEnabled = false,
  String? adBlockBlockRuleSetPath,
  String? adBlockAllowRuleSetPath,
  String dnsDirectResolver = 'udp://1.1.1.1',
  String dnsProxyResolver = 'https://dns.cloudflare.com/dns-query',
  String russiaDnsDirectResolver = defaultRussiaDnsDirectResolver,
  String? russiaAiServicesPath,
  String? russiaSocialServicesPath,
  LibboxCapabilities capabilities = LibboxCapabilities.bundledLegacy,
}) {
  return SingboxConfigBuilder(
    activeSubscription: subscription,
    selectedProxyTag: selectedProxyTag,
    vpnInboundEnabled: vpnInboundEnabled,
    vpnMtu: 3400,
    vpnStrictRoute: true,
    vpnTunImplementation: TunImplementationPreference.mixed,
    proxyInboundEnabled: proxyInboundEnabled,
    proxyMixedListen: proxyMixedListen,
    proxyMixedPort: 1080,
    proxyUsername: proxyUsername,
    proxyPassword: proxyPassword,
    dnsDirectResolver: dnsDirectResolver,
    dnsProxyResolver: dnsProxyResolver,
    dnsPreferIpv6: false,
    russiaDnsDirectResolver: russiaDnsDirectResolver,
    urlTestUrl: urlTestUrl,
    urlTestIntervalSeconds: urlTestIntervalSeconds,
    urlTestTimeoutSeconds: urlTestTimeoutSeconds,
    urlTestConcurrency: urlTestConcurrency,
    urlTestUnavailableCheckIntervalSeconds:
        urlTestUnavailableCheckIntervalSeconds,
    blockLeaks: false,
    adBlockEnabled: adBlockEnabled,
    adBlockBlockRuleSetPath: adBlockBlockRuleSetPath,
    adBlockAllowRuleSetPath: adBlockAllowRuleSetPath,
    useRussiaRouteData: useRussiaRouteData,
    russiaGeositeRuBlockedPath: useRussiaRouteData
        ? _russiaRuleSetPath('geosite-ru-blocked.srs')
        : null,
    russiaGeositeRuAvailableOnlyInsidePath: useRussiaRouteData
        ? _russiaRuleSetPath('geosite-ru-available-only-inside.srs')
        : null,
    russiaGeositeCategoryRuPath: useRussiaRouteData
        ? _russiaRuleSetPath('geosite-category-ru.srs')
        : null,
    russiaGeoipRuBlockedPath: useRussiaRouteData
        ? _russiaRuleSetPath('geoip-ru-blocked.srs')
        : null,
    russiaGeoipRuWhitelistPath: useRussiaRouteData
        ? _russiaRuleSetPath('geoip-ru-whitelist.srs')
        : null,
    russiaGeoipRuPath: useRussiaRouteData
        ? _russiaRuleSetPath('geoip-ru.srs')
        : null,
    russiaCuratedDirectServicesPath: useRussiaRouteData
        ? _russiaRuleSetPath('geosite-ru-available-only-inside.srs')
        : null,
    russiaAiServicesPath: useRussiaRouteData
        ? russiaAiServicesPath ?? _russiaRuleSetPath('geosite-ru-blocked.srs')
        : russiaAiServicesPath,
    russiaSocialServicesPath: russiaSocialServicesPath,
    trafficRulePreset: trafficRulePreset,
    bypassLocalNetwork: true,
    splitRoutingMode: splitRoutingMode,
    splitRoutingPackages: splitRoutingPackages,
    logLevel: 'warning',
    tcpFastOpenEnabled: true,
    tcpMultiPathEnabled: false,
    tlsFragmentationMode: tlsFragmentationMode,
    interruptExistingConnections: true,
    urlTestStrictTolerance: urlTestStrictTolerance,
    experimentalFakeIpEnabled: experimentalFakeIpEnabled,
    markAllServersRussia: markAllServersRussia,
    capabilities: capabilities,
  );
}

String _russiaRuleSetPath(String fileName) {
  return '${Directory.current.path}/assets/route_data/russia/$fileName';
}

Map<String, dynamic> _xrayVlessOutbound(String tag, String server) {
  return {
    'protocol': 'vless',
    'tag': tag,
    'settings': {
      'vnext': [
        {
          'address': server,
          'port': 443,
          'users': [
            {'id': '$tag-uuid', 'encryption': 'none'},
          ],
        },
      ],
    },
  };
}
