import 'package:circle_flags/circle_flags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/features/home/public_ip_controller.dart';
import 'package:meow_client/features/home/server_network_card.dart';
import 'package:meow_client/features/home/traffic_dashboard_page.dart';
import 'package:meow_client/l10n/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/server_connection_info.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

Widget app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('circular unknown-country fallback preserves badge geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Row(
          children: [
            CountryFlagBadge(
              key: ValueKey('legacy'),
              countryCode: 'SE',
              size: 28,
            ),
            CountryFlagBadge(
              key: ValueKey('fallback'),
              countryCode: '',
              size: 28,
              circular: true,
            ),
          ],
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('legacy'))),
      const Size.square(28),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('fallback'))),
      const Size.square(28),
    );
    expect(tester.widget<CircleFlag>(find.byType(CircleFlag)).shape, isNull);
    final fallback = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('fallback')),
        matching: find.byType(Container),
      ),
    );
    expect((fallback.decoration! as BoxDecoration).shape, BoxShape.circle);
    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('server flag sits inline before exit IP and header is compact', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const SingleChildScrollView(
          child: ServerNetworkCard(
            connection: ServerConnectionInfo(
              connected: true,
              countryCode: 'SE',
              exitIp: '203.0.113.7',
            ),
            hideIp: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final flag = tester.getRect(find.byType(CountryFlagBadge));
    final ip = tester.getRect(find.text('203.0.113.7'));
    expect(flag.center.dy, closeTo(ip.center.dy, 1));
    expect(flag.right, lessThan(ip.left));
    expect(
      tester.widget<CircleFlag>(find.byType(CircleFlag)).shape,
      isA<CircleBorder>(),
    );
    final card = tester.getRect(
      find.byKey(const ValueKey('server-network-card')),
    );
    final title = tester.getRect(find.text('Server and network'));
    expect(title.top - card.top, lessThan(24));
  });

  testWidgets('device refresh is centered, 48dp and works with VPN off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final traffic = ValueNotifier(TrafficDashboardSnapshot.empty);
    var calls = 0;
    final controller = PublicIpController(
      load: () async => PublicIpInfo(
        ip: ++calls == 1 ? '203.0.113.8' : '203.0.113.9',
        countryCode: 'SE',
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(traffic.dispose);
    await tester.pumpWidget(
      app(
        TrafficDashboardPage(
          snapshotListenable: traffic,
          publicIpController: controller,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    final refresh = find.byKey(const ValueKey('public-ip-refresh'));
    final glyph = find.descendant(
      of: refresh,
      matching: find.byIcon(Icons.refresh_rounded),
    );
    final buttonRect = tester.getRect(refresh);
    expect(buttonRect.width, greaterThanOrEqualTo(48));
    expect(buttonRect.height, greaterThanOrEqualTo(48));
    expect(tester.getCenter(glyph), buttonRect.center);
    final title = tester.getRect(find.text('External IP'));
    expect(title.center.dy, closeTo(buttonRect.center.dy, 1));
    await tester.tapAt(tester.getCenter(glyph));
    await tester.pump();
    expect(find.text('203.0.113.9'), findsOneWidget);
    expect(find.text('203.0.113.8'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('VPN off retains endpoint but never presents old exit IP', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const SingleChildScrollView(
          child: ServerNetworkCard(
            connection: ServerConnectionInfo(
              exitIp: '203.0.113.7',
              countryCode: 'SE',
              endpointHost: 'entry.example',
              protocol: 'VLESS',
            ),
            hideIp: false,
          ),
        ),
      ),
    );
    expect(find.text('entry.example'), findsOneWidget);
    expect(find.text('VLESS'), findsOneWidget);
    expect(find.text('203.0.113.7'), findsNothing);
    expect(find.byType(CountryFlagBadge), findsNothing);
  });

  testWidgets('failed device lookup labels the retained address as cached', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final traffic = ValueNotifier(TrafficDashboardSnapshot.empty);
    var calls = 0;
    final controller = PublicIpController(
      load: () async {
        if (++calls > 1) throw StateError('offline');
        return const PublicIpInfo(ip: '203.0.113.8', countryCode: 'SE');
      },
    );
    addTearDown(controller.dispose);
    addTearDown(traffic.dispose);
    await tester.pumpWidget(
      app(
        TrafficDashboardPage(
          snapshotListenable: traffic,
          publicIpController: controller,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byKey(const ValueKey('public-ip-refresh')));
    await tester.pump();
    final l10n = AppLocalizations.of(tester.element(find.text('External IP')));
    expect(find.text('203.0.113.8'), findsOneWidget);
    expect(find.text(l10n.trafficDashboardPublicIpCached), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  });
}
