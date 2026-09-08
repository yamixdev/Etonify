import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/settings/settings_core_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/core_settings.dart';
import 'package:meow_client/models/subscription.dart';

Widget app({
  CoreSettings settings = const CoreSettings(),
  bool notice = true,
  bool vpn = true,
  Future<void> Function()? acknowledge,
  Future<bool> Function(CoreSettings)? apply,
  Subscription? subscription,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: SettingsCorePage(
    settings: settings,
    vpnInboundEnabled: vpn,
    noticeAcknowledged: notice,
    onAcknowledgeNotice: acknowledge ?? () async {},
    onApply: apply ?? (_) async => true,
    subscription: subscription,
  ),
);
Future<void> reveal(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'multiplex picker excludes group internals regardless of their name',
    (tester) async {
      const subscription = Subscription(
        id: 'p',
        name: 'Provider',
        url: '',
        groups: [
          SubscriptionGroup(
            tag: 'auto',
            name: 'Automatic',
            outboundTags: ['internal'],
          ),
        ],
        outbounds: [
          Outbound(
            tag: 'internal',
            name: 'Ordinary-looking name',
            config: {'type': 'trojan'},
          ),
          Outbound(
            tag: 'hidden',
            name: 'Hidden',
            config: {'type': 'trojan', '_group_only': true},
          ),
          Outbound(
            tag: 'visible',
            name: 'Visible server',
            config: {'type': 'trojan'},
          ),
        ],
      );
      await tester.pumpWidget(app(subscription: subscription));
      await tester.pumpAndSettle();
      await reveal(tester, 'core-mux-server');
      await tester.tap(find.byKey(const ValueKey('core-mux-server')));
      await tester.pumpAndSettle();
      expect(find.text('Visible server'), findsOneWidget);
      expect(find.text('Ordinary-looking name'), findsNothing);
      expect(find.text('Hidden'), findsNothing);
    },
  );

  testWidgets(
    'numeric input rejects out-of-range values and accepts zero inheritance',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('core-connectTimeoutSeconds')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '9999');
      await tester.tap(find.widgetWithText(FilledButton, 'Apply').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Enter an integer within the displayed range.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Apply').last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await reveal(tester, 'core-apply');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('core-apply')))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'notice is acknowledged once; saved acknowledgement suppresses it',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(
        app(
          notice: false,
          acknowledge: () async {
            count++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Before changing these settings'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(count, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Before changing these settings'), findsNothing);
    },
  );
  testWidgets('edits are a draft and apply once; failures retain draft', (
    tester,
  ) async {
    var count = 0;
    CoreSettings? applied;
    await tester.pumpWidget(
      app(
        apply: (value) async {
          count++;
          applied = value;
          return false;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('core-networkStrategy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hybrid'));
    await tester.pumpAndSettle();
    expect(count, 0);
    await reveal(tester, 'core-apply');
    await tester.tap(find.byKey(const ValueKey('core-apply')));
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(applied!.networkStrategy, CoreNetworkStrategy.hybrid);
    expect(find.textContaining('Could not apply'), findsOneWidget);
    await reveal(tester, 'core-apply');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('core-apply')))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('reset submits defaults and cannot double submit while saving', (
    tester,
  ) async {
    final done = Completer<bool>();
    var count = 0;
    await tester.pumpWidget(
      app(
        settings: const CoreSettings(connectTimeoutSeconds: 12),
        apply: (value) {
          count++;
          expect(value, const CoreSettings());
          return done.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('core-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset core settings'));
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('core-reset')))
          .onPressed,
      isNull,
    );
    done.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Core settings applied'), findsOneWidget);
  });
  testWidgets(
    'NAT is disabled without VPN inbound and narrow layout has no overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(vpn: false));
      await tester.pumpAndSettle();
      await reveal(tester, 'core-udpMapping');
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('core-udpMapping')))
            .enabled,
        false,
      );
      await reveal(tester, 'core-apply');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('provider multiplex is shown read-only until explicit override', (
    tester,
  ) async {
    const subscription = Subscription(
      id: 'p',
      name: 'Provider',
      url: '',
      outbounds: [
        Outbound(
          tag: 'one',
          name: 'Node',
          config: {
            'type': 'trojan',
            'multiplex': {'enabled': true, 'protocol': 'smux'},
          },
        ),
      ],
    );
    await tester.pumpWidget(app(subscription: subscription));
    await tester.pumpAndSettle();
    await reveal(tester, 'core-mux-server');
    await tester.tap(find.byKey(const ValueKey('core-mux-server')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Node'));
    await tester.pumpAndSettle();
    await reveal(tester, 'core-mux-protocol');
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('core-mux-protocol')))
          .enabled,
      false,
    );
    await reveal(tester, 'core-mux-mode');
    await tester.tap(find.byKey(const ValueKey('core-mux-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    expect(find.text('Override server settings?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    await reveal(tester, 'core-mux-protocol');
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('core-mux-protocol')))
          .enabled,
      false,
    );
  });
}
