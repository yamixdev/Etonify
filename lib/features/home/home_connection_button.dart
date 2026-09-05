import 'dart:math' as math;
import 'dart:typed_data';

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
          child: TweenAnimationBuilder<ConnectionButtonShape>(
            tween: _ConnectionButtonShapeTween(
              end: ConnectionButtonShape.forState(
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
              return RepaintBoundary(
                child: Transform.scale(
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
class ConnectionButtonShape {
  const ConnectionButtonShape({
    required this.phase,
    required this.rotation,
    required this.emphasis,
  });

  factory ConnectionButtonShape.forState({
    required bool connected,
    required bool connecting,
    required bool resolvingProxy,
  }) {
    if (resolvingProxy) {
      return const ConnectionButtonShape(phase: 3, rotation: 0, emphasis: .96);
    }
    if (connected) {
      return const ConnectionButtonShape(
        phase: 2,
        rotation: 0,
        emphasis: 1.16,
      );
    }
    if (connecting) {
      return const ConnectionButtonShape(phase: 1, rotation: 0, emphasis: .52);
    }
    return const ConnectionButtonShape(phase: 0, rotation: 0, emphasis: 0);
  }

  final double phase;
  final double rotation;
  final double emphasis;

  ConnectionButtonShape copyWith({
    double? phase,
    double? rotation,
    double? emphasis,
  }) {
    return ConnectionButtonShape(
      phase: phase ?? this.phase,
      rotation: rotation ?? this.rotation,
      emphasis: emphasis ?? this.emphasis,
    );
  }

  static ConnectionButtonShape lerp(
    ConnectionButtonShape a,
    ConnectionButtonShape b,
    double t,
  ) {
    return ConnectionButtonShape(
      phase: _lerp(a.phase, b.phase, t),
      rotation: _lerpAngle(a.rotation, b.rotation, t),
      emphasis: _lerp(a.emphasis, b.emphasis, t),
    );
  }
}

class _ConnectionButtonShapeTween extends Tween<ConnectionButtonShape> {
  _ConnectionButtonShapeTween({required ConnectionButtonShape end})
    : super(end: end);

  @override
  ConnectionButtonShape lerp(double t) {
    return ConnectionButtonShape.lerp(begin ?? end!, end!, t);
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

Path _connectionButtonCookiePath(Size size, ConnectionButtonShape shape) {
  // Fast path: if the button is at canonical size and resting (no rotation),
  // return pre-generated cached Path instance immediately without computation or allocation.
  if (size.width == _kConnectionButtonSize &&
      size.height == _kConnectionButtonSize &&
      shape.rotation == 0.0) {
    if (shape.phase == 0.0) return _kIdleConnectionButtonPath;
    if (shape.phase == 1.0) return _kConnectingConnectionButtonPath;
    if (shape.phase == 2.0) return _kConnectedConnectionButtonPath;
    if (shape.phase == 3.0) return _kResolvingConnectionButtonPath;
  }

  return _buildConnectionButtonCookiePath(size, shape);
}

@visibleForTesting
Path connectionButtonCookiePathForTesting(
  Size size,
  ConnectionButtonShape shape,
) => _connectionButtonCookiePath(size, shape);

Path _buildConnectionButtonCookiePath(Size size, ConnectionButtonShape shape) {
  final centerX = size.width / 2;
  final centerY = size.height / 2;
  final radius = math.min(size.width, size.height) / 2;
  const samples = _kConnectionButtonPathSamples;
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

  final hasRotation = shape.rotation != 0.0;
  final rotCos = hasRotation ? math.cos(shape.rotation) : 1.0;
  final rotSin = hasRotation ? math.sin(shape.rotation) : 0.0;

  for (var index = 0; index < samples; index += 1) {
    final cosTheta = hasRotation
        ? (_kBaseCos[index] * rotCos - _kBaseSin[index] * rotSin)
        : _kBaseCos[index];
    final sinTheta = hasRotation
        ? (_kBaseSin[index] * rotCos + _kBaseCos[index] * rotSin)
        : _kBaseSin[index];
    final r = radius * _lerp(from[index], to[index], t);
    _reusablePointsX[index] = centerX + cosTheta * r;
    _reusablePointsY[index] = centerY + sinTheta * r;
  }

  final path = Path();
  final firstMidX = (_reusablePointsX[0] + _reusablePointsX[1]) / 2;
  final firstMidY = (_reusablePointsY[0] + _reusablePointsY[1]) / 2;
  path.moveTo(firstMidX, firstMidY);

  for (var index = 1; index < samples; index += 1) {
    final nextIndex = (index + 1) % samples;
    final midX = (_reusablePointsX[index] + _reusablePointsX[nextIndex]) / 2;
    final midY = (_reusablePointsY[index] + _reusablePointsY[nextIndex]) / 2;
    path.quadraticBezierTo(
      _reusablePointsX[index],
      _reusablePointsY[index],
      midX,
      midY,
    );
  }

  path.quadraticBezierTo(
    _reusablePointsX[0],
    _reusablePointsY[0],
    firstMidX,
    firstMidY,
  );
  path.close();
  return path;
}

const _kConnectionButtonPathSamples = 96;
const _kConnectionButtonSize = 148.0;

final Float64List _reusablePointsX = Float64List(_kConnectionButtonPathSamples);
final Float64List _reusablePointsY = Float64List(_kConnectionButtonPathSamples);

final List<double> _kBaseCos = List<double>.generate(
  _kConnectionButtonPathSamples,
  (index) => math.cos(index / _kConnectionButtonPathSamples * math.pi * 2),
  growable: false,
);

final List<double> _kBaseSin = List<double>.generate(
  _kConnectionButtonPathSamples,
  (index) => math.sin(index / _kConnectionButtonPathSamples * math.pi * 2),
  growable: false,
);

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

final Path _kIdleConnectionButtonPath = _buildConnectionButtonCookiePath(
  const Size.square(_kConnectionButtonSize),
  const ConnectionButtonShape(phase: 0, rotation: 0, emphasis: 0),
);

final Path _kConnectingConnectionButtonPath = _buildConnectionButtonCookiePath(
  const Size.square(_kConnectionButtonSize),
  const ConnectionButtonShape(phase: 1, rotation: 0, emphasis: .52),
);

final Path _kConnectedConnectionButtonPath = _buildConnectionButtonCookiePath(
  const Size.square(_kConnectionButtonSize),
  const ConnectionButtonShape(phase: 2, rotation: 0, emphasis: 1.16),
);

final Path _kResolvingConnectionButtonPath = _buildConnectionButtonCookiePath(
  const Size.square(_kConnectionButtonSize),
  const ConnectionButtonShape(phase: 3, rotation: 0, emphasis: .96),
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
