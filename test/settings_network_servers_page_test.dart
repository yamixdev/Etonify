import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/features/settings/settings_network_servers_page.dart';
import 'package:meow_client/l10n/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  testWidgets('saves a mobile choice separately from Wi-Fi and memory', (
    tester,
  ) async {
    const channel = MethodChannel('com.etonify.meow_client/network_servers');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final configured = <String, String>{'wifi': 'wifi-proxy'};
    final writes = <(String, Object?)>[];
    var enabled = false;
    var remember = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments as Map<Object?, Object?>;
      expect(arguments['profileId'], 'profile');
      if (call.method == 'update') {
        final field = arguments['field'] as String;
        final value = arguments['value'];
        writes.add((field, value));
        switch (field) {
          case 'enabled':
            enabled = value == true;
          case 'remember':
            remember = value == true;
          case 'mobile':
            configured[field] = value as String;
        }
      }
      return {
        'enabled': enabled,
        'remember': remember,
        'configured': configured,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        home: SettingsNetworkServersPage(
          loadProfile: () async => (
            id: 'profile',
            name: 'Test profile',
            servers: const [
              Outbound(
                tag: 'wifi-proxy',
                name: 'Home server',
                config: {'type': 'vless', 'server': 'example.test'},
              ),
              Outbound(
                tag: 'mobile-proxy',
                name: 'Travel server',
                config: {'type': 'vless', 'server': 'example.test'},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Switch by network type'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('network-servers-mobile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Travel');
    await tester.pumpAndSettle();
    expect(find.text('Home server'), findsNothing);
    await tester.tap(find.text('Travel server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remember manual selection'));
    await tester.pumpAndSettle();

    expect(find.text('Home server'), findsOneWidget);
    expect(find.text('Travel server'), findsOneWidget);
    expect(writes, [
      ('enabled', true),
      ('mobile', 'mobile-proxy'),
      ('remember', true),
    ]);
  });
}
