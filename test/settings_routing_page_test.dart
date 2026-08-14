import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/features/settings/settings_routing_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('traffic rules replace the old smart routing entry', (
    tester,
  ) async {
    await _pumpPage(tester, const RussiaRouteDataStatus.unavailable());

    expect(find.text('Правила трафика'), findsOneWidget);
    expect(find.text('Умная маршрутизация'), findsNothing);
  });

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
  });

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
    expect(find.text('Использовать пресет'), findsOneWidget);

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
    expect(
      find.text('Участник команды MeowTeam.'),
      findsOneWidget,
    );
  });

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
  });

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
  });

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

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(changedPackages, isEmpty);
    expect(find.text('Telegram'), findsNothing);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  RussiaRouteDataStatus routeStatus, {
  SplitRoutingMode splitRoutingMode = SplitRoutingMode.disabled,
  List<String> splitRoutingPackages = const [],
  List<Map<String, dynamic>> installedApps = const [],
  String scrollTo = 'Правила трафика',
  ValueChanged<List<String>>? onSplitRoutingPackagesChanged,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 860));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SettingsRoutingPage(
        currentBlockLeaks: true,
        currentAdBlockEnabled: false,
        currentAdBlockStatus: const AdBlockRuleSetStatus.unavailable(),
        currentRussiaRouteDataStatus: routeStatus,
        currentTrafficRulePreset: TrafficRulePreset.none,
        currentRussiaDnsDirectResolver: 'udp://77.88.8.8',
        currentBypassLocalNetwork: true,
        currentVpnInboundEnabled: true,
        currentSplitRoutingMode: splitRoutingMode,
        currentSplitRoutingPackages: splitRoutingPackages,
        initialInstalledApps: installedApps,
        preloadInstalledApps: () async => installedApps,
        onBlockLeaksChanged: (_) {},
        onAdBlockEnabledChanged: (_) {},
        onDownloadAdBlockRuleSet: () async =>
            const AdBlockRuleSetStatus.unavailable(),
        onDeleteAdBlockRuleSet: () async =>
            const AdBlockRuleSetStatus.unavailable(),
        onRefreshRoutingRuleData: () async => routeStatus,
        onTrafficRulePresetChanged: (_) {},
        onRussiaDnsDirectResolverChanged: (_) {},
        onBypassLocalNetworkChanged: (_) {},
        onSplitRoutingModeChanged: (_) {},
        onSplitRoutingPackagesChanged: onSplitRoutingPackagesChanged ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(scrollTo),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}
