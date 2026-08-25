import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_general_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

Widget _generalSettingsApp({
  required bool statusNotificationEnabled,
  Locale locale = const Locale('en'),
  NotificationTrafficDisplayMode trafficDisplayMode =
      NotificationTrafficDisplayMode.speed,
  ValueChanged<NotificationTrafficDisplayMode>? onTrafficDisplayChanged,
  ValueChanged<int>? onTrafficRefreshChanged,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: SettingsGeneralPage(
      currentLocaleCode: locale.languageCode,
      currentThemePreference: AppThemePreference.system,
      currentAccentColorHex: 'default',
      currentHapticEnabled: true,
      currentStatusNotificationEnabled: statusNotificationEnabled,
      currentNotificationTrafficDisplayMode: trafficDisplayMode,
      currentNotificationTrafficRefreshSeconds: 2,
      currentHideServerIp: false,
      currentMemoryLimitEnabled: true,
      currentMemoryLimitWarningDismissed: false,
      currentUpdateInstallMode: AppUpdateInstallMode.ask,
      onLocaleChanged: (_) {},
      onThemePreferenceChanged: (_) {},
      onAccentColorChanged: (_) {},
      onHapticChanged: (_) {},
      onStatusNotificationChanged: (_) {},
      onNotificationTrafficDisplayModeChanged:
          onTrafficDisplayChanged ?? (_) {},
      onNotificationTrafficRefreshSecondsChanged:
          onTrafficRefreshChanged ?? (_) {},
      onHideServerIpChanged: (_) {},
      onMemoryLimitChanged: (_, {warningDismissed = false}) {},
      onUpdateInstallModeChanged: (_) {},
    ),
  );
}

void main() {
  const trafficDisplaySetting = ValueKey(
    'notification-traffic-display-setting',
  );

  testWidgets(
    'notification display setting remains visible but disabled with status off',
    (tester) async {
      await tester.pumpWidget(
        _generalSettingsApp(statusNotificationEnabled: false),
      );
      await tester.scrollUntilVisible(
        find.byKey(trafficDisplaySetting),
        240,
        scrollable: find.byType(Scrollable).first,
      );

      final tile = tester.widget<InkWell>(find.byKey(trafficDisplaySetting));
      expect(tile.onTap, isNull);
    },
  );

  testWidgets('notification display setting opens only with status enabled', (
    tester,
  ) async {
    NotificationTrafficDisplayMode? selected;
    await tester.pumpWidget(
      _generalSettingsApp(
        statusNotificationEnabled: true,
        onTrafficDisplayChanged: (value) => selected = value,
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(trafficDisplaySetting),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    final tile = tester.widget<InkWell>(find.byKey(trafficDisplaySetting));
    expect(tile.onTap, isNotNull);

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(trafficDisplaySetting));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Total transferred'));
    await tester.pumpAndSettle();

    expect(selected, NotificationTrafficDisplayMode.total);
  });

  testWidgets(
    'notification display setting stays readable on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _generalSettingsApp(
          statusNotificationEnabled: true,
          locale: const Locale('ru'),
          trafficDisplayMode: NotificationTrafficDisplayMode.both,
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(trafficDisplaySetting),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final title = find.text('Что показывать в уведомлении');
      expect(title, findsOneWidget);
      expect(tester.getSize(title).width, greaterThan(120));
      expect(find.text('Скорость и общий объём'), findsOneWidget);
    },
  );

  testWidgets(
    'notification traffic refresh slider is disabled with status off',
    (tester) async {
      await tester.pumpWidget(
        _generalSettingsApp(statusNotificationEnabled: false),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 1);
      expect(slider.max, 10);
      expect(slider.divisions, 9);
      expect(slider.onChanged, isNull);
    },
  );

  testWidgets('notification traffic refresh slider selects whole seconds', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      _generalSettingsApp(
        statusNotificationEnabled: true,
        onTrafficRefreshChanged: (value) => selected = value,
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(7);
    await tester.pump();

    expect(selected, 7);
    expect(find.text('7 s'), findsOneWidget);
  });
}
