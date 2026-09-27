import 'package:flutter/material.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:meow_client/app/dynamic_color_scheme_adapter.dart';

void main() {
  test('preserves dynamic palette roles when passing them to Flutter', () {
    final source =
        material_ui.ColorScheme.fromSeed(
          seedColor: const flutter.Color(0xFF345678),
          brightness: flutter.Brightness.dark,
        ).copyWith(
          primary: const flutter.Color(0xFF123456),
          secondaryContainer: const flutter.Color(0xFF234567),
          surfaceContainerHighest: const flutter.Color(0xFF345678),
          outlineVariant: const flutter.Color(0xFF456789),
        );

    final result = toFlutterColorScheme(source);

    expect(result.brightness, flutter.Brightness.dark);
    expect(result.primary, const flutter.Color(0xFF123456));
    expect(result.secondaryContainer, const flutter.Color(0xFF234567));
    expect(result.surfaceContainerHighest, const flutter.Color(0xFF345678));
    expect(result.outlineVariant, const flutter.Color(0xFF456789));
  });
}
