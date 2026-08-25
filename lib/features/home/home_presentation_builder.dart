import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meow_client/features/home/home_page.dart';
import 'package:meow_client/features/home/home_presentation.dart';
import 'package:meow_client/features/proxies/proxy_panel_shell.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';

@immutable
class HomePresentationData {
  const HomePresentationData({
    required this.connected,
    required this.connecting,
    required this.resolvingProxy,
    required this.connectionStatusLabel,
    required this.activeProfile,
    required this.activeProxy,
    required this.runtimeStates,
    required this.hideServerIp,
    required this.hapticEnabled,
    required this.trafficAvailable,
    required this.downlinkBytesPerSecond,
    required this.uplinkTotalBytes,
    required this.downlinkTotalBytes,
    required this.trafficListenable,
    required this.activeProfileRefreshing,
    required this.showActiveProfileRefreshAction,
    required this.brandName,
    required this.versionLabel,
    this.prereleaseVersion = false,
  });

  final bool connected;
  final bool connecting;
  final bool resolvingProxy;
  final String connectionStatusLabel;
  final AppProfileSummary? activeProfile;
  final AppProxySummary? activeProxy;
  final ProxyRuntimeVisualStore runtimeStates;
  final bool hideServerIp;
  final bool hapticEnabled;
  final bool trafficAvailable;
  final int downlinkBytesPerSecond;
  final int uplinkTotalBytes;
  final int downlinkTotalBytes;
  final ValueListenable<TrafficUiSnapshot> trafficListenable;
  final bool activeProfileRefreshing;
  final bool showActiveProfileRefreshAction;
  final String brandName;
  final String versionLabel;
  final bool prereleaseVersion;

  HomeViewState toViewState() {
    final showTraffic = connected && trafficAvailable;
    return HomeViewState(
      connected: connected,
      connecting: connecting,
      resolvingProxy: resolvingProxy,
      connectionStatusLabel: connectionStatusLabel,
      activeProfile: activeProfile,
      activeProxy: activeProxy,
      runtimeStates: runtimeStates,
      hideServerIp: hideServerIp,
      hapticEnabled: hapticEnabled,
      speedBytesPerSecond: showTraffic ? downlinkBytesPerSecond.toDouble() : 0,
      trafficBytes: showTraffic
          ? (uplinkTotalBytes + downlinkTotalBytes).toDouble()
          : 0,
      trafficListenable: trafficListenable,
      activeProfileRefreshing: activeProfileRefreshing,
      showActiveProfileRefreshAction: showActiveProfileRefreshAction,
      brandName: brandName,
      versionLabel: versionLabel,
      prereleaseVersion: prereleaseVersion,
    );
  }
}

@immutable
class HomePresentationCallbacks {
  const HomePresentationCallbacks({
    required this.toggleConnection,
    required this.refreshLatency,
    required this.refreshActiveProxyIp,
    required this.openSubscriptions,
    required this.addSubscription,
    required this.openSettings,
    required this.openChangelog,
    required this.openTrafficDashboard,
    this.refreshActiveSubscription,
  });

  final VoidCallback toggleConnection;
  final VoidCallback refreshLatency;
  final VoidCallback refreshActiveProxyIp;
  final VoidCallback openSubscriptions;
  final VoidCallback addSubscription;
  final VoidCallback openSettings;
  final VoidCallback openChangelog;
  final VoidCallback openTrafficDashboard;
  final Future<void> Function()? refreshActiveSubscription;

  HomeViewActions toViewActions() {
    return HomeViewActions(
      toggleConnection: toggleConnection,
      refreshLatency: refreshLatency,
      refreshActiveProxyIp: refreshActiveProxyIp,
      openSubscriptions: openSubscriptions,
      addSubscription: addSubscription,
      openSettings: openSettings,
      openChangelog: openChangelog,
      openTrafficDashboard: openTrafficDashboard,
      refreshActiveSubscription: refreshActiveSubscription,
    );
  }
}

class HomePresentationBuilder {
  const HomePresentationBuilder({required this.data, required this.callbacks});

  final HomePresentationData data;
  final HomePresentationCallbacks callbacks;

  Widget build({
    required ProxyPanelMetrics panelMetrics,
    required ProxyPanelGestures panelGestures,
  }) {
    return HomePage(
      state: data.toViewState(),
      actions: callbacks.toViewActions(),
      bottomInset: panelMetrics.bottomInset + proxyPanelMinHeight + 20,
      onProxyPanelInteractionStart: panelGestures.onInteractionStart,
      onProxyPanelDragUpdate: panelGestures.onDragUpdate,
      onProxyPanelDragEnd: panelGestures.onDragEnd,
      showActiveProxyFooter: false,
    );
  }
}
