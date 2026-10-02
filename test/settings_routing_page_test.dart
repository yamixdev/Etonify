import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/features/settings/settings_routing_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'large text and keyboard keep controls reachable without overflow',
    (tester) async {
      await _pumpPage(
        tester,
        const RussiaRouteDataStatus.unavailable(),
        textScale: 1.6,
        keyboardInset: 300,
        installedApps: [
          {'packageName': 'com.example.app', 'label': 'Example'},
        ],
        scrollTo: 'Раздельная маршрутизация',
      );
      await tester.tap(find.text('Раздельная маршрутизация'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Example'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('split-routing-app-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Example'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('split-routing-apply')), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets('app lists remain independent drafts until Apply', (
    tester,
  ) async {
    var applies = 0;
    final controller = await _pumpPage(
      tester,
      const RussiaRouteDataStatus.unavailable(),
      installedApps: [
        {'packageName': 'org.telegram.messenger', 'label': 'Telegram'},
        {'packageName': 'com.example.mail', 'label': 'Mail'},
      ],
      scrollTo: 'Раздельная маршрутизация',
      onSplitRoutingPackagesChanged: (_) => applies++,
    );
    await tester.tap(find.text('Раздельная маршрутизация'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.tap(
      find.byKey(const ValueKey('split-app-org.telegram.messenger')),
    );
    await tester.tap(find.text('Вне VPN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-app-com.example.mail')));
    await tester.tap(find.text('Через VPN'));
    await tester.pumpAndSettle();
    expect(applies, 0);
    expect(controller.splitRoutingMode, SplitRoutingMode.disabled);
    final telegram = find.descendant(
      of: find.byKey(const ValueKey('split-app-org.telegram.messenger')),
      matching: find.byType(Checkbox),
    );
    expect(tester.widget<Checkbox>(telegram).value, isTrue);
    await tester.tap(find.byKey(const ValueKey('split-routing-apply')));
    await tester.pumpAndSettle();
    expect(applies, 1);
    expect(controller.splitRoutingIncludedPackages, ['org.telegram.messenger']);
    expect(controller.splitRoutingExcludedPackages, ['com.example.mail']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'empty cache still loads apps when old selected package is missing',
    (tester) async {
      await _pumpPage(
        tester,
        const RussiaRouteDataStatus.unavailable(),
        splitRoutingMode: SplitRoutingMode.proxySelected,
        splitRoutingPackages: ['com.old.removed'],
        preloadApps: [
          {'packageName': 'com.google.android.youtube', 'label': 'YouTube'},
        ],
        scrollTo: 'Раздельная маршрутизация',
      );
      await tester.tap(find.text('Раздельная маршрутизация'));
      await tester.pumpAndSettle();
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('com.old.removed'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('large app catalog builds only viewport and searches packages', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const RussiaRouteDataStatus.unavailable(),
      installedApps: List.generate(
        1000,
        (i) => {'packageName': 'com.example.app$i', 'label': 'App $i'},
      ),
      scrollTo: 'Раздельная маршрутизация',
    );
    await tester.tap(find.text('Раздельная маршрутизация'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox).evaluate().length, lessThan(25));
    await tester.enterText(find.byType(TextField), 'com.example.app999');
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pumpAndSettle();
    expect(find.text('App 999'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('enabled empty app list is never applied as unrestricted VPN', (
    tester,
  ) async {
    List<String>? applied;
    await _pumpPage(
      tester,
      const RussiaRouteDataStatus.unavailable(),
      scrollTo: 'Раздельная маршрутизация',
      onSplitRoutingPackagesChanged: (v) => applied = v,
    );
    await tester.tap(find.text('Раздельная маршрутизация'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.tap(find.byKey(const ValueKey('split-routing-apply')));
    await tester.pumpAndSettle();
    expect(applied, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('split routing opens a dedicated page with independent modes', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const RussiaRouteDataStatus.unavailable(),
      scrollTo: 'Раздельная маршрутизация',
    );
    await tester.tap(find.text('Раздельная маршрутизация'));
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<SplitRoutingMode>), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('split-routing-apply')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('traffic rules replace the old smart routing entry', (
    tester,
  ) async {
    await _pumpPage(tester, const RussiaRouteDataStatus.unavailable());

    expect(find.text('Правила трафика'), findsOneWidget);
    expect(find.text('Умная маршрутизация'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('traffic rules show three presets without duplicate navigation', (
    tester,
  ) async {
    await _pumpPage(tester, const RussiaRouteDataStatus.unavailable());

    await tester.tap(find.text('Правила трафика'));
    await tester.pumpAndSettle();

    expect(find.text('.RU без VPN'), findsOneWidget);
    expect(find.text('Нейросети через VPN'), findsOneWidget);
    expect(find.text('Социальные сети через VPN'), findsOneWidget);
    expect(find.text('Правила от разработчика'), findsNothing);
    expect(
      find.text(
        'Одновременно можно включить только одно правило трафика — так правила не конфликтуют между собой.',
      ),
      findsNothing,
    );
    expect(find.text('🇷🇺'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('traffic rule card opens details and developer profile', (
    tester,
  ) async {
    await _pumpPage(tester, const RussiaRouteDataStatus.unavailable());

    await tester.tap(find.text('Правила трафика'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('ОПИСАНИЕ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('DNS ДЛЯ .RU БЕЗ VPN'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DNS ДЛЯ .RU БЕЗ VPN'), findsOneWidget);
    expect(find.text('Применить правило'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('yamixdev'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('yamixdev'));
    await tester.pumpAndSettle();

    expect(find.text('Bio'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);

    await tester.tap(find.byTooltip('Проверено'));
    await tester.pumpAndSettle();
    expect(find.text('Участник проекта Etonify.'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('selected split app keeps name and package on separate rows', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const RussiaRouteDataStatus.unavailable(),
      splitRoutingMode: SplitRoutingMode.bypassSelected,
      splitRoutingPackages: const ['org.telegram.messenger'],
      installedApps: const [
        {
          'packageName': 'org.telegram.messenger',
          'label': 'Telegram',
          'system': false,
          'launchable': true,
        },
      ],
      scrollTo: 'Telegram',
    );

    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('org.telegram.messenger'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('missing selected app does not repeat package as its name', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const RussiaRouteDataStatus.unavailable(),
      splitRoutingMode: SplitRoutingMode.bypassSelected,
      splitRoutingPackages: const ['com.example.removed'],
      scrollTo: 'Приложение не найдено',
    );

    expect(find.text('Приложение не найдено'), findsOneWidget);
    expect(find.text('com.example.removed'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('selected split app can be removed without reopening picker', (
    tester,
  ) async {
    List<String>? changedPackages;
    await _pumpPage(
      tester,
      const RussiaRouteDataStatus.unavailable(),
      splitRoutingMode: SplitRoutingMode.bypassSelected,
      splitRoutingPackages: const ['org.telegram.messenger'],
      installedApps: const [
        {
          'packageName': 'org.telegram.messenger',
          'label': 'Telegram',
          'system': false,
          'launchable': true,
        },
      ],
      scrollTo: 'Telegram',
      onSplitRoutingPackagesChanged: (value) => changedPackages = value,
    );

    await tester.tap(
      find.byKey(const ValueKey('split-app-org.telegram.messenger')),
    );
    await tester.pumpAndSettle();
    // Selecting a row is a draft; disable the now-empty mode before applying.
    expect(changedPackages, isNull);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-routing-apply')));
    await tester.pumpAndSettle();
    expect(changedPackages, isEmpty);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

Future<AppSettingsController> _pumpPage(
  WidgetTester tester,
  RussiaRouteDataStatus routeStatus, {
  SplitRoutingMode splitRoutingMode = SplitRoutingMode.disabled,
  List<String> splitRoutingPackages = const [],
  List<Map<String, dynamic>> installedApps = const [],
  List<Map<String, dynamic>>? preloadApps,
  double textScale = 1,
  double keyboardInset = 0,
  String scrollTo = 'Правила трафика',
  ValueChanged<List<String>>? onSplitRoutingPackagesChanged,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 860));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final controller = AppSettingsController()
    ..blockLeaks = true
    ..adBlockEnabled = false
    ..trafficRulePreset = TrafficRulePreset.none
    ..russiaDnsDirectResolver = 'udp://77.88.8.8'
    ..bypassLocalNetwork = true
    ..vpnInboundEnabled = true
    ..splitRoutingMode = splitRoutingMode
    ..splitRoutingPackages = splitRoutingPackages;

  final commands = AppSettingsCommands();
  commands.bindRoutingHandlers(
    setBlockLeaks: (_) {},
    setAdBlockEnabled: (_) {},
    downloadAdBlockRuleSet: () async =>
        const AdBlockRuleSetStatus.unavailable(),
    deleteAdBlockRuleSet: () async => const AdBlockRuleSetStatus.unavailable(),
    refreshRoutingRuleData: () async => routeStatus,
    setTrafficRulePreset: (_) {},
    prepareTrafficRuleData: (_) async => routeStatus,
    setRussiaDnsDirectResolver: (_) {},
    setBypassLocalNetwork: (_) {},
    setSplitRoutingMode: (_) {},
    setSplitRoutingPackages: onSplitRoutingPackagesChanged ?? (_) {},
    preloadInstalledApps: () async => preloadApps ?? installedApps,
    applySplitRoutingSettings: (mode, included, excluded) async {
      controller.setSplitRoutingSettings(
        mode: mode,
        included: included,
        excluded: excluded,
      );
      onSplitRoutingPackagesChanged?.call(controller.splitRoutingPackages);
      return true;
    },
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsControllerProvider.overrideWithValue(controller),
        appSettingsCommandsProvider.overrideWithValue(commands),
        russiaRouteDataStatusProvider.overrideWith(
          () => RussiaRouteDataStatusNotifier(routeStatus),
        ),
        installedAppsCacheProvider.overrideWith(
          () => InstalledAppsCacheNotifier(installedApps),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: child!,
        ),
        locale: Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SettingsRoutingPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final inSplitPage =
      scrollTo == 'Telegram' || scrollTo == 'Приложение не найдено';
  await tester.scrollUntilVisible(
    find.text(inSplitPage ? 'Раздельная маршрутизация' : scrollTo),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  if (inSplitPage) {
    await tester.tap(find.text('Раздельная маршрутизация'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(scrollTo),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }
  return controller;
}
