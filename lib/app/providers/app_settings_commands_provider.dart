import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';

typedef SetBlockLeaksCommand = void Function(bool value);
typedef SetAdBlockEnabledCommand = void Function(bool value);
typedef DownloadAdBlockRuleSetCommand = Future<AdBlockRuleSetStatus> Function();
typedef DeleteAdBlockRuleSetCommand = Future<AdBlockRuleSetStatus> Function();
typedef RefreshRoutingRuleDataCommand = Future<RussiaRouteDataStatus> Function();
typedef SetTrafficRulePresetCommand = void Function(TrafficRulePreset value);
typedef PrepareTrafficRuleDataCommand =
    Future<RussiaRouteDataStatus> Function(TrafficRulePreset preset);
typedef SetRussiaDnsDirectResolverCommand = void Function(String value);
typedef SetBypassLocalNetworkCommand = void Function(bool value);
typedef SetSplitRoutingModeCommand = void Function(SplitRoutingMode value);
typedef SetSplitRoutingPackagesCommand = void Function(List<String> value);
typedef PreloadInstalledAppsCommand =
    Future<List<Map<String, dynamic>>> Function();
typedef SetDnsDirectPresetCommand = void Function(String value);
typedef SetDnsDirectResolverCommand = void Function(String value);
typedef SetDnsProxyPresetCommand = void Function(String value);
typedef SetDnsProxyResolverCommand = void Function(String value);
typedef SetDnsPreferIpv6Command = void Function(bool value);
typedef SetDnsSecureOnlyCommand = void Function(bool value);
typedef SetDnsDirectThroughProxyCommand = void Function(bool value);
typedef SetExperimentalTcpFastOpenCommand = void Function(bool value);
typedef SetExperimentalTcpMultiPathCommand = void Function(bool value);
typedef SetExperimentalInterruptExistingConnectionsCommand =
    void Function(bool value);
typedef SetExperimentalUrlTestStrictToleranceCommand =
    void Function(bool value);
typedef SetExperimentalFakeIpEnabledCommand = void Function(bool value);
typedef SetTlsFragmentationModeCommand =
    void Function(TlsFragmentationMode value);
typedef SetMemoryLimitEnabledCommand =
    void Function(bool value, {bool warningDismissed});
typedef SetAllowUntrustedProxyCertificatesCommand = void Function(bool value);
typedef SetAllowUntrustedSubscriptionCertificatesCommand =
    void Function(bool value);
typedef SetSingBoxLogLevelCommand = void Function(String value);

/// UI-facing command port for mutating application settings and triggering
/// dependent runtime reconfiguration operations.
class AppSettingsCommands {
  SetBlockLeaksCommand? _setBlockLeaks;
  SetAdBlockEnabledCommand? _setAdBlockEnabled;
  DownloadAdBlockRuleSetCommand? _downloadAdBlockRuleSet;
  DeleteAdBlockRuleSetCommand? _deleteAdBlockRuleSet;
  RefreshRoutingRuleDataCommand? _refreshRoutingRuleData;
  SetTrafficRulePresetCommand? _setTrafficRulePreset;
  PrepareTrafficRuleDataCommand? _prepareTrafficRuleData;
  SetRussiaDnsDirectResolverCommand? _setRussiaDnsDirectResolver;
  SetBypassLocalNetworkCommand? _setBypassLocalNetwork;
  SetSplitRoutingModeCommand? _setSplitRoutingMode;
  SetSplitRoutingPackagesCommand? _setSplitRoutingPackages;
  PreloadInstalledAppsCommand? _preloadInstalledApps;
  SetDnsDirectPresetCommand? _setDnsDirectPreset;
  SetDnsDirectResolverCommand? _setDnsDirectResolver;
  SetDnsProxyPresetCommand? _setDnsProxyPreset;
  SetDnsProxyResolverCommand? _setDnsProxyResolver;
  SetDnsPreferIpv6Command? _setDnsPreferIpv6;
  SetDnsSecureOnlyCommand? _setDnsSecureOnly;
  SetDnsDirectThroughProxyCommand? _setDnsDirectThroughProxy;
  SetExperimentalTcpFastOpenCommand? _setExperimentalTcpFastOpen;
  SetExperimentalTcpMultiPathCommand? _setExperimentalTcpMultiPath;
  SetExperimentalInterruptExistingConnectionsCommand?
      _setExperimentalInterruptExistingConnections;
  SetExperimentalUrlTestStrictToleranceCommand?
      _setExperimentalUrlTestStrictTolerance;
  SetExperimentalFakeIpEnabledCommand? _setExperimentalFakeIpEnabled;
  SetTlsFragmentationModeCommand? _setTlsFragmentationMode;
  SetMemoryLimitEnabledCommand? _setMemoryLimitEnabled;
  SetAllowUntrustedProxyCertificatesCommand?
      _setAllowUntrustedProxyCertificates;
  SetAllowUntrustedSubscriptionCertificatesCommand?
      _setAllowUntrustedSubscriptionCertificates;
  SetSingBoxLogLevelCommand? _setSingBoxLogLevel;

