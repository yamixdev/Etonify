import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:meow_client/core/demo_utils.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/widgets/app_bottom_sheet_surface.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';
import 'package:meow_client/widgets/ip_refresh_dots.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

import 'proxy_list_ordering.dart';
import 'proxy_panel_shell.dart';

part 'proxies_page_chains.dart';
part 'proxies_page_group_sheet.dart';
part 'proxies_page_header.dart';
part 'proxies_page_share.dart';
part 'proxy_tile.dart';

const _kProxySheetHeaderHeight = 108.0;
const _kProxySheetCompactHeaderHeight = 72.0;
const _kProxyGroupSheetListTopReserve = 144.0;
const _kProxySheetRowExtent = proxyPanelRowExtent;
const _kProxyListScrollCacheExtent = ScrollCacheExtent.pixels(
  _kProxySheetRowExtent * 2,
);
const _kProxySheetHeaderCollapseDistance = 48.0;
const _kProxySheetHeaderBlurStart = 0.0;

Duration _runtimeResortInterval(int proxyCount) {
  if (proxyCount >= 2000) {
    return const Duration(milliseconds: 900);
  }
  if (proxyCount >= 500) {
    return const Duration(milliseconds: 600);
  }
  return const Duration(milliseconds: 80);
}

enum _ProxyChainAction { edit, rename, remove }

String _proxySortLabel(AppLocalizations l10n, ProxySort sort) => switch (sort) {
  ProxySort.source => l10n.sortByDefault,
  ProxySort.latency => l10n.sortByLatency,
  ProxySort.working => l10n.sortByWorking,
  ProxySort.name => l10n.sortByName,
  ProxySort.country => l10n.sortByCountry,
};

String _localizedLowestBaseLabel(AppLocalizations l10n, String tag) =>
    l10n.proxyLowestName;

String? _lowestSelectedDisplayName(AppProxySummary proxy) {
  final selected = proxy.selectedChildName?.trim() ?? '';
  if (selected.isNotEmpty) {
    return selected;
  }
  final technicalBase = lowestProxyBaseLabel(proxy.tag);
  final prefix = '$technicalBase · ';
  return proxy.displayName.startsWith(prefix)
      ? proxy.displayName.substring(prefix.length).trim()
      : null;
}

String _localizedProxyTitle(AppLocalizations l10n, AppProxySummary proxy) {
  if (!isLowestProxyTag(proxy.tag)) {
    return proxy.displayName;
  }
  final base = _localizedLowestBaseLabel(l10n, proxy.tag);
  final selected = _lowestSelectedDisplayName(proxy);
  return selected == null || selected.isEmpty ? base : '$base · $selected';
}

String _localizedProxySubtitle(AppLocalizations l10n, AppProxySummary proxy) {
  return _localizedProxyTechnicalText(l10n, proxy, proxy.protocolLabel.trim());
}

String _localizedProxyDetail(AppLocalizations l10n, AppProxySummary proxy) {
  return _localizedProxyTechnicalText(l10n, proxy, proxy.detailText.trim());
}

String _localizedProxyTechnicalText(
  AppLocalizations l10n,
  AppProxySummary proxy,
  String value,
) {
  const urlTestPrefix = 'URLTest · ';
  if (value == 'URLTest' || value == 'URLTest · auto') {
    return l10n.proxyAutomaticSelectionLabel;
  }
  if (value.startsWith(urlTestPrefix)) {
    final detail = value.substring(urlTestPrefix.length).trim();
    return detail.isEmpty
        ? l10n.proxyAutomaticSelectionLabel
        : '${l10n.proxyAutomaticSelectionLabel} · $detail';
  }
  const chainPrefix = 'Chain · ';
  if (value == 'Chain') {
    return l10n.proxyChainLabel;
  }
  if (value.startsWith(chainPrefix)) {
    return '${l10n.proxyChainLabel} · ${value.substring(chainPrefix.length)}';
  }
  if (proxy.isGroup && proxy.childCount > 0 && value.isEmpty) {
    return '${l10n.proxyAutomaticSelectionLabel} · '
        '${l10n.subscriptionServersCount(proxy.childCount)}';
  }
  return value;
}

IconData _proxySortIcon(ProxySort sort) => switch (sort) {
  ProxySort.source => FluentIcons.list_24_regular,
  ProxySort.latency => FluentIcons.timer_24_regular,
  ProxySort.working => FluentIcons.checkmark_circle_24_regular,
  ProxySort.name => FluentIcons.text_sort_ascending_24_regular,
  ProxySort.country => FluentIcons.globe_24_regular,
};

