import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_inbound_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('header status follows the selected connection mode', (
    tester,
  ) async {
    InboundConnectionMode? selectedMode;
    String? changedUsername;

    await tester.binding.setSurfaceSize(const Size(420, 1200));
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
        home: SettingsInboundPage(
          currentVpnInboundEnabled: true,
          currentVpnMtu: 1500,
          currentVpnStrictRoute: true,
          currentVpnTunImplementation: TunImplementationPreference.mixed,
          currentProxyInboundEnabled: false,
          currentProxyAllowLan: false,
          currentProxyMixedListen: '127.0.0.1',
          currentProxyMixedPort: 1080,
          currentProxyUsername: defaultProxyUsername,
          currentProxyPassword: '',
          onConnectionModeChanged: (mode) => selectedMode = mode,
          onVpnMtuChanged: (_) {},
          onVpnStrictRouteChanged: (_) {},
          onVpnTunImplementationChanged: (_) {},
          onProxyInboundEnabledChanged: (_) {},
          onProxyAllowLanChanged: (_) {},
          onProxyMixedPortChanged: (_) {},
          onProxyUsernameChanged: (value) => changedUsername = value,
          onProxyPasswordChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Активно: VPN TUN'), findsOneWidget);
    await tester.tap(find.text('Расширенные параметры TUN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Смешанный (Mixed)'), findsOneWidget);
    expect(
      find.textContaining('TCP обрабатывает системный стек Android'),
      findsOneWidget,
    );

    final mixedDescription = find.textContaining('Смешанный (Mixed)');
    final mixedTile = find.ancestor(
      of: mixedDescription,
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(mixedTile);
    await tester.tap(mixedTile);
    await tester.pumpAndSettle();
    expect(find.text('Системный (System)'), findsOneWidget);
    expect(find.text('gVisor'), findsOneWidget);
    await tester.tap(find.text('Системный (System)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Прокси').first);
    await tester.pumpAndSettle();

    expect(selectedMode, InboundConnectionMode.proxy);
    expect(find.text('Активно: Прокси'), findsOneWidget);
    expect(find.text('Активно: VPN TUN'), findsNothing);

    await tester.scrollUntilVisible(
      find.text(defaultProxyUsername),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(defaultProxyUsername));
    await tester.pumpAndSettle();

    expect(
      find.text('От 1 до 64 символов, без пробелов и двоеточия'),
      findsOne,
    );
    await tester.enterText(find.byType(TextField).last, 'sergey');
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();

    expect(changedUsername, 'sergey');
    expect(find.text('sergey'), findsOneWidget);
  });
}
