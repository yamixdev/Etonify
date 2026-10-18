import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_general_page.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

Widget _generalSettingsApp({
  required bool statusNotificationEnabled,
  Locale locale = const Locale('en'),
  NotificationTrafficDisplayMode trafficDisplayMode =
      NotificationTrafficDisplayMode.speed,
  ValueChanged<NotificationTrafficDisplayMode>? onTrafficDisplayChanged,
  ValueChanged<int>? onTrafficRefreshChanged,
  bool currentSendHwidToProviders = true,
  ValueChanged<bool>? onHwidChanged,
  bool autoConnectOnLaunch = false,
  ValueChanged<bool>? onAutoConnectChanged,
  VoidCallback? onAddQuickSettingsTile,
  ValueChanged<HomeNavigationMode>? onHomeNavigationChanged,
  HomeNavigationMode homeNavigationMode = HomeNavigationMode.panel,
  ValueChanged<BottomNavigationStyle>? onBottomNavigationStyleChanged,
  BottomNavigationStyle bottomNavigationStyle = BottomNavigationStyle.floating,
  ValueChanged<bool>? onHapticChanged,
  ValueChanged<bool>? onHideIpChanged,
  ValueChanged<AppThemePreference>? onThemeChanged,
  ValueChanged<String>? onAccentChanged,
  ValueChanged<String>? onLocaleChanged,
  bool hapticEnabled = true,
  ValueChanged<bool>? onStatusChanged,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: SettingsGeneralPage(
      currentLocaleCode: locale.languageCode,
      currentThemePreference: AppThemePreference.system,
      currentAccentColorHex: 'default',
      currentHapticEnabled: hapticEnabled,
      currentStatusNotificationEnabled: statusNotificationEnabled,
      currentNotificationTrafficDisplayMode: trafficDisplayMode,
      currentNotificationTrafficRefreshSeconds: 2,
      currentHideServerIp: false,
      currentSendHwidToProviders: currentSendHwidToProviders,
      onSendHwidToProvidersChanged: onHwidChanged,
      currentAutoConnectOnLaunch: autoConnectOnLaunch,
      onAutoConnectOnLaunchChanged: onAutoConnectChanged,
      showQuickSettingsTileAction: onAddQuickSettingsTile != null,
      onAddQuickSettingsTile: onAddQuickSettingsTile,
      onLocaleChanged: onLocaleChanged ?? (_) {},
      onThemePreferenceChanged: onThemeChanged ?? (_) {},
      onAccentColorChanged: onAccentChanged ?? (_) {},
      onHapticChanged: onHapticChanged ?? (_) {},
      onStatusNotificationChanged: onStatusChanged ?? (_) {},
      onNotificationTrafficDisplayModeChanged:
          onTrafficDisplayChanged ?? (_) {},
      onNotificationTrafficRefreshSecondsChanged:
          onTrafficRefreshChanged ?? (_) {},
      onHideServerIpChanged: onHideIpChanged ?? (_) {},
      onHomeNavigationModeChanged: onHomeNavigationChanged,
      currentHomeNavigationMode: homeNavigationMode,
      currentBottomNavigationStyle: bottomNavigationStyle,
      onBottomNavigationStyleChanged: onBottomNavigationStyleChanged,
    ),
  );
}

