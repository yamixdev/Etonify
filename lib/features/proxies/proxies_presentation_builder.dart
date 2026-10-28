import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/features/proxies/proxy_panel_shell.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/models/url_test_progress.dart';

@immutable
class ProxiesPresentationData {
  const ProxiesPresentationData({
    this.profileId = '',
    required this.proxies,
    required this.groupChildrenByTag,
    required this.selectedTag,
    required this.activeProxy,
    required this.hideActiveProxyIp,
    required this.connected,
    this.serverCount = 0,
    this.urlTestInFlight = false,
    this.urlTestInFlightListenable,
    this.urlTestProgressListenable,
    required this.hapticEnabled,
    required this.trafficAvailable,
    required this.downlinkBytesPerSecond,
    required this.uplinkTotalBytes,
    required this.downlinkTotalBytes,
    required this.trafficListenable,
    required this.initialSort,
    this.hideUnavailable = false,
    required this.progressiveBlurEnabled,
    required this.runtimeStates,
    this.proxyListLoading = false,
    this.catalogReady = true,
  });

  final String profileId;
  final List<AppProxySummary> proxies;
  final Map<String, List<AppProxySummary>> groupChildrenByTag;
  final String selectedTag;
  final AppProxySummary? activeProxy;
  final bool hideActiveProxyIp;
  final bool connected;
  final int serverCount;
  final bool urlTestInFlight;
  final ValueListenable<bool>? urlTestInFlightListenable;
  final ValueListenable<UrlTestProgressState>? urlTestProgressListenable;
  final bool hapticEnabled;
  final bool trafficAvailable;
  final int downlinkBytesPerSecond;
  final int uplinkTotalBytes;
  final int downlinkTotalBytes;
  final ValueListenable<TrafficUiSnapshot> trafficListenable;
  final ProxySort initialSort;
  final bool hideUnavailable;
  final bool progressiveBlurEnabled;
  final ProxyRuntimeVisualStore runtimeStates;
  final bool proxyListLoading;
  final bool catalogReady;

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
    this.changeHideUnavailable,
    required this.selectProxy,
    required this.runUrlTest,
    this.runProxyUrlTest,
    this.addProxy,
    required this.resolveVisibleProxyLocation,
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
  final ValueChanged<bool>? changeHideUnavailable;
  final ValueChanged<String> selectProxy;
  final Future<void> Function() runUrlTest;
  final Future<void> Function(String tag)? runProxyUrlTest;
  final VoidCallback? addProxy;
  final void Function(String tag, ValueGetter<bool> isVisible)
  resolveVisibleProxyLocation;
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
    ProxyPanelMetrics? panelMetrics,
    ValueListenable<ProxyPanelMetrics>? panelMetricsListenable,
    ScrollController? scrollController,
    ProxyPanelGestures? panelGestures,
    bool browserMode = false,
    bool browserActive = true,
    ({int serial, String? groupTag})? browserRequest,
    VoidCallback? onBackAtRoot,
  }) {
    return ProxiesPage(
      profileId: data.profileId,
      proxies: data.proxies,
      groupChildrenByTag: data.groupChildrenByTag,
      selectedTag: data.selectedTag,
      activeProxy: data.activeProxy,
      activeProxyHideIp: data.hideActiveProxyIp,
      connected: data.connected,
      serverCount: data.serverCount,
      urlTestInFlight: data.urlTestInFlight,
      urlTestInFlightListenable: data.urlTestInFlightListenable,
      urlTestProgressListenable: data.urlTestProgressListenable,
      hapticEnabled: data.hapticEnabled,
      speedBytesPerSecond: data.speedBytesPerSecond,
      trafficBytes: data.trafficBytes,
      trafficListenable: data.trafficListenable,
      initialSort: data.initialSort,
      hideUnavailable: data.hideUnavailable,
      onHideUnavailableChanged: callbacks.changeHideUnavailable,
      onSortChanged: callbacks.changeSort,
      progressiveBlurEnabled: data.progressiveBlurEnabled,
      onSelected: callbacks.selectProxy,
      onUrlTest: callbacks.runUrlTest,
      onProxyUrlTest: callbacks.runProxyUrlTest,
      onAddProxy: callbacks.addProxy,
      onVisibleProxyNeedsLocation: callbacks.resolveVisibleProxyLocation,
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
      catalogReady: data.catalogReady,
      embedded: !browserMode,
      browserMode: browserMode,
      browserActive: browserActive,
      browserRequest: browserRequest,
      onBackAtRoot: onBackAtRoot,
      sheetMetricsListenable: panelMetricsListenable,
      scrollController: scrollController,
      sheetAtMaxExtent: panelMetrics?.atMaxExtent ?? false,
      sheetCanFillScreen: panelMetrics?.canFillScreen ?? false,
      sheetExtent: panelMetrics?.progress ?? 0,
      collapsedSheetExtent: 0,
      expandedHeaderExtent: 1,
      sheetCornerRadius: proxyPanelScreenCornerRadius,
      onHeaderTap: panelGestures?.onHeaderTap,
    );
  }
}
