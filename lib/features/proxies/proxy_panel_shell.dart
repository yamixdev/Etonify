import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meow_client/widgets/app_bottom_sheet_surface.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

const proxyPanelMinHeight = 108.0;
const proxyPanelRowExtent = 72.0;
const proxyPanelScreenCornerRadius = appBottomSheetCornerRadius;

const _proxyPanelContentBottomPadding = 60.0;
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

class _ProxyPanelShellState extends State<ProxyPanelShell> {
  late final ValueNotifier<ProxyPanelMetrics> _collapsedMetricsNotifier =
      ValueNotifier<ProxyPanelMetrics>(_fallbackMetrics);
  final ValueNotifier<int> _contentRevision = ValueNotifier<int>(0);
  final ScrollController _collapsedListController = ScrollController();

  bool _interactionActive = false;
  bool _panelRouteOpen = false;
  bool _openedNotified = false;
  bool _contentRefreshScheduled = false;
  bool _dismissWhenRouteReady = false;
  BuildContext? _panelRouteContext;
  double _collapsedDragStartY = 0;
  double _collapsedDragDistance = 0;

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
  void didUpdateWidget(covariant ProxyPanelShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleRouteContentRefresh();

    final panelUnavailable =
        !widget.ready ||
        !widget.onboardingCompleted ||
        !widget.hasActiveProfile;
    if (panelUnavailable || oldWidget.resetListKey != widget.resetListKey) {
      _resetCollapsedListScroll();
      _dismissPanel();
    }
  }

  @override
  void dispose() {
    _collapsedListController.dispose();
    _collapsedMetricsNotifier.dispose();
    _contentRevision.dispose();
    super.dispose();
  }

