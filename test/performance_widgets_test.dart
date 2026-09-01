import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/features/proxies/proxy_panel_shell.dart';
import 'package:meow_client/widgets/ip_refresh_dots.dart';

void main() {
  testWidgets(
    'proxy latency dots update discretely and pause with TickerMode',
    (tester) async {
      const dotsKey = ValueKey('latency-dots');

      Widget buildDots({required bool enabled}) {
        return MaterialApp(
          home: TickerMode(
            enabled: enabled,
            child: const ProxyLatencyDots(key: dotsKey, color: Colors.green),
          ),
        );
      }

      await tester.pumpWidget(buildDots(enabled: true));
      expect(find.text('.'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 299));
      expect(find.text('.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('..'), findsOneWidget);

      await tester.pumpWidget(buildDots(enabled: false));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('..'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('IP refresh dots repaint without rebuilding a widget row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: TickerMode(
          enabled: true,
          child: IpRefreshDots(color: Colors.blue),
        ),
      ),
    );

    final dots = find.byKey(const ValueKey('ip-refresh-dots'));
    expect(dots, findsOneWidget);
    expect(tester.widget<CustomPaint>(dots).painter, isNotNull);
    expect(
      find.descendant(of: dots, matching: find.byType(AnimatedBuilder)),
      findsNothing,
    );
    expect(find.descendant(of: dots, matching: find.byType(Row)), findsNothing);

    await tester.pump(const Duration(milliseconds: 450));
    expect(dots, findsOneWidget);
  });

  testWidgets('proxy panel keeps one sheet during repeated open-close cycles', (
    tester,
  ) async {
    var opened = 0;
    var closed = 0;
    var interactionActive = false;
    var sheetBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ProxyPanelShell(
          ready: true,
          onboardingCompleted: true,
          loading: const SizedBox.shrink(),
          welcome: const SizedBox.shrink(),
          visibleRows: 40,
          hasActiveProfile: true,
          onOpened: () => opened++,
          onClosed: () => closed++,
          onInteractionActiveChanged: (value) => interactionActive = value,
          homeBuilder: (_, _) => const SizedBox.expand(),
          sheetBuilder: (_, _, _, controller, gestures) {
            sheetBuilds++;
            return Material(
              child: Column(
                children: [
                  GestureDetector(
                    key: const ValueKey('test-proxy-panel-header'),
                    behavior: HitTestBehavior.opaque,
                    onTap: gestures.onHeaderTap,
                    child: const SizedBox(height: 72, child: Text('Proxies')),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemExtent: proxyPanelRowExtent,
                      itemCount: 40,
                      itemBuilder: (_, index) => Text('Proxy $index'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final panelSurface = find.byKey(const ValueKey('proxy-panel-drag-surface'));
    final collapsedHeight = tester.getSize(panelSurface).height;

    for (var cycle = 0; cycle < 20; cycle++) {
      await tester.drag(panelSurface, const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(tester.getSize(panelSurface).height, greaterThan(collapsedHeight));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(panelSurface, findsOneWidget);
    }

    expect(opened, 20);
    expect(closed, 20);
    expect(interactionActive, isFalse);
    expect(sheetBuilds, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sparse proxy panel can expand to the viewport on a tall phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2388);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProxyPanelShell(
          ready: true,
          onboardingCompleted: true,
          loading: const SizedBox.shrink(),
          welcome: const SizedBox.shrink(),
          visibleRows: 3,
          hasActiveProfile: true,
          homeBuilder: (_, _) => const SizedBox.expand(),
          sheetBuilder: (_, _, _, controller, gestures) => Material(
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: gestures.onHeaderTap,
                  child: const SizedBox(
                    height: proxyPanelMinHeight,
                    child: Text('Proxies'),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemExtent: proxyPanelRowExtent,
                    itemCount: 3,
                    itemBuilder: (_, index) => Text('Proxy $index'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final panelSurface = find.byKey(const ValueKey('proxy-panel-drag-surface'));
    await tester.drag(panelSurface, const Offset(0, -500));
    await tester.pumpAndSettle();

    final viewportHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final expandedHeight = tester.getSize(panelSurface).height;
    final oldContentBound =
        proxyPanelMinHeight +
        3 * proxyPanelRowExtent +
        proxyPanelListBottomPadding;
    expect(expandedHeight, greaterThan(oldContentBound));
    expect(expandedHeight, greaterThanOrEqualTo(viewportHeight - 9));
    expect(tester.takeException(), isNull);
  });
}
