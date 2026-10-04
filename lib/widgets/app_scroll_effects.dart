import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:meow_client/widgets/app_visual_effects.dart';

class AppScrollEffects extends StatefulWidget {
  const AppScrollEffects({super.key, required this.child});

  final Widget child;

  @override
  State<AppScrollEffects> createState() => _AppScrollEffectsState();
}

class _AppScrollEffectsState extends State<AppScrollEffects> {
  static const _edgeHapticCooldown = Duration(milliseconds: 220);
  static const _ratchetHapticCooldown = Duration(milliseconds: 72);
  static const _ratchetStep = 40.0;
  static const _edgeTolerance = 0.5;

  DateTime? _lastHapticAt;
  DateTime? _lastRatchetHapticAt;
  _ScrollEdge? _lastHapticEdge;
  _ScrollEdge? _dragStartEdge;
  bool _trackingUserScroll = false;
  double? _lastPixels;
  double _ratchetDistance = 0;
  final Set<_ScrollEdge> _hitEdgesInDrag = <_ScrollEdge>{};

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: widget.child,
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!AppVisualEffects.of(context).hapticEnabled) {
      return false;
    }

    switch (notification) {
      case ScrollStartNotification(:final dragDetails) when dragDetails != null:
        _startUserScroll(notification.metrics);
      case UserScrollNotification(:final direction)
          when direction != ScrollDirection.idle:
        _startUserScroll(notification.metrics);
      case ScrollUpdateNotification():
        _handleScrollUpdate(notification);
      case ScrollEndNotification():
        _trackingUserScroll = false;
        _dragStartEdge = null;
        _lastPixels = null;
        _ratchetDistance = 0;
        _hitEdgesInDrag.clear();
      default:
        break;
    }

    return false;
  }

  void _handleScrollUpdate(ScrollUpdateNotification notification) {
    if (notification.dragDetails != null) {
      _startUserScroll(notification.metrics);
    }
    if (!_trackingUserScroll) {
      return;
    }

    final metrics = notification.metrics;
    if (metrics.maxScrollExtent <= metrics.minScrollExtent) {
      return;
    }

    final scrollDelta = _scrollDelta(notification);
    _lastPixels = metrics.pixels;
    _handleRatchetHaptic(scrollDelta);

    final edge = _edgeForMetrics(metrics);
    if (edge == null) {
      return;
    }

    final isPushingIntoEdge = switch (edge) {
      _ScrollEdge.leading => scrollDelta < 0,
      _ScrollEdge.trailing => scrollDelta > 0,
    };
    if (!isPushingIntoEdge ||
        _dragStartEdge == edge ||
        !_hitEdgesInDrag.add(edge)) {
      return;
    }

    _pulseHaptic(edge);
  }

  void _startUserScroll(ScrollMetrics metrics) {
    if (_trackingUserScroll) {
      return;
    }

    _trackingUserScroll = true;
    _dragStartEdge = _edgeForMetrics(metrics);
    _lastPixels = metrics.pixels;
    _ratchetDistance = 0;
    _hitEdgesInDrag.clear();
  }

  double _scrollDelta(ScrollUpdateNotification notification) {
    final explicitDelta = notification.scrollDelta;
    if (explicitDelta != null) {
      return explicitDelta;
    }

    final previousPixels = _lastPixels;
    if (previousPixels == null) {
      return 0;
    }
    return notification.metrics.pixels - previousPixels;
  }

  void _handleRatchetHaptic(double scrollDelta) {
    final distance = scrollDelta.abs();
    if (distance <= 0) {
      return;
    }

    _ratchetDistance += distance;
    if (_ratchetDistance < _ratchetStep) {
      return;
    }

    _ratchetDistance %= _ratchetStep;
    final now = DateTime.now();
    if (_lastRatchetHapticAt != null &&
        now.difference(_lastRatchetHapticAt!) < _ratchetHapticCooldown) {
      return;
    }

    _lastRatchetHapticAt = now;
    HapticFeedback.selectionClick();
  }

  _ScrollEdge? _edgeForMetrics(ScrollMetrics metrics) {
    if (metrics.pixels <= metrics.minScrollExtent + _edgeTolerance) {
      return _ScrollEdge.leading;
    }
    if (metrics.pixels >= metrics.maxScrollExtent - _edgeTolerance) {
      return _ScrollEdge.trailing;
    }
    return null;
  }

  void _pulseHaptic(_ScrollEdge edge) {
    final now = DateTime.now();
    final canPulse =
        _lastHapticAt == null ||
        now.difference(_lastHapticAt!) >= _edgeHapticCooldown ||
        edge != _lastHapticEdge;
    if (!canPulse) {
      return;
    }

    _lastHapticAt = now;
    _lastHapticEdge = edge;
    HapticFeedback.selectionClick();
  }
}

enum _ScrollEdge { leading, trailing }