Future<void> _showProxySortPicker(
  BuildContext context, {
  required AppLocalizations l10n,
  required ProxySort current,
  required ValueChanged<ProxySort> onSelected,
}) async {
  final result = await showModalBottomSheet<ProxySort>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(l10n.sort, style: theme.textTheme.titleLarge),
              ),
              RadioGroup<ProxySort>(
                groupValue: current,
                onChanged: (value) => Navigator.of(context).pop(value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final sort in ProxySort.values)
                      RadioListTile<ProxySort>(
                        value: sort,
                        secondary: Icon(_proxySortIcon(sort)),
                        title: Text(_proxySortLabel(l10n, sort)),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (result != null && result != current) {
    onSelected(result);
  }
}

class _ProxyLatencyLabel extends StatelessWidget {
  const _ProxyLatencyLabel({
    required this.text,
    required this.color,
    required this.checking,
    required this.unavailable,
    required this.unavailableLabel,
    required this.emphasized,
    this.tooltip,
  });

  final String text;
  final Color color;
  final bool checking;
  final bool unavailable;
  final String unavailableLabel;
  final bool emphasized;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color,
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
    );
    if (checking) {
      return Center(child: ProxyLatencyDots(color: color));
    }
    final content = unavailable
        ? Icon(
            Icons.warning_amber_rounded,
            key: const ValueKey('proxy-latency-unavailable'),
            color: color,
            size: 25,
            semanticLabel: unavailableLabel,
          )
        : Text(
            text,
            key: ValueKey(text),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: content,
    );
    final message = tooltip?.trim();
    if (message == null || message.isEmpty) {
      return child;
    }
    return Tooltip(message: message, child: child);
  }
}

String? _latencyErrorTooltip(String? error) {
  final text = error?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text.length <= 180 ? text : '${text.substring(0, 177)}...';
}

class ProxyLatencyDots extends StatefulWidget {
  const ProxyLatencyDots({super.key, required this.color});

  final Color color;

  @override
  State<ProxyLatencyDots> createState() => _ProxyLatencyDotsState();
}

class _ProxyLatencyClock {
  static const _stepDuration = Duration(milliseconds: 300);

  final Set<VoidCallback> _listeners = <VoidCallback>{};
  Timer? _timer;
  int visibleCount = 1;

  void addListener(VoidCallback listener) {
    if (!_listeners.add(listener)) {
      return;
    }
    _timer ??= Timer.periodic(_stepDuration, _advance);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    if (_listeners.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _advance(Timer _) {
    visibleCount = visibleCount % 3 + 1;
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }
}

final _proxyLatencyClock = _ProxyLatencyClock();

class _ProxyLatencyDotsState extends State<ProxyLatencyDots> {
  late final VoidCallback _clockListener;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _clockListener = _onClockTick;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setActive(TickerMode.valuesOf(context).enabled);
  }

  void _setActive(bool active) {
    if (_active == active) {
      return;
    }
    _active = active;
    if (active) {
      _proxyLatencyClock.addListener(_clockListener);
    } else {
      _proxyLatencyClock.removeListener(_clockListener);
    }
  }

  void _onClockTick() {
    if (mounted && _active) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _proxyLatencyClock.removeListener(_clockListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: widget.color,
      fontWeight: FontWeight.w700,
    );
    return Text(
      '.' * _proxyLatencyClock.visibleCount,
      key: ValueKey(_proxyLatencyClock.visibleCount),
      textAlign: TextAlign.center,
      style: style,
    );
  }
}

class ProxiesPage extends StatefulWidget {
  const ProxiesPage({
    super.key,
    required this.proxies,
    required this.selectedTag,
    this.activeProxy,
    this.activeProxyHideIp = false,
    required this.connected,
    this.hapticEnabled = true,
    this.speedBytesPerSecond = 0,
    this.trafficBytes = 0,
    this.trafficListenable,
    this.initialSort = ProxySort.source,
    this.onSortChanged,
    required this.progressiveBlurEnabled,
    required this.onSelected,
    required this.onUrlTest,
    this.outboundForTag,
    this.loadProxyChainTargetSources,
    this.loadProxyChainTargetsForSource,
    this.onAddProxyChain,
    this.onChangeProxyChainDetour,
    this.onRenameProxyChain,
    this.onRemoveProxyChain,
    this.isProxyChainTag,
    this.onActiveProxyHideIpChanged,
    this.onActiveProxyIpRefresh,
    this.embedded = false,
    this.sheetMetricsListenable,
    this.scrollController,
    this.sheetAtMaxExtent = false,
    this.sheetCanFillScreen = false,
    this.sheetExtent = 0,
    this.collapsedSheetExtent = 0,
    this.expandedHeaderExtent = 1,
    this.sheetCornerRadius = 0,
    this.onHeaderTap,
    this.runtimeStates,
    this.loading = false,
    this.groupChildrenByTag = const <String, List<AppProxySummary>>{},
  });

