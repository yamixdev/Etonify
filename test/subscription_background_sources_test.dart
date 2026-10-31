import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_background_updates.dart';
import 'package:meow_client/data/subscription/subscription_fetcher.dart';
import 'package:meow_client/data/subscription/subscription_failure.dart';
import 'package:meow_client/data/subscription/subscription_refresh_report.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';
import 'support/windows_storage_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('meow_client/subscription_refresh');
  late Directory directory;
  var plans = <Map<String, dynamic>>[];
  var pending = <Map<String, dynamic>>[];
  var results = <String, Map<String, dynamic>>{};
  var acknowledged = <String>[];
  Future<void> Function()? beforeRead;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'etonify-background-sources',
    );
    await bootstrapWindowsStorageFixture(directory);
    Hive.init(directory.path);
    await SubscriptionStore.init();
    SubscriptionFetcher.configureHwidSharing(false);
    await SubscriptionRefreshReports.setBackgroundEnabled(true);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    plans = [];
    pending = [];
    results = {};
    acknowledged = [];
    beforeRead = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'configure':
              plans = (jsonDecode(call.arguments as String)['profiles'] as List)
                  .map((p) => Map<String, dynamic>.from(p as Map))
                  .toList();
              return null;
            case 'pending':
              return jsonEncode(pending);
            case 'read':
              await beforeRead?.call();
              return jsonEncode(results[call.arguments]);
            case 'ack':
              acknowledged.add(
                jsonDecode(call.arguments as String)['id'] as String,
              );
              return null;
          }
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  SubscriptionSource source(String id, {bool enabled = true, String? url}) =>
      SubscriptionSource(
        id: id,
        enabled: enabled,
        snapshot: Subscription(
          id: id,
          name: 'Source $id',
          url: url ?? 'https://$id.example.test/sub',
          lastUpdated: id == 'a' ? 1000 : 2000,
          info: SubscriptionInfo(customUserAgent: 'agent-$id'),
        ),
      );
  Subscription profile(String id) => Subscription(
    id: id,
    name: 'Combined',
    url: '',
    autoRefreshMinutes: 60,
    sources: [
      source('a'),
      source('b'),
      source('disabled', enabled: false),
      source('local', url: ''),
      source('http', url: 'http://plain.example.test'),
    ],
  );

  test(
    'background plan schedules each enabled HTTPS source with its own headers and backoff',
    () async {
      final p = profile('plans');
      await SubscriptionRefreshReports.save([
        const SubscriptionRefreshEntry(
          id: 'plans',
          sourceId: 'a',
          name: 'a',
          time: 5000000,
          failure: SubscriptionFailure(SubscriptionFailureKind.timeout),
        ),
      ]);
      await SubscriptionBackgroundUpdates.configure([p]);
      expect(plans, hasLength(2));
      expect(plans.map((p) => p['id']), [
        jsonEncode(['plans', 'a']),
        jsonEncode(['plans', 'b']),
      ]);
      expect(plans[0]['dueAt'], 5000000 + 15 * 60000);
      expect(plans[1]['dueAt'], 2000 + 60 * 60000);
      expect(plans[0]['headers']['User-Agent'], 'agent-a');
      expect(plans[1]['headers']['User-Agent'], 'agent-b');
      expect(plans[0]['token'], isNot(plans[1]['token']));
    },
  );

  test(
    'pending failures are recorded on their source and report retains profile id',
    () async {
      final initial = profile('failure');
      final p = initial.copyWith(
        sources: [
          initial.sources.first.copyWith(
            snapshot: initial.sources.first.snapshot.copyWith(
              outbounds: const [
                Outbound(
                  tag: 'retained',
                  name: 'Retained',
                  config: {
                    'type': 'vless',
                    'server': 'retained.example.test',
                    'server_port': 443,
                    'uuid': '11111111-1111-4111-8111-111111111111',
                  },
                ),
              ],
            ),
          ),
          ...initial.sources.skip(1),
        ],
      );
      await SubscriptionStore.save(p);
      await SubscriptionBackgroundUpdates.configure([
        SubscriptionStore.getMetadata(p.id)!,
      ]);
      final plan = plans.first;
      pending = [
        {'id': plan['id'], 'token': plan['token']},
      ];
      results[plan['id'] as String] = {
        'token': plan['token'],
        'time': 8000,
        'failure': 'httpStatus',
        'httpStatus': 502,
      };
      final entries = await SubscriptionBackgroundUpdates.applyPending();
      expect(entries, hasLength(1));
      expect(entries.single.id, 'failure');
      expect(entries.single.sourceId, 'a');
      expect(entries.single.failure?.httpStatus, 502);
      expect(acknowledged, [plan['id']]);
      final stored = (await SubscriptionStore.get('failure'))!;
      expect(stored.effectiveSources.first.lastError, isNotNull);
      expect(stored.effectiveSources[1].lastError, isNull);
      expect(stored.effectiveSources.first.lastUpdated, 1000);
      expect(
        stored.effectiveSources.first.snapshot.outbounds.single.tag,
        'retained',
      );
    },
  );

  test(
    'staged successes for separate sources both apply despite aggregate changes',
    () async {
      await SubscriptionStore.save(
        profile('success').copyWith(autoRefreshMinutes: 1440),
      );
      await SubscriptionBackgroundUpdates.configure([
        SubscriptionStore.getMetadata('success')!,
      ]);
      for (var i = 0; i < plans.length; i++) {
        final plan = plans[i];
        final id = plan['id'] as String;
        pending.add({'id': id, 'token': plan['token']});
        results[id] = {
          'token': plan['token'],
          'time': 9000 + i,
          'body': base64Encode(
            utf8.encode(
              'vless://11111111-1111-4111-8111-111111111111@server$i.example.test:443?security=tls&type=tcp#Node$i',
            ),
          ),
          'headers': <String, String>{
            'profile-update-interval': i == 0 ? '1' : '2',
          },
        };
      }
      final entries = await SubscriptionBackgroundUpdates.applyPending();
      expect(entries.map((e) => e.id), ['success', 'success']);
      expect(entries.map((e) => e.sourceId), ['a', 'b']);
      expect(entries.every((e) => e.succeeded), isTrue);
      expect(acknowledged, hasLength(2));
      final stored = (await SubscriptionStore.get('success'))!;
      expect(stored.autoRefreshMinutes, 60);
      expect(stored.effectiveSources[0].snapshot.outbounds, hasLength(1));
      expect(stored.effectiveSources[1].snapshot.outbounds, hasLength(1));
      expect(
        stored.effectiveSources[0].snapshot.outbounds.single.config['server'],
        'server0.example.test',
      );
      expect(
        stored.effectiveSources[1].snapshot.outbounds.single.config['server'],
        'server1.example.test',
      );
    },
  );

  for (final interval in [180, 0, -60]) {
    test(
      'staged source content survives manual interval $interval only when enabled',
      () async {
        final id = 'manual-interval-$interval';
        await SubscriptionStore.save(profile(id));
        await SubscriptionBackgroundUpdates.configure([
          SubscriptionStore.getMetadata(id)!,
        ]);
        final plan = plans.first;
        pending = [
          {'id': plan['id'], 'token': plan['token']},
        ];
        results[plan['id'] as String] = {
          'token': plan['token'],
          'time': 9000,
          'body': base64Encode(
            utf8.encode(
              'vless://11111111-1111-4111-8111-111111111111@manual-interval.example.test:443?security=tls&type=tcp#Interval',
            ),
          ),
          'headers': <String, String>{},
        };
        final current = (await SubscriptionStore.get(id))!;
        await SubscriptionStore.save(
          current.copyWith(
            autoRefreshMinutes: interval,
            autoRefreshOverridden: true,
          ),
        );
        if (interval <= 0) {
          await expectLater(
            SubscriptionStore.applyBackgroundSourceDownload(
              id,
              'a',
              revision: plan['token'] as String,
              bytes: base64Decode(results[plan['id']]!['body'] as String),
              headers: const {},
            ),
            throwsStateError,
          );
        }
        final entries = await SubscriptionBackgroundUpdates.applyPending();
        final stored = (await SubscriptionStore.get(id))!;
        expect(stored.autoRefreshMinutes, interval);
        expect(acknowledged, [plan['id']]);
        if (interval > 0) {
          expect(entries, hasLength(1));
          expect(entries.single.succeeded, isTrue);
          expect(
            stored.sources.first.snapshot.outbounds.single.config['server'],
            'manual-interval.example.test',
          );
        } else {
          expect(entries, isEmpty);
          expect(stored.sources.first.lastUpdated, 1000);
          expect(stored.sources.first.snapshot.outbounds, isEmpty);
        }
      },
    );
  }

  test('legacy pending ids and profile tokens remain applicable', () async {
    await SubscriptionStore.save(
      const Subscription(
        id: 'legacy',
        name: 'Legacy',
        url: 'https://legacy.example.test/sub',
        lastUpdated: 1000,
      ),
    );
    final p = SubscriptionStore.getMetadata('legacy')!;
    final token = SubscriptionStore.backgroundRevision(p);
    pending = [
      {'id': 'legacy', 'token': token},
    ];
    results['legacy'] = {
      'token': token,
      'time': 9000,
      'body': base64Encode(
        utf8.encode(
          'vless://11111111-1111-4111-8111-111111111111@legacy.example.test:443?security=tls&type=tcp#Legacy',
        ),
      ),
      'headers': <String, String>{},
    };
    final entries = await SubscriptionBackgroundUpdates.applyPending();
    expect(entries.single.id, 'legacy');
    expect(entries.single.sourceId, isNull);
    expect(entries.single.succeeded, isTrue);
    expect((await SubscriptionStore.get('legacy'))!.outbounds, hasLength(1));
    expect(acknowledged, ['legacy']);
  });

  for (final overridden in [false, true]) {
    test(
      'legacy source background download updates interval unless manual override=$overridden',
      () async {
        final id = 'legacy-interval-$overridden';
        await SubscriptionStore.save(
          Subscription(
            id: id,
            name: 'Legacy interval',
            url: 'https://interval.example.test/sub',
            lastUpdated: 1000,
            autoRefreshMinutes: overridden ? 180 : 1440,
            autoRefreshOverridden: overridden,
            info: const SubscriptionInfo(updateIntervalHours: 24),
          ),
        );
        await SubscriptionBackgroundUpdates.configure([
          SubscriptionStore.getMetadata(id)!,
        ]);
        final plan = plans.single;
        pending = [
          {'id': plan['id'], 'token': plan['token']},
        ];
        results[plan['id'] as String] = {
          'token': plan['token'],
          'time': 9000,
          'body': base64Encode(
            utf8.encode(
              'vless://11111111-1111-4111-8111-111111111111@interval.example.test:443?security=tls&type=tcp#Interval',
            ),
          ),
          'headers': {'profile-update-interval': '1'},
        };
        final entries = await SubscriptionBackgroundUpdates.applyPending();
        expect(entries.single.succeeded, isTrue);
        final stored = (await SubscriptionStore.get(id))!;
        expect(stored.autoRefreshMinutes, overridden ? 180 : 60);
        expect(stored.sources.single.snapshot.autoRefreshMinutes, 60);
        expect(stored.autoRefreshOverridden, overridden);
        await SubscriptionBackgroundUpdates.configure([stored]);
        expect(
          plans.single['dueAt'],
          stored.sources.single.lastUpdated + (overridden ? 180 : 60) * 60000,
        );
      },
    );
  }

  test(
    'disabling one source discards its staged result without a failure report',
    () async {
      await SubscriptionStore.save(profile('stale'));
      await SubscriptionBackgroundUpdates.configure([
        SubscriptionStore.getMetadata('stale')!,
      ]);
      final plan = plans.first;
      final p = (await SubscriptionStore.get('stale'))!;
      await SubscriptionStore.save(
        p.copyWith(
          sources: [
            p.effectiveSources.first.copyWith(enabled: false),
            ...p.effectiveSources.skip(1),
          ],
        ),
      );
      pending = [
        {'id': plan['id'], 'token': plan['token']},
      ];
      expect(await SubscriptionBackgroundUpdates.applyPending(), isEmpty);
      expect(acknowledged, [plan['id']]);
      expect(
        (await SubscriptionStore.get(
          'stale',
        ))!.effectiveSources.first.lastError,
        isNull,
      );
    },
  );

  test(
    'source edited while reading a staged payload is not marked failed',
    () async {
      await SubscriptionStore.save(profile('race'));
      await SubscriptionBackgroundUpdates.configure([
        SubscriptionStore.getMetadata('race')!,
      ]);
      final plan = plans.first;
      pending = [
        {'id': plan['id'], 'token': plan['token']},
      ];
      results[plan['id'] as String] = {
        'token': plan['token'],
        'time': 8000,
        'body': base64Encode(utf8.encode('invalid staged subscription')),
        'headers': <String, String>{},
      };
      beforeRead = () async {
        final current = (await SubscriptionStore.get('race'))!;
        final source = current.sources.first;
        await SubscriptionStore.save(
          current.copyWith(
            sources: [
              source.copyWith(
                snapshot: source.snapshot.copyWith(
                  url: 'https://edited.example.test/sub',
                ),
              ),
              ...current.sources.skip(1),
            ],
          ),
        );
      };
      expect(await SubscriptionBackgroundUpdates.applyPending(), isEmpty);
      expect(acknowledged, [plan['id']]);
      final current = (await SubscriptionStore.get('race'))!;
      expect(current.effectiveSources.first.lastError, isNull);
      expect(
        current.effectiveSources.first.url,
        'https://edited.example.test/sub',
      );
    },
  );
}
