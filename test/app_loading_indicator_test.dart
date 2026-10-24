import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/widgets/app_loading_indicator.dart';
import 'dart:ui' as ui;

Widget _app(Widget child, {bool reduced = false, bool ticking = true}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: TickerMode(
          enabled: ticking,
          child: Center(child: child),
        ),
      ),
    );

void main() {
  testWidgets('motion preferences can change while loading', (tester) async {
    await tester.pumpWidget(_app(const AppLoadingIndicator()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(_app(const AppLoadingIndicator(), reduced: true));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_app(const AppLoadingIndicator(), ticking: false));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_app(const AppLoadingIndicator()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('one progress instance transitions from unknown to complete', (
    tester,
  ) async {
    for (final value in <double?>[null, 0, .4, 1]) {
      await tester.pumpWidget(
        _app(
          SizedBox(width: 240, child: AppLinearProgressIndicator(value: value)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.binding.transientCallbackCount,
        value == null || value == .4 ? greaterThan(0) : 0,
      );
      expect(tester.takeException(), isNull);
    }
  });

  for (final direction in TextDirection.values) {
    testWidgets('painted progress follows the real fraction in $direction', (
      tester,
    ) async {
      const key = ValueKey('painted-fraction');
      for (final value in [.25, .7, 1.0]) {
        await tester.pumpWidget(
          _app(
            Directionality(
              textDirection: direction,
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 240,
                  child: AppLinearProgressIndicator(
                    value: value,
                    color: Colors.red,
                    backgroundColor: Colors.black,
                  ),
                ),
              ),
            ),
            reduced: true,
          ),
        );
        await tester.pumpAndSettle();
        final centerX = await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          final image = await boundary.toImage();
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            var sum = 0;
            var count = 0;
            for (var i = 0; i < bytes.lengthInBytes; i += 4) {
              if (bytes.getUint8(i) > 200 &&
                  bytes.getUint8(i + 1) < 100 &&
                  bytes.getUint8(i + 2) < 100) {
                sum += (i ~/ 4) % image.width;
                count++;
              }
            }
            expect(count, greaterThan(0));
            return sum / count;
          } finally {
            image.dispose();
          }
        });
        expect(
          centerX,
          closeTo(
            direction == TextDirection.ltr ? value * 120 : 239 - value * 120,
            3,
          ),
        );
      }
    });
  }

  testWidgets('ambient animation repaints without rebuilding its parent', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (_) {
            builds++;
            return const AppLoadingIndicator();
          },
        ),
      ),
    );
    final initialBuilds = builds;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(builds, initialBuilds);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('morphing loader keeps a fixed accessible footprint', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const AppLoadingIndicator(
          size: 40,
          semanticsLabel: 'Loading subscription',
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(AppLoadingIndicator)),
      const Size(40, 40),
    );
    expect(find.bySemanticsLabel('Loading subscription'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      tester.getSize(find.byType(AppLoadingIndicator)),
      const Size(40, 40),
    );
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    semantics.dispose();
  });

  for (final reduced in [false, true]) {
    testWidgets('hidden loaders schedule no frames (reduced=$reduced)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLoadingIndicator(),
              SizedBox(width: 240, child: AppLinearProgressIndicator()),
            ],
          ),
          reduced: reduced,
          ticking: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion shows static feedback instead of looping', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AppLoadingIndicator(), reduced: true));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('backgrounding pauses and resuming restarts visible loading', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AppLoadingIndicator.compact()));
    await tester.pump(const Duration(milliseconds: 100));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('determinate progress announces the real fraction immediately', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 240,
          child: AppLinearProgressIndicator(
            value: .25,
            semanticsLabel: 'Download',
          ),
        ),
        reduced: true,
      ),
    );
    expect(
      tester.getSemantics(find.byType(AppLinearProgressIndicator)).value,
      '25%',
    );
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 240,
          child: AppLinearProgressIndicator(
            value: .7,
            semanticsLabel: 'Download',
          ),
        ),
        reduced: true,
      ),
    );
    expect(
      tester.getSemantics(find.byType(AppLinearProgressIndicator)).value,
      '70%',
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    semantics.dispose();
  });

  testWidgets('completed progress does not keep an ambient ticker alive', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(width: 240, child: AppLinearProgressIndicator(value: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'reduced indeterminate progress retains a visible active segment',
    (tester) async {
      const key = ValueKey('static-progress');
      await tester.pumpWidget(
        _app(
          const RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 240,
              child: AppLinearProgressIndicator(
                color: Colors.red,
                backgroundColor: Colors.black,
              ),
            ),
          ),
          reduced: true,
        ),
      );
      await tester.pumpAndSettle();
      final redPixels = await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final image = await boundary.toImage();
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var red = 0;
          for (var i = 0; i < bytes.lengthInBytes; i += 4) {
            if (bytes.getUint8(i) > 200 &&
                bytes.getUint8(i + 1) < 100 &&
                bytes.getUint8(i + 2) < 100) {
              red++;
            }
          }
          return red;
        } finally {
          image.dispose();
        }
      });
      expect(redPixels, greaterThan(10));
    },
  );

  testWidgets('state transition preserves only the current interactive child', (
    tester,
  ) async {
    var oldTaps = 0;
    var newTaps = 0;
    Widget view(bool busy) => _app(
      AppAnimatedSwitcher(
        child: TextButton(
          key: ValueKey(busy),
          onPressed: busy ? () => oldTaps++ : () => newTaps++,
          child: Text(busy ? 'Loading' : 'Done'),
        ),
      ),
    );
    await tester.pumpWidget(view(true));
    await tester.pumpWidget(view(false));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('Done'));
    expect(oldTaps, 0);
    expect(newTaps, 1);
    await tester.pumpAndSettle();
    expect(find.text('Loading'), findsNothing);
  });
}
