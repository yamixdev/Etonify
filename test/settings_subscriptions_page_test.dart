import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/subscription/happ_crypt5_local.dart';
import 'package:meow_client/features/settings/settings_subscriptions_page.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';

Widget _subscriptionsSettingsApp({
  Locale locale = const Locale('en'),
  ValueChanged<UrlTestConfig>? onChanged,
  ValueChanged<int>? onLocationLookupLimitChanged,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: SettingsSubscriptionsPage(
      currentConfig: const UrlTestConfig(
        url: defaultUrlTestUrl,
        intervalSeconds: 1800,
        timeoutSeconds: 15,
        concurrency: 8,
        unavailableCheckIntervalSeconds: 120,
      ),
      currentLocationLookupLimit: 2,
      currentLocationLookupTimeoutSeconds: 3,
      currentLocationLookupConcurrency: 1,
      onChanged: onChanged ?? (_) {},
      onLocationLookupLimitChanged: onLocationLookupLimitChanged ?? (_) {},
      onLocationLookupTimeoutSecondsChanged: (_) {},
      onLocationLookupConcurrencyChanged: (_) {},
      androidIdLoader: () async => '0123456789abcdef',
      happSupportLoader: () async =>
          const HappCrypt5Support(supported: true, detail: 'ready'),
    ),
  );
}

void main() {
  testWidgets('settings stay compact and readable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _subscriptionsSettingsApp(locale: const Locale('ru')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Подписки и проверка'), findsOneWidget);
    expect(find.byType(SettingsTileGroup), findsOneWidget);
    expect(find.byType(Slider), findsNothing);

    final intervalTile = find.descendant(
      of: find.byKey(const ValueKey('urltest-interval-setting')),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(intervalTile).subtitle, isNull);
    expect(find.text('1800 сек.'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Локации'), 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Happ'), 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'URLTest interval editor supports the current 1800 second value',
    (tester) async {
      UrlTestConfig? selected;
      await tester.pumpWidget(
        _subscriptionsSettingsApp(onChanged: (value) => selected = value),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('urltest-interval-setting')));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('compact-setting-slider')),
      );
      expect(slider.value, 1800);
      expect(slider.min, 30);
      expect(slider.max, 3600);
      expect(slider.divisions, 119);

      slider.onChanged!(3600);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(selected?.intervalSeconds, 3600);
      expect(find.text('3600s'), findsOneWidget);
    },
  );

  testWidgets('test URL is edited in a focused sheet', (tester) async {
    UrlTestConfig? selected;
    await tester.pumpWidget(
      _subscriptionsSettingsApp(onChanged: (value) => selected = value),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('urltest-url-setting')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('urltest-url-field')),
      'https://example.com/generate_204',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(selected?.url, 'https://example.com/generate_204');
    expect(find.text('example.com'), findsOneWidget);
  });
}
