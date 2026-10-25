import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/home/home_current_proxy_card.dart';
import 'package:meow_client/features/home/home_server_preview.dart';
import 'package:meow_client/features/home/server_ip_metadata.dart';
import 'package:meow_client/features/home/server_network_card.dart';
import 'package:meow_client/features/home/traffic_dashboard_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/server_connection_info.dart';
import 'package:meow_client/theme/app_theme.dart';

const connection = ServerConnectionInfo(
  outboundTag: 'server',
  key: 'session-A',
  connected: true,
  name: 'Sweden',
  countryCode: 'SE',
  exitIp: '203.0.113.7',
  endpointHost: 'entry.example',
  endpointPort: 443,
  protocol: 'VLESS',
  transport: 'GRPC',
  security: 'REALITY',
);
const proxy = AppProxySummary(
  tag: 'server',
  displayName: 'Sweden',
  countryCode: 'SE',
  type: 'vless',
  server: 'entry.example',
  port: 443,
  detailText: '',
  ip: '198.51.100.9',
  latency: 42,
  latencyFresh: true,
  latencyChecking: false,
  latencyUnavailable: false,
  latencyError: null,
  protocolLabel: 'VLESS · REALITY',
  endpointLabel: 'entry.example:443',
);

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  if (const bool.fromEnvironment('CAPTURE_NETWORK_PREVIEWS')) {
    setUpAll(() async {
      final font = File(
        '${Platform.environment['SystemRoot'] ?? 'C:/Windows'}/Fonts/segoeui.ttf',
      );
      if (await font.exists()) {
        await (FontLoader(
          'Roboto',
        )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    testWidgets('render home IP preview', (tester) async {
      tester.view.physicalSize = const Size(360, 180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('rendered-network'),
          child: homeServerIpPreview(),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'home');
    });
  }

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'network details reflow on a narrow $brightness screen scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(360, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final metadata = ServerIpMetadataController(
            load: (ip) async => ServerIpMetadata(
              ip: ip,
              organization: 'Example Network',
              asn: 64500,
              countryName: 'Sweden',
              city: 'Stockholm',
            ),
          );
          addTearDown(metadata.dispose);
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('rendered-network'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(
                  brightness,
                  seedColor: const Color(0xff8b4c14),
                ),
                locale: const Locale('en'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ServerNetworkCard(
                          connection: connection,
                          hideIp: false,
                          controller: metadata,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('CAPTURE_NETWORK_PREVIEWS')) {
            await capture(tester, '${brightness.name}-$scale');
          }
          await tester.scrollUntilVisible(find.text('REALITY'), 180);
          await tester.pumpAndSettle();
          expect(
            find.text('REALITY').hitTestable(),
            findsOneWidget,
            reason:
                'text=${tester.getRect(find.text('REALITY'))} viewport=${tester.view.physicalSize}',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('home clears a lost network IP without a parent rebuild', (
    tester,
  ) async {
    final source = ValueNotifier(connection);
    addTearDown(source.dispose);
    await tester.pumpWidget(
      app(
        HomeCurrentProxyCard(
          proxy: proxy,
          connectionInfo: connection,
          connectionListenable: source,
          onTap: () {},
          onOpenInfo: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('203.0.113.7'), findsOneWidget);
    source.value = const ServerConnectionInfo(
      key: 'new-network',
      connected: true,
      outboundTag: 'server',
    );
    await tester.pumpAndSettle();
    expect(find.text('203.0.113.7'), findsNothing);
  });

  testWidgets(
    'lowest through a nested group and a chain retain confirmed leaf IP',
    (tester) async {
      for (final tag in ['lowest', 'chain']) {
        final selected = proxy.copyWith(
          tag: tag,
          isGroup: tag == 'lowest',
          selectedChildTag: 'nested-group',
        );
        await tester.pumpWidget(
          app(
            HomeCurrentProxyCard(
              proxy: selected,
              connectionInfo: ServerConnectionInfo(
                connected: true,
                outboundTag: 'leaf',
                selectedProxyTag: tag,
                presentedChildTag: 'nested-group',
                presentedEndpoint: 'entry.example:443',
                exitIp: '203.0.113.7',
              ),
              onTap: () {},
              onOpenInfo: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('203.0.113.7'), findsOneWidget);
        await tester.pumpWidget(
          app(
            HomeCurrentProxyCard(
              proxy: selected.copyWith(endpointLabel: 'new.example:443'),
              connectionInfo: ServerConnectionInfo(
                connected: true,
                outboundTag: 'leaf',
                selectedProxyTag: tag,
                presentedChildTag: 'nested-group',
                presentedEndpoint: 'entry.example:443',
                exitIp: '203.0.113.7',
              ),
              onTap: () {},
              onOpenInfo: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('203.0.113.7'), findsNothing);
      }
    },
  );

  testWidgets(
    'an unknown exit IP can be retried without looking up the endpoint',
    (tester) async {
      var probes = 0;
      var lookups = 0;
      final metadata = ServerIpMetadataController(
        load: (ip) async {
          lookups++;
          return ServerIpMetadata(ip: ip);
        },
      );
      addTearDown(metadata.dispose);
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: ServerNetworkCard(
              connection: const ServerConnectionInfo(
                key: 'A',
                connected: true,
                endpointHost: '198.51.100.9',
              ),
              hideIp: false,
              controller: metadata,
              onRefreshExitIp: () => probes++,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Refresh network information'));
      expect(probes, 1);
      expect(lookups, 0);
    },
  );

  testWidgets('auto card uses the selected leaf IP and rejects another leaf', (
    tester,
  ) async {
    final group = proxy.copyWith(
      tag: 'group',
      isGroup: true,
      selectedChildTag: 'server',
    );
    await tester.pumpWidget(
      app(
        HomeCurrentProxyCard(
          proxy: group,
          connectionInfo: connection,
          onTap: () {},
          onOpenInfo: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('203.0.113.7'), findsOneWidget);
    await tester.pumpWidget(
      app(
        HomeCurrentProxyCard(
          proxy: group.copyWith(selectedChildTag: 'other'),
          connectionInfo: connection,
          onTap: () {},
          onOpenInfo: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('203.0.113.7'), findsNothing);
  });

  testWidgets('home IP opens details without opening the proxy list', (
    tester,
  ) async {
    var lists = 0;
    var details = 0;
    await tester.pumpWidget(
      app(
        Center(
          child: HomeCurrentProxyCard(
            proxy: proxy,
            connectionInfo: connection,
            onTap: () => lists++,
            onOpenInfo: () => details++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('203.0.113.7'), findsOneWidget);
    expect(find.text('198.51.100.9'), findsNothing);
    expect(find.text('VLESS · REALITY'), findsNothing);
    await tester.tap(find.text('203.0.113.7'));
    expect(details, 1);
    expect(lists, 0);
    await tester.tap(find.text('Sweden'));
    expect(lists, 1);
  });

  testWidgets(
    'hidden and disconnected home IP do not disclose endpoint or cached IP',
    (tester) async {
      await tester.pumpWidget(
        app(
          HomeCurrentProxyCard(
            proxy: proxy,
            connectionInfo: connection,
            hideIp: true,
            onTap: () {},
            onOpenInfo: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('203.0.*.*'), findsOneWidget);
      expect(find.text('203.0.113.7'), findsNothing);
      await tester.pumpWidget(
        app(
          HomeCurrentProxyCard(
            proxy: proxy,
            connectionInfo: const ServerConnectionInfo(),
            onTap: () {},
            onOpenInfo: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('203.0.113.7'), findsNothing);
      expect(find.text('198.51.100.9'), findsNothing);
    },
  );

  testWidgets(
    'IP details open first and replace metadata after server change',
    (tester) async {
      final source = ValueNotifier(connection);
      final traffic = ValueNotifier(TrafficDashboardSnapshot.empty);
      final pending = Completer<ServerIpMetadata>();
      final metadata = ServerIpMetadataController(load: (ip) => pending.future);
      addTearDown(source.dispose);
      addTearDown(traffic.dispose);
      addTearDown(metadata.dispose);
      await tester.pumpWidget(
        app(
          TrafficDashboardPage(
            snapshotListenable: traffic,
            serverConnectionListenable: source,
            serverIpMetadataController: metadata,
            initialSection: TrafficDashboardSection.serverNetwork,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Server and network').hitTestable(), findsOneWidget);
      pending.complete(
        const ServerIpMetadata(
          ip: '203.0.113.7',
          organization: 'Example Network',
          asn: 64500,
          countryName: 'Sweden',
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Example Network'), 100);
      expect(find.text('AS64500'), findsOneWidget);
      source.value = const ServerConnectionInfo();
      await tester.pumpAndSettle();
      expect(find.text('Example Network'), findsNothing);
      expect(find.text('AS64500'), findsNothing);
      expect(metadata.info, isNull);
    },
  );
}

Future<void> capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('rendered-network')),
    );
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(
        '${Directory.systemTemp.path}/etonify-network-$name.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
