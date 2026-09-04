import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsExperimentalPage extends ConsumerWidget {
  const SettingsExperimentalPage({super.key});

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

  Future<void> _showTlsFragmentationPicker(
    BuildContext context,
    AppSettingsCommands commands,
    TlsFragmentationMode currentMode,
  ) async {
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
                  selected: mode == currentMode,
                  title: Text(_tlsFragmentationModeLabel(l10n, mode)),
                  subtitle: Text(_tlsFragmentationModeSubtitle(l10n, mode)),
                  trailing: mode == currentMode
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
      commands.setTlsFragmentationMode(result);
    }
  }

  Future<void> _setMemoryLimitEnabled(
    BuildContext context,
    AppSettingsCommands commands,
    bool value, {
    required bool warningDismissed,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (value || warningDismissed) {
      commands.setMemoryLimitEnabled(value);
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
      commands.setMemoryLimitEnabled(false, warningDismissed: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = ref.watch(appSettingsProvider).controller;
    final commands = ref.read(appSettingsCommandsProvider);

    final currentTcpFastOpen = settings.experimentalTcpFastOpen;
    final currentTcpMultiPath = settings.experimentalTcpMultiPath;
    final currentInterruptExistingConnections =
        settings.experimentalInterruptExistingConnections;
    final currentUrlTestStrictTolerance =
        settings.experimentalUrlTestStrictTolerance;
    final currentFakeIpEnabled = settings.experimentalFakeIpEnabled;
    final fakeIpAvailable = settings.vpnInboundEnabled &&
        settings.splitRoutingMode == SplitRoutingMode.disabled;
    final currentTlsFragmentationMode = settings.tlsFragmentationMode;
    final currentMemoryLimitEnabled = settings.memoryLimitEnabled;
    final currentMemoryLimitWarningDismissed =
        settings.memoryLimitWarningDismissed;

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
                    onTap: () => _showTlsFragmentationPicker(
                      context,
                      commands,
                      currentTlsFragmentationMode,
                    ),
                  ),
                  SwitchListTile(
                    secondary: SettingsLeadingIcon(
                      icon: Icons.bolt_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.experimentalTcpFastOpenTitle),
                    subtitle: Text(l10n.experimentalTcpFastOpenSubtitle),
                    value: currentTcpFastOpen,
                    onChanged: commands.setExperimentalTcpFastOpen,
                  ),
                  SwitchListTile(
                    secondary: SettingsLeadingIcon(
                      icon: Icons.merge_type_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.experimentalTcpMultiPathTitle),
                    subtitle: Text(l10n.experimentalTcpMultiPathSubtitle),
                    value: currentTcpMultiPath,
                    onChanged: commands.setExperimentalTcpMultiPath,
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
                    onChanged: fakeIpAvailable
                        ? commands.setExperimentalFakeIpEnabled
                        : null,
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
                    onChanged:
                        commands.setExperimentalInterruptExistingConnections,
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
                    onChanged:
                        commands.setExperimentalUrlTestStrictTolerance,
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
                    onChanged: (value) => unawaited(
                      _setMemoryLimitEnabled(
                        context,
                        commands,
                        value,
                        warningDismissed:
                            currentMemoryLimitWarningDismissed,
                      ),
                    ),
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
