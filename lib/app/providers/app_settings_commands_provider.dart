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
}

final appSettingsCommandsProvider = Provider<AppSettingsCommands>((ref) {
  final commands = AppSettingsCommands();
  ref.onDispose(commands.unbindRoutingHandlers);
  return commands;
}, name: 'appSettingsCommandsProvider');
