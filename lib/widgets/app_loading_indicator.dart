import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 40,
    this.color,
    this.contained = false,
    this.semanticsLabel,
  }) : compact = false,
       assert(size > 0 && size < double.infinity);

  const AppLoadingIndicator.compact({
    super.key,
    this.size = 18,
    this.color,
    this.semanticsLabel,
  }) : compact = true,
       contained = false,
       assert(size > 0 && size < double.infinity);

  final double size;
  final Color? color;
  final bool compact;
  final bool contained;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label:
          semanticsLabel ??
          Localizations.of<AppLocalizations>(
            context,
            AppLocalizations,
          )?.loading,
      child: SizedBox.square(
        dimension: size,
        child: RepaintBoundary(
          child: _ProgressMotion(
            builder: (animation) => CustomPaint(
              painter: _LoadingPainter(
                animation,
                color ??
                    (contained ? colors.onPrimaryContainer : colors.primary),
                compact: compact,
                background: contained ? colors.primaryContainer : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppLinearProgressIndicator extends StatelessWidget {
  const AppLinearProgressIndicator({
    super.key,
    this.value,
    this.minHeight = 6,
    this.color,
    this.backgroundColor,
    this.semanticsLabel,
    this.semanticsValue,
  }) : assert(value == null || (value >= 0 && value <= 1)),
       assert(minHeight > 0 && minHeight < double.infinity);

  final double? value;
  final double minHeight;
  final Color? color;
  final Color? backgroundColor;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      label:
          semanticsLabel ??
          Localizations.of<AppLocalizations>(
            context,
            AppLocalizations,
          )?.loading,
      value:
          semanticsValue ??
          (value == null ? null : '${(value! * 100).round()}%'),
      child: SizedBox(
        height: minHeight,
        width: double.infinity,
        child: RepaintBoundary(
          child: _ProgressMotion(
            active: value == null || (value! > 0 && value! < 1),
            builder: (animation) => CustomPaint(
              painter: _LinearProgressPainter(
                animation,
                value: value,
                color: color ?? colors.primary,
                trackColor: backgroundColor ?? colors.surfaceContainerHighest,
                rtl: rtl,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppAnimatedSwitcher extends StatelessWidget {
  const AppAnimatedSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      return child;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 120),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [
          for (final child in previous)
            IgnorePointer(
              child: ExcludeFocus(child: ExcludeSemantics(child: child)),
            ),
          ?current,
        ],
      ),
      child: child,
    );
  }
}

class _ProgressMotion extends StatefulWidget {
  const _ProgressMotion({required this.builder, this.active = true});

  final Widget Function(Animation<double>) builder;
  final bool active;

  @override
  State<_ProgressMotion> createState() => _ProgressMotionState();
}

class _ProgressMotionState extends State<_ProgressMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800),
    value: .125,
  );
  bool _foreground = true;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _synchronize();
  }

  @override
  void didUpdateWidget(_ProgressMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _synchronize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _synchronize();
  }

  void _synchronize() {
    if (_enabled && _foreground && widget.active) {
      if (!_animation.isAnimating) _animation.repeat();
    } else {
      _animation.stop();
      if (!_enabled) _animation.value = .125;
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_animation);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    super.dispose();
  }
}

const _shapeSamples = 48;
final _loadingShapes = List<List<Offset>>.generate(
  4,
  (shape) => List<Offset>.generate(_shapeSamples, (sample) {
    final angle = sample * math.pi * 2 / _shapeSamples;
    final radius = switch (shape) {
      0 => .38 + .055 * math.cos(3 * angle),
      1 => .38 + .055 * math.cos(5 * angle),
      2 =>
        .34 *
            math.pow(
              math.pow(math.cos(angle).abs(), 4) +
                  math.pow(math.sin(angle).abs(), 4),
              -.25,
            ),
      _ => .38 + .055 * math.cos(4 * angle),
    };
    return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }, growable: false),
  growable: false,
);

class _LoadingPainter extends CustomPainter {
  _LoadingPainter(
    this.animation,
    this.color, {
    required this.compact,
    this.background,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final Color? background;
  final bool compact;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = size.center(Offset.zero);
    if (background != null) {
      canvas.drawCircle(center, side / 2, _paint..color = background!);
    }
    _paint
      ..color = color
      ..style = PaintingStyle.fill;
    if (compact) {
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, side * .11)
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: side * .36),
        animation.value * math.pi * 8,
        math.pi * 1.35,
        false,
        _paint,
      );
      return;
    }
    final cycle = animation.value * _loadingShapes.length;
    final index = cycle.floor() % _loadingShapes.length;
    final morph = Curves.easeInOutCubicEmphasized.transform(cycle % 1);
    final from = _loadingShapes[index];
    final to = _loadingShapes[(index + 1) % _loadingShapes.length];
    final scale = background == null ? side : side * .7;
    final points = List<Offset>.generate(
      _shapeSamples,
      (i) => Offset.lerp(from[i], to[i], morph)! * scale,
    );
    final path = Path()
      ..moveTo(
        (points.last.dx + points.first.dx) / 2,
        (points.last.dy + points.first.dy) / 2,
      );
    for (var i = 0; i < points.length; i++) {
      final next = points[(i + 1) % points.length];
      path.quadraticBezierTo(
        points[i].dx,
        points[i].dy,
        (points[i].dx + next.dx) / 2,
        (points[i].dy + next.dy) / 2,
      );
    }
    path.close();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(animation.value * math.pi * 2);
    canvas.drawPath(path, _paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LoadingPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.color != color ||
      oldDelegate.compact != compact ||
      oldDelegate.background != background;
}

class _LinearProgressPainter extends CustomPainter {
  _LinearProgressPainter(
    this.animation, {
    required this.value,
    required this.color,
    required this.trackColor,
    required this.rtl,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final double? value;
  final Color color;
  final Color trackColor;
  final bool rtl;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final stroke = math.min(3.0, size.height);
    final inset = stroke / 2;
    final width = math.max(0.0, size.width - stroke);
    final middle = size.height / 2;
    _paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawLine(
      Offset(inset, middle),
      Offset(size.width - inset, middle),
      _paint,
    );
    final phase = (animation.value * 3) % 1;
    final start = value == null ? (phase * 1.4 - .4).clamp(0.0, 1.0) : 0.0;
    final end = value ?? (phase * 1.4).clamp(0.0, 1.0);
    final span = (end - start) * width;
    if (span > 0) {
      final amplitude =
          math.max(0.0, (size.height - stroke) / 2) * (value == 1 ? 0 : 1);
      final path = Path();
      final steps = math.max(1, (span / 2).ceil());
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final x = inset + start * width + span * t;
        final y =
            middle +
            math.sin((x / 20 - animation.value * 8) * math.pi * 2) *
                amplitude *
                math.sin(t * math.pi);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, _paint..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LinearProgressPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.rtl != rtl;
}
