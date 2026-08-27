import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/update/app_update_channel.dart';
import 'package:meow_client/features/settings/developer_profile_sheet.dart';
import 'package:meow_client/features/settings/settings_documentation_page.dart';
import 'package:meow_client/features/settings/settings_update_page.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/models/core_integration_diagnostics.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';
import 'package:meow_client/widgets/app_visual_effects.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsAboutPage extends StatefulWidget {
  const SettingsAboutPage({
    super.key,
    required this.versionLabel,
    required this.onShowOnboarding,
    this.updateInstallMode = AppUpdateInstallMode.ask,
    this.updateChannel = AppUpdateChannel.stable,
    this.onUpdateInstallModeChanged,
    this.onUpdateChannelChanged,
    this.readCoreIntegrationDiagnostics,
    this.loadCoreCapabilities,
    this.readRuntimeStatus,
  });

  static final Uri _telegramUri = Uri.parse('https://t.me/etonify');
  static final Uri _contactUri = Uri.parse('https://t.me/etonify?direct');

  final String versionLabel;
  final VoidCallback onShowOnboarding;
  final AppUpdateInstallMode updateInstallMode;
  final AppUpdateChannel updateChannel;
  final ValueChanged<AppUpdateInstallMode>? onUpdateInstallModeChanged;
  final ValueChanged<AppUpdateChannel>? onUpdateChannelChanged;
  final CoreIntegrationDiagnosticsSnapshot Function()?
  readCoreIntegrationDiagnostics;
  final Future<LibboxCapabilities> Function()? loadCoreCapabilities;
  final Future<Map<String, dynamic>> Function()? readRuntimeStatus;

  @override
  State<SettingsAboutPage> createState() => _SettingsAboutPageState();
}