  void _scheduleRouteContentRefresh() {
    if (!_panelRouteOpen || _contentRefreshScheduled) {
      return;
    }
    _contentRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentRefreshScheduled = false;
      if (mounted && _panelRouteOpen) {
        _contentRevision.value++;
      }
    });
  }

  void _markInteractionActive() {
    if (_interactionActive) {
      return;
    }
    _interactionActive = true;
    widget.onInteractionActiveChanged?.call(true);
  }

  void _finishInteraction() {
    if (!_interactionActive) {
      return;
    }
    _interactionActive = false;
    widget.onInteractionActiveChanged?.call(false);
  }

  void _resetCollapsedListScroll() {
    if (!_collapsedListController.hasClients) {
      return;
    }
    for (final position in _collapsedListController.positions) {
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
    if (viewportHeight <= proxyPanelMinHeight || widget.visibleRows <= 0) {
      return proxyPanelMinHeight;
    }
    final viewportLimit = _viewportLimit(viewportHeight, topInset: topInset);
    final contentHeight =
        proxyPanelMinHeight +
        widget.visibleRows * proxyPanelRowExtent +
        _proxyPanelContentBottomPadding;
    final maxForContent = contentHeight
        .clamp(proxyPanelMinHeight, viewportLimit)
        .toDouble();
    return maxForContent >= viewportLimit * .88 ? viewportLimit : maxForContent;
  }

  ProxyPanelMetrics _metricsFor(
    BuildContext context, {
    required double availableHeight,
    required bool expanded,
  }) {
    final bottomInset = appSystemNavigationBarInset(
      context,
    ).clamp(0.0, availableHeight - proxyPanelMinHeight).toDouble();
    final viewportHeight = (availableHeight - bottomInset)
        .clamp(proxyPanelMinHeight, double.infinity)
        .toDouble();
    final topInset = MediaQuery.paddingOf(context).top;
    final viewportLimit = _viewportLimit(viewportHeight, topInset: topInset);
    final maxPanelHeight = _maxHeight(viewportHeight, topInset: topInset);
    return ProxyPanelMetrics(
      bottomInset: bottomInset,
      panelHeight: expanded ? maxPanelHeight : proxyPanelMinHeight,
      maxPanelHeight: maxPanelHeight,
      viewportHeight: viewportHeight,
      viewportLimit: viewportLimit,
      progress: expanded ? 1 : 0,
      backdropProgress: expanded ? 1 : 0,
      atMaxExtent: expanded,
      canFillScreen: maxPanelHeight >= viewportLimit - 0.5,
      collapseOnAnyDownwardDrag:
          maxPanelHeight < viewportLimit - 0.5 || widget.visibleRows <= 3,
      dragging: false,
      animating: false,
    );
  }

  void _publishCollapsedMetrics(ProxyPanelMetrics metrics) {
    if (_collapsedMetricsNotifier.value == metrics) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _collapsedMetricsNotifier.value != metrics) {
        _collapsedMetricsNotifier.value = metrics;
      }
    });
  }

  void _handleCollapsedDragStart(DragStartDetails details) {
    _collapsedDragStartY = details.globalPosition.dy;
    _collapsedDragDistance = 0;
    _markInteractionActive();
  }

  void _handleCollapsedDragUpdate(DragUpdateDetails details) {
    _collapsedDragDistance = details.globalPosition.dy - _collapsedDragStartY;
  }

  void _handleCollapsedDragEnd(DragEndDetails details) {
    final shouldOpen = _collapsedDragDistance <= -appBottomSheetDragThreshold;
    _collapsedDragStartY = 0;
    _collapsedDragDistance = 0;
    if (shouldOpen) {
      unawaited(_openPanel());
    } else {
      _finishInteraction();
    }
  }

  void _handleCollapsedDragCancel() {
    _collapsedDragStartY = 0;
    _collapsedDragDistance = 0;
    _finishInteraction();
  }

  void _dismissPanel() {
    if (!_panelRouteOpen) {
      _finishInteraction();
      return;
    }
    final routeContext = _panelRouteContext;
    if (routeContext == null) {
      _dismissWhenRouteReady = true;
      return;
    }
    _dismissWhenRouteReady = false;
    unawaited(Navigator.of(routeContext).maybePop());
  }

  void _notifyPanelOpened() {
    if (_openedNotified || !_panelRouteOpen) {
      return;
    }
    _openedNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_panelRouteOpen) {
        return;
      }
      _finishInteraction();
      widget.onOpened?.call();
    });
  }

  Future<void> _openPanel() async {
    if (_panelRouteOpen ||
        !mounted ||
        !widget.ready ||
        !widget.onboardingCompleted ||
        !widget.hasActiveProfile) {
      _finishInteraction();
      return;
    }

    _panelRouteOpen = true;
    _openedNotified = false;
    _dismissWhenRouteReady = false;
    _markInteractionActive();
    widget.onOpenRequested?.call();

    final routeListController = ScrollController();
    final routeMetricsNotifier = ValueNotifier<ProxyPanelMetrics>(
      _fallbackMetrics,
    );

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        enableDrag: true,
        isDismissible: true,
        useSafeArea: false,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        clipBehavior: Clip.none,
        builder: (routeContext) {
          _panelRouteContext = routeContext;
          _notifyPanelOpened();
          if (_dismissWhenRouteReady) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _panelRouteOpen) {
                _dismissPanel();
              }
            });
          }

          return ValueListenableBuilder<int>(
            valueListenable: _contentRevision,
            builder: (context, _, _) {
              final metrics = _metricsFor(
                context,
                availableHeight: MediaQuery.sizeOf(context).height,
                expanded: true,
              );
              if (routeMetricsNotifier.value != metrics) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_panelRouteOpen &&
                      routeMetricsNotifier.value != metrics) {
                    routeMetricsNotifier.value = metrics;
                  }
                });
              }
              final gestures = ProxyPanelGestures(onHeaderTap: _dismissPanel);
              return SizedBox(
                key: const ValueKey('proxy-panel-expanded'),
                height: metrics.panelHeight + metrics.bottomInset,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(proxyPanelScreenCornerRadius),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: widget.sheetBuilder(
                    context,
                    metrics,
                    routeMetricsNotifier,
                    routeListController,
                    gestures,
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      routeListController.dispose();
      routeMetricsNotifier.dispose();
      _panelRouteContext = null;
      _panelRouteOpen = false;
      _openedNotified = false;
      _dismissWhenRouteReady = false;
      _resetCollapsedListScroll();
      _finishInteraction();
      if (mounted) {
        widget.onClosed?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rootChild = !widget.ready
        ? widget.loading
        : !widget.onboardingCompleted
        ? widget.welcome
        : _buildShell(context);

    return AnimatedSwitcher(
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
    );
  }

  Widget _buildShell(BuildContext context) {
    return Scaffold(
      key: const ValueKey('shell'),
      extendBody: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final metrics = _metricsFor(
            context,
            availableHeight: availableHeight,
            expanded: false,
          );
          _publishCollapsedMetrics(metrics);

          return Stack(
            children: [
              RepaintBoundary(child: widget.homeBuilder(context, metrics)),
              if (widget.hasActiveProfile)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: proxyPanelMinHeight + metrics.bottomInset,
                  child: GestureDetector(
                    key: const ValueKey('proxy-panel-collapsed'),
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: _handleCollapsedDragStart,
                    onVerticalDragUpdate: _handleCollapsedDragUpdate,
                    onVerticalDragEnd: _handleCollapsedDragEnd,
                    onVerticalDragCancel: _handleCollapsedDragCancel,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(proxyPanelScreenCornerRadius),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: widget.sheetBuilder(
                        context,
                        metrics,
                        _collapsedMetricsNotifier,
                        _collapsedListController,
                        ProxyPanelGestures(
                          onHeaderTap: () => unawaited(_openPanel()),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
