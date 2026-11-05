import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/url_test_progress.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

void main() {
  testWidgets('collapsed panel keeps active proxy above its bottom inset', (
    tester,
  ) async {
    const proxy = AppProxySummary(
      tag: 'active',
      displayName: 'Active',
      countryCode: 'DE',
      type: 'vless',
      server: 'example.org',
      port: 443,
      detailText: '',
      ip: '203.0.113.1',
      latency: null,
      latencyFresh: false,
      latencyChecking: false,
      latencyUnavailable: false,
      latencyError: null,
      protocolLabel: 'VLESS',
      endpointLabel: 'example.org:443',
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 108,
            child: ProxiesPage(
              proxies: const [],
              activeProxy: proxy,
              selectedTag: 'active',
              connected: true,
              progressiveBlurEnabled: false,
              embedded: true,
              sheetAtMaxExtent: false,
              sheetExtent: 0,
              collapsedSheetExtent: 0,
              expandedHeaderExtent: 1,
              onSelected: (_) {},
              onUrlTest: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(CountryFlagBadge)).bottom,
      lessThanOrEqualTo(100),
    );
    expect(
      tester.getRect(find.text('203.0.113.1')).bottom,
      lessThanOrEqualTo(100),
    );
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'sheet header separates title and actions at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final progress = ValueNotifier(
            const UrlTestProgressState(
              total: 1200,
              working: 900,
              failed: 10,
              isRunning: true,
              showCheckProgress: true,
            ),
          );
          addTearDown(progress.dispose);
          var back = 0, add = 0, exclusions = 0, check = 0;
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: ProxiesPage(
                  proxies: const [],
                  selectedTag: '',
                  connected: true,
                  progressiveBlurEnabled: false,
                  embedded: true,
                  sheetAtMaxExtent: true,
                  sheetExtent: 1,
                  collapsedSheetExtent: 0,
                  expandedHeaderExtent: 1,
                  serverCount: 1200,
                  urlTestProgressListenable: progress,
                  onSelected: (_) {},
                  onUrlTest: () async {
                    check++;
                  },
                  onHeaderTap: () {
                    back++;
                  },
                  onAddProxy: () {
                    add++;
                  },
                  onEditExclusions: () {
                    exclusions++;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final header = find.byKey(const ValueKey('proxy-sheet-header'));
          final l = AppLocalizations.of(tester.element(header));
          final actions = [
            find.byTooltip(l.proxyExclusionsTitle),
            find.byTooltip(l.add),
            find.byTooltip(l.urlTestTitle),
            find.byTooltip(l.sort),
          ];
          final titleRect = tester.getRect(find.text(l.proxiesTitle));
          final headerRect = tester.getRect(header);
          final backButton = find.byTooltip('Назад');
          final backRect = tester.getRect(backButton);
          expect(backRect.width, greaterThanOrEqualTo(48));
          expect(backRect.height, greaterThanOrEqualTo(48));
          expect(backRect.overlaps(titleRect), isFalse);
          final progressRect = tester.getRect(
            find.byKey(const ValueKey('proxy-test-progress-bar')),
          );
          expect(progressRect.top, greaterThanOrEqualTo(titleRect.bottom));
          for (var i = 0; i < actions.length; i++) {
            final rect = tester.getRect(actions[i]);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.top, greaterThanOrEqualTo(titleRect.bottom));
            expect(rect.top, greaterThanOrEqualTo(progressRect.bottom));
            expect(headerRect.contains(rect.topLeft), isTrue);
            expect(rect.bottom, lessThanOrEqualTo(headerRect.bottom - 10));
            for (var j = 0; j < i; j++) {
              expect(rect.overlaps(tester.getRect(actions[j])), isFalse);
            }
          }
          await tester.tap(actions[0]);
          await tester.tap(actions[1]);
          await tester.tap(actions[2]);
          await tester.tap(backButton);
          expect([exclusions, add, check, back], [1, 1, 1, 1]);
          await tester.tap(actions[3]);
          await tester.pumpAndSettle();
          expect(find.byType(RadioGroup<ProxySort>), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