class _SettingsAboutPageState extends State<SettingsAboutPage> {
  Future<void> _openUri(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppNotice.show(context, uri.toString(), tone: AppNoticeTone.error);
    }
  }

  void _openTeamPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const _MeowTeamPage()),
    );
  }

  void _openUpdatePage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsUpdatePage(
          currentVersion: widget.versionLabel,
          installMode: widget.updateInstallMode,
          updateChannel: widget.updateChannel,
          onInstallModeChanged: widget.onUpdateInstallModeChanged,
          onUpdateChannelChanged: widget.onUpdateChannelChanged,
        ),
      ),
    );
  }

  void _openDiagnosticsPage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => SettingsDiagnosticsPage(
          onShowOnboarding: widget.onShowOnboarding,
          readCoreIntegrationDiagnostics: widget.readCoreIntegrationDiagnostics,
          loadCoreCapabilities: widget.loadCoreCapabilities,
          readRuntimeStatus: widget.readRuntimeStatus,
        ),
      ),
    );
  }

  void _openDocumentationPage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const SettingsDocumentationPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.aboutSectionTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          progressiveHeaderTopPadding(context, 20),
          0,
          appBottomSafePadding(context, 24),
        ),
        children: [
          Padding(
            padding: settingsScreenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AboutInfoCard(
                  versionLabel: widget.versionLabel,
                  onOpenTelegram: () =>
                      _openUri(SettingsAboutPage._telegramUri),
                  onOpenContact: () => _openUri(SettingsAboutPage._contactUri),
                  onOpenTeam: _openTeamPage,
                ),
                const Gap(12),
                _AboutUpdatesCard(onOpenUpdates: _openUpdatePage),
                const Gap(12),
                _AboutDocumentationCard(
                  onOpenDocumentation: _openDocumentationPage,
                ),
                const Gap(12),
                _AboutDiagnosticsCard(onOpenDiagnostics: _openDiagnosticsPage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsDiagnosticsPage extends StatefulWidget {
  const SettingsDiagnosticsPage({
    super.key,
    required this.onShowOnboarding,
    this.readCoreIntegrationDiagnostics,
    this.loadCoreCapabilities,
    this.readRuntimeStatus,
  });

  final VoidCallback onShowOnboarding;
  final CoreIntegrationDiagnosticsSnapshot Function()?
  readCoreIntegrationDiagnostics;
  final Future<LibboxCapabilities> Function()? loadCoreCapabilities;
  final Future<Map<String, dynamic>> Function()? readRuntimeStatus;

  @override
  State<SettingsDiagnosticsPage> createState() =>
      _SettingsDiagnosticsPageState();
}

class _SettingsDiagnosticsPageState extends State<SettingsDiagnosticsPage> {
  bool _debugVisible = false;
  Map<String, dynamic>? _performanceSnapshot;
  bool _performanceBusy = false;
  LibboxCapabilities? _coreCapabilities;
  Map<String, dynamic>? _runtimeStatus;
  CoreIntegrationDiagnosticsSnapshot _coreIntegration =
      const CoreIntegrationDiagnosticsSnapshot.empty();
  bool _coreIntegrationBusy = false;

  @override
  void initState() {
    super.initState();
    _refreshCoreIntegration();
  }

  void _toggleDebugVisible() {
    if (AppVisualEffects.of(context).hapticEnabled) {
      HapticFeedback.selectionClick();
    }
    setState(() => _debugVisible = !_debugVisible);
  }

  Future<void> _refreshPerformanceSnapshot() async {
    if (_performanceBusy) return;
    setState(() => _performanceBusy = true);
    try {
      final snapshot = _withFlutterMemoryStats(
        await SingboxRuntime.instance.getPerformanceSnapshot(),
      );
      if (!mounted) return;
      setState(() => _performanceSnapshot = snapshot);
    } finally {
      if (mounted) {
        setState(() => _performanceBusy = false);
      }
    }
  }

  Future<void> _refreshCoreIntegration() async {
    if (_coreIntegrationBusy) return;
    setState(() => _coreIntegrationBusy = true);
    try {
      final capabilities =
          await (widget.loadCoreCapabilities?.call() ??
                  SingboxRuntime.instance.getCoreCapabilities())
              .timeout(
                const Duration(seconds: 3),
                onTimeout: () => LibboxCapabilities.incompatible,
              )
              .catchError((_) => LibboxCapabilities.incompatible);
      final status =
          await (widget.readRuntimeStatus?.call() ??
                  SingboxRuntime.instance.status())
              .timeout(
                const Duration(seconds: 3),
                onTimeout: () => const <String, dynamic>{},
              )
              .catchError((_) => const <String, dynamic>{});
      final diagnostics =
          widget.readCoreIntegrationDiagnostics?.call() ??
          const CoreIntegrationDiagnosticsSnapshot.empty();
      if (!mounted) return;
      setState(() {
        _coreCapabilities = capabilities;
        _runtimeStatus = status;
        _coreIntegration = diagnostics;
      });
    } finally {
      if (mounted) {
        setState(() => _coreIntegrationBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.diagnosticsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          progressiveHeaderTopPadding(context, 20),
          0,
          appBottomSafePadding(context, 24),
        ),
        children: [
          Padding(
            padding: settingsScreenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CoreIntegrationCard(
                  capabilities: _coreCapabilities,
                  runtimeStatus: _runtimeStatus,
                  diagnostics: _coreIntegration,
                  busy: _coreIntegrationBusy,
                  onRefresh: _refreshCoreIntegration,
                ),
                const Gap(12),
                _AboutResourcesCard(
                  snapshot: _performanceSnapshot,
                  busy: _performanceBusy,
                  onRefresh: _refreshPerformanceSnapshot,
                  onDebugToggle: _toggleDebugVisible,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: _debugVisible
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _AboutDebugCard(
                            onShowOnboarding: () {
                              Navigator.of(context).pop();
                              widget.onShowOnboarding();
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoreIntegrationCard extends StatelessWidget {
  const _CoreIntegrationCard({
    required this.capabilities,
    required this.runtimeStatus,
    required this.diagnostics,
    required this.busy,
    required this.onRefresh,
  });

  final LibboxCapabilities? capabilities;
  final Map<String, dynamic>? runtimeStatus;
  final CoreIntegrationDiagnosticsSnapshot diagnostics;
  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    final core = capabilities;
    final compatible = core?.isCompatible == true;
    final running = runtimeStatus?['running'] == true;
    final nativeGeneration =
        (runtimeStatus?['runtimeGeneration'] as num?)?.toInt() ?? 0;
    final effectiveGeneration = nativeGeneration > 0
        ? nativeGeneration
        : diagnostics.configRuntimeGeneration;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.coreIntegrationTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.refresh,
                  onPressed: busy ? null : onRefresh,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Text(
              l10n.coreIntegrationSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const Gap(14),
            _AboutInfoRow(
              label: l10n.coreVersionLabel,
              value: core?.coreVersion.trim().isNotEmpty == true
                  ? core!.coreVersion
                  : '—',
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.coreApiLabel,
              value: core == null || core.apiVersion <= 0
                  ? '—'
                  : core.apiVersion.toString(),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.coreCompatibilityLabel,
              value: core == null
                  ? '—'
                  : compatible
                  ? l10n.coreCompatible
                  : l10n.coreIncompatible,
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.coreConfigStateLabel,
              value: _applyStatusLabel(l10n, diagnostics),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.coreRuntimeStateLabel,
              value: running
                  ? l10n.coreRuntimeRunning
                  : l10n.coreRuntimeStopped,
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.coreRuntimeGenerationLabel,
              value: effectiveGeneration > 0
                  ? effectiveGeneration.toString()
                  : '—',
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.coreConfigSchemaLabel,
              value: diagnostics.configSchemaVersion > 0
                  ? diagnostics.configSchemaVersion.toString()
                  : '—',
            ),
            if (diagnostics.lastApplyAtMillis > 0) ...[
              const Gap(8),
              _AboutInfoRow(
                label: l10n.coreLastChangeLabel,
                value: _formatDateTime(diagnostics.lastApplyAtMillis),
              ),
            ],
            if (core != null &&
                !compatible &&
                core.contractError.isNotEmpty) ...[
              const Gap(12),
              Text(
                core.contractError,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.error,
                  height: 1.35,
                ),
              ),
            ],
            if (diagnostics.applyError.isNotEmpty) ...[
              const Gap(8),
              Text(
                diagnostics.applyError,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.error,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _applyStatusLabel(
    AppLocalizations l10n,
    CoreIntegrationDiagnosticsSnapshot diagnostics,
  ) {
    if (diagnostics.settingsApplyPending) return l10n.coreConfigPending;
    return switch (diagnostics.applyStatus) {
      'applied' => l10n.coreConfigApplied,
      'validated' => l10n.coreConfigValidated,
      'failed' => l10n.coreConfigFailed,
      'superseded' => l10n.coreConfigSuperseded,
      _ => l10n.coreConfigNotApplied,
    };
  }

  static String _formatDateTime(int millisecondsSinceEpoch) {
    final value = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}

class _AboutInfoCard extends StatelessWidget {
  const _AboutInfoCard({
    required this.versionLabel,
    required this.onOpenTelegram,
    required this.onOpenContact,
    required this.onOpenTeam,
  });

  final String versionLabel;
  final VoidCallback onOpenTelegram;
  final VoidCallback onOpenContact;
  final VoidCallback onOpenTeam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Text(
              'Etonify',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const Divider(height: 1),
          _AboutOverviewRow(label: l10n.appVersionLabel, value: versionLabel),
          const Divider(height: 1, indent: 18, endIndent: 18),
          _AboutOverviewRow(
            label: l10n.telegramChannelLabel,
            value: '@etonify',
            trailingIcon: Icons.open_in_new_rounded,
            onTap: onOpenTelegram,
          ),
          const Divider(height: 1, indent: 18, endIndent: 18),
          _AboutOverviewRow(
            label: l10n.aboutTeamLabel,
            value: 'MeowTeam',
            trailingIcon: Icons.chevron_right_rounded,
            onTap: onOpenTeam,
          ),
          const Divider(height: 1, indent: 18, endIndent: 18),
          _AboutOverviewRow(
            label: l10n.aboutContactLabel,
            trailingIcon: Icons.forum_outlined,
            onTap: onOpenContact,
          ),
        ],
      ),
    );
  }
}

class _AboutOverviewRow extends StatelessWidget {
  const _AboutOverviewRow({
    required this.label,
    this.value,
    this.trailingIcon,
    this.onTap,
  });

  final String label;
  final String? value;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (value != null) ...[
                const Gap(12),
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (trailingIcon != null) ...[
                const Gap(8),
                Icon(trailingIcon, size: 20, color: colors.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutDocumentationCard extends StatelessWidget {
  const _AboutDocumentationCard({required this.onOpenDocumentation});

  final VoidCallback onOpenDocumentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onOpenDocumentation,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cs.tertiaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.menu_book_rounded, color: cs.onTertiaryContainer),
        ),
        title: Text(
          l10n.aboutDocumentationTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l10n.aboutDocumentationSubtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _AboutUpdatesCard extends StatelessWidget {
  const _AboutUpdatesCard({required this.onOpenUpdates});

  final VoidCallback onOpenUpdates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onOpenUpdates,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.system_update_rounded,
            color: cs.onPrimaryContainer,
          ),
        ),
        title: Text(
          l10n.updatesTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l10n.updatesSubtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _AboutDiagnosticsCard extends StatelessWidget {
  const _AboutDiagnosticsCard({required this.onOpenDiagnostics});

  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onOpenDiagnostics,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.memory_rounded, color: cs.onSecondaryContainer),
        ),
        title: Text(
          l10n.diagnosticsTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l10n.diagnosticsSubtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _AboutResourcesCard extends StatelessWidget {
  const _AboutResourcesCard({
    required this.snapshot,
    required this.busy,
    required this.onRefresh,
    required this.onDebugToggle,
  });

  final Map<String, dynamic>? snapshot;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onDebugToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    final data = snapshot;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.aboutResourcesTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                GestureDetector(
                  onDoubleTap: onDebugToggle,
                  child: IconButton(
                    tooltip: l10n.refresh,
                    onPressed: busy ? null : onRefresh,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              l10n.aboutResourcesSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const Gap(12),
            Text(
              l10n.aboutResourcesPssTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Gap(4),
            Text(
              l10n.aboutResourcesPssSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const Gap(10),
            _AboutInfoRow(
              label: l10n.aboutResourcePss,
              value: _formatKb(data?['totalPssKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceRss,
              value: _formatKb(data?['totalRssKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceSwapPss,
              value: _formatKb(data?['totalSwapPssKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourcePrivateDirty,
              value: _formatKb(data?['totalPrivateDirtyKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceNativePss,
              value: _formatKb(data?['nativePssKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceDalvikPss,
              value: _formatKb(data?['dalvikPssKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceOtherPss,
              value: _formatKb(data?['otherPssKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceGraphicsPss,
              value: _formatKb(data?['graphicsPssKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceCodePss,
              value: _formatKb(data?['codePssKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceStackPss,
              value: _formatKb(data?['stackPssKb']),
            ),
            const Gap(14),
            Text(
              l10n.aboutResourcesRuntimeTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Gap(10),
            _AboutInfoRow(
              label: l10n.aboutResourceNativeHeap,
              value: _formatKb(data?['nativeHeapAllocatedKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceJavaHeap,
              value: _formatKb(data?['javaHeapUsedKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceCoreMemory,
              value: _formatBytes(data?['coreMemoryBytes']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceFlutterImageCache,
              value: _formatBytes(data?['flutterImageCacheBytes']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceCoreGoroutines,
              value: _formatCount(data?['coreGoroutines']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceCoreConnections,
              value:
                  '${_formatCount(data?['connectionsIn'])} / ${_formatCount(data?['connectionsOut'])}',
            ),
            const Gap(14),
            Text(
              l10n.aboutResourcesSystemTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Gap(10),
            _AboutInfoRow(
              label: l10n.aboutResourceProcessCpu,
              value: _formatPercent(data?['processCpuPercent']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceSystemMemory,
              value: _formatKb(data?['systemAvailMemKb']),
            ),
            const Gap(8),
            _AboutInfoRow(
              label: l10n.aboutResourceBatteryTemp,
              value: _formatTemperature(data?['batteryTemperatureC']),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatKb(Object? value) {
    final kb = _numValue(value);
    if (kb == null || kb < 0) return '—';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }

  static String _formatBytes(Object? value) {
    final bytes = _numValue(value);
    if (bytes == null || bytes < 0) return '—';
    return _formatKb(bytes / 1024);
  }

  static String _formatCount(Object? value) {
    final count = _numValue(value);
    if (count == null || count < 0) return '—';
    return count.toInt().toString();
  }

  static String _formatPercent(Object? value) {
    final percent = _numValue(value);
    if (percent == null || percent < 0) return '—';
    return '${percent.toStringAsFixed(percent >= 100 ? 0 : 1)} %';
  }

  static String _formatTemperature(Object? value) {
    final c = _numValue(value);
    if (c == null) return '—';
    return '${c.toStringAsFixed(1)} °C';
  }

  static num? _numValue(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const Gap(12),
        Flexible(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutActionChip extends StatelessWidget {
  const _AboutActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.primaryContainer.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: cs.onPrimaryContainer),
              const Gap(6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeowTeamPage extends StatelessWidget {
  const _MeowTeamPage();

  static final Uri _telegramUri = Uri.parse('https://t.me/etonify');
  static final Uri _coreUri = Uri.parse(
    'https://github.com/yamixdev/etonify-core/tree/etonify-dev',
  );

  Future<void> _open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AppNotice.show(context, uri.toString(), tone: AppNoticeTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dudosxdev = AppDevelopers.dudosxdev(l10n);
    final yamixdev = AppDevelopers.yamixdev(l10n);

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.teamPageTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          progressiveHeaderTopPadding(context, 20),
          16,
          appBottomSafePadding(context, 24),
        ),
        children: [
          Text(
            l10n.teamIntroTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const Gap(8),
          Text(
            l10n.teamIntroBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const Gap(18),
          _TimelineItem(
            icon: Icons.fork_right_rounded,
            title: l10n.teamTimelineForkTitle,
            body: l10n.teamTimelineForkBody,
          ),
          _TimelineItem(
            icon: Icons.cleaning_services_rounded,
            title: l10n.teamTimelineRefactorTitle,
            body: l10n.teamTimelineRefactorBody,
          ),
          _TimelineItem(
            icon: Icons.memory_rounded,
            title: l10n.teamTimelineCoreTitle,
            body: l10n.teamTimelineCoreBody,
            actionLabel: 'yamixdev/etonify-core',
            onAction: () => _open(context, _coreUri),
          ),
          _TimelineItem(
            icon: Icons.auto_awesome_rounded,
            title: l10n.teamTimelineNowTitle,
            body: l10n.teamTimelineNowBody,
          ),
          const Gap(14),
          _DeveloperCard(
            profile: dudosxdev,
            onTap: () => showDeveloperProfileSheet(context, dudosxdev),
          ),
          const Gap(10),
          _DeveloperCard(
            profile: yamixdev,
            onTap: () => showDeveloperProfileSheet(context, yamixdev),
          ),
          const Gap(10),
          _TeamLinkCard(
            name: l10n.telegramChannelLabel,
            role: l10n.teamTelegramRole,
            avatarAsset: 'assets/images/team/telegram.png',
            onTap: () => _open(context, _telegramUri),
          ),
          const Gap(28),
          Center(
            child: Text(
              '© 2026 MeowTeam™',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Gap(5),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const Gap(8),
                    _AboutActionChip(
                      icon: Icons.open_in_new_rounded,
                      label: actionLabel!,
                      onTap: onAction!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({required this.profile, required this.onTap});

  final DeveloperProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 22,
          backgroundImage: ResizeImage(
            AssetImage(profile.avatarAsset),
            width: 128,
            height: 128,
          ),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(5),
            Icon(
              Icons.verified_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
        subtitle: Text(profile.role),
        trailing: const Icon(Icons.chevron_right_rounded),
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TeamLinkCard extends StatelessWidget {
  const _TeamLinkCard({
    required this.name,
    required this.role,
    required this.avatarAsset,
    required this.onTap,
  });

  final String name;
  final String role;
  final String avatarAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 22,
          backgroundImage: ResizeImage(
            AssetImage(avatarAsset),
            width: 128,
            height: 128,
          ),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        title: Text(name),
        subtitle: Text(role),
        trailing: const Icon(Icons.open_in_new_rounded),
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AboutDebugCard extends StatelessWidget {
  const _AboutDebugCard({required this.onShowOnboarding});

  final VoidCallback onShowOnboarding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.debugMenuTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Gap(8),
            Text(
              l10n.debugMenuSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const Gap(14),
            FilledButton.tonalIcon(
              onPressed: onShowOnboarding,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: Text(l10n.showOnboardingAgain),
            ),
            const Gap(14),
            const _RuntimeFlagsToggles(),
            const Gap(14),
            const Divider(height: 1),
            const Gap(14),
            const _RuntimeMeasurementCard(),
          ],
        ),
      ),
    );
  }
}

class _RuntimeFlagsToggles extends StatefulWidget {
  const _RuntimeFlagsToggles();

  @override
  State<_RuntimeFlagsToggles> createState() => _RuntimeFlagsTogglesState();
}

class _RuntimeFlagsTogglesState extends State<_RuntimeFlagsToggles> {
  RuntimeFlags? _flags;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final flags = await SingboxRuntime.instance.getRuntimeFlags();
    if (!mounted) return;
    setState(() => _flags = flags);
  }

  Future<void> _setWakeLock(bool value) async {
    if (_busy || _flags == null) return;
    setState(() {
      _busy = true;
      _flags = RuntimeFlags(
        wakeLockEnabled: value,
        networkHeartbeatEnabled: _flags!.networkHeartbeatEnabled,
        networkHeartbeatIntervalSeconds:
            _flags!.networkHeartbeatIntervalSeconds,
        memoryLimitEnabled: _flags!.memoryLimitEnabled,
      );
    });
    await SingboxRuntime.instance.setRuntimeFlags(wakeLockEnabled: value);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _setHeartbeat(bool value) async {
    if (_busy || _flags == null) return;
    setState(() {
      _busy = true;
      _flags = RuntimeFlags(
        wakeLockEnabled: _flags!.wakeLockEnabled,
        networkHeartbeatEnabled: value,
        networkHeartbeatIntervalSeconds:
            _flags!.networkHeartbeatIntervalSeconds,
        memoryLimitEnabled: _flags!.memoryLimitEnabled,
      );
    });
    await SingboxRuntime.instance.setRuntimeFlags(
      networkHeartbeatEnabled: value,
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _recordPerformanceSnapshot() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final snapshot = _withFlutterMemoryStats(
        await SingboxRuntime.instance.getPerformanceSnapshot(),
      );
      AppLogStore.info('performance snapshot', snapshot.toString());
      if (!mounted) return;
      AppNotice.show(
        context,
        AppLocalizations.of(context).debugSnapshotDone,
        tone: AppNoticeTone.success,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flags = _flags;
    if (flags == null) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.debugNetworkHeartbeatTitle),
          subtitle: Text(
            l10n.debugNetworkHeartbeatSubtitle(
              flags.networkHeartbeatIntervalSeconds,
            ),
          ),
          value: flags.networkHeartbeatEnabled,
          onChanged: _busy ? null : _setHeartbeat,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.debugWakeLockTitle),
          subtitle: Text(l10n.debugWakeLockSubtitle),
          value: flags.wakeLockEnabled,
          onChanged: _busy ? null : _setWakeLock,
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _recordPerformanceSnapshot,
          icon: const Icon(Icons.memory_rounded),
          label: Text(l10n.debugRecordSnapshot),
        ),
      ],
    );
  }
}

class _RuntimeMeasurementCard extends StatefulWidget {
  const _RuntimeMeasurementCard();

  @override
  State<_RuntimeMeasurementCard> createState() =>
      _RuntimeMeasurementCardState();
}

class _RuntimeMeasurementCardState extends State<_RuntimeMeasurementCard> {
  static const _minDurationSeconds = 15.0;
  static const _maxDurationSeconds = 3600.0;
  static const _durationStepSeconds = 15.0;

  Timer? _refreshTimer;
  Map<String, dynamic> _measurement = const {};
  double _durationSeconds = 60.0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool get _running => _measurement['state'] == 'running';

  Future<void> _refresh({bool silent = false}) async {
    if (_busy && !silent) return;
    final measurement = await SingboxRuntime.instance.getRuntimeMeasurement();
    if (!mounted) return;
    setState(() => _measurement = measurement);
    _syncRefreshTimer();
  }

  void _syncRefreshTimer() {
    if (_running) {
      _refreshTimer ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => _refresh(silent: true),
      );
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  Future<void> _start() async {
    if (_busy || _running) return;
    setState(() => _busy = true);
    try {
      await SingboxRuntime.instance.startRuntimeMeasurement(
        durationSeconds: _durationSeconds.round(),
      );
      await _refresh(silent: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (_busy || !_running) return;
    setState(() => _busy = true);
    try {
      await SingboxRuntime.instance.stopRuntimeMeasurement();
      await _refresh(silent: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveReport() async {
    if (_busy || _measurement['reportAvailable'] != true) return;
    setState(() => _busy = true);
    try {
      final report = await SingboxRuntime.instance
          .getRuntimeMeasurementReport();
      if (report.trim().isEmpty) return;
      final savedPath = await SingboxRuntime.instance.exportLogs(
        content: report,
        suggestedName:
            'etonify-runtime-measurement-${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      if (!mounted || savedPath == null) return;
      AppNotice.show(
        context,
        AppLocalizations.of(context).debugRuntimeMeasurementSaved,
        tone: AppNoticeTone.success,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    final state = _measurement['state']?.toString() ?? 'idle';
    final elapsedSeconds = _intValue(_measurement['elapsedSeconds']);
    final durationSeconds = _intValue(
      _measurement['durationSeconds'],
    ).clamp(_minDurationSeconds.toInt(), _maxDurationSeconds.toInt()).toInt();
    final statusLabel = switch (state) {
      'running' => l10n.debugRuntimeMeasurementProgress(
        _formatDuration(elapsedSeconds),
        _formatDuration(durationSeconds),
      ),
      'completed' => l10n.debugRuntimeMeasurementCompleted,
      'stopped' => l10n.debugRuntimeMeasurementStopped,
      _ => l10n.debugRuntimeMeasurementIdle,
    };
    final assessment = _assessmentText(l10n, _measurement['assessmentCode']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.debugRuntimeMeasurementTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Gap(6),
        Text(
          l10n.debugRuntimeMeasurementSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const Gap(12),
        Text(
          l10n.debugRuntimeMeasurementDuration(
            _formatDuration(_durationSeconds.round()),
          ),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Slider(
          value: _durationSeconds,
          min: _minDurationSeconds,
          max: _maxDurationSeconds,
          divisions:
              ((_maxDurationSeconds - _minDurationSeconds) /
                      _durationStepSeconds)
                  .round(),
          label: _formatDuration(_durationSeconds.round()),
          onChanged: _busy || _running
              ? null
              : (value) {
                  final snapped =
                      ((value / _durationStepSeconds).round() *
                              _durationStepSeconds)
                          .clamp(_minDurationSeconds, _maxDurationSeconds)
                          .toDouble();
                  setState(() => _durationSeconds = snapped);
                },
        ),
        Text(
          statusLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _running ? cs.primary : cs.onSurfaceVariant,
            fontWeight: _running ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        if (assessment != null) ...[
          const Gap(6),
          Text(
            assessment,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        if (_measurement['sampleCount'] is num &&
            (_measurement['sampleCount'] as num) > 1) ...[
          const Gap(10),
          _MeasurementSummary(measurement: _measurement),
        ],
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy || _running ? null : _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.debugRuntimeMeasurementStart),
              ),
            ),
            if (_running) ...[
              const Gap(8),
              IconButton.outlined(
                tooltip: l10n.debugRuntimeMeasurementStop,
                onPressed: _busy ? null : _stop,
                icon: const Icon(Icons.stop_rounded),
              ),
            ],
            if (_measurement['reportAvailable'] == true) ...[
              const Gap(8),
              IconButton.outlined(
                tooltip: l10n.debugRuntimeMeasurementSave,
                onPressed: _busy ? null : _saveReport,
                icon: const Icon(Icons.save_alt_rounded),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static int _intValue(Object? value) => (value as num?)?.toInt() ?? 0;

  static String _formatDuration(int seconds) {
    final duration = Duration(
      seconds: seconds.clamp(0, 99 * 60 * 60 + 59 * 60 + 59).toInt(),
    );
    String pad(int value) => value.toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${pad(duration.inHours)}:${pad(duration.inMinutes.remainder(60))}:${pad(duration.inSeconds.remainder(60))}';
    }
    return '${pad(duration.inMinutes)}:${pad(duration.inSeconds.remainder(60))}';
  }

  static String? _assessmentText(AppLocalizations l10n, Object? rawCode) {
    return switch (rawCode?.toString()) {
      'healthy' => l10n.debugRuntimeMeasurementHealthy,
      'high_cpu_low_traffic' => l10n.debugRuntimeMeasurementHighCpu,
      'goroutine_growth' => l10n.debugRuntimeMeasurementGoroutineGrowth,
      'memory_growth' => l10n.debugRuntimeMeasurementMemoryGrowth,
      'connection_churn' => l10n.debugRuntimeMeasurementConnectionChurn,
      'collecting' => l10n.debugRuntimeMeasurementCollecting,
      'idle' || null => null,
      _ => l10n.debugRuntimeMeasurementUnavailable,
    };
  }
}

class _MeasurementSummary extends StatelessWidget {
  const _MeasurementSummary({required this.measurement});

  final Map<String, dynamic> measurement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cpu = _number(measurement['cpuAveragePercent']);
    final pss = _number(measurement['pssEndKb']);
    final goroutines = _number(measurement['coreGoroutinesEnd']);
    final connections = _number(measurement['connectionsPeak']);
    final values = <String>[
      if (cpu != null) 'CPU ${cpu.toStringAsFixed(1)}%',
      if (pss != null) 'PSS ${(pss / 1024).toStringAsFixed(0)} MB',
      if (goroutines != null) 'Go ${goroutines.toInt()}',
      if (connections != null) 'Conn ${connections.toInt()}',
    ];
    if (values.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: values
          .map(
            (value) => Chip(
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: cs.outlineVariant),
              label: Text(value, style: theme.textTheme.labelSmall),
            ),
          )
          .toList(growable: false),
    );
  }

  static num? _number(Object? value) => value is num ? value : null;
}

Map<String, dynamic> _withFlutterMemoryStats(Map<String, dynamic> snapshot) {
  final imageCache = PaintingBinding.instance.imageCache;
  return <String, dynamic>{
    ...snapshot,
    'flutterImageCacheBytes': imageCache.currentSizeBytes,
    'flutterImageCacheEntries': imageCache.currentSize,
    'flutterLiveImages': imageCache.liveImageCount,
    'flutterPendingImages': imageCache.pendingImageCount,
  };
}
