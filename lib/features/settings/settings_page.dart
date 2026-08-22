import 'package:flutter/material.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.currentLocaleLabel,
    required this.currentThemeLabel,
    required this.onOpenGeneral,
    required this.onOpenDns,
    required this.onOpenSubscriptions,
    required this.onOpenInbound,
    required this.onOpenRouting,
    required this.onOpenSecurity,
    required this.onImportBackup,
    required this.onExportSettings,
    required this.onExportEncryptedProfile,
    required this.onExportPlainProfile,
    required this.onResetSettings,
    required this.onOpenExperimental,
    required this.onOpenLogs,
    required this.onOpenAbout,
  });

  final String currentLocaleLabel;
  final String currentThemeLabel;
  final VoidCallback onOpenGeneral;
  final VoidCallback onOpenDns;
  final VoidCallback onOpenSubscriptions;
  final VoidCallback onOpenInbound;
  final VoidCallback onOpenRouting;
  final VoidCallback onOpenSecurity;
  final VoidCallback onImportBackup;
  final VoidCallback onExportSettings;
  final VoidCallback onExportEncryptedProfile;
  final VoidCallback onExportPlainProfile;
  final VoidCallback onResetSettings;
  final VoidCallback onOpenExperimental;
  final VoidCallback onOpenLogs;
  final VoidCallback onOpenAbout;

  Future<void> _confirmResetSettings(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext).settingsResetTitle),
        content: Text(AppLocalizations.of(dialogContext).settingsResetMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            key: const ValueKey('settings-reset-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.of(dialogContext).settingsResetAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onResetSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ProgressiveBlurScaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          MenuAnchor(
            menuChildren: [
              MenuItemButton(
                key: const ValueKey('settings-import'),
                onPressed: onImportBackup,
                leadingIcon: const Icon(Icons.file_open_rounded),
                child: Text(l10n.settingsMenuImport),
              ),
              SubmenuButton(
                key: const ValueKey('settings-export'),
                leadingIcon: const Icon(Icons.ios_share_rounded),
                menuChildren: [
                  MenuItemButton(
                    key: const ValueKey('settings-export-options'),
                    onPressed: onExportSettings,
                    leadingIcon: const Icon(
                      Icons.settings_backup_restore_rounded,
                    ),
                    child: Text(l10n.backupExportSettings),
                  ),
                  MenuItemButton(
                    key: const ValueKey('settings-export-encrypted-profile'),
                    onPressed: onExportEncryptedProfile,
                    leadingIcon: const Icon(Icons.lock_rounded),
                    child: Text(l10n.backupExportProfileEncrypted),
                  ),
                  MenuItemButton(
                    key: const ValueKey('settings-export-plain-profile'),
                    onPressed: onExportPlainProfile,
                    leadingIcon: const Icon(Icons.no_encryption_rounded),
                    child: Text(l10n.backupExportProfilePlain),
                  ),
                ],
                child: Text(l10n.settingsMenuExport),
              ),
              const PopupMenuDivider(),
              MenuItemButton(
                key: const ValueKey('settings-reset'),
                onPressed: () => _confirmResetSettings(context),
                leadingIcon: Icon(
                  Icons.restart_alt_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                child: Text(
                  l10n.settingsResetAction,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            builder: (context, controller, child) {
              return IconButton(
                key: const ValueKey('settings-more-menu'),
                tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                icon: const Icon(Icons.more_vert_rounded),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          settingsScreenPadding.left,
          progressiveHeaderTopPadding(context, settingsScreenPadding.top),
          settingsScreenPadding.right,
          appBottomSafePadding(context, settingsScreenPadding.bottom),
        ),
        children: [
          _SettingsEntryTile(
            icon: Icons.tune_rounded,
            title: l10n.generalSectionTitle,
            subtitle:
                '${l10n.languageSettingTitle}: $currentLocaleLabel · ${l10n.themeSettingTitle}: $currentThemeLabel',
            onTap: onOpenGeneral,
          ),
          const SizedBox(height: settingsIslandGap),
          _SettingsEntryTile(
            icon: Icons.settings_ethernet_rounded,
            title: l10n.inboundTitle,
            subtitle: '${l10n.vpnInTitle} · ${l10n.proxyInTitle}',
            onTap: onOpenInbound,
          ),
          const SizedBox(height: settingsIslandGap),
          _SettingsEntryTile(
            icon: Icons.alt_route_rounded,
            title: l10n.routingTitle,
            subtitle: l10n.routingSubtitle,
            onTap: onOpenRouting,
          ),
          const SizedBox(height: settingsIslandGap),
          _SettingsEntryTile(
            icon: Icons.dns_rounded,
            title: l10n.dnsTitle,
            subtitle: '${l10n.dnsDirectTitle} · ${l10n.dnsProxyTitle}',
            onTap: onOpenDns,
          ),
          const SizedBox(height: settingsIslandGap),
          _SettingsEntryTile(
            icon: Icons.security_rounded,
            title: l10n.securityTitle,
            subtitle: l10n.securitySubtitle,
            onTap: onOpenSecurity,
          ),
          const SizedBox(height: settingsIslandGap),
          _SettingsEntryTile(
            icon: Icons.science_rounded,
            title: l10n.experimentalTitle,
            subtitle: l10n.experimentalSubtitle,
            onTap: onOpenExperimental,
          ),
          const SizedBox(height: settingsIslandGap),
          _SettingsEntryTile(
            icon: Icons.speed_rounded,
            title: l10n.settingsProfilesChecksTitle,
            subtitle: l10n.settingsProfilesChecksSubtitle,
            onTap: onOpenSubscriptions,
          ),
          const SizedBox(height: settingsIslandGap),
          _SettingsEntryTile(
            icon: Icons.article_rounded,
            title: l10n.logsTitle,
            subtitle: l10n.logsSubtitle,
            onTap: onOpenLogs,
          ),
          const SizedBox(height: settingsIslandGap),
          _SettingsEntryTile(
            icon: Icons.info_outline_rounded,
            title: l10n.aboutSectionTitle,
            subtitle: l10n.aboutSectionSubtitle,
            onTap: onOpenAbout,
          ),
        ],
      ),
    );
  }
}

class _SettingsEntryTile extends StatelessWidget {
  const _SettingsEntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: SettingsLeadingIcon(
          icon: icon,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
