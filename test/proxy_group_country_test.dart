import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/core/proxy_group_country.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test('empty cycles do not produce an invented country', () {
    final countries = buildProxyGroupCountryCatalog(const [], [
      _group('a', ['b']),
      _group('b', ['a']),
    ]);
    expect(countries, {'a': '', 'b': ''});
  });

  test('unresolved member prevents unanimous fallback', () {
    final countries = buildProxyGroupCountryCatalog(
      [_node('a', 'SE')],
      [
        _group('auto', ['a', 'missing']),
      ],
    );
    expect(countries['auto'], '');
  });

  test('nested group label cannot conceal concrete mixed countries', () {
    final countries = buildProxyGroupCountryCatalog(
      [_node('a', 'SE'), _node('b', 'DE')],
      [
        _group('auto', ['nested']),
        _group('nested', ['a', 'b'], country: 'SE'),
      ],
    );
    expect(countries, {'auto': '', 'nested': 'SE'});
  });

  test('raw selector references resolve to concrete leaves', () {
    final countries = buildProxyGroupCountryCatalog(
      [
        _node('a', 'SE'),
        _node('b', 'SE'),
        const Outbound(
          tag: 'selector',
          name: 'Selector',
          config: {
            'type': 'selector',
            'outbounds': ['a', 'b'],
          },
        ),
      ],
      [
        _group('auto', ['selector']),
      ],
    );
    expect(countries['auto'], 'SE');
  });

  test('non-server direct references are not a known-country member', () {
    final countries = buildProxyGroupCountryCatalog(
      [
        _node('a', 'SE'),
        const Outbound(
          tag: 'direct',
          name: 'Direct',
          config: {'type': 'direct'},
        ),
      ],
      [
        _group('auto', ['a', 'direct']),
      ],
    );
    expect(countries['auto'], '');
  });

  test('invalid selected country does not erase normalized fallback', () {
    expect(
      groupDisplayCountryCode(
        fallbackCountryCode: ' se ',
        selectedCountryCode: 'unknown',
        markAllServersRussia: false,
      ),
      'SE',
    );
  });

  for (final homeOnly in [false, true]) {
    group(homeOnly ? 'home group country' : 'full group country', () {
      test('shows unanimous declared member country before selection', () {
        final result = _build(homeOnly, [_node('a', 'SE'), _node('b', 'SE')]);
        expect(result.displayProxy!.countryCode, 'SE');
        expect(result.displayProxy!.selectedChildTag, isNull);
        expect(result.groupCountryCodes['auto'], 'SE');
        expect(
          result.withWorkerElapsed(Duration.zero).groupCountryCodes['auto'],
          'SE',
        );
      });

      for (final name in [
        'LTE Авто - Швеция',
        'LTE Авто - Швеция #2',
        'Auto | Sweden',
        '🇸🇪 LTE Авто',
      ]) {
        test('uses the declared group label $name before selection', () {
          final result = _build(
            homeOnly,
            [_node('a', null), _node('b', 'DE')],
            groups: [
              _group('auto', ['a', 'b']).copyWith(name: name),
            ],
          );
          expect(result.displayProxy!.countryCode, 'SE');
        });
      }

      for (final name in [
        'Auto - sweden.example.com',
        'Auto - NotSweden',
        'Auto - Швецияне',
        'Sweden.example.com',
        'Auto - Sweden | Germany',
      ]) {
        test('does not guess a declaration from $name', () {
          final result = _build(
            homeOnly,
            [_node('a', null), _node('b', 'DE')],
            groups: [
              _group('auto', ['a', 'b']).copyWith(name: name),
            ],
          );
          expect(result.displayProxy!.countryCode, '');
        });
      }

      test('explicit country metadata takes precedence over group label', () {
        final result = _build(
          homeOnly,
          [_node('a', null), _node('b', 'DE')],
          groups: [
            _group('auto', [
              'a',
              'b',
            ], country: 'FI').copyWith(name: 'Auto - Sweden'),
          ],
        );
        expect(result.displayProxy!.countryCode, 'FI');
      });

      test('resolves nested groups to all distinct concrete members', () {
        final result = _build(
          homeOnly,
          [_node('a', 'SE'), _node('b', 'SE')],
          groups: [
            _group('auto', ['nested', 'a']),
            _group('nested', ['a', 'b']),
          ],
        );
        expect(result.displayProxy!.countryCode, 'SE');
      });

      test('does not guess from the first member of a mixed group', () {
        final result = _build(homeOnly, [_node('a', 'SE'), _node('b', 'DE')]);
        expect(result.displayProxy!.countryCode, '');
      });

      test('does not ignore a member with unknown country', () {
        final result = _build(homeOnly, [_node('a', 'SE'), _node('b', null)]);
        expect(result.displayProxy!.countryCode, '');
      });

      test('empty runtime leaf country preserves declared group country', () {
        final result = _build(
          homeOnly,
          [_node('a', null), _node('b', 'DE')],
          groups: [
            _group('auto', ['a', 'b'], country: ' se '),
          ],
          selections: {'auto': 'a'},
        );
        expect(result.displayProxy!.countryCode, 'SE');
        expect(result.displayProxy!.selectedChildTag, 'a');
      });

      test('known runtime leaf country overrides reliable group fallback', () {
        final result = _build(
          homeOnly,
          [_node('a', 'DE'), _node('b', 'DE')],
          groups: [
            _group('auto', ['a', 'b'], country: 'SE'),
          ],
          selections: {'auto': 'a'},
        );
        expect(result.displayProxy!.countryCode, 'DE');
      });

      test('uses observed exit country only for undeclared members', () {
        final result = _build(homeOnly, [
          _node('a', null, exitCountry: 'SE'),
          _node('b', 'SE', exitCountry: 'DE'),
        ]);
        expect(result.displayProxy!.countryCode, 'SE');
      });

      test('cyclic membership remains safe and includes reachable leaves', () {
        final result = _build(
          homeOnly,
          [_node('a', 'SE'), _node('b', 'SE')],
          groups: [
            _group('auto', ['a', 'nested']),
            _group('nested', ['b', 'auto']),
          ],
        );
        expect(result.displayProxy!.countryCode, 'SE');
      });

      test('global Russia override covers unknown and runtime countries', () {
        final result = _build(
          homeOnly,
          [_node('a', null), _node('b', 'DE')],
          selections: {'auto': 'b'},
          markAllServersRussia: true,
        );
        expect(result.displayProxy!.countryCode, 'RU');
      });
    });
  }
}

