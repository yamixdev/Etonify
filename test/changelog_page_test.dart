import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/features/settings/changelog_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('changelog has one heading and full notes on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const info = AppUpdateInfo(
      version: '0.3.7-beta.4',
      tagName: 'v0.3.7-beta.4',
      title: 'Release',
      body: '## Fixes\nA longer release note.',
      htmlUrl: 'https://example.com/release',
      publishedAt: null,
      asset: AppUpdateAsset(
        name: 'etonify.apk',
        downloadUrl: 'https://example.com/etonify.apk',
        sizeBytes: 100,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ChangelogPage(
          currentVersion: '0.3.7-beta.4',
          currentBuildNumber: 1,
          initialInfo: info,
        ),
      ),
    );
    await tester.pump();

    expect(find.text("What's new"), findsOneWidget);
    expect(find.text('0.3.7-beta.4'), findsOneWidget);
    expect(find.textContaining('A longer release note'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
