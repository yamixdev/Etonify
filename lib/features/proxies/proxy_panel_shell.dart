import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:meow_client/widgets/app_bottom_sheet_surface.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

const proxyPanelMinHeight = 108.0;
const proxyPanelRowExtent = 72.0;
const proxyPanelListBottomPadding = 20.0;
const proxyPanelScreenCornerRadius = appBottomSheetCornerRadius;

const _proxyPanelStatusBarGap = 8.0;

@immutable
class ProxyPanelMetrics {
  const ProxyPanelMetrics({
    required this.bottomInset,
    required this.panelHeight,
    required this.maxPanelHeight,
    required this.viewportHeight,
    required this.viewportLimit,
    required this.progress,
    required this.backdropProgress,
    required this.atMaxExtent,
    required this.canFillScreen,
    required this.collapseOnAnyDownwardDrag,
    required this.dragging,
    required this.animating,
  });

  final double bottomInset;
  final double panelHeight;
  final double maxPanelHeight;
  final double viewportHeight;
  final double viewportLimit;
  final double progress;
  final double backdropProgress;
  final bool atMaxExtent;
  final bool canFillScreen;
  final bool collapseOnAnyDownwardDrag;
  final bool dragging;
  final bool animating;

  @override
  bool operator ==(Object other) {
    return other is ProxyPanelMetrics &&
        other.bottomInset == bottomInset &&
        other.panelHeight == panelHeight &&
        other.maxPanelHeight == maxPanelHeight &&
        other.viewportHeight == viewportHeight &&
        other.viewportLimit == viewportLimit &&
        other.progress == progress &&
        other.backdropProgress == backdropProgress &&
        other.atMaxExtent == atMaxExtent &&
        other.canFillScreen == canFillScreen &&
        other.collapseOnAnyDownwardDrag == collapseOnAnyDownwardDrag &&
        other.dragging == dragging &&
        other.animating == animating;
  }

  @override
  int get hashCode => Object.hash(
    bottomInset,
    panelHeight,
    maxPanelHeight,
    viewportHeight,
    viewportLimit,
    progress,
    backdropProgress,
    atMaxExtent,
    canFillScreen,
    collapseOnAnyDownwardDrag,
    dragging,
    animating,
  );
}

@immutable
class ProxyPanelGestures {
  const ProxyPanelGestures({required this.onHeaderTap});

  final VoidCallback onHeaderTap;
}

typedef ProxyPanelHomeBuilder =
    Widget Function(BuildContext context, ProxyPanelMetrics metrics);

typedef ProxyPanelSheetBuilder =
    Widget Function(
      BuildContext context,
      ProxyPanelMetrics metrics,
      ValueListenable<ProxyPanelMetrics> metricsListenable,
      ScrollController scrollController,
      ProxyPanelGestures gestures,
    );

class ProxyPanelShell extends StatefulWidget {
  const ProxyPanelShell({
    super.key,
    required this.ready,
    required this.onboardingCompleted,
    required this.loading,
    required this.welcome,
    required this.visibleRows,
    required this.hasActiveProfile,
    required this.homeBuilder,
    required this.sheetBuilder,
    this.resetListKey,
    this.onInteractionActiveChanged,
    this.onOpenRequested,
    this.onOpened,
    this.onClosed,
  });

  final bool ready;
  final bool onboardingCompleted;
  final Widget loading;
  final Widget welcome;
  final int visibleRows;
  final bool hasActiveProfile;
  final ProxyPanelHomeBuilder homeBuilder;
  final ProxyPanelSheetBuilder sheetBuilder;
  final Object? resetListKey;
  final ValueChanged<bool>? onInteractionActiveChanged;
  final VoidCallback? onOpenRequested;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  @override
  State<ProxyPanelShell> createState() => _ProxyPanelShellState();
}

