import 'package:flutter/widgets.dart';
import 'package:meow_client/features/settings/settings_page.dart';

@immutable
class SettingsPresentationCallbacks {
  const SettingsPresentationCallbacks({
    required this.openGeneral,
    required this.openDns,
    required this.openSubscriptions,
    required this.openInbound,
    required this.openRouting,
    required this.openSecurity,
    required this.importBackup,
    required this.exportSettings,
    required this.exportEncryptedProfile,
    required this.exportPlainProfile,
    required this.resetSettings,
    required this.openExperimental,
    required this.openLogs,
    required this.openAbout,
  });

  final VoidCallback openGeneral;
  final VoidCallback openDns;
  final VoidCallback openSubscriptions;
  final VoidCallback openInbound;
  final VoidCallback openRouting;
  final VoidCallback openSecurity;
  final VoidCallback importBackup;
  final VoidCallback exportSettings;
  final VoidCallback exportEncryptedProfile;
  final VoidCallback exportPlainProfile;
  final VoidCallback resetSettings;
  final VoidCallback openExperimental;
  final VoidCallback openLogs;
  final VoidCallback openAbout;
}

class SettingsPresentationBuilder {
  const SettingsPresentationBuilder({required this.callbacks});

  final SettingsPresentationCallbacks callbacks;

  SettingsPage build() {
    return SettingsPage(
      onOpenGeneral: callbacks.openGeneral,
      onOpenDns: callbacks.openDns,
      onOpenSubscriptions: callbacks.openSubscriptions,
      onOpenInbound: callbacks.openInbound,
      onOpenRouting: callbacks.openRouting,
      onOpenSecurity: callbacks.openSecurity,
      onImportBackup: callbacks.importBackup,
      onExportSettings: callbacks.exportSettings,
      onExportEncryptedProfile: callbacks.exportEncryptedProfile,
      onExportPlainProfile: callbacks.exportPlainProfile,
      onResetSettings: callbacks.resetSettings,
      onOpenExperimental: callbacks.openExperimental,
      onOpenLogs: callbacks.openLogs,
      onOpenAbout: callbacks.openAbout,
    );
  }
}
