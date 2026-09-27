import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/models/url_test_progress.dart';

void main() {
  group('Historical latency persistence and UI tests', () {
    test('OutboundInfo toMap and fromMap preserve latestPing', () {
      const infoWithPing = OutboundInfo(
        checked: true,
        externalIp: '1.2.3.4',
        country: 'DE',
        exitCountry: 'NL',
        latestPing: 142,
      );
      final map = infoWithPing.toMap();
      expect(map['latest_ping'], 142);
      expect(map['country'], 'DE');

      final restored = OutboundInfo.fromMap(map);
      expect(restored.latestPing, 142);
      expect(restored.country, 'DE');
      expect(restored.checked, isTrue);

      const infoWithoutPing = OutboundInfo(checked: false);
      final emptyMap = infoWithoutPing.toMap();
      expect(emptyMap.containsKey('latest_ping'), isFalse);
      expect(OutboundInfo.fromMap(emptyMap).latestPing, isNull);
    });

    test(
      'UrlTestProgressCounter does not count unverified historical latency',
      () {
        final counter = UrlTestProgressCounter();
        counter.reset(
          visibleTags: {'node-1', 'node-2'},
          testableTags: {'node-1', 'node-2'},
          resultForTag: (_) => null,
        );

        final state = counter.state(isRunning: false);
        expect(state.total, 2);
        expect(state.working, 0);

        counter.applyCoreSessionSnapshot(total: 2, completed: 1);
        counter.update(['node-1'], (tag) => tag == 'node-1' ? true : null);
        final updatedState = counter.state(isRunning: true);
        expect(updatedState.completed, 1);
        expect(updatedState.working, 1);
      },
    );

    testWidgets(
      'ProxyTile renders historical latency in muted color instead of no-data',
      (tester) async {
        const historicalProxy = AppProxySummary(
          tag: 'server-de',
          displayName: 'Frankfurt 01',
          countryCode: 'DE',
          type: 'vless',
          server: '1.2.3.4',
          port: 443,
          detailText: 'VLESS · 1.2.3.4:443',
          ip: '1.2.3.4',
          latency: 142,
          latencyFresh: false,
          latencyChecking: false,
          latencyUnavailable: false,
          latencyError: null,
          protocolLabel: 'VLESS',
          endpointLabel: '1.2.3.4:443',
        );

        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
            home: Scaffold(
              body: ProxyTile(
                proxy: historicalProxy,
                selected: false,
                animate: false,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('142 ms'), findsOneWidget);
        expect(find.text('Нет данных'), findsNothing);
        expect(find.text('No data'), findsNothing);

        final textWidget = tester.widget<Text>(find.text('142 ms'));
        final context = tester.element(find.byType(ProxyTile));
        final theme = Theme.of(context);
        expect(textWidget.style?.color, theme.colorScheme.onSurfaceVariant);
        expect(textWidget.style?.fontWeight, isNot(FontWeight.bold));
      },
    );

    testWidgets('ProxyTile renders no-data when latency is truly null', (
      tester,
    ) async {
      const blankProxy = AppProxySummary(
        tag: 'server-fr',
        displayName: 'Paris 01',
        countryCode: 'FR',
        type: 'vless',
        server: '2.3.4.5',
        port: 443,
        detailText: 'VLESS · 2.3.4.5:443',
        ip: '',
        latency: null,
        latencyFresh: false,
        latencyChecking: false,
        latencyUnavailable: false,
        latencyError: null,
        protocolLabel: 'VLESS',
        endpointLabel: '2.3.4.5:443',
      );

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ProxyTile(
              proxy: blankProxy,
              selected: false,
              animate: false,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProxyTile));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.proxyLatencyNoResult), findsOneWidget);
    });

    testWidgets(
      'ProxyTile renders fresh latency with vivid color and bold emphasis',
      (tester) async {
        const freshProxy = AppProxySummary(
          tag: 'server-nl',
          displayName: 'Amsterdam 01',
          countryCode: 'NL',
          type: 'vless',
          server: '3.4.5.6',
          port: 443,
          detailText: 'VLESS · 3.4.5.6:443',
          ip: '3.4.5.6',
          latency: 68,
          latencyFresh: true,
          latencyChecking: false,
          latencyUnavailable: false,
          latencyError: null,
          protocolLabel: 'VLESS',
          endpointLabel: '3.4.5.6:443',
        );

        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
            home: Scaffold(
              body: ProxyTile(
                proxy: freshProxy,
                selected: false,
                animate: false,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('68 ms'), findsOneWidget);
        final textWidget = tester.widget<Text>(find.text('68 ms'));
        expect(textWidget.style?.color, Colors.green);
        expect(textWidget.style?.fontWeight, FontWeight.bold);
      },
    );
  });
}
