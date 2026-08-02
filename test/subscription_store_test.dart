import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_parser.dart';
import 'package:meow_client/data/subscription/subscription_failure.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  late Directory tempDir;
  HttpOverrides? previousHttpOverrides;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _PassthroughHttpOverrides();
    tempDir = await Directory.systemTemp.createTemp('meow-client-hive-');
    Hive.init(tempDir.path);
    await SubscriptionStore.init();
  });

  setUp(() async {
    await SubscriptionStore.clear();
  });

  tearDownAll(() async {
    await SubscriptionStore.clear();
    await Hive.close();
    HttpOverrides.global = previousHttpOverrides;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'addFromUrl saves placeholder subscription when initial fetch fails',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
      });

      final result = await SubscriptionStore.addFromUrl(
        'http://${server.address.host}:${server.port}/sub',
        customName: 'Saved Anyway',
        requestInfo: const SubscriptionInfo(
          requireHwid: true,
          customHwid: 'spoofed-hwid',
        ),
      );

      expect(result.hasWarning, isTrue);
      expect(result.subscription.name, 'Saved Anyway');
      expect(result.subscription.outbounds, isEmpty);

      final saved = SubscriptionStore.get(result.subscription.id);
      expect(saved, isNotNull);
      expect(saved!.url, 'http://${server.address.host}:${server.port}/sub');
      expect(saved.info?.requireHwid, isTrue);
      expect(saved.info?.customHwid, 'spoofed-hwid');
      expect(saved.outbounds, isEmpty);
    },
  );

  test('addFromContent imports a subscription from file content', () async {
    final result = await SubscriptionStore.addFromContent(
      'vless://uuid@server.com:443?type=tcp&security=tls#Node1',
      sourceName: 'nodes.txt',
    );

    expect(result.hasWarning, isFalse);
    expect(
      SubscriptionStore.isLocalFileImportUrl(result.subscription.url),
      isTrue,
    );
    expect(result.subscription.disableAutoUpdate, isTrue);
    expect(result.subscription.outbounds, isNotEmpty);

    final metadata = SubscriptionStore.getAllMetadata().single;
    expect(metadata.cachedVisibleProxyCount, greaterThan(0));
    expect(metadata.hasRawPayload, isTrue);
  });

  test('cancelled file import does not persist a subscription', () async {
    var cancellationChecks = 0;

    await expectLater(
      SubscriptionStore.addFromContent(
        'vless://uuid@server.com:443?type=tcp&security=tls#Node1',
        sourceName: 'nodes.txt',
        isCancelled: () => ++cancellationChecks >= 3,
      ),
      throwsA(isA<SubscriptionImportCancelledException>()),
    );

    expect(SubscriptionStore.getAllMetadata(), isEmpty);
  });

  test(
    'stores payloads compressed without changing hydrated profiles',
    () async {
      final subscription = Subscription(
        id: 'compressed-profile',
        name: 'Compressed profile',
        url: 'file:///compressed.txt',
        rawContent: ''.padRight(512 * 1024, 'a'),
        outbounds: const [
          Outbound(
            tag: 'node-1',
            name: 'Node 1',
            config: {'type': 'vless', 'server': 'server.example'},
          ),
        ],
      );

      await SubscriptionStore.save(subscription);

      final stored = Hive.box(
        'subscription_payloads_secure_v1',
      ).get(subscription.id);
      expect(stored, isA<String>());
      expect(stored as String, startsWith('gzip-base64-v1:'));
      expect(stored.length, lessThan(subscription.rawContent.length ~/ 10));
      expect(SubscriptionStore.payloadSnapshotFor(subscription.id), stored);
      expect(
        jsonDecode(SubscriptionStore.payloadJsonFor(subscription.id)!)
            as Map<String, dynamic>,
        containsPair('raw_content', subscription.rawContent),
      );

      final hydrated = await SubscriptionStore.getInBackground(subscription.id);
      expect(hydrated, isNotNull);
      expect(hydrated!.rawContent, subscription.rawContent);
      expect(hydrated.outbounds.single.tag, 'node-1');
    },
  );

  test('addFromUrl reports a successful response without proxies', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) async {
      request.response.statusCode = HttpStatus.ok;
      request.response.write('{"message":"subscription expired"}');
      await request.response.close();
    });

    final result = await SubscriptionStore.addFromUrl(
      'http://${server.address.host}:${server.port}/sub',
    );

    expect(result.hasWarning, isTrue);
    expect(
      result.warning,
      isA<SubscriptionContentException>().having(
        (error) => error.kind,
        'kind',
        SubscriptionContentFailureKind.noUsableProxies,
      ),
    );
    expect(result.subscription.outbounds, isEmpty);
  });

  test('coalesces concurrent refreshes of the same subscription', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var requestCount = 0;

    server.listen((request) async {
      requestCount++;
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.text;
      request.response.write(
        'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@server.example.com:443'
        '?encryption=none&security=tls#Node',
      );
      await request.response.close();
    });

    final url = 'http://${server.address.host}:${server.port}/subscription';
    await SubscriptionStore.save(
      Subscription(
        id: 'single-flight-refresh',
        name: 'Single flight',
        url: url,
        outbounds: const [
          Outbound(
            tag: 'old-node',
            name: 'Old node',
            config: {
              'type': 'vless',
              'server': 'old.example.com',
              'server_port': 443,
            },
          ),
        ],
      ),
    );

    final first = SubscriptionStore.refresh('single-flight-refresh');
    final second = SubscriptionStore.refresh('single-flight-refresh');

    final results = await Future.wait([first, second]);
    expect(requestCount, 1);
    expect(results[0].outbounds.single.tag, results[1].outbounds.single.tag);
  });

  test('builds Husi-style proxy chain detours from parsed links', () {
    const raw =
        'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@144.31.94.151:443'
        '?encryption=none&flow=xtls-rprx-vision&security=reality'
        '&sni=kinopoisk.ru&fp=chrome'
        '&pbk=mhvT7-nUtXaWrw1Xf7JmBsB0Twj4-alH73mgsN4PZz0'
        '&sid=29f847c151f96091#%D0%90%D0%B2%D1%81%D1%82%D1%80%D0%B8%D1%8F%E2%9A%A1%F0%9F%A4%96%C2%B7%20TCP'
        ' -> socks5://VzBzbTRTOkJETEx0Vw==@178.171.42.39:9909#178.171.42.39%3A9909';

    final payload = SubscriptionStore.buildSubscriptionPayloadForTest(
      SubscriptionParser.parse(raw),
    );

    expect(payload.warnings, isEmpty);
    expect(payload.outbounds.length, 2);
    final firstHop = payload.outbounds[0];
    final chained = payload.outbounds[1];
    expect(firstHop['config']['type'], 'vless');
    expect(firstHop['config']['_group_only'], true);
    expect(chained['config']['type'], 'socks');
    expect(chained['config']['detour'], firstHop['tag']);
    expect(chained['config']['username'], 'W0sm4S');
    expect(chained['config']['password'], 'BDLLtW');
  });

  test('get hydrates saved proxy groups from payload storage', () async {
    const subscription = Subscription(
      id: 'grouped-sub',
      name: 'Grouped subscription',
      url: 'https://example.com/sub',
      outbounds: [
        Outbound(
          tag: 'leaf-1',
          name: 'Leaf 1',
          config: {'type': 'vless', 'tag': 'leaf-1'},
        ),
        Outbound(
          tag: 'leaf-2',
          name: 'Leaf 2',
          config: {'type': 'vless', 'tag': 'leaf-2'},
        ),
      ],
      groups: [
        SubscriptionGroup(
          tag: 'group-auto',
          name: 'Auto group',
          outboundTags: ['leaf-1', 'leaf-2'],
        ),
      ],
    );

    await SubscriptionStore.save(subscription);

    final saved = SubscriptionStore.get(subscription.id);
    expect(saved, isNotNull);
    expect(saved!.outbounds.map((entry) => entry.tag), ['leaf-1', 'leaf-2']);
    expect(saved.groups, hasLength(1));
    expect(saved.groups.single.tag, 'group-auto');
    expect(saved.groups.single.outboundTags, ['leaf-1', 'leaf-2']);
  });

  test(
    'selected proxy save preserves newer subscription metadata and payload',
    () async {
      const original = Subscription(
        id: 'selection-race-sub',
        name: 'Original name',
        url: 'https://example.com/original',
        selectedProxyTag: 'leaf-1',
        lastUpdated: 1,
        rawContent: 'original subscription payload',
        outbounds: [
          Outbound(
            tag: 'leaf-1',
            name: 'Leaf 1',
            config: {'type': 'vless', 'tag': 'leaf-1'},
          ),
        ],
      );
      await SubscriptionStore.save(original);
      final staleSelection = SubscriptionStore.get(original.id)!;

      const refreshed = Subscription(
        id: 'selection-race-sub',
        name: 'Refreshed name',
        url: 'https://example.com/refreshed',
        selectedProxyTag: 'leaf-1',
        lastUpdated: 2,
        rawContent: 'refreshed subscription payload',
        outbounds: [
          Outbound(
            tag: 'leaf-1',
            name: 'Leaf 1 refreshed',
            config: {'type': 'vless', 'tag': 'leaf-1'},
          ),
          Outbound(
            tag: 'leaf-2',
            name: 'Leaf 2',
            config: {'type': 'vless', 'tag': 'leaf-2'},
          ),
        ],
      );
      await SubscriptionStore.save(refreshed);

      await SubscriptionStore.saveSelectedProxyMetadata(
        staleSelection.copyWith(selectedProxyTag: 'leaf-2'),
      );

      final saved = SubscriptionStore.get(original.id);
      expect(saved, isNotNull);
      expect(saved!.selectedProxyTag, 'leaf-2');
      expect(saved.name, 'Refreshed name');
      expect(saved.url, 'https://example.com/refreshed');
      expect(saved.lastUpdated, 2);
      expect(saved.rawContent, 'refreshed subscription payload');
      expect(saved.outbounds.map((outbound) => outbound.tag), [
        'leaf-1',
        'leaf-2',
      ]);
    },
  );

  test('keeps selected proxy group when group still has live children', () {
    const outbounds = [
      Outbound(
        tag: 'leaf-1',
        name: 'Leaf 1',
        config: {'type': 'vless', 'tag': 'leaf-1'},
      ),
      Outbound(
        tag: 'leaf-2',
        name: 'Leaf 2',
        config: {'type': 'vless', 'tag': 'leaf-2'},
      ),
    ];
    const groups = [
      SubscriptionGroup(
        tag: 'group-auto',
        name: 'Auto group',
        outboundTags: ['leaf-1', 'leaf-2'],
      ),
    ];

    final selected = SubscriptionStore.selectedProxyTagForOutboundsForTest(
      outbounds,
      preferredTag: 'group-auto',
      groups: groups,
    );

    expect(selected, 'group-auto');
  });

  test('falls back when selected proxy group has no live children', () {
    const outbounds = [
      Outbound(
        tag: 'leaf-1',
        name: 'Leaf 1',
        config: {'type': 'vless', 'tag': 'leaf-1'},
      ),
      Outbound(
        tag: 'leaf-2',
        name: 'Leaf 2',
        config: {'type': 'vless', 'tag': 'leaf-2'},
      ),
    ];
    const groups = [
      SubscriptionGroup(
        tag: 'group-auto',
        name: 'Auto group',
        outboundTags: ['missing'],
      ),
    ];

    final selected = SubscriptionStore.selectedProxyTagForOutboundsForTest(
      outbounds,
      preferredTag: 'group-auto',
      groups: groups,
    );

    expect(selected, 'lowest');
  });

  test('keeps latency runtime-only without clearing location fields', () async {
    const subscription = Subscription(
      id: 'runtime-sub',
      name: 'Runtime subscription',
      url: 'https://example.com/sub',
      outbounds: [
        Outbound(
          tag: 'leaf-1',
          name: 'Leaf 1',
          config: {'type': 'vless', 'tag': 'leaf-1'},
          info: OutboundInfo(
            externalIp: '1.1.1.1',
            country: 'FI',
            exitCountry: 'SE',
          ),
        ),
      ],
    );

    await SubscriptionStore.save(subscription);
    await SubscriptionStore.saveOutboundRuntimeInfoInBackground(
      subscription.id,
      latestPings: const {'leaf-1': 42},
    );

    var saved = SubscriptionStore.get(subscription.id);
    expect(saved, isNotNull);
    expect(saved!.outbounds.single.info.latestPing, isNull);
    expect(saved.outbounds.single.info.externalIp, '1.1.1.1');
    expect(saved.outbounds.single.info.country, 'FI');
    expect(saved.outbounds.single.info.exitCountry, 'SE');

    await SubscriptionStore.saveOutboundRuntimeInfoInBackground(
      subscription.id,
      externalInfos: const {
        'leaf-1': {
          'external_ip': '2.2.2.2',
          'source_country': 'FI',
          'exit_country': 'DE',
        },
      },
    );

    saved = SubscriptionStore.get(subscription.id);
    expect(saved, isNotNull);
    expect(saved!.outbounds.single.info.latestPing, isNull);
    expect(saved.outbounds.single.info.externalIp, '2.2.2.2');
    expect(saved.outbounds.single.info.country, 'FI');
    expect(saved.outbounds.single.info.exitCountry, 'DE');
  });

  test('preserves state across duplicate endpoints when credentials match', () {
    final oldOutbounds = [
      _outbound(
        tag: 'proxy',
        name: 'proxy',
        server: '89.106.85.2',
        country: 'DE',
        latestPing: 42,
      ),
      _outbound(
        tag: 'germany',
        name: 'Germany',
        server: '89.106.85.2',
        country: 'SE',
        latestPing: 84,
      ),
    ];
    final newOutbounds = [
      _outbound(tag: 'proxy', name: 'proxy', server: '89.106.85.2'),
      _outbound(tag: 'germany', name: 'Germany', server: '89.106.85.2'),
    ];

    final preserved = SubscriptionStore.preserveUserStateForTest(
      oldOutbounds,
      newOutbounds,
    );

    expect(preserved[0].info.country, 'DE');
    expect(preserved[0].info.latestPing, 42);
    expect(preserved[1].info.country, 'SE');
    expect(preserved[1].info.latestPing, 84);
  });

  test('does not preserve runtime state when outbound credentials change', () {
    final oldOutbounds = [
      _outbound(
        tag: 'proxy',
        name: 'proxy',
        server: '89.106.85.2',
        country: 'DE',
        latestPing: 42,
      ),
    ];
    final newOutbounds = [
      _outbound(
        tag: 'proxy',
        name: 'proxy',
        server: '89.106.85.2',
        uuid: 'changed-uuid',
      ),
    ];

    final preserved = SubscriptionStore.preserveUserStateForTest(
      oldOutbounds,
      newOutbounds,
    );

    expect(preserved.single.info.country, isNull);
    expect(preserved.single.info.latestPing, isNull);
  });

  test('preserves runtime state when outbound credentials stay the same', () {
    final oldOutbounds = [
      _outbound(
        tag: 'proxy',
        name: 'proxy',
        server: '89.106.85.2',
        country: 'DE',
        latestPing: 42,
      ),
    ];
    final newOutbounds = [
      _outbound(tag: 'proxy', name: 'proxy', server: '89.106.85.2'),
    ];

    final preserved = SubscriptionStore.preserveUserStateForTest(
      oldOutbounds,
      newOutbounds,
    );

    expect(preserved.single.info.country, 'DE');
    expect(preserved.single.info.latestPing, 42);
  });

  test('normalizes LagomVPN full-profile outbounds', () {
    final payload = SubscriptionStore.buildSubscriptionPayloadForTest(
      ParseResult(
        format: SubscriptionFormat.xrayConfig,
        outbounds: [
          _parsedLagomVless(
            sourceTag: 'proxy',
            sourceScope: 'xray-0',
            profileName: '🇫🇮 Финляндия',
            server: 'pro-fi.emrata.top',
          ),
          _parsedLagomVless(
            sourceTag: 'proxy',
            sourceScope: 'xray-1',
            profileName: 'YouTube (Глобальный)',
            server: 'pro-se.emrata.top',
          ),
          _parsedLagomVless(sourceTag: 'WL-01-VKC-01-02'),
          _parsedLagomVless(sourceTag: 'WL-01-VKC-01-07'),
          _parsedLagomVless(sourceTag: 'WL-01-CON-01-04'),
          _parsedLagomVless(sourceTag: 'WL-02-SEL-01-04'),
          _parsedLagomVless(sourceTag: 'WL-02-CDN-YA-01'),
          _parsedLagomVless(sourceTag: 'WL-03-YAD-01-04'),
          _parsedLagomVless(sourceTag: 'WL-03-YAD-02-04'),
          _parsedLagomVless(
            sourceTag: 'WL-03-YAD-02-04',
            sourceScope: 'xray-1',
          ),
          {
            '_name': 'WL-IN',
            '_source_tag': 'WL-IN',
            '_source_scope': 'xray-0',
            'type': 'socks',
            'server': '127.0.0.1',
            'server_port': 10810,
          },
        ],
        groups: const [
          ParsedOutboundGroup(
            sourceTag: '01-FALLBACK',
            name: 'fallback',
            sourceOutboundTags: ['WL-01-VKC-01-02', 'WL-01-VKC-01-07'],
            url: 'https://www.google.com/generate_204',
            intervalSeconds: 300,
          ),
        ],
      ),
      providerName: 'LagomVPN 🫠',
    );

    expect(payload.outbounds.map((entry) => entry['name']), [
      'Direct',
      'WL',
      'Direct',
      'WL',
      'WL VK Cloud',
      'WL VK Cloud 2',
      'WL Contell',
      'WL SEL',
      'WL CDN Yandex',
      'WL Yandex',
      'WL Yandex 2',
    ]);
    expect(payload.outbounds.map((entry) => entry['info']?['country']), [
      'FI',
      'FI',
      null,
      null,
      'RU',
      'RU',
      'RU',
      'RU',
      'RU',
      'RU',
      'RU',
    ]);
    final finlandWhitelist = payload.outbounds[1]['config'] as Map;
    final youtubeWhitelist = payload.outbounds[3]['config'] as Map;
    expect(finlandWhitelist['detour'], 'whitelist');
    expect(finlandWhitelist['_group_only'], isTrue);
    expect(youtubeWhitelist['detour'], 'whitelist');
    expect(youtubeWhitelist['_group_only'], isTrue);

    expect(payload.groups, hasLength(3));
    expect(payload.groups[0]['name'], 'Финляндия');
    expect(payload.groups[0]['type'], 'urltest');
    expect(payload.groups[0]['outbounds'], ['vless-0', 'wl']);
    expect(payload.groups[0]['urltest_config'], {
      'method': 'setback',
      'url': 'https://www.google.com/generate_204',
      'interval': 300,
    });
    expect(payload.groups[1]['name'], 'YouTube');
    expect(payload.groups[1]['type'], 'urltest');
    expect(payload.groups[1]['outbounds'], ['vless-2', 'vless-3']);
    expect(payload.groups[1]['urltest_config'], {
      'method': 'setback',
      'url': 'https://www.google.com/generate_204',
      'interval': 300,
    });
    expect(payload.groups[2]['tag'], 'whitelist');
    expect(payload.groups[2]['name'], 'Whitelist');
    expect(payload.groups[2]['type'], 'urltest');
    expect(payload.groups[2]['outbounds'], [
      'wl-vk-cloud',
      'wl-vk-cloud-2',
      'wl-contell',
      'wl-sel',
      'wl-cdn-yandex',
      'wl-yandex',
      'wl-yandex-2',
    ]);
    expect(payload.groups[2]['urltest_config'], {
      'method': 'lowest',
      'url': 'https://www.google.com/generate_204',
      'interval': 300,
    });
  });
}

class _PassthroughHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionTimeout = const Duration(seconds: 15);
    return client;
  }
}

Outbound _outbound({
  required String tag,
  required String name,
  required String server,
  String? uuid,
  String? country,
  int? latestPing,
}) {
  return Outbound(
    tag: tag,
    name: name,
    config: {
      'type': 'vless',
      'tag': tag,
      'server': server,
      'server_port': 443,
      'uuid': uuid ?? '$tag-uuid',
    },
    info: OutboundInfo(country: country, latestPing: latestPing),
  );
}

Map<String, dynamic> _parsedLagomVless({
  required String sourceTag,
  String sourceScope = 'xray-0',
  String? profileName,
  String server = 'server.example.com',
}) {
  return {
    '_name': sourceTag,
    '_source_tag': sourceTag,
    '_source_scope': sourceScope,
    '_source_profile_name': ?profileName,
    'type': 'vless',
    'tag': '',
    'server': server,
    'server_port': 443,
    'uuid': '84efe0da-6bad-4008-98e6-37c6b6f3846b',
  };
}
