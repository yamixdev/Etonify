import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/windows_storage_fixture.dart';
import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/features/settings/settings_update_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
  setUpAll(() async {
    final directory = await Directory.systemTemp.createTemp(
      'etonify-update-layout-',
    );
    await bootstrapWindowsStorageFixture(directory);
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
  });
  testWidgets('OTA setting title uses the shared settings title styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsUpdatePage(currentVersion: '0.3.7-beta.4'),
      ),
    );
    await tester.pump();
    final tile = find.byKey(const ValueKey('update-install-mode-setting'));
    final title = tester.widget<ListTile>(tile).title!;
    final renderedTitle = tester.widget<RichText>(
      find.descendant(
        of: find.byWidget(title),
        matching: find.byType(RichText),
      ),
    );
    expect(renderedTitle.text.style?.fontSize, 16);
    expect(renderedTitle.text.style?.fontWeight, FontWeight.w700);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'update screen keeps full short title and controls near the top',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SettingsUpdatePage(currentVersion: '0.3.7-beta.4'),
        ),
      );
      await tester.pump();

      expect(find.text('Обновления'), findsOneWidget);
      final installMode = find.byKey(
        const ValueKey('update-install-mode-setting'),
      );
      expect(installMode, findsOneWidget);
      expect(tester.getTopLeft(installMode).dy, lessThan(245));
      expect(tester.takeException(), isNull);
    },
  );
}