  final List<AppProxySummary> proxies;
  final String selectedTag;
  final AppProxySummary? activeProxy;
  final bool activeProxyHideIp;
  final bool connected;
  final bool hapticEnabled;
  final double speedBytesPerSecond;
  final double trafficBytes;
  final ValueListenable<TrafficUiSnapshot>? trafficListenable;
  final ProxySort initialSort;
  final ValueChanged<ProxySort>? onSortChanged;
  final bool progressiveBlurEnabled;
  final ValueChanged<String> onSelected;
  final Future<void> Function() onUrlTest;
  final Outbound? Function(String tag)? outboundForTag;
  final Future<List<AppProfileSummary>> Function()? loadProxyChainTargetSources;
  final Future<List<AppProxySummary>> Function(String subscriptionId)?
  loadProxyChainTargetsForSource;
  final Future<void> Function(String detourTag, String targetTag)?
  onAddProxyChain;
  final Future<void> Function(String chainTag, String detourTag)?
  onChangeProxyChainDetour;
  final Future<void> Function(String chainTag, String name)? onRenameProxyChain;
  final Future<void> Function(String chainTag)? onRemoveProxyChain;
  final bool Function(String tag)? isProxyChainTag;
  final ValueChanged<bool>? onActiveProxyHideIpChanged;
  final VoidCallback? onActiveProxyIpRefresh;
  final bool embedded;
  final ValueListenable<ProxyPanelMetrics>? sheetMetricsListenable;
  final ScrollController? scrollController;
  final bool sheetAtMaxExtent;
  final bool sheetCanFillScreen;
  final double sheetExtent;
  final double collapsedSheetExtent;
  final double expandedHeaderExtent;
  final double sheetCornerRadius;
  final VoidCallback? onHeaderTap;
  final ProxyRuntimeVisualStore? runtimeStates;
  final bool loading;
  final Map<String, List<AppProxySummary>> groupChildrenByTag;

  @override
  State<ProxiesPage> createState() => _ProxiesPageState();
}

class _ProxiesPageState extends State<ProxiesPage> {
  late ProxySort _sort;
  List<AppProxySummary> _visibleItems = const [];
  Timer? _runtimeResortTimer;
  ValueListenable<ProxyPanelMetrics>? _observedSheetMetrics;
  final ValueNotifier<double> _proxySheetHeaderScrollCollapse =
      ValueNotifier<double>(0);
  bool _groupSheetOpen = false;
  List<_ProxyListEntry>? _visibleEntriesCache;
  List<AppProxySummary>? _visibleEntriesItemsCache;
  ProxySort? _visibleEntriesSortCache;
  bool _embeddedListActivated = false;
  bool? _visibleEntriesCanAddChainCache;
  bool Function(String tag)? _visibleEntriesChainPredicateCache;

  bool _isProxyChain(AppProxySummary proxy) =>
      widget.isProxyChainTag?.call(proxy.tag) ?? false;

  ProxyPanelMetrics? get _sheetMetrics => widget.sheetMetricsListenable?.value;

  bool get _effectiveSheetAtMaxExtent =>
      _sheetMetrics?.atMaxExtent ?? widget.sheetAtMaxExtent;

  @override
  void initState() {
    super.initState();
    _sort = widget.initialSort;
    widget.runtimeStates?.revision.addListener(_onRuntimeStatesChanged);
    _bindSheetMetricsListenable(widget.sheetMetricsListenable);
    _rebuildVisibleItems();
  }

  @override
  void didUpdateWidget(covariant ProxiesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtimeStates != widget.runtimeStates) {
      oldWidget.runtimeStates?.revision.removeListener(_onRuntimeStatesChanged);
      widget.runtimeStates?.revision.addListener(_onRuntimeStatesChanged);
    }
    if (oldWidget.sheetMetricsListenable != widget.sheetMetricsListenable) {
      _bindSheetMetricsListenable(widget.sheetMetricsListenable);
    } else {
      _activateEmbeddedListIfNeeded();
    }
    if (oldWidget.proxies != widget.proxies ||
        oldWidget.isProxyChainTag != widget.isProxyChainTag ||
        oldWidget.runtimeStates != widget.runtimeStates) {
      _rebuildVisibleItems();
    }
    if (oldWidget.initialSort != widget.initialSort &&
        widget.initialSort != _sort) {
      _sort = widget.initialSort;
      _rebuildVisibleItems();
    }
    if (!_effectiveSheetAtMaxExtent &&
        _proxySheetHeaderScrollCollapse.value != 0) {
      _proxySheetHeaderScrollCollapse.value = 0;
    }
  }

  @override
  void dispose() {
    _runtimeResortTimer?.cancel();
    widget.runtimeStates?.revision.removeListener(_onRuntimeStatesChanged);
    _observedSheetMetrics?.removeListener(_onSheetMetricsChanged);
    _proxySheetHeaderScrollCollapse.dispose();
    super.dispose();
  }

  void _bindSheetMetricsListenable(
    ValueListenable<ProxyPanelMetrics>? listenable,
  ) {
    _observedSheetMetrics?.removeListener(_onSheetMetricsChanged);
    _observedSheetMetrics = listenable;
    listenable?.addListener(_onSheetMetricsChanged);
    _activateEmbeddedListIfNeeded();
  }

