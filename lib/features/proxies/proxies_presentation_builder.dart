import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/features/proxies/proxy_panel_shell.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';
import 'package:meow_client/models/subscription.dart';

@immutable
class ProxiesPresentationData {
  const ProxiesPresentationData({
    required this.proxies,
    required this.groupChildrenByTag,
    required this.selectedTag,
    required this.activeProxy,
    required this.hideActiveProxyIp,
    required this.connected,
    required this.hapticEnabled,
    required this.trafficAvailable,
    required this.downlinkBytesPerSecond,
    required this.uplinkTotalBytes,
    required this.downlinkTotalBytes,
    required this.trafficListenable,
    required this.initialSort,
    required this.progressiveBlurEnabled,
    required this.runtimeStates,
    this.proxyListLoading = false,
  });

  final List<AppProxySummary> proxies;
  final Map<String, List<AppProxySummary>> groupChildrenByTag;
  final String selectedTag;
  final AppProxySummary? activeProxy;
  final bool hideActiveProxyIp;
  final bool connected;
  final bool hapticEnabled;
  final bool trafficAvailable;
  final int downlinkBytesPerSecond;
  final int uplinkTotalBytes;
  final int downlinkTotalBytes;
  final ValueListenable<TrafficUiSnapshot> trafficListenable;
  final ProxySort initialSort;
  final bool progressiveBlurEnabled;
  final ProxyRuntimeVisualStore runtimeStates;
  final bool proxyListLoading;

  double get speedBytesPerSecond =>
      connected && trafficAvailable ? downlinkBytesPerSecond.toDouble() : 0;

  double get trafficBytes => connected && trafficAvailable
      ? (uplinkTotalBytes + downlinkTotalBytes).toDouble()
      : 0;
}

@immutable
class ProxiesPresentationCallbacks {
  const ProxiesPresentationCallbacks({
    required this.changeSort,
    required this.selectProxy,
    required this.runUrlTest,
    required this.refreshActiveProxyIp,
    required this.outboundForTag,
    required this.loadProxyChainTargetSources,
    required this.loadProxyChainTargetsForSource,
    required this.addProxyChain,
    required this.changeProxyChainDetour,
    required this.renameProxyChain,
    required this.removeProxyChain,
    required this.isProxyChainTag,
    required this.changeHideActiveProxyIp,
  });

  final ValueChanged<ProxySort> changeSort;
  final ValueChanged<String> selectProxy;
  final Future<void> Function() runUrlTest;
  final VoidCallback refreshActiveProxyIp;
  final Outbound? Function(String tag) outboundForTag;
  final Future<List<AppProfileSummary>> Function() loadProxyChainTargetSources;
  final Future<List<AppProxySummary>> Function(String subscriptionId)
  loadProxyChainTargetsForSource;
  final Future<void> Function(String detourTag, String targetTag) addProxyChain;
  final Future<void> Function(String chainTag, String detourTag)
  changeProxyChainDetour;
  final Future<void> Function(String chainTag, String name) renameProxyChain;
  final Future<void> Function(String chainTag) removeProxyChain;
  final bool Function(String tag) isProxyChainTag;
  final ValueChanged<bool> changeHideActiveProxyIp;
}

class ProxiesPresentationBuilder {
  const ProxiesPresentationBuilder({
    required this.data,
    required this.callbacks,
  });

  final ProxiesPresentationData data;
  final ProxiesPresentationCallbacks callbacks;

  Widget build({
    required ProxyPanelMetrics panelMetrics,
    required ValueListenable<ProxyPanelMetrics> panelMetricsListenable,
    required ScrollController scrollController,
    required ProxyPanelGestures panelGestures,
  }) {
    return ProxiesPage(
      proxies: data.proxies,
      groupChildrenByTag: data.groupChildrenByTag,
      selectedTag: data.selectedTag,
      activeProxy: data.activeProxy,
      activeProxyHideIp: data.hideActiveProxyIp,
      connected: data.connected,
      hapticEnabled: data.hapticEnabled,
      speedBytesPerSecond: data.speedBytesPerSecond,
      trafficBytes: data.trafficBytes,
      trafficListenable: data.trafficListenable,
      initialSort: data.initialSort,
      onSortChanged: callbacks.changeSort,
      progressiveBlurEnabled: data.progressiveBlurEnabled,
      onSelected: callbacks.selectProxy,
      onUrlTest: callbacks.runUrlTest,
      onActiveProxyIpRefresh: callbacks.refreshActiveProxyIp,
      outboundForTag: callbacks.outboundForTag,
      loadProxyChainTargetSources: callbacks.loadProxyChainTargetSources,
      loadProxyChainTargetsForSource: callbacks.loadProxyChainTargetsForSource,
      onAddProxyChain: callbacks.addProxyChain,
      onChangeProxyChainDetour: callbacks.changeProxyChainDetour,
      onRenameProxyChain: callbacks.renameProxyChain,
      onRemoveProxyChain: callbacks.removeProxyChain,
      isProxyChainTag: callbacks.isProxyChainTag,
      onActiveProxyHideIpChanged: callbacks.changeHideActiveProxyIp,
      runtimeStates: data.runtimeStates,
      loading: data.proxyListLoading,
      embedded: true,
      sheetMetricsListenable: panelMetricsListenable,
      scrollController: scrollController,
      sheetAtMaxExtent: panelMetrics.atMaxExtent,
      sheetCanFillScreen: panelMetrics.canFillScreen,
      sheetExtent: panelMetrics.progress,
      collapsedSheetExtent: 0,
      expandedHeaderExtent: 1,
      sheetCornerRadius: proxyPanelScreenCornerRadius,
      onHeaderTap: panelGestures.onHeaderTap,
    );
  }
}
