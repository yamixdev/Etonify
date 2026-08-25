import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

const proxyPanelMinHeight = 108.0;
const proxyPanelScreenCornerRadius = 32.0;

const _proxyPanelHeaderHeight = 108.0;
const _proxyPanelRowHeight = 66.0;
const _proxyPanelContentBottomPadding = 60.0;
const _proxyPanelStatusBarGap = 8.0;
const _proxyPanelSettleVelocity = 320.0;
const _proxyPanelOpenThreshold = .36;
const _proxyPanelAnimationDuration = Duration(milliseconds: 260);

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
  const ProxyPanelGestures({
    required this.onInteractionStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onHeaderTap,
  });

  final VoidCallback onInteractionStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;
  final VoidCallback onHeaderTap;
}

typedef ProxyPanelHomeBuilder =
    Widget Function(
      BuildContext context,
      ProxyPanelMetrics metrics,
      ProxyPanelGestures gestures,
    );

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
  final VoidCallback? onClosed;

  @override
  State<ProxyPanelShell> createState() => _ProxyPanelShellState();
}

class _ProxyPanelShellState extends State<ProxyPanelShell> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  late final ValueNotifier<ProxyPanelMetrics> _metricsNotifier =
      ValueNotifier<ProxyPanelMetrics>(_fallbackMetrics);

  ScrollController? _listController;
  bool _interactionActive = false;
  bool _animating = false;
  bool _resetAfterWidgetUpdateScheduled = false;
  int _animationGeneration = 0;
  double _parentHeight = proxyPanelMinHeight;
  double _viewportHeight = proxyPanelMinHeight;
  double _topInset = 0;
  double _bottomInset = 0;
  double _minSize = 1;
  double _maxSize = 1;
  double _lastSize = 1;
  bool _layoutReady = false;
  int? _sheetPointer;
  bool _rawSheetDragMoved = false;
  bool _rawSheetOpenRequested = false;
  double _rawSheetStartProgress = 0;
  double _rawSheetTotalDeltaY = 0;
  bool _externalOpenRequested = false;
  double _externalDragDeltaY = 0;

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
    _sheetController.addListener(_handleSheetExtentChanged);
  }

  @override
  void didUpdateWidget(covariant ProxyPanelShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetListKey != widget.resetListKey) {
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
    _sheetController
      ..removeListener(_handleSheetExtentChanged)
      ..dispose();
    _metricsNotifier.dispose();
    super.dispose();
  }

  bool get _isClosed =>
      _metricsNotifier.value.progress <= .02 &&
      !_metricsNotifier.value.animating;

  void _handleSheetExtentChanged() {
    if (!_sheetController.isAttached || !_layoutReady) {
      return;
    }
    _lastSize = _sheetController.size.clamp(_minSize, _maxSize).toDouble();
    _publishMetrics();
  }

  void _markInteractionActive() {
    if (!_interactionActive) {
      _interactionActive = true;
      widget.onInteractionActiveChanged?.call(true);
      _publishMetrics();
    }
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
      if (!mounted || !_layoutReady) {
        return;
      }
      ++_animationGeneration;
      _animating = false;
      _sheetPointer = null;
      _rawSheetDragMoved = false;
      _rawSheetOpenRequested = false;
      _rawSheetTotalDeltaY = 0;
      _externalDragDeltaY = 0;
      if (_sheetController.isAttached) {
        _sheetController.jumpTo(_minSize);
      }
      _lastSize = _minSize;
      _resetListScroll();
      _finishInteraction();
      widget.onClosed?.call();
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_sheetPointer != null) {
      return;
    }
    _sheetPointer = event.pointer;
    if (_animating) {
      ++_animationGeneration;
      _animating = false;
      if (_sheetController.isAttached) {
        _sheetController.jumpTo(_currentSize());
      }
    }
    _rawSheetDragMoved = false;
    _rawSheetOpenRequested = false;
    _rawSheetTotalDeltaY = 0;
    final progress = _currentMetrics().progress;
    _rawSheetStartProgress = progress;
    _markInteractionActive();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _sheetPointer) {
      return;
    }
    final deltaY = event.delta.dy;
    if (deltaY.abs() < 0.01) {
      return;
    }
    _rawSheetTotalDeltaY += deltaY;
    _rawSheetDragMoved = _rawSheetTotalDeltaY.abs() >= 2;
    if (!_layoutReady || !_sheetController.isAttached || _parentHeight <= 0) {
      return;
    }
    final progress = _currentMetrics().progress;
    final controlsExtent =
        progress < .985 ||
        event.localPosition.dy <= _proxyPanelHeaderHeight ||
        (deltaY > 0 && _listIsAtTop);
    if (!controlsExtent) {
      return;
    }
    if (!_rawSheetOpenRequested && deltaY < 0 && _isClosed) {
      _rawSheetOpenRequested = true;
      widget.onOpenRequested?.call();
    }
    _markInteractionActive();
    final target = (_sheetController.size - deltaY / _parentHeight)
        .clamp(_minSize, _maxSize)
        .toDouble();
    _sheetController.jumpTo(target);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _sheetPointer) {
      return;
    }
    final totalDeltaY = _rawSheetTotalDeltaY;
    final extentChanged =
        (_currentMetrics().progress - _rawSheetStartProgress).abs() >= .015;
    final shouldSettle =
        _rawSheetDragMoved &&
        _layoutReady &&
        (extentChanged ||
            (_currentMetrics().progress > .02 &&
                _currentMetrics().progress < .985 &&
                totalDeltaY.abs() >= 12));
    _sheetPointer = null;
    _rawSheetDragMoved = false;
    _rawSheetOpenRequested = false;
    _rawSheetStartProgress = 0;
    _rawSheetTotalDeltaY = 0;
    if (shouldSettle) {
      _settleAfterPointer(
        open: totalDeltaY.abs() >= 12
            ? totalDeltaY < 0
            : _currentMetrics().progress >= _proxyPanelOpenThreshold,
      );
      return;
    }
    _finishInteraction();
  }

  bool get _listIsAtTop {
    final controller = _listController;
    if (controller == null || !controller.hasClients) {
      return true;
    }
    return controller.positions.every(
      (position) => position.pixels <= position.minScrollExtent + 0.5,
    );
  }

  void _settleAfterPointer({required bool open}) {
    if (mounted) {
      unawaited(_animateTo(open: open));
    }
  }

  void _resetListScroll() {
    final controller = _listController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    for (final position in controller.positions) {
      if ((position.pixels - position.minScrollExtent).abs() > 0.5) {
        position.jumpTo(position.minScrollExtent);
      }
    }
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
    if (viewportHeight <= proxyPanelMinHeight) {
      return proxyPanelMinHeight;
    }
    final viewportLimit = _viewportLimit(viewportHeight, topInset: topInset);
    final rowCount = widget.visibleRows;
    if (rowCount <= 0) {
      return proxyPanelMinHeight;
    }
    if (widget.hasActiveProfile && rowCount <= 1) {
      return viewportLimit;
    }
    final contentHeight =
        _proxyPanelHeaderHeight +
        rowCount * _proxyPanelRowHeight +
        _proxyPanelContentBottomPadding;
    final maxForContent = contentHeight
        .clamp(proxyPanelMinHeight, viewportLimit)
        .toDouble();
    return maxForContent >= viewportLimit * .88 ? viewportLimit : maxForContent;
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
    final nextMaxHeight = _maxHeight(
      nextViewportHeight,
      topInset: nextTopInset,
    );
    final nextMinTotalHeight = (proxyPanelMinHeight + nextBottomInset)
        .clamp(0.0, nextParentHeight)
        .toDouble();
    final nextMaxTotalHeight = (nextMaxHeight + nextBottomInset)
        .clamp(nextMinTotalHeight, nextParentHeight)
        .toDouble();
    final nextMinSize = nextParentHeight <= 0
        ? 1.0
        : nextMinTotalHeight / nextParentHeight;
    final nextMaxSize = nextParentHeight <= 0
        ? 1.0
        : nextMaxTotalHeight / nextParentHeight;

    final layoutChanged =
        !_layoutReady ||
        (nextParentHeight - _parentHeight).abs() > 0.5 ||
        (nextViewportHeight - _viewportHeight).abs() > 0.5 ||
        (nextTopInset - _topInset).abs() > 0.5 ||
        (nextBottomInset - _bottomInset).abs() > 0.5 ||
        (nextMinSize - _minSize).abs() > 0.0001 ||
        (nextMaxSize - _maxSize).abs() > 0.0001;
    if (!layoutChanged) {
      return;
    }

    final previousProgress = _layoutReady
        ? _normalizedProgress(_currentSize())
        : 0.0;
    _parentHeight = nextParentHeight;
    _viewportHeight = nextViewportHeight;
    _topInset = nextTopInset;
    _bottomInset = nextBottomInset;
    _minSize = nextMinSize;
    _maxSize = nextMaxSize;
    _lastSize = _minSize + (_maxSize - _minSize) * previousProgress;
    _layoutReady = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_sheetController.isAttached) {
        final current = _sheetController.size;
        final target = current.clamp(_minSize, _maxSize).toDouble();
        if ((target - current).abs() > 0.0001) {
          _sheetController.jumpTo(target);
        }
        _lastSize = target;
      }
      _publishMetrics();
    });
  }

  double _currentSize() {
    if (_sheetController.isAttached) {
      return _sheetController.size.clamp(_minSize, _maxSize).toDouble();
    }
    return _lastSize.clamp(_minSize, _maxSize).toDouble();
  }

  double _normalizedProgress(double size) {
    final range = _maxSize - _minSize;
    if (range <= 0.0001) {
      return 0;
    }
    return ((size - _minSize) / range).clamp(0.0, 1.0).toDouble();
  }

  ProxyPanelMetrics _currentMetrics() {
    if (!_layoutReady) {
      return _fallbackMetrics;
    }
    final maxPanelHeight = _maxHeight(_viewportHeight, topInset: _topInset);
    final viewportLimit = _viewportLimit(_viewportHeight, topInset: _topInset);
    final size = _currentSize();
    final totalHeight = size * _parentHeight;
    final panelHeight = (totalHeight - _bottomInset)
        .clamp(proxyPanelMinHeight, maxPanelHeight)
        .toDouble();
    final progress = _normalizedProgress(size);
    return ProxyPanelMetrics(
      bottomInset: _bottomInset,
      panelHeight: panelHeight,
      maxPanelHeight: maxPanelHeight,
      viewportHeight: _viewportHeight,
      viewportLimit: viewportLimit,
      progress: progress,
      backdropProgress: Curves.easeOutCubic.transform(progress),
      atMaxExtent: progress >= .985,
      canFillScreen: maxPanelHeight >= viewportLimit - 0.5,
      collapseOnAnyDownwardDrag:
          maxPanelHeight < viewportLimit - 0.5 || widget.visibleRows <= 3,
      dragging: _interactionActive,
      animating: _animating,
    );
  }

  void _publishMetrics() {
    final metrics = _currentMetrics();
    if (_metricsNotifier.value != metrics) {
      _metricsNotifier.value = metrics;
    }
  }

  Future<void> _animateTo({
    required bool open,
    bool retryIfDetached = true,
  }) async {
    if (!_layoutReady) {
      return;
    }
    if (!_sheetController.isAttached) {
      if (retryIfDetached) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_animateTo(open: open, retryIfDetached: false));
          }
        });
      }
      return;
    }
    if (open) {
      widget.onOpenRequested?.call();
    }
    final target = open ? _maxSize : _minSize;
    final current = _currentSize();
    if ((target - current).abs() <= 0.0001) {
      if (!open) {
        _resetListScroll();
        widget.onClosed?.call();
      }
      _finishInteraction();
      return;
    }

    final generation = ++_animationGeneration;
    _animating = true;
    _markInteractionActive();
    _publishMetrics();
    try {
      await _sheetController.animateTo(
        target,
        duration: _proxyPanelAnimationDuration,
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // The sheet can detach while the app route or onboarding state changes.
    } finally {
      if (mounted && generation == _animationGeneration) {
        _animating = false;
        if (_sheetController.isAttached) {
          _lastSize = _sheetController.size
              .clamp(_minSize, _maxSize)
              .toDouble();
        }
        if (!open) {
          _resetListScroll();
          widget.onClosed?.call();
        }
        _publishMetrics();
        _finishInteraction();
      }
    }
  }

  void _handleHeaderDragUpdate(DragUpdateDetails details) {
    if (!_layoutReady || !_sheetController.isAttached || _parentHeight <= 0) {
      return;
    }
    if (_isClosed && !_externalOpenRequested) {
      _externalOpenRequested = true;
      widget.onOpenRequested?.call();
    }
    _markInteractionActive();
    final deltaY = details.primaryDelta ?? details.delta.dy;
    _externalDragDeltaY += deltaY;
    final target = (_sheetController.size - deltaY / _parentHeight)
        .clamp(_minSize, _maxSize)
        .toDouble();
    _sheetController.jumpTo(target);
  }

  void _handleHeaderDragEnd(DragEndDetails details) {
    _externalOpenRequested = false;
    final totalDeltaY = _externalDragDeltaY;
    _externalDragDeltaY = 0;
    final velocity = details.primaryVelocity ?? 0;
    final progress = _currentMetrics().progress;
    final open = totalDeltaY.abs() >= 12
        ? totalDeltaY < 0
        : velocity < -_proxyPanelSettleVelocity
        ? true
        : velocity > _proxyPanelSettleVelocity
        ? false
        : progress >= _proxyPanelOpenThreshold;
    _settleAfterPointer(open: open);
  }

  void _toggle() {
    unawaited(_animateTo(open: _currentMetrics().progress <= .02));
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
        final panelOpen = metrics.progress > .02 || metrics.animating;
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
          final gestures = ProxyPanelGestures(
            onInteractionStart: () {
              _externalOpenRequested = false;
              _externalDragDeltaY = 0;
              _markInteractionActive();
            },
            onDragUpdate: _handleHeaderDragUpdate,
            onDragEnd: _handleHeaderDragEnd,
            onHeaderTap: _toggle,
          );

          return Stack(
            children: [
              RepaintBoundary(
                child: widget.homeBuilder(context, metrics, gestures),
              ),
              ValueListenableBuilder<ProxyPanelMetrics>(
                valueListenable: _metricsNotifier,
                builder: (context, liveMetrics, _) {
                  final visible =
                      liveMetrics.progress > .02 || liveMetrics.animating;
                  return IgnorePointer(
                    ignoring: !visible,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => unawaited(_animateTo(open: false)),
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha:
                              liveMetrics.backdropProgress *
                              (theme.brightness == Brightness.dark ? .22 : .16),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  );
                },
              ),
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: _minSize,
                minChildSize: _minSize,
                maxChildSize: _maxSize,
                snap: false,
                shouldCloseOnMinExtent: false,
                builder: (context, scrollController) {
                  _listController = scrollController;
                  return Listener(
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
                      child: widget.sheetBuilder(
                        context,
                        metrics,
                        _metricsNotifier,
                        scrollController,
                        gestures,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