  void _onSheetMetricsChanged() {
    final metrics = _sheetMetrics;
    final atMaxExtent = metrics?.atMaxExtent ?? widget.sheetAtMaxExtent;
    final activateList = !_embeddedListActivated && atMaxExtent;
    final deactivateList =
        _embeddedListActivated &&
        metrics != null &&
        !metrics.dragging &&
        !metrics.animating &&
        metrics.progress <= 0.001;
    final resetHeaderCollapse =
        !atMaxExtent && _proxySheetHeaderScrollCollapse.value != 0;
    if (!activateList && !deactivateList && !resetHeaderCollapse) {
      return;
    }
    if (!mounted) {
      if (activateList) {
        _embeddedListActivated = true;
        _rebuildVisibleItems();
      } else if (deactivateList) {
        _releaseEmbeddedListPresentation();
      }
      if (resetHeaderCollapse) {
        _proxySheetHeaderScrollCollapse.value = 0;
      }
      return;
    }
    if (resetHeaderCollapse) {
      _proxySheetHeaderScrollCollapse.value = 0;
    }
    if (activateList || deactivateList) {
      setState(() {
        if (activateList) {
          _embeddedListActivated = true;
          _rebuildVisibleItems();
        } else if (deactivateList) {
          _releaseEmbeddedListPresentation();
        }
      });
    }
  }

  void _activateEmbeddedListIfNeeded({bool notify = false}) {
    if (_embeddedListActivated || !_effectiveSheetAtMaxExtent) {
      return;
    }
    if (!notify || !mounted) {
      _embeddedListActivated = true;
      _rebuildVisibleItems();
      return;
    }
    setState(() {
      _embeddedListActivated = true;
      _rebuildVisibleItems();
    });
  }

  void _releaseEmbeddedListPresentation() {
    _runtimeResortTimer?.cancel();
    _runtimeResortTimer = null;
    _proxySheetHeaderScrollCollapse.value = 0;
    _embeddedListActivated = false;
    _visibleItems = const <AppProxySummary>[];
    _invalidateVisibleEntries();
  }

  void _onRuntimeStatesChanged() {
    if (!mounted ||
        (widget.embedded && !_embeddedListActivated) ||
        (_sort != ProxySort.latency && _sort != ProxySort.working)) {
      return;
    }
    if (_runtimeResortTimer?.isActive ?? false) {
      return;
    }
    final interval = _runtimeResortInterval(widget.proxies.length);
    _runtimeResortTimer = Timer(interval, () {
      if (!mounted ||
          (widget.embedded && !_embeddedListActivated) ||
          (_sort != ProxySort.latency && _sort != ProxySort.working)) {
        return;
      }
      setState(_rebuildVisibleItems);
    });
  }

  void _setSort(ProxySort value) {
    if (_sort == value) {
      return;
    }
    setState(() {
      _sort = value;
      _rebuildVisibleItems();
    });
    widget.onSortChanged?.call(value);
  }

  void _rebuildVisibleItems() {
    if (widget.embedded && !_embeddedListActivated) {
      _visibleItems = const <AppProxySummary>[];
      _invalidateVisibleEntries();
      return;
    }
    final pinnedItems = <AppProxySummary>[];
    final visibleItems = <AppProxySummary>[];
    for (final proxy in widget.proxies) {
      final parentTag = proxy.parentGroupTag;
      if (parentTag != null && parentTag.isNotEmpty) {
        continue;
      }
      if (_isPinnedHeaderProxy(proxy)) {
        pinnedItems.add(proxy);
      } else if (shouldShowProxyForSort(
        proxy,
        _sort,
        runtimeState: widget.runtimeStates?.valueFor(proxy.tag),
      )) {
        visibleItems.add(proxy);
      }
    }

    _sortItems(visibleItems);
    _visibleItems = [...pinnedItems, ...visibleItems];
    _invalidateVisibleEntries();
  }

  bool _isPinnedHeaderProxy(AppProxySummary proxy) =>
      isLowestProxyTag(proxy.tag) || _isProxyChain(proxy);

  List<_ProxyListEntry> _visibleEntries() {
    if (kDebugMode) {
      return developer.Timeline.timeSync(
        'ProxiesPage._visibleEntries',
        _visibleEntriesImpl,
        arguments: <String, Object?>{
          'visibleItems': _visibleItems.length,
          'embedded': widget.embedded,
        },
      );
    }
    return _visibleEntriesImpl();
  }

