import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/core/outbound_location.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

void main() {
  group('outbound location', () {
    test(
      'shows the observed exit country instead of the subscription name',
      () {
        final outbound = _outbound(
          sourceCountry: 'CZ',
          exitCountry: 'US',
          externalIp: '203.0.113.7',
        );

        expect(
          outboundDisplayCountryCode(outbound, markAllServersRussia: false),
          'US',
        );
      },
    );

    test('keeps the source country until an exit country is observed', () {
      final outbound = _outbound(sourceCountry: 'CZ');

      expect(
        outboundDisplayCountryCode(outbound, markAllServersRussia: false),
        'CZ',
      );
    });

    test('does not treat legacy source country cache as verified exit', () {
      final outbound = _outbound(
        sourceCountry: 'CZ',
        externalIp: '203.0.113.7',
      );

      expect(
        hasResolvedOutboundExitLocation(outbound, markAllServersRussia: false),
        isFalse,
      );
    });

    test('recognizes a complete observed exit location', () {
      final outbound = _outbound(
        sourceCountry: 'CZ',
        exitCountry: 'US',
        externalIp: '203.0.113.7',
      );

      expect(
        hasResolvedOutboundExitLocation(outbound, markAllServersRussia: false),
        isTrue,
      );
    });

    testWidgets('proxy tile renders the observed exit flag', (tester) async {
      final outbound = _outbound(
        sourceCountry: 'CZ',
        exitCountry: 'US',
        externalIp: '203.0.113.7',
      );
      final cache = buildProxyCache(
        ProxyCacheBuildInput(
          subscription: Subscription(
            id: 'location-test',
            name: 'Location test',
            url: 'file:///location-test',
            outbounds: [outbound],
          ),
          selectedProxyTag: outbound.tag,
          lowestLatency: null,
          runtimeLowestOutboundTag: null,
          runtimeLowestSelections: const <String, String>{},
          urlTestInFlight: false,
          runtimeLatencies: const <String, int>{},
          unavailableLatencyTags: const <String>{},
          latencyErrors: const <String, String>{},
          runtimeGroupSelections: const <String, String>{},
          markAllServersRussia: false,
        ),
      );
      final proxy = cache.activeProxies.firstWhere(
        (entry) => entry.tag == outbound.tag,
      );

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ProxyTile(
              proxy: proxy,
              selected: true,
              animate: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is CountryFlagBadge && widget.countryCode == 'US',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is CountryFlagBadge && widget.countryCode == 'CZ',
        ),
        findsNothing,
      );
    });
  });
}

Outbound _outbound({
  String? sourceCountry,
  String? exitCountry,
  String? externalIp,
}) {
  return Outbound(
    tag: 'named-czechia',
    name: '🇨🇿 Czechia',
    config: const {
      'type': 'vless',
      'server': 'proxy.example.com',
      'server_port': 443,
    },
    info: OutboundInfo(
      country: sourceCountry,
      exitCountry: exitCountry,
      externalIp: externalIp,
    ),
  );
}
