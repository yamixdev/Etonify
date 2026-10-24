import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/widgets/app_loading_indicator.dart';
import 'package:meow_client/widgets/app_loading_previews.dart';

void main() {
  if (const bool.fromEnvironment('CAPTURE_LOADING_PREVIEWS')) {
    setUpAll(() async {
      final font = File(
        '${Platform.environment['SystemRoot'] ?? 'C:/Windows'}/Fonts/segoeui.ttf',
      );
      if (await font.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(font.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    });
  }
  for (final variant in ['dark', 'light', 'amoled', 'large-text', 'reduced']) {
    testWidgets('loading gallery renders $variant without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue =
          variant == 'large-text' ? 2 : 1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const key = ValueKey('gallery');
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: LoadingPreviewGallery(
            brightness: variant == 'light' ? Brightness.light : Brightness.dark,
            amoled: variant == 'amoled',
            reducedMotion: variant == 'reduced',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(AppLoadingIndicator), findsNWidgets(3));
      expect(find.byType(AppLinearProgressIndicator), findsWidgets);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_LOADING_PREVIEWS')) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          final image = await boundary.toImage();
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final output = File(
              '${Directory.systemTemp.path}/etonify-loading-$variant.png',
            );
            await output.writeAsBytes(bytes.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
      await tester.scrollUntilVisible(find.text('Готово'), 100);
      await tester.pump();
      expect(find.text('Готово').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