  List<_ProxyListEntry> _visibleEntriesImpl() {
    final cached = _visibleEntriesCache;
    if (cached != null &&
        identical(_visibleEntriesItemsCache, _visibleItems) &&
        _visibleEntriesSortCache == _sort &&
        _visibleEntriesCanAddChainCache == (widget.onAddProxyChain != null) &&
        _visibleEntriesChainPredicateCache == widget.isProxyChainTag) {
      return cached;
    }
    final primary = <AppProxySummary>[];
    final chains = <AppProxySummary>[];
    final rest = <AppProxySummary>[];
    for (final proxy in _visibleItems) {
      if (isLowestProxyTag(proxy.tag)) {
        primary.add(proxy);
      } else if (_isProxyChain(proxy)) {
        chains.add(proxy);
      } else {
        rest.add(proxy);
      }
    }
    int byPinnedOrder(AppProxySummary a, AppProxySummary b) =>
        pinnedProxyTagOrder(a.tag).compareTo(pinnedProxyTagOrder(b.tag));
    primary.sort(byPinnedOrder);
    final hasPinnedHeader =
        primary.isNotEmpty ||
        chains.isNotEmpty ||
        widget.onAddProxyChain != null;
    final entries = <_ProxyListEntry>[
      for (final proxy in primary) _ProxyListEntry.tile(proxy),
      for (final proxy in chains) _ProxyListEntry.tile(proxy),
      if (widget.onAddProxyChain != null) const _ProxyListEntry.addChain(),
      if (rest.isNotEmpty && hasPinnedHeader) const _ProxyListEntry.divider(),
      for (final proxy in rest) _ProxyListEntry.tile(proxy),
    ];
    _visibleEntriesCache = entries;
    _visibleEntriesItemsCache = _visibleItems;
    _visibleEntriesSortCache = _sort;
    _visibleEntriesCanAddChainCache = widget.onAddProxyChain != null;
    _visibleEntriesChainPredicateCache = widget.isProxyChainTag;
    return entries;
  }

  void _invalidateVisibleEntries() {
    _visibleEntriesCache = null;
    _visibleEntriesItemsCache = null;
    _visibleEntriesSortCache = null;
    _visibleEntriesCanAddChainCache = null;
    _visibleEntriesChainPredicateCache = null;
  }

  List<AppProxySummary> _groupChildren(AppProxySummary group) {
    if (group.childTags.isEmpty) {
      return const [];
    }
    final cachedChildren = widget.groupChildrenByTag[group.tag];
    if (cachedChildren != null) {
      final children = cachedChildren
          .where(
            (proxy) => shouldShowProxyForSort(
              proxy,
              _sort,
              runtimeState: widget.runtimeStates?.valueFor(proxy.tag),
            ),
          )
          .toList(growable: false);
      _sortItems(children, keepLowestFirst: false);
      return children;
    }
    final childByTag = <String, AppProxySummary>{
      for (final proxy in widget.proxies)
        if (proxy.parentGroupTag == group.tag) proxy.tag: proxy,
    };
    final children = group.childTags
        .map((tag) => childByTag[tag])
        .whereType<AppProxySummary>()
        .where(
          (proxy) => shouldShowProxyForSort(
            proxy,
            _sort,
            runtimeState: widget.runtimeStates?.valueFor(proxy.tag),
          ),
        )
        .toList(growable: false);
    _sortItems(children, keepLowestFirst: false);
    return children;
  }

