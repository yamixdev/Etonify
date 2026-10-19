import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/home/tabbed_home_shell.dart';
import 'package:meow_client/features/home/home_page.dart';
import 'package:meow_client/features/settings/navigation_preview_gallery.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

Widget _app({
  HomeNavigationMode mode = HomeNavigationMode.panel,
  BottomNavigationStyle style = BottomNavigationStyle.floating,
  ValueChanged<HomeNavigationMode>? onModeChanged,
  ValueChanged<BottomNavigationStyle>? onStyleChanged,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
  home: Scaffold(
    body: NavigationPreviewGallery(
      mode: mode,
      style: style,
      onModeChanged: onModeChanged,
      onStyleChanged: onStyleChanged,
    ),
  ),
);

Finder _card(String id) => find.byKey(ValueKey('navigation-preview-$id'));

void main() {
  testWidgets('tab previews show real two and three destination surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsNWidgets(3));
    expect(find.byType(ConnectionButton), findsNWidgets(3));
    final docked = find.descendant(
      of: _card('docked'),
      matching: find.byType(TabbedHomeShell),
    );
    final floating = find.descendant(
      of: _card('floating'),
      matching: find.byType(TabbedHomeShell),
    );
    expect(
      find.descendant(of: docked, matching: find.byType(NavigationDestination)),
      findsNWidgets(2),
    );
    for (final tab in ['home-tab', 'proxies-tab', 'settings-tab']) {
      expect(
        find.descendant(of: floating, matching: find.byKey(ValueKey(tab))),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: docked,
        matching: find.byIcon(Icons.settings_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: floating,
        matching: find.byIcon(Icons.settings_outlined),
      ),
      findsOneWidget,
    );
    expect(tester.widget<TabbedHomeShell>(docked).effectsEnabled, isFalse);
    expect(tester.widget<TabbedHomeShell>(floating).effectsEnabled, isFalse);
  });

  testWidgets('unavailable callbacks disable only incompatible choices', (
    tester,
  ) async {
    final modes = <HomeNavigationMode>[];
    await tester.pumpWidget(_app(onModeChanged: modes.add));
    await tester.pumpAndSettle();
    final docked = tester.getSemantics(_card('docked')).getSemanticsData();
    expect(docked.flagsCollection.isEnabled, Tristate.isFalse);
    await tester.ensureVisible(_card('docked'));
    await tester.tap(_card('docked'));
    expect(modes, isEmpty);
    await tester.ensureVisible(_card('floating'));
    await tester.tap(_card('floating'));
    expect(modes, [HomeNavigationMode.tabs]);
  });

  testWidgets(
    'previews expose one labeled choice and hide miniature controls',
    (tester) async {
      await tester.pumpWidget(
        _app(onModeChanged: (_) {}, onStyleChanged: (_) {}),
      );
      await tester.pumpAndSettle();
      final panel = tester.getSemantics(_card('panel')).getSemanticsData();
      expect(panel.label, 'Sliding panel');
      expect(panel.flagsCollection.isSelected, Tristate.isTrue);
      await tester.ensureVisible(_card('floating'));
      final floating = tester
          .getSemantics(_card('floating'))
          .getSemanticsData();
      expect(floating.label, 'Floating navigation, Experimental');
      expect(find.bySemanticsLabel('Home'), findsNothing);
      expect(find.bySemanticsLabel('Settings'), findsNothing);
    },
  );

  for (final width in [320.0, 800.0]) {
    testWidgets('Russian gallery fits width $width with doubled text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _app(
          locale: const Locale('ru'),
          onModeChanged: (_) {},
          onStyleChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      for (final id in ['panel', 'docked', 'floating']) {
        await tester.ensureVisible(_card(id));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: id);
      }
      expect(find.text('Экспериментально'), findsOneWidget);
    });
  }
}
