import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/features/settings/settings_network_servers_page.dart';
import 'package:meow_client/l10n/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/singbox/singbox_api.g.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

void main() {
  testWidgets('saves a mobile choice separately from Wi-Fi and memory', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? mobile;
    final writes = <(String, Object?)>[];
    var enabled = false;
    var remember = false;
    void mock(String method, void Function(List<Object?> arguments) handle) {
      final channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.meow_client.NetworkServerHostApi.$method',
        NetworkServerHostApi.pigeonChannelCodec,
      );
      messenger.setMockDecodedMessageHandler(channel, (message) async {
        final arguments = message! as List<Object?>;
        expect(arguments.first, 'profile');
        handle(arguments);
        return <Object?>[
          NetworkServerSettingsMessage(
            enabled: enabled,
            remember: remember,
            configuredWifi: 'wifi-proxy',
            configuredMobile: mobile,
          ),
        ];
      });
      addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
    }

    mock('read', (_) {});
    mock('setEnabled', (arguments) {
      enabled = arguments[1]! as bool;
      writes.add(('enabled', enabled));
    });
    mock('setRemember', (arguments) {
      remember = arguments[1]! as bool;
      writes.add(('remember', remember));
    });
    mock('setConfigured', (arguments) {
      expect(arguments[1], NetworkServerKind.mobile);
      mobile = arguments[2] as String?;
      writes.add(('mobile', mobile));
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        home: SettingsNetworkServersPage(
          loadProfile: () async => const Subscription(
            id: 'profile',
            name: 'Test profile',
            url: '',
            groups: [
              SubscriptionGroup(
                tag: 'provider-root',
                name: 'Provider selector',
                type: 'selector',
                outboundTags: ['wifi-proxy', 'mobile-proxy', 'extra', 'solo'],
                config: {
                  '_provider_root': true,
                  'outbounds': [
                    'wifi-proxy',
                    'travel-group',
                    'mobile-proxy',
                    'solo',
                  ],
                },
              ),
              SubscriptionGroup(
                tag: 'travel-group',
                name: 'LTE - Sweden',
                outboundTags: ['mobile-proxy', 'extra'],
              ),
            ],
            outbounds: [
              Outbound(
                tag: 'wifi-proxy',
                name: 'Home server',
                config: {'type': 'vless', 'server': 'example.test'},
              ),
              Outbound(
                tag: 'mobile-proxy',
                name: 'cand-07',
                config: {'type': 'vless', 'server': 'example.test'},
              ),
              Outbound(
                tag: 'extra',
                name: 'Provider node B',
                config: {'type': 'trojan', 'server': 'other.test'},
              ),
              Outbound(
                tag: 'solo',
                name: 'cand-99',
                config: {'type': 'vless', 'server': 'solo.test'},
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
    expect(find.text('cand-07'), findsNothing);
    expect(find.text('Provider node B'), findsNothing);
    expect(find.text('cand-99'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Швеция');
    await tester.pumpAndSettle();
    expect(find.text('Home server'), findsNothing);
    expect(find.text('cand-99'), findsNothing);
    expect(
      tester
          .widget<CountryFlagBadge>(find.byType(CountryFlagBadge))
          .countryCode,
      'SE',
    );
    await tester.tap(find.text('LTE - Sweden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remember manual selection'));
    await tester.pumpAndSettle();

    expect(find.text('Home server'), findsOneWidget);
    expect(find.text('LTE - Sweden'), findsOneWidget);
    expect(writes, [
      ('enabled', true),
      ('mobile', 'travel-group'),
      ('remember', true),
    ]);

    await tester.tap(find.byKey(const ValueKey('network-servers-mobile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep current server'));
    await tester.pumpAndSettle();
    expect(writes.last, ('mobile', null));
    expect(find.text('Home server'), findsOneWidget);
    expect(find.text('LTE - Sweden'), findsNothing);
  });
}
