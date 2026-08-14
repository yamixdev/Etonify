import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/data/local/app_settings_store.dart';

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
