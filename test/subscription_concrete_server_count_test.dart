import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/features/subscriptions/subscription_server_catalog.dart';
import 'package:meow_client/features/subscriptions/subscriptions_page.dart';
import 'package:meow_client/models/subscription.dart';

const _profile = Subscription(
  id: 'count-fixture',
  name: 'Profile',
  url: '',
  outbounds: [
    Outbound(
      tag: 'one',
      name: 'One',
      config: {'type': 'vless', '_group_only': true},
    ),
    Outbound(
      tag: 'two',
      name: 'Two',
      config: {'type': 'trojan', '_group_only': true},
    ),
    Outbound(
      tag: 'one',
      name: 'Duplicate',
      config: {'type': 'vless', '_group_only': true},
    ),
    Outbound(
      tag: 'fallback',
      name: 'Fallback',
      config: {'type': 'hysteria2', '_group_only': true},
    ),
    Outbound(tag: 'free', name: 'Free', config: {'type': 'socks'}),
    Outbound(
      tag: 'orphan',
      name: 'Orphan',
      config: {'type': 'socks', '_group_only': true},
    ),
    Outbound(
      tag: 'helper',
      name: 'Helper',
      config: {'type': 'socks', '_group_only': true},
    ),
    Outbound(
      tag: 'via-helper',
      name: 'Via helper',
      config: {'type': 'vless', 'detour': 'helper'},
    ),
    Outbound(
      tag: 'broken',
      name: 'Broken',
      config: {'type': 'vless', 'detour': 'missing'},
    ),
    Outbound(
      tag: 'via-deleted',
      name: 'Deleted detour',
      config: {'type': 'vless', 'detour': 'deleted'},
    ),
    Outbound(
      tag: 'deleted',
      name: 'Deleted',
      config: {'type': 'vless'},
      info: OutboundInfo(deleted: true),
    ),
    Outbound(tag: 'wg', name: 'WireGuard', config: {'type': 'wireguard'}),
    Outbound(tag: 'direct', name: 'Direct', config: {'type': 'direct'}),
    Outbound(tag: 'block', name: 'Block', config: {'type': 'block'}),
    Outbound(tag: 'dns', name: 'DNS', config: {'type': 'dns'}),
    Outbound(
      tag: 'lowest',
      name: 'Synthetic',
      config: {
        'type': 'urltest',
        'outbounds': ['one', 'two'],
      },
    ),
    Outbound(
      tag: 'nested',
      name: 'Nested',
      config: {
        'type': 'selector',
        '_group_only': true,
        'outbounds': ['one', 'two', 'root'],
      },
    ),
  ],
  groups: [
    SubscriptionGroup(
      tag: 'root',
      name: 'Root',
      outboundTags: ['one', 'two'],
      fallbackOutboundTags: ['fallback'],
      config: {
        'outbounds': ['nested', 'one'],
      },
    ),
    SubscriptionGroup(
      tag: 'shared',
      name: 'Shared',
      outboundTags: ['two', 'one'],
    ),
  ],
);

ProxyCacheBuildInput _input(
  Subscription profile, {
  String selectedProxyTag = '',
  Map<String, String> groupSelections = const {},
}) => ProxyCacheBuildInput(
  subscription: profile,
  selectedProxyTag: selectedProxyTag,
  lowestLatency: null,
  runtimeLowestOutboundTag: null,
  runtimeLowestSelections: const {},
  urlTestInFlight: false,
  runtimeLatencies: const {},
  unavailableLatencyTags: const {},
  latencyErrors: const {},
  runtimeGroupSelections: groupSelections,
  markAllServersRussia: false,
);