Outbound _node(String tag, String? country, {String? exitCountry}) => Outbound(
  tag: tag,
  name: tag,
  config: const {
    'type': 'vless',
    'server': 'proxy.example.com',
    'server_port': 443,
    'uuid': '00000000-0000-0000-0000-000000000001',
  },
  info: OutboundInfo(country: country, exitCountry: exitCountry),
);

SubscriptionGroup _group(String tag, List<String> members, {String? country}) =>
    SubscriptionGroup(
      tag: tag,
      name: 'Auto',
      country: country,
      outboundTags: members,
      config: {'outbounds': members},
    );

ProxyCacheBuildResult _build(
  bool homeOnly,
  List<Outbound> nodes, {
  List<SubscriptionGroup>? groups,
  Map<String, String> selections = const {},
  bool markAllServersRussia = false,
}) {
  final input = ProxyCacheBuildInput(
    subscription: Subscription(
      id: 'group-country',
      name: 'Group country',
      url: 'file:///group-country',
      outbounds: nodes,
      groups:
          groups ?? [_group('auto', nodes.map((node) => node.tag).toList())],
    ),
    selectedProxyTag: 'auto',
    lowestLatency: null,
    runtimeLowestOutboundTag: null,
    runtimeLowestSelections: const {},
    urlTestInFlight: false,
    runtimeLatencies: const {},
    unavailableLatencyTags: const {},
    latencyErrors: const {},
    runtimeGroupSelections: selections,
    markAllServersRussia: markAllServersRussia,
  );
  return homeOnly ? buildHomeProxyCache(input) : buildProxyCache(input);
}
