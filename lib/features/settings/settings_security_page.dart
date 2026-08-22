import 'package:flutter/material.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsSecurityPage extends StatefulWidget {
  const SettingsSecurityPage({
    super.key,
    required this.allowUntrustedProxyCertificates,
    required this.allowUntrustedSubscriptionCertificates,
    required this.onAllowUntrustedProxyCertificatesChanged,
    required this.onAllowUntrustedSubscriptionCertificatesChanged,
  });

  final bool allowUntrustedProxyCertificates;
  final bool allowUntrustedSubscriptionCertificates;
  final ValueChanged<bool> onAllowUntrustedProxyCertificatesChanged;
  final ValueChanged<bool> onAllowUntrustedSubscriptionCertificatesChanged;

  @override
  State<SettingsSecurityPage> createState() => _SettingsSecurityPageState();
}

class _SettingsSecurityPageState extends State<SettingsSecurityPage> {
  late bool _allowUntrustedProxyCertificates;
  late bool _allowUntrustedSubscriptionCertificates;

  @override
  void initState() {
    super.initState();
    _allowUntrustedProxyCertificates = widget.allowUntrustedProxyCertificates;
    _allowUntrustedSubscriptionCertificates =
        widget.allowUntrustedSubscriptionCertificates;
  }

  Future<bool> _confirmRisk({
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

  Future<void> _setProxyCertificates(bool value) async {
    if (value) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await _confirmRisk(
        title: l10n.securityConfirmProxyTitle,
        message: l10n.securityConfirmProxyMessage,
        confirmKey: const ValueKey('security-confirm-proxy'),
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _allowUntrustedProxyCertificates = value);
    widget.onAllowUntrustedProxyCertificatesChanged(value);
  }

  Future<void> _setSubscriptionCertificates(bool value) async {
    if (value) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await _confirmRisk(
        title: l10n.securityConfirmSubscriptionTitle,
        message: l10n.securityConfirmSubscriptionMessage,
        confirmKey: const ValueKey('security-confirm-subscription'),
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _allowUntrustedSubscriptionCertificates = value);
    widget.onAllowUntrustedSubscriptionCertificatesChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

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
                    subtitle: Text(
                      l10n.securityUntrustedProxyCertificatesSubtitle,
                    ),
                    value: _allowUntrustedProxyCertificates,
                    onChanged: _setProxyCertificates,
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
                    subtitle: Text(
                      l10n.securityUntrustedSubscriptionCertificatesSubtitle,
                    ),
                    value: _allowUntrustedSubscriptionCertificates,
                    onChanged: _setSubscriptionCertificates,
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
