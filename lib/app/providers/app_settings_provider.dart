import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';

class AppSettingsSnapshot {
  const AppSettingsSnapshot({required this.controller, this.revision = 0});

  final AppSettingsController controller;
  final int revision;
}

class AppSettingsNotifier extends Notifier<AppSettingsSnapshot> {
  @override
  AppSettingsSnapshot build() {
    return AppSettingsSnapshot(
      controller: ref.read(appSettingsControllerProvider),
    );
  }

  void hydrate(
    AppSettingsState persisted, {
    bool progressiveBlurEnabledOverride = false,
  }) {
    final controller = state.controller;
    controller.applyState(
      persisted,
      progressiveBlurEnabledOverride: progressiveBlurEnabledOverride,
    );
    state = AppSettingsSnapshot(
      controller: controller,
      revision: state.revision + 1,
    );
  }

  AppSettingsChange mutate(
    AppSettingsChange Function(AppSettingsController controller) operation,
  ) {
    final controller = state.controller;
    final change = operation(controller);
    if (change.changed) {
      state = AppSettingsSnapshot(
        controller: controller,
        revision: state.revision + 1,
      );
    }
    return change;
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsSnapshot>(
      AppSettingsNotifier.new,
      name: 'appSettingsProvider',
    );

class AdBlockStatusNotifier extends Notifier<AdBlockRuleSetStatus> {
  AdBlockStatusNotifier([this._initialValue]);

  final AdBlockRuleSetStatus? _initialValue;

  @override
  AdBlockRuleSetStatus build() =>
      _initialValue ?? const AdBlockRuleSetStatus.unavailable();

  void update(AdBlockRuleSetStatus status) => state = status;
}

final adBlockStatusProvider =
    NotifierProvider<AdBlockStatusNotifier, AdBlockRuleSetStatus>(
      AdBlockStatusNotifier.new,
      name: 'adBlockStatusProvider',
    );

class RussiaRouteDataStatusNotifier extends Notifier<RussiaRouteDataStatus> {
  RussiaRouteDataStatusNotifier([this._initialValue]);

  final RussiaRouteDataStatus? _initialValue;

  @override
  RussiaRouteDataStatus build() =>
      _initialValue ?? const RussiaRouteDataStatus.unavailable();

  void update(RussiaRouteDataStatus status) => state = status;
}

final russiaRouteDataStatusProvider =
    NotifierProvider<RussiaRouteDataStatusNotifier, RussiaRouteDataStatus>(
      RussiaRouteDataStatusNotifier.new,
      name: 'russiaRouteDataStatusProvider',
    );

class InstalledAppsCacheNotifier extends Notifier<List<Map<String, dynamic>>> {
  InstalledAppsCacheNotifier([this._initialValue]);

  final List<Map<String, dynamic>>? _initialValue;

  @override
  List<Map<String, dynamic>> build() =>
      _initialValue ?? const <Map<String, dynamic>>[];

  void update(List<Map<String, dynamic>> apps) => state = apps;
}

final installedAppsCacheProvider =
    NotifierProvider<InstalledAppsCacheNotifier, List<Map<String, dynamic>>>(
      InstalledAppsCacheNotifier.new,
      name: 'installedAppsCacheProvider',
    );

