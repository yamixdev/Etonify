import 'package:circle_flags/circle_flags.dart';
import 'package:flutter/material.dart';

class CountryFlagBadge extends StatelessWidget {
  static final RegExp _countryCodePattern = RegExp(r'^[A-Z]{2}$');

  const CountryFlagBadge({
    super.key,
    required this.countryCode,
    this.size = 40,
  });

  final String countryCode;
  final double size;

  static String? circleFlagCodeFor(String countryCode) {
    final normalizedCode = countryCode.trim().toUpperCase();
    if (!_countryCodePattern.hasMatch(normalizedCode)) {
      return null;
    }
    final normalizedLowerCode = normalizedCode.toLowerCase();
    return switch (normalizedLowerCode) {
      'eu' => 'european_union',
      'ir' || 'ir-shir' => 'ir-shir',
      'uk' => 'gb',
      _ => normalizedLowerCode,
    };
  }

  static Future<void> preload(Iterable<String> countryCodes) async {
    final codes = countryCodes
        .map(circleFlagCodeFor)
        .whereType<String>()
        .toSet();
    if (codes.isEmpty) {
      return;
    }
    await (CircleFlag.preload(codes) as Future<dynamic>);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final circleFlagCode = circleFlagCodeFor(countryCode);

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: circleFlagCode != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.hardEdge,
                  child: CircleFlag(circleFlagCode, size: size - 8, shape: null),
                )
              : Container(
                  width: size - 8,
                  height: size - 8,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.public_rounded,
                    size: size * 0.45,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }
}
