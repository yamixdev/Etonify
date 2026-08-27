import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsExperimentalPage extends StatelessWidget {
  const SettingsExperimentalPage({
    super.key,
    required this.currentTcpFastOpen,
    required this.currentTcpMultiPath,
    required this.currentInterruptExistingConnections,
    required this.currentUrlTestStrictTolerance,
    required this.currentFakeIpEnabled,
    required this.fakeIpAvailable,
    required this.currentTlsFragmentationMode,
    required this.currentMemoryLimitEnabled,
    required this.currentMemoryLimitWarningDismissed,
    required this.onTcpFastOpenChanged,
    required this.onTcpMultiPathChanged,
    required this.onInterruptExistingConnectionsChanged,
    required this.onUrlTestStrictToleranceChanged,
    required this.onFakeIpEnabledChanged,
    required this.onTlsFragmentationModeChanged,
    required this.onMemoryLimitChanged,
  });

  final bool currentTcpFastOpen;
  final bool currentTcpMultiPath;
  final bool currentInterruptExistingConnections;
  final bool currentUrlTestStrictTolerance;
  final bool currentFakeIpEnabled;
  final bool fakeIpAvailable;
  final TlsFragmentationMode currentTlsFragmentationMode;
  final bool currentMemoryLimitEnabled;
  final bool currentMemoryLimitWarningDismissed;
  final ValueChanged<bool> onTcpFastOpenChanged;
  final ValueChanged<bool> onTcpMultiPathChanged;
  final ValueChanged<bool> onInterruptExistingConnectionsChanged;
  final ValueChanged<bool> onUrlTestStrictToleranceChanged;
  final ValueChanged<bool> onFakeIpEnabledChanged;
  final ValueChanged<TlsFragmentationMode> onTlsFragmentationModeChanged;
  final void Function(bool value, {bool warningDismissed}) onMemoryLimitChanged;

  String _tlsFragmentationModeLabel(
    AppLocalizations l10n,
    TlsFragmentationMode mode,
  ) => switch (mode) {
    TlsFragmentationMode.disabled => l10n.tlsFragmentationModeDisabled,
    TlsFragmentationMode.record => l10n.tlsFragmentationModeRecord,
    TlsFragmentationMode.fragment => l10n.tlsFragmentationModeFragment,
  };

  String _tlsFragmentationModeSubtitle(
    AppLocalizations l10n,
    TlsFragmentationMode mode,
  ) => switch (mode) {
    TlsFragmentationMode.disabled => l10n.tlsFragmentationModeDisabledSubtitle,
    TlsFragmentationMode.record => l10n.tlsFragmentationModeRecordSubtitle,
    TlsFragmentationMode.fragment => l10n.tlsFragmentationModeFragmentSubtitle,
  };

  Future<void> _showTlsFragmentationPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await showModalBottomSheet<TlsFragmentationMode>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.tlsFragmentationTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              for (final mode in TlsFragmentationMode.values)
                ListTile(
                  selected: mode == currentTlsFragmentationMode,
                  title: Text(_tlsFragmentationModeLabel(l10n, mode)),
                  subtitle: Text(_tlsFragmentationModeSubtitle(l10n, mode)),
                  trailing: mode == currentTlsFragmentationMode
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(context).pop(mode),
                ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      onTlsFragmentationModeChanged(result);
    }
  }

  Future<void> _setMemoryLimitEnabled(BuildContext context, bool value) async {
    final l10n = AppLocalizations.of(context);
    if (value || currentMemoryLimitWarningDismissed) {
      onMemoryLimitChanged(value);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.memoryLimitDisableWarningTitle),
        content: Text(l10n.memoryLimitDisableWarningMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.memoryLimitDisableConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onMemoryLimitChanged(false, warningDismissed: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.experimentalTitle)),
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
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: SettingsLeadingIcon(
                      icon: Icons.content_cut_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.tlsFragmentationTitle),
                    subtitle: Text(
                      '${_tlsFragmentationModeLabel(l10n, currentTlsFragmentationMode)} · ${l10n.tlsFragmentationSubtitle}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showTlsFragmentationPicker(context),
                  ),
                  SwitchListTile(
                    secondary: SettingsLeadingIcon(
                      icon: Icons.bolt_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.experimentalTcpFastOpenTitle),
                    subtitle: Text(l10n.experimentalTcpFastOpenSubtitle),
                    value: currentTcpFastOpen,
                    onChanged: onTcpFastOpenChanged,
                  ),
                  SwitchListTile(
                    secondary: SettingsLeadingIcon(
                      icon: Icons.merge_type_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.experimentalTcpMultiPathTitle),
                    subtitle: Text(l10n.experimentalTcpMultiPathSubtitle),
                    value: currentTcpMultiPath,
                    onChanged: onTcpMultiPathChanged,
                  ),
                  SwitchListTile(
                    secondary: SettingsLeadingIcon(
                      icon: Icons.dns_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.experimentalFakeIpTitle),
                    subtitle: Text(
                      fakeIpAvailable
                          ? l10n.experimentalFakeIpSubtitle
                          : l10n.experimentalFakeIpUnavailableSubtitle,
                    ),
                    value: fakeIpAvailable && currentFakeIpEnabled,
                    onChanged: fakeIpAvailable ? onFakeIpEnabledChanged : null,
                  ),
                ],
              ),
            ),
            const Gap(settingsIslandGap),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: SettingsLeadingIcon(
                      icon: Icons.sync_problem_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.experimentalInterruptConnectionsTitle),
                    subtitle: Text(
                      l10n.experimentalInterruptConnectionsSubtitle,
                    ),
                    value: currentInterruptExistingConnections,
                    onChanged: onInterruptExistingConnectionsChanged,
                  ),
                  SwitchListTile(
                    secondary: SettingsLeadingIcon(
                      icon: Icons.speed_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.experimentalUrlTestStrictToleranceTitle),
                    subtitle: Text(
                      l10n.experimentalUrlTestStrictToleranceSubtitle,
                    ),
                    value: currentUrlTestStrictTolerance,
                    onChanged: onUrlTestStrictToleranceChanged,
                  ),
                  SwitchListTile(
                    secondary: SettingsLeadingIcon(
                      icon: Icons.memory_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.memoryLimitTitle),
                    subtitle: Text(
                      currentMemoryLimitEnabled
                          ? l10n.memoryLimitEnabledSubtitle
                          : l10n.memoryLimitDisabledSubtitle,
                    ),
                    value: currentMemoryLimitEnabled,
                    onChanged: (value) =>
                        unawaited(_setMemoryLimitEnabled(context, value)),
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
