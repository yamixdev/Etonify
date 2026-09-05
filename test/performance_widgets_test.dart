import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/features/proxies/proxy_panel_shell.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/widgets/ip_refresh_dots.dart';

void main() {
  testWidgets('provider group selects the group without exposing members', (
    tester,
  ) async {
    final selected = <String>[];
    final group = _performanceProxy(0).copyWith(
      tag: 'provider-auto',
      displayName: 'Provider auto',
      isGroup: true,
      membersSelectable: false,
      childTags: ['cand-1'],
      childCount: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProxiesPage(
            proxies: [group],
            selectedTag: '',
            connected: true,
            progressiveBlurEnabled: false,
            onSelected: selected.add,
            onUrlTest: () async {},
            groupChildrenByTag: {
              'provider-auto': [
                _performanceProxy(
                  1,
                ).copyWith(tag: 'cand-1', displayName: 'cand-1'),
              ],
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byWidgetPredicate(
      (widget) => widget is ProxyTile && widget.proxy.tag == 'provider-auto',
    );
    expect(tester.widget<ProxyTile>(tile).onOpenGroup, isNull);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(selected, ['provider-auto']);
    expect(find.text('cand-1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expandable group sheet paints an opaque full panel', (
    tester,
  ) async {
    final group = _performanceProxy(0).copyWith(
      tag: 'group',
      displayName: 'Group',
      isGroup: true,
      childTags: ['child'],
      childCount: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProxiesPage(
            proxies: [group],
            selectedTag: '',
            connected: false,
            progressiveBlurEnabled: false,
            onSelected: (_) {},
            onUrlTest: () async {},
            groupChildrenByTag: {
              'group': [_performanceProxy(1).copyWith(tag: 'child')],
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = tester.widget<ProxyTile>(
      find.byWidgetPredicate(
        (widget) => widget is ProxyTile && widget.proxy.tag == 'group',
      ),
    );
    tile.onOpenGroup!(Rect.zero);
    await tester.pumpAndSettle();
    final surface = find.byKey(const ValueKey('proxy-group-sheet-surface'));
    expect(surface, findsOneWidget);
    expect(tester.widget<ColoredBox>(surface).color.a, 1);
    expect(
      tester.getSize(surface).width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
    expect(tester.getSize(surface).height, greaterThan(400));
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('proxy header collapse leaves the lazy list mounted', (
    tester,
  ) async {
    final proxies = List<AppProxySummary>.generate(
      80,
      (index) => _performanceProxy(index),
      growable: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            height: 720,
            child: ProxiesPage(
              proxies: proxies,
              selectedTag: proxies.first.tag,
              connected: false,
              progressiveBlurEnabled: false,
              onSelected: (_) {},
              onUrlTest: () async {},
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
    await tester.pumpAndSettle();

    final listFinder = find.byType(ListView);
    final headerFinder = find.byKey(const ValueKey('proxy-sheet-header'));
    expect(listFinder, findsOneWidget);
    expect(headerFinder, findsOneWidget);

    final listBefore = tester.widget<ListView>(listFinder);
    final paddingBefore = listBefore.padding;
    final headerHeightBefore = tester.getSize(headerFinder).height;

    await tester.drag(listFinder, const Offset(0, -96));
    await tester.pumpAndSettle();

    final listAfter = tester.widget<ListView>(listFinder);
    expect(identical(listAfter, listBefore), isTrue);
    expect(listAfter.padding, paddingBefore);
    expect(tester.getSize(headerFinder).height, lessThan(headerHeightBefore));
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

AppProxySummary _performanceProxy(int index) {
  return AppProxySummary(
    tag: 'proxy-$index',
    displayName: 'Proxy $index',
    countryCode: index.isEven ? 'DE' : 'NL',
    type: 'vless',
    server: 'example.com',
    port: 443,
    detailText: 'VLESS · TLS',
    ip: '',
    latency: index + 1,
    latencyFresh: true,
    latencyChecking: false,
    latencyUnavailable: false,
    latencyError: null,
    protocolLabel: 'VLESS · TLS',
    endpointLabel: 'example.com:443',
  );
}
