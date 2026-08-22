import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/settings/settings_about_page.dart';
import 'package:meow_client/features/settings/settings_documentation_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

Widget _documentationApp(Locale locale) {
  return MaterialApp(
    key: ValueKey(locale.languageCode),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const SettingsDocumentationPage(),
  );
}

void main() {
  testWidgets('documentation is localized and sections stay compact', (
    tester,
  ) async {
    await tester.pumpWidget(_documentationApp(const Locale('ru')));

    expect(find.text('Справочник Etonify'), findsOneWidget);
    expect(find.text('Что такое Etonify'), findsOneWidget);
    expect(find.text('VPN и локальный прокси'), findsOneWidget);
    expect(find.textContaining('Etonify — Android-клиент'), findsNothing);

    await tester.tap(find.text('Что такое Etonify'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Etonify — Android-клиент'), findsOneWidget);

    await tester.pumpWidget(_documentationApp(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Etonify guide'), findsOneWidget);
    expect(find.text('What Etonify is'), findsOneWidget);
    expect(find.text('VPN and local proxy'), findsOneWidget);
    expect(find.textContaining('Etonify is an Android client'), findsNothing);
  });

  testWidgets('about page opens the embedded documentation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsAboutPage(versionLabel: '0.3.0', onShowOnboarding: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Etonify documentation'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsDocumentationPage), findsOneWidget);
    expect(find.text('Etonify guide'), findsOneWidget);
  });
}
