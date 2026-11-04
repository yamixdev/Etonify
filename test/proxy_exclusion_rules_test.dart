import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/models/proxy_exclusion_rules.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/data/local/app_settings_store.dart';

Outbound node(
  String tag, {
  String type = 'vless',
  bool reality = true,
  String transport = 'grpc',
  String? country,
}) => Outbound(
  tag: tag,
  name: tag,
  config: {
    'type': type,
    'server': 'example.com',
    'server_port': 443,
    'uuid': '00000000-0000-0000-0000-000000000001',
    'tls': {
      'enabled': true,
      if (reality) 'reality': {'enabled': true},
    },
    'transport': {'type': transport},
  },
  info: OutboundInfo(country: country),
);

void main() {
  test('native UDP protocols never match a TCP transport rule', () {
    final condition = ProxyExclusionCondition(transport: 'tcp');
    for (final type in ['hysteria', 'hysteria2', 'tuic', 'wireguard']) {
      expect(
        condition.matches(
          Outbound(tag: type, name: type, config: {'type': type}),
        ),
        isFalse,
      );
    }
  });

  test(
    'eligibility projection hides excluded choices but retains chain dependencies',
    () {
      final excluded = node('dependency');
      final chain = node(
        'chain',
      ).copyWith(config: {...node('chain').config, 'detour': 'dependency'});
      final source = Subscription(
        id: 'one',
        name: 'one',
        url: '',
        outbounds: [excluded, chain],
      );
      final projected = ProxyExclusionRules(
        excludedTags: {'dependency'},
      ).eligibleSubscription(source);
      expect(projected.concreteServerTags, {'chain'});
      expect(
        projected.outbounds.map((node) => node.tag),
        contains('dependency'),
      );
      expect(projected.outbounds.first.config['_group_only'], isTrue);
      expect(source.outbounds.first.config['_group_only'], isNull);
    },
  );

  test('nested groups expose concrete leaves, not detour dependencies', () {
    final subscription = Subscription(
      id: 'nested',
      name: 'Nested',
      url: '',
      outbounds: [
        node('visible'),
        node(
          'dependency',
        ).copyWith(config: {...node('dependency').config, '_group_only': true}),
        node(
          'broken',
        ).copyWith(config: {...node('broken').config, 'detour': 'missing'}),
      ],
      groups: const [
        SubscriptionGroup(tag: 'outer', name: 'Outer', outboundTags: ['inner']),
        SubscriptionGroup(
          tag: 'inner',
          name: 'Inner',
          outboundTags: ['visible', 'embedded', 'broken'],
          config: {
            '_direct_outbounds': {
              'embedded': {'type': 'trojan', 'server': 'example.com'},
            },
          },
        ),
      ],
    );
    expect(
      ProxyExclusionRules.concreteServers(
        subscription,
      ).map((n) => n.tag).toSet(),
      {'visible', 'embedded'},
    );
    expect(
      ProxyExclusionRules(
        conditions: [ProxyExclusionCondition(protocol: 'trojan')],
      ).excludedTagsFor(subscription),
      {'embedded'},
    );
    expect(subscription.outbounds.length, 3);
  });

  test(
    'profile Russia override matches country rule without changing nodes',
    () {
      final subscription = Subscription(
        id: 'ru',
        name: 'RU',
        url: '',
        markAllServersRussia: true,
        outbounds: [node('unknown')],
      );
      expect(
        ProxyExclusionRules(
          conditions: [ProxyExclusionCondition(country: 'RU')],
        ).excludedTagsFor(subscription),
        {'unknown'},
      );
      expect(subscription.outbounds.single.info.country, isNull);
    },
  );

  test(
    'compound fields use AND, separate conditions and manual tags use OR',
    () {
      final rules = ProxyExclusionRules(
        excludedTags: {'manual'},
        conditions: [
          ProxyExclusionCondition(
            protocol: ' VLESS ',
            security: 'Reality',
            transport: 'gRPC',
          ),
          ProxyExclusionCondition(country: 'ru'),
        ],
      );
      expect(rules.excludes(node('match')), isTrue);
      expect(rules.excludes(node('tls', reality: false)), isFalse);
      expect(rules.excludes(node('ws', transport: 'ws')), isFalse);
      expect(rules.excludes(node('manual', type: 'trojan')), isTrue);
      expect(rules.excludes(node('ru', type: 'trojan', country: 'RU')), isTrue);
      expect(rules.excludes(node('unknown', type: 'trojan')), isFalse);
    },
  );

  test('empty or malformed condition never matches everything', () {
    expect(ProxyExclusionCondition().matches(node('a')), isFalse);
    final rules = ProxyExclusionRules.fromMap({
      'conditions': [
        <String, dynamic>{},
        7,
        {'protocol': 3},
      ],
    });
    expect(rules.excludes(node('a')), isFalse);
  });

  test(
    'serialization retains missing manual tags and collections are immutable',
    () {
      final tags = {'missing'};
      final rules = ProxyExclusionRules(
        excludedTags: tags,
        conditions: [ProxyExclusionCondition(country: 'RU')],
      );
      tags.clear();
      expect(rules.excludedTags, {'missing'});
      final restored = ProxyExclusionRules.fromMap(rules.toMap());
      expect(restored.excludedTags, {'missing'});
      expect(restored.excludes(node('ru', country: 'RU')), isTrue);
      expect(() => restored.excludedTags.add('a'), throwsUnsupportedError);
    },
  );

  test(
    'per-profile exclusions survive storage mapping without leaking profiles',
    () async {
      final store = MemoryAppSettingsStore();
      final initial = await store.loadState();
      expect(initial.proxyExclusionsByProfile, isEmpty);
      final state = initial.copyWith(
        proxyExclusionsByProfile: {
          'one': ProxyExclusionRules(excludedTags: {'stale'}),
          'two': ProxyExclusionRules(
            conditions: [ProxyExclusionCondition(country: 'RU')],
          ),
        },
      );
      await store.saveState(state);
      final restored = store.mapState(
        store.stateToMap(await store.loadState()),
      );
      expect(restored.proxyExclusionsByProfile['one']!.excludedTags, {'stale'});
      expect(restored.proxyExclusionsByProfile['two']!.excludedTags, isEmpty);
      expect(store.mapState({}).proxyExclusionsByProfile, isEmpty);
      expect(
        store.mapState({
          'proxy_exclusions_by_profile': 'bad json',
        }).proxyExclusionsByProfile,
        isEmpty,
      );
    },
  );
}