void main() {
  test('a fallback used by another group is not a member of its owner', () {
    const profile = Subscription(
      id: 'shared-fallback',
      name: 'Shared fallback',
      url: '',
      outbounds: [
        Outbound(tag: 'a', name: 'A', config: {'type': 'vless'}),
        Outbound(tag: 'b', name: 'B', config: {'type': 'vless'}),
      ],
      groups: [
        SubscriptionGroup(
          tag: 'auto-a',
          name: 'Auto A',
          outboundTags: ['a'],
          fallbackOutboundTags: ['b'],
        ),
        SubscriptionGroup(tag: 'auto-b', name: 'Auto B', outboundTags: ['b']),
      ],
    );
    final cache = buildProxyCache(_input(profile));
    expect(profile.concreteServerCount, 2);
    final a = cache.activeProxies.firstWhere((node) => node.tag == 'auto-a');
    final b = cache.activeProxies.firstWhere((node) => node.tag == 'auto-b');
    expect(a.childCount, 1);
    expect(b.childCount, 1);
    expect(cache.groupChildrenByTag['auto-a']?.map((node) => node.tag), ['a']);
  });

  test(
    'home cache resolves nested leaf country and counts concrete members',
    () {
      const profile = Subscription(
        id: 'home-nested',
        name: 'Home nested',
        url: '',
        outbounds: [
          Outbound(
            tag: 'a',
            name: 'Actual A',
            config: {'type': 'vless'},
            info: OutboundInfo(country: 'RU'),
          ),
          Outbound(tag: 'b', name: 'Actual B', config: {'type': 'vless'}),
        ],
        groups: [
          SubscriptionGroup(
            tag: 'root',
            name: 'Root',
            country: 'DE',
            outboundTags: ['nested'],
            config: {
              'outbounds': ['nested'],
            },
          ),
          SubscriptionGroup(
            tag: 'nested',
            name: 'Nested',
            outboundTags: ['a', 'b'],
            config: {
              'outbounds': ['a', 'b'],
            },
          ),
        ],
      );
      final cache = buildHomeProxyCache(
        _input(
          profile,
          selectedProxyTag: 'root',
          groupSelections: {'root': 'nested', 'nested': 'a'},
        ),
      );
      expect(cache.displayProxy?.childCount, 2);
      expect(cache.displayProxy?.selectedChildTag, 'a');
      expect(cache.displayProxy?.selectedChildName, 'Actual A');
      expect(cache.displayProxy?.countryCode, 'RU');
    },
  );

  test(
    'group-only detour clones are routes rather than additional servers',
    () {
      const profile = Subscription(
        id: 'clones',
        name: 'Clones',
        url: '',
        outbounds: [
          Outbound(tag: 'leaf', name: 'Leaf', config: {'type': 'vless'}),
          Outbound(
            tag: 'clone',
            name: 'Clone',
            config: {'type': 'vless', '_group_only': true, 'detour': 'leaf'},
          ),
        ],
        groups: [
          SubscriptionGroup(
            tag: 'auto',
            name: 'Auto',
            outboundTags: ['leaf', 'clone'],
          ),
        ],
      );
      expect(profile.concreteServerTags, {'leaf'});
      expect(
        buildProxyCache(
          _input(profile),
        ).groupChildrenByTag['auto']?.map((node) => node.tag),
        ['leaf'],
      );
    },
  );

  for (final flattened in [true, false]) {
    test(
      'parent-before-child groups retain immediate hierarchy (flattened=$flattened)',
      () {
        final profile = Subscription(
          id: 'hierarchy',
          name: 'Hierarchy',
          url: '',
          outbounds: const [
            Outbound(
              tag: 'leaf',
              name: 'Actual leaf',
              config: {'type': 'vless', '_group_only': true},
            ),
          ],
          groups: [
            SubscriptionGroup(
              tag: 'Root',
              name: 'Root',
              outboundTags: flattened ? const ['leaf'] : const ['Nested'],
              config: const {
                'outbounds': ['Nested'],
              },
            ),
            const SubscriptionGroup(
              tag: 'Nested',
              name: 'Nested',
              outboundTags: ['leaf'],
              config: {
                'outbounds': ['leaf'],
              },
            ),
          ],
        );
        final result = buildProxyCache(
          _input(
            profile,
            selectedProxyTag: 'Root',
            groupSelections: {'Root': 'Nested', 'Nested': 'leaf'},
          ),
        );
        expect(
          result.activeProxies
              .where((node) => !node.tag.startsWith('lowest'))
              .map((node) => node.tag),
          ['Root'],
        );
        expect(result.groupChildrenByTag['Root']?.map((node) => node.tag), [
          'Nested',
        ]);
        final nested = result.groupChildrenByTag['Root']!.single;
        expect(nested.isGroup, isTrue);
        expect(nested.membersSelectable, isTrue);
        expect(nested.childTags, ['leaf']);
        expect(nested.childCount, 1);
        expect(nested.selectedChildName, 'Actual leaf');
        expect(result.groupChildrenByTag['Nested']?.map((node) => node.tag), [
          'leaf',
        ]);
        expect(result.activeProfile?.outboundsCount, 1);
        expect(result.totalTopLevelProxyCount, 1);
      },
    );
  }

  test(
    'full group summary exposes its children for opening the group panel',
    () {
      const profile = Subscription(
        id: 'group-navigation',
        name: 'Group navigation',
        url: '',
        outbounds: [
          Outbound(tag: 'one', name: 'One', config: {'type': 'vless'}),
        ],
        groups: [
          SubscriptionGroup(tag: 'auto', name: 'Auto', outboundTags: ['one']),
        ],
      );
      final result = buildProxyCache(_input(profile));
      final group = result.activeProxies.firstWhere(
        (node) => node.tag == 'auto',
      );
      expect(group.membersSelectable, isTrue);
      expect(result.groupChildrenByTag['auto']?.map((node) => node.tag), [
        'one',
      ]);
    },
  );

  test('nested group selection keeps the resolved leaf name and country', () {
    const profile = Subscription(
      id: 'nested-selection',
      name: 'Nested selection',
      url: '',
      outbounds: [
        Outbound(
          tag: 'leaf',
          name: 'Actual leaf',
          config: {'type': 'vless', '_group_only': true},
          info: OutboundInfo(country: 'RU'),
        ),
      ],
      groups: [
        SubscriptionGroup(
          tag: 'root',
          name: 'Root',
          country: 'DE',
          outboundTags: ['leaf'],
          config: {
            'outbounds': ['inner'],
          },
        ),
        SubscriptionGroup(
          tag: 'inner',
          name: 'Inner',
          outboundTags: ['leaf'],
          config: {'_group_only': true},
        ),
      ],
    );
    final input = _input(
      profile,
      selectedProxyTag: 'root',
      groupSelections: {'root': 'inner', 'inner': 'leaf'},
    );
    final home = buildHomeProxyCache(input).displayProxy!;
    final full = buildProxyCache(
      input,
    ).activeProxies.firstWhere((node) => node.tag == 'root');
    for (final summary in [home, full]) {
      expect(summary.selectedChildTag, 'leaf');
      expect(summary.selectedChildName, 'Actual leaf');
      expect(summary.countryCode, 'RU');
    }
    expect(profile.concreteServerTags, {'leaf'});
  });

  test('broken detours are pruned transitively without counting helpers', () {
    const profile = Subscription(
      id: 'broken-chain',
      name: 'Broken chain',
      url: '',
      outbounds: [
        Outbound(
          tag: 'leaf',
          name: 'Leaf',
          config: {'type': 'vless', 'detour': 'helper'},
        ),
        Outbound(
          tag: 'helper',
          name: 'Helper',
          config: {'type': 'socks', '_group_only': true, 'detour': 'missing'},
        ),
      ],
    );
    expect(profile.concreteServerTags, isEmpty);
    expect(SubscriptionServerCatalog(profile).visibleProxyCount, 0);
  });

  for (final country in <String?>[null, 'RU']) {
    test(
      'selected leaf country overrides provider group country ($country)',
      () {
        final profile = Subscription(
          id: 'country',
          name: 'Country',
          url: '',
          outbounds: [
            Outbound(
              tag: 'one',
              name: 'Actual leaf',
              config: const {'type': 'vless'},
              info: OutboundInfo(country: country),
            ),
          ],
          groups: const [
            SubscriptionGroup(
              tag: 'auto',
              name: 'Auto',
              country: 'DE',
              outboundTags: ['one'],
            ),
          ],
        );
        final input = _input(
          profile,
          selectedProxyTag: 'auto',
          groupSelections: {'auto': 'one'},
        );
        expect(
          buildHomeProxyCache(input).displayProxy?.countryCode,
          country ?? '',
        );
        expect(
          buildProxyCache(
            input,
          ).activeProxies.firstWhere((node) => node.tag == 'auto').countryCode,
          country ?? '',
        );
      },
    );
  }

  test(
    'group summaries expose the selected leaf name on home and full lists',
    () {
      const profile = Subscription(
        id: 'grouped',
        name: 'Grouped',
        url: '',
        outbounds: [
          Outbound(
            tag: 'one',
            name: 'Amsterdam real server',
            config: {'type': 'vless'},
          ),
        ],
        groups: [
          SubscriptionGroup(tag: 'auto', name: 'Auto', outboundTags: ['one']),
        ],
      );
      final input = _input(
        profile,
        selectedProxyTag: 'auto',
        groupSelections: {'auto': 'one'},
      );
      expect(
        buildHomeProxyCache(input).displayProxy?.selectedChildName,
        'Amsterdam real server',
      );
      expect(
        buildProxyCache(input).activeProxies
            .firstWhere((node) => node.tag == 'auto')
            .selectedChildName,
        'Amsterdam real server',
      );
    },
  );

  test(
    'fallback helpers do not become servers when the primary group is empty',
    () {
      const profile = Subscription(
        id: 'empty-primary',
        name: 'Empty primary',
        url: '',
        outbounds: [
          Outbound(
            tag: 'fallback',
            name: 'Fallback',
            config: {'type': 'vless', '_group_only': true},
          ),
        ],
        groups: [
          SubscriptionGroup(
            tag: 'auto',
            name: 'Auto',
            outboundTags: ['missing'],
            fallbackOutboundTags: ['fallback'],
          ),
        ],
      );
      expect(profile.concreteServerCount, 0);
      expect(SubscriptionServerCatalog(profile).visibleProxyCount, 0);
    },
  );

  test(
    'compact presentation preserves concrete count and public unique tags',
    () {
      final compact = compactSubscriptionForProxyCache(_profile);
      expect(compact.concreteServerTags, {'one', 'two', 'free', 'via-helper'});
      expect(
        buildHomeProxyCache(_input(compact)).activeProfile?.outboundsCount,
        4,
      );
    },
  );

  test(
    'metadata counts unique real leaves across nested and shared groups',
    () {
      expect(_profile.toMetadataMap()['visible_proxy_count'], 4);
    },
  );

  test(
    'home summary counts real servers without changing row geometry count',
    () {
      final profile = Subscription(
        id: 'grouped',
        name: 'Grouped',
        url: '',
        outbounds: const [
          Outbound(tag: 'one', name: 'One', config: {'type': 'vless'}),
          Outbound(tag: 'two', name: 'Two', config: {'type': 'trojan'}),
        ],
        groups: const [
          SubscriptionGroup(
            tag: 'auto',
            name: 'Auto',
            outboundTags: ['one', 'two'],
          ),
        ],
      );
      final result = buildHomeProxyCache(_input(profile));
      expect(result.activeProfile?.outboundsCount, 2);
      expect(result.totalTopLevelProxyCount, 1);
    },
  );

  test(
    'catalog and metadata count the same leaves after dependency filtering',
    () {
      final catalog = SubscriptionServerCatalog(_profile);
      expect(catalog.visibleProxyCount, 4);
      expect(_profile.toMetadataMap()['visible_proxy_count'], 4);
      expect(
        catalog.members('root').map((node) => node.tag),
        isNot(contains('fallback')),
      );
    },
  );

  test('legacy positive summaries must be recalculated once', () {
    final legacy = Subscription.fromMetadataMap({
      'id': 'legacy',
      'name': 'Legacy',
      'visible_proxy_count': 77,
      'has_raw_payload': true,
      'payload_revision': 'unchanged',
    });
    expect(legacy.cachedVisibleProxyCount, -1);
    expect(subscriptionCountNeedsHydration(legacy), isTrue);
    expect(legacy.payloadRevision, 'unchanged');
  });

  test('fresh zero summary is trusted without rehydrating raw content', () {
    const profile = Subscription(
      id: 'empty',
      name: 'Empty',
      url: '',
      cachedVisibleProxyCount: 0,
      hasRawPayload: true,
    );
    final saved = profile.toMetadataMap();
    expect(saved['visible_proxy_count_policy'], 1);
    final restored = Subscription.fromMetadataMap(saved);
    expect(restored.cachedVisibleProxyCount, 0);
    expect(subscriptionCountNeedsHydration(restored), isFalse);
  });

  test(
    'refreshing a legacy summary preserves payload revision and trusts count',
    () {
      final legacy = Subscription.fromMetadataMap({
        'id': 'legacy',
        'name': 'Legacy',
        'visible_proxy_count': 77,
        'has_raw_payload': true,
        'payload_revision': 'revision-1',
      });
      final refreshed = legacy
          .copyWith(cachedVisibleProxyCount: 5)
          .toMetadataMap();
      final restored = Subscription.fromMetadataMap(refreshed);
      expect(restored.cachedVisibleProxyCount, 5);
      expect(restored.payloadRevision, 'revision-1');
      expect(subscriptionCountNeedsHydration(restored), isFalse);
    },
  );
}
