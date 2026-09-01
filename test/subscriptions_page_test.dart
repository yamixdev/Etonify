import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
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
  });

  setUp(() async {
    await SubscriptionStore.clear();
  });

  tearDownAll(() async {
    await SubscriptionStore.clear();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('add profile morphs in one sheet and keeps its header pinned', (
    tester,
  ) async {
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
  });

  testWidgets('one subscription keeps the compact sheet extent', (
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

  testWidgets('subscriptions grow to content before enabling list scrolling', (
    tester,
  ) async {
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
  });

  testWidgets(
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

  testWidgets('shows the complete localized Russian refresh date', (
    tester,
  ) async {
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
  });

  testWidgets('subscription card keeps profile details on separate lines', (
    tester,
  ) async {
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
  });

  testWidgets('share menu exposes URL actions without raw JSON export', (
    tester,
  ) async {
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
  });

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

    final subscription = SubscriptionStore.get(subscriptionId)!;
    await SubscriptionStore.saveMetadata(
      subscription.copyWith(url: 'https://example.com/working', lastUpdated: 0),
    );

    final updated = SubscriptionStore.get(subscriptionId);
    expect(updated?.url, 'https://example.com/working');
    expect(updated?.lastUpdated, 0);
    expect(updated?.rawContent, 'vless://payload');
    expect(updated?.outbounds.single.tag, 'proxy-one');
  });

  testWidgets('the URL editor rejects a merged legacy source list', (
    tester,
  ) async {
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
  });
}

Future<void> _openSheet(
  WidgetTester tester, {
  bool openAddOnStart = false,
  String? activeSubscriptionId,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 860));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
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
