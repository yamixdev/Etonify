import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/settings/settings_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

Widget _settingsApp({
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
      currentLocaleLabel: 'System',
      currentThemeLabel: 'System',
      onOpenGeneral: () {},
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
