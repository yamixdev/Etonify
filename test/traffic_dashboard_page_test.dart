import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/home/public_ip_controller.dart';
import 'package:meow_client/features/home/traffic_dashboard_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/theme/app_theme.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

TrafficDashboardSnapshot snapshot({
  int speed = 2048,
  int elapsed = 1,
  bool available = true,
  bool connected = true,
  bool hideIp = false,
  String ip = '31.22.93.6',
}) {
  return TrafficDashboardSnapshot(
    connected: connected,
    connecting: false,
    trafficAvailable: available,
    hideServerIp: hideIp,
    downlinkBps: speed,
    uplinkBps: 1024,
    uplinkTotalBytes: 4096,
    downlinkTotalBytes: 8192,
    connectedSince: DateTime(2026),
    activeProfile: const AppProfileSummary(
      id: 'profile',
      name: 'Main subscription',
      consumed: 0,
      total: 0,
      remainingDays: null,
      outboundsCount: 226,
      sourceLabel: '',
    ),
    activeProxy: AppProxySummary(
      tag: 'server',
      displayName: 'A long automatic proxy server name for testing',
      countryCode: 'SE',
      type: 'vless',
      server: '31.22.93.6',
      port: 443,
      detailText: '',
      ip: ip,
      latency: 118,
      latencyFresh: true,
      latencyChecking: false,
      latencyUnavailable: false,
      latencyError: null,
      protocolLabel: 'VLESS',
      endpointLabel: '31.22.93.6:443',
    ),
    samples: [
      TrafficSample(
        timestamp: DateTime(2026),
        downlinkBps: 8192,
        uplinkBps: 2048,
        totalBytes: 0,
      ),
      TrafficSample(
        timestamp: DateTime(2026).add(Duration(seconds: elapsed)),
        downlinkBps: speed,
        uplinkBps: 1024,
        totalBytes: 12288,
      ),
    ],
  );
}

Widget app(
  ValueNotifier<TrafficDashboardSnapshot> notifier, {
  Color seed = Colors.blue,
  double textScale = 1,
  bool reducedMotion = false,
  PublicIpController? publicIpController,
}) => MaterialApp(
  locale: const Locale('ru'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: buildAppTheme(
    Brightness.light,
    dynamicLightScheme: ColorScheme.fromSeed(seedColor: seed),
  ),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reducedMotion,
    ),
    child: TrafficDashboardPage(
      snapshotListenable: notifier,
      publicIpController: publicIpController,
    ),
  ),
);

