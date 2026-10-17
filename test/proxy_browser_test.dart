import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/features/home/home_page.dart';
import 'package:meow_client/features/home/home_presentation.dart';
import 'package:meow_client/features/home/tabbed_home_shell.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';

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
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  locale: const Locale('en'),
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
  selectedTag: '',
  connected: true,
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
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
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
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
      states.replaceAll({
        'Auto': ProxyRuntimeVisualState(
          presentation: group.copyWith(selectedChildTag: 'Two'),
        ),
      });
      await tester.pumpAndSettle(const Duration(milliseconds: 120));
      expect(tile('Two').selected, isTrue);
      expect(tile('One').selected, isFalse);
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
      await tester.tap(find.byKey(const ValueKey('proxy-latency-action-Auto')));
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
