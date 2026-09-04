import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/features/settings/settings_security_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

Widget _securityApp({
  Locale locale = const Locale('en'),
  bool allowProxy = false,
  bool allowSubscription = false,
  ValueChanged<bool>? onProxyChanged,
  ValueChanged<bool>? onSubscriptionChanged,
}) {
  final controller = AppSettingsController()
    ..allowUntrustedProxyCertificates = allowProxy
    ..allowUntrustedSubscriptionCertificates = allowSubscription;
  final commands = AppSettingsCommands();
  final container = ProviderContainer(
    overrides: [
      appSettingsControllerProvider.overrideWithValue(controller),
      appSettingsCommandsProvider.overrideWithValue(commands),
    ],
  );
  commands.bindSecurityHandlers(
    setAllowUntrustedProxyCertificates: (value) {
      container.read(appSettingsProvider.notifier).mutate((c) {
        return c.setAllowUntrustedProxyCertificates(value);
      });
      onProxyChanged?.call(value);
    },
    setAllowUntrustedSubscriptionCertificates: (value) {
      container.read(appSettingsProvider.notifier).mutate((c) {
        return c.setAllowUntrustedSubscriptionCertificates(value);
      });
      onSubscriptionChanged?.call(value);
    },
  );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SettingsSecurityPage(),
    ),
  );
}

void main() {
  testWidgets('proxy certificate override requires confirmation', (
    tester,
  ) async {
    final values = <bool>[];
    await tester.pumpWidget(_securityApp(onProxyChanged: values.add));

    await tester.tap(
      find.byKey(const ValueKey('security-untrusted-proxy-certificates')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Allow untrusted proxy certificates?'), findsOneWidget);
    expect(values, isEmpty);

    await tester.tap(find.byKey(const ValueKey('security-confirm-proxy')));
    await tester.pumpAndSettle();

    expect(values, [true]);
  });

  testWidgets('subscription certificate override can be cancelled', (
    tester,
  ) async {
    final values = <bool>[];
    await tester.pumpWidget(_securityApp(onSubscriptionChanged: values.add));

    await tester.tap(
      find.byKey(
        const ValueKey('security-untrusted-subscription-certificates'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(values, isEmpty);
  });

  testWidgets('disabling an override is immediate', (tester) async {
    final values = <bool>[];
    await tester.pumpWidget(
      _securityApp(allowProxy: true, onProxyChanged: values.add),
    );

    await tester.tap(
      find.byKey(const ValueKey('security-untrusted-proxy-certificates')),
    );
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    expect(values, [false]);
  });

  testWidgets('security copy is localized in Russian', (tester) async {
    await tester.pumpWidget(_securityApp(locale: const Locale('ru')));

    expect(find.text('Безопасность'), findsOneWidget);
    expect(
      find.text('Разрешать недоверенные сертификаты прокси'),
      findsOneWidget,
    );
    expect(
      find.text('Разрешать недоверенные сертификаты подписок'),
      findsOneWidget,
    );
  });

  testWidgets('risk explanations are shown only in confirmation dialogs', (
    tester,
  ) async {
    await tester.pumpWidget(_securityApp());

    final switches = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switches, hasLength(2));
    expect(switches.every((tile) => tile.subtitle == null), isTrue);

    await tester.tap(
      find.byKey(const ValueKey('security-untrusted-proxy-certificates')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Allow untrusted proxy certificates?'), findsOneWidget);
  });
}
