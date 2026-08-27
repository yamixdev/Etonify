import 'package:flutter/material.dart';

const appBottomSheetCornerRadius = 28.0;
const appBottomSheetDragThreshold = 96.0;
const appBottomSheetAnimationDuration = Duration(milliseconds: 260);

class AppBottomSheetDragHandle extends StatelessWidget {
  const AppBottomSheetDragHandle({super.key, this.opacity = .34});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: opacity);
    return Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
