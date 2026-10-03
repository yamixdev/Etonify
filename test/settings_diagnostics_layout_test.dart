import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/settings/settings_about_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';

void main() {
  for (final status in <Map<String, dynamic>>[
    {'running': false, 'mode': 'vpn', 'runtimeGeneration': 1},
    {'running': true, 'mode': 'vpn', 'runtimeGeneration': 0},
    {'running': true, 'mode': 'probe', 'runtimeGeneration': 1},
  ]) {
    testWidgets('does not infer an active VPN config from $status', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SettingsDiagnosticsPage(
            onShowOnboarding: () {},
            loadCoreCapabilities: () async => LibboxCapabilities.bundledLegacy,
            readRuntimeStatus: () async => status,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Активен'), findsNothing);
      expect(find.text('Ещё не применялся'), findsOneWidget);
    });
  }

  testWidgets('native runtime without a Dart journal is active, not unapplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsDiagnosticsPage(
          onShowOnboarding: () {},
          loadCoreCapabilities: () async => LibboxCapabilities.bundledLegacy,
          readRuntimeStatus: () async => const {
            'running': true,
            'mode': 'vpn',
            'runtimeGeneration': 1,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ещё не применялся'), findsNothing);
    expect(find.text('Активен'), findsOneWidget);
    expect(
      find.text(
        'Ядро работает. В этой сессии приложения нет записи о запуске его конфигурации.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('diagnostic labels stay readable on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.25)),
          child: child!,
        ),
        home: SettingsDiagnosticsPage(
          onShowOnboarding: () {},
          loadCoreCapabilities: () async => LibboxCapabilities.incompatible,
          readRuntimeStatus: () async => const {},
        ),
      ),
    );
    await tester.pump();

    for (final label in [
      'Кэш изображений Flutter',
      'Соединения ядра (вход. / исход.)',
      'Свободная RAM системы',
    ]) {
      final text = find.text(label);
      expect(text, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    }
    expect(tester.takeException(), isNull);
  });
}
