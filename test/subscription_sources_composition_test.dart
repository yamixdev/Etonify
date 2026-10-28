import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/subscription/subscription_sources.dart';
import 'package:meow_client/models/subscription.dart';

SubscriptionSource _source(String id, {bool nested = false}) =>
    SubscriptionSource(
      id: id,
      snapshot: Subscription(
        id: id,
        name: id,
        url: 'https://example.com/$id',
        groups: [
          SubscriptionGroup(
            tag: 'group',
            name: 'Group',
            type: 'selector',
            outboundTags: [nested ? 'nested' : 'leaf'],
            config: {
              'outbounds': [nested ? 'nested' : 'leaf'],
              '_direct_outbounds': {
                'leaf': {
                  'tag': 'leaf',
                  'type': 'vless',
                  'server': '$id.example.com',
                  'server_port': 443,
                  if (nested) 'detour': 'hop',
                },
                if (nested) ...{
                  'hop': {
                    'tag': 'hop',
                    'type': 'socks',
                    'server': 'hop.example.com',
                    'server_port': 1080,
                  },
                  'nested': {
                    'tag': 'nested',
                    'type': 'selector',
                    'outbounds': ['leaf'],
                    'default': 'leaf',
                    '_group_tags': ['group'],
                    '_direct_outbounds': {
                      'deep': {
                        'tag': 'deep',
                        'type': 'vless',
                        'server': 'deep.example.com',
                        'server_port': 443,
                        'detour': 'hop',
                      },
                    },
                  },
                },
              },
            },
          ),
        ],
      ),
    );

void main() {
  test('same-name embedded dependencies remain distinct across sources', () {
    final result = composeSubscriptionSources([
      _source('primary'),
      _source('other'),
    ]);
    final primary = result.groups[0].config['_direct_outbounds'] as Map;
    final other = result.groups[1].config['_direct_outbounds'] as Map;
    expect(primary.keys, ['leaf']);
    expect(other.keys, ['source:other:leaf']);
    expect(other['source:other:leaf']['tag'], 'source:other:leaf');
    expect(result.groups[1].outboundTags, ['source:other:leaf']);
    expect(concreteSubscriptionServerTags(result.outbounds, result.groups), {
      'leaf',
      'source:other:leaf',
    });
  });

  test(
    'nested embedded groups and detours resolve within their own source',
    () {
      final result = composeSubscriptionSources([
        _source('primary', nested: true),
        _source('other', nested: true),
      ]);
      final direct = result.groups[1].config['_direct_outbounds'] as Map;
      expect(direct.keys, [
        'source:other:leaf',
        'source:other:hop',
        'source:other:nested',
      ]);
      expect(direct['source:other:leaf']['detour'], 'source:other:hop');
      final nested = direct['source:other:nested'] as Map;
      expect(nested['tag'], 'source:other:nested');
      expect(nested['outbounds'], ['source:other:leaf']);
      expect(nested['default'], 'source:other:leaf');
      expect(nested['_group_tags'], ['source:other:group']);
      expect(nested['_direct_outbounds'], {
        'source:other:deep': {
          'tag': 'source:other:deep',
          'type': 'vless',
          'server': 'deep.example.com',
          'server_port': 443,
          'detour': 'source:other:hop',
        },
      });
      expect(
        (result.groups.first.config['_direct_outbounds']
            as Map)['leaf']['detour'],
        'hop',
      );
    },
  );
}
