import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_parser.dart';
import 'package:meow_client/data/subscription/subscription_failure.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/logging/app_log_store.dart';
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

      final saved = await SubscriptionStore.get(result.subscription.id);
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

  test('payload summary cannot replace a newer nonzero count', () async {
    await SubscriptionStore.save(
      const Subscription(
        id: 'summary-race',
        name: 'Summary race',
        url: 'https://example.com/summary',
        outbounds: [
          Outbound(tag: 'proxy', name: 'Proxy', config: {'type': 'vless'}),
        ],
      ),
    );
    final current = SubscriptionStore.getMetadata('summary-race')!;
    await SubscriptionStore.cachePayloadSummaries({
      current.id: (
        visibleProxyCount: 0,
        hasRawPayload: false,
        payloadRevision: current.payloadRevision,
      ),
    });
    expect(
      SubscriptionStore.getMetadata(current.id)!.cachedVisibleProxyCount,
      1,
    );
  });

  test('payload summary ignores a superseded payload revision', () async {
    await SubscriptionStore.save(
      const Subscription(
        id: 'summary-revision',
        name: 'Summary revision',
        url: 'https://example.com/summary',
        outbounds: [
          Outbound(tag: 'proxy', name: 'Proxy', config: {'type': 'vless'}),
        ],
      ),
    );
    final current = SubscriptionStore.getMetadata('summary-revision')!;
    await SubscriptionStore.cachePayloadSummaries({
      current.id: (
        visibleProxyCount: 0,
        hasRawPayload: false,
        payloadRevision: 'old-revision',
      ),
    });
    expect(
      SubscriptionStore.getMetadata(current.id)!.cachedVisibleProxyCount,
      1,
    );
  });

  test('payload summary repairs a stale zero count', () async {
    await SubscriptionStore.save(
      const Subscription(
        id: 'summary-repair',
        name: 'Summary repair',
        url: 'https://example.com/summary',
        rawContent: 'vless://uuid@example.com:443#Proxy',
        outbounds: [
          Outbound(tag: 'proxy', name: 'Proxy', config: {'type': 'vless'}),
        ],
      ),
    );
    final current = SubscriptionStore.getMetadata('summary-repair')!;
    await SubscriptionStore.saveMetadata(
      current.copyWith(cachedVisibleProxyCount: 0),
    );
    await SubscriptionStore.cachePayloadSummaries({
      current.id: (
        visibleProxyCount: 1,
        hasRawPayload: true,
        payloadRevision: current.payloadRevision,
      ),
    });
    expect(
      SubscriptionStore.getMetadata(current.id)!.cachedVisibleProxyCount,
      1,
    );
  });

  test(
    'a changed outbound config changes the metadata payload revision',
    () async {
      await SubscriptionStore.save(
        const Subscription(
          id: 'config-revision',
          name: 'Config revision',
          url: 'https://example.com/config',
          outbounds: [
            Outbound(
              tag: 'proxy',
              name: 'Proxy',
              config: {'type': 'vless', 'server': 'one.example.com'},
            ),
          ],
        ),
      );
      final before = SubscriptionStore.getMetadata('config-revision')!;
      final hydrated = (await SubscriptionStore.get(before.id))!;
      await SubscriptionStore.save(
        hydrated.copyWith(
          outbounds: const [
            Outbound(
              tag: 'proxy',
              name: 'Proxy',
              config: {'type': 'vless', 'server': 'two.example.com'},
            ),
          ],
        ),
      );
      final after = SubscriptionStore.getMetadata(before.id)!;
      expect(after.payloadRevision, isNot(before.payloadRevision));
    },
  );

  test(
    'file import rejects a WireGuard-only profile with a clear reason',
    () async {
      const content = '''
[Interface]
PrivateKey = yGXGKezPjPNbRfHAJNmkDDT4hPsYRFJ+/GIOQ1kzIXM=
Address = 10.0.0.2/32

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0
Endpoint = wg.example.com:51820
''';

      await expectLater(
        SubscriptionStore.addFromContent(content, sourceName: 'wireguard.conf'),
        throwsA(
          isA<SubscriptionContentException>().having(
            (error) => error.kind,
            'kind',
            SubscriptionContentFailureKind.wireGuardUnsupported,
          ),
        ),
      );
    },
  );

  test('mixed import skips WireGuard and keeps supported servers', () async {
    final result = await SubscriptionStore.addFromContent(
      jsonEncode({
        'outbounds': [
          {
            'type': 'vless',
            'tag': 'supported',
            'server': 'server.example.com',
            'server_port': 443,
            'uuid': '11111111-1111-1111-1111-111111111111',
          },
          {
            'type': 'wireguard',
            'tag': 'unsupported',
            'private_key': 'yGXGKezPjPNbRfHAJNmkDDT4hPsYRFJ+/GIOQ1kzIXM=',
            'address': ['10.0.0.2/32'],
            'peers': [
              {
                'address': 'wg.example.com',
                'port': 51820,
                'public_key': 'bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=',
                'allowed_ips': ['0.0.0.0/0'],
              },
            ],
          },
        ],
      }),
      sourceName: 'mixed.json',
    );

    expect(result.subscription.outbounds, hasLength(1));
    expect(result.subscription.outbounds.single.type, 'vless');
    expect(
      result.warning,
      isA<SubscriptionContentException>().having(
        (error) => error.kind,
        'kind',
        SubscriptionContentFailureKind.wireGuardUnsupported,
      ),
    );
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

      final stored = await Hive.lazyBox<dynamic>(
        'subscription_payloads_secure_v1',
      ).get(subscription.id);
      expect(stored, isA<Uint8List>());
      expect(
        (stored as Uint8List).length,
        lessThan(subscription.rawContent.length ~/ 10),
      );
      expect(
        await SubscriptionStore.payloadSnapshotFor(subscription.id),
        stored,
      );
      expect(
        jsonDecode((await SubscriptionStore.payloadJsonFor(subscription.id))!)
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

    AppLogStore.clear();
    final first = SubscriptionStore.refresh('single-flight-refresh');
    final second = SubscriptionStore.refresh('single-flight-refresh');

    final results = await Future.wait([first, second]);
    expect(requestCount, 1);
    expect(results[0].outbounds.single.tag, results[1].outbounds.single.tag);
    final refreshTimings = AppLogStore.entries.value
        .where((entry) => entry.title == 'subscription refresh timing')
        .toList();
    expect(refreshTimings, hasLength(1));
    final timing = refreshTimings.single.message;
    for (final stage in [
      'totalMs',
      'payloadOpenMs',
      'metadataMs',
      'fetchMs',
      'buildMs',
      'lockReadMs',
      'preserveMs',
      'saveMs',
    ]) {
      expect(timing, matches(RegExp('$stage=\\d+')));
    }
    expect(timing, contains('nodes=1'));
    expect(timing, isNot(contains(url)));
    expect(
      AppLogStore.entries.value.any(
        (entry) =>
            entry.title == 'subscription fetch timing' &&
            RegExp(r'networkMs=\d+').hasMatch(entry.message),
      ),
      isTrue,
    );
    expect(
      AppLogStore.entries.value.any(
        (entry) =>
            entry.title == 'subscription parse timing' &&
            RegExp(r'parseMs=\d+').hasMatch(entry.message),
      ),
      isTrue,
    );
    expect(
      AppLogStore.entries.value.any(
        (entry) =>
            entry.title == 'subscription save timing' &&
            RegExp(r'encodeMs=\d+').hasMatch(entry.message) &&
            RegExp(r'payloadWriteMs=\d+').hasMatch(entry.message),
      ),
      isTrue,
    );
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

    final saved = await SubscriptionStore.get(subscription.id);
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
      final staleSelection = (await SubscriptionStore.get(original.id))!;

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

      final saved = await SubscriptionStore.get(original.id);
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

  test('refresh keeps selected server when its configuration changes', () async {
    var body =
        'vless://aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa@old.example:443?security=tls#Chosen\n'
        'vless://bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb@other.example:443?security=tls#Other';
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.text;
      request.response.write(body);
      await request.response.close();
    });
    final added = await SubscriptionStore.addFromUrl(
      'http://${server.address.host}:${server.port}/sub',
    );
    final original = added.subscription;
    final chosen = original.outbounds.singleWhere(
      (outbound) => outbound.name == 'Chosen',
    );
    await SubscriptionStore.saveSelectedProxyMetadata(
      original.copyWith(selectedProxyTag: chosen.tag),
    );

    body = body.replaceFirst('old.example:443', 'new.example:8443');
    final refreshed = await SubscriptionStore.refresh(original.id);

    expect(refreshed.selectedProxyTag, chosen.tag);
    expect(
      refreshed.outbounds
          .singleWhere((outbound) => outbound.tag == chosen.tag)
          .config['server'],
      'new.example',
    );
  });

  test(
    'refresh respects a user interval instead of the provider header',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        request.response.headers.set('profile-update-interval', '3');
        request.response.write(
          'vless://aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa@example.com:443?security=tls#Node',
        );
        await request.response.close();
      });
      final added = await SubscriptionStore.addFromUrl(
        'http://${server.address.host}:${server.port}/sub',
      );
      expect(added.subscription.autoRefreshMinutes, 180);
      final metadata = added.subscription.toMetadataMap()
        ..['auto_refresh_minutes'] = 2880
        ..['auto_refresh_overridden'] = true;
      await SubscriptionStore.saveMetadata(
        Subscription.fromMetadataMap(metadata),
      );
      final refreshed = await SubscriptionStore.refresh(added.subscription.id);
      expect(refreshed.autoRefreshMinutes, 2880);
      expect(refreshed.toMetadataMap()['auto_refresh_overridden'], true);
    },
  );

  test('persists latest latency alongside location fields', () async {
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
      expectedOutboundKeys: {
        'leaf-1': SubscriptionStore.outboundIdentityKey(
          subscription.outbounds.single.config,
        ),
      },
    );

    var saved = await SubscriptionStore.get(subscription.id);
    expect(saved, isNotNull);
    expect(saved!.outbounds.single.info.latestPing, 42);
    expect(saved.outbounds.single.info.externalIp, '1.1.1.1');
    expect(saved.outbounds.single.info.country, 'FI');
    expect(saved.outbounds.single.info.exitCountry, 'SE');

    await SubscriptionStore.saveOutboundRuntimeInfoInBackground(
      subscription.id,
      expectedOutboundKeys: {
        'leaf-1': SubscriptionStore.outboundIdentityKey(
          subscription.outbounds.single.config,
        ),
      },
      externalInfos: const {
        'leaf-1': {
          'external_ip': '2.2.2.2',
          'source_country': 'FI',
          'exit_country': 'DE',
        },
      },
    );

    saved = await SubscriptionStore.get(subscription.id);
    expect(saved, isNotNull);
    expect(saved!.outbounds.single.info.latestPing, 42);
    expect(saved.outbounds.single.info.externalIp, '2.2.2.2');
    expect(saved.outbounds.single.info.country, 'FI');
    expect(saved.outbounds.single.info.exitCountry, 'DE');
  });

  test(
    'delayed latency write cannot attach to a refreshed server with the same tag',
    () async {
      const oldOutbound = Outbound(
        tag: 'leaf-1',
        name: 'Leaf 1',
        config: {
          'type': 'vless',
          'tag': 'leaf-1',
          'server': 'old.example',
          'server_port': 443,
          'uuid': '11111111-1111-1111-1111-111111111111',
        },
      );
      const refreshedOutbound = Outbound(
        tag: 'leaf-1',
        name: 'Leaf 1',
        config: {
          'type': 'vless',
          'tag': 'leaf-1',
          'server': 'new.example',
          'server_port': 443,
          'uuid': '11111111-1111-1111-1111-111111111111',
        },
      );
      const oldSubscription = Subscription(
        id: 'refreshed-sub',
        name: 'Refreshed subscription',
        url: 'https://example.com/sub',
        outbounds: [oldOutbound],
      );
      await SubscriptionStore.save(oldSubscription);
      final oldKey = SubscriptionStore.outboundIdentityKey(oldOutbound.config);
      await SubscriptionStore.save(
        oldSubscription.copyWith(outbounds: [refreshedOutbound]),
      );

      expect(
        await SubscriptionStore.saveLatestPingsInBackground(
          oldSubscription.id,
          const {'leaf-1': 42},
          expectedOutboundKeys: {'leaf-1': oldKey},
        ),
        isFalse,
      );
      final saved = await SubscriptionStore.get(oldSubscription.id);
      expect(saved!.outbounds.single.info.latestPing, isNull);
    },
  );

  test(
    'delayed location write cannot attach to a refreshed server with the same tag',
    () async {
      const oldOutbound = Outbound(
        tag: 'leaf-1',
        name: 'Leaf 1',
        config: {'type': 'vless', 'tag': 'leaf-1', 'server': 'old.example'},
      );
      const newOutbound = Outbound(
        tag: 'leaf-1',
        name: 'Leaf 1',
        config: {'type': 'vless', 'tag': 'leaf-1', 'server': 'new.example'},
      );
      const stableOutbound = Outbound(
        tag: 'leaf-2',
        name: 'Leaf 2',
        config: {'type': 'vless', 'tag': 'leaf-2', 'server': 'stable.example'},
      );
      const subscription = Subscription(
        id: 'location-refresh-sub',
        name: 'Location refresh',
        url: 'https://example.com/sub',
        outbounds: [oldOutbound, stableOutbound],
      );
      await SubscriptionStore.save(subscription);
      final oldKey = SubscriptionStore.outboundIdentityKey(oldOutbound.config);
      await SubscriptionStore.save(
        subscription.copyWith(outbounds: [newOutbound, stableOutbound]),
      );

      expect(
        await SubscriptionStore.saveOutboundRuntimeInfoInBackground(
          subscription.id,
          expectedOutboundKeys: {
            'leaf-1': oldKey,
            'leaf-2': SubscriptionStore.outboundIdentityKey(
              stableOutbound.config,
            ),
          },
          externalInfos: const {
            'leaf-1': {'external_ip': '1.2.3.4', 'exit_country': 'DE'},
            'leaf-2': {'external_ip': '5.6.7.8', 'exit_country': 'FI'},
          },
        ),
        isTrue,
      );
      final saved = await SubscriptionStore.get(subscription.id);
      expect(saved!.outbounds[0].info.externalIp, isNull);
      expect(saved.outbounds[0].info.exitCountry, isNull);
      expect(saved.outbounds[1].info.externalIp, '5.6.7.8');
      expect(saved.outbounds[1].info.exitCountry, 'FI');
    },
  );

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

  test('shouldCompactMetadataBox triggers when threshold is reached', () {
    expect(shouldCompactMetadataBox(10, 9), isFalse);
    expect(shouldCompactMetadataBox(20, 10), isFalse);
    expect(shouldCompactMetadataBox(10, 10), isTrue);
    expect(shouldCompactMetadataBox(5, 10), isTrue);
  });

  test(
    'saving with unchanged payload content updates metadata and avoids redundant write',
    () async {
      final sub = Subscription(
        id: 'sub-test-id',
        name: 'Test Profile',
        url: 'https://example.com/sub',
        outbounds: [
          _outbound(tag: 'node-1', name: 'Node 1', server: '1.2.3.4'),
        ],
        lastUpdated: 1000,
      );

      await SubscriptionStore.save(sub);
      final saved1 = await SubscriptionStore.get('sub-test-id');
      expect(saved1, isNotNull);
      expect(saved1!.payloadRevision, isNotEmpty);
      final revision = saved1.payloadRevision;

      // Simulate refresh with identical outbounds but updated timestamp
      final updated = saved1.copyWith(
        lastUpdated: 2000,
        name: 'Test Profile Updated',
      );

      final payloadBox = Hive.lazyBox<dynamic>(
        'subscription_payloads_secure_v1',
      );
      final payloadEvents = <BoxEvent>[];
      final payloadEventsSubscription = payloadBox
          .watch(key: sub.id)
          .listen(payloadEvents.add);
      addTearDown(payloadEventsSubscription.cancel);

      await SubscriptionStore.save(updated);
      await Future<void>.delayed(Duration.zero);

      final saved2 = await SubscriptionStore.get('sub-test-id');
      expect(saved2, isNotNull);
      expect(saved2!.name, 'Test Profile Updated');
      expect(saved2.lastUpdated, 2000);
      expect(saved2.payloadRevision, revision);
      expect(saved2.outbounds.length, 1);
      expect(saved2.outbounds.first.tag, 'node-1');
      expect(payloadEvents, isEmpty);
    },
  );

  test('stale payload revision cannot skip a required payload write', () async {
    final original = Subscription(
      id: 'stale-revision-test',
      name: 'Original',
      url: 'https://example.com/sub',
      outbounds: [_outbound(tag: 'node-1', name: 'Node 1', server: '1.1.1.1')],
    );
    await SubscriptionStore.save(original);
    final staleSnapshot = await SubscriptionStore.get(original.id);
    expect(staleSnapshot, isNotNull);

    await SubscriptionStore.save(
      staleSnapshot!.copyWith(
        name: 'New payload',
        outbounds: [
          _outbound(tag: 'node-1', name: 'Node 1', server: '2.2.2.2'),
        ],
      ),
    );

    await SubscriptionStore.save(staleSnapshot.copyWith(name: 'Restored'));

    final restored = await SubscriptionStore.get(original.id);
    expect(restored, isNotNull);
    expect(restored!.name, 'Restored');
    expect(restored.outbounds.single.server, '1.1.1.1');
    expect(restored.payloadRevision, staleSnapshot.payloadRevision);
  });

  test('payload comparison repairs mismatched metadata revision', () async {
    final original = Subscription(
      id: 'mismatched-revision-test',
      name: 'Original',
      url: 'https://example.com/sub',
      outbounds: [_outbound(tag: 'node-1', name: 'Node 1', server: '1.1.1.1')],
    );
    await SubscriptionStore.save(original);
    final originalSnapshot = await SubscriptionStore.get(original.id);
    expect(originalSnapshot, isNotNull);

    await SubscriptionStore.save(
      originalSnapshot!.copyWith(
        name: 'New payload',
        outbounds: [
          _outbound(tag: 'node-1', name: 'Node 1', server: '2.2.2.2'),
        ],
      ),
    );

    // Simulate a previous interrupted save: metadata still describes the old
    // payload while the payload box already contains the newer bytes.
    await Hive.box<dynamic>(
      'subscriptions_secure_v1',
    ).put(original.id, jsonEncode(originalSnapshot.toMetadataMap()));

    await SubscriptionStore.save(originalSnapshot.copyWith(name: 'Restored'));

    final restored = await SubscriptionStore.get(original.id);
    expect(restored, isNotNull);
    expect(restored!.name, 'Restored');
    expect(restored.outbounds.single.server, '1.1.1.1');
    expect(restored.payloadRevision, originalSnapshot.payloadRevision);
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
