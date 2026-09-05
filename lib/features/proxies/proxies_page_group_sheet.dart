part of 'proxies_page.dart';

class _GroupOutboundsSheet extends StatelessWidget {
  const _GroupOutboundsSheet({
    required this.group,
    required this.children,
    required this.selectedTag,
    required this.progressiveBlurEnabled,
    this.runtimeStates,
    required this.routeAnimation,
    required this.onSelected,
    this.outboundForTag,
    required this.initialSort,
    this.onSortChanged,
  });

  final AppProxySummary group;
  final List<AppProxySummary> children;
  final String selectedTag;
  final bool progressiveBlurEnabled;
  final ProxyRuntimeVisualStore? runtimeStates;
  final Animation<double> routeAnimation;
  final ValueChanged<String> onSelected;
  final Outbound? Function(String tag)? outboundForTag;
  final ProxySort initialSort;
  final ValueChanged<ProxySort>? onSortChanged;

  @override
  Widget build(BuildContext context) {
    return _GroupOutboundsSheetBody(
      group: group,
      children: children,
      selectedTag: selectedTag,
      progressiveBlurEnabled: progressiveBlurEnabled,
      runtimeStates: runtimeStates,
      routeAnimation: routeAnimation,
      onSelected: onSelected,
      outboundForTag: outboundForTag,
      initialSort: initialSort,
      onSortChanged: onSortChanged,
    );
  }
}

class _GroupOutboundsSheetBody extends StatefulWidget {
  const _GroupOutboundsSheetBody({
    required this.group,
    required this.children,
    required this.selectedTag,
    required this.progressiveBlurEnabled,
    this.runtimeStates,
    required this.routeAnimation,
    required this.onSelected,
    this.outboundForTag,
    required this.initialSort,
    this.onSortChanged,
  });

  final AppProxySummary group;
  final List<AppProxySummary> children;
  final String selectedTag;
  final bool progressiveBlurEnabled;
  final ProxyRuntimeVisualStore? runtimeStates;
  final Animation<double> routeAnimation;
  final ValueChanged<String> onSelected;
  final Outbound? Function(String tag)? outboundForTag;
  final ProxySort initialSort;
  final ValueChanged<ProxySort>? onSortChanged;

  @override
  State<_GroupOutboundsSheetBody> createState() =>
      _GroupOutboundsSheetBodyState();
}

class _GroupOutboundsSheetBodyState extends State<_GroupOutboundsSheetBody> {
  late ProxySort _sort;
  late String _selectedTag;
  Timer? _runtimeResortTimer;
  List<AppProxySummary>? _sortedChildrenCache;
  ProxySort? _sortedChildrenSort;

  @override
  void initState() {
    super.initState();
    _sort = widget.initialSort;
    _selectedTag = widget.selectedTag;
    widget.runtimeStates?.revision.addListener(_onRuntimeStatesChanged);
  }

