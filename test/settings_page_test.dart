import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/settings/settings_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

Widget _settingsApp({
  VoidCallback? onOpenGeneral,
  VoidCallback? onImportBackup,
  VoidCallback? onExportSettings,
  VoidCallback? onExportEncryptedProfile,
  VoidCallback? onExportPlainProfile,
  VoidCallback? onResetSettings,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: SettingsPage(
      onOpenGeneral: onOpenGeneral ?? () {},
      onOpenDns: () {},
      onOpenSubscriptions: () {},
      onOpenInbound: () {},
      onOpenRouting: () {},
      onOpenSecurity: () {},
      onImportBackup: onImportBackup ?? () {},
      onExportSettings: onExportSettings ?? () {},
      onExportEncryptedProfile: onExportEncryptedProfile ?? () {},
      onExportPlainProfile: onExportPlainProfile ?? () {},
      onResetSettings: onResetSettings ?? () {},
      onOpenExperimental: () {},
      onOpenLogs: () {},
      onOpenAbout: () {},
    ),
  );
}

Future<void> _openSettingsMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('settings-more-menu')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('settings destinations are compact and omit descriptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNWidgets(3));
    expect(find.byType(ListTile), findsNWidgets(9));
    expect(find.text('General'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.textContaining('Language: System'), findsNothing);
    expect(find.text('VPN · Proxy'), findsNothing);
    expect(find.text('Direct · Via proxy'), findsNothing);
    expect(tester.getBottomLeft(find.text('About')).dy, lessThan(800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings destinations stay fixed and remain tappable', (
    tester,
  ) async {
    var generalCalls = 0;
    await tester.pumpWidget(_settingsApp(onOpenGeneral: () => generalCalls++));
    await tester.pumpAndSettle();

    final destinations = tester.widget<ListView>(
      find.byKey(const ValueKey('settings-destinations')),
    );
    expect(destinations.physics, isA<NeverScrollableScrollPhysics>());

    await tester.tap(find.text('General'));
    await tester.pump();
    expect(generalCalls, 1);
  });

  testWidgets('settings menu exposes import, export, and reset', (
    tester,
  ) async {
    var importCalls = 0;
    await tester.pumpWidget(_settingsApp(onImportBackup: () => importCalls++));

    await _openSettingsMenu(tester);

    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Reset settings'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-import')));
    await tester.pumpAndSettle();
    expect(importCalls, 1);
  });

  testWidgets('export submenu dispatches the selected export action', (
    tester,
  ) async {
    var encryptedExportCalls = 0;
    await tester.pumpWidget(
      _settingsApp(onExportEncryptedProfile: () => encryptedExportCalls++),
    );

    await _openSettingsMenu(tester);
    await tester.tap(find.byKey(const ValueKey('settings-export')));
    await tester.pumpAndSettle();

    expect(find.text('Export settings'), findsOneWidget);
    expect(find.text('Export subscriptions with password'), findsOneWidget);
    expect(
      find.text('Export subscriptions without encryption'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-export-encrypted-profile')),
    );
    await tester.pumpAndSettle();
    expect(encryptedExportCalls, 1);
  });

  testWidgets('reset requires confirmation before invoking callback', (
    tester,
  ) async {
    var resetCalls = 0;
    await tester.pumpWidget(_settingsApp(onResetSettings: () => resetCalls++));

    await _openSettingsMenu(tester);
    await tester.tap(find.byKey(const ValueKey('settings-reset')));
    await tester.pumpAndSettle();

    expect(find.text('Reset settings?'), findsOneWidget);
    expect(resetCalls, 0);

    await tester.tap(find.byKey(const ValueKey('settings-reset-confirm')));
    await tester.pumpAndSettle();
    expect(resetCalls, 1);
  });
}