  bool get isDnsBound =>
      _setDnsDirectPreset != null &&
      _setDnsDirectResolver != null &&
      _setDnsProxyPreset != null &&
      _setDnsProxyResolver != null &&
      _setDnsPreferIpv6 != null &&
      _setDnsSecureOnly != null &&
      _setDnsDirectThroughProxy != null;

  void bindDnsHandlers({
    required SetDnsDirectPresetCommand setDnsDirectPreset,
    required SetDnsDirectResolverCommand setDnsDirectResolver,
    required SetDnsProxyPresetCommand setDnsProxyPreset,
    required SetDnsProxyResolverCommand setDnsProxyResolver,
    required SetDnsPreferIpv6Command setDnsPreferIpv6,
    required SetDnsSecureOnlyCommand setDnsSecureOnly,
    required SetDnsDirectThroughProxyCommand setDnsDirectThroughProxy,
  }) {
    _setDnsDirectPreset = setDnsDirectPreset;
    _setDnsDirectResolver = setDnsDirectResolver;
    _setDnsProxyPreset = setDnsProxyPreset;
    _setDnsProxyResolver = setDnsProxyResolver;
    _setDnsPreferIpv6 = setDnsPreferIpv6;
    _setDnsSecureOnly = setDnsSecureOnly;
    _setDnsDirectThroughProxy = setDnsDirectThroughProxy;
  }

  void unbindDnsHandlers() {
    _setDnsDirectPreset = null;
    _setDnsDirectResolver = null;
    _setDnsProxyPreset = null;
    _setDnsProxyResolver = null;
    _setDnsPreferIpv6 = null;
    _setDnsSecureOnly = null;
    _setDnsDirectThroughProxy = null;
  }

  bool get isExperimentalBound =>
      _setExperimentalTcpFastOpen != null &&
      _setExperimentalTcpMultiPath != null &&
      _setExperimentalInterruptExistingConnections != null &&
      _setExperimentalUrlTestStrictTolerance != null &&
      _setExperimentalFakeIpEnabled != null &&
      _setTlsFragmentationMode != null &&
      _setMemoryLimitEnabled != null;

  void bindExperimentalHandlers({
    required SetExperimentalTcpFastOpenCommand setExperimentalTcpFastOpen,
    required SetExperimentalTcpMultiPathCommand setExperimentalTcpMultiPath,
    required SetExperimentalInterruptExistingConnectionsCommand
        setExperimentalInterruptExistingConnections,
    required SetExperimentalUrlTestStrictToleranceCommand
        setExperimentalUrlTestStrictTolerance,
    required SetExperimentalFakeIpEnabledCommand setExperimentalFakeIpEnabled,
    required SetTlsFragmentationModeCommand setTlsFragmentationMode,
    required SetMemoryLimitEnabledCommand setMemoryLimitEnabled,
  }) {
    _setExperimentalTcpFastOpen = setExperimentalTcpFastOpen;
    _setExperimentalTcpMultiPath = setExperimentalTcpMultiPath;
    _setExperimentalInterruptExistingConnections =
        setExperimentalInterruptExistingConnections;
    _setExperimentalUrlTestStrictTolerance =
        setExperimentalUrlTestStrictTolerance;
    _setExperimentalFakeIpEnabled = setExperimentalFakeIpEnabled;
    _setTlsFragmentationMode = setTlsFragmentationMode;
    _setMemoryLimitEnabled = setMemoryLimitEnabled;
  }

