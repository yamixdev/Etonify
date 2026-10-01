import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/subscriptions/subscription_server_catalog.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test('explicit ownership nests shared candidates without name guessing', () {
    final catalog = SubscriptionServerCatalog(
      const Subscription(
        id: 'test',
        name: 'Test',
        url: '',
        outbounds: [
          Outbound(tag: 'one', name: 'cand-01', config: {'type': 'vless'}),
          Outbound(tag: 'two', name: 'cand-02', config: {'type': 'vless'}),
          Outbound(tag: 'free', name: 'cand-03', config: {'type': 'vless'}),
        ],
        groups: [
          SubscriptionGroup(
            tag: 'nl',
            name: 'LTE Auto Netherlands',
            outboundTags: ['one', 'two', 'one'],
          ),
          SubscriptionGroup(
            tag: 'de',
            name: 'LTE Auto Germany',
            outboundTags: ['two'],
          ),
        ],
      ),
    );
    expect(catalog.roots.map((node) => node.tag), ['nl', 'de', 'free']);
    expect(catalog.members('nl').map((node) => node.tag), ['one', 'two']);
    expect(catalog.memberCount('nl'), 2);
    expect(catalog.searchText(catalog.node('nl')!), contains('cand-02'));
  });

  test('nested native groups and cycles are bounded and counted once', () {
    final catalog = SubscriptionServerCatalog(
      const Subscription(
        id: 'test',
        name: 'Test',
        url: '',
        outbounds: [
          Outbound(
            tag: 'a',
            name: 'A',
            config: {
              'type': 'urltest',
              'outbounds': ['b', 'leaf'],
            },
          ),
          Outbound(
            tag: 'b',
            name: 'B',
            config: {
              'type': 'selector',
              'outbounds': ['a', 'leaf'],
            },
          ),
          Outbound(tag: 'leaf', name: 'Leaf', config: {'type': 'vless'}),
        ],
      ),
    );
    expect(catalog.roots.map((node) => node.tag), ['a']);
    expect(catalog.memberCount('a'), 1);
    expect((catalog.exportGroup('a')['outbounds'] as List).length, 3);
  });

  test(
    'group export uses current URLTest schema and includes detour dependencies',
    () {
      final catalog = SubscriptionServerCatalog(
        const Subscription(
          id: 'test',
          name: 'Test',
          url: '',
          outbounds: [
            Outbound(
              tag: 'leaf',
              name: 'Leaf',
              config: {'type': 'vless', 'detour': 'hop', '_private': true},
            ),
            Outbound(
              tag: 'hop',
              name: 'Hop',
              config: {'type': 'socks', '_group_only': true},
            ),
          ],
          groups: [
            SubscriptionGroup(
              tag: 'auto',
              name: 'Auto',
              outboundTags: ['leaf'],
              urlTestConfig: UrlTestConfig(
                url: 'https://example.com/test',
                intervalSeconds: 30,
                timeoutSeconds: 5,
                concurrency: 2,
                method: 'lowest',
                unavailableCheckIntervalSeconds: 120,
              ),
            ),
          ],
        ),
      );
      final configs = (catalog.exportGroup('auto')['outbounds'] as List)
          .cast<Map<String, dynamic>>();
      expect(configs.map((config) => config['tag']), ['auto', 'leaf', 'hop']);
      expect(configs.first, {
        'type': 'urltest',
        'tag': 'auto',
        'outbounds': ['leaf'],
        'url': 'https://example.com/test',
        'interval': '30s',
      });
      expect(configs[1].containsKey('_private'), isFalse);
      expect(configs[2].containsKey('_group_only'), isFalse);
    },
  );

  for (final hop in <Outbound?>[
    null,
    const Outbound(
      tag: 'hop',
      name: 'Hop',
      config: {'type': 'socks'},
      info: OutboundInfo(deleted: true),
    ),
    const Outbound(tag: 'hop', name: 'Hop', config: {'type': 'wireguard'}),
  ]) {
    test(
      'sharing rejects an unavailable detour (${hop?.type ?? 'missing'})',
      () {
        final catalog = SubscriptionServerCatalog(
          Subscription(
            id: 'test',
            name: 'Test',
            url: '',
            outbounds: [
              const Outbound(
                tag: 'leaf',
                name: 'Leaf',
                config: {'type': 'vless', 'detour': 'hop'},
              ),
              ?hop,
            ],
            groups: const [
              SubscriptionGroup(
                tag: 'auto',
                name: 'Auto',
                outboundTags: ['leaf'],
              ),
            ],
          ),
        );
        expect(() => catalog.exportGroup('auto'), throwsA(isA<Exception>()));
      },
    );
  }

  test('sharing rejects an empty nested group after filtering', () {
    final catalog = SubscriptionServerCatalog(
      const Subscription(
        id: 'test',
        name: 'Test',
        url: '',
        outbounds: [
          Outbound(
            tag: 'empty',
            name: 'Empty',
            config: {
              'type': 'urltest',
              'outbounds': ['missing'],
            },
          ),
        ],
        groups: [
          SubscriptionGroup(tag: 'auto', name: 'Auto', outboundTags: ['empty']),
        ],
      ),
    );
    expect(() => catalog.exportGroup('auto'), throwsA(isA<Exception>()));
  });

  test('deleted and unsupported members are not offered by group sharing', () {
    final catalog = SubscriptionServerCatalog(
      const Subscription(
        id: 'test',
        name: 'Test',
        url: '',
        outbounds: [
          Outbound(tag: 'live', name: 'Live', config: {'type': 'vless'}),
          Outbound(
            tag: 'deleted',
            name: 'Deleted',
            config: {'type': 'vless'},
            info: OutboundInfo(deleted: true),
          ),
          Outbound(
            tag: 'unsupported',
            name: 'Unsupported',
            config: {'type': 'wireguard'},
          ),
        ],
        groups: [
          SubscriptionGroup(
            tag: 'auto',
            name: 'Auto',
            outboundTags: ['live', 'deleted', 'unsupported', 'missing'],
          ),
        ],
      ),
    );
    expect(catalog.members('auto').map((node) => node.tag), ['live']);
    final configs = (catalog.exportGroup('auto')['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    expect(configs.first['outbounds'], ['live']);
  });
}
