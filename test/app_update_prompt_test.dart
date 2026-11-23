import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/core/formatting.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/features/settings/app_update_prompt.dart';
import 'package:meow_client/l10n/app_localizations.dart';

AppUpdateInfo _info({required String version, required String apkName}) =>
    AppUpdateInfo(
      version: version,
      tagName: version,
      title: 'Etonify $version',
      body: List.generate(
        48,
        (index) => '- Release change ${index + 1}',
      ).join('\n'),
      htmlUrl: 'https://example.com/releases',
      publishedAt: null,
      asset: AppUpdateAsset(
        name: apkName,
        downloadUrl: 'https://example.com/update.apk',
        sizeBytes: 25165824,
      ),
    );

void main() {
  testWidgets('beta sheet scrolls the changelog above fixed actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(380, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AppUpdateOfferSheet(
            info: _info(
              version: '0.4.1-beta.1',
              apkName: 'Etonify-arm64-v8a.apk',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.science_outlined), findsOneWidget);
    expect(find.text('ARMv8 (64-bit)'), findsOneWidget);
    expect(find.text(formatBytes(25165824)), findsOneWidget);
    final action = find.widgetWithText(FilledButton, 'Download update');
    final later = find.widgetWithText(TextButton, 'Later');
    final actionPosition = tester.getTopLeft(action);
    final laterPosition = tester.getTopLeft(later);
    await tester.drag(
      find.byKey(const ValueKey('app-update-changelog')),
      const Offset(0, -210),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(action), actionPosition);
    expect(tester.getTopLeft(later), laterPosition);
  });

  testWidgets(
    'stable release has no flask and the compact bar can reopen or hide it',
    (tester) async {
      var opened = false;
      var dismissed = false;
      final info = _info(version: '0.4.1', apkName: 'Etonify-universal.apk');
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppUpdateOfferSheet(info: info),
            bottomNavigationBar: AppUpdateDownloadBar(
              info: info,
              operation: null,
              downloaded: false,
              installing: false,
              onOpen: () => opened = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.science_outlined), findsNothing);
      expect(find.text('Universal APK'), findsOneWidget);
      await tester.tap(find.text('Etonify update'));
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(opened, isTrue);
      expect(dismissed, isTrue);
    },
  );
}
