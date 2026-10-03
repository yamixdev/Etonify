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
          child: SingleChildScrollView(
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
    final settings = ref.watch(appSettingsProvider).controller;
    final commands = ref.read(appSettingsCommandsProvider);

    final currentTcpFastOpen = settings.experimentalTcpFastOpen;
    final currentTcpMultiPath = settings.experimentalTcpMultiPath;
    final currentInterruptExistingConnections =
        settings.experimentalInterruptExistingConnections;
    final currentUrlTestStrictTolerance =
        settings.experimentalUrlTestStrictTolerance;
    final currentFakeIpEnabled = settings.experimentalFakeIpEnabled;
    final fakeIpAvailable =
        settings.vpnInboundEnabled &&
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
            _ExperimentalSection(
              title: l10n.experimentalNetworkSection,
              children: [
                _ExperimentalSettingTile(
                  icon: Icons.content_cut_rounded,
                  title: l10n.tlsFragmentationTitle,
                  description:
                      '${_tlsFragmentationModeLabel(l10n, currentTlsFragmentationMode)} · ${l10n.tlsFragmentationSubtitle}',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showTlsFragmentationPicker(
                    context,
                    commands,
                    currentTlsFragmentationMode,
                  ),
                ),
                _ExperimentalSettingTile.toggle(
                  icon: Icons.bolt_rounded,
                  title: l10n.experimentalTcpFastOpenTitle,
                  description: l10n.experimentalTcpFastOpenSubtitle,
                  value: currentTcpFastOpen,
                  onChanged: commands.setExperimentalTcpFastOpen,
                ),
                _ExperimentalSettingTile.toggle(
                  icon: Icons.merge_type_rounded,
                  title: l10n.experimentalTcpMultiPathTitle,
                  description: l10n.experimentalTcpMultiPathSubtitle,
                  value: currentTcpMultiPath,
                  onChanged: commands.setExperimentalTcpMultiPath,
                ),
                _ExperimentalSettingTile.toggle(
                  icon: Icons.dns_rounded,
                  title: l10n.experimentalFakeIpTitle,
                  description: fakeIpAvailable
                      ? l10n.experimentalFakeIpSubtitle
                      : l10n.experimentalFakeIpUnavailableSubtitle,
                  value: fakeIpAvailable && currentFakeIpEnabled,
                  onChanged: fakeIpAvailable
                      ? commands.setExperimentalFakeIpEnabled
                      : null,
                ),
              ],
            ),
            const Gap(settingsSectionGap),
            _ExperimentalSection(
              title: l10n.experimentalSelectionSection,
              children: [
                _ExperimentalSettingTile.toggle(
                  icon: Icons.sync_problem_rounded,
                  title: l10n.experimentalInterruptConnectionsTitle,
                  description: l10n.experimentalInterruptConnectionsSubtitle,
                  value: currentInterruptExistingConnections,
                  onChanged:
                      commands.setExperimentalInterruptExistingConnections,
                ),
                _ExperimentalSettingTile.toggle(
                  icon: Icons.speed_rounded,
                  title: l10n.experimentalUrlTestStrictToleranceTitle,
                  description: l10n.experimentalUrlTestStrictToleranceSubtitle,
                  value: currentUrlTestStrictTolerance,
                  onChanged: commands.setExperimentalUrlTestStrictTolerance,
                ),
              ],
            ),
            const Gap(settingsSectionGap),
            _ExperimentalSection(
              title: l10n.experimentalMemorySection,
              children: [
                _ExperimentalSettingTile.toggle(
                  icon: Icons.memory_rounded,
                  title: l10n.memoryLimitTitle,
                  description: currentMemoryLimitEnabled
                      ? l10n.memoryLimitEnabledSubtitle
                      : l10n.memoryLimitDisabledSubtitle,
                  value: currentMemoryLimitEnabled,
                  onChanged: (value) => unawaited(
                    _setMemoryLimitEnabled(
                      context,
                      commands,
                      value,
                      warningDismissed: currentMemoryLimitWarningDismissed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExperimentalSection extends StatelessWidget {
  const _ExperimentalSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
      ),
      SettingsTileGroup(dividerIndent: 16, children: children),
    ],
  );
}

class _ExperimentalSettingTile extends StatelessWidget {
  const _ExperimentalSettingTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.trailing,
    required this.onTap,
  }) : value = null,
       onChanged = null;

  const _ExperimentalSettingTile.toggle({
    required this.icon,
    required this.title,
    required this.description,
    required bool this.value,
    required this.onChanged,
  }) : trailing = null,
       onTap = null;

  final IconData icon;
  final String title;
  final String description;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = value == null || onChanged != null;
    final color = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: .38);
    return MergeSemantics(
      child: InkWell(
        onTap: value == null
            ? onTap
            : onChanged == null
            ? null
            : () => onChanged!(!value!),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SettingsLeadingIcon(icon: icon, color: color, size: 36),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: enabled ? theme.colorScheme.onSurface : color,
                      ),
                    ),
                  ),
                  const Gap(8),
                  if (value != null)
                    Switch(value: value!, onChanged: onChanged)
                  else
                    trailing!,
                ],
              ),
              const Gap(8),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
