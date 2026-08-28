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

  testWidgets(
    'proxy panel releases its route after repeated open-close cycles',
    (tester) async {
      var opened = 0;
      var closed = 0;
      var interactionActive = false;

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
            sheetBuilder: (_, _, _, controller, gestures) => Material(
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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var cycle = 0; cycle < 20; cycle++) {
        await tester.drag(
          find.byKey(const ValueKey('proxy-panel-collapsed')),
          const Offset(0, -120),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('proxy-panel-expanded')),
          findsOneWidget,
        );

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('proxy-panel-expanded')),
          findsNothing,
        );
      }

      expect(opened, 20);
      expect(closed, 20);
      expect(interactionActive, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