Future<void> _openGeneralSection(WidgetTester tester, String section) async {
  final entry = find.byKey(ValueKey('general-$section-entry'));
  await tester.ensureVisible(entry);
  await tester.pumpAndSettle();
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

Future<void> _openNotificationSettings(WidgetTester tester) async {
  final entry = find.byKey(const ValueKey('notification-settings-entry'));
  await tester.ensureVisible(entry);
  await tester.pumpAndSettle();
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('open appearance follows externally restored bottom bar style', (
    tester,
  ) async {
    final style = ValueNotifier(BottomNavigationStyle.floating);
    addTearDown(style.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<BottomNavigationStyle>(
        valueListenable: style,
        builder: (_, value, child) => _generalSettingsApp(
          statusNotificationEnabled: true,
          homeNavigationMode: HomeNavigationMode.tabs,
          bottomNavigationStyle: value,
          onBottomNavigationStyleChanged: (_) {},
        ),
      ),
    );
    await _openGeneralSection(tester, 'appearance');
    final entry = find.byKey(const ValueKey('bottom-navigation-style-setting'));
    expect(entry, findsOneWidget);
    style.value = BottomNavigationStyle.docked;
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: entry, matching: find.text('Docked')),
      findsOneWidget,
    );
  });
  testWidgets(
    'bottom bar style appears only for tabs and updates immediately',
    (tester) async {
      final changes = <BottomNavigationStyle>[];
      await tester.pumpWidget(
        _generalSettingsApp(
          statusNotificationEnabled: true,
          onHomeNavigationChanged: (_) {},
          onBottomNavigationStyleChanged: changes.add,
        ),
      );
      await _openGeneralSection(tester, 'appearance');
      final style = find.byKey(
        const ValueKey('bottom-navigation-style-setting'),
      );
      expect(style, findsNothing);
      final navigation = find.byKey(const ValueKey('home-navigation-setting'));
      await tester.ensureVisible(navigation);
      await tester.tap(navigation);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bottom tabs').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(style);
      await tester.tap(style);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Docked').last);
      await tester.pumpAndSettle();
      expect(changes, [BottomNavigationStyle.docked]);
      expect(
        find.descendant(of: style, matching: find.text('Docked')),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openGeneralSection(tester, 'appearance');
      await tester.ensureVisible(style);
      expect(
        find.descendant(of: style, matching: find.text('Docked')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'notification selections survive closing and reopening the section',
    (tester) async {
      final statuses = <bool>[];
      final modes = <NotificationTrafficDisplayMode>[];
      final refreshes = <int>[];
      await tester.pumpWidget(
        _generalSettingsApp(
          statusNotificationEnabled: true,
          onStatusChanged: statuses.add,
          onTrafficDisplayChanged: modes.add,
          onTrafficRefreshChanged: refreshes.add,
        ),
      );
      await _openNotificationSettings(tester);
      tester.widget<Slider>(find.byType(Slider)).onChanged!(7);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('notification-traffic-display-setting')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Total transferred'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Notification status'),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _openNotificationSettings(tester);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 7);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Notification status'),
            )
            .value,
        isFalse,
      );
      expect(find.text('Total transferred'), findsOneWidget);
      expect(statuses, [false]);
      expect(modes, [NotificationTrafficDisplayMode.total]);
      expect(refreshes, [7]);
    },
  );

  testWidgets('open sections receive parent property changes', (tester) async {
    final hapticEnabled = ValueNotifier(true);
    addTearDown(hapticEnabled.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: hapticEnabled,
        builder: (context, value, child) => _generalSettingsApp(
          statusNotificationEnabled: true,
          hapticEnabled: value,
        ),
      ),
    );
    await _openGeneralSection(tester, 'startup');
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Vibration'),
          )
          .value,
      isTrue,
    );
    hapticEnabled.value = false;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Vibration'),
          )
          .value,
      isFalse,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openGeneralSection(tester, 'startup');
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Vibration'),
          )
          .value,
      isFalse,
    );
  });

  testWidgets('appearance callbacks keep their selections after system back', (
    tester,
  ) async {
    final themes = <AppThemePreference>[];
    final accents = <String>[];
    final locales = <String>[];
    await tester.pumpWidget(
      _generalSettingsApp(
        statusNotificationEnabled: true,
        onThemeChanged: themes.add,
        onAccentChanged: accents.add,
        onLocaleChanged: locales.add,
      ),
    );
    await _openGeneralSection(tester, 'appearance');
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    final swatches = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.child is AnimatedContainer &&
          (widget.child! as AnimatedContainer).constraints?.maxWidth == 48,
    );
    await tester.tap(swatches.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Russian'));
    await tester.pumpAndSettle();
    expect(themes, [AppThemePreference.dark]);
    expect(accents, ['2D5BFF']);
    expect(locales, ['ru']);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _openGeneralSection(tester, 'appearance');
    expect(find.text('Russian'), findsOneWidget);
    final darkCard = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find
                .ancestor(
                  of: find.text('Dark'),
                  matching: find.byType(GestureDetector),
                )
                .first,
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(
      ((darkCard.decoration! as BoxDecoration).border! as Border).top.width,
      2.5,
    );
    final blueSwatch = tester.widget<GestureDetector>(swatches.at(1));
    expect(
      (((blueSwatch.child! as AnimatedContainer).decoration! as BoxDecoration)
                  .border!
              as Border)
          .top
          .width,
      3,
    );
  });

  testWidgets('appearance scroll survives setting updates and reopening', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 450);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final changes = <HomeNavigationMode>[];
    await tester.pumpWidget(
      _generalSettingsApp(
        statusNotificationEnabled: true,
        onHomeNavigationChanged: changes.add,
      ),
    );
    await _openGeneralSection(tester, 'appearance');
    final entry = find.byKey(const ValueKey('home-navigation-setting'));
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    final scrollable = find.byKey(
      const PageStorageKey('general-appearance-scroll'),
    );
    final state = tester.state<ScrollableState>(
      find.descendant(of: scrollable, matching: find.byType(Scrollable)).first,
    );
    final offset = state.position.pixels;
    expect(offset, greaterThan(0));
    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bottom tabs').last);
    await tester.pumpAndSettle();
    expect(state.position.pixels, offset);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _openGeneralSection(tester, 'appearance');
    final reopened = tester.state<ScrollableState>(
      find.descendant(of: scrollable, matching: find.byType(Scrollable)).first,
    );
    expect(reopened.position.pixels, offset);
    expect(
      find.descendant(of: entry, matching: find.text('Bottom tabs')),
      findsOneWidget,
    );
    expect(changes, [HomeNavigationMode.tabs]);
  });

  testWidgets(
    'general hub opens five focused sections without inline controls',
    (tester) async {
      await tester.pumpWidget(
        _generalSettingsApp(statusNotificationEnabled: true),
      );
      await tester.pumpAndSettle();
      for (final section in [
        'appearance',
        'startup',
        'background',
        'privacy',
      ]) {
        expect(find.byKey(ValueKey('general-$section-entry')), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey('notification-settings-entry')),
        findsOneWidget,
      );
      expect(find.byType(SwitchListTile), findsNothing);
      await _openGeneralSection(tester, 'background');
      expect(find.text('Subscription updates'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('general-appearance-entry')),
        findsOneWidget,
      );
    },
  );

  testWidgets('startup and privacy values survive changes and reopening', (
    tester,
  ) async {
    final haptics = <bool>[];
    final hiddenIps = <bool>[];
    final hwids = <bool>[];
    final connections = <bool>[];
    await tester.pumpWidget(
      _generalSettingsApp(
        statusNotificationEnabled: true,
        onHapticChanged: haptics.add,
        onHideIpChanged: hiddenIps.add,
        onHwidChanged: hwids.add,
        onAutoConnectChanged: connections.add,
      ),
    );
    await _openGeneralSection(tester, 'startup');
    await tester.tap(find.byKey(const ValueKey('auto-connect-on-launch')));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Vibration'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openGeneralSection(tester, 'startup');
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('auto-connect-on-launch')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Vibration'),
          )
          .value,
      isFalse,
    );
    expect(connections, [true]);
    expect(haptics, [false]);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openGeneralSection(tester, 'privacy');
    await tester.tap(find.byKey(const ValueKey('hide-server-ip')));
    await tester.tap(find.byKey(const ValueKey('send-hwid-to-providers')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openGeneralSection(tester, 'privacy');
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('hide-server-ip')))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('send-hwid-to-providers')),
          )
          .value,
      isFalse,
    );
    expect(hiddenIps, [true]);
    expect(hwids, [false]);
  });

  testWidgets(
    'general sections fit narrow screens with enlarged Russian text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _generalSettingsApp(
          statusNotificationEnabled: true,
          locale: const Locale('ru'),
        ),
      );
      await tester.pumpAndSettle();
      for (final section in [
        'appearance',
        'startup',
        'privacy',
        'background',
      ]) {
        await _openGeneralSection(tester, section);
        expect(tester.takeException(), isNull);
        expect(
          Navigator.of(tester.element(find.byType(Scaffold).last)).canPop(),
          isTrue,
          reason: section,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets(
    'navigation picker changes mode immediately without reopening settings',
    (tester) async {
      final changes = <HomeNavigationMode>[];
      await tester.pumpWidget(
        _generalSettingsApp(
          statusNotificationEnabled: true,
          onHomeNavigationChanged: changes.add,
        ),
      );
      await _openGeneralSection(tester, 'appearance');
      final entry = find.byKey(const ValueKey('home-navigation-setting'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bottom tabs').last);
      await tester.pumpAndSettle();
      expect(changes, [HomeNavigationMode.tabs]);
      expect(
        find.descendant(of: entry, matching: find.text('Bottom tabs')),
        findsOneWidget,
      );
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sliding panel').last);
      await tester.pumpAndSettle();
      expect(changes, [HomeNavigationMode.tabs, HomeNavigationMode.panel]);
    },
  );
  testWidgets('general settings exposes launch connect and quick tile action', (
    tester,
  ) async {
    final changes = <bool>[];
    var tileRequests = 0;
    await tester.pumpWidget(
      _generalSettingsApp(
        statusNotificationEnabled: true,
        onAutoConnectChanged: changes.add,
        onAddQuickSettingsTile: () => tileRequests++,
      ),
    );
    await _openGeneralSection(tester, 'startup');
    final autoConnect = find.byKey(const ValueKey('auto-connect-on-launch'));
    await tester.ensureVisible(autoConnect);
    await tester.tap(autoConnect);
    await tester.pump();
    expect(changes, [true]);
    expect(tester.widget<SwitchListTile>(autoConnect).value, isTrue);

    final tileAction = find.byKey(const ValueKey('add-quick-settings-tile'));
    await tester.ensureVisible(tileAction);
    await tester.tap(tileAction);
    expect(tileRequests, 1);
  });
  testWidgets(
    'HWID switch defaults to true, updates immediately and remains readable in Russian',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final values = <bool>[];
      await tester.pumpWidget(
        _generalSettingsApp(
          statusNotificationEnabled: true,
          locale: const Locale('ru'),
          onHwidChanged: values.add,
        ),
      );
      await tester.pumpAndSettle();
      await _openGeneralSection(tester, 'privacy');
      final tile = find.byKey(const ValueKey('send-hwid-to-providers'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      expect(values, [false, true]);
      expect(tester.takeException(), isNull);
    },
  );
  const trafficDisplaySetting = ValueKey(
    'notification-traffic-display-setting',
  );

  testWidgets('general settings shows one notification entry and no OTA mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _generalSettingsApp(statusNotificationEnabled: true),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notification-settings-entry')),
      findsOneWidget,
    );
    expect(find.text('Update installation'), findsNothing);
  });

  testWidgets('common controls are compact and grouped', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _generalSettingsApp(statusNotificationEnabled: true),
    );
    await _openGeneralSection(tester, 'startup');
    final autoConnect = find.byKey(const ValueKey('auto-connect-on-launch'));
    await tester.ensureVisible(autoConnect);
    await tester.pumpAndSettle();

    final vibrationCard = find
        .ancestor(of: find.text('Vibration'), matching: find.byType(Card))
        .first;
    final notificationCard = find
        .ancestor(of: autoConnect, matching: find.byType(Card))
        .first;
    expect(
      vibrationCard.evaluate().single,
      same(notificationCard.evaluate().single),
    );

    final vibrationTile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Vibration'),
    );
    expect(vibrationTile.subtitle, isNull);
  });

  testWidgets('language value remains readable below its title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _generalSettingsApp(statusNotificationEnabled: true),
    );
    await tester.pumpAndSettle();
    await _openGeneralSection(tester, 'appearance');

    final languageTile = tester.widget<ListTile>(
      find.ancestor(of: find.text('Language'), matching: find.byType(ListTile)),
    );
    expect((languageTile.subtitle! as Text).data, 'English');
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('soft core memory limit is not shown in general settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _generalSettingsApp(statusNotificationEnabled: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Soft core memory limit'), findsNothing);
  });

  testWidgets(
    'notification display setting remains visible but disabled with status off',
    (tester) async {
      await tester.pumpWidget(
        _generalSettingsApp(statusNotificationEnabled: false),
      );
      await _openNotificationSettings(tester);
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
    await _openNotificationSettings(tester);

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
      await _openNotificationSettings(tester);
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

  testWidgets('notification controls share one compact group', (tester) async {
    await tester.pumpWidget(
      _generalSettingsApp(statusNotificationEnabled: true),
    );
    await _openNotificationSettings(tester);

    expect(find.byType(SettingsTileGroup), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Notification status'),
          )
          .subtitle,
      isNull,
    );
  });

  testWidgets(
    'notification traffic refresh slider is disabled with status off',
    (tester) async {
      await tester.pumpWidget(
        _generalSettingsApp(statusNotificationEnabled: false),
      );
      await _openNotificationSettings(tester);

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
    await _openNotificationSettings(tester);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(7);
    await tester.pump();

    expect(selected, 7);
    expect(find.text('7 s'), findsOneWidget);
  });
}
