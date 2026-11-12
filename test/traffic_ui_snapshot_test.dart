import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/features/home/home_page.dart';
import 'package:meow_client/features/home/home_presentation.dart';
import 'package:meow_client/l10n/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';

void main() {
  testWidgets('traffic notifier updates footer without rebuilding app state', (
    tester,
  ) async {
    final traffic = ValueNotifier<TrafficUiSnapshot>(TrafficUiSnapshot.zero);
    addTearDown(traffic.dispose);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: HomePage(
          state: HomeViewState(
            connected: true,
            connecting: false,
            resolvingProxy: false,
            connectionStatusLabel: '',
            activeProfile: const AppProfileSummary(
              id: 'sub',
              name: 'Subscription',
              consumed: 0,
              total: 0,
              remainingDays: null,
              outboundsCount: 1,
              sourceLabel: '',
            ),
            activeProxy: const AppProxySummary(
              tag: 'proxy',
              displayName: 'Germany',
              countryCode: 'DE',
              type: 'vless',
              server: 'example.com',
              port: 443,
              detailText: 'VLESS',
              ip: '1.1.1.1',
              latency: 42,
              latencyFresh: true,
              latencyChecking: false,
              latencyUnavailable: false,
              latencyError: null,
              protocolLabel: 'VLESS',
              endpointLabel: 'example.com:443',
            ),
            hideServerIp: false,
            hapticEnabled: false,
            speedBytesPerSecond: 0,
            trafficBytes: 0,
            trafficListenable: traffic,
            brandName: 'Etonify',
            versionLabel: '0.2.2',
          ),
          actions: HomeViewActions(
            toggleConnection: () {},
            refreshLatency: () {},
            openSubscriptions: () {},
            addSubscription: () {},
            openSettings: () {},
            openChangelog: () {},
          ),
          bottomInset: 0,
        ),
      ),
    );

    traffic.value = const TrafficUiSnapshot(
      speedBytesPerSecond: 2048,
      trafficBytes: 4096,
    );
    await tester.pump();

    expect(find.text('2.00 KB/s'), findsOneWidget);
    expect(find.text('4.00 KB'), findsOneWidget);
  });
}
