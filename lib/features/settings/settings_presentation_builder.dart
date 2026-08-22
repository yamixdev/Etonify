import 'package:flutter/widgets.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

@immutable
class SettingsPresentationData {
  const SettingsPresentationData({
    required this.localeCode,
    required this.themePreference,
  });

  final String localeCode;
  final AppThemePreference themePreference;

  String localeLabel(AppLocalizations l10n) => switch (localeCode) {
    'ru' => l10n.languageRussian,
    'en' => l10n.languageEnglish,
    _ => l10n.languageSystem,
  };

  String themeLabel(AppLocalizations l10n) => switch (themePreference) {
    AppThemePreference.light => l10n.themeLight,
    AppThemePreference.dark => l10n.themeDark,
    AppThemePreference.amoled => l10n.themeAmoled,
    AppThemePreference.system => l10n.themeSystem,
  };
}

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
  const SettingsPresentationBuilder({
    required this.data,
    required this.callbacks,
  });

  final SettingsPresentationData data;
  final SettingsPresentationCallbacks callbacks;

  SettingsPage build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsPage(
      currentLocaleLabel: data.localeLabel(l10n),
      currentThemeLabel: data.themeLabel(l10n),
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
