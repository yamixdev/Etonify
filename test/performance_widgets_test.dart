import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/features/proxies/proxy_panel_shell.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';
import 'package:meow_client/widgets/ip_refresh_dots.dart';

void main() {
  testWidgets(
    'compact group rows keep selection and testing separate from opening',
    (tester) async {
      final group = _performanceProxy(0).copyWith(
        isGroup: true,
        childCount: 3,
        displayName: 'LTE Auto Netherlands',
      );
      var selections = 0;
      var tests = 0;
      final opened = <Rect>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 320,
                child: ProxyTile(
                  proxy: group,
                  selected: true,
                  animate: false,
                  onTap: () => selections++,
                  onTestLatency: () => tests++,
                  onOpenGroup: opened.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('proxy-latency-action-${group.tag}')),
      );
      expect(tests, 1);
      expect(selections, 0);
      await tester.tap(find.text('LTE Auto Netherlands'));
      expect(selections, 1);
      await tester.longPress(find.text('LTE Auto Netherlands'));
      expect(opened, hasLength(1));
      expect(opened.single.width, greaterThan(0));
      expect(selections, 1);
      expect(tests, 1);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'embedded compact rows fit long names with enlarged Russian text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final children = List.generate(
        3,
        (index) => _performanceProxy(index + 1),
      );
      final group = _performanceProxy(0).copyWith(
        isGroup: true,
        childCount: 3,
        displayName: 'LTE Авто — Нидерланды и другие серверы',
        childTags: [for (final child in children) child.tag],
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ProxiesPage(
              proxies: [group],
              selectedTag: '',
              connected: true,
              embedded: true,
              sheetAtMaxExtent: true,
              sheetExtent: 1,
              progressiveBlurEnabled: false,
              groupChildrenByTag: {group.tag: children},
              onSelected: (_) {},
              onUrlTest: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Автовыбор · 3 прокси'), findsOneWidget);
      await tester.longPress(find.text(group.displayName));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('proxy-group-sheet-surface')),
        findsOneWidget,
      );
      expect(find.text(children.first.displayName), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('ping updates retain the static flag and labels of a row', (
    tester,
  ) async {
    final runtime = ProxyRuntimeVisualStore();
    addTearDown(runtime.dispose);
    final proxy = _performanceProxy(0);
    runtime.replaceAll({proxy.tag: const ProxyRuntimeVisualState(latency: 10)});
    await tester.pumpWidget(_scrollTestPage([proxy], runtime: runtime));
    await tester.pumpAndSettle();
    final before = tester.widget<CountryFlagBadge>(
      find.byType(CountryFlagBadge),
    );
    runtime.updateTags({
      proxy.tag: const ProxyRuntimeVisualState(
        latency: 135,
        latencyFresh: true,
      ),
    });
    await tester.pump();
    expect(find.text('135 ms'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(
      identical(
        tester.widget<CountryFlagBadge>(find.byType(CountryFlagBadge)),
        before,
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'runtime sorting moves existing row elements instead of replacing them',
    (tester) async {
      final runtime = ProxyRuntimeVisualStore();
      addTearDown(runtime.dispose);
      final proxies = List.generate(3, _performanceProxy);
      await tester.pumpWidget(
        _scrollTestPage(proxies, runtime: runtime, sort: ProxySort.latency),
      );
      await tester.pumpAndSettle();
      Finder row(String tag) => find.byWidgetPredicate(
        (widget) => widget is ProxyTile && widget.proxy.tag == tag,
      );
      final firstElement = tester.element(row(proxies.first.tag));
      runtime.updateTags({
        proxies.first.tag: const ProxyRuntimeVisualState(
          latency: 100,
          latencyFresh: true,
        ),
      });
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.getTopLeft(row(proxies[1].tag)).dy,
        lessThan(tester.getTopLeft(row(proxies.first.tag)).dy),
      );
      expect(
        identical(tester.element(row(proxies.first.tag)), firstElement),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('parent data refresh cannot reorder rows during a drag', (
    tester,
  ) async {
    var proxies = List.generate(20, _performanceProxy);
    var profile = 'same';
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _scrollTestPage(
            proxies,
            sort: ProxySort.latency,
            profileId: profile,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    rebuild(() {
      proxies = [proxies.first.copyWith(latency: 1000), ...proxies.skip(1)];
    });
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widgetList<ProxyTile>(find.byType(ProxyTile)).first.proxy.tag,
      'proxy-0',
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<ProxyTile>(find.byType(ProxyTile)).first.proxy.tag,
      'proxy-1',
    );

    final nextDrag = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await nextDrag.moveBy(const Offset(0, -30));
    await tester.pump();
    rebuild(() {
      profile = 'next';
      proxies = [
        for (final proxy in proxies)
          proxy.copyWith(displayName: 'New ${proxy.tag}'),
      ];
    });
    await tester.pump();
    expect(find.text('Proxy 1'), findsNothing);
    expect(find.text('New proxy-1'), findsOneWidget);
    await nextDrag.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('source-sorted rows receive parent data after scrolling stops', (
    tester,
  ) async {
    var proxies = List.generate(20, _performanceProxy);
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _scrollTestPage(proxies);
        },
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    rebuild(() {
      proxies = [
        proxies.first.copyWith(displayName: 'Updated proxy', countryCode: 'FI'),
        ...proxies.skip(1),
      ];
    });
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Proxy 0'), findsOneWidget);
    expect(find.text('Updated proxy'), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Updated proxy'), findsOneWidget);
    expect(
      tester
          .widgetList<CountryFlagBadge>(find.byType(CountryFlagBadge))
          .first
          .countryCode,
      'FI',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('group sorting waits for the child list to stop scrolling', (
    tester,
  ) async {
    final runtime = ProxyRuntimeVisualStore();
    addTearDown(runtime.dispose);
    final children = List.generate(20, _performanceProxy);
    final group = _performanceProxy(30).copyWith(
      tag: 'group',
      isGroup: true,
      childTags: [for (final child in children) child.tag],
      childCount: children.length,
    );
    await tester.pumpWidget(
      _scrollTestPage(
        [group],
        runtime: runtime,
        sort: ProxySort.latency,
        groupChildren: {'group': children},
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<ProxyTile>(find.byType(ProxyTile)).onOpenGroup!(Rect.zero);
    await tester.pumpAndSettle();
    final surface = find.byKey(const ValueKey('proxy-group-sheet-surface'));
    final list = find.descendant(of: surface, matching: find.byType(ListView));
    final rows = find.descendant(of: surface, matching: find.byType(ProxyTile));
    final nextChild = find.descendant(
      of: surface,
      matching: find.byWidgetPredicate(
        (widget) => widget is ProxyTile && widget.proxy.tag == 'proxy-1',
      ),
    );
    final nextChildElement = tester.element(nextChild);
    final gesture = await tester.startGesture(tester.getCenter(list));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    runtime.updateTags({
      children.first.tag: const ProxyRuntimeVisualState(
        latency: 1000,
        latencyFresh: true,
      ),
    });
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.descendant(of: surface, matching: find.text('1.0 s')),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<ProxyTile>(rows)
          .where((row) => !row.proxy.isGroup)
          .first
          .proxy
          .tag,
      'proxy-0',
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<ProxyTile>(rows)
          .where((row) => !row.proxy.isGroup)
          .first
          .proxy
          .tag,
      'proxy-1',
    );
    expect(identical(tester.element(nextChild), nextChildElement), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no-data rows and provider groups keep a tappable test action', (
    tester,
  ) async {
    final runtime = ProxyRuntimeVisualStore();
    addTearDown(runtime.dispose);
    final proxies = [
      _performanceProxy(0),
      _performanceProxy(1).copyWith(
        isGroup: true,
        membersSelectable: false,
        childTags: ['child-a', 'child-b'],
        childCount: 2,
      ),
    ];
    runtime.replaceAll({
      for (final proxy in proxies)
        proxy.tag: const ProxyRuntimeVisualState(latencyFresh: false),
    });
    final tested = <String>[];
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProxiesPage(
            proxies: proxies,
            connected: true,
            selectedTag: '',
            runtimeStates: runtime,
            progressiveBlurEnabled: false,
            onSelected: selected.add,
            onUrlTest: () async {},
            onProxyUrlTest: (tag) async => tested.add(tag),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Нет данных'), findsNWidgets(2));
    for (final proxy in proxies) {
      final button = find.byKey(ValueKey('proxy-latency-action-${proxy.tag}'));
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tested, [
      proxies[0].tag,
      proxies[0].tag,
      proxies[1].tag,
      proxies[1].tag,
    ]);
    expect(selected, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('individual result renders while another proxy is still queued', (
    tester,
  ) async {
    final proxies = List.generate(2, _performanceProxy);
    final runtime = ProxyRuntimeVisualStore();
    addTearDown(runtime.dispose);
    final tested = <String>[];
    final selected = <String>[];
    runtime.replaceAll({
      for (final proxy in proxies)
        proxy.tag: const ProxyRuntimeVisualState(latencyChecking: true),
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProxiesPage(
            proxies: proxies,
            selectedTag: '',
            connected: true,
            runtimeStates: runtime,
            progressiveBlurEnabled: false,
            onSelected: selected.add,
            onUrlTest: () async {},
            onProxyUrlTest: (tag) async {
              tested.add(tag);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(ValueKey('proxy-latency-action-${proxies.first.tag}')),
    );
    expect(tested, [proxies.first.tag]);
    expect(selected, isEmpty);
    runtime.updateTags({
      proxies.first.tag: const ProxyRuntimeVisualState(
        latency: 123,
        latencyFresh: true,
      ),
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('123 ms'), findsOneWidget);
    expect(find.byType(ProxyLatencyDots), findsOneWidget);
    runtime.updateTags({
      proxies.last.tag: const ProxyRuntimeVisualState(latencyUnavailable: true),
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('123 ms'), findsOneWidget);
    expect(find.byType(ProxyLatencyDots), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('latency updates keep list mounted until order changes', (
    tester,
  ) async {
    final proxies = List.generate(900, _performanceProxy);
    final runtime = ProxyRuntimeVisualStore();
    addTearDown(runtime.dispose);
    runtime.replaceAll({
      for (var i = 0; i < proxies.length; i++)
        proxies[i].tag: ProxyRuntimeVisualState(latency: 100 + i),
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProxiesPage(
          proxies: proxies,
          selectedTag: '',
          connected: true,
          initialSort: ProxySort.latency,
          runtimeStates: runtime,
          progressiveBlurEnabled: false,
          onSelected: (_) {},
          onUrlTest: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.widget<ListView>(find.byType(ListView));
    expect(find.byType(ProxyTile).evaluate().length, lessThan(30));
    runtime.updateTags({
      proxies.first.tag: const ProxyRuntimeVisualState(latency: 90),
    });
    await tester.pump(const Duration(seconds: 1));
    expect(
      identical(tester.widget<ListView>(find.byType(ListView)), before),
      isTrue,
    );
    expect(
      tester
          .widgetList<ProxyTile>(find.byType(ProxyTile))
          .first
          .runtimeState
          ?.latency,
      90,
    );
    runtime.updateTags({
      proxies[1].tag: const ProxyRuntimeVisualState(latency: 50),
    });
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widgetList<ProxyTile>(find.byType(ProxyTile)).first.proxy.tag,
      proxies[1].tag,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
      String dotsText() => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(dotsKey),
              matching: find.byType(Text),
            ),
          )
          .data!;
      // The shared clock survives previous widgets; its phase is not always 1.
      final initial = dotsText();
      expect(initial, matches(r'^\.{1,3}$'));

      await tester.pump(const Duration(milliseconds: 299));
      expect(dotsText(), initial);
      await tester.pump(const Duration(milliseconds: 1));
      final next = '.' * (initial.length % 3 + 1);
      expect(dotsText(), next);

      await tester.pumpWidget(buildDots(enabled: false));
      await tester.pump(const Duration(milliseconds: 900));
      expect(dotsText(), next);

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

  testWidgets(
    'expanded proxy panel stops painting and ticking the covered home',
    (tester) async {
      final repaint = ValueNotifier(0);
      addTearDown(repaint.dispose);
      var paints = 0;
      const homeKey = ValueKey('covered-home-paint');
      await tester.pumpWidget(
        MaterialApp(
          home: ProxyPanelShell(
            ready: true,
            onboardingCompleted: true,
            loading: const SizedBox.shrink(),
            welcome: const SizedBox.shrink(),
            visibleRows: 40,
            hasActiveProfile: true,
            homeBuilder: (_, _) => CustomPaint(
              key: homeKey,
              painter: _PaintProbe(repaint, () => paints++),
              child: const SizedBox.expand(),
            ),
            sheetBuilder: (_, _, _, _, gestures) => Material(
              child: Align(
                alignment: Alignment.topCenter,
                child: TextButton(
                  onPressed: gestures.onHeaderTap,
                  child: const Text('Open proxies'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final home = find.byKey(homeKey, skipOffstage: false);
      final originalRender = tester.renderObject(home);
      await tester.tap(find.text('Open proxies'));
      await tester.pumpAndSettle();
      final settledPaints = paints;
      repaint.value++;
      await tester.pump();
      expect(paints, settledPaints);
      expect(TickerMode.valuesOf(tester.element(home)).enabled, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(paints, greaterThan(settledPaints));
      expect(TickerMode.valuesOf(tester.element(home)).enabled, isTrue);
      expect(identical(tester.renderObject(home), originalRender), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'proxy list prepares a bounded buffer ahead of the visible rows',
    (tester) async {
      final proxies = List.generate(1000, _performanceProxy);
      await tester.pumpWidget(_scrollTestPage(proxies));
      final viewport = tester.getRect(find.byType(ListView));
      final rows = find
          .byType(ProxyTile, skipOffstage: false)
          .evaluate()
          .toList();
      expect(rows.length, lessThan(40));
      expect(
        rows.any(
          (row) =>
              tester
                  .getRect(find.byWidget(row.widget, skipOffstage: false))
                  .top >
              viewport.bottom + viewport.height * .35,
        ),
        isTrue,
        reason:
            'Upcoming rows should be ready before a fast swipe reveals them',
      );
      expect(tester.takeException(), isNull);
    },
  );

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

class _PaintProbe extends CustomPainter {
  _PaintProbe(Listenable repaint, this.onPaint) : super(repaint: repaint);
  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_PaintProbe oldDelegate) => false;
}

Widget _scrollTestPage(
  List<AppProxySummary> proxies, {
  ProxyRuntimeVisualStore? runtime,
  ProxySort sort = ProxySort.source,
  String profileId = '',
  Map<String, List<AppProxySummary>> groupChildren = const {},
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: ProxiesPage(
      profileId: profileId,
      proxies: proxies,
      selectedTag: '',
      connected: true,
      runtimeStates: runtime,
      initialSort: sort,
      groupChildrenByTag: groupChildren,
      progressiveBlurEnabled: false,
      embedded: true,
      sheetAtMaxExtent: true,
      sheetExtent: 1,
      onSelected: (_) {},
      onUrlTest: () async {},
    ),
  ),
);

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