class _ProxyPanelShellState extends State<ProxyPanelShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _panelController;
  late final ValueNotifier<ProxyPanelMetrics> _metricsNotifier =
      ValueNotifier<ProxyPanelMetrics>(_fallbackMetrics);
  final ScrollController _listController = ScrollController();

  bool _interactionActive = false;
  bool _animating = false;
  bool _open = false;
  bool _openRequested = false;
  bool _openedNotified = false;
  bool _resetAfterWidgetUpdateScheduled = false;
  int _animationGeneration = 0;
  double _parentHeight = proxyPanelMinHeight;
  double _viewportHeight = proxyPanelMinHeight;
  double _topInset = 0;
  double _bottomInset = 0;
  bool _layoutReady = false;

  int? _sheetPointer;
  double _pointerStartY = 0;
  double _pointerDeltaY = 0;
  double _dragStartProgress = 0;
  double _dragRange = 0;
  bool _pointerStartedInHeader = false;
  bool _draggingPanel = false;

  static const ProxyPanelMetrics _fallbackMetrics = ProxyPanelMetrics(
    bottomInset: 0,
    panelHeight: proxyPanelMinHeight,
    maxPanelHeight: proxyPanelMinHeight,
    viewportHeight: proxyPanelMinHeight,
    viewportLimit: proxyPanelMinHeight,
    progress: 0,
    backdropProgress: 0,
    atMaxExtent: false,
    canFillScreen: false,
    collapseOnAnyDownwardDrag: true,
    dragging: false,
    animating: false,
  );

  @override
  void initState() {
    super.initState();
    _panelController = AnimationController(
      vsync: this,
      duration: appBottomSheetAnimationDuration,
    )..addListener(_publishMetrics);
  }

  @override
  void didUpdateWidget(covariant ProxyPanelShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final panelUnavailable =
        !widget.ready ||
        !widget.onboardingCompleted ||
        !widget.hasActiveProfile;
    if (panelUnavailable || oldWidget.resetListKey != widget.resetListKey) {
      _resetListScroll();
      _scheduleCollapsedReset();
      return;
    }
    if (oldWidget.visibleRows != widget.visibleRows && _isClosed) {
      _resetListScroll();
    }
  }

  @override
  void dispose() {
    _panelController.dispose();
    _listController.dispose();
    _metricsNotifier.dispose();
    super.dispose();
  }

  bool get _isClosed =>
      !_open && _panelController.value <= 0.001 && !_animating;

  void _markInteractionActive() {
    if (_interactionActive) {
      return;
    }
    _interactionActive = true;
    widget.onInteractionActiveChanged?.call(true);
    _publishMetrics();
  }

  void _finishInteraction() {
    if (!_interactionActive) {
      return;
    }
    _interactionActive = false;
    widget.onInteractionActiveChanged?.call(false);
    _publishMetrics();
  }

  void _scheduleCollapsedReset() {
    if (_resetAfterWidgetUpdateScheduled) {
      return;
    }
    _resetAfterWidgetUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetAfterWidgetUpdateScheduled = false;
      if (!mounted) {
        return;
      }
      final notifyClosed = _openRequested;
      ++_animationGeneration;
      _panelController.stop();
      _panelController.value = 0;
      _animating = false;
      _open = false;
      _draggingPanel = false;
      _resetPointerTracking();
      _resetListScroll();
      _finishInteraction();
      if (notifyClosed) {
        _openRequested = false;
        _openedNotified = false;
        widget.onClosed?.call();
      }
    });
  }

  void _resetListScroll() {
    if (!_listController.hasClients) {
      return;
    }
    for (final position in _listController.positions) {
      if ((position.pixels - position.minScrollExtent).abs() > 0.5) {
        position.jumpTo(position.minScrollExtent);
      }
    }
  }

  bool get _listIsAtTop {
    if (!_listController.hasClients) {
      return true;
    }
    return _listController.positions.every(
      (position) => position.pixels <= position.minScrollExtent + 0.5,
    );
  }

  double _viewportLimit(double viewportHeight, {double topInset = 0}) {
    if (viewportHeight <= proxyPanelMinHeight) {
      return proxyPanelMinHeight;
    }
    final topReserve = (topInset + _proxyPanelStatusBarGap)
        .clamp(0.0, viewportHeight - proxyPanelMinHeight)
        .toDouble();
    return viewportHeight - topReserve;
  }

  double _maxHeight(double viewportHeight, {double topInset = 0}) {
    if (viewportHeight <= proxyPanelMinHeight || widget.visibleRows <= 0) {
      return proxyPanelMinHeight;
    }
    // The expanded extent must not depend on how many rows happen to be in
    // the active profile. A short list still needs to drag to the top; if its
    // content height is used as the limit, the list starts scrolling under the
    // pinned header while the sheet remains stranded halfway up the screen.
    return _viewportLimit(viewportHeight, topInset: topInset);
  }

  void _updateLayout(BuildContext context, BoxConstraints constraints) {
    final mediaSize = MediaQuery.sizeOf(context);
    final nextParentHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : mediaSize.height;
    final nextBottomInset = appSystemNavigationBarInset(
      context,
    ).clamp(0.0, nextParentHeight - proxyPanelMinHeight).toDouble();
    final nextViewportHeight = (nextParentHeight - nextBottomInset)
        .clamp(proxyPanelMinHeight, double.infinity)
        .toDouble();
    final nextTopInset = MediaQuery.paddingOf(context).top;
    final layoutChanged =
        !_layoutReady ||
        (nextParentHeight - _parentHeight).abs() > 0.5 ||
        (nextViewportHeight - _viewportHeight).abs() > 0.5 ||
        (nextTopInset - _topInset).abs() > 0.5 ||
        (nextBottomInset - _bottomInset).abs() > 0.5;
    if (!layoutChanged) {
      return;
    }

    _parentHeight = nextParentHeight;
    _viewportHeight = nextViewportHeight;
    _topInset = nextTopInset;
    _bottomInset = nextBottomInset;
    _layoutReady = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _publishMetrics();
      }
    });
  }

  ProxyPanelMetrics _currentMetrics() {
    if (!_layoutReady) {
      return _fallbackMetrics;
    }
    final maxPanelHeight = _maxHeight(_viewportHeight, topInset: _topInset);
    final viewportLimit = _viewportLimit(_viewportHeight, topInset: _topInset);
    final progress = _panelController.value.clamp(0.0, 1.0).toDouble();
    final panelHeight =
        proxyPanelMinHeight + (maxPanelHeight - proxyPanelMinHeight) * progress;
    return ProxyPanelMetrics(
      bottomInset: _bottomInset,
      panelHeight: panelHeight,
      maxPanelHeight: maxPanelHeight,
      viewportHeight: _viewportHeight,
      viewportLimit: viewportLimit,
      progress: progress,
      backdropProgress: Curves.easeOutCubic.transform(progress),
      atMaxExtent: progress >= 0.999 && !_draggingPanel,
      canFillScreen: maxPanelHeight >= viewportLimit - 0.5,
      collapseOnAnyDownwardDrag:
          maxPanelHeight < viewportLimit - 0.5 || widget.visibleRows <= 3,
      dragging: _draggingPanel,
      animating: _animating,
    );
  }

  void _publishMetrics() {
    final metrics = _currentMetrics();
    if (_metricsNotifier.value != metrics) {
      _metricsNotifier.value = metrics;
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_sheetPointer != null) {
      return;
    }
    if (_animating) {
      ++_animationGeneration;
      _panelController.stop();
      _animating = false;
    }
    final metrics = _currentMetrics();
    _sheetPointer = event.pointer;
    _pointerStartY = event.position.dy;
    _pointerDeltaY = 0;
    _dragStartProgress = _panelController.value;
    _dragRange = metrics.maxPanelHeight - proxyPanelMinHeight;
    _pointerStartedInHeader = event.localPosition.dy <= proxyPanelMinHeight;
    _draggingPanel = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _sheetPointer || _dragRange <= 0) {
      return;
    }
    final deltaY = event.position.dy - _pointerStartY;
    _pointerDeltaY = deltaY;

    if (!_draggingPanel) {
      if (deltaY.abs() < kTouchSlop) {
        return;
      }
      final panelBelowMax = _panelController.value < 0.999;
      final pullingDownAtListTop = deltaY > 0 && _listIsAtTop;
      if (!panelBelowMax && !_pointerStartedInHeader && !pullingDownAtListTop) {
        // Let the list consume this gesture. Reset the hand-off origin while
        // it scrolls so reaching the top cannot make the sheet jump by the
        // distance already consumed by the list.
        _pointerStartY = event.position.dy;
        _pointerDeltaY = 0;
        _dragStartProgress = _panelController.value;
        return;
      }
      _draggingPanel = true;
      _markInteractionActive();
    }

    _panelController.value = (_dragStartProgress - deltaY / _dragRange)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _sheetPointer) {
      return;
    }
    final wasDragging = _draggingPanel;
    final deltaY = _pointerDeltaY;
    final cancelled = event is PointerCancelEvent;
    _resetPointerTracking();
    if (!wasDragging) {
      _finishInteraction();
      return;
    }
    final targetOpen = cancelled
        ? _open
        : deltaY.abs() < kTouchSlop
        ? _panelController.value >= 0.5
        : deltaY < 0;
    unawaited(_animateTo(open: targetOpen));
  }

  void _resetPointerTracking() {
    _sheetPointer = null;
    _pointerStartY = 0;
    _pointerDeltaY = 0;
    _dragStartProgress = 0;
    _dragRange = 0;
    _pointerStartedInHeader = false;
  }

  void _notifyOpened() {
    if (_openedNotified) {
      return;
    }
    _openedNotified = true;
    widget.onOpened?.call();
  }

  void _notifyClosed() {
    _resetListScroll();
    if (!_openRequested) {
      return;
    }
    _openRequested = false;
    _openedNotified = false;
    widget.onClosed?.call();
  }

  Future<void> _animateTo({required bool open}) async {
    if (!_layoutReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_animateTo(open: open));
        }
      });
      return;
    }
    if (open && !_openRequested) {
      _openRequested = true;
      widget.onOpenRequested?.call();
    }
    _open = open;
    final target = open ? 1.0 : 0.0;
    final generation = ++_animationGeneration;
    _animating = true;
    _draggingPanel = false;
    _markInteractionActive();
    _publishMetrics();
    try {
      await _panelController.animateTo(
        target,
        duration: appBottomSheetAnimationDuration,
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // The panel can detach while the app route or profile changes.
    } finally {
      if (mounted && generation == _animationGeneration) {
        _animating = false;
        _publishMetrics();
        _finishInteraction();
        if (open && (_panelController.value - 1).abs() <= 0.001) {
          _notifyOpened();
        } else if (!open && _panelController.value <= 0.001) {
          _notifyClosed();
        }
      }
    }
  }

  void _toggle() {
    unawaited(_animateTo(open: !_open));
  }

  @override
  Widget build(BuildContext context) {
    final rootChild = !widget.ready
        ? widget.loading
        : !widget.onboardingCompleted
        ? widget.welcome
        : _buildShell(context);

    return ValueListenableBuilder<ProxyPanelMetrics>(
      valueListenable: _metricsNotifier,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: rootChild,
      ),
      builder: (context, metrics, child) {
        final panelOpen = metrics.progress > 0.001 || metrics.animating;
        return PopScope(
          canPop: !panelOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && panelOpen) {
              unawaited(_animateTo(open: false));
            }
          },
          child: child!,
        );
      },
    );
  }

  Widget _buildShell(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const ValueKey('shell'),
      extendBody: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _updateLayout(context, constraints);
          final metrics = _currentMetrics();
          if (_metricsNotifier.value != metrics) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _publishMetrics();
              }
            });
          }

          final gestures = ProxyPanelGestures(onHeaderTap: _toggle);
          final sheet = widget.hasActiveProfile
              ? RepaintBoundary(
                  child: widget.sheetBuilder(
                    context,
                    metrics,
                    _metricsNotifier,
                    _listController,
                    gestures,
                  ),
                )
              : null;

          return Stack(
            children: [
              RepaintBoundary(child: widget.homeBuilder(context, metrics)),
              if (sheet != null) ...[
                ValueListenableBuilder<ProxyPanelMetrics>(
                  valueListenable: _metricsNotifier,
                  builder: (context, liveMetrics, _) {
                    final visible =
                        liveMetrics.progress > 0.001 || liveMetrics.animating;
                    return IgnorePointer(
                      ignoring: !visible,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => unawaited(_animateTo(open: false)),
                        child: ColoredBox(
                          color: Colors.black.withValues(
                            alpha:
                                liveMetrics.backdropProgress *
                                (theme.brightness == Brightness.dark
                                    ? 0.22
                                    : 0.16),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<ProxyPanelMetrics>(
                  valueListenable: _metricsNotifier,
                  child: Listener(
                    key: const ValueKey('proxy-panel-drag-surface'),
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _handlePointerEnd,
                    onPointerCancel: _handlePointerEnd,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(proxyPanelScreenCornerRadius),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: sheet,
                    ),
                  ),
                  builder: (context, liveMetrics, child) {
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: liveMetrics.panelHeight + liveMetrics.bottomInset,
                      child: child!,
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
