import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/home/home_presentation_builder.dart';
import 'package:meow_client/features/home/tabbed_home_shell.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';
import 'package:meow_client/widgets/floating_navigation_insets.dart';

void main() {
  for (final style in BottomNavigationStyle.values) {
    for (final language in ['en', 'ru']) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets(
          'phone card clears compact ${style.name} bar $language scale=$scale',
          (tester) async {
            tester.view.physicalSize = const Size(393, 850);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final traffic = ValueNotifier<TrafficUiSnapshot>(
              TrafficUiSnapshot.zero,
            );
            final runtimeStates = ProxyRuntimeVisualStore();
            addTearDown(traffic.dispose);
            addTearDown(runtimeStates.dispose);
            var settingsOpened = false;
            var changelogOpened = false;
            void noop() {}
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(393, 850),
                    padding: const EdgeInsets.only(top: 32, bottom: 24),
                    viewPadding: const EdgeInsets.only(top: 32, bottom: 24),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: TabbedHomeShell(
                    bottomNavigationStyle: style,
                    homeBuilder: (context, open) =>
                        HomePresentationBuilder(
                          data: _data(
                            connected: true,
                            trafficAvailable: true,
                            traffic: traffic,
                            runtimeStates: runtimeStates,
                            populated: true,
                          ),
                          callbacks: HomePresentationCallbacks(
                            toggleConnection: noop,
                            refreshLatency: noop,
                            refreshActiveProxyIp: noop,
                            openSubscriptions: noop,
                            addSubscription: noop,
                            openSettings: () => settingsOpened = true,
                            openChangelog: () => changelogOpened = true,
                            openTrafficDashboard: noop,
                            openProxies: () => open(null),
                          ),
                        ).build(
                          tabbed: true,
                          bottomNavigationStyle: style,
                          navigationBottomInset: FloatingNavigationInsets.of(
                            context,
                          ),
                        ),
                    proxiesBuilder: (_, active, back, request) =>
                        const Text('Proxy browser'),
                    settingsBuilder: (_) => const Text('Settings destination'),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final bar = tester.getRect(
              style == BottomNavigationStyle.floating
                  ? find.byKey(const ValueKey('floating-bottom-navigation'))
                  : find.byType(NavigationBar),
            );
            expect(
              bar.height,
              style == BottomNavigationStyle.floating
                  ? greaterThanOrEqualTo(56)
                  : equals(60),
            );
            expect(
              bar.bottom,
              style == BottomNavigationStyle.floating ? 818 : 826,
            );
            final card = find.byKey(const ValueKey('home-current-proxy-card'));
            expect(
              tester.getRect(card).bottom,
              lessThanOrEqualTo(bar.top - 12),
            );
            expect(tester.takeException(), isNull);
            expect(
              tester.getSize(find.text('Etonify')).width,
              greaterThanOrEqualTo(48),
            );
            await tester.tap(find.text('0.3.0-beta.1'));
            expect(changelogOpened, isTrue);
            if (style == BottomNavigationStyle.docked) {
              await tester.tap(
                find.byTooltip(language == 'ru' ? 'Настройки' : 'Settings'),
              );
              expect(settingsOpened, isTrue);
              expect(find.byKey(const ValueKey('settings-tab')), findsNothing);
            } else {
              await tester.tap(find.byKey(const ValueKey('settings-tab')));
              await tester.pumpAndSettle();
              expect(find.text('Settings destination'), findsOneWidget);
              await tester.tap(find.byKey(const ValueKey('home-tab')));
              await tester.pumpAndSettle();
            }
            await tester.tap(card);
            await tester.pumpAndSettle();
            expect(find.text('Proxy browser'), findsOneWidget);
          },
        );
      }
    }
  }

  group('HomePresentationData', () {
    test('hides traffic metrics while the runtime is disconnected', () {
      final traffic = ValueNotifier<TrafficUiSnapshot>(TrafficUiSnapshot.zero);
      final runtimeStates = ProxyRuntimeVisualStore();
      addTearDown(traffic.dispose);
      addTearDown(runtimeStates.dispose);

      final state = _data(
        connected: false,
        trafficAvailable: true,
        traffic: traffic,
        runtimeStates: runtimeStates,
      ).toViewState();

      expect(state.speedBytesPerSecond, 0);
      expect(state.trafficBytes, 0);
    });

    test('forwards live totals only while traffic is available', () {
      final traffic = ValueNotifier<TrafficUiSnapshot>(TrafficUiSnapshot.zero);
      final runtimeStates = ProxyRuntimeVisualStore();
      addTearDown(traffic.dispose);
      addTearDown(runtimeStates.dispose);

      final state = _data(
        connected: true,
        trafficAvailable: true,
        traffic: traffic,
        runtimeStates: runtimeStates,
      ).toViewState();

      expect(state.speedBytesPerSecond, 1536);
      expect(state.trafficBytes, 7168);
      expect(state.trafficListenable, same(traffic));
    });
  });
}

HomePresentationData _data({
  required bool connected,
  required bool trafficAvailable,
  required ValueNotifier<TrafficUiSnapshot> traffic,
  required ProxyRuntimeVisualStore runtimeStates,
  bool populated = false,
}) {
  return HomePresentationData(
    connected: connected,
    connecting: false,
    resolvingProxy: false,
    connectionStatusLabel: '',
    activeProfile: populated
        ? const AppProfileSummary(
            id: 'test',
            name: 'Test subscription',
            consumed: 10,
            total: 100,
            remainingDays: 30,
            outboundsCount: 1,
            sourceLabel: 'test',
          )
        : null,
    activeProxy: populated
        ? const AppProxySummary(
            tag: 'test-proxy',
            displayName: 'Test server',
            countryCode: 'DE',
            type: 'vless',
            server: 'test.example.com',
            port: 443,
            detailText: 'VLESS',
            ip: '',
            latency: 32,
            latencyFresh: true,
            latencyChecking: false,
            latencyUnavailable: false,
            latencyError: null,
            protocolLabel: 'VLESS',
            endpointLabel: 'test.example.com',
          )
        : null,
    runtimeStates: runtimeStates,
    hideServerIp: false,
    hapticEnabled: true,
    trafficAvailable: trafficAvailable,
    downlinkBytesPerSecond: 1536,
    uplinkTotalBytes: 2048,
    downlinkTotalBytes: 5120,
    trafficListenable: traffic,
    activeProfileRefreshing: false,
    showActiveProfileRefreshAction: false,
    brandName: 'Etonify',
    versionLabel: '0.3.0-beta.1',
    prereleaseVersion: true,
  );
}
