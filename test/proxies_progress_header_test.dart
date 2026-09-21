import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/url_test_progress.dart';

Widget _buildHeaderTestApp({
  required ValueNotifier<UrlTestProgressState> progressNotifier,
  Locale locale = const Locale('ru'),
  double progress = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: ProxiesPage(
        proxies: const <AppProxySummary>[
          AppProxySummary(
            tag: 'node-1',
            displayName: 'Node 1',
            countryCode: 'US',
            type: 'vless',
            server: '1.2.3.4',
            port: 443,
            detailText: 'vless',
            ip: '',
            latency: null,
            latencyFresh: false,
            latencyChecking: false,
            latencyUnavailable: false,
            latencyError: null,
            protocolLabel: 'vless',
            endpointLabel: '1.2.3.4:443',
            highlighted: false,
          ),
        ],
        selectedTag: 'node-1',
        connected: true,
        progressiveBlurEnabled: false,
        embedded: true,
        sheetAtMaxExtent: true,
        collapsedSheetExtent: 0,
        expandedHeaderExtent: 1,
        sheetExtent: progress,
        urlTestProgressListenable: progressNotifier,
        onSelected: (_) {},
        onUrlTest: () async {},
      ),
    ),
  );
}

void main() {
  testWidgets('progress bar and counter display testing status during active run in Russian', (
    tester,
  ) async {
    final progressNotifier = ValueNotifier<UrlTestProgressState>(
      const UrlTestProgressState(
        isRunning: true,
        isCancelled: false,
        total: 10,
        working: 5,
        failed: 2,
      ),
    );
    addTearDown(progressNotifier.dispose);

    await tester.pumpWidget(
      _buildHeaderTestApp(progressNotifier: progressNotifier),
    );
    await tester.pumpAndSettle();

    expect(find.text('Прокси'), findsOneWidget);
    expect(find.text('Работают 5 / 10 · проверено 7 / 10'), findsOneWidget);

    // Verify progress bar colored boxes
    final barFinder = find.byKey(const ValueKey('proxy-test-progress-bar'));
    expect(barFinder, findsOneWidget);
    expect(
      find.descendant(of: barFinder, matching: find.byType(ColoredBox)),
      findsNWidgets(3),
    );
  });

  testWidgets('progress bar and counter display full test completion status in Russian', (
    tester,
  ) async {
    final progressNotifier = ValueNotifier<UrlTestProgressState>(
      const UrlTestProgressState(
        isRunning: false,
        isCancelled: false,
        total: 10,
        working: 8,
        failed: 2,
      ),
    );
    addTearDown(progressNotifier.dispose);

    await tester.pumpWidget(
      _buildHeaderTestApp(progressNotifier: progressNotifier),
    );
    await tester.pumpAndSettle();

    expect(find.text('Прокси'), findsOneWidget);
    expect(find.text('Работают 8 / 10'), findsOneWidget);
  });

  testWidgets('progress bar and counter display cancelled status with tested count', (
    tester,
  ) async {
    final progressNotifier = ValueNotifier<UrlTestProgressState>(
      const UrlTestProgressState(
        isRunning: false,
        isCancelled: true,
        total: 10,
        working: 4,
        failed: 1,
      ),
    );
    addTearDown(progressNotifier.dispose);

    await tester.pumpWidget(
      _buildHeaderTestApp(progressNotifier: progressNotifier),
    );
    await tester.pumpAndSettle();

    expect(find.text('Прокси'), findsOneWidget);
    expect(find.text('Работают 4 / 10 · проверено 5 / 10'), findsOneWidget);
  });

  testWidgets('progress bar and counter are hidden when idle without results', (
    tester,
  ) async {
    final progressNotifier = ValueNotifier<UrlTestProgressState>(
      const UrlTestProgressState(
        isRunning: false,
        isCancelled: false,
        total: 10,
        working: 0,
        failed: 0,
      ),
    );
    addTearDown(progressNotifier.dispose);

    await tester.pumpWidget(
      _buildHeaderTestApp(progressNotifier: progressNotifier),
    );
    await tester.pumpAndSettle();

    expect(find.text('Прокси'), findsOneWidget);
    expect(find.textContaining('Работают'), findsNothing);
  });
}
