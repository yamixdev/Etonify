import 'dart:math' as math;

import 'package:flutter/material.dart';

class IpRefreshDots extends StatefulWidget {
  const IpRefreshDots({
    super.key,
    this.color,
    this.dotSize = 4.2,
    this.spacing = 4,
    this.lift = 4.5,
  });

  final Color? color;
  final double dotSize;
  final double spacing;
  final double lift;

  @override
  State<IpRefreshDots> createState() => _IpRefreshDotsState();
}

class _IpRefreshDotsState extends State<IpRefreshDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ??
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: widget.dotSize * 3 + widget.spacing * 2,
      height: widget.dotSize + widget.lift + 8,
      child: CustomPaint(
        key: const ValueKey('ip-refresh-dots'),
        painter: _IpRefreshDotsPainter(
          animation: _controller,
          color: color,
          dotSize: widget.dotSize,
          spacing: widget.spacing,
          lift: widget.lift,
        ),
      ),
    );
  }
}

class _IpRefreshDotsPainter extends CustomPainter {
  _IpRefreshDotsPainter({
    required Animation<double> animation,
    required this.color,
    required this.dotSize,
    required this.spacing,
    required this.lift,
  }) : _animation = animation,
       super(repaint: animation);

  final Animation<double> _animation;
  final Color color;
  final double dotSize;
  final double spacing;
  final double lift;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final radius = dotSize / 2;
    for (var index = 0; index < 3; index++) {
      final raw = (_animation.value * 3 - index) % 3;
      final local = raw < 0 ? raw + 3 : raw;
      final liftProgress = local <= 1
          ? math.sin(local * math.pi).clamp(0.0, 1.0)
          : 0.0;
      final eased = Curves.easeInOutCubic.transform(liftProgress);
      final opacity = .72 + .28 * eased;
      final center = Offset(
        radius + index * (dotSize + spacing),
        size.height / 2 - lift * eased,
      );
      canvas.drawCircle(
        center,
        radius,
        _paint..color = color.withValues(alpha: color.a * opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_IpRefreshDotsPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dotSize != dotSize ||
        oldDelegate.spacing != spacing ||
        oldDelegate.lift != lift;
  }
}
