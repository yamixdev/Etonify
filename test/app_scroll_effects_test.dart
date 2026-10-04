import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/widgets/app_scroll_effects.dart';
import 'package:meow_client/widgets/app_visual_effects.dart';

Widget _scrollApp(
  ScrollController controller, {
  TargetPlatform platform = TargetPlatform.android,
  bool hapticEnabled = true,
}) => MaterialApp(
  theme: ThemeData(platform: platform),
  home: AppVisualEffects(
    progressiveBlurEnabled: false,
    hapticEnabled: hapticEnabled,
    child: AppScrollEffects(
      child: ListView.builder(
        controller: controller,
        itemCount: 40,
        itemExtent: 60,
        itemBuilder: (_, index) => Text('Row $index'),
      ),
    ),
  ),
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('scroll stays clamped at the leading edge on $platform', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_scrollApp(controller, platform: platform));
      final gesture = await tester.startGesture(const Offset(300, 200));
      await gesture.moveBy(const Offset(0, 180));
      await tester.pump();
      expect(controller.offset, 0);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('iOS keeps native bouncing scroll behavior', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _scrollApp(controller, platform: TargetPlatform.iOS),
    );
    final gesture = await tester.startGesture(const Offset(300, 200));
    await gesture.moveBy(const Offset(0, 180));
    await tester.pump();
    expect(controller.offset, lessThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  for (final enabled in [true, false]) {
    testWidgets('user scroll respects hapticEnabled=$enabled', (tester) async {
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_scrollApp(controller, hapticEnabled: enabled));
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(haptics, enabled ? isNotEmpty : isEmpty);
    });
  }
}
