import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/home/home_page.dart';
import 'package:meow_client/features/home/home_presentation.dart';
import 'package:meow_client/features/home/traffic_dashboard_page.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/features/proxies/proxy_panel_shell.dart';
import 'package:meow_client/features/settings/settings_about_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/core_integration_diagnostics.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

void main() {
  testWidgets('renders cloned mobile shell', (tester) async {
    await tester.pumpWidget(
      _TestMeowClient(
        store: MemoryAppSettingsStore(
          const AppSettingsState(
            onboardingCompleted: true,
            acceptedLegalVersion: '0.2.1',
            acceptedLegalAtMillis: 1,
            activeProfileId: '',
            selectedProxyTag: '',
            localeCode: 'system',
            themePreference: AppThemePreference.system,
            accentColorHex: 'default',
            hapticEnabled: true,
            hideServerIp: false,
            progressiveBlurEnabled: true,
            vpnInboundEnabled: true,
            vpnMtu: 3400,
            vpnStrictRoute: true,
            vpnTunImplementation: TunImplementationPreference.mixed,
            proxyInboundEnabled: false,
            proxyAllowLan: false,
            proxyMixedListen: '127.0.0.1',
            proxyMixedPort: 1080,
            dnsDirectPreset: 'cloudflare',
            dnsDirectResolver: 'udp://1.1.1.1',
            dnsProxyPreset: 'cloudflare',
            dnsProxyResolver: 'https://dns.cloudflare.com/dns-query',
            dnsPreferIpv6: false,
            urlTestUrl: 'https://www.gstatic.com/generate_204',
            urlTestIntervalSeconds: 180,
            urlTestTimeoutSeconds: 15,
            urlTestConcurrency: 30,
            urlTestUnavailableCheckIntervalSeconds: 2,
            locationLookupLimit: 12,
            locationLookupTimeoutSeconds: 6,
            locationLookupConcurrency: 16,
            blockLeaks: false,
            adBlockEnabled: false,
            useRussiaRouteData: false,
            bypassLocalNetwork: true,
            splitRoutingMode: SplitRoutingMode.disabled,
            splitRoutingPackages: <String>[],
            singBoxLogLevel: 'info',
            experimentalTcpFastOpen: true,
            experimentalTcpMultiPath: true,
            experimentalInterruptExistingConnections: true,
            experimentalUrlTestStrictTolerance: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Etonify'), findsOneWidget);
    expect(find.text('MeowVPN'), findsNothing);
    expect(find.text('No subscriptions yet'), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });

  testWidgets('welcome uses Etonify before onboarding is completed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestMeowClient(
        store: MemoryAppSettingsStore(
          const AppSettingsState(
            onboardingCompleted: false,
            activeProfileId: '',
            selectedProxyTag: '',
            localeCode: 'system',
            themePreference: AppThemePreference.system,
            accentColorHex: 'default',
            hapticEnabled: true,
            hideServerIp: false,
            progressiveBlurEnabled: true,
            vpnInboundEnabled: true,
            vpnMtu: 3400,
            vpnStrictRoute: true,
            vpnTunImplementation: TunImplementationPreference.mixed,
            proxyInboundEnabled: false,
            proxyAllowLan: false,
            proxyMixedListen: '127.0.0.1',
            proxyMixedPort: 1080,
            dnsDirectPreset: 'cloudflare',
            dnsDirectResolver: 'udp://1.1.1.1',
            dnsProxyPreset: 'cloudflare',
            dnsProxyResolver: 'https://dns.cloudflare.com/dns-query',
            dnsPreferIpv6: false,
            urlTestUrl: 'https://www.gstatic.com/generate_204',
            urlTestIntervalSeconds: 180,
            urlTestTimeoutSeconds: 15,
            urlTestConcurrency: 30,
            urlTestUnavailableCheckIntervalSeconds: 2,
            locationLookupLimit: 12,
            locationLookupTimeoutSeconds: 6,
            locationLookupConcurrency: 16,
            blockLeaks: false,
            adBlockEnabled: false,
            useRussiaRouteData: false,
            bypassLocalNetwork: true,
            splitRoutingMode: SplitRoutingMode.disabled,
            splitRoutingPackages: <String>[],
            singBoxLogLevel: 'info',
            experimentalTcpFastOpen: true,
            experimentalTcpMultiPath: true,
            experimentalInterruptExistingConnections: true,
            experimentalUrlTestStrictTolerance: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Etonify'), findsOneWidget);
    expect(find.text('No subscriptions yet'), findsNothing);
    expect(find.byIcon(Icons.settings_rounded), findsNothing);
  });

  testWidgets('opens settings page from home header', (tester) async {
    await tester.pumpWidget(
      _TestMeowClient(
        store: MemoryAppSettingsStore(
          const AppSettingsState(
            onboardingCompleted: true,
            acceptedLegalVersion: '0.2.1',
            acceptedLegalAtMillis: 1,
            activeProfileId: '',
            selectedProxyTag: '',
            localeCode: 'system',
            themePreference: AppThemePreference.system,
            accentColorHex: 'default',
            hapticEnabled: true,
            hideServerIp: false,
            progressiveBlurEnabled: true,
            vpnInboundEnabled: true,
            vpnMtu: 3400,
            vpnStrictRoute: true,
            vpnTunImplementation: TunImplementationPreference.mixed,
            proxyInboundEnabled: false,
            proxyAllowLan: false,
            proxyMixedListen: '127.0.0.1',
            proxyMixedPort: 1080,
            dnsDirectPreset: 'cloudflare',
            dnsDirectResolver: 'udp://1.1.1.1',
            dnsProxyPreset: 'cloudflare',
            dnsProxyResolver: 'https://dns.cloudflare.com/dns-query',
            dnsPreferIpv6: false,
            urlTestUrl: 'https://www.gstatic.com/generate_204',
            urlTestIntervalSeconds: 180,
            urlTestTimeoutSeconds: 15,
            urlTestConcurrency: 30,
            urlTestUnavailableCheckIntervalSeconds: 2,
            locationLookupLimit: 12,
            locationLookupTimeoutSeconds: 6,
            locationLookupConcurrency: 16,
            blockLeaks: false,
            adBlockEnabled: false,
            useRussiaRouteData: false,
            bypassLocalNetwork: true,
            splitRoutingMode: SplitRoutingMode.disabled,
            splitRoutingPackages: <String>[],
            singBoxLogLevel: 'info',
            experimentalTcpFastOpen: true,
            experimentalTcpMultiPath: true,
            experimentalInterruptExistingConnections: true,
            experimentalUrlTestStrictTolerance: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('proxy panel shell opens and collapses with local state', (
    tester,
  ) async {
    var closeCount = 0;
    var openedCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, rebuildHost) => ProxyPanelShell(
            ready: true,
            onboardingCompleted: true,
            loading: const SizedBox.shrink(),
            welcome: const SizedBox.shrink(),
            visibleRows: 20,
            hasActiveProfile: true,
            onOpenRequested: () => rebuildHost(() {}),
            onOpened: () => openedCount++,
            onClosed: () => closeCount++,
            homeBuilder: (context, metrics, gestures) {
              return ColoredBox(
                color: Colors.white,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text('home:${metrics.progress.toStringAsFixed(2)}'),
                ),
              );
            },
            sheetBuilder:
                (
                  context,
                  metrics,
                  metricsListenable,
                  scrollController,
                  gestures,
                ) {
                  return Material(
                    child: ValueListenableBuilder<ProxyPanelMetrics>(
                      valueListenable: metricsListenable,
                      builder: (context, liveMetrics, _) {
                        return GestureDetector(
                          key: const ValueKey('proxy-panel-header'),
                          behavior: HitTestBehavior.opaque,
                          onTap: gestures.onHeaderTap,
                          child: ListView.builder(
                            controller: scrollController,
                            padding: EdgeInsets.zero,
                            itemCount: 24,
                            itemBuilder: (context, index) => SizedBox(
                              height: index == 0 ? proxyPanelMinHeight : 48,
                              child: Text(
                                index == 0
                                    ? 'panel:${liveMetrics.progress.toStringAsFixed(2)}'
                                    : 'proxy-$index',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
          ),
        ),
      ),
    );

    expect(find.text('panel:0.00'), findsOneWidget);
    expect(closeCount, 0);

    final partialOpen = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('proxy-panel-header'))),
    );
    await partialOpen.moveBy(const Offset(0, -70));
    await tester.pump();
    expect(find.text('panel:0.00'), findsNothing);
    await partialOpen.up();
    await tester.pumpAndSettle();

    expect(find.text('panel:1.00'), findsOneWidget);
    expect(openedCount, 1);

    await tester.tap(find.byKey(const ValueKey('proxy-panel-header')));
    await tester.pumpAndSettle();

    expect(find.text('panel:0.00'), findsOneWidget);
    expect(closeCount, 1);

    await tester.tap(find.byKey(const ValueKey('proxy-panel-header')));
    await tester.pumpAndSettle();

    expect(find.text('panel:1.00'), findsOneWidget);
    expect(openedCount, 2);

    await tester.tap(find.byKey(const ValueKey('proxy-panel-header')));
    await tester.pumpAndSettle();

    expect(find.text('panel:0.00'), findsOneWidget);
    expect(closeCount, 2);
  });

  testWidgets('real proxy panel opens from the collapsed header swipe', (
    tester,
  ) async {
    final proxies = <AppProxySummary>[
      _proxy('proxy-1', 'Amsterdam', latency: 42),
      _proxy('proxy-2', 'Paris', latency: 58),
    ];
    var panelProgress = 0.0;

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(bottom: 48),
            viewPadding: const EdgeInsets.only(bottom: 48),
          ),
          child: child!,
        ),
        home: ProxyPanelShell(
          ready: true,
          onboardingCompleted: true,
          loading: const SizedBox.shrink(),
          welcome: const SizedBox.shrink(),
          visibleRows: proxies.length,
          hasActiveProfile: true,
          homeBuilder: (_, metrics, _) {
            panelProgress = metrics.progress;
            return const ColoredBox(color: Colors.white);
          },
          sheetBuilder:
              (
                context,
                metrics,
                metricsListenable,
                scrollController,
                gestures,
              ) => ValueListenableBuilder<ProxyPanelMetrics>(
                valueListenable: metricsListenable,
                builder: (context, liveMetrics, _) {
                  panelProgress = liveMetrics.progress;
                  return ProxiesPage(
                    proxies: proxies,
                    selectedTag: proxies.first.tag,
                    activeProxy: proxies.first,
                    connected: false,
                    progressiveBlurEnabled: false,
                    onSelected: (_) {},
                    onUrlTest: () async {},
                    embedded: true,
                    sheetMetricsListenable: metricsListenable,
                    scrollController: scrollController,
                    sheetAtMaxExtent: metrics.atMaxExtent,
                    sheetCanFillScreen: metrics.canFillScreen,
                    sheetExtent: metrics.progress,
                    collapsedSheetExtent: 0,
                    expandedHeaderExtent: 1,
                    onHeaderTap: gestures.onHeaderTap,
                  );
                },
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amsterdam'), findsOneWidget);
    expect(find.text('Paris'), findsNothing);

    final openGesture = await tester.startGesture(
      tester.getCenter(find.text('Amsterdam')),
    );
    var previousProgress = panelProgress;
    for (var step = 0; step < 8; step++) {
      await openGesture.moveBy(const Offset(0, -10));
      await tester.pump();
      expect(panelProgress, greaterThan(previousProgress));
      previousProgress = panelProgress;
    }
    await openGesture.up();
    await tester.pumpAndSettle();

    expect(panelProgress, greaterThan(.95));
    expect(find.text('Proxies'), findsOneWidget);
    expect(find.text('Paris'), findsOneWidget);

    await tester.drag(find.text('Proxies'), const Offset(0, 80));
    await tester.pumpAndSettle();

    expect(panelProgress, closeTo(0, .01));
    expect(find.text('Amsterdam'), findsOneWidget);
    expect(find.text('Paris'), findsNothing);

    await tester.tap(find.text('Amsterdam'));
    await tester.pumpAndSettle();
    expect(panelProgress, greaterThan(.95));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(panelProgress, closeTo(0, .01));
    expect(find.text('Amsterdam'), findsOneWidget);
    expect(find.text('Paris'), findsNothing);
  });

  testWidgets(
    'embedded proxy sheet exposes one lowest and pinned chain actions',
    (tester) async {
      String? selectedTag;
      final proxies = <AppProxySummary>[
        _proxy(lowestProxyTag, 'lowest'),
        for (var i = 0; i < 80; i++)
          _proxy('proxy-$i', 'proxy $i', latency: i + 1),
        _proxy('chain-test', 'chain · Germany', latency: 999),
      ];

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              height: 720,
              child: ProxiesPage(
                proxies: proxies,
                selectedTag: lowestProxyTag,
                connected: false,
                progressiveBlurEnabled: false,
                onSelected: (tag) => selectedTag = tag,
                onUrlTest: () async {},
                onAddProxyChain: (_, _) async {},
                isProxyChainTag: (tag) => tag == 'chain-test',
                embedded: true,
                sheetAtMaxExtent: true,
                sheetExtent: 1,
                collapsedSheetExtent: 0,
                expandedHeaderExtent: 1,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Lowest'), findsOneWidget);
      expect(find.text('Lowest · open access'), findsNothing);
      expect(find.text('Lowest · unrestricted'), findsNothing);
      expect(find.text('chain · Germany'), findsOneWidget);
      expect(find.text('+ Add proxy chain'), findsOneWidget);

      await tester.tap(find.text('Lowest'));
      await tester.pump();
      expect(selectedTag, lowestProxyTag);
    },
  );

  testWidgets('Russian proxy labels describe the fastest automatic selection', (
    tester,
  ) async {
    final lowest = _proxy(lowestProxyTag, 'lowest · Finland', latency: 73)
        .copyWith(
          selectedChildName: 'Финляндия',
          protocolLabel: 'URLTest · VLESS · TLS',
        );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Column(
            children: [ProxyTile(proxy: lowest, selected: false, onTap: () {})],
          ),
        ),
      ),
    );

    expect(find.text('Самый быстрый · Финляндия'), findsOneWidget);
    expect(find.text('Автовыбор · VLESS · TLS'), findsOneWidget);
  });

  testWidgets('large proxy list exposes every server through lazy scrolling', (
    tester,
  ) async {
    final proxies = <AppProxySummary>[
      for (var i = 0; i < 80; i++)
        _proxy('proxy-$i', 'proxy $i', latency: i + 1),
    ];
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            height: 720,
            child: ProxiesPage(
              proxies: proxies,
              selectedTag: 'proxy-0',
              connected: false,
              progressiveBlurEnabled: false,
              onSelected: (_) {},
              onUrlTest: () async {},
              embedded: true,
              sheetAtMaxExtent: true,
              sheetExtent: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text('proxy 79'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('proxy 79'),
      600,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('proxy 79'), findsOneWidget);
  });

  testWidgets('collapsed proxy panel releases mounted runtime rows', (
    tester,
  ) async {
    final runtimeStates = ProxyRuntimeVisualStore();
    final metrics = ValueNotifier<ProxyPanelMetrics>(
      _proxyPanelMetrics(progress: 1, atMaxExtent: true),
    );
    addTearDown(runtimeStates.dispose);
    addTearDown(metrics.dispose);
    final proxies = <AppProxySummary>[
      for (var i = 0; i < 80; i++)
        _proxy('proxy-$i', 'proxy $i', latency: i + 1),
    ];

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            height: 720,
            child: ProxiesPage(
              proxies: proxies,
              selectedTag: 'proxy-0',
              connected: false,
              progressiveBlurEnabled: false,
              onSelected: (_) {},
              onUrlTest: () async {},
              embedded: true,
              sheetMetricsListenable: metrics,
              sheetAtMaxExtent: true,
              sheetExtent: 1,
              collapsedSheetExtent: 0,
              expandedHeaderExtent: 1,
              runtimeStates: runtimeStates,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(runtimeStates.retainedNotifierCount, greaterThan(0));

    metrics.value = _proxyPanelMetrics(progress: 0, atMaxExtent: false);
    await tester.pump();
    await tester.pump();
    runtimeStates.pruneUnobserved();

    expect(runtimeStates.retainedNotifierCount, 0);
  });

  testWidgets('embedded proxy list uses SVG flag badges when expanded', (
    tester,
  ) async {
    final proxies = <AppProxySummary>[
      _proxy('proxy-1', 'proxy 1', latency: 42),
      _proxy('proxy-2', 'proxy 2', latency: 84),
    ];

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            height: 720,
            child: ProxiesPage(
              proxies: proxies,
              selectedTag: 'proxy-1',
              connected: false,
              progressiveBlurEnabled: false,
              onSelected: (_) {},
              onUrlTest: () async {},
              embedded: true,
              sheetAtMaxExtent: true,
              sheetExtent: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CountryFlagBadge), findsWidgets);
    expect(find.text('proxy 1'), findsOneWidget);
  });

  testWidgets('proxy sheet header crossfades active proxy and title', (
    tester,
  ) async {
    final activeProxy = _proxy(
      'active-proxy',
      'Active Poland',
      latency: 96,
    ).copyWith(ip: '57.128.200.35');
    final proxies = <AppProxySummary>[
      _proxy('proxy-1', 'Austria', latency: 42),
      _proxy('proxy-2', 'Germany', latency: 84),
    ];

    Future<void> pumpAt(double extent) async {
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              height: 720,
              child: ProxiesPage(
                proxies: proxies,
                selectedTag: 'proxy-1',
                activeProxy: activeProxy,
                connected: true,
                progressiveBlurEnabled: false,
                onSelected: (_) {},
                onUrlTest: () async {},
                embedded: true,
                sheetAtMaxExtent: extent >= 1,
                sheetExtent: extent,
                collapsedSheetExtent: 0,
                expandedHeaderExtent: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    double opacityFor(String label) {
      return tester
          .widget<Opacity>(
            find
                .ancestor(of: find.text(label), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
    }

    await pumpAt(.20);
    expect(find.text('Active Poland'), findsOneWidget);
    expect(opacityFor('Active Poland'), greaterThan(0));
    expect(opacityFor('Proxies'), 0);

    await pumpAt(.42);
    expect(opacityFor('Active Poland'), 0);
    expect(opacityFor('Proxies'), 0);

    await pumpAt(.70);
    expect(opacityFor('Active Poland'), 0);
    expect(opacityFor('Proxies'), greaterThan(0));
  });

  testWidgets('closed proxy panel does not build proxy rows', (tester) async {
    final proxies = <AppProxySummary>[
      _proxy('proxy-1', 'proxy 1', latency: 42),
      _proxy('proxy-2', 'proxy 2', latency: 84),
    ];

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            height: 720,
            child: ProxiesPage(
              proxies: proxies,
              selectedTag: 'proxy-1',
              activeProxy: proxies.first,
              connected: false,
              progressiveBlurEnabled: false,
              onSelected: (_) {},
              onUrlTest: () async {},
              embedded: true,
              sheetAtMaxExtent: false,
              sheetExtent: 0,
            ),
          ),
        ),
      ),
    );

    expect(find.text('proxy 1'), findsOneWidget);
    expect(find.text('proxy 2'), findsNothing);
  });

  testWidgets(
    'embedded proxy row keeps checking feedback until latency arrives',
    (tester) async {
      final proxies = <AppProxySummary>[
        _proxy('proxy-1', 'proxy 1', latency: 42),
      ];
      final runtimeStates = ProxyRuntimeVisualStore();
      addTearDown(runtimeStates.dispose);

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              height: 720,
              child: ProxiesPage(
                proxies: proxies,
                selectedTag: 'proxy-1',
                connected: false,
                progressiveBlurEnabled: false,
                onSelected: (_) {},
                onUrlTest: () async {},
                embedded: true,
                sheetAtMaxExtent: true,
                sheetExtent: 1,
                runtimeStates: runtimeStates,
              ),
            ),
          ),
        ),
      );

      expect(find.text('42 ms'), findsOneWidget);

      runtimeStates.replaceAll(const <String, ProxyRuntimeVisualState>{
        'proxy-1': ProxyRuntimeVisualState(latency: 7, latencyFresh: true),
      });
      await tester.pump();

      expect(find.text('7 ms'), findsOneWidget);

      runtimeStates.replaceAll(const <String, ProxyRuntimeVisualState>{
        'proxy-1': ProxyRuntimeVisualState(
          latency: 7,
          latencyFresh: true,
          latencyChecking: true,
        ),
      });
      await tester.pump();

      expect(find.text('7 ms'), findsNothing);
      expect(find.text('—'), findsNothing);
      expect(find.text('.'), findsOneWidget);

      runtimeStates.replaceAll(const <String, ProxyRuntimeVisualState>{
        'proxy-1': ProxyRuntimeVisualState(latency: 9, latencyFresh: true),
      });
      await tester.pump();

      expect(find.text('9 ms'), findsOneWidget);
    },
  );

  testWidgets(
    'embedded proxy row hides transient URLTest details from the list',
    (tester) async {
      final proxies = <AppProxySummary>[
        _proxy('proxy-1', 'proxy 1', latency: 42),
      ];
      final runtimeStates = ProxyRuntimeVisualStore();
      addTearDown(runtimeStates.dispose);

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              height: 720,
              child: ProxiesPage(
                proxies: proxies,
                selectedTag: 'proxy-1',
                connected: true,
                progressiveBlurEnabled: false,
                onSelected: (_) {},
                onUrlTest: () async {},
                embedded: true,
                sheetAtMaxExtent: true,
                sheetExtent: 1,
                runtimeStates: runtimeStates,
              ),
            ),
          ),
        ),
      );

      runtimeStates.replaceAll(const <String, ProxyRuntimeVisualState>{
        'proxy-1': ProxyRuntimeVisualState(
          latencyError: 'unexpected EOF',
          latencyUnavailable: false,
        ),
      });
      await tester.pump();

      expect(find.text('EOF'), findsNothing);
      expect(find.text('No result'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Tooltip && widget.message == 'unexpected EOF',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('embedded proxy row marks a confirmed unavailable server', (
    tester,
  ) async {
    final proxies = <AppProxySummary>[_proxy('proxy-1', 'proxy 1')];
    final runtimeStates = ProxyRuntimeVisualStore();
    addTearDown(runtimeStates.dispose);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            height: 720,
            child: ProxiesPage(
              proxies: proxies,
              selectedTag: 'proxy-1',
              connected: true,
              progressiveBlurEnabled: false,
              onSelected: (_) {},
              onUrlTest: () async {},
              embedded: true,
              sheetAtMaxExtent: true,
              sheetExtent: 1,
              runtimeStates: runtimeStates,
            ),
          ),
        ),
      ),
    );

    runtimeStates.replaceAll(const <String, ProxyRuntimeVisualState>{
      'proxy-1': ProxyRuntimeVisualState(
        latencyError: 'lookup failed',
        latencyUnavailable: true,
      ),
    });
    await tester.pump();

    expect(find.text('DNS'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets(
    'latency sort follows runtime updates without replacing the proxy list',
    (tester) async {
      final proxies = <AppProxySummary>[
        _proxy('old-fast', 'Old fast', latency: 1),
        _proxy('healthy', 'Healthy', latency: 50),
      ];
      final runtimeStates = ProxyRuntimeVisualStore();
      addTearDown(runtimeStates.dispose);

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              height: 720,
              child: ProxiesPage(
                proxies: proxies,
                selectedTag: 'healthy',
                connected: true,
                initialSort: ProxySort.latency,
                progressiveBlurEnabled: false,
                onSelected: (_) {},
                onUrlTest: () async {},
                embedded: true,
                sheetAtMaxExtent: true,
                sheetExtent: 1,
                runtimeStates: runtimeStates,
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('Old fast')).dy,
        lessThan(tester.getTopLeft(find.text('Healthy')).dy),
      );

      runtimeStates.replaceAll(const <String, ProxyRuntimeVisualState>{
        'old-fast': ProxyRuntimeVisualState(
          latencyUnavailable: true,
          latencyError: 'i/o timeout',
        ),
        'healthy': ProxyRuntimeVisualState(latency: 25, latencyFresh: true),
      });
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(
        tester.getTopLeft(find.text('Healthy')).dy,
        lessThan(tester.getTopLeft(find.text('Old fast')).dy),
      );
    },
  );

  testWidgets(
    'working-only proxy mode hides failed rows and restores recovered rows',
    (tester) async {
      final proxies = <AppProxySummary>[
        _proxy('healthy', 'Healthy', latency: 40),
        _proxy('failed', 'Failed', latency: 20),
      ];
      final runtimeStates = ProxyRuntimeVisualStore();
      addTearDown(runtimeStates.dispose);

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              height: 720,
              child: ProxiesPage(
                proxies: proxies,
                selectedTag: 'healthy',
                connected: true,
                initialSort: ProxySort.working,
                progressiveBlurEnabled: false,
                onSelected: (_) {},
                onUrlTest: () async {},
                embedded: true,
                sheetAtMaxExtent: true,
                sheetExtent: 1,
                runtimeStates: runtimeStates,
              ),
            ),
          ),
        ),
      );

      runtimeStates.replaceAll(const <String, ProxyRuntimeVisualState>{
        'healthy': ProxyRuntimeVisualState(latency: 40, latencyFresh: true),
        'failed': ProxyRuntimeVisualState(
          latencyUnavailable: true,
          latencyError: 'i/o timeout',
        ),
      });
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Healthy'), findsOneWidget);
      expect(find.text('Failed'), findsNothing);

      runtimeStates.replaceAll(const <String, ProxyRuntimeVisualState>{
        'healthy': ProxyRuntimeVisualState(latency: 40, latencyFresh: true),
        'failed': ProxyRuntimeVisualState(latency: 62, latencyFresh: true),
      });
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Failed'), findsOneWidget);
    },
  );

  testWidgets(
    'embedded proxy row shows switching feedback from runtime notifier',
    (tester) async {
      final proxies = <AppProxySummary>[
        _proxy('proxy-1', 'proxy 1', latency: 42),
      ];
      final runtimeStates = ProxyRuntimeVisualStore();
      addTearDown(runtimeStates.dispose);

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              height: 720,
              child: ProxiesPage(
                proxies: proxies,
                selectedTag: 'proxy-1',
                connected: true,
                progressiveBlurEnabled: false,
                onSelected: (_) {},
                onUrlTest: () async {},
                embedded: true,
                sheetAtMaxExtent: true,
                sheetExtent: 1,
                runtimeStates: runtimeStates,
              ),
            ),
          ),
        ),
      );

      runtimeStates.replaceAll(const <String, ProxyRuntimeVisualState>{
        'proxy-1': ProxyRuntimeVisualState(selecting: true),
      });
      await tester.pump();

      expect(find.text('Switching'), findsOneWidget);
    },
  );

  testWidgets('embedded proxy rows use larger flag hit visuals', (
    tester,
  ) async {
    final proxies = <AppProxySummary>[
      _proxy('proxy-1', 'proxy 1', latency: 42),
    ];

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            height: 720,
            child: ProxiesPage(
              proxies: proxies,
              selectedTag: 'proxy-1',
              connected: false,
              progressiveBlurEnabled: false,
              onSelected: (_) {},
              onUrlTest: () async {},
              embedded: true,
              sheetAtMaxExtent: true,
              sheetExtent: 1,
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(CountryFlagBadge).first).height, 36);
  });

  testWidgets('shows no proxies empty state for an empty proxy list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: ProxiesPage(
            proxies: const [],
            selectedTag: '',
            connected: false,
            progressiveBlurEnabled: false,
            onSelected: (_) {},
            onUrlTest: () async {},
          ),
        ),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.noProxies), findsOneWidget);
    expect(find.text('No subscriptions yet'), findsNothing);
  });

  testWidgets('active proxy delay indicator keeps visual ping tap target', (
    tester,
  ) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: ActiveProxyDelayIndicator(
              connected: true,
              proxy: _proxy('proxy-1', 'proxy 1', latency: 42),
              onRefresh: () => refreshCount++,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(FluentIcons.wifi_1_24_regular), findsOneWidget);

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(refreshCount, 1);
  });

  testWidgets('active proxy delay indicator is inactive when disconnected', (
    tester,
  ) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: ActiveProxyDelayIndicator(
              connected: false,
              proxy: _proxy('proxy-1', 'proxy 1', latency: 42),
              onRefresh: () => refreshCount++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell), warnIfMissed: false);
    await tester.pump();

    expect(refreshCount, 0);
  });

  testWidgets('home latency updates through the runtime visual store', (
    tester,
  ) async {
    final runtimeStates = ProxyRuntimeVisualStore();
    addTearDown(runtimeStates.dispose);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: HomePage(
          state: HomeViewState(
            connected: true,
            connecting: false,
            resolvingProxy: false,
            connectionStatusLabel: '',
            activeProfile: const AppProfileSummary(
              id: 'sub-1',
              name: 'Main subscription',
              consumed: 0,
              total: 0,
              remainingDays: null,
              outboundsCount: 1,
              sourceLabel: '',
            ),
            activeProxy: _proxy('proxy-1', 'proxy 1', latency: 42),
            runtimeStates: runtimeStates,
            hideServerIp: false,
            hapticEnabled: false,
            speedBytesPerSecond: 0,
            trafficBytes: 0,
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
          showActiveProxyFooter: false,
        ),
      ),
    );

    expect(find.text('42 ms', findRichText: true), findsOneWidget);

    runtimeStates.replaceAll(const <String, ProxyRuntimeVisualState>{
      'proxy-1': ProxyRuntimeVisualState(latency: 73, latencyFresh: true),
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('42 ms', findRichText: true), findsNothing);
    expect(find.text('73 ms', findRichText: true), findsOneWidget);
  });

  testWidgets('active proxy footer hides IP and traffic when disconnected', (
    tester,
  ) async {
    final proxy = _proxy(
      'proxy-1',
      'Poland',
      latency: 42,
    ).copyWith(ip: '57.128.200.35');

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: ActiveProxyFooter(
              connected: false,
              proxy: proxy,
              hideIp: false,
              hapticEnabled: false,
              speedBytesPerSecond: 44 * 1024,
              trafficBytes: 96.2 * 1024 * 1024,
              unknownText: '?',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Poland'), findsOneWidget);
    expect(find.text('57.128.200.35'), findsNothing);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0.00 B/s'), findsOneWidget);
    expect(find.text('0.00 B'), findsOneWidget);
  });

  testWidgets('active proxy footer tap refreshes active IP', (tester) async {
    final proxy = _proxy(
      'proxy-1',
      'Poland',
      latency: 42,
    ).copyWith(ip: '57.128.200.35');
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: ActiveProxyFooter(
              connected: true,
              proxy: proxy,
              hideIp: false,
              hapticEnabled: false,
              speedBytesPerSecond: 0,
              trafficBytes: 0,
              unknownText: '?',
              onRefreshIp: () => refreshCount++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('57.128.200.35'));
    await tester.pump();

    expect(refreshCount, 1);
  });

  testWidgets('active proxy footer keeps cached IP visible while refreshing', (
    tester,
  ) async {
    final proxy = _proxy(
      'proxy-1',
      'Poland',
      latency: 42,
    ).copyWith(ip: '57.128.200.35', ipChecking: true);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: ActiveProxyFooter(
              connected: true,
              proxy: proxy,
              hideIp: false,
              hapticEnabled: false,
              speedBytesPerSecond: 0,
              trafficBytes: 0,
              unknownText: '?',
              onRefreshIp: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('ip-refresh-checking')), findsNothing);
    expect(find.text('57.128.200.35'), findsOneWidget);
  });

  testWidgets('active proxy delay shows progress instead of a stale value', (
    tester,
  ) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: ActiveProxyDelayIndicator(
              connected: true,
              proxy: AppProxySummary(
                tag: 'proxy-1',
                displayName: 'proxy 1',
                countryCode: 'DE',
                type: 'vless',
                server: 'proxy-1.example.com',
                port: 443,
                detailText: 'VLESS',
                ip: '',
                latency: 42,
                latencyFresh: true,
                latencyChecking: true,
                latencyUnavailable: false,
                latencyError: null,
                protocolLabel: 'VLESS',
                endpointLabel: 'proxy-1.example.com',
              ),
              onRefresh: () => refreshCount++,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('42 ms', findRichText: true), findsNothing);
    final latencyText = find.text('Checking…', findRichText: true);
    expect(latencyText, findsOneWidget);

    await tester.tap(latencyText);
    await tester.pump();

    // The tap is still forwarded while a check is running so the app can
    // explain that the current session is already in progress.
    expect(refreshCount, 1);
  });

  testWidgets('active profile refresh button calls current refresh callback', (
    tester,
  ) async {
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: HomePage(
          state: const HomeViewState(
            connected: false,
            connecting: false,
            resolvingProxy: false,
            connectionStatusLabel: '',
            activeProfile: AppProfileSummary(
              id: 'sub-1',
              name: 'Main subscription',
              consumed: 0,
              total: 0,
              remainingDays: null,
              outboundsCount: 1,
              sourceLabel: '',
            ),
            activeProxy: null,
            hideServerIp: false,
            hapticEnabled: false,
            speedBytesPerSecond: 0,
            trafficBytes: 0,
            showActiveProfileRefreshAction: true,
            brandName: 'Etonify',
            versionLabel: '0.2.1',
          ),
          actions: HomeViewActions(
            toggleConnection: () {},
            refreshLatency: () {},
            openSubscriptions: () {},
            addSubscription: () {},
            openSettings: () {},
            openChangelog: () {},
            refreshActiveSubscription: () async {
              refreshCount++;
            },
          ),
          bottomInset: 0,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.update_rounded));
    await tester.pump();

    expect(refreshCount, 1);
  });

  testWidgets('active profile refresh button shows loading state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: HomePage(
          state: const HomeViewState(
            connected: false,
            connecting: false,
            resolvingProxy: false,
            connectionStatusLabel: '',
            activeProfile: AppProfileSummary(
              id: 'sub-1',
              name: 'Main subscription',
              consumed: 0,
              total: 0,
              remainingDays: null,
              outboundsCount: 1,
              sourceLabel: '',
            ),
            activeProxy: null,
            hideServerIp: false,
            hapticEnabled: false,
            speedBytesPerSecond: 0,
            trafficBytes: 0,
            activeProfileRefreshing: true,
            showActiveProfileRefreshAction: true,
            brandName: 'Etonify',
            versionLabel: '0.2.1',
          ),
          actions: HomeViewActions(
            toggleConnection: () {},
            refreshLatency: () {},
            openSubscriptions: () {},
            addSubscription: () {},
            openSettings: () {},
            openChangelog: () {},
            refreshActiveSubscription: () async {},
          ),
          bottomInset: 0,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('profile-refresh-progress')),
      findsOneWidget,
    );
  });

  testWidgets('home adapts to a short landscape window and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: HomePage(
          state: const HomeViewState(
            connected: false,
            connecting: false,
            resolvingProxy: false,
            connectionStatusLabel: '',
            activeProfile: AppProfileSummary(
              id: 'sub-1',
              name: 'A subscription with a deliberately long display name',
              consumed: 1024,
              total: 4096,
              remainingDays: 30,
              outboundsCount: 1000,
              sourceLabel: 'Remote',
            ),
            activeProxy: AppProxySummary(
              tag: 'france',
              displayName: 'France — long proxy display name',
              countryCode: 'FR',
              type: 'vless',
              server: 'france.example.com',
              port: 443,
              detailText: 'VLESS',
              ip: '203.0.113.10',
              latency: 42,
              latencyFresh: true,
              latencyChecking: false,
              latencyUnavailable: false,
              latencyError: null,
              protocolLabel: 'VLESS',
              endpointLabel: 'france.example.com',
            ),
            hideServerIp: false,
            hapticEnabled: false,
            speedBytesPerSecond: 1024,
            trafficBytes: 4096,
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
          bottomInset: 48,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Etonify'), findsOneWidget);
    expect(find.byType(ConnectionButton), findsOneWidget);
  });

  testWidgets('traffic dashboard renders live metrics and graph', (
    tester,
  ) async {
    final notifier = ValueNotifier<TrafficDashboardSnapshot>(
      TrafficDashboardSnapshot(
        connected: true,
        connecting: false,
        trafficAvailable: true,
        hideServerIp: false,
        downlinkBps: 2048,
        uplinkBps: 1024,
        uplinkTotalBytes: 4096,
        downlinkTotalBytes: 8192,
        connectedSince: DateTime.now().subtract(const Duration(seconds: 90)),
        activeProfile: const AppProfileSummary(
          id: 'sub-1',
          name: 'Main subscription',
          consumed: 0,
          total: 0,
          remainingDays: null,
          outboundsCount: 1,
          sourceLabel: '',
        ),
        activeProxy: _proxy('proxy-1', 'proxy 1', latency: 42),
        samples: [
          TrafficSample(
            timestamp: DateTime.now().subtract(const Duration(seconds: 2)),
            downlinkBps: 1024,
            uplinkBps: 512,
            totalBytes: 1024,
          ),
          TrafficSample(
            timestamp: DateTime.now().subtract(const Duration(seconds: 1)),
            downlinkBps: 2048,
            uplinkBps: 1024,
            totalBytes: 2048,
          ),
        ],
      ),
    );
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: TrafficDashboardPage(snapshotListenable: notifier),
      ),
    );

    expect(find.text('Traffic dashboard'), findsOneWidget);
    expect(find.text('2.00 KB/s'), findsOneWidget);
    expect(find.text('1.00 KB/s'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('traffic-dashboard-graph')),
      findsOneWidget,
    );
  });

  testWidgets('about page opens MeowTeam timeline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsAboutPage(
          versionLabel: '0.1.1',
          onShowOnboarding: () {},
          readCoreIntegrationDiagnostics: () =>
              const CoreIntegrationDiagnosticsSnapshot(
                applyStatus: 'applied',
                applyReason: 'settings_changed',
                applyError: '',
                configGeneration: 7,
                configRuntimeGeneration: 4,
                configSchemaVersion: 4,
                settingsApplyPending: false,
                lastApplyAtMillis: 1,
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Etonify v0.1.1'), findsNothing);
    expect(find.text('Client version'), findsOneWidget);
    expect(find.text('0.1.1'), findsOneWidget);
    expect(find.text('MeowVPN'), findsNothing);
    expect(find.text('yamixdev/etonify-core'), findsOneWidget);

    final teamAction = find.ancestor(
      of: find.text('MeowTeam'),
      matching: find.byType(InkWell),
    );
    await tester.tap(teamAction.first);
    await tester.pumpAndSettle();

    expect(find.text('The team behind Etonify'), findsOneWidget);
    expect(find.text('Early client development'), findsOneWidget);
    expect(find.text('Moving to etonify-core'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('dudosxdev'), 500);
    expect(find.text('dudosxdev'), findsOneWidget);
    expect(find.text('yamixdev'), findsOneWidget);

    await tester.tap(find.text('dudosxdev'));
    await tester.pumpAndSettle();
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('© 2026 MeowTeam™'), 500);
    expect(find.text('© 2026 MeowTeam™'), findsOneWidget);
  });

  testWidgets('about page opens resources and diagnostics separately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsAboutPage(
          versionLabel: '0.1.1',
          onShowOnboarding: () {},
          readCoreIntegrationDiagnostics: () =>
              const CoreIntegrationDiagnosticsSnapshot(
                applyStatus: 'applied',
                applyReason: 'settings_changed',
                applyError: '',
                configGeneration: 7,
                configRuntimeGeneration: 4,
                configSchemaVersion: 4,
                settingsApplyPending: false,
                lastApplyAtMillis: 1,
              ),
          loadCoreCapabilities: () async => LibboxCapabilities.bundledLegacy,
          readRuntimeStatus: () async => const <String, dynamic>{
            'running': true,
            'runtimeGeneration': 4,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsDiagnosticsPage), findsNothing);
    expect(find.text('Resources & diagnostics'), findsOneWidget);
    expect(find.text('Etonify documentation'), findsOneWidget);
    expect(find.text('Process memory'), findsNothing);

    await tester.tap(find.text('Resources & diagnostics'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsDiagnosticsPage), findsOneWidget);
    expect(find.text('Core and configuration'), findsOneWidget);
    expect(find.text('Applied'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('Process memory'), findsOneWidget);
  });

  testWidgets('unsupported system locale falls back to English', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        localeResolutionCallback: (locale, supportedLocales) {
          if (locale?.languageCode.toLowerCase() == 'ru') {
            return const Locale('ru');
          }
          return const Locale('en');
        },
        home: Builder(
          builder: (context) {
            return Text(AppLocalizations.of(context).settingsTitle);
          },
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
  });

  test('subscription proxy count labels are localized', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final ru = await AppLocalizations.delegate.load(const Locale('ru'));

    expect(en.subscriptionServersCount(13), '13 proxies');
    expect(en.subscriptionProxyTypeLabel, 'Proxies');
    expect(ru.subscriptionServersCount(13), '13 прокси');
    expect(ru.subscriptionProxyTypeLabel, 'Прокси');
  });
}

AppProxySummary _proxy(String tag, String name, {int? latency}) {
  return AppProxySummary(
    tag: tag,
    displayName: name,
    countryCode: 'DE',
    type: 'vless',
    server: '$tag.example.com',
    port: 443,
    detailText: 'VLESS',
    ip: '',
    latency: latency,
    latencyFresh: latency != null,
    latencyChecking: false,
    latencyUnavailable: false,
    latencyError: null,
    protocolLabel: 'VLESS',
    endpointLabel: '$tag.example.com',
  );
}

ProxyPanelMetrics _proxyPanelMetrics({
  required double progress,
  required bool atMaxExtent,
}) {
  return ProxyPanelMetrics(
    bottomInset: 0,
    panelHeight: progress * 720,
    maxPanelHeight: 720,
    viewportHeight: 720,
    viewportLimit: 720,
    progress: progress,
    backdropProgress: progress,
    atMaxExtent: atMaxExtent,
    canFillScreen: true,
    collapseOnAnyDownwardDrag: atMaxExtent,
    dragging: false,
    animating: false,
  );
}

class _TestMeowClient extends StatelessWidget {
  const _TestMeowClient({required this.store});

  final AppSettingsStore store;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(child: MeowClient(store: store));
  }
}