  void unbindExperimentalHandlers() {
    _setExperimentalTcpFastOpen = null;
    _setExperimentalTcpMultiPath = null;
    _setExperimentalInterruptExistingConnections = null;
    _setExperimentalUrlTestStrictTolerance = null;
    _setExperimentalFakeIpEnabled = null;
    _setTlsFragmentationMode = null;
    _setMemoryLimitEnabled = null;
  }

  bool get isSecurityBound =>
      _setAllowUntrustedProxyCertificates != null &&
      _setAllowUntrustedSubscriptionCertificates != null;

  void bindSecurityHandlers({
    required SetAllowUntrustedProxyCertificatesCommand
        setAllowUntrustedProxyCertificates,
    required SetAllowUntrustedSubscriptionCertificatesCommand
        setAllowUntrustedSubscriptionCertificates,
  }) {
    _setAllowUntrustedProxyCertificates = setAllowUntrustedProxyCertificates;
    _setAllowUntrustedSubscriptionCertificates =
        setAllowUntrustedSubscriptionCertificates;
  }

  void unbindSecurityHandlers() {
    _setAllowUntrustedProxyCertificates = null;
    _setAllowUntrustedSubscriptionCertificates = null;
  }

  bool get isLogsBound => _setSingBoxLogLevel != null;

  void bindLogsHandlers({
    required SetSingBoxLogLevelCommand setSingBoxLogLevel,
  }) {
    _setSingBoxLogLevel = setSingBoxLogLevel;
  }

  void unbindLogsHandlers() {
    _setSingBoxLogLevel = null;
  }

  bool get isRoutingBound =>
      _setBlockLeaks != null &&
      _setAdBlockEnabled != null &&
      _downloadAdBlockRuleSet != null &&
      _deleteAdBlockRuleSet != null &&
      _refreshRoutingRuleData != null &&
      _setTrafficRulePreset != null &&
      _prepareTrafficRuleData != null &&
      _setRussiaDnsDirectResolver != null &&
      _setBypassLocalNetwork != null &&
      _setSplitRoutingMode != null &&
      _setSplitRoutingPackages != null &&
      _preloadInstalledApps != null;

  void bindRoutingHandlers({
    required SetBlockLeaksCommand setBlockLeaks,
    required SetAdBlockEnabledCommand setAdBlockEnabled,
    required DownloadAdBlockRuleSetCommand downloadAdBlockRuleSet,
    required DeleteAdBlockRuleSetCommand deleteAdBlockRuleSet,
    required RefreshRoutingRuleDataCommand refreshRoutingRuleData,
    required SetTrafficRulePresetCommand setTrafficRulePreset,
    required PrepareTrafficRuleDataCommand prepareTrafficRuleData,
    required SetRussiaDnsDirectResolverCommand setRussiaDnsDirectResolver,
    required SetBypassLocalNetworkCommand setBypassLocalNetwork,
    required SetSplitRoutingModeCommand setSplitRoutingMode,
    required SetSplitRoutingPackagesCommand setSplitRoutingPackages,
    required PreloadInstalledAppsCommand preloadInstalledApps,
  }) {
    _setBlockLeaks = setBlockLeaks;
    _setAdBlockEnabled = setAdBlockEnabled;
    _downloadAdBlockRuleSet = downloadAdBlockRuleSet;
    _deleteAdBlockRuleSet = deleteAdBlockRuleSet;
    _refreshRoutingRuleData = refreshRoutingRuleData;
    _setTrafficRulePreset = setTrafficRulePreset;
    _prepareTrafficRuleData = prepareTrafficRuleData;
    _setRussiaDnsDirectResolver = setRussiaDnsDirectResolver;
    _setBypassLocalNetwork = setBypassLocalNetwork;
    _setSplitRoutingMode = setSplitRoutingMode;
    _setSplitRoutingPackages = setSplitRoutingPackages;
    _preloadInstalledApps = preloadInstalledApps;
  }

  void unbindRoutingHandlers() {
    _setBlockLeaks = null;
    _setAdBlockEnabled = null;
    _downloadAdBlockRuleSet = null;
    _deleteAdBlockRuleSet = null;
    _refreshRoutingRuleData = null;
    _setTrafficRulePreset = null;
    _prepareTrafficRuleData = null;
    _setRussiaDnsDirectResolver = null;
    _setBypassLocalNetwork = null;
    _setSplitRoutingMode = null;
    _setSplitRoutingPackages = null;
    _preloadInstalledApps = null;
  }

