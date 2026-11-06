import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/models/proxy_exclusion_rules.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/subscription/subscription_sources.dart';

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
  test('adding another source does not change existing primary identity', () {
    final source = Subscription(
      id: 'profile',
      name: 'P',
      url: 'https://primary.test',
      outbounds: [node('a')],
    );
    final rules = ProxyExclusionRules(
      excludedTags: {'a'},
    ).bindLegacyTags(source);
    final primary = SubscriptionSource(id: 'primary', snapshot: source);
    final secondary = SubscriptionSource(
      id: 'second',
      snapshot: source.copyWith(url: 'https://second.test'),
    );
    final merged = composeSubscriptionSources([primary, secondary]);
    expect(
      rules.excludedTagsFor(
        source.copyWith(
          sources: [primary, secondary],
          outbounds: merged.outbounds,
          groups: merged.groups,
        ),
      ),
      {'a'},
    );
  });

  test('prepared projections scan the concrete graph only once', () {
    final source = _CountingSubscription();
    final result = ProxyExclusionRules(
      conditions: [ProxyExclusionCondition(protocol: 'vless')],
    ).prepare(source);
    expect(result.excludedTags, {'a'});
    expect(
      result.runtimeSubscription.outbounds.single.config['_excluded_by_user'],
      isTrue,
    );
    expect(
      result.eligibleSubscription.outbounds.single.config['_group_only'],
      isTrue,
    );
    expect(source.concreteScans, 1);
  });

  test(
    'stable exclusions distinguish composed sources and canonicalize metadata',
    () {
      final endpoint = node('a');
      Subscription profile(List<SubscriptionSource> sources) {
        final merged = composeSubscriptionSources(sources);
        return Subscription(
          id: 'profile',
          name: 'Profile',
          url: '',
          sources: sources,
          outbounds: merged.outbounds,
          groups: merged.groups,
        );
      }

      final primary = SubscriptionSource(
        id: 'primary',
        snapshot: Subscription(
          id: 'p',
          name: 'P',
          url: 'https://primary.test/private-token',
          outbounds: [endpoint],
        ),
      );
      final second = SubscriptionSource(
        id: 'second',
        snapshot: Subscription(
          id: 's',
          name: 'S',
          url: 'https://second.test/private-token',
          outbounds: [endpoint],
        ),
      );
      final original = profile([primary, second]);
      final rules = ProxyExclusionRules(
        excludedTags: {'source:second:a'},
      ).bindLegacyTags(original);
      expect(rules.excludedTagsFor(original), {'source:second:a'});
      final renamed = second.copyWith(
        snapshot: second.snapshot.copyWith(
          outbounds: [
            endpoint.copyWith(
              tag: 'new',
              name: 'New',
              config: {
                '_source_order': 999,
                '_name': 'New',
                'tag': 'new',
                for (final entry in endpoint.config.entries.toList().reversed)
                  entry.key: entry.value,
              },
            ),
          ],
        ),
      );
      expect(rules.excludedTagsFor(profile([primary, renamed])), {
        'source:second:new',
      });
      expect(
        rules.excludedTagsFor(
          profile([
            primary,
            second.copyWith(
              snapshot: second.snapshot.copyWith(
                url: 'https://replacement.test',
              ),
            ),
          ]),
        ),
        isEmpty,
      );
      expect(rules.toMap().toString(), isNot(contains('private-token')));
    },
  );

  test('legacy binding follows endpoint across duplicate-name tag reorder', () {
    final a = node(
      'same',
    ).copyWith(config: {...node('same').config, 'server': 'a.test'});
    final b = node(
      'same-2',
    ).copyWith(config: {...node('same-2').config, 'server': 'b.test'});
    final source = Subscription(
      id: 'one',
      name: 'One',
      url: 'https://one.test',
      outbounds: [a, b],
    );
    final rules = ProxyExclusionRules(
      excludedTags: {'same'},
    ).bindLegacyTags(source);
    final reordered = source.copyWith(
      outbounds: [
        b.copyWith(tag: 'same'),
        a.copyWith(tag: 'same-2', name: 'Renamed'),
      ],
    );
    expect(rules.excludedTagsFor(reordered), {'same-2'});
    expect(
      rules.excludedTagsFor(
        source.copyWith(outbounds: [b.copyWith(tag: 'same')]),
      ),
      isEmpty,
    );
    expect(
      rules.excludedTagsFor(source.copyWith(url: 'https://other.test')),
      isEmpty,
    );
    expect(rules.excludedTagsFor(source.copyWith(id: 'two')), isEmpty);
    final restored = ProxyExclusionRules.fromMap(rules.toMap());
    expect(restored.bindLegacyTags(reordered).excludedTagsFor(reordered), {
      'same-2',
    });
    expect(restored.toMap().toString(), isNot(contains('a.test')));
    expect(restored.toMap().toString(), isNot(contains('00000000-0000')));
  });

  test('missing legacy tag is retired once rather than rebound on refresh', () {
    final source = Subscription(
      id: 'one',
      name: 'One',
      url: '',
      outbounds: [node('other')],
    );
    final rules = ProxyExclusionRules(
      excludedTags: {'missing'},
    ).bindLegacyTags(source);
    final updated = source.copyWith(outbounds: [node('missing')]);
    expect(rules.bindLegacyTags(updated).excludedTagsFor(updated), isEmpty);
    expect(
      ProxyExclusionRules.fromMap(rules.toMap()).excludedTagsFor(updated),
      isEmpty,
    );
  });

  test(
    'prepared projection evaluates embedded stable exclusions consistently',
    () {
      const source = Subscription(
        id: 'one',
        name: 'One',
        url: '',
        groups: [
          SubscriptionGroup(
            tag: 'group',
            name: 'Group',
            outboundTags: ['embedded'],
            config: {
              'outbounds': ['embedded'],
              '_direct_outbounds': {
                'embedded': {
                  'type': 'trojan',
                  'server': 'a.test',
                  'password': 'secret',
                },
              },
            },
          ),
        ],
      );
      final rules = ProxyExclusionRules(
        excludedTags: {'embedded'},
      ).bindLegacyTags(source);
      final projection = rules.prepare(source);
      expect(projection.excludedTags, {'embedded'});
      expect(projection.runtimeSubscription.groups.single.outboundTags, [
        'embedded',
      ]);
      expect(
        (projection
                .runtimeSubscription
                .groups
                .single
                .config['_direct_outbounds']
            as Map)['embedded']['_excluded_by_user'],
        isTrue,
      );
      expect(
        projection.eligibleSubscription.groups.single.outboundTags,
        isEmpty,
      );
      expect(
        projection.eligibleSubscription.outbounds.single.config['_group_only'],
        isTrue,
      );
      expect(source.groups.single.outboundTags, ['embedded']);
    },
  );

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

  test('country alternatives roundtrip and still require other fields', () {
    final old = ProxyExclusionCondition.fromMap({'country': 'de'});
    expect(old.matches(node('de', country: 'DE')), isTrue);
    expect(old.matches(node('fi', country: 'FI')), isFalse);
    final rule = ProxyExclusionCondition.fromMap({
      'protocol': 'vless',
      'countries': [' fi ', 'DE', 'de'],
    });
    final restored = ProxyExclusionCondition.fromMap(rule.toMap());
    expect(restored.toMap()['countries'], ['DE', 'FI']);
    expect(restored.matches(node('de', country: 'DE')), isTrue);
    expect(restored.matches(node('fi', country: 'FI')), isTrue);
    expect(restored.matches(node('ru', country: 'RU')), isFalse);
    expect(restored.matches(node('unknown')), isFalse);
    expect(
      restored.matches(node('other', country: 'FI', type: 'trojan')),
      isFalse,
    );
  });

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

class _CountingSubscription extends Subscription {
  _CountingSubscription()
    : super(id: 'one', name: 'One', url: '', outbounds: [node('a')]);
  int concreteScans = 0;
  @override
  Set<String> get concreteServerTags {
    concreteScans++;
    return super.concreteServerTags;
  }
}
