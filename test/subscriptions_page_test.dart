import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/backup/etonify_backup_service.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/data/subscription/subscription_fetcher.dart';
import 'package:meow_client/features/subscriptions/subscriptions_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('subscriptions-page-');
    Hive.init(tempDir.path);
    await SubscriptionStore.init();
    SubscriptionFetcher.configureAppVersion('0.3.7');
  });

  setUp(() async {
    await SubscriptionStore.init();
    await SubscriptionStore.clear();
  });

  tearDownAll(() async {
    await SubscriptionStore.clear();
    await SubscriptionStore.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('profile snapshot waits for a queued full-profile save', () async {
    final original = _largeProfile();
    await SubscriptionStore.save(original);
    final saving = SubscriptionStore.save(
      original.copyWith(
        name: 'Changed profile',
        outbounds: const [
          Outbound(
            tag: 'changed',
            name: 'Changed server',
            config: {'type': 'vless'},
          ),
        ],
      ),
    );
    final snapshot = await SubscriptionStore.loadProfileSnapshotInBackground(
      original.id,
    );
    await saving;
    expect(snapshot?.name, 'Changed profile');
    expect(snapshot?.outbounds.single.tag, 'changed');
    expect(
      snapshot?.payloadRevision,
      SubscriptionStore.getMetadata(original.id)?.payloadRevision,
    );
  });

  test(
    'profile snapshot keeps current chain metadata when reusing cached servers',
    () async {
      await SubscriptionStore.save(_largeProfile());
      final cached = (await SubscriptionStore.loadProfileSnapshotInBackground(
        'large-profile',
      ))!;
      await SubscriptionStore.saveMetadata(
        SubscriptionStore.getMetadata(cached.id)!.copyWith(
          proxyChains: const [
            SubscriptionProxyChain(
              tag: 'chain',
              name: 'New chain',
              targetTag: 'server-299',
              detourTag: 'server-0',
            ),
          ],
        ),
      );
      final fresh = await SubscriptionStore.loadProfileSnapshotInBackground(
        cached.id,
        cachedPayload: cached,
      );
      expect(identical(fresh?.outbounds, cached.outbounds), isTrue);
      expect(fresh?.proxyChains.single.name, 'New chain');
    },
  );

  test('profile snapshot refreshes changed cached servers', () async {
    final original = _largeProfile();
    await SubscriptionStore.save(original);
    final cached = await SubscriptionStore.loadProfileSnapshotInBackground(
      original.id,
    );
    final saving = SubscriptionStore.save(
      original.copyWith(
        name: 'Changed profile',
        outbounds: const [
          Outbound(
            tag: 'changed',
            name: 'Changed server',
            config: {'type': 'vless'},
          ),
        ],
      ),
    );
    final snapshot = await SubscriptionStore.loadProfileSnapshotInBackground(
      original.id,
      cachedPayload: cached,
    );
    await saving;
    expect(snapshot?.name, 'Changed profile');
    expect(snapshot?.outbounds.single.tag, 'changed');
    expect(
      snapshot?.payloadRevision,
      SubscriptionStore.getMetadata(original.id)?.payloadRevision,
    );
  });

  test(
    'profile snapshot rejects a missing payload even when its count is unknown',
    () async {
      await SubscriptionStore.save(_largeProfile());
      final metadata = SubscriptionStore.getMetadata('large-profile')!;
      await SubscriptionStore.saveMetadata(
        metadata.copyWith(cachedVisibleProxyCount: -1),
      );
      await Hive.lazyBox<dynamic>(
        'subscription_payloads_secure_v1',
      ).delete(metadata.id);
      await expectLater(
        SubscriptionStore.loadProfileSnapshotInBackground(metadata.id),
        throwsStateError,
      );
    },
  );

  for (final damaged in [
    'not JSON',
    '{}',
    '{"outbounds":[false]}',
    '{"padding":"${'x' * 40000}"}',
  ]) {
    test(
      'profile snapshot rejects corrupt payload (${damaged.length} bytes)',
      () async {
        await SubscriptionStore.save(_largeProfile());
        await Hive.lazyBox<dynamic>(
          'subscription_payloads_secure_v1',
        ).put('large-profile', damaged);
        await expectLater(
          SubscriptionStore.loadProfileSnapshotInBackground('large-profile'),
          throwsA(anything),
        );
        expect(
          SubscriptionStore.getMetadata(
            'large-profile',
          )?.cachedVisibleProxyCount,
          300,
        );
      },
    );
  }

  test(
    'metadata edits do not overwrite a refreshed profile with a stale screen snapshot',
    () async {
      final original = _largeProfile();
      await SubscriptionStore.save(original);
      final refreshing = SubscriptionStore.save(
        original.copyWith(
          lastUpdated: 123456,
          info: const SubscriptionInfo(
            download: 789,
            supportUrl: 'https://example.com/new-support',
          ),
          outbounds: const [
            Outbound(
              tag: 'updated',
              name: 'Updated server',
              config: {'type': 'vless'},
            ),
          ],
        ),
      );
      // The details screen still holds `original` when the refresh completes.
      await refreshing;
      await SubscriptionStore.updateMetadata(
        original.id,
        (current) => current.copyWith(
          name: 'Edited name',
          info: SubscriptionInfo.fromMap({
            ...?current.info?.toMap(),
            'custom_user_agent': 'Custom UA',
          }),
        ),
      );
      final snapshot = await SubscriptionStore.loadProfileSnapshotInBackground(
        original.id,
      );
      expect(snapshot?.name, 'Edited name');
      expect(snapshot?.lastUpdated, 123456);
      expect(snapshot?.info?.download, 789);
      expect(snapshot?.info?.supportUrl, 'https://example.com/new-support');
      expect(snapshot?.info?.customUserAgent, 'Custom UA');
      expect(snapshot?.outbounds.single.tag, 'updated');
      expect(
        snapshot?.payloadRevision,
        SubscriptionStore.getMetadata(original.id)?.payloadRevision,
      );
    },
  );

  test('metadata edits never resurrect a deleted profile', () async {
    await SubscriptionStore.save(_largeProfile());
    await SubscriptionStore.delete('large-profile');
    await SubscriptionStore.updateMetadata(
      'large-profile',
      (current) => current.copyWith(name: 'Deleted'),
    );
    expect(SubscriptionStore.getMetadata('large-profile'), isNull);
  });

  for (final strategy in ['urltest', 'leastping']) {
    _testSubscriptionWidgets(
      '$strategy candidates are nested and remain shareable',
      (tester) async {
        final profile = _largeProfile();
        await tester.runAsync(
          () => SubscriptionStore.save(
            profile.copyWith(
              groups: [profile.groups.single.copyWith(type: strategy)],
            ),
          ),
        );
        await _openDetails(tester, 'large-profile', 'Large profile');
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('subscription_details_proxies')),
          180,
          scrollable: _detailsScrollable(),
        );
        await _pumpUntilFound(tester, find.text('Automatic group'));
        expect(find.text('Server 0'), findsNothing);
        await tester.tap(find.text('Automatic group'));
        await _pumpUi(tester);
        expect(find.text('Server 0'), findsOneWidget);
        expect(find.text('Server 299'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('subscription_share_group')),
          findsOneWidget,
        );
        await tester.tap(find.text('Server 299'));
        await _pumpUi(tester);
        expect(find.text('Share link'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  _testSubscriptionWidgets(
    'a server chain shares its complete JSON instead of a lossy link',
    (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final profile = _largeProfile();
      await tester.runAsync(
        () => SubscriptionStore.save(
          profile.copyWith(
            groups: const [],
            outbounds: [
              profile.outbounds[0].copyWith(
                config: {...profile.outbounds[0].config, 'detour': 'server-1'},
              ),
              profile.outbounds[1].copyWith(
                config: {...profile.outbounds[1].config, '_group_only': true},
              ),
            ],
          ),
        ),
      );
      await _openDetails(tester, 'large-profile', 'Large profile');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('subscription_details_proxies')),
        180,
        scrollable: _detailsScrollable(),
      );
      await _pumpUntilFound(tester, find.text('Server 0'));
      await tester.tap(find.text('Server 0'));
      await _pumpUi(tester);
      final link = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Share link'),
          matching: find.byType(ListTile),
        ),
      );
      expect(link.enabled, isFalse);
      await tester.tap(find.text('sing-box outbound'));
      await _pumpUi(tester);
      expect(clipboardText, isNotNull);
      final copied = jsonDecode(clipboardText!) as Map;
      final nodes = (copied['outbounds'] as List).cast<Map<String, dynamic>>();
      expect(nodes.map((node) => node['tag']), ['server-0', 'server-1']);
      expect(nodes.first['detour'], nodes.last['tag']);
      expect(
        nodes.any((node) => node.keys.any((key) => key.startsWith('_'))),
        isFalse,
      );
    },
  );

  _testSubscriptionWidgets('profile actions use equal widths and heights', (
    tester,
  ) async {
    await tester.runAsync(() => SubscriptionStore.save(_largeProfile()));
    await _openDetails(tester, 'large-profile', 'Large profile');
    final refresh = find.widgetWithText(FilledButton, 'Refresh');
    final export = find.byKey(const ValueKey('subscription_export_json'));
    expect(tester.getSize(refresh), tester.getSize(export));
    final copy = find.widgetWithText(OutlinedButton, 'Copy');
    final qr = find.widgetWithText(OutlinedButton, 'Show QR');
    expect(copy, findsOneWidget);
    expect(qr, findsOneWidget);
    expect(tester.getSize(copy), tester.getSize(qr));
    expect(tester.takeException(), isNull);
  });

  _testSubscriptionWidgets(
    'custom refresh interval validates input and persists two days',
    (tester) async {
      await tester.runAsync(() => SubscriptionStore.save(_largeProfile()));
      await _openDetails(tester, 'large-profile', 'Large profile');
      await tester.scrollUntilVisible(
        find.text('Refresh interval'),
        180,
        scrollable: _detailsScrollable(),
      );
      await tester.tap(find.text('Refresh interval'));
      await _pumpUi(tester);
      await tester.tap(find.text('Custom interval'));
      await _pumpUi(tester);
      final input = find.byKey(const ValueKey('subscription_interval_value'));
      await tester.enterText(input, '0');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(input, findsOneWidget);
      await tester.enterText(input, '2');
      await tester.tap(find.text('Days'));
      await tester.pump();
      await tester.enterText(input, '366');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(input, findsOneWidget);
      await tester.enterText(input, '2');
      await tester.tap(find.text('Save'));
      await _pumpUntilFound(tester, find.text('Refreshes every: 2 d'));
      expect(
        SubscriptionStore.getMetadata('large-profile')?.autoRefreshMinutes,
        2880,
      );
      expect(
        SubscriptionStore.getMetadata(
          'large-profile',
        )?.toMetadataMap()['auto_refresh_overridden'],
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );

  _testSubscriptionWidgets(
    'group-only candidates count as servers and keep the full list accessible',
    (tester) async {
      await tester.runAsync(
        () => SubscriptionStore.save(
          _largeProfile().copyWith(
            outbounds: const [
              Outbound(
                tag: 'internal',
                name: 'cand-01',
                config: {'type': 'vless', '_group_only': true},
              ),
            ],
            groups: const [
              SubscriptionGroup(
                tag: 'auto',
                name: 'Automatic group',
                outboundTags: ['internal'],
              ),
            ],
          ),
        ),
      );
      await _openDetails(tester, 'large-profile', 'Large profile');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('subscription_details_proxies')),
        180,
        scrollable: _detailsScrollable(),
      );
      await _pumpUntilFound(tester, find.text('Automatic group'));
      expect(find.text('1 proxies'), findsWidgets);
      expect(
        find.byKey(const ValueKey('subscription_all_servers')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  _testSubscriptionWidgets(
    'details hydrate servers instead of showing a metadata-only zero',
    (tester) async {
      await tester.runAsync(() => SubscriptionStore.save(_largeProfile()));
      await _openDetails(tester, 'large-profile', 'Large profile');
      await _showServerPreview(tester);
      await _pumpUntilFound(tester, find.text('Server 1'));
      expect(find.text('300 proxies'), findsWidgets);
      expect(find.text('0 proxies'), findsNothing);
      expect(find.text('Server 299'), findsNothing);
      expect(find.text('...'), findsNothing);
      expect(find.text('Custom User-Agent'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  _testSubscriptionWidgets(
    'advanced settings retain their height during the closing animation',
    (tester) async {
      await tester.runAsync(() => SubscriptionStore.save(_largeProfile()));
      await _openDetails(tester, 'large-profile', 'Large profile');
      final tile = find.byType(ExpansionTile);
      await tester.scrollUntilVisible(
        tile,
        180,
        scrollable: _detailsScrollable(),
      );
      final closedHeight = tester.getSize(tile).height;
      await tester.tap(find.text('Advanced settings'));
      await _pumpUi(tester);
      expect(tester.getSize(tile).height, greaterThan(closedHeight));
      await tester.ensureVisible(find.text('Advanced settings'));
      await tester.pump();
      await tester.tap(find.text('Advanced settings'));
      await tester.pump();
      expect(tester.getSize(tile).height, greaterThan(closedHeight));
      await _pumpUi(tester);
      expect(tester.getSize(tile).height, closeTo(closedHeight, .1));
      expect(tester.takeException(), isNull);
    },
  );

  _testSubscriptionWidgets(
    'subscription actions remain reachable on a narrow Russian large-text screen',
    (tester) async {
      await tester.runAsync(() => SubscriptionStore.save(_largeProfile()));
      await _openSheet(
        tester,
        activeSubscriptionId: 'large-profile',
        locale: const Locale('ru'),
        textScale: 1.6,
      );
      await _pumpUntilFound(tester, find.text('Large profile'));
      await tester.binding.setSurfaceSize(const Size(320, 860));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pump();
      await tester.tap(find.text('Подписка'));
      await _pumpUi(tester);
      expect(tester.takeException(), isNull);
      final export = find.byKey(const ValueKey('subscription_export_json'));
      await tester.ensureVisible(export);
      await tester.pump();
      expect(export.hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Показать QR'),
        150,
        scrollable: _detailsScrollable(),
      );
      expect(find.text('Показать QR').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  _testSubscriptionWidgets(
    'all servers are lazy, searchable and open sharing on a row tap',
    (tester) async {
      await tester.runAsync(() => SubscriptionStore.save(_largeProfile()));
      await _openDetails(tester, 'large-profile', 'Large profile');
      await _showServerPreview(tester);
      await _pumpUntilFound(tester, find.text('Server 1'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('subscription_all_servers')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(
                const PageStorageKey('subscription_details_scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('subscription_all_servers')));
      await _pumpUi(tester);
      expect(find.text('Server 299'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('subscription_server_search')),
        'Server 298',
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('server-298')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('server-298')));
      await _pumpUi(tester);
      expect(find.text('Share link'), findsOneWidget);
      expect(find.text('sing-box outbound'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  _testSubscriptionWidgets(
    'one profile JSON export imports from the ordinary file picker',
    (tester) async {
      final previousPicker = FilePickerPlatform.instance;
      final picker = _ProfileFilePicker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = previousPicker);
      await tester.runAsync(() async {
        await SubscriptionStore.save(_largeProfile());
        await SubscriptionStore.save(
          const Subscription(
            id: 'unrelated',
            name: 'Unrelated',
            url: 'https://example.com/unrelated',
          ),
        );
      });
      await _openDetails(tester, 'large-profile', 'Large profile');
      await tester.tap(find.byKey(const ValueKey('subscription_export_json')));
      await _pumpUi(tester);
      expect(find.text('The file will contain VPN keys'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await _pumpUntilFound(tester, find.text('Backup file saved'));
      expect(picker.savedBytes, isNotNull);
      expect(picker.savedName, endsWith('.json'));
      final decoded = const EtonifyBackupService().parseProfileExport(
        bytes: picker.savedBytes!,
        currentClientVersion: '0.3.7',
      );
      expect(decoded.subscriptions, hasLength(1));
      expect(decoded.subscriptions.single.name, 'Large profile');
      expect(decoded.subscriptions.single.outbounds, hasLength(301));
      expect(decoded.subscriptions.single.selectedProxyTag, 'server-299');
      expect(decoded.subscriptions.single.groups.single.urlTestConfig.toMap(), {
        'url': 'https://example.com/check',
        'interval': 60,
        'timeout': 5,
        'concurrency': 2,
      });
      await tester.pumpWidget(const SizedBox.shrink());
      var cleared = false;
      final clearing = SubscriptionStore.clear().then((_) => cleared = true);
      for (var i = 0; i < 100 && !cleared; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(cleared, isTrue);
      await clearing;
      picker.picked = _MemoryProfileFile(picker.savedBytes!);
      await _openSheet(tester, openAddOnStart: true);
      await tester.tap(find.text('From file'));
      await _pumpUntilFound(tester, find.text('Plain profile file'));
      await tester.tap(find.text('Continue'));
      await _pumpUntilFound(tester, find.text('Import completed'));
      expect(find.text('Import completed'), findsOneWidget);
      var readFinished = false;
      Subscription? restored;
      final reading =
          SubscriptionStore.loadProfileSnapshotInBackground(
            'large-profile',
          ).then((value) {
            restored = value;
            readFinished = true;
          });
      for (var i = 0; i < 100 && !readFinished; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(readFinished, isTrue);
      await reading;
      expect(restored?.outbounds, hasLength(301));
      expect(restored?.groups.single.outboundTags, ['server-0', 'server-299']);
      expect(restored?.selectedProxyTag, 'server-299');
      expect(SubscriptionStore.getMetadata('unrelated'), isNull);
      await _pumpUi(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  _testSubscriptionWidgets(
    'HWID toggle preserves request fields changed after opening details',
    (tester) async {
      final sharingBefore = SubscriptionFetcher.sendHwidToProviders;
      SubscriptionFetcher.configureHwidSharing(false);
      addTearDown(
        () => SubscriptionFetcher.configureHwidSharing(sharingBefore),
      );
      await tester.runAsync(() => SubscriptionStore.save(_largeProfile()));
      await _openDetails(tester, 'large-profile', 'Large profile');
      await _showServerPreview(tester);
      var updated = false;
      final updating = SubscriptionStore.updateMetadata(
        'large-profile',
        (current) => current.copyWith(
          info: const SubscriptionInfo(
            customUserAgent: 'Fresh UA',
            customRequestHeader: 'Authorization: fresh',
            customHwid: 'fresh-hwid',
          ),
        ),
      ).then((_) => updated = true);
      for (var i = 0; i < 100 && !updated; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(updated, isTrue);
      await updating;
      await tester.scrollUntilVisible(
        find.byType(ExpansionTile),
        150,
        scrollable: find
            .descendant(
              of: find.byKey(
                const PageStorageKey('subscription_details_scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byType(ExpansionTile));
      await _pumpUi(tester);
      final toggle = find
          .descendant(
            of: find.byType(ExpansionTile),
            matching: find.byType(SwitchListTile),
          )
          .first;
      await tester.ensureVisible(toggle);
      await tester.pump();
      await tester.tap(toggle);
      for (
        var i = 0;
        i < 100 &&
            SubscriptionStore.getMetadata('large-profile')?.info?.requireHwid !=
                true;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      final info = SubscriptionStore.getMetadata('large-profile')?.info;
      expect(info?.requireHwid, isTrue);
      expect(info?.customUserAgent, 'Fresh UA');
      expect(info?.customRequestHeader, 'Authorization: fresh');
      expect(info?.customHwid, 'fresh-hwid');
      expect(tester.takeException(), isNull);
    },
  );

  _testSubscriptionWidgets(
    'add profile morphs in one sheet and keeps its header pinned',
    (tester) async {
      await _openSheet(tester, openAddOnStart: true);

      expect(find.text('Add profile'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey('subscriptions_sheet_clip')),
        findsOneWidget,
      );
      final quickSheetTop = tester
          .getTopLeft(find.byKey(const ValueKey('subscriptions_sheet_clip')))
          .dy;
      final quickContentTop = tester.getTopLeft(find.text('Manual')).dy;

      await tester.drag(find.text('Manual'), const Offset(0, -320));
      await _pumpUi(tester, const Duration(milliseconds: 320));

      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('subscriptions_sheet_clip')))
            .dy,
        closeTo(quickSheetTop, .1),
      );
      expect(tester.getTopLeft(find.text('Manual')).dy, quickContentTop);

      await tester.tap(find.text('Manual'));
      await _pumpUi(tester, const Duration(milliseconds: 420));

      expect(find.text('URL or content'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      final manualHeader = find.text('Manual').hitTestable();
      final headerTop = tester.getTopLeft(manualHeader).dy;

      await tester.dragFrom(const Offset(210, 700), const Offset(0, -260));
      await _pumpUi(tester, const Duration(milliseconds: 80));

      expect(tester.getTopLeft(manualHeader).dy, headerTop);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await _pumpUi(tester, const Duration(milliseconds: 420));
      expect(find.text('Add profile'), findsOneWidget);

      await tester.drag(find.text('Add profile'), const Offset(0, 420));
      await _pumpUi(tester, const Duration(milliseconds: 400));
      expect(find.text('Add profile'), findsNothing);
    },
  );

  _testSubscriptionWidgets('one subscription keeps the compact sheet extent', (
    tester,
  ) async {
    await tester.runAsync(
      () => SubscriptionStore.save(
        Subscription(
          id: 'only-subscription',
          name: 'Only profile',
          url: 'https://example.com/only',
          lastUpdated: DateTime(2026, 8, 27).millisecondsSinceEpoch,
          outbounds: const [
            Outbound(
              tag: 'only-proxy',
              name: 'Only proxy',
              config: {'type': 'vless'},
            ),
          ],
          cachedVisibleProxyCount: 1,
        ),
      ),
    );
    await _openSheet(tester, activeSubscriptionId: 'only-subscription');
    await _pumpUntilFound(tester, find.text('Only profile'));
    await _pumpUi(tester);

    final sheet = find.byKey(const ValueKey('subscriptions_sheet_clip'));
    final initialTop = tester.getTopLeft(sheet).dy;

    await tester.drag(find.text('Subscriptions'), const Offset(0, -420));
    await _pumpUi(tester);

    expect(tester.getTopLeft(sheet).dy, closeTo(initialTop, .1));
  });

  _testSubscriptionWidgets(
    'subscriptions grow to content before enabling list scrolling',
    (tester) async {
      await tester.runAsync(() async {
        for (var index = 0; index < 3; index++) {
          await SubscriptionStore.save(
            Subscription(
              id: 'compact-$index',
              name: 'Compact profile $index',
              url: 'https://example.com/compact-$index',
              lastUpdated: DateTime(2026, 8, 27).millisecondsSinceEpoch,
              outbounds: [
                Outbound(
                  tag: 'compact-proxy-$index',
                  name: 'Compact proxy $index',
                  config: const {'type': 'vless'},
                ),
              ],
              cachedVisibleProxyCount: 1,
            ),
          );
        }
      });
      await _openSheet(tester, activeSubscriptionId: 'compact-0');
      await _pumpUntilFound(tester, find.text('Compact profile 2'));
      await _pumpUi(tester);

      final sheet = find.byKey(const ValueKey('subscriptions_sheet_clip'));
      final sheetTop = tester.getTopLeft(sheet).dy;
      final firstCardTop = tester.getTopLeft(find.text('Compact profile 0')).dy;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await _pumpUi(tester);

      expect(tester.getTopLeft(sheet).dy, closeTo(sheetTop, .1));
      expect(
        tester.getTopLeft(find.text('Compact profile 0')).dy,
        closeTo(firstCardTop, .1),
      );
    },
  );

  _testSubscriptionWidgets(
    'subscriptions keep a pinned header and use an inline sort menu',
    (tester) async {
      await tester.runAsync(() async {
        for (var index = 0; index < 8; index++) {
          await SubscriptionStore.save(
            Subscription(
              id: 'sub-$index',
              name: index == 0 ? 'FurkVPN' : 'Profile $index',
              url: 'https://example.com/$index',
              lastUpdated: DateTime(
                2026,
                6,
                28,
                12,
                index,
              ).millisecondsSinceEpoch,
              outbounds: [
                Outbound(
                  tag: 'proxy-$index-a',
                  name: 'Proxy A',
                  config: const {'type': 'vless'},
                ),
                Outbound(
                  tag: 'proxy-$index-b',
                  name: 'Proxy B',
                  config: const {'type': 'vless'},
                ),
              ],
              cachedVisibleProxyCount: 2,
              hasRawPayload: true,
              rawContent: 'vless://payload-$index',
            ),
          );
        }
      });
      await _openSheet(tester, activeSubscriptionId: 'sub-0');
      await _pumpUntilFound(tester, find.textContaining('2 proxies'));

      expect(find.text('Current profile'), findsNothing);
      expect(find.textContaining('2 proxies'), findsWidgets);
      expect(
        find.textContaining('Updated June 28, 2026 at 12:00:00'),
        findsOneWidget,
      );
      expect(find.textContaining('Working:'), findsNothing);
      await tester.drag(find.text('Subscriptions'), const Offset(0, -520));
      await _pumpUi(tester, const Duration(milliseconds: 420));
      final headerTop = tester.getTopLeft(find.text('Subscriptions')).dy;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -560));
      await _pumpUi(tester, const Duration(milliseconds: 80));
      expect(tester.getTopLeft(find.text('Subscriptions')).dy, headerTop);
      expect(find.text('FurkVPN'), findsNothing);
      expect(find.text('Profile 7'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.sort_rounded));
      await tester.pump();
      expect(find.text('By name'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.byIcon(Icons.sort_rounded));
      await _pumpUi(tester, const Duration(milliseconds: 250));
      await tester.tap(find.byIcon(Icons.add_rounded).hitTestable());
      await _pumpUi(tester, const Duration(milliseconds: 420));
      expect(find.text('Add profile'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    },
  );

  _testSubscriptionWidgets(
    'shows the complete localized Russian refresh date',
    (tester) async {
      await tester.runAsync(
        () => SubscriptionStore.save(
          Subscription(
            id: 'dated-subscription',
            name: 'Профиль',
            url: 'https://example.com/sub',
            lastUpdated: DateTime(2026, 8, 20, 17, 49).millisecondsSinceEpoch,
            outbounds: const [
              Outbound(
                tag: 'proxy-one',
                name: 'Прокси',
                config: {'type': 'vless'},
              ),
            ],
            cachedVisibleProxyCount: 1,
            hasRawPayload: true,
            rawContent: 'vless://payload',
          ),
        ),
      );

      await _openSheet(
        tester,
        activeSubscriptionId: 'dated-subscription',
        locale: const Locale('ru'),
      );
      await _pumpUntilFound(tester, find.textContaining('1 прокси'));

      expect(
        find.textContaining('Обновлено 20 августа 2026 года в 17:49:00'),
        findsOneWidget,
      );
      expect(find.textContaining('Работают:'), findsNothing);
    },
  );

  _testSubscriptionWidgets(
    'subscription card keeps profile details on separate lines',
    (tester) async {
      const subscriptionId = 'profile-summary';
      await tester.runAsync(
        () => SubscriptionStore.save(
          Subscription(
            id: subscriptionId,
            name: 'A very long subscription profile name for compact layout',
            url: 'https://example.com/summary',
            lastUpdated: DateTime(2026, 8, 30, 18, 45).millisecondsSinceEpoch,
            info: SubscriptionInfo(
              upload: 1024 * 1024,
              download: 2 * 1024 * 1024,
              total: 10 * 1024 * 1024,
              expire:
                  DateTime.now()
                      .add(const Duration(days: 10))
                      .millisecondsSinceEpoch ~/
                  1000,
            ),
            outbounds: const [
              Outbound(
                tag: 'summary-proxy',
                name: 'Summary proxy',
                config: {'type': 'vless'},
              ),
            ],
            cachedVisibleProxyCount: 1,
          ),
        ),
      );

      await _openSheet(tester, activeSubscriptionId: subscriptionId);
      final name = find.byKey(
        const ValueKey('subscription_name_profile-summary'),
      );
      final remaining = find.byKey(
        const ValueKey('subscription_remaining_profile-summary'),
      );
      final summary = find.byKey(
        const ValueKey('subscription_summary_profile-summary'),
      );
      final updated = find.byKey(
        const ValueKey('subscription_updated_profile-summary'),
      );
      await _pumpUntilFound(tester, updated);

      final nameText = tester.widget<Text>(name);
      final summaryText = tester.widget<Text>(summary).data!;
      expect(nameText.maxLines, 1);
      expect(nameText.overflow, TextOverflow.ellipsis);
      expect(nameText.style?.fontSize, lessThan(20));
      expect(
        tester.getTopLeft(name).dy,
        lessThan(tester.getTopLeft(remaining).dy),
      );
      expect(
        tester.getTopLeft(remaining).dy,
        lessThan(tester.getTopLeft(summary).dy),
      );
      expect(
        tester.getTopLeft(summary).dy,
        lessThan(tester.getTopLeft(updated).dy),
      );
      expect(summaryText, contains('1'));
      expect(summaryText, contains('MB'));
      expect(find.textContaining('Updated August 30, 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  _testSubscriptionWidgets(
    'share menu exposes URL actions without raw JSON export',
    (tester) async {
      await tester.runAsync(
        () => SubscriptionStore.save(
          Subscription(
            id: 'share-subscription',
            name: 'Share profile',
            url: 'https://example.com/subscription',
            lastUpdated: DateTime(2026, 8, 27).millisecondsSinceEpoch,
            outbounds: const [
              Outbound(
                tag: 'share-proxy',
                name: 'Share proxy',
                config: {'type': 'vless'},
              ),
            ],
            cachedVisibleProxyCount: 1,
            hasRawPayload: true,
            rawContent: 'vless://payload',
          ),
        ),
      );

      await _openSheet(tester, activeSubscriptionId: 'share-subscription');
      await _pumpUntilFound(tester, find.text('Share profile'));
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pump();
      await tester.tap(find.text('Share'));
      await _pumpUi(tester, const Duration(milliseconds: 250));

      expect(find.text('URL to clipboard'), findsOneWidget);
      expect(find.text('Show URL QR code'), findsOneWidget);
      expect(find.text('JSON to clipboard'), findsNothing);
    },
  );

  test('URL metadata repair preserves the subscription payload', () async {
    const subscriptionId = 'legacy-url-metadata';
    await SubscriptionStore.save(
      const Subscription(
        id: subscriptionId,
        name: 'Legacy profile',
        url:
            'https://example.com/source-one\n'
            'https://example.com/source-two',
        lastUpdated: 123,
        rawContent: 'vless://payload',
        outbounds: [
          Outbound(
            tag: 'proxy-one',
            name: 'Proxy one',
            config: {'type': 'vless'},
          ),
        ],
      ),
    );

    final subscription = (await SubscriptionStore.get(subscriptionId))!;
    await SubscriptionStore.saveMetadata(
      subscription.copyWith(url: 'https://example.com/working', lastUpdated: 0),
    );

    final updated = await SubscriptionStore.get(subscriptionId);
    expect(updated?.url, 'https://example.com/working');
    expect(updated?.lastUpdated, 0);
    expect(updated?.rawContent, 'vless://payload');
    expect(updated?.outbounds.single.tag, 'proxy-one');
  });

  _testSubscriptionWidgets(
    'subscription settings hide the forced Russia location override',
    (tester) async {
      const subscriptionId = 'location-settings';
      await tester.runAsync(
        () => SubscriptionStore.save(
          const Subscription(
            id: subscriptionId,
            name: 'Location settings profile',
            url: 'https://example.com/location-settings',
            cachedVisibleProxyCount: 0,
          ),
        ),
      );

      await _openSheet(tester, activeSubscriptionId: subscriptionId);
      await _pumpUntilFound(tester, find.text('Location settings profile'));
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pump();
      await tester.tap(find.text('Subscription'));
      await _pumpUi(tester);

      expect(
        find.byKey(const ValueKey('edit_subscription_url_button')),
        findsOneWidget,
      );
      expect(find.text('Локация'), findsNothing);
      expect(find.text('Пометить все сервера как Россию'), findsNothing);
    },
  );

  _testSubscriptionWidgets(
    'the URL editor rejects a merged legacy source list',
    (tester) async {
      const subscriptionId = 'legacy-merged-url';
      await tester.runAsync(
        () => SubscriptionStore.save(
          const Subscription(
            id: subscriptionId,
            name: 'Legacy profile',
            url:
                'https://example.com/source-one\n'
                'https://example.com/source-two',
            lastUpdated: 123,
            cachedVisibleProxyCount: 0,
          ),
        ),
      );
      await _openSheet(tester, activeSubscriptionId: subscriptionId);
      await _pumpUntilFound(tester, find.text('Legacy profile'));
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pump();
      await tester.tap(find.text('Subscription'));
      await _pumpUi(tester);
      await tester.tap(
        find.byKey(const ValueKey('edit_subscription_url_button')),
      );
      await _pumpUi(tester, const Duration(milliseconds: 200));
      final editor = find.byKey(const ValueKey('subscription_url_editor'));
      expect(editor, findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(
        find.text('Keep one URL. Add the other sources as separate profiles.'),
        findsOneWidget,
      );

      await tester.enterText(editor, '  https://example.com/working  \n');
      await tester.pump();
      expect(
        find.text('Keep one URL. Add the other sources as separate profiles.'),
        findsNothing,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

Subscription _largeProfile() => Subscription(
  id: 'large-profile',
  name: 'Large profile',
  url: 'https://example.com/large',
  selectedProxyTag: 'server-299',
  cachedVisibleProxyCount: 300,
  hasRawPayload: true,
  rawContent: 'vless://original-profile',
  outbounds: [
    for (var i = 0; i < 300; i++)
      Outbound(
        tag: 'server-$i',
        name: 'Server $i',
        config: {
          'type': 'vless',
          'server': 'example.com',
          'server_port': 443,
          'uuid': '11111111-1111-1111-1111-111111111111',
        },
      ),
    const Outbound(
      tag: 'hidden',
      name: 'Hidden child',
      config: {'type': 'vless', '_group_only': true},
    ),
  ],
  groups: const [
    SubscriptionGroup(
      tag: 'auto',
      name: 'Automatic group',
      type: 'urltest',
      outboundTags: ['server-0', 'server-299'],
      urlTestConfig: UrlTestConfig(
        url: 'https://example.com/check',
        intervalSeconds: 60,
        timeoutSeconds: 5,
        concurrency: 2,
      ),
    ),
  ],
);

Future<void> _openDetails(WidgetTester tester, String id, String name) async {
  await _openSheet(tester, activeSubscriptionId: id);
  await _pumpUntilFound(tester, find.text(name));
  await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
  await tester.pump();
  await tester.tap(find.text('Subscription'));
  await _pumpUi(tester);
}

class _ProfileFilePicker extends FilePickerPlatform {
  Uint8List? savedBytes;
  String? savedName;
  PlatformFile? picked;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    savedBytes = bytes;
    savedName = fileName;
    return Uri.parse('file:///saved-profile.json');
  }

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => picked;
}

base class _MemoryProfileFile extends PlatformFile {
  _MemoryProfileFile(this.bytes);
  final Uint8List bytes;
  @override
  String get name => 'profile.json';
  @override
  Uri get uri => Uri.parse('memory:///profile.json');
  @override
  Never get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => bytes.length;
  @override
  Future<int?> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

void _testSubscriptionWidgets(
  String description,
  WidgetTesterCallback callback,
) {
  testWidgets(description, (tester) async {
    try {
      await callback(tester);
    } finally {
      await _finishWidgetStore(tester);
    }
  });
}

Future<void> _finishWidgetStore(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  var finished = false;
  // Hive's read/write synchronization futures inherit the fake-clock zone
  // which performed the UI read. Close them while that zone can still pump,
  // rather than awaiting their callbacks from the next test's real-clock setup.
  final closing = SubscriptionStore.close().then((_) => finished = true);
  for (var i = 0; i < 100 && !finished; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(
    finished,
    isTrue,
    reason:
        'Hive callbacks must complete before leaving the fake-clock widget test',
  );
  await closing;
}

Future<void> _showServerPreview(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('subscription_details_proxies')),
    180,
    scrollable: find
        .descendant(
          of: find.byKey(const PageStorageKey('subscription_details_scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await _pumpUntilFound(tester, find.text('Server 1'));
  expect(find.text('Server 1'), findsOneWidget);
}

Finder _detailsScrollable() => find
    .descendant(
      of: find.byKey(const PageStorageKey('subscription_details_scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _openSheet(
  WidgetTester tester, {
  bool openAddOnStart = false,
  String? activeSubscriptionId,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 860));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showModalBottomSheet<Object?>(
                context: context,
                isScrollControlled: true,
                enableDrag: false,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (context) => SubscriptionsPage(
                  activeSubscriptionId: activeSubscriptionId,
                  openAddOnStart: openAddOnStart,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await _pumpUi(tester, const Duration(milliseconds: 500));
}

Future<void> _pumpUi(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 400),
]) async {
  const frame = Duration(milliseconds: 50);
  final frameCount = (duration.inMilliseconds / frame.inMilliseconds).ceil();
  for (var index = 0; index < frameCount; index++) {
    await tester.pump(frame);
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final stopwatch = Stopwatch()..start();
  while (finder.evaluate().isEmpty && stopwatch.elapsed < timeout) {
    // Background subscription decoding runs in a real isolate, while widget
    // test frame durations use the fake clock. Give the worker a short real
    // scheduling window before pumping the result into the widget tree.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}
