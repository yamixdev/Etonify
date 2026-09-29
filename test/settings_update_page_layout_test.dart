import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/settings/settings_update_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
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
