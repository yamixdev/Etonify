import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsSecurityPage extends ConsumerWidget {
  const SettingsSecurityPage({super.key});

  Future<bool> _confirmRisk({
    required BuildContext context,
    required String title,
    required String message,
    required Key confirmKey,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                key: confirmKey,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  AppLocalizations.of(dialogContext).securityAllowAction,
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _setProxyCertificates(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    if (value) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await _confirmRisk(
        context: context,
        title: l10n.securityConfirmProxyTitle,
        message: l10n.securityConfirmProxyMessage,
        confirmKey: const ValueKey('security-confirm-proxy'),
      );
      if (!confirmed || !context.mounted) return;
    }
    ref
        .read(appSettingsCommandsProvider)
        .setAllowUntrustedProxyCertificates(value);
  }

  Future<void> _setSubscriptionCertificates(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    if (value) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await _confirmRisk(
        context: context,
        title: l10n.securityConfirmSubscriptionTitle,
        message: l10n.securityConfirmSubscriptionMessage,
        confirmKey: const ValueKey('security-confirm-subscription'),
      );
      if (!confirmed || !context.mounted) return;
    }
    ref
        .read(appSettingsCommandsProvider)
        .setAllowUntrustedSubscriptionCertificates(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(appSettingsProvider).controller;

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.securityTitle)),
      body: Theme(
        data: settingsTileTheme(context),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            settingsScreenPadding.left,
            progressiveHeaderTopPadding(context, settingsScreenPadding.top),
            settingsScreenPadding.right,
            appBottomSafePadding(context, settingsScreenPadding.bottom),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                l10n.securityTlsSectionTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    key: const ValueKey(
                      'security-untrusted-proxy-certificates',
                    ),
                    secondary: SettingsLeadingIcon(
                      icon: Icons.shield_outlined,
                      color: colorScheme.error,
                    ),
                    title: Text(l10n.securityUntrustedProxyCertificatesTitle),
                    value: settings.allowUntrustedProxyCertificates,
                    onChanged:
                        (value) => _setProxyCertificates(context, ref, value),
                  ),
                  SwitchListTile(
                    key: const ValueKey(
                      'security-untrusted-subscription-certificates',
                    ),
                    secondary: SettingsLeadingIcon(
                      icon: Icons.cloud_download_outlined,
                      color: colorScheme.error,
                    ),
                    title: Text(
                      l10n.securityUntrustedSubscriptionCertificatesTitle,
                    ),
                    value: settings.allowUntrustedSubscriptionCertificates,
                    onChanged:
                        (value) =>
                            _setSubscriptionCertificates(context, ref, value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
