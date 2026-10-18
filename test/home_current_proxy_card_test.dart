import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/home/home_current_proxy_card.dart';
import 'package:meow_client/features/home/home_page.dart';
import 'package:meow_client/features/home/home_presentation.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';
import 'package:meow_client/theme/app_theme.dart';

const _proxy = AppProxySummary(
  tag: 'auto',
  displayName: 'Sweden server',
  countryCode: 'SE',
  type: 'vless',
  server: 'example.com',
  port: 443,
  detailText: 'VLESS',
  ip: '',
  latency: 42,
  latencyFresh: true,
  latencyChecking: false,
  latencyUnavailable: false,
  latencyError: null,
  protocolLabel: 'VLESS',
  endpointLabel: 'example.com:443',
);

Widget _app(Widget child, {ThemeData? theme, double textScale = 1}) =>
    MaterialApp(
      theme: theme,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: child,
    );

HomePage _home({
  AppProxySummary proxy = _proxy,
  VoidCallback? open,
  VoidCallback? refresh,
  ValueChanged<String>? group,
  ProxyRuntimeVisualStore? states,
}) => HomePage(
  state: HomeViewState(
    connected: true,
    connecting: false,
    resolvingProxy: false,
    connectionStatusLabel: 'Connected',
    activeProfile: const AppProfileSummary(
      id: 'profile',
      name: 'Profile',
      consumed: 0,
      total: 0,
      remainingDays: null,
      outboundsCount: 2,
      sourceLabel: '',
    ),
    activeProxy: proxy,
    runtimeStates: states,
    hideServerIp: false,
    hapticEnabled: false,
    speedBytesPerSecond: 0,
    trafficBytes: 0,
    brandName: 'Etonify',
    versionLabel: '0.3.9',
  ),
  actions: HomeViewActions(
    toggleConnection: () {},
    refreshLatency: refresh ?? () {},
    openSubscriptions: () {},
    addSubscription: () {},
    openSettings: () {},
    openChangelog: () {},
    openProxies: open ?? () {},
    openProxyGroup: group,
  ),
  bottomInset: 0,
);

