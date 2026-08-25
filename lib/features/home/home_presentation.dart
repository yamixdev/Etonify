import 'package:flutter/foundation.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';

@immutable
class HomeViewState {
  const HomeViewState({
    required this.connected,
    required this.connecting,
    required this.resolvingProxy,
    required this.connectionStatusLabel,
    required this.activeProfile,
    required this.activeProxy,
    required this.hideServerIp,
    required this.hapticEnabled,
    required this.speedBytesPerSecond,
    required this.trafficBytes,
    required this.brandName,
    required this.versionLabel,
    this.prereleaseVersion = false,
    this.runtimeStates,
    this.trafficListenable,
    this.activeProfileRefreshing = false,
    this.showActiveProfileRefreshAction = false,
  });

  final bool connected;
  final bool connecting;
  final bool resolvingProxy;
  final String connectionStatusLabel;
  final AppProfileSummary? activeProfile;
  final AppProxySummary? activeProxy;
  final ProxyRuntimeVisualStore? runtimeStates;
  final bool hideServerIp;
  final bool hapticEnabled;
  final double speedBytesPerSecond;
  final double trafficBytes;
  final ValueListenable<TrafficUiSnapshot>? trafficListenable;
  final bool activeProfileRefreshing;
  final bool showActiveProfileRefreshAction;
  final String brandName;
  final String versionLabel;
  final bool prereleaseVersion;
}

@immutable
class HomeViewActions {
  const HomeViewActions({
    required this.toggleConnection,
    required this.refreshLatency,
    required this.openSubscriptions,
    required this.addSubscription,
    required this.openSettings,
    required this.openChangelog,
    this.openTrafficDashboard,
    this.refreshActiveProxyIp,
    this.refreshActiveSubscription,
  });

  final VoidCallback toggleConnection;
  final VoidCallback refreshLatency;
  final VoidCallback openSubscriptions;
  final VoidCallback addSubscription;
  final VoidCallback openSettings;
  final VoidCallback openChangelog;
  final VoidCallback? openTrafficDashboard;
  final VoidCallback? refreshActiveProxyIp;
  final Future<void> Function()? refreshActiveSubscription;
}