  void setBlockLeaks(bool value) => _setBlockLeaks?.call(value);

  void setAdBlockEnabled(bool value) => _setAdBlockEnabled?.call(value);

  Future<AdBlockRuleSetStatus> downloadAdBlockRuleSet() async {
    final command = _downloadAdBlockRuleSet;
    if (command == null) {
      return const AdBlockRuleSetStatus.unavailable();
    }
    return await command();
  }

  Future<AdBlockRuleSetStatus> deleteAdBlockRuleSet() async {
    final command = _deleteAdBlockRuleSet;
    if (command == null) {
      return const AdBlockRuleSetStatus.unavailable();
    }
    return await command();
  }

  Future<RussiaRouteDataStatus> refreshRoutingRuleData() async {
    final command = _refreshRoutingRuleData;
    if (command == null) {
      return const RussiaRouteDataStatus.unavailable();
    }
    return await command();
  }

  void setTrafficRulePreset(TrafficRulePreset value) =>
      _setTrafficRulePreset?.call(value);

  Future<RussiaRouteDataStatus> prepareTrafficRuleData(
    TrafficRulePreset preset,
  ) async {
    final command = _prepareTrafficRuleData;
    if (command == null) {
      return const RussiaRouteDataStatus.unavailable();
    }
    return await command(preset);
  }

  void setRussiaDnsDirectResolver(String value) =>
      _setRussiaDnsDirectResolver?.call(value);

  void setBypassLocalNetwork(bool value) => _setBypassLocalNetwork?.call(value);

  void setSplitRoutingMode(SplitRoutingMode value) =>
      _setSplitRoutingMode?.call(value);

  void setSplitRoutingPackages(List<String> value) =>
      _setSplitRoutingPackages?.call(value);

  Future<List<Map<String, dynamic>>> preloadInstalledApps() async {
    final command = _preloadInstalledApps;
    if (command == null) {
      return const <Map<String, dynamic>>[];
    }
    return await command();
  }

  void setDnsDirectPreset(String value) => _setDnsDirectPreset?.call(value);

  void setDnsDirectResolver(String value) => _setDnsDirectResolver?.call(value);

  void setDnsProxyPreset(String value) => _setDnsProxyPreset?.call(value);

  void setDnsProxyResolver(String value) => _setDnsProxyResolver?.call(value);

  void setDnsPreferIpv6(bool value) => _setDnsPreferIpv6?.call(value);

  void setDnsSecureOnly(bool value) => _setDnsSecureOnly?.call(value);

  void setDnsDirectThroughProxy(bool value) =>
      _setDnsDirectThroughProxy?.call(value);

  void setExperimentalTcpFastOpen(bool value) =>
      _setExperimentalTcpFastOpen?.call(value);

  void setExperimentalTcpMultiPath(bool value) =>
      _setExperimentalTcpMultiPath?.call(value);

  void setExperimentalInterruptExistingConnections(bool value) =>
      _setExperimentalInterruptExistingConnections?.call(value);

  void setExperimentalUrlTestStrictTolerance(bool value) =>
      _setExperimentalUrlTestStrictTolerance?.call(value);

  void setExperimentalFakeIpEnabled(bool value) =>
      _setExperimentalFakeIpEnabled?.call(value);

  void setTlsFragmentationMode(TlsFragmentationMode value) =>
      _setTlsFragmentationMode?.call(value);

  void setMemoryLimitEnabled(bool value, {bool warningDismissed = false}) =>
      _setMemoryLimitEnabled?.call(value, warningDismissed: warningDismissed);

  void setAllowUntrustedProxyCertificates(bool value) =>
      _setAllowUntrustedProxyCertificates?.call(value);

  void setAllowUntrustedSubscriptionCertificates(bool value) =>
      _setAllowUntrustedSubscriptionCertificates?.call(value);

  void setSingBoxLogLevel(String value) => _setSingBoxLogLevel?.call(value);
}

final appSettingsCommandsProvider = Provider<AppSettingsCommands>((ref) {
  final commands = AppSettingsCommands();
  ref.onDispose(() {
    commands.unbindRoutingHandlers();
    commands.unbindDnsHandlers();
    commands.unbindExperimentalHandlers();
    commands.unbindSecurityHandlers();
    commands.unbindLogsHandlers();
  });
  return commands;
}, name: 'appSettingsCommandsProvider');