  Future<void> _openGroupOutbounds(AppProxySummary group, Rect _) async {
    final children = _groupChildren(group);
    if (children.isEmpty) {
      return;
    }
    if (widget.hapticEnabled) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _groupSheetOpen = true;
    });
    try {
      await Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.transparent,
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          transitionDuration: const Duration(milliseconds: 440),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) =>
              _GroupOutboundsSheet(
                group: group,
                children: children,
                selectedTag: widget.selectedTag,
                progressiveBlurEnabled: widget.progressiveBlurEnabled,
                runtimeStates: widget.runtimeStates,
                routeAnimation: animation,
                onSelected: widget.onSelected,
                outboundForTag: widget.outboundForTag,
                initialSort: _sort,
                onSortChanged: (value) {
                  if (_sort != value && mounted) {
                    setState(() {
                      _sort = value;
                      _rebuildVisibleItems();
                    });
                  }
                  widget.onSortChanged?.call(value);
                },
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child;
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _groupSheetOpen = false;
        });
      }
    }
  }

  Future<void> _openProxyShareSheet(AppProxySummary proxy) async {
    if (proxy.isGroup) {
      return;
    }
    final outbound = widget.outboundForTag?.call(proxy.tag);
    if (outbound == null) {
      return;
    }
    if (widget.hapticEnabled) {
      HapticFeedback.selectionClick();
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProxyShareSheet(proxy: proxy, outbound: outbound),
    );
  }

  void _sortItems(List<AppProxySummary> items, {bool keepLowestFirst = true}) {
    sortProxySummaries(
      items,
      _sort,
      keepPinnedFirst: keepLowestFirst,
      runtimeStateFor: widget.runtimeStates?.valueFor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final theme = Theme.of(context);
    if (widget.embedded) {
      final sheetMetricsListenable = widget.sheetMetricsListenable;
      final list = _buildEmbeddedProxyList(context: context, l10n: l10n);
      if (sheetMetricsListenable != null) {
        return ValueListenableBuilder<ProxyPanelMetrics>(
          valueListenable: sheetMetricsListenable,
          child: list,
          builder: (context, metrics, list) {
            return _buildEmbeddedSheet(
              context: context,
              l10n: l10n,
              theme: theme,
              list: list!,
              sheetAtMaxExtent: metrics.atMaxExtent,
              sheetCanFillScreen: metrics.canFillScreen,
              sheetExtent: metrics.progress,
              progressiveBlurEnabled:
                  widget.progressiveBlurEnabled && !metrics.dragging,
            );
          },
        );
      }
      return _buildEmbeddedSheet(
        context: context,
        l10n: l10n,
        theme: theme,
        list: list,
      );
    }

    final topPadding = appSystemStatusBarInset(context);
    final headerHeight = topPadding + kToolbarHeight;
    final footerHeight = appBottomNavigationTotalHeight(context);
    final listTopPadding = widget.progressiveBlurEnabled
        ? headerHeight + 8
        : 6.0;
    final listBottomPadding = footerHeight + 24;
    final headerBlurHeight = appHeaderBlurTotalHeight(context);

    return Scaffold(
      extendBodyBehindAppBar: widget.progressiveBlurEnabled,
      appBar: AppBar(
        title: Text(l10n.proxiesTitle),
        backgroundColor: widget.progressiveBlurEnabled
            ? Colors.transparent
            : theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: l10n.sort,
            onPressed: () => _showProxySortPicker(
              context,
              l10n: l10n,
              current: _sort,
              onSelected: _setSort,
            ),
            icon: const Icon(FluentIcons.arrow_sort_24_regular),
          ),
        ],
      ),
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Stack(
          children: [
            AppProgressiveEdgeBlur(
              enabled: widget.progressiveBlurEnabled,
              headerHeight: headerBlurHeight,
              footerHeight: 0,
              sigma: 16,
              tintColor: theme.scaffoldBackgroundColor.withValues(
                alpha: theme.brightness == Brightness.dark ? .08 : .06,
              ),
              child: _buildProxyList(
                context: context,
                l10n: l10n,
                listTopPadding: listTopPadding,
                listBottomPadding: listBottomPadding,
              ),
            ),
            if (widget.connected)
              Positioned(
                right: 24,
                bottom: footerHeight + 24,
                child: FloatingActionButton.small(
                  onPressed: () => widget.onUrlTest(),
                  tooltip: l10n.urlTestTitle,
                  child: const Icon(FluentIcons.flash_24_filled),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedSheet({
    required BuildContext context,
    required AppLocalizations l10n,
    required ThemeData theme,
    required Widget list,
    bool? sheetAtMaxExtent,
    bool? sheetCanFillScreen,
    double? sheetExtent,
    bool? progressiveBlurEnabled,
  }) {
    final effectiveSheetAtMaxExtent =
        sheetAtMaxExtent ?? widget.sheetAtMaxExtent;
    final effectiveSheetCanFillScreen =
        sheetCanFillScreen ?? widget.sheetCanFillScreen;
    final effectiveSheetExtent = sheetExtent ?? widget.sheetExtent;
    final effectiveProgressiveBlurEnabled =
        progressiveBlurEnabled ?? widget.progressiveBlurEnabled;
    final progressRange =
        widget.expandedHeaderExtent - widget.collapsedSheetExtent;
    final headerProgress = progressRange <= 0
        ? 1.0
        : ((effectiveSheetExtent - widget.collapsedSheetExtent) / progressRange)
              .clamp(0.0, 1.0)
              .toDouble();
    final sheetBody = RepaintBoundary(
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _handleEmbeddedScrollNotification,
            child: IgnorePointer(
              ignoring: !effectiveSheetAtMaxExtent,
              child: RepaintBoundary(child: list),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _proxySheetHeaderScrollCollapse,
              builder: (context, scrollCollapse, _) {
                final effectiveScrollCollapse = effectiveSheetAtMaxExtent
                    ? scrollCollapse
                    : 0.0;
                final headerHeight = _proxySheetHeaderHeightForCollapse(
                  effectiveScrollCollapse,
                );
                return _ProxySheetHeaderBackdrop(
                  enabled:
                      effectiveProgressiveBlurEnabled &&
                      !_groupSheetOpen &&
                      headerProgress >= _kProxySheetHeaderBlurStart,
                  cornerRadius: widget.sheetCornerRadius,
                  height: headerHeight,
                  child: _ProxySheetHeader(
                    height: headerHeight,
                    progress: headerProgress,
                    scrollCollapse: effectiveScrollCollapse,
                    canFillScreen: effectiveSheetCanFillScreen,
                    activeProxy: widget.activeProxy,
                    activeProxyHideIp: widget.activeProxyHideIp,
                    l10n: l10n,
                    sort: _sort,
                    connected: widget.connected,
                    hapticEnabled: widget.hapticEnabled,
                    speedBytesPerSecond: widget.speedBytesPerSecond,
                    trafficBytes: widget.trafficBytes,
                    trafficListenable: widget.trafficListenable,
                    onSortSelected: _setSort,
                    onUrlTest: widget.onUrlTest,
                    onRefreshIp: widget.onActiveProxyIpRefresh,
                    onTap: widget.onHeaderTap,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    return Material(
      color: theme.scaffoldBackgroundColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      clipBehavior: Clip.none,
      child: sheetBody,
    );
  }

  Widget _buildEmbeddedProxyList({
    required BuildContext context,
    required AppLocalizations l10n,
  }) {
    final listMounted = _embeddedListActivated;
    // Keep the sliver geometry stable while the pinned header collapses.
    // Mutating padding during a drag forces the list to relayout and makes the
    // first rows visibly jump under the finger.
    const listTopPadding = _kProxySheetHeaderHeight + 6;
    final bottomInset = appSystemNavigationBarInset(context);
    final entries = listMounted ? _visibleEntries() : const <_ProxyListEntry>[];
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ListView.builder(
        controller: widget.scrollController,
        physics: listMounted
            ? const ClampingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              )
            : const NeverScrollableScrollPhysics(),
        itemExtent: _kProxySheetRowExtent,
        scrollCacheExtent: _kProxyListScrollCacheExtent,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        padding: listMounted
            ? EdgeInsets.only(
                top: listTopPadding,
                bottom: proxyPanelListBottomPadding,
              )
            : EdgeInsets.zero,
        itemCount: !listMounted
            ? 0
            : widget.proxies.isEmpty
            ? 1
            : entries.length,
        itemBuilder: (context, index) {
          if (widget.proxies.isEmpty) {
            return _buildEmptyOrLoadingState(context: context, l10n: l10n);
          }
          return _buildEmbeddedEntry(
            context: context,
            l10n: l10n,
            entry: entries[index],
          );
        },
      ),
    );
  }

  bool _handleEmbeddedScrollNotification(ScrollNotification notification) {
    _updateProxySheetHeaderScrollCollapse(notification.metrics);
    return false;
  }

  void _updateProxySheetHeaderScrollCollapse(ScrollMetrics metrics) {
    final nextCollapse = _effectiveSheetAtMaxExtent
        ? ((metrics.pixels - metrics.minScrollExtent) /
                  _kProxySheetHeaderCollapseDistance)
              .clamp(0.0, 1.0)
              .toDouble()
        : 0.0;
    if ((nextCollapse - _proxySheetHeaderScrollCollapse.value).abs() < 0.01) {
      return;
    }
    _proxySheetHeaderScrollCollapse.value = nextCollapse;
  }

  double _proxySheetHeaderHeightForCollapse(double collapse) {
    final t = Curves.easeOutCubic.transform(
      collapse.clamp(0.0, 1.0).toDouble(),
    );
    return lerpDouble(
      _kProxySheetHeaderHeight,
      _kProxySheetCompactHeaderHeight,
      t,
    )!;
  }

  Widget _buildProxyList({
    required BuildContext context,
    required AppLocalizations l10n,
    required double listTopPadding,
    required double listBottomPadding,
  }) {
    if (widget.proxies.isEmpty) {
      return _buildEmptyOrLoadingState(context: context, l10n: l10n);
    }
    final entries = _visibleEntries();
    return ListView.builder(
      scrollCacheExtent: _kProxyListScrollCacheExtent,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      padding: EdgeInsets.only(top: listTopPadding, bottom: listBottomPadding),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _buildEntry(context: context, l10n: l10n, entry: entries[index]);
      },
    );
  }

  Widget _buildEmptyOrLoadingState({
    required BuildContext context,
    required AppLocalizations l10n,
  }) {
    if (widget.loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }
    return Center(
      child: Text(
        l10n.noProxies,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildEntry({
    required BuildContext context,
    required AppLocalizations l10n,
    required _ProxyListEntry entry,
  }) {
    switch (entry.type) {
      case _ProxyListEntryType.tile:
        final proxy = entry.proxy!;
        Widget buildTile(ProxyRuntimeVisualState? state) => ProxyTile(
          proxy: proxy,
          runtimeState: state,
          selected: proxy.tag == widget.selectedTag,
          highlighted: proxy.highlighted,
          animate: !widget.embedded,
          onTap: () => widget.onSelected(proxy.tag),
          onLongPress: proxy.isGroup
              ? null
              : _isProxyChain(proxy)
              ? () => _openProxyChainActionSheet(proxy)
              : () => _openProxyShareSheet(proxy),
          onOpenGroup: proxy.isGroup
              ? (rect) => _openGroupOutbounds(proxy, rect)
              : null,
        );
        final runtimeStates = widget.runtimeStates;
        if (!widget.embedded || runtimeStates == null) {
          return buildTile(null);
        }
        return ValueListenableBuilder<ProxyRuntimeVisualState?>(
          valueListenable: runtimeStates.listenableFor(proxy.tag),
          builder: (context, state, _) => buildTile(state),
        );
      case _ProxyListEntryType.addChain:
        return _AddProxyChainTile(onTap: _openAddProxyChainSheet);
      case _ProxyListEntryType.divider:
        return const _ProxyListDivider();
    }
  }

  Widget _buildEmbeddedEntry({
    required BuildContext context,
    required AppLocalizations l10n,
    required _ProxyListEntry entry,
  }) {
    return _buildEntry(context: context, l10n: l10n, entry: entry);
  }

  Future<void> _openAddProxyChainSheet() async {
    final callback = widget.onAddProxyChain;
    if (callback == null) {
      return;
    }
    final localTargets = widget.proxies
        .where(
          (proxy) =>
              !proxy.isGroup &&
              !_isProxyChain(proxy) &&
              !isSyntheticProxyTag(proxy.tag),
        )
        .toList(growable: false);
    final sources = await widget.loadProxyChainTargetSources?.call();
    if (!mounted) {
      return;
    }
    final detours = widget.proxies
        .where((proxy) => !_isProxyChain(proxy))
        .toList(growable: false);
    if (sources == null ||
        sources.isEmpty ||
        widget.loadProxyChainTargetsForSource == null) {
      if (localTargets.isEmpty) {
        return;
      }
      final selection = await showModalBottomSheet<_ProxyChainSelection>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _AddProxyChainSheet.staticTargets(
          detours: detours,
          targets: localTargets,
        ),
      );
      if (selection != null) {
        await callback(selection.detourTag, selection.targetTag);
      }
      return;
    }
    final selection = await showModalBottomSheet<_ProxyChainSelection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AddProxyChainSheet(
        detours: detours,
        sources: sources,
        loadTargetsForSource: widget.loadProxyChainTargetsForSource!,
      ),
    );
    if (selection == null) {
      return;
    }
    await callback(selection.detourTag, selection.targetTag);
  }

  Future<void> _openProxyChainActionSheet(AppProxySummary proxy) async {
    if (widget.onRemoveProxyChain == null &&
        widget.onChangeProxyChainDetour == null &&
        widget.onRenameProxyChain == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<_ProxyChainAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_localizedProxyTitle(l10n, proxy)),
              subtitle: Text(_localizedProxyDetail(l10n, proxy)),
            ),
            if (widget.onChangeProxyChainDetour != null)
              ListTile(
                leading: const Icon(FluentIcons.arrow_routing_24_regular),
                title: Text(l10n.proxyChainChangeFirstHop),
                onTap: () => Navigator.of(context).pop(_ProxyChainAction.edit),
              ),
            if (widget.onRenameProxyChain != null)
              ListTile(
                leading: const Icon(FluentIcons.edit_24_regular),
                title: Text(l10n.proxyChainRenameAction),
                onTap: () =>
                    Navigator.of(context).pop(_ProxyChainAction.rename),
              ),
            ListTile(
              leading: const Icon(FluentIcons.delete_24_regular),
              title: Text(l10n.proxyChainRemoveAction),
              onTap: () => Navigator.of(context).pop(_ProxyChainAction.remove),
            ),
          ],
        ),
      ),
    );
    if (action == _ProxyChainAction.remove) {
      await widget.onRemoveProxyChain?.call(proxy.tag);
    } else if (action == _ProxyChainAction.edit) {
      await _openChangeProxyChainDetourSheet(proxy);
    } else if (action == _ProxyChainAction.rename) {
      await _openRenameProxyChainSheet(proxy);
    }
  }

  Future<void> _openRenameProxyChainSheet(AppProxySummary proxy) async {
    final callback = widget.onRenameProxyChain;
    if (callback == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: proxy.displayName);
    final name = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.proxyChainRenameTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l10n.proxyChainNameLabel),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.proxyChainSaveAction),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) {
      return;
    }
    await callback(proxy.tag, name);
  }

  Future<void> _openChangeProxyChainDetourSheet(AppProxySummary proxy) async {
    final callback = widget.onChangeProxyChainDetour;
    if (callback == null) {
      return;
    }
    final detours = widget.proxies
        .where((candidate) => !_isProxyChain(candidate))
        .toList(growable: false);
    if (detours.isEmpty) {
      return;
    }
    final detourTag = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ChangeProxyChainDetourSheet(detours: detours),
    );
    if (detourTag == null || detourTag.trim().isEmpty) {
      return;
    }
    await callback(proxy.tag, detourTag);
  }
}
