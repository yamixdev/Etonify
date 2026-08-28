import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/theme/demo_app_theme.dart';

class ConnectionButton extends StatefulWidget {
  const ConnectionButton({
    super.key,
    required this.connected,
    required this.connecting,
    required this.resolvingProxy,
    required this.statusLabel,
    required this.onTap,
  });

  final bool connected;
  final bool connecting;
  final bool resolvingProxy;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  State<ConnectionButton> createState() => _ConnectionButtonState();
}

class _ConnectionButtonState extends State<ConnectionButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final buttonTheme =
        theme.extension<ConnectionButtonTheme>() ?? ConnectionButtonTheme.light;
    final buttonColor = widget.connected
        ? buttonTheme.connectedColor!
        : buttonTheme.idleColor!;
    final busyLabel = widget.statusLabel.trim().isNotEmpty
        ? widget.statusLabel
        : l10n.tapToConnect;
    final label = widget.connected
        ? l10n.connected
        : (widget.connecting || widget.resolvingProxy)
        ? busyLabel
        : l10n.tapToConnect;

    return Column(
      children: [
        Semantics(
          button: true,
          label: label,
          child: TweenAnimationBuilder<_ConnectionButtonShape>(
            tween: _ConnectionButtonShapeTween(
              end: _ConnectionButtonShape.forState(
                connected: widget.connected,
                connecting: widget.connecting,
                resolvingProxy: widget.resolvingProxy,
              ),
            ),
            duration: const Duration(milliseconds: 680),
            curve: Curves.easeInOutCubicEmphasized,
            child: SizedBox(
              width: _kConnectionButtonSize,
              height: _kConnectionButtonSize,
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: widget.connecting ? null : widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(34),
                    child: SvgPicture.asset(
                      'assets/images/logo.svg',
                      key: const ValueKey('connection-button-logo'),
                      colorFilter: ColorFilter.mode(
                        buttonColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            builder: (context, shape, child) {
              final scale = 1 + (shape.emphasis * 0.06);
              final glow = 16 + (shape.emphasis * 12);
              final path = _connectionButtonCookiePath(
                const Size.square(_kConnectionButtonSize),
                shape,
              );
              return Transform.scale(
                scale: scale,
                child: CustomPaint(
                  painter: _ConnectionButtonShadowPainter(
                    path: path,
                    color: buttonColor.withValues(alpha: .45),
                    blur: glow,
                    spread: shape.emphasis * 2,
                  ),
                  child: ClipPath(
                    clipper: _ConnectionButtonShapeClipper(path),
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
        const Gap(16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.18),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Row(
            key: ValueKey(
              '${label}_${widget.connecting}_${widget.resolvingProxy}',
            ),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.connecting || widget.resolvingProxy) ...[
                Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const Gap(8),
              ],
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: widget.connected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

@immutable
class _ConnectionButtonShape {
  const _ConnectionButtonShape({
    required this.phase,
    required this.rotation,
    required this.emphasis,
  });

  factory _ConnectionButtonShape.forState({
    required bool connected,
    required bool connecting,
    required bool resolvingProxy,
  }) {
    if (resolvingProxy) {
      return const _ConnectionButtonShape(phase: 3, rotation: 0, emphasis: .96);
    }
    if (connected) {
      return const _ConnectionButtonShape(
        phase: 2,
        rotation: 0,
        emphasis: 1.16,
      );
    }
    if (connecting) {
      return const _ConnectionButtonShape(phase: 1, rotation: 0, emphasis: .52);
    }
    return const _ConnectionButtonShape(phase: 0, rotation: 0, emphasis: 0);
  }

  final double phase;
  final double rotation;
  final double emphasis;

  _ConnectionButtonShape copyWith({
    double? phase,
    double? rotation,
    double? emphasis,
  }) {
    return _ConnectionButtonShape(
      phase: phase ?? this.phase,
      rotation: rotation ?? this.rotation,
      emphasis: emphasis ?? this.emphasis,
    );
  }

  static _ConnectionButtonShape lerp(
    _ConnectionButtonShape a,
    _ConnectionButtonShape b,
    double t,
  ) {
    return _ConnectionButtonShape(
      phase: _lerp(a.phase, b.phase, t),
      rotation: _lerpAngle(a.rotation, b.rotation, t),
      emphasis: _lerp(a.emphasis, b.emphasis, t),
    );
  }
}

class _ConnectionButtonShapeTween extends Tween<_ConnectionButtonShape> {
  _ConnectionButtonShapeTween({required _ConnectionButtonShape end})
    : super(end: end);

  @override
  _ConnectionButtonShape lerp(double t) {
    return _ConnectionButtonShape.lerp(begin ?? end!, end!, t);
  }
}

class _ConnectionButtonShapeClipper extends CustomClipper<Path> {
  const _ConnectionButtonShapeClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_ConnectionButtonShapeClipper oldClipper) {
    return !identical(oldClipper.path, path);
  }
}

class _ConnectionButtonShadowPainter extends CustomPainter {
  const _ConnectionButtonShadowPainter({
    required this.path,
    required this.color,
    required this.blur,
    required this.spread,
  });

  final Path path;
  final Color color;
  final double blur;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2;
    final shadowScale = radius <= 0 ? 1.0 : (radius + spread) / radius;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(shadowScale);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawShadow(path, color, blur, true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ConnectionButtonShadowPainter oldDelegate) {
    return !identical(oldDelegate.path, path) ||
        oldDelegate.color != color ||
        oldDelegate.blur != blur ||
        oldDelegate.spread != spread;
  }
}

Path _connectionButtonCookiePath(Size size, _ConnectionButtonShape shape) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = math.min(size.width, size.height) / 2;
  const samples = _kConnectionButtonPathSamples;
  final points = <Offset>[];
  final phase = shape.phase.clamp(0.0, 3.0);
  final (from, to, t) = switch (phase) {
    <= 1 => (_kConnectionCircle, _kConnectionConnectingCookie, phase),
    <= 2 => (
      _kConnectionConnectingCookie,
      _kConnectionConnectedCookie,
      phase - 1,
    ),
    _ => (_kConnectionConnectedCookie, _kConnectionResolvingCookie, phase - 2),
  };

  for (var index = 0; index < samples; index += 1) {
    final theta = (index / samples * math.pi * 2) + shape.rotation;
    final radiusFactor = _lerp(from[index], to[index], t);
    points.add(
      center + Offset(math.cos(theta), math.sin(theta)) * radius * radiusFactor,
    );
  }

  final path = Path();
  for (var index = 0; index < points.length; index += 1) {
    final current = points[index];
    final next = points[(index + 1) % points.length];
    final midpoint = Offset(
      (current.dx + next.dx) / 2,
      (current.dy + next.dy) / 2,
    );
    if (index == 0) {
      path.moveTo(midpoint.dx, midpoint.dy);
    } else {
      path.quadraticBezierTo(current.dx, current.dy, midpoint.dx, midpoint.dy);
    }
  }
  final first = points.first;
  final second = points[1];
  final firstMidpoint = Offset(
    (first.dx + second.dx) / 2,
    (first.dy + second.dy) / 2,
  );
  path.quadraticBezierTo(
    first.dx,
    first.dy,
    firstMidpoint.dx,
    firstMidpoint.dy,
  );
  path.close();
  return path;
}

const _kConnectionButtonPathSamples = 96;
const _kConnectionButtonSize = 148.0;

final List<double> _kConnectionCircle = List<double>.filled(
  _kConnectionButtonPathSamples,
  1,
);

final List<double> _kConnectionConnectingCookie = List<double>.generate(
  _kConnectionButtonPathSamples,
  (index) => _cookieRadius(
    index: index,
    samples: _kConnectionButtonPathSamples,
    sides: 5,
    depth: .12,
    sharpness: 1.35,
    rotation: -math.pi / 2,
  ),
  growable: false,
);

final List<double> _kConnectionConnectedCookie = List<double>.generate(
  _kConnectionButtonPathSamples,
  (index) => _cookieRadius(
    index: index,
    samples: _kConnectionButtonPathSamples,
    sides: 8,
    depth: .1,
    sharpness: 1.08,
    rotation: -math.pi / 2,
  ),
  growable: false,
);

final List<double> _kConnectionResolvingCookie = List<double>.generate(
  _kConnectionButtonPathSamples,
  (index) => _cookieRadius(
    index: index,
    samples: _kConnectionButtonPathSamples,
    sides: 6,
    depth: .12,
    sharpness: 1.08,
    rotation: -math.pi / 2,
  ),
  growable: false,
);

double _cookieRadius({
  required int index,
  required int samples,
  required int sides,
  required double depth,
  required double sharpness,
  required double rotation,
}) {
  final theta = index / samples * math.pi * 2;
  final lobe = (1 + math.cos(sides * (theta - rotation))) / 2;
  final valley = math.pow(1 - lobe, sharpness).toDouble();
  return 1 - depth * valley;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _lerpAngle(double a, double b, double t) {
  final difference = math.atan2(math.sin(b - a), math.cos(b - a));
  return a + difference * t;
}
