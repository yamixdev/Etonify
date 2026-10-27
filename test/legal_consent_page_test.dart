import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/legal/legal_consent_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

Widget _app({
  required VoidCallback onAccept,
  Locale locale = const Locale('ru'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: LegalConsentPage(requiredVersion: '0.2.1', onAccept: onAccept),
  );
}

void main() {
  for (final mode in HomeNavigationMode.values) {
    testWidgets('app requires and persists explicit consent in $mode', (
      tester,
    ) async {
      final initial = AppSettingsController()
          .toState(
            onboardingCompleted: true,
            acceptedLegalVersion: '',
            acceptedLegalAtMillis: null,
            activeProfileId: '',
            selectedProxyTag: '',
          )
          .copyWith(
            localeCode: 'ru',
            homeNavigationMode: mode,
            autoCheckNoticeAcknowledged: true,
            hwidDefaultNoticeShown: true,
          );
      final store = MemoryAppSettingsStore(initial);
      Widget client() => ProviderScope(child: MeowClient(store: store));
      await tester.pumpWidget(client());
      await tester.pumpAndSettle();
      expect(find.byType(LegalConsentPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LegalConsentPage), findsOneWidget);
      expect((await store.loadState()).acceptedLegalVersion, isEmpty);
      await tester.tap(find.text('Принять'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LegalConsentPage), findsNothing);
      final saved = await store.loadState();
      expect(saved.acceptedLegalVersion, '0.2.1');
      expect(saved.acceptedLegalAtMillis, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(client());
      await tester.pumpAndSettle();
      expect(find.byType(LegalConsentPage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('explicit accept works without pretending documents were read', (
    tester,
  ) async {
    var accepted = 0;
    await tester.pumpWidget(_app(onAccept: () => accepted++));
    await tester.pumpAndSettle();

    final accept = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
    expect(accepted, 0);
    await tester.tap(accept);
    await tester.tap(accept);
    await tester.pump();
    expect(accepted, 1);
  });

  testWidgets('both documents can be read and left without accepting', (
    tester,
  ) async {
    var accepted = 0;
    await tester.pumpWidget(_app(onAccept: () => accepted++));
    await tester.pumpAndSettle();
    expect(find.text('Документы'), findsOneWidget);
    for (final title in [
      'Пользовательское соглашение',
      'Политика конфиденциальности',
    ]) {
      await tester.tap(find.text('Документы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(LegalDocumentPage), findsOneWidget);
      if (title == 'Пользовательское соглашение') {
        await tester.tap(find.text('Закрыть'));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.byType(LegalDocumentsPage), findsOneWidget);
      expect(find.text('Документы'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Отказ от ответственности'), findsOneWidget);
      expect(accepted, 0);
    }
    await tester.tap(find.text('Принять'));
    await tester.pump();
    expect(accepted, 1);
  });

  testWidgets('back and taps outside the disclaimer cannot bypass consent', (
    tester,
  ) async {
    var accepted = 0;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => LegalConsentPage(
                  requiredVersion: '0.2.1',
                  onAccept: () => accepted++,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LegalConsentPage), findsOneWidget);
    expect(accepted, 0);
  });

  for (final locale in [const Locale('ru'), const Locale('en')]) {
    for (final size in [const Size(360, 800), const Size(640, 320)]) {
      testWidgets('actions remain reachable at 200% text: $locale $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var accepted = false;
        await tester.pumpWidget(
          _app(locale: locale, onAccept: () => accepted = true),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final documents = find.byType(TextButton);
        expect(documents.hitTestable(), findsOneWidget);
        await tester.tap(documents);
        await tester.pumpAndSettle();
        final privacy = find.text(
          locale.languageCode == 'ru'
              ? 'Политика конфиденциальности'
              : 'Privacy Policy',
        );
        await tester.scrollUntilVisible(privacy, 150);
        await tester.pumpAndSettle();
        await tester.tap(privacy);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final close = find.widgetWithText(
          TextButton,
          locale.languageCode == 'ru' ? 'Закрыть' : 'Close',
        );
        expect(close.hitTestable(), findsOneWidget);
        await tester.tap(close);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        final accept = find.byType(FilledButton);
        expect(accept.hitTestable(), findsOneWidget);
        await tester.tap(accept);
        await tester.pump();
        expect(accepted, isTrue);
      });
    }
  }
}
