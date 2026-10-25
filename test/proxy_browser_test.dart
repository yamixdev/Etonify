import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/features/home/home_page.dart';
import 'package:meow_client/features/home/home_presentation.dart';
import 'package:meow_client/features/home/tabbed_home_shell.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';
import 'package:meow_client/widgets/app_loading_indicator.dart';
import 'package:meow_client/theme/app_theme.dart';

class _CountingRuntimeStore extends ProxyRuntimeVisualStore {
  int reads = 0;

  @override
  ProxyRuntimeVisualState? valueFor(String tag) {
    reads++;
    return super.valueFor(tag);
  }
}

AppProxySummary _proxy(String tag, {List<String> children = const []}) =>
    AppProxySummary(
      tag: tag,
      displayName: tag,
      countryCode: 'SE',
      type: children.isEmpty ? 'vless' : 'urltest',
      server: 'example.com',
      port: 443,
      detailText: 'VLESS · REALITY',
      ip: '',
      latency: 42,
      latencyFresh: true,
      latencyChecking: false,
      latencyUnavailable: false,
      latencyError: null,
      protocolLabel: 'VLESS',
      endpointLabel: 'example.com:443',
      isGroup: children.isNotEmpty,
      childTags: children,
      childCount: children.length,
    );

Widget _app(
  Widget page, {
  TextScaler? scaler,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: scaler == null
      ? null
      : (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        ),
  home: page,
);

ProxiesPage _page({
  List<AppProxySummary>? proxies,
  Map<String, List<AppProxySummary>>? groups,
  ValueChanged<String>? select,
  Future<void> Function(String)? ping,
  VoidCallback? back,
  String profileId = 'profile',
  ProxyRuntimeVisualStore? states,
  ({int serial, String? groupTag})? request,
  bool loading = false,
  bool active = true,
  bool catalogReady = true,
  bool connected = true,
  String selectedTag = '',
  AppProxySummary? activeProxy,
  ProxySort initialSort = ProxySort.source,
  bool hideUnavailable = false,
}) => ProxiesPage(
  profileId: profileId,
  proxies:
      proxies ??
      [
        _proxy('Auto', children: ['Nested', 'Leaf']),
        _proxy('Other'),
      ],
  groupChildrenByTag:
      groups ??
      {
        'Auto': [
          _proxy('Nested', children: ['Deep']),
          _proxy('Leaf').copyWith(parentGroupTag: 'Auto'),
        ],
        'Nested': [_proxy('Deep').copyWith(parentGroupTag: 'Nested')],
      },
  selectedTag: selectedTag,
  activeProxy: activeProxy,
  initialSort: initialSort,
  hideUnavailable: hideUnavailable,
  connected: connected,
  progressiveBlurEnabled: false,
  browserMode: true,
  browserRequest: request,
  browserActive: active,
  loading: loading,
  catalogReady: catalogReady,
  onBackAtRoot: back,
  hapticEnabled: false,
  runtimeStates: states,
  onSelected: select ?? (_) {},
  onUrlTest: () async {},
  onProxyUrlTest: ping,
);

void main() {
  testWidgets(
    'sort options remain reachable at narrow width and doubled Russian text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(_page(), locale: const Locale('ru'), scaler: TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Сортировка'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Скрывать недоступные'));
      await tester.tap(find.text('Скрывать недоступные'));
      await tester.ensureVisible(find.text('Готово'));
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'large source list filters live status in the background worker',
    (tester) async {
      final states = ProxyRuntimeVisualStore();
      addTearDown(states.dispose);
      states.replaceAll({
        'First': const ProxyRuntimeVisualState(latencyUnavailable: true),
      });
      await tester.pumpWidget(
        _app(
          _page(
            proxies: [
              _proxy('First'),
              for (var i = 0; i < 500; i++) _proxy('Server $i'),
            ],
            states: states,
            hideUnavailable: true,
          ),
        ),
      );
      Future<void> waitFor(String name) async {
        for (var i = 0; i < 150 && find.text(name).evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.text(name), findsOneWidget);
      }

      await waitFor('Server 0');
      expect(find.text('First'), findsNothing);
      states.replaceAll({
        'First': const ProxyRuntimeVisualState(latency: 40, latencyFresh: true),
      });
      await tester.pump(const Duration(milliseconds: 650));
      await waitFor('First');
      expect(
        tester.getTopLeft(find.text('First')).dy,
        lessThan(tester.getTopLeft(find.text('Server 0')).dy),
      );
    },
  );
  testWidgets('sort sheet separates filtering from order and applies both', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _page(
          proxies: [
            _proxy('Zulu'),
            _proxy('Bad').copyWith(latencyUnavailable: true, latency: null),
            _proxy('Alpha').copyWith(latency: null, latencyFresh: false),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    expect(find.text('Working only'), findsNothing);
    expect(find.byType(SwitchListTile), findsOneWidget);
    await tester.tap(find.text('Hide unavailable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('By name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Bad'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Zulu')).dy),
    );
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.tap(find.text('Hide unavailable'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Bad'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Bad')).dy),
    );
  });
  for (final connected in [true, false]) {
    testWidgets(
      'current choice ping is actionable and live connected=$connected',
      (tester) async {
        final states = ProxyRuntimeVisualStore();
        addTearDown(states.dispose);
        final pings = <String>[];
        final selections = <String>[];
        await tester.pumpWidget(
          _app(
            _page(
              proxies: [_proxy('Selected')],
              groups: {},
              selectedTag: 'Selected',
              connected: connected,
              states: states,
              select: selections.add,
              ping: (tag) async {
                pings.add(tag);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('proxy-current-choice'));
        expect(
          find.descendant(of: card, matching: find.text('Selected proxy')),
          findsNothing,
        );
        final ping = find.descendant(of: card, matching: find.text('42 ms'));
        expect(ping, findsOneWidget);
        await tester.tap(ping);
        expect(pings, ['Selected']);
        expect(selections, isEmpty);
        states.replaceAll({
          'Selected': const ProxyRuntimeVisualState(
            latency: 137,
            latencyFresh: true,
          ),
        });
        await tester.pump();
        expect(
          find.descendant(of: card, matching: find.text('137 ms')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('current choice uses accent outline without a circular check', (
    tester,
  ) async {
    final theme = buildAppTheme(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: _page(
          proxies: [_proxy('Selected')],
          groups: {},
          selectedTag: 'Selected',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('proxy-current-choice'));
    expect(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsNothing,
    );
    final decoration =
        tester.widget<Container>(card).decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
    final border = decoration.border! as Border;
    expect(border.top.color.a, greaterThanOrEqualTo(.65));
    expect(find.byKey(const ValueKey('proxy-select-Selected')), findsOneWidget);
  });

  testWidgets(
    'nested active summary arrival and removal update header structure',
    (tester) async {
      final leaf = _proxy('Leaf').copyWith(parentGroupTag: 'Auto');
      final proxies = [
        _proxy('Auto', children: ['Leaf']),
        _proxy('Other'),
      ];
      final groups = {
        'Auto': [leaf],
      };
      Widget page(AppProxySummary? active) => _app(
        _page(
          proxies: proxies,
          groups: groups,
          selectedTag: 'Leaf',
          activeProxy: active,
        ),
      );
      await tester.pumpWidget(page(null));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('proxy-current-choice')), findsNothing);
      await tester.pumpWidget(page(leaf));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('proxy-current-choice')),
        findsOneWidget,
      );
      expect(find.text('Leaf'), findsOneWidget);
      expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsNothing);
      await tester.pumpWidget(page(null));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('proxy-current-choice')), findsNothing);
    },
  );

  for (final count in [20, 500]) {
    testWidgets('active IP update does not prepare $count rows during a drag', (
      tester,
    ) async {
      final proxies = [
        for (var i = 0; i < count; i++)
          _proxy('Server $i').copyWith(latency: i + 10),
      ];
      final groups = <String, List<AppProxySummary>>{};
      final states = _CountingRuntimeStore();
      addTearDown(states.dispose);
      Widget page(AppProxySummary active) => _app(
        _page(
          proxies: proxies,
          groups: groups,
          states: states,
          selectedTag: 'Server 0',
          activeProxy: active,
          initialSort: ProxySort.latency,
        ),
      );
      await tester.pumpWidget(page(proxies.first));
      for (
        var i = 0;
        i < 120 &&
            find
                .byKey(const ValueKey('proxy-current-choice'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }
      final list = find.byKey(const ValueKey('proxy-browser-list'));
      final gesture = await tester.startGesture(tester.getCenter(list));
      await gesture.moveBy(const Offset(0, -35));
      await tester.pump();
      states.replaceAll({
        'Server 0': const ProxyRuntimeVisualState(
          latency: 9999,
          latencyFresh: true,
        ),
      });
      await tester.pump(const Duration(seconds: 1));
      final readsBefore = states.reads;
      final controller = tester.widget<ListView>(list).controller!;
      final offsetBefore = controller.offset;
      final source = find.byKey(const ValueKey('proxy-select-Server 0'));
      final rectBefore = tester.getRect(source);
      await tester.pumpWidget(page(proxies.first.copyWith(ip: '192.0.2.10')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(states.reads, readsBefore);
      expect(controller.offset, offsetBefore);
      expect(tester.getRect(source), rectBefore);
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets(
    'last proxy stays above floating navigation and can be selected',
    (tester) async {
      tester.view.physicalSize = const Size(393, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = <String>[];
      final proxies = [for (var i = 0; i < 80; i++) _proxy('Server $i')];
      await tester.pumpWidget(
        _app(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(393, 800),
              padding: EdgeInsets.only(bottom: 24),
              viewPadding: EdgeInsets.only(bottom: 24),
            ),
            child: TabbedHomeShell(
              homeBuilder: (_, open) => const SizedBox.expand(),
              proxiesBuilder: (_, active, back, request) => _page(
                proxies: proxies,
                groups: {},
                selectedTag: 'Server 0',
                select: selected.add,
                active: active,
                back: back,
                request: request,
              ),
              settingsBuilder: (_) => const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('proxies-tab')));
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('proxy-browser-list'));
      final controller = tester.widget<ListView>(list).controller!;
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final last = find.byKey(const ValueKey('proxy-select-Server 79'));
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(
          tester
              .getRect(find.byKey(const ValueKey('floating-bottom-navigation')))
              .top,
        ),
      );
      await tester.tap(last);
      expect(selected, ['Server 79']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('background presentation refreshes current choice metadata', (
    tester,
  ) async {
    final proxies = [for (var i = 0; i < 500; i++) _proxy('Server $i')];
    final groups = <String, List<AppProxySummary>>{};
    Future<void> waitFor(Finder target) async {
      for (var i = 0; i < 120; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 1));
        if (target.evaluate().isNotEmpty) return;
      }
      expect(target, findsOneWidget);
    }

    await tester.pumpWidget(
      _app(
        _page(
          proxies: proxies,
          groups: groups,
          selectedTag: 'Server 0',
          activeProxy: proxies.first,
        ),
      ),
    );
    await waitFor(find.byKey(const ValueKey('proxy-current-choice')));
    await tester.pumpWidget(
      _app(
        _page(
          proxies: proxies,
          groups: groups,
          selectedTag: 'Server 0',
          activeProxy: proxies.first.copyWith(
            displayName: 'Updated current choice',
          ),
        ),
      ),
    );
    await waitFor(find.text('Updated current choice'));
    expect(find.byKey(const ValueKey('proxy-select-Server 0')), findsOneWidget);
  });

  testWidgets('group header identity updates without preparing its catalog', (
    tester,
  ) async {
    final group = _proxy(
      'lowest',
      children: ['Leaf'],
    ).copyWith(selectedChildName: 'Old member');
    final proxies = [group, _proxy('Other')];
    final groups = <String, List<AppProxySummary>>{};
    final states = _CountingRuntimeStore();
    addTearDown(states.dispose);
    Widget page(AppProxySummary active) => _app(
      _page(
        proxies: proxies,
        groups: groups,
        states: states,
        selectedTag: 'lowest',
        activeProxy: active,
      ),
    );
    await tester.pumpWidget(page(group));
    await tester.pumpAndSettle();
    final readsBefore = states.reads;
    await tester.pumpWidget(
      page(group.copyWith(countryCode: 'FR', selectedChildName: 'New member')),
    );
    await tester.pump();
    final header = find.byKey(const ValueKey('proxy-current-choice'));
    expect(
      find.descendant(of: header, matching: find.text('Lowest · New member')),
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
      'FR',
    );
    expect(states.reads, readsBefore);
  });
  testWidgets(
    'selected source row exposes its selected state to accessibility',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          _page(
            proxies: [_proxy('First'), _proxy('Selected')],
            groups: {},
            selectedTag: 'Selected',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final data = tester
          .getSemantics(find.byKey(const ValueKey('proxy-select-Selected')))
          .getSemanticsData();
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      semantics.dispose();
    },
  );

  testWidgets(
    'current choice fits a long Russian group at 320px and 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final group = _proxy(
        'Очень длинная группа автоматического выбора сервера',
        children: ['Leaf'],
      );
      await tester.pumpWidget(
        _app(
          _page(
            proxies: [group],
            groups: {
              group.tag: [_proxy('Leaf')],
            },
            selectedTag: group.tag,
            activeProxy: group,
          ),
          scaler: TextScaler.linear(2),
          locale: const Locale('ru'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('proxy-current-choice')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'root shows current choice without moving or duplicating source',
    (tester) async {
      final proxies = [_proxy('First'), _proxy('Selected'), _proxy('Last')];
      await tester.pumpWidget(
        _app(_page(proxies: proxies, groups: {}, selectedTag: 'Selected')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('proxy-current-choice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('proxy-select-Selected')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('proxy-select-First'))).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('proxy-select-Selected')))
              .dy,
        ),
      );
      expect(
        tester
            .widget<ProxyTile>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is ProxyTile && widget.proxy.tag == 'Selected',
              ),
            )
            .selected,
        isTrue,
      );
    },
  );

  testWidgets(
    'nested current choice is header only and disappears inside group',
    (tester) async {
      final leaf = _proxy('Leaf').copyWith(parentGroupTag: 'Auto');
      await tester.pumpWidget(
        _app(_page(selectedTag: 'Leaf', activeProxy: leaf)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('proxy-current-choice')),
        findsOneWidget,
      );
      expect(find.text('Leaf'), findsOneWidget);
      expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('proxy-open-group-Auto')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('proxy-current-choice')), findsNothing);
      expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsOneWidget);
    },
  );

  testWidgets(
    'selecting a scrolled row preserves its position and scroll offset',
    (tester) async {
      final proxies = [for (var i = 0; i < 100; i++) _proxy('Server $i')];
      var selected = 'Server 0';
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => _page(
              proxies: proxies,
              groups: {},
              selectedTag: selected,
              select: (tag) => setState(() => selected = tag),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('proxy-browser-list'));
      await tester.drag(list, const Offset(0, -650));
      await tester.pumpAndSettle();
      final tile = find.byType(ProxyTile).hitTestable().first;
      final tag = tester.widget<ProxyTile>(tile).proxy.tag;
      final row = find.byKey(ValueKey('proxy-select-$tag'));
      final beforeRect = tester.getRect(row);
      final controller = tester.widget<ListView>(list).controller!;
      final beforeOffset = controller.offset;
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(selected, tag);
      expect(controller.offset, beforeOffset);
      expect(tester.getRect(row), beforeRect);
      expect(find.byKey(ValueKey('proxy-select-$tag')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('proxy-current-choice')).hitTestable(),
        findsNothing,
      );
      await tester.drag(list, const Offset(0, 1800));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('proxy-current-choice')),
          matching: find.text(tag),
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('search keyboard does not overflow the retained home page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      _app(
        TabbedHomeShell(
          homeBuilder: (context, open) => HomePage(
            state: HomeViewState(
              connected: true,
              connecting: false,
              resolvingProxy: false,
              connectionStatusLabel: 'Connected',
              activeProfile: const AppProfileSummary(
                id: 'p',
                name: 'Profile',
                consumed: 0,
                total: 0,
                remainingDays: null,
                outboundsCount: 2,
                sourceLabel: '',
              ),
              activeProxy: _proxy('Auto', children: ['Leaf']),
              hideServerIp: false,
              hapticEnabled: false,
              speedBytesPerSecond: 0,
              trafficBytes: 0,
              brandName: 'Etonify',
              versionLabel: '0.3.9',
            ),
            actions: HomeViewActions(
              toggleConnection: () {},
              refreshLatency: () {},
              openSubscriptions: () {},
              addSubscription: () {},
              openSettings: () {},
              openChangelog: () {},
              openProxies: () => open(null),
              openProxyGroup: open,
            ),
            bottomInset: 12,
          ),
          proxiesBuilder: (context, active, back, request) =>
              _page(active: active, back: back, request: request),
        ),
        scaler: TextScaler.linear(1.5),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proxies-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThanOrEqualTo(360),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('back during catalog loading keeps the parent group title', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_page()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proxy-open-group-Auto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proxy-open-group-Nested')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(_page(proxies: [], groups: {}, catalogReady: false)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('proxy-browser-back')));
    await tester.pump();
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Nested'), findsNothing);
  });
  for (final brightness in Brightness.values) {
    testWidgets('browser handles large text on a narrow $brightness screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(_page(), scaler: TextScaler.linear(2), brightness: brightness),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('proxy-open-group-Auto')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'large browser stays lazy through background preparation and search',
    (tester) async {
      final proxies = [for (var i = 0; i < 5000; i++) _proxy('Server $i')];
      await tester.pumpWidget(_app(_page(proxies: proxies, groups: {})));
      Future<void> settleWorker() async {
        for (var i = 0; i < 300; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 1));
          if (find.byType(AppLoadingIndicator).evaluate().isEmpty) return;
        }
        fail('Background presentation did not finish');
      }

      await settleWorker();
      expect(find.byType(ProxyTile).evaluate().length, lessThan(35));
      await tester.enterText(find.byType(TextField), 'Server 4999');
      await tester.pump(const Duration(milliseconds: 200));
      for (
        var i = 0;
        i < 300 &&
            find
                .byKey(const ValueKey('proxy-select-Server 4999'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(
        find.byKey(const ValueKey('proxy-select-Server 4999')),
        findsOneWidget,
      );
      expect(find.byType(ProxyTile), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'temporary catalog eviction retains group search until rehydration',
    (tester) async {
      await tester.pumpWidget(_app(_page()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('proxy-open-group-Auto')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'leaf');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _app(
          _page(proxies: [], groups: {}, active: false, catalogReady: false),
        ),
      );
      await tester.pump();
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      await tester.pumpWidget(_app(_page()));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'leaf',
      );
      expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsOneWidget);
      expect(find.byKey(const ValueKey('proxy-select-Other')), findsNothing);
    },
  );
  testWidgets(
    'auto selection highlight follows live group selection in source order',
    (tester) async {
      final states = ProxyRuntimeVisualStore();
      addTearDown(states.dispose);
      final group = _proxy(
        'Auto',
        children: ['One', 'Two'],
      ).copyWith(selectedChildTag: 'One');
      await tester.pumpWidget(
        _app(
          _page(
            proxies: [group],
            groups: {
              'Auto': [_proxy('One'), _proxy('Two')],
            },
            states: states,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('proxy-open-group-Auto')));
      await tester.pumpAndSettle();
      ProxyTile tile(String tag) => tester.widget<ProxyTile>(
        find.ancestor(
          of: find.byKey(ValueKey('proxy-select-$tag')),
          matching: find.byType(ProxyTile),
        ),
      );
      expect(tile('One').selected, isTrue);
      final firstPosition = tester.getRect(
        find.byKey(const ValueKey('proxy-select-One')),
      );
      states.replaceAll({
        'Auto': ProxyRuntimeVisualState(
          presentation: group.copyWith(selectedChildTag: 'Two'),
        ),
      });
      await tester.pumpAndSettle(const Duration(milliseconds: 120));
      expect(tile('Two').selected, isTrue);
      expect(tile('One').selected, isFalse);
      expect(
        tester.getRect(find.byKey(const ValueKey('proxy-select-One'))),
        firstPosition,
      );
    },
  );

  testWidgets('home group request survives asynchronous profile hydration', (
    tester,
  ) async {
    const request = (serial: 1, groupTag: 'Auto');
    await tester.pumpWidget(
      _app(_page(proxies: [], groups: {}, request: request, loading: true)),
    );
    await tester.pump();
    await tester.pumpWidget(_app(_page(request: request)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsOneWidget);
    expect(find.byKey(const ValueKey('proxy-select-Other')), findsNothing);
  });

  testWidgets(
    'removed open group returns to the root without leaking its members',
    (tester) async {
      await tester.pumpWidget(_app(_page()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('proxy-open-group-Auto')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _app(_page(proxies: [_proxy('Fresh')], groups: {})),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('proxy-select-Fresh')), findsOneWidget);
      expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsNothing);
    },
  );
  testWidgets(
    'home card opens root or auto group and leaves ping independent',
    (tester) async {
      var opens = 0;
      var pings = 0;
      final groups = <String>[];
      await tester.pumpWidget(
        _app(
          HomePage(
            state: HomeViewState(
              connected: true,
              connecting: false,
              resolvingProxy: false,
              connectionStatusLabel: 'Connected',
              activeProfile: const AppProfileSummary(
                id: 'p',
                name: 'Profile',
                consumed: 0,
                total: 0,
                remainingDays: null,
                outboundsCount: 2,
                sourceLabel: '',
              ),
              activeProxy: _proxy(
                'Auto',
                children: ['Leaf'],
              ).copyWith(membersSelectable: false),
              hideServerIp: false,
              hapticEnabled: false,
              speedBytesPerSecond: 0,
              trafficBytes: 0,
              brandName: 'Etonify',
              versionLabel: '0.3.9',
            ),
            actions: HomeViewActions(
              toggleConnection: () {},
              refreshLatency: () => pings++,
              openSubscriptions: () {},
              addSubscription: () {},
              openSettings: () {},
              openChangelog: () {},
              openProxies: () => opens++,
              openProxyGroup: groups.add,
            ),
            bottomInset: 12,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auto'));
      expect(opens, 1);
      await tester.tap(find.byKey(const ValueKey('proxy-open-group-Auto')));
      expect(groups, ['Auto']);
      expect(
        find.byKey(const ValueKey('proxy-latency-action-Auto')),
        findsNothing,
      );
      await tester.tap(find.byType(ActiveProxyDelayIndicator));
      expect(pings, 1);
      expect(opens, 1);
      expect(groups, ['Auto']);
    },
  );
  testWidgets('browser group navigation stays inline and never selects a row', (
    tester,
  ) async {
    final selected = <String>[];
    var backs = 0;
    await tester.pumpWidget(
      _app(_page(select: selected.add, back: () => backs++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proxy-open-group-Auto')));
    await tester.pumpAndSettle();
    expect(find.byType(ProxiesPage), findsOneWidget);
    expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsOneWidget);
    expect(find.byKey(const ValueKey('proxy-select-Other')), findsNothing);
    expect(selected, isEmpty);
    await tester.tap(find.byKey(const ValueKey('proxy-open-group-Nested')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('proxy-select-Deep')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsOneWidget);
    expect(backs, 0);
    await tester.tap(find.byKey(const ValueKey('proxy-browser-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('proxy-select-Other')), findsOneWidget);
    expect(find.byKey(const ValueKey('proxy-select-Deep')), findsNothing);
    expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(backs, 1);
  });

  testWidgets('browser ping and group buttons do not select; row space does', (
    tester,
  ) async {
    final selected = <String>[];
    final pings = <String>[];
    await tester.pumpWidget(
      _app(_page(select: selected.add, ping: (tag) async => pings.add(tag))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proxy-latency-action-Auto')));
    expect(pings, ['Auto']);
    expect(selected, isEmpty);
    final row = tester.getRect(
      find.byKey(const ValueKey('proxy-select-Other')),
    );
    await tester.tapAt(Offset(row.right - 120, row.center.dy));
    expect(selected, ['Other']);
    await tester.drag(
      find.byKey(const ValueKey('proxy-select-Auto')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(selected, ['Other']);
  });

  testWidgets('browser search is scoped and restores parent search on back', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_page()));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('proxy-browser-search'));
    await tester.enterText(search, 'auto');
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('proxy-select-Other')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('proxy-open-group-Auto')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    await tester.enterText(search, 'leaf');
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsOneWidget);
    expect(find.byKey(const ValueKey('proxy-select-Nested')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('proxy-browser-back')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, 'auto');
    expect(find.byKey(const ValueKey('proxy-select-Other')), findsNothing);
  });

  testWidgets('profile replacement clears old group navigation and search', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_page()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proxy-open-group-Auto')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'leaf');
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.pumpWidget(
      _app(_page(profileId: 'new', proxies: [_proxy('Fresh')], groups: {})),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('proxy-select-Fresh')), findsOneWidget);
    expect(find.byKey(const ValueKey('proxy-select-Leaf')), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets(
    'browser builds a bounded number of rows and retains scroll on ping',
    (tester) async {
      final proxies = [for (var i = 0; i < 300; i++) _proxy('Server $i')];
      final states = ProxyRuntimeVisualStore();
      addTearDown(states.dispose);
      await tester.pumpWidget(
        _app(_page(proxies: proxies, groups: {}, states: states)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProxyTile).evaluate().length, lessThan(35));
      final list = find.byKey(const ValueKey('proxy-browser-list'));
      await tester.drag(list, const Offset(0, -650));
      await tester.pumpAndSettle();
      final controller = tester.widget<ListView>(list).controller!;
      final before = controller.offset;
      states.replaceAll({
        'Server 12': const ProxyRuntimeVisualState(
          latency: 23,
          latencyFresh: true,
        ),
      });
      await tester.pumpAndSettle();
      expect(controller.offset, before);
      expect(find.byType(ProxyTile).evaluate().length, lessThan(35));
    },
  );
}