void main() {
  testWidgets(
    'central ping grows for large text instead of clipping its digits',
    (tester) async {
      var refreshes = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: ActiveProxyDelayIndicator(
                connected: true,
                proxy: _proxy,
                onRefresh: () => refreshes++,
              ),
            ),
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      final indicator = find.byType(ActiveProxyDelayIndicator);
      expect(tester.getSize(indicator).height, greaterThanOrEqualTo(56));
      await tester.tap(indicator);
      expect(refreshes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion shows the mini-card immediately without a slide',
    (tester) async {
      await tester.pumpWidget(
        _app(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: HomeCurrentProxyCard(proxy: _proxy, onTap: () {}),
          ),
        ),
      );
      final card = find.byKey(const ValueKey('home-current-proxy-card'));
      expect(
        find.ancestor(
          of: card,
          matching: find.byType(TweenAnimationBuilder<double>),
        ),
        findsNothing,
      );
      expect(card.hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'mini-card enters gradually and ping updates do not replay entrance',
    (tester) async {
      final states = ProxyRuntimeVisualStore();
      addTearDown(states.dispose);
      await tester.pumpWidget(_app(_home(states: states)));
      final card = find.byKey(const ValueKey('home-current-proxy-card'));
      final opacity = find
          .ancestor(of: card, matching: find.byType(Opacity))
          .first;
      expect(opacity, findsOneWidget);
      expect(tester.widget<Opacity>(opacity).opacity, lessThan(1));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      states.replaceAll({
        'auto': const ProxyRuntimeVisualState(latency: 83, latencyFresh: true),
      });
      await tester.pump();
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      expect(find.byType(ActiveProxyDelayIndicator), findsOneWidget);
    },
  );

  testWidgets('home removes mini-card ping but keeps central ping clickable', (
    tester,
  ) async {
    var opens = 0;
    var pings = 0;
    await tester.pumpWidget(
      _app(_home(open: () => opens++, refresh: () => pings++)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('proxy-latency-action-auto')),
      findsNothing,
    );
    await tester.tap(find.byType(ActiveProxyDelayIndicator));
    expect(pings, 1);
    expect(opens, 0);
    await tester.tap(find.text('Sweden server'));
    expect(opens, 1);
    expect(pings, 1);
  });

  testWidgets('home group subtitle has independent 48dp action', (
    tester,
  ) async {
    var opens = 0;
    final groups = <String>[];
    await tester.pumpWidget(
      _app(
        _home(
          proxy: _proxy.copyWith(isGroup: true, childCount: 5),
          open: () => opens++,
          group: groups.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final group = find.byKey(const ValueKey('proxy-open-group-auto'));
    expect(tester.getSize(group).height, greaterThanOrEqualTo(48));
    await tester.tap(group);
    expect(groups, ['auto']);
    expect(opens, 0);
    await tester.tap(find.text('Sweden server'));
    expect(opens, 1);
  });

  testWidgets('home card follows updated runtime proxy identity', (
    tester,
  ) async {
    final states = ProxyRuntimeVisualStore();
    addTearDown(states.dispose);
    await tester.pumpWidget(_app(_home(states: states)));
    states.replaceAll({
      'auto': ProxyRuntimeVisualState(
        presentation: _proxy.copyWith(
          displayName: 'New current server',
          protocolLabel: 'Trojan',
          countryCode: 'FR',
        ),
      ),
    });
    await tester.pumpAndSettle();
    expect(find.text('New current server'), findsOneWidget);
    expect(find.text('Trojan'), findsOneWidget);
    expect(find.text('Sweden server'), findsNothing);
    expect(
      find.byKey(const ValueKey('proxy-latency-action-auto')),
      findsNothing,
    );
  });

  for (final group in [false, true]) {
    testWidgets('compact home card fits long names at 200% text group=$group', (
      tester,
    ) async {
      var opens = 0;
      final proxy = _proxy.copyWith(
        displayName:
            'A very long server name that must use all available width',
        isGroup: group,
        childCount: group ? 123 : 0,
      );
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 288,
                child: HomeCurrentProxyCard(
                  proxy: proxy,
                  onTap: () => opens++,
                  onOpenGroup: () {},
                ),
              ),
            ),
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final title = find.text(proxy.displayName);
      final card = find.byKey(const ValueKey('home-current-proxy-card'));
      expect(tester.getSize(title).width, greaterThan(200));
      expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
      expect(
        tester.getRect(title).right,
        closeTo(tester.getRect(card).right - 16, 1),
      );
      await tester.tap(title);
      expect(opens, 1);
    });
  }

  testWidgets('lowest card preserves selected name and empty group metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: HomeCurrentProxyCard(
            proxy: _proxy.copyWith(
              tag: 'lowest',
              displayName: 'lowest · Sweden server',
              protocolLabel: '',
              isGroup: true,
              childCount: 5,
            ),
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('Lowest · Sweden server'), findsOneWidget);
    expect(find.text('Automatic selection · 5 proxies'), findsOneWidget);
  });

  testWidgets('AMOLED connected moon retains green and toggle action', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ConnectionButton(
            connected: true,
            connecting: false,
            resolvingProxy: false,
            statusLabel: 'Connected',
            onTap: () => toggles++,
          ),
        ),
        theme: buildAmoledTheme(),
      ),
    );
    final logo = find.byKey(const ValueKey('connection-button-logo'));
    expect(
      tester.widget<SvgPicture>(logo).colorFilter,
      const ColorFilter.mode(Color(0xFF34D399), BlendMode.srcIn),
    );
    final material = tester.widget<Material>(
      find.ancestor(of: logo, matching: find.byType(Material)).first,
    );
    expect(material.color!.computeLuminance(), lessThan(.01));
    await tester.tap(logo);
    expect(toggles, 1);
  });

  for (final brightness in Brightness.values) {
    testWidgets('connection surface preserves $brightness contrast', (
      tester,
    ) async {
      final dark = brightness == Brightness.dark;
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: ConnectionButton(
              connected: false,
              connecting: false,
              resolvingProxy: false,
              statusLabel: '',
              onTap: _noop,
            ),
          ),
          theme: ThemeData(
            brightness: brightness,
            extensions: [
              dark ? ConnectionButtonTheme.dark : ConnectionButtonTheme.light,
            ],
          ),
        ),
      );
      final logo = find.byKey(const ValueKey('connection-button-logo'));
      final material = tester.widget<Material>(
        find.ancestor(of: logo, matching: find.byType(Material)).first,
      );
      expect(
        material.color!.computeLuminance(),
        dark ? lessThan(.1) : equals(1),
      );
      expect(
        tester.widget<SvgPicture>(logo).colorFilter,
        ColorFilter.mode(
          dark ? Colors.white : const Color(0xFF2D5BFF),
          BlendMode.srcIn,
        ),
      );
    });
  }
}

void _noop() {}