  @override
  void didUpdateWidget(covariant _GroupOutboundsSheetBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtimeStates != widget.runtimeStates) {
      oldWidget.runtimeStates?.revision.removeListener(_onRuntimeStatesChanged);
      widget.runtimeStates?.revision.addListener(_onRuntimeStatesChanged);
    }
    if (oldWidget.children != widget.children) {
      _sortedChildrenCache = null;
      _sortedChildrenSort = null;
    }
    if (oldWidget.selectedTag != widget.selectedTag) {
      _selectedTag = widget.selectedTag;
    }
  }

  @override
  void dispose() {
    _runtimeResortTimer?.cancel();
    widget.runtimeStates?.revision.removeListener(_onRuntimeStatesChanged);
    super.dispose();
  }

  void _onRuntimeStatesChanged() {
    if (!mounted ||
        (_sort != ProxySort.latency && _sort != ProxySort.working)) {
      return;
    }
    if (_runtimeResortTimer?.isActive ?? false) {
      return;
    }
    _runtimeResortTimer = Timer(
      _runtimeResortInterval(widget.children.length),
      () {
        if (!mounted ||
            (_sort != ProxySort.latency && _sort != ProxySort.working)) {
          return;
        }
        setState(() {
          _sortedChildrenCache = null;
          _sortedChildrenSort = null;
        });
      },
    );
  }

  void _setSort(ProxySort value) {
    if (_sort == value) {
      return;
    }
    setState(() {
      _sort = value;
      _sortedChildrenCache = null;
      _sortedChildrenSort = null;
    });
    widget.onSortChanged?.call(value);
  }

  List<AppProxySummary> _sortedChildren() {
    final cached = _sortedChildrenCache;
    if (cached != null && _sortedChildrenSort == _sort) {
      return cached;
    }
    final children = widget.children
        .where(
          (proxy) => shouldShowProxyForSort(
            proxy,
            _sort,
            runtimeState: widget.runtimeStates?.valueFor(proxy.tag),
          ),
        )
        .toList(growable: false);
    sortProxySummaries(
      children,
      _sort,
      keepPinnedFirst: false,
      runtimeStateFor: widget.runtimeStates?.valueFor,
    );
    _sortedChildrenCache = children;
    _sortedChildrenSort = _sort;
    return children;
  }

  void _select(String tag) {
    setState(() {
      _selectedTag = tag;
    });
    widget.onSelected(tag);
  }

  Future<void> _openProxyShareSheet(AppProxySummary proxy) async {
    if (proxy.isGroup) {
      return;
    }
    final outbound = widget.outboundForTag?.call(proxy.tag);
    if (outbound == null) {
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProxyShareSheet(proxy: proxy, outbound: outbound),
    );
  }

  Widget _runtimeTile({
    required AppProxySummary proxy,
    required bool selected,
    required bool highlighted,
    String? titleOverride,
    String? subtitleOverride,
    bool showGroupHandle = false,
    VoidCallback? onLongPress,
    required VoidCallback onTap,
  }) {
    Widget buildTile(ProxyRuntimeVisualState? state) {
      return ProxyTile(
        proxy: proxy,
        runtimeState: state,
        selected: selected,
        highlighted: highlighted,
        titleOverride: titleOverride,
        subtitleOverride: subtitleOverride,
        forceBaseInset: true,
        showGroupHandle: showGroupHandle,
        animate: false,
        onTap: onTap,
        onLongPress: onLongPress,
      );
    }

    final runtimeStates = widget.runtimeStates;
    if (runtimeStates == null) {
      return buildTile(null);
    }
    return ValueListenableBuilder<ProxyRuntimeVisualState?>(
      valueListenable: runtimeStates.listenableFor(proxy.tag),
      builder: (context, state, _) => buildTile(state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = appSystemNavigationBarInset(context);
    final activeChildTag = widget.group.selectedChildTag;
    final children = _sortedChildren();
    AppProxySummary? activeChild;
    for (final proxy in children) {
      if (proxy.tag == activeChildTag) {
        activeChild = proxy;
        break;
      }
    }

    final groupBaseTitle = isLowestProxyTag(widget.group.tag)
        ? _localizedLowestBaseLabel(l10n, widget.group.tag)
        : widget.group.displayName;
    final groupTitle = activeChild == null
        ? groupBaseTitle
        : '$groupBaseTitle · ${_localizedProxyTitle(l10n, activeChild)}';
    final groupSubtitle = activeChild == null
        ? l10n.proxyAutomaticSelectionLabel
        : '${l10n.proxyAutomaticSelectionLabel} · '
              '${_localizedProxySubtitle(l10n, activeChild)}';

    final viewportSize = MediaQuery.sizeOf(context);
    final topReserve = (appSystemStatusBarInset(context) + 8)
        .clamp(0.0, max(0.0, viewportSize.height - _kProxySheetHeaderHeight))
        .toDouble();
    final panelRect = Rect.fromLTWH(
      0,
      topReserve,
      viewportSize.width,
      viewportSize.height - topReserve,
    );
    final sheetBody = RepaintBoundary(
      child: SizedBox(
        width: panelRect.width,
        height: panelRect.height,
        child: ColoredBox(
          key: const ValueKey('proxy-group-sheet-surface'),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            children: [
              ListView.builder(
                physics: const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemExtent: _kProxySheetRowExtent,
                scrollCacheExtent: _kProxyListScrollCacheExtent,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                addSemanticIndexes: false,
                padding: EdgeInsets.only(
                  top: _kProxyGroupSheetListTopReserve,
                  bottom: bottomInset + 18,
                ),
                itemCount: children.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _runtimeTile(
                      proxy: widget.group,
                      selected: widget.group.tag == _selectedTag,
                      highlighted: false,
                      titleOverride: groupTitle,
                      subtitleOverride: groupSubtitle,
                      showGroupHandle: true,
                      onTap: () => _select(widget.group.tag),
                    );
                  }
                  final proxy = children[index - 1];
                  return _runtimeTile(
                    proxy: proxy,
                    selected: proxy.tag == _selectedTag,
                    highlighted:
                        proxy.tag == activeChildTag || proxy.highlighted,
                    onTap: () => _select(proxy.tag),
                    onLongPress: () => _openProxyShareSheet(proxy),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: AnimatedBuilder(
                  animation: widget.routeAnimation,
                  builder: (context, child) => _ProxySheetHeaderBackdrop(
                    enabled:
                        widget.progressiveBlurEnabled &&
                        widget.routeAnimation.value >= 0.985,
                    cornerRadius: 28,
                    height: _kProxySheetHeaderHeight,
                    child: child!,
                  ),
                  child: _GroupOutboundsSheetHeader(
                    title: l10n.proxySelectorTitle,
                    l10n: l10n,
                    sort: _sort,
                    onSortSelected: _setSort,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: widget.routeAnimation,
        builder: (context, _) {
          final raw = widget.routeAnimation.value.clamp(0.0, 1.0).toDouble();
          final progress = Curves.easeOutCubic.transform(raw);
          final scrimProgress = Curves.easeInOutCubic.transform(raw);
          final animatedRect = panelRect.shift(
            Offset(0, panelRect.height * (1 - progress)),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(context).pop(),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.32 * scrimProgress),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned.fromRect(
                rect: animatedRect,
                child: IgnorePointer(
                  ignoring: raw < 0.6,
                  child: ClipRRect(
                    clipBehavior: Clip.hardEdge,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: sheetBody,
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

class _GroupOutboundsSheetHeader extends StatelessWidget {
  const _GroupOutboundsSheetHeader({
    required this.title,
    required this.l10n,
    required this.sort,
    required this.onSortSelected,
    required this.onClose,
  });

  final String title;
  final AppLocalizations l10n;
  final ProxySort sort;
  final ValueChanged<ProxySort> onSortSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: _kProxySheetHeaderHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: .34,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 18,
            bottom: 0,
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 18,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onClose,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(FluentIcons.chevron_left_24_regular),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 18,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: l10n.sort,
                onPressed: () => _showProxySortPicker(
                  context,
                  l10n: l10n,
                  current: sort,
                  onSelected: onSortSelected,
                ),
                icon: const Icon(FluentIcons.arrow_sort_24_regular),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
