import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/routing/traffic_route_inspector.dart';

void main() {
  test(
    'reports the first traffic rule and the independent DNS resolver',
    () async {
      final result = await TrafficRouteInspector.inspect(
        target: 'A.Example.Com.',
        config: {
          'route': {
            'rules': [
              {'action': 'sniff'},
              {'domain_suffix': 'example.com', 'outbound': 'direct'},
              {'domain': 'a.example.com', 'outbound': 'select'},
            ],
            'final': 'select',
          },
          'dns': {
            'rules': [
              {'domain_keyword': 'example', 'server': 'dns-remote'},
            ],
            'servers': [
              {
                'tag': 'dns-remote',
                'type': 'https',
                'server': '1.1.1.1',
                'detour': 'select',
              },
            ],
            'final': 'dns-direct',
          },
        },
      );

      expect(result.target, 'a.example.com');
      expect(result.route.tag, 'direct');
      expect(result.route.ruleIndex, 1);
      expect(result.dns?.tag, 'dns-remote');
      expect(result.dns?.resolver, '1.1.1.1');
      expect(result.dns?.detour, 'select');
    },
  );

  test('a missing earlier rule set makes the route uncertain', () async {
    final result = await TrafficRouteInspector.inspect(
      target: 'example.com',
      config: {
        'route': {
          'rules': [
            {'rule_set': 'missing', 'outbound': 'select'},
            {'domain': 'example.com', 'outbound': 'direct'},
          ],
          'final': 'direct',
        },
        'dns': {
          'servers': [
            {'type': 'local', 'tag': 'dns-direct'},
          ],
          'final': 'dns-direct',
        },
      },
    );

    expect(result.route.isUnknown, isTrue);
    expect(result.route.ruleIndex, 0);
    expect(result.route.tag, isNull);
    expect(result.dns?.tag, 'dns-direct');
  });

  test('matches the binary GeoIP set bundled with the app', () async {
    final result = await TrafficRouteInspector.inspect(
      target: '77.88.8.8',
      config: {
        'route': {
          'rule_set': [
            {
              'type': 'local',
              'tag': 'ru',
              'path': File(
                'assets/route_data/russia/geoip-ru.srs',
              ).absolute.path,
            },
          ],
          'rules': [
            {'rule_set': 'ru', 'outbound': 'direct'},
          ],
          'final': 'select',
        },
      },
    );

    expect(result.route.tag, 'direct');
    expect(result.route.ruleIndex, 0);
    expect(result.dns, isNull);
  });

  test('matches legacy binary domain suffixes on a label boundary', () async {
    final config = <String, dynamic>{
      'route': {
        'rule_set': [
          {
            'type': 'local',
            'tag': 'ru',
            'path': File(
              'assets/route_data/russia/geosite-category-ru.srs',
            ).absolute.path,
          },
        ],
        'rules': [
          {'rule_set': 'ru', 'outbound': 'direct'},
        ],
        'final': 'select',
      },
    };
    final match = await TrafficRouteInspector.inspect(
      target: 'sample-etonify-testing.ru',
      config: config,
    );
    final miss = await TrafficRouteInspector.inspect(
      target: 'sample-etonify-testing.ru.example',
      config: config,
    );

    expect(match.route.tag, 'direct');
    expect(miss.route.tag, 'select');
  });
}
