import 'package:material_ui/material_ui.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/backup/etonify_backup_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_backup_export_actions.dart';
import 'package:meow_client/features/settings/settings_backup_import_actions.dart';
import 'package:meow_client/models/subscription.dart';

enum SettingsBackupAction {
  importFile,
  exportSettings,
  exportEncryptedProfile,
  exportPlainProfile,
}

/// Dispatches settings menu actions to isolated import and export workflows.
class SettingsBackupActions {
  const SettingsBackupActions({
    required this.store,
    required this.settingsState,
    required this.clientVersion,
    required this.loadSubscriptions,
    required this.onImportSettings,
    required this.onImportSubscriptions,
  });

  final AppSettingsStore store;
  final AppSettingsState settingsState;
  final String clientVersion;
  final Future<List<Subscription>> Function() loadSubscriptions;
  final Future<void> Function(AppSettingsState state) onImportSettings;
  final Future<void> Function(List<Subscription> subscriptions)
  onImportSubscriptions;

  Future<void> run(BuildContext context, SettingsBackupAction action) async {
    try {
      switch (action) {
        case SettingsBackupAction.importFile:
          await SettingsBackupImportActions(
            store: store,
            settingsState: settingsState,
            clientVersion: clientVersion,
            onImportSettings: onImportSettings,
            onImportSubscriptions: onImportSubscriptions,
          ).importFile(context);
          return;
        case SettingsBackupAction.exportSettings:
          await _exportActions.exportSettings(context);
          return;
        case SettingsBackupAction.exportEncryptedProfile:
          await _exportActions.exportEncryptedProfile(context);
          return;
        case SettingsBackupAction.exportPlainProfile:
          await _exportActions.exportPlainProfile(context);
          return;
      }
    } on EtonifyBackupException catch (error) {
      if (!context.mounted) return;
      AppNotice.show(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      AppNotice.show(context, error.toString());
    }
  }

  SettingsBackupExportActions get _exportActions => SettingsBackupExportActions(
    store: store,
    settingsState: settingsState,
    clientVersion: clientVersion,
    loadSubscriptions: loadSubscriptions,
  );
}