void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'an expiring left-edge sample scrolls out rather than disappearing',
    (tester) async {
      final notifier = ValueNotifier(snapshot(elapsed: 90));
      addTearDown(notifier.dispose);
      await tester.pumpWidget(app(notifier));
      notifier.value = snapshot(elapsed: 91);
      await tester.pump();
      final dynamic painter = tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey('traffic-dashboard-graph')),
          )
          .painter;
      expect(
        (painter.download as List<Offset>).first.dx,
        closeTo(-1 / 90, .00001),
      );
      expect((painter.previousDownload as List<Offset>).first.dx, 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    },
  );
  testWidgets('graph keeps a fixed time scale instead of compressing history', (
    tester,
  ) async {
    final notifier = ValueNotifier(snapshot());
    addTearDown(notifier.dispose);
    await tester.pumpWidget(app(notifier, reducedMotion: true));
    final dynamic painter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('traffic-dashboard-graph')),
        )
        .painter;
    final points = painter.download as List<Offset>;
    expect(points.last.dx, 1);
    expect(points.last.dx - points.first.dx, closeTo(1 / 90, .00001));
  });

  testWidgets(
    'public IP title aligns with its icon and panel clips rounded top',
    (tester) async {
      useTallViewport(tester);
      final notifier = ValueNotifier(snapshot());
      addTearDown(notifier.dispose);
      await tester.pumpWidget(app(notifier));
      final card = find.byKey(const ValueKey('traffic-dashboard-public-ip'));
      final title = find.descendant(of: card, matching: find.text('Ваш IP'));
      expect(
        tester.getTopLeft(title).dy - tester.getTopLeft(card).dy,
        lessThan(22),
      );
      final materials = tester.widgetList<Material>(
        find.ancestor(
          of: find.byKey(const ValueKey('traffic-dashboard')),
          matching: find.byType(Material),
        ),
      );
      expect(
        materials.any(
          (m) =>
              m.borderRadius ==
                  const BorderRadius.vertical(top: Radius.circular(28)) &&
              m.clipBehavior != Clip.none,
        ),
        isTrue,
      );
    },
  );
  testWidgets('public IP has its own card alongside server IP', (tester) async {
    useTallViewport(tester);
    final notifier = ValueNotifier(snapshot());
    addTearDown(notifier.dispose);
    await tester.pumpWidget(app(notifier));
    expect(find.text('Ваш IP'), findsOneWidget);
    expect(find.text('IP сервера'), findsOneWidget);
  });

  testWidgets(
    'opening fetches once, updates preserve IP and country on failure',
    (tester) async {
      useTallViewport(tester);
      var calls = 0;
      final controller = PublicIpController(
        load: () async {
          if (++calls > 1) throw StateError('network unavailable');
          return PublicIpInfo.fromTrace('ip=203.0.113.8\nloc=SE');
        },
      );
      final notifier = ValueNotifier(snapshot());
      addTearDown(notifier.dispose);
      await tester.pumpWidget(app(notifier, publicIpController: controller));
      await tester.pump();
      final card = find.byKey(const ValueKey('traffic-dashboard-public-ip'));
      expect(
        find.descendant(of: card, matching: find.text('203.0.113.8')),
        findsOneWidget,
      );
      final flag = tester.widget<CountryFlagBadge>(
        find.descendant(of: card, matching: find.byType(CountryFlagBadge)),
      );
      expect(flag.countryCode, 'SE');
      final refresh = find.byKey(const ValueKey('public-ip-refresh'));
      expect(tester.widget<IconButton>(refresh).onPressed, isNull);
      notifier.value = snapshot(speed: 4096);
      await tester.pump();
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(refresh);
      await tester.pump();
      expect(
        find.descendant(of: card, matching: find.text('203.0.113.8')),
        findsOneWidget,
      );
      expect(
        find.text('Не удалось обновить IP. Попробуйте ещё раз.'),
        findsOneWidget,
      );
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('closing cancels lookup and quick reopening does not spam', (
    tester,
  ) async {
    final pending = Completer<PublicIpInfo>();
    var calls = 0;
    var cancellations = 0;
    final controller = PublicIpController(
      load: () {
        calls++;
        return pending.future;
      },
      cancel: () {
        cancellations++;
      },
    );
    final notifier = ValueNotifier(snapshot());
    addTearDown(notifier.dispose);
    await tester.pumpWidget(app(notifier, publicIpController: controller));
    await tester.pumpWidget(const SizedBox());
    expect(cancellations, 1);
    await tester.pumpWidget(app(notifier, publicIpController: controller));
    expect(calls, 1);
    pending.complete(PublicIpInfo.fromTrace('ip=203.0.113.8\nloc=SE'));
    await tester.pump();
    expect(controller.info, isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('public IPv6 respects privacy and fits narrow large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PublicIpController(
      load: () async =>
          PublicIpInfo.fromTrace('ip=2001:db8:abcd:1234::1\nloc=SE'),
    );
    final notifier = ValueNotifier(snapshot(hideIp: true));
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      app(notifier, publicIpController: controller, textScale: 2),
    );
    await tester.pump();
    final card = find.byKey(const ValueKey('traffic-dashboard-public-ip'));
    await tester.scrollUntilVisible(card, 200);
    expect(find.text('2001:db8:abcd:1234::1'), findsNothing);
    expect(
      find.descendant(of: card, matching: find.textContaining('****')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
    'current speeds and actual peak live together above session totals',
    (tester) async {
      final notifier = ValueNotifier(snapshot());
      addTearDown(notifier.dispose);
      await tester.pumpWidget(app(notifier));
      expect(find.text('Пик 8.00 KB/s'), findsOneWidget);
      final graph = find.byKey(const ValueKey('traffic-dashboard-graph'));
      expect(
        tester.getTopLeft(graph).dy,
        lessThan(tester.getTopLeft(find.text('Трафик сессии')).dy),
      );
      expect(find.text('2.00 KB/s'), findsOneWidget);
      expect(find.text('1.00 KB/s'), findsOneWidget);
    },
  );

  testWidgets(
    'traffic ticks do not rebuild the heading or connection details',
    (tester) async {
      useTallViewport(tester);
      final notifier = ValueNotifier(snapshot());
      addTearDown(notifier.dispose);
      await tester.pumpWidget(app(notifier));
      final heading = tester.widget(find.text('Мониторинг трафика'));
      final connection = tester.widget(find.text('Main subscription'));
      notifier.value = snapshot(speed: 3072);
      await tester.pump();
      expect(find.text('3.00 KB/s'), findsOneWidget);
      expect(tester.widget(find.text('Мониторинг трафика')), same(heading));
      expect(tester.widget(find.text('Main subscription')), same(connection));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('unavailable traffic is not presented as measured zero speed', (
    tester,
  ) async {
    final notifier = ValueNotifier(snapshot(available: false));
    addTearDown(notifier.dispose);
    await tester.pumpWidget(app(notifier));
    expect(find.text('Ждём данные трафика'), findsOneWidget);
    expect(find.text('2.00 KB/s'), findsNothing);
    expect(find.text('1.00 KB/s'), findsNothing);
  });

  testWidgets('graph animation does not rebuild metrics and stops on close', (
    tester,
  ) async {
    final notifier = ValueNotifier(snapshot());
    addTearDown(notifier.dispose);
    await tester.pumpWidget(app(notifier));
    notifier.value = snapshot(speed: 4096);
    await tester.pump();
    final metric = tester.widget(find.text('4.00 KB/s'));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget(find.text('4.00 KB/s')), same(metric));
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion updates graph without scheduling animation', (
    tester,
  ) async {
    final notifier = ValueNotifier(snapshot());
    addTearDown(notifier.dispose);
    await tester.pumpWidget(app(notifier, reducedMotion: true));
    notifier.value = snapshot(speed: 4096);
    await tester.pump();
    expect(find.text('4.00 KB/s'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disconnect clears graph and honors server IP privacy', (
    tester,
  ) async {
    useTallViewport(tester);
    final notifier = ValueNotifier(snapshot());
    addTearDown(notifier.dispose);
    await tester.pumpWidget(app(notifier));
    notifier.value = snapshot(connected: false, hideIp: true);
    await tester.pump();
    expect(find.byKey(const ValueKey('traffic-dashboard-graph')), findsNothing);
    expect(find.text('Отключено'), findsOneWidget);
    expect(find.text('31.22.*.*'), findsOneWidget);
    expect(find.text('31.22.93.6'), findsNothing);
    expect(find.text('2.00 KB/s'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('IP privacy also masks a short compressed IPv6 address', (
    tester,
  ) async {
    useTallViewport(tester);
    final notifier = ValueNotifier(snapshot(hideIp: true, ip: '2606::1'));
    addTearDown(notifier.dispose);
    await tester.pumpWidget(app(notifier));
    expect(find.text('2606::1'), findsNothing);
    expect(find.text('****'), findsOneWidget);
  });

  testWidgets(
    'new samples interrupt animation and reduced motion snaps to latest values',
    (tester) async {
      final notifier = ValueNotifier(snapshot());
      addTearDown(notifier.dispose);
      final reducedMotion = ValueNotifier(false);
      addTearDown(reducedMotion.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ValueListenableBuilder<bool>(
            valueListenable: reducedMotion,
            builder: (context, reduced, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: TrafficDashboardPage(snapshotListenable: notifier),
            ),
          ),
        ),
      );
      notifier.value = snapshot(speed: 4096);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      notifier.value = snapshot(speed: 6144);
      await tester.pump();
      expect(find.text('6.00 KB/s'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      reducedMotion.value = true;
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow Russian layout supports large text and updates theme colors',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notifier = ValueNotifier(snapshot());
      addTearDown(notifier.dispose);
      await tester.pumpWidget(app(notifier, textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('31.22.93.6'), 200);
      expect(tester.takeException(), isNull);
      expect(find.text('31.22.93.6'), findsOneWidget);
      await tester.pumpWidget(
        app(notifier, seed: Colors.green, reducedMotion: true),
      );
      await tester.pumpAndSettle();
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.arrow_downward_rounded).first,
      );
      expect(icon.color, ColorScheme.fromSeed(seedColor: Colors.green).primary);
      expect(tester.takeException(), isNull);
    },
  );
}
