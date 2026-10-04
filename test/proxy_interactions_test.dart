import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/features/proxies/proxy_panel_shell.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

AppProxySummary _proxy(String tag, {List<String> children = const []}) =>
    AppProxySummary(
      tag: tag,
      displayName: tag,
      countryCode: 'US',
      type: children.isEmpty ? 'vless' : 'urltest',
      server: 'example.com',
      port: 443,
      detailText: 'vless',
      ip: '',
      latency: 42,
      latencyFresh: true,
      latencyChecking: false,
      latencyUnavailable: false,
      latencyError: null,
      protocolLabel: 'vless',
      endpointLabel: 'example.com:443',
      isGroup: children.isNotEmpty,
      childTags: children,
      childCount: children.length,
    );

Widget _app(
  Widget child, {
  TargetPlatform? platform,
  TextScaler? textScaler,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  theme: ThemeData(platform: platform, brightness: brightness),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
  builder: textScaler == null
      ? null
      : (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
);

Widget _page({
  required List<AppProxySummary> proxies,
  required ValueChanged<String> onSelected,
  Map<String, List<AppProxySummary>> groups = const {},
  bool shell = false,
}) {
  Widget page({
    ValueListenable<ProxyPanelMetrics>? metrics,
    ScrollController? controller,
    VoidCallback? onHeaderTap,
  }) => ProxiesPage(
    proxies: proxies,
    selectedTag: '',
    connected: true,
    progressiveBlurEnabled: false,
    hapticEnabled: false,
    embedded: true,
    sheetAtMaxExtent: !shell,
    sheetExtent: 1,
    collapsedSheetExtent: 0,
    expandedHeaderExtent: 1,
    sheetMetricsListenable: metrics,
    scrollController: controller,
    onHeaderTap: onHeaderTap,
    groupChildrenByTag: groups,
    onSelected: onSelected,
    onUrlTest: () async {},
    outboundForTag: (tag) => Outbound(
      tag: tag,
      name: tag,
      config: const {
        'type': 'vless',
        'server': 'example.com',
        'server_port': 443,
        'uuid': '00000000-0000-0000-0000-000000000001',
      },
    ),
  );
  if (!shell) return Scaffold(body: page());
  return ProxyPanelShell(
    ready: true,
    onboardingCompleted: true,
    loading: const SizedBox(),
    welcome: const SizedBox(),
    visibleRows: proxies.length,
    hasActiveProfile: true,
    homeBuilder: (_, _) => const SizedBox.expand(),
    sheetBuilder: (_, _, metrics, controller, gestures) => page(
      metrics: metrics,
      controller: controller,
      onHeaderTap: gestures.onHeaderTap,
    ),
  );
}

void main() {
  testWidgets('provider members stay inside all groups after auto and back', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 873));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final subscription = Subscription(
      id: 'lte',
      name: 'LTE',
      url: '',
      selectedProxyTag: 'auto-se',
      groups: [
        for (final country in ['se', 'nl', 'de'])
          SubscriptionGroup(
            tag: 'auto-$country',
            name: {
              'se': 'LTE Sweden',
              'nl': 'LTE Netherlands',
              'de': 'LTE Germany',
            }[country]!,
            country: country.toUpperCase(),
            outboundTags: ['cand-$country-01', 'cand-$country-02'],
          ),
      ],
      outbounds: [
        for (final country in ['se', 'nl', 'de'])
          for (final index in ['01', '02'])
            Outbound(
              tag: 'cand-$country-$index',
              name: 'cand-$country-$index',
              info: OutboundInfo(country: country.toUpperCase()),
              config: {
                'type': 'vless',
                'server': '$country-$index.example.com',
                'server_port': 443,
                'uuid': '00000000-0000-0000-0000-000000000001',
              },
            ),
      ],
    );
    var selectedTag = '';
    var runtimeSelections = <String, String>{};
    late ProxyCacheBuildResult cache;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            cache = buildProxyCache(
              ProxyCacheBuildInput(
                subscription: subscription,
                selectedProxyTag: selectedTag,
                lowestLatency: null,
                runtimeLowestOutboundTag: null,
                runtimeLowestSelections: const {},
                urlTestInFlight: false,
                runtimeLatencies: const {'cand-se-02': 11},
                unavailableLatencyTags: const {},
                latencyErrors: const {},
                runtimeGroupSelections: runtimeSelections,
                markAllServersRussia: false,
              ),
            );
            return Scaffold(
              body: ProxiesPage(
                proxies: cache.activeProxies,
                groupChildrenByTag: cache.groupChildrenByTag,
                selectedTag: selectedTag,
                connected: true,
                progressiveBlurEnabled: false,
                hapticEnabled: false,
                embedded: true,
                sheetAtMaxExtent: true,
                sheetExtent: 1,
                collapsedSheetExtent: 0,
                expandedHeaderExtent: 1,
                onUrlTest: () async {},
                onSelected: (tag) => setState(() {
                  selectedTag = tag;
                  runtimeSelections = {
                    'auto-se': 'cand-se-02',
                    'auto-nl': 'cand-nl-01',
                    'auto-de': 'cand-de-01',
                  };
                }),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('LTE Sweden'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proxy-open-group-auto-se')));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('proxy-group-sheet-surface'));
    expect(
      find.descendant(of: panel, matching: find.text('cand-se-02')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back').last);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(selectedTag, 'auto-se');
    expect(
      cache.activeProxies
          .map((proxy) => proxy.tag)
          .where((tag) => tag.startsWith('cand-')),
      isEmpty,
    );
    for (final title in ['LTE Sweden', 'LTE Netherlands', 'LTE Germany']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.textContaining('cand-'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('proxy-open-group-auto-nl')));
    await tester.pumpAndSettle();
    expect(find.text('cand-nl-01'), findsOneWidget);
    expect(find.text('cand-nl-02'), findsOneWidget);
    expect(find.text('cand-se-02'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.textContaining('cand-'), findsNothing);
    expect(cache.groupChildrenByTag['auto-de']!.map((proxy) => proxy.tag), [
      'cand-de-01',
      'cand-de-02',
    ]);
  });

  for (final title in ['Node', 'A long title that wraps onto a second line']) {
    testWidgets('protocol follows title without a reserved gap: $title', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 873));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ProxyTile(
                proxy: _proxy(title),
                selected: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final nameFinder = find.text(title);
      final name = tester.getRect(nameFinder);
      final label = tester.widget<Text>(nameFinder);
      final painter = TextPainter(
        text: TextSpan(text: label.data, style: label.style),
        textDirection: TextDirection.ltr,
        maxLines: label.maxLines,
      )..layout(maxWidth: name.width);
      addTearDown(painter.dispose);
      final protocol = tester.getRect(find.text('vless'));
      expect(
        protocol.top - (name.top + painter.height),
        inInclusiveRange(2.0, 4.0),
      );
    });
  }

  testWidgets('group open action is outlined and does not cover empty space', (
    tester,
  ) async {
    var selected = 0;
    var opened = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ProxyTile(
            proxy: _proxy('Group', children: ['Node']),
            selected: false,
            onTap: () => selected++,
            onOpenGroup: (_) => opened++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('proxy-open-group-Group'));
    expect(tester.widget(action), isA<OutlinedButton>());
    final area = tester.getRect(action);
    expect(area.height, greaterThanOrEqualTo(28));
    final row = tester.getRect(find.byType(ProxyTile));
    await tester.tapAt(Offset(row.right - 170, area.center.dy));
    expect(opened, 0);
    expect(selected, 0);
    await tester.tap(action);
    expect(opened, 1);
    expect(selected, 0);
    await tester.drag(action, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.1, 2.0]) {
      testWidgets('outlined group fits Russian text in $brightness at $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 873));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final group = _proxy(
          '⚡ ⭐ LTE Авто - Нидерланды с длинным названием',
          children: ['Node'],
        );
        final selections = <String>[];
        await tester.pumpWidget(
          _app(
            _page(
              proxies: [group],
              groups: {
                group.tag: [_proxy('Node')],
              },
              onSelected: selections.add,
            ),
            brightness: brightness,
            locale: const Locale('ru'),
            platform: TargetPlatform.android,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(ValueKey('proxy-open-group-${group.tag}'));
        final button = tester.widget<OutlinedButton>(action);
        final theme = Theme.of(tester.element(action));
        expect(
          button.style!.side!.resolve({})!.color,
          theme.colorScheme.outlineVariant,
        );
        final name = tester.getRect(find.text(group.displayName));
        final area = tester.getRect(action);
        expect(area.top, greaterThanOrEqualTo(name.bottom + 2));
        expect(area.right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('Node'), findsOneWidget);
        expect(selections, isEmpty);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Node'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'open nested panel refreshes actual leaf and flag without losing scroll',
    (tester) async {
      final one = _proxy('One');
      final two = _proxy('Two').copyWith(countryCode: 'DE');
      var nested = _proxy('Nested', children: ['One', 'Two']).copyWith(
        selectedChildTag: 'One',
        selectedChildName: 'One',
        countryCode: 'US',
      );
      var root = _proxy('Root', children: ['Nested']);
      final leaves = [
        one,
        two,
        ...List.generate(30, (i) => _proxy('Extra $i')),
      ];
      late StateSetter refresh;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return _page(
                proxies: [root],
                groups: {
                  'Root': [nested],
                  'Nested': leaves,
                },
                onSelected: (_) {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('proxy-open-group-Root')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('proxy-open-group-Nested')));
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('proxy-group-sheet-surface'));
      final header = find.byKey(const ValueKey('proxy-group-header-Nested'));
      final scrollable = find.descendant(
        of: panel,
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(scrollable).position.jumpTo(72);
      await tester.pumpAndSettle();
      refresh(() {
        nested = nested.copyWith(
          selectedChildTag: 'Two',
          selectedChildName: 'Two',
          countryCode: 'DE',
        );
        root = root.copyWith(
          selectedChildTag: 'Two',
          selectedChildName: 'Two',
          countryCode: 'DE',
        );
      });
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: header, matching: find.text('Nested · Two')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CountryFlagBadge>(
              find.descendant(
                of: header,
                matching: find.byType(CountryFlagBadge),
              ),
            )
            .countryCode,
        'DE',
      );
      expect(tester.state<ScrollableState>(scrollable).position.pixels, 72);
      expect(panel, findsOneWidget);
      await tester.tap(find.byTooltip('Back').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('proxy-group-header-Root')),
          matching: find.text('Root · Two'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('real cache provider group opens its preserved nested group', (
    tester,
  ) async {
    const subscription = Subscription(
      id: 'nested-provider',
      name: 'Nested provider',
      url: '',
      selectedProxyTag: 'Root',
      groups: [
        SubscriptionGroup(
          tag: 'Root',
          name: 'Root',
          outboundTags: ['leaf'],
          config: {
            'type': 'urltest',
            'outbounds': ['Nested'],
          },
        ),
        SubscriptionGroup(
          tag: 'Nested',
          name: 'Nested',
          outboundTags: ['leaf'],
          config: {
            'type': 'urltest',
            'outbounds': ['leaf'],
          },
        ),
      ],
      outbounds: [
        Outbound(
          tag: 'leaf',
          name: 'Leaf',
          config: {
            'type': 'vless',
            'server': 'example.com',
            'server_port': 443,
            'uuid': 'id',
          },
        ),
      ],
    );
    final cache = buildProxyCache(
      const ProxyCacheBuildInput(
        subscription: subscription,
        selectedProxyTag: 'Root',
        lowestLatency: null,
        runtimeLowestOutboundTag: null,
        runtimeLowestSelections: {},
        urlTestInFlight: false,
        runtimeLatencies: {},
        unavailableLatencyTags: {},
        latencyErrors: {},
        runtimeGroupSelections: {'Root': 'Nested', 'Nested': 'leaf'},
        markAllServersRussia: false,
      ),
    );
    final selections = <String>[];
    await tester.pumpWidget(
      _app(
        _page(
          proxies: cache.activeProxies,
          groups: cache.groupChildrenByTag,
          onSelected: selections.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proxy-open-group-Root')));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('proxy-group-sheet-surface'));
    final nested = find.descendant(
      of: panel,
      matching: find.byKey(const ValueKey('proxy-row-Nested')),
    );
    expect(nested, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: nested,
        matching: find.byKey(const ValueKey('proxy-open-group-Nested')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: panel, matching: find.text('Leaf')),
      findsOneWidget,
    );
    expect(selections, isEmpty);
    await tester.tap(find.descendant(of: panel, matching: find.text('Leaf')));
    expect(selections, ['leaf']);
    await tester.tap(find.byTooltip('Back').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: nested, matching: find.textContaining('Nested')),
    );
    expect(selections, ['leaf', 'Nested']);
  });

  testWidgets('only flag/name selects; whitespace and swipe are inert', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 873));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = 0;
    var tested = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ProxyTile(
              proxy: _proxy('Node'),
              selected: false,
              onTap: () => selected++,
              onTestLatency: () => tested++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = tester.getRect(find.byType(ProxyTile));
    await tester.tapAt(Offset(tile.right - 180, tile.center.dy));
    await tester.tapAt(Offset(tile.left + 25, tile.top + 2));
    expect(selected, 0);
    await tester.tap(find.text('Node'));
    expect(selected, 1);
    await tester.tapAt(Offset(tile.left + 30, tile.center.dy));
    expect(selected, 2);
    await tester.tap(find.text('42 ms'));
    expect(tested, 1);
    expect(selected, 2);
    await tester.tap(find.text('vless'));
    expect(selected, 2);
    await tester.drag(find.text('Node'), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(selected, 2);
  });

  testWidgets('group subtitle opens without selecting; name still selects', (
    tester,
  ) async {
    var selected = 0;
    var opened = 0;
    var tested = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ProxyTile(
            proxy: _proxy('Group', children: ['Node']),
            selected: false,
            onTap: () => selected++,
            onOpenGroup: (_) => opened++,
            onTestLatency: () => tested++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Automatic selection'));
    expect(opened, 1);
    expect(selected, 0);
    await tester.tap(find.text('Group'));
    expect(selected, 1);
    await tester.tap(find.text('42 ms'));
    expect(tested, 1);
    expect(selected, 1);
    expect(opened, 1);
    await tester.drag(
      find.textContaining('Automatic selection'),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(selected, 1);
  });

  testWidgets('group keeps its name outside and shows the actual leaf inside', (
    tester,
  ) async {
    final leaf = _proxy('Actual leaf');
    final nested = _proxy('Nested', children: [leaf.tag]);
    final group = _proxy(
      'Group',
      children: [nested.tag],
    ).copyWith(selectedChildTag: leaf.tag, selectedChildName: leaf.displayName);
    final selections = <String>[];
    await tester.pumpWidget(
      _app(
        _page(
          proxies: [group],
          groups: {
            'Group': [nested],
            'Nested': [leaf],
          },
          onSelected: selections.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Group'), findsOneWidget);
    expect(find.text('Group · Actual leaf'), findsNothing);
    await tester.tap(find.textContaining('Automatic selection'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('proxy-group-header-Group')),
        matching: find.text('Group · Actual leaf'),
      ),
      findsOneWidget,
    );
    expect(selections, isEmpty);
  });

  testWidgets('nested groups use one panel; back restores parent scroll', (
    tester,
  ) async {
    final leaf = _proxy('Leaf');
    final nested = _proxy('Nested', children: ['Leaf', 'Root']);
    final root = _proxy('Root', children: ['Nested', 'Node']);
    final rootChildren = [
      nested,
      ...List.generate(30, (i) => _proxy('Node $i')),
    ];
    final selections = <String>[];
    await tester.pumpWidget(
      _app(
        _page(
          proxies: [root],
          groups: {
            'Root': rootChildren,
            'Nested': [
              leaf,
              root,
              ...List.generate(30, (i) => _proxy('Leaf $i')),
            ],
          },
          onSelected: selections.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Automatic selection'));
    await tester.pumpAndSettle();
    final surface = find.byKey(const ValueKey('proxy-group-sheet-surface'));
    expect(surface, findsOneWidget);
    final list = find.descendant(of: surface, matching: find.byType(ListView));
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(72);
    await tester.pump();
    final nestedRow = find.byKey(const ValueKey('proxy-row-Nested'));
    await tester.tap(
      find.descendant(
        of: nestedRow,
        matching: find.textContaining('Automatic selection'),
      ),
    );
    await tester.pumpAndSettle();
    expect(surface, findsOneWidget);
    expect(find.text('Leaf'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('proxy-group-current-name')))
          .data,
      'Nested',
    );
    expect(selections, isEmpty);
    await tester.longPress(find.text('Leaf'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leaf'), findsOneWidget);
    // A cycle back to an ancestor must not open another panel.
    final cycle = find.descendant(
      of: surface,
      matching: find.byKey(const ValueKey('proxy-row-Root')),
    );
    await tester.longPress(
      find.descendant(of: cycle, matching: find.text('Root')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leaf'), findsOneWidget);
    tester.state<ScrollableState>(scrollable).position.jumpTo(90);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('proxy-row-Nested')), findsOneWidget);
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 72);
    expect(selections, isEmpty);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('proxy-row-Nested')),
        matching: find.textContaining('Automatic selection'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 90);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 72);
    expect(selections, isEmpty);
  });

  testWidgets(
    'narrow group rows fit enlarged text and inherit platform physics',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 873));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final group = _proxy(
        'A long automatic selection group name',
        children: ['Leaf'],
      );
      await tester.pumpWidget(
        _app(
          _page(
            proxies: [group],
            groups: {
              group.tag: [_proxy('Leaf')],
            },
            onSelected: (_) {},
          ),
          platform: TargetPlatform.iOS,
          textScaler: TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListView>(find.byType(ListView)).physics,
        isNot(isA<ClampingScrollPhysics>()),
      );
      await tester.tap(find.byKey(ValueKey('proxy-open-group-${group.tag}')));
      await tester.pumpAndSettle();
      final list = find.descendant(
        of: find.byKey(const ValueKey('proxy-group-sheet-surface')),
        matching: find.byType(ListView),
      );
      expect(
        tester.widget<ListView>(list).physics,
        isNot(isA<ClampingScrollPhysics>()),
      );
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scrollable).position.physics.toString(),
        contains('BouncingScrollPhysics'),
      );
      final name = tester.getRect(
        find.byKey(const ValueKey('proxy-group-current-name')),
      );
      final back = tester.getRect(find.byTooltip('Back').last);
      expect(name.left, greaterThanOrEqualTo(back.right));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('full proxy panel retains rows after sharing and system back', (
    tester,
  ) async {
    var copies = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copies++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      _app(
        _page(
          proxies: List.generate(12, (i) => _proxy('Node $i')),
          onSelected: (_) {},
          shell: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proxy-sheet-header')));
    await tester.pumpAndSettle();
    expect(find.text('Node 0'), findsOneWidget);
    await tester.longPress(find.text('Node 0'));
    await tester.pumpAndSettle();
    expect(find.text('Node 0'), findsNWidgets(2));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Node 0'), findsOneWidget);
    expect(find.text('Node 1'), findsOneWidget);
    await tester.longPress(find.text('Node 0'));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(ProxiesPage)));
    await tester.tap(find.text(l10n.shareProxyLinkLabel));
    await tester.pumpAndSettle();
    expect(copies, 1);
    expect(find.text('Node 0'), findsOneWidget);
    expect(find.text('Node 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
