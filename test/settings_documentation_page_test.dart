import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/legal/legal_consent_page.dart';
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

    expect(find.text('Документация'), findsOneWidget);
    expect(find.text('Начало работы'), findsOneWidget);
    expect(find.text('Быстрый старт'), findsOneWidget);
    expect(find.text('О Etonify'), findsOneWidget);
    expect(find.text('VPN и локальный прокси'), findsOneWidget);
    expect(find.textContaining('Etonify работает на Android'), findsNothing);
    expect(find.text('Нужна помощь?'), findsNothing);

    await tester.tap(find.text('О Etonify'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Etonify работает на Android'), findsOneWidget);
    final aboutTile = tester.widget<ExpansionTile>(
      find.ancestor(
        of: find.text('О Etonify'),
        matching: find.byType(ExpansionTile),
      ),
    );
    expect(aboutTile.shape, const RoundedRectangleBorder());
    expect(aboutTile.collapsedShape, const RoundedRectangleBorder());

    await tester.tap(find.text('Быстрый старт'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('1. Добавьте подписку или отдельный сервер.'),
      findsOneWidget,
    );

    await tester.pumpWidget(_documentationApp(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Documentation'), findsOneWidget);
    expect(find.text('Getting started'), findsOneWidget);
    expect(find.text('Quick start'), findsOneWidget);
    expect(find.text('About Etonify'), findsOneWidget);
    expect(find.text('VPN and local proxy'), findsOneWidget);
    expect(find.textContaining('Etonify works on Android'), findsNothing);
    expect(find.text('Need help?'), findsNothing);
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

    expect(find.text('yamixdev/etonify-core'), findsNothing);
    expect(find.text('Terms of Use'), findsNothing);
    expect(find.text('Privacy Policy'), findsNothing);
    expect(find.text('@etonify'), findsOneWidget);

    final updatesTop = tester.getTopLeft(find.text('App updates')).dy;
    final documentationTop = tester
        .getTopLeft(find.text('Etonify documentation'))
        .dy;
    final diagnosticsTop = tester
        .getTopLeft(find.text('Resources & diagnostics'))
        .dy;
    expect(updatesTop, lessThan(documentationTop));
    expect(documentationTop, lessThan(diagnosticsTop));

    await tester.ensureVisible(find.text('Etonify documentation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Etonify documentation'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsDocumentationPage), findsOneWidget);
    expect(find.text('Documentation'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);

    await tester.ensureVisible(find.text('Terms of Use'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terms of Use'));
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentPage), findsOneWidget);
    expect(find.text('Terms of Use'), findsWidgets);
  });

  testWidgets('about overview stays readable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsAboutPage(
          versionLabel: '0.3.1-rc.1',
          onShowOnboarding: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('App version'), findsOneWidget);
    expect(find.text('0.3.1-rc.1'), findsOneWidget);
    expect(find.text('@etonify'), findsOneWidget);
    expect(find.text('MeowTeam'), findsOneWidget);
  });

  testWidgets('about page follows the compact reference hierarchy in Russian', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsAboutPage(versionLabel: '0.3.1', onShowOnboarding: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('О приложении'), findsOneWidget);
    expect(find.text('Версия приложения'), findsOneWidget);
    expect(find.text('Телеграм-канал'), findsOneWidget);
    expect(find.text('Telegram Etonify'), findsNothing);
    expect(find.text('Обновления приложения'), findsOneWidget);

    final brand = find.byKey(const ValueKey('about-brand'));
    final overview = find.byKey(const ValueKey('about-overview-card'));
    expect(brand, findsOneWidget);
    expect(overview, findsOneWidget);
    expect(
      tester.getBottomLeft(brand).dy,
      lessThan(tester.getTopLeft(overview).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
