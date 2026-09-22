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
  int proxyCount = 1,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: ProxiesPage(
        proxies: List.generate(
          proxyCount,
          (index) => AppProxySummary(
            tag: 'node-$index',
            displayName: 'Node $index',
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
        ),
        selectedTag: 'node-0',
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
  testWidgets(
    'progress bar and counter display testing status during active run in Russian',
    (tester) async {
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
    },
  );

  testWidgets(
    'progress bar and counter display full test completion status in Russian',
    (tester) async {
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
    },
  );

  testWidgets(
    'progress bar and counter display cancelled status with tested count',
    (tester) async {
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
    },
  );

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

  // The header is an overlay the list scrolls beneath, and the progressive
  // blur it used to lean on is a no-op, so its gradient is the only thing
  // separating "Прокси" from the row text.
  testWidgets('header backdrop stays opaque across the header', (tester) async {
    final progressNotifier = ValueNotifier<UrlTestProgressState>(
      const UrlTestProgressState(
        isRunning: true,
        total: 57,
        working: 38,
        failed: 3,
      ),
    );
    addTearDown(progressNotifier.dispose);

    await tester.pumpWidget(
      _buildHeaderTestApp(progressNotifier: progressNotifier),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('proxy-sheet-header'));
    final backdrops = tester
        .widgetList<DecoratedBox>(
          find.ancestor(of: header, matching: find.byType(DecoratedBox)),
        )
        .where(
          (widget) =>
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).gradient is LinearGradient,
        )
        .toList();
    expect(backdrops, hasLength(1));

    final gradient =
        (backdrops.single.decoration as BoxDecoration).gradient!
            as LinearGradient;
    expect(gradient.colors.first.a, 1.0);
    expect(gradient.colors[1].a, 1.0);

    // Only the bottom edge may dissolve; a wider translucent band reaches the
    // title and puts row text back on top of it.
    final translucentBand =
        (1 - gradient.stops![1]) * tester.getSize(header).height;
    expect(translucentBand, lessThanOrEqualTo(20));
  });

  testWidgets('collapsed header fits the wrapped progress line', (
    tester,
  ) async {
    final progressNotifier = ValueNotifier<UrlTestProgressState>(
      const UrlTestProgressState(
        isRunning: true,
        total: 57,
        working: 38,
        failed: 3,
      ),
    );
    addTearDown(progressNotifier.dispose);

    await tester.binding.setSurfaceSize(const Size(393, 873));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHeaderTestApp(progressNotifier: progressNotifier, proxyCount: 12),
    );
    await tester.pumpAndSettle();

    // Drag past the collapse distance so the compact header is the one under
    // test; it is the tighter of the two.
    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('proxy-sheet-header'))).height,
      closeTo(80, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress line wraps instead of ellipsizing on one line', (
    tester,
  ) async {
    final progressNotifier = ValueNotifier<UrlTestProgressState>(
      const UrlTestProgressState(
        isRunning: true,
        total: 57,
        working: 38,
        failed: 3,
      ),
    );
    addTearDown(progressNotifier.dispose);

    await tester.binding.setSurfaceSize(const Size(320, 873));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHeaderTestApp(progressNotifier: progressNotifier),
    );
    await tester.pumpAndSettle();

    final status = find.text('Работают 38 / 57 · проверено 41 / 57');
    expect(status, findsOneWidget);
    // Two lines of labelSmall. A single line here would mean the trailing
    // "проверено" half was clipped, which is the reported bug.
    expect(tester.getSize(status).height, greaterThan(24));
    expect(tester.takeException(), isNull);
  });
}
