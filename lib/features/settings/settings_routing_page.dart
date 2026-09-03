import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/core/network/remote_download_error_message.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/features/settings/routing_rule_files_page.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/features/settings/traffic_rules_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

final _installedAppIconCache = _InstalledAppIconCache(maxEntries: 96);
final _installedAppIconLoads = <String, Future<Uint8List?>>{};
final _appSearchSeparatorsPattern = RegExp(r'[._\-]+');
final _appSearchWhitespacePattern = RegExp(r'\s+');
final _appSearchNonAlphaNumericPattern = RegExp(r'[^a-z0-9а-яё]+');
const _splitRoutingTemporarilyDisabled = false;

void clearInstalledAppIconCache() {
  _installedAppIconCache.clear();
  _installedAppIconLoads.clear();
}

String _trafficRulePresetTitle(
  AppLocalizations l10n,
  TrafficRulePreset preset,
) {
  return switch (preset) {
    TrafficRulePreset.none => l10n.trafficRulesNone,
    TrafficRulePreset.russianServicesDirect => l10n.trafficRulesRussianTitle,
    TrafficRulePreset.aiViaVpn => l10n.trafficRulesAiTitle,
    TrafficRulePreset.socialViaVpn => l10n.trafficRulesSocialTitle,
  };
}

class SettingsRoutingPage extends ConsumerStatefulWidget {
  const SettingsRoutingPage({super.key});

  @override
  ConsumerState<SettingsRoutingPage> createState() =>
      _SettingsRoutingPageState();
}

class _SettingsRoutingPageState extends ConsumerState<SettingsRoutingPage> {
  late final TextEditingController _packagesController;
  late final AppSettingsCommands _commands;
  late final AdBlockRuleSetService _adBlockService;
  bool _adBlockBusy = false;
  AdBlockUpdateProgress? _adBlockProgress;
  bool _loadingInstalledApps = false;
  String? _installedAppsError;
  bool _manualEditorExpanded = false;
  List<_InstalledApp> _installedApps = const <_InstalledApp>[];

  @override
  void initState() {
    super.initState();
    _commands = ref.read(appSettingsCommandsProvider);
    _adBlockService = ref.read(adBlockRuleSetServiceProvider);
    final initialPackages = ref.read(
      appSettingsProvider.select((s) => s.controller.splitRoutingPackages),
    );
    _packagesController = TextEditingController(
      text: initialPackages.join('\n'),
    );
    _adBlockBusy = _adBlockService.isUpdating;
    _adBlockProgress = _adBlockService.progress.value;
    _adBlockService.progress.addListener(_handleAdBlockProgress);
    final initialApps = ref.read(installedAppsCacheProvider);
    _installedApps = initialApps
        .map((item) => _InstalledApp.fromMap(item))
        .where((item) => item.packageName.isNotEmpty)
        .toList(growable: false);
    if (_installedApps.isEmpty &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadInstalledApps());
        }
      });
    }
  }

  @override
  void dispose() {
    _adBlockService.progress.removeListener(_handleAdBlockProgress);
    _commitPackages();
    _packagesController.dispose();
    super.dispose();
  }

  void _handleAdBlockProgress() {
    if (!mounted) return;
    final busy = _adBlockService.isUpdating;
    setState(() {
      _adBlockBusy = busy;
      _adBlockProgress = _adBlockService.progress.value;
    });
    if (!busy) {
      unawaited(_reloadAdBlockStatus());
    }
  }

  Future<void> _reloadAdBlockStatus() async {
    final status = await _adBlockService.loadStatus();
    if (!mounted || _adBlockService.isUpdating) return;
    ref.read(adBlockStatusProvider.notifier).update(status);
  }

  Future<bool> _loadInstalledApps() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    if (_loadingInstalledApps) {
      return _installedApps.isNotEmpty;
    }
    setState(() {
      _loadingInstalledApps = true;
      _installedAppsError = null;
    });
    try {
      final items = await ref
          .read(appSettingsCommandsProvider)
          .preloadInstalledApps();
      if (!mounted) {
        return false;
      }
      setState(() {
        _installedApps = items
            .map((item) => _InstalledApp.fromMap(item))
            .where((item) => item.packageName.isNotEmpty)
            .toList(growable: false);
        _loadingInstalledApps = false;
        _installedAppsError = null;
      });
      return _installedApps.isNotEmpty;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _loadingInstalledApps = false;
        _installedAppsError = error.toString();
      });
      return false;
    }
  }

  List<String> _selectedPackages() {
    return normalizeSplitRoutingPackages(
      _packagesController.text.split(RegExp(r'[\n,;]')),
    );
  }

  void _commitPackages() {
    final packages = _selectedPackages();
    _commands.setSplitRoutingPackages(packages);
    final normalizedText = packages.join('\n');
    if (_packagesController.text.trim() != normalizedText) {
      _packagesController.text = normalizedText;
    }
  }

  void _removeSelectedPackage(String packageName) {
    final packages = _selectedPackages()
        .where((item) => item != packageName)
        .toList(growable: false);
    setState(() => _packagesController.text = packages.join('\n'));
    _commitPackages();
  }

  void _showOperationError(Object error) {
    final l10n = AppLocalizations.of(context);
    AppNotice.show(
      context,
      remoteDownloadErrorMessage(l10n, error) ?? error.toString(),
      tone: AppNoticeTone.error,
    );
  }

  Future<void> _openTrafficRules() async {
    final commands = ref.read(appSettingsCommandsProvider);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            final liveSettings = ref.watch(appSettingsProvider).controller;
            final liveStatus = ref.watch(russiaRouteDataStatusProvider);
            return TrafficRulesPage(
              currentPreset: liveSettings.trafficRulePreset,
              currentStatus: liveStatus,
              currentRussiaDnsDirectResolver:
                  liveSettings.russiaDnsDirectResolver,
              onPrepareRuleData: commands.prepareTrafficRuleData,
              onPresetChanged: commands.setTrafficRulePreset,
              onRussiaDnsDirectResolverChanged:
                  commands.setRussiaDnsDirectResolver,
            );
          },
        ),
      ),
    );
  }

  Future<void> _openRoutingRuleFiles() async {
    final commands = ref.read(appSettingsCommandsProvider);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            final liveStatus = ref.watch(russiaRouteDataStatusProvider);
            return RoutingRuleFilesPage(
              currentStatus: liveStatus,
              onRefresh: commands.refreshRoutingRuleData,
            );
          },
        ),
      ),
    );
  }

  Future<void> _setAdBlock(bool value) async {
    final commands = ref.read(appSettingsCommandsProvider);
    final adBlockStatus = ref.read(adBlockStatusProvider);
    if (!value) {
      commands.setAdBlockEnabled(false);
      return;
    }
    if (adBlockStatus.available) {
      commands.setAdBlockEnabled(true);
      return;
    }
    await _downloadAdBlock(enableAfterDownload: true);
  }

  Future<void> _downloadAdBlock({bool enableAfterDownload = false}) async {
    if (_adBlockBusy) {
      return;
    }
    setState(() {
      _adBlockBusy = true;
    });
    try {
      final commands = ref.read(appSettingsCommandsProvider);
      final status = await commands.downloadAdBlockRuleSet();
      if (!mounted) {
        return;
      }
      ref.read(adBlockStatusProvider.notifier).update(status);
      if (enableAfterDownload && status.available) {
        commands.setAdBlockEnabled(true);
      }
    } catch (error) {
      if (mounted) {
        _showOperationError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _adBlockBusy = false;
        });
      }
    }
  }

  Future<void> _deleteAdBlock() async {
    if (_adBlockBusy) {
      return;
    }
    setState(() {
      _adBlockBusy = true;
    });
    try {
      final commands = ref.read(appSettingsCommandsProvider);
      final status = await commands.deleteAdBlockRuleSet();
      if (!mounted) {
        return;
      }
      ref.read(adBlockStatusProvider.notifier).update(status);
      commands.setAdBlockEnabled(false);
    } catch (error) {
      if (mounted) {
        _showOperationError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _adBlockBusy = false;
        });
      }
    }
  }

  Future<void> _openAppPicker() async {
    FocusScope.of(context).unfocus();
    _commitPackages();
    if (_installedApps.isEmpty) {
      final loaded = await _loadInstalledApps();
      if (!loaded || !mounted) {
        return;
      }
    }
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _AppPickerSheet(
        apps: _installedApps,
        initialSelected: _selectedPackages().toSet(),
      ),
    );
    if (result == null) {
      return;
    }
    final packages = result.toList()..sort();
    _packagesController.text = packages.join('\n');
    _commitPackages();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    final settingsSnapshot = ref.watch(appSettingsProvider);
    final settings = settingsSnapshot.controller;
    final blockLeaks = settings.blockLeaks;
    final bypassLocalNetwork = settings.bypassLocalNetwork;
    final trafficRulePreset = settings.trafficRulePreset;
    final vpnInboundEnabled = settings.vpnInboundEnabled;
    final splitRoutingMode = settings.splitRoutingMode;
    final adBlockEnabled = settings.adBlockEnabled;

    final adBlockStatus = ref.watch(adBlockStatusProvider);
    final russiaRouteDataStatus = ref.watch(russiaRouteDataStatusProvider);
    final commands = ref.read(appSettingsCommandsProvider);

    final splitAvailable =
        !_splitRoutingTemporarilyDisabled &&
        isAndroid &&
        vpnInboundEnabled;
    final selectedPackages = _selectedPackages();
    final installedAppByPackage = <String, _InstalledApp>{
      for (final app in _installedApps) app.packageName: app,
    };
    final selectedApps = selectedPackages
        .map(
          (packageName) =>
              installedAppByPackage[packageName] ??
              _InstalledApp(
                packageName: packageName,
                label: '',
                system: false,
                launchable: false,
              ),
        )
        .toList(growable: false);
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.routingTitle)),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    secondary: SettingsLeadingIcon(
                      icon: Icons.shield_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.blockLeaksTitle),
                    subtitle: Text(l10n.blockLeaksSubtitle),
                    value: blockLeaks,
                    onChanged: commands.setBlockLeaks,
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    secondary: SettingsLeadingIcon(
                      icon: Icons.lan_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.bypassLocalNetworkTitle),
                    subtitle: Text(l10n.bypassLocalNetworkSubtitle),
                    value: bypassLocalNetwork,
                    onChanged: commands.setBypassLocalNetwork,
                  ),
                ],
              ),
            ),
            const Gap(settingsIslandGap),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: SettingsLeadingIcon(
                  icon: Icons.alt_route_rounded,
                  color: cs.primary,
                ),
                title: Text(l10n.trafficRulesSettingsTitle),
                subtitle: Text(
                  trafficRulePreset == TrafficRulePreset.none
                      ? l10n.trafficRulesNone
                      : _trafficRulePresetTitle(l10n, trafficRulePreset),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openTrafficRules,
              ),
            ),
            const Gap(settingsIslandGap),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: SettingsLeadingIcon(
                  icon: Icons.folder_copy_rounded,
                  color: cs.primary,
                ),
                title: Text(l10n.routingRuleFilesSettingsTitle),
                subtitle: Text(
                  russiaRouteDataStatus.available
                      ? l10n.routingRuleFilesSettingsReady(
                          russiaRouteDataStatus
                              .verifiedFiles
                              .length,
                        )
                      : l10n.routingRuleFilesSettingsPreparing,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openRoutingRuleFiles,
              ),
            ),
            const Gap(settingsIslandGap),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SettingsLeadingIcon(
                          icon: Icons.block_rounded,
                          color: cs.primary,
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.adBlockTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                l10n.adBlockSubtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    _AdBlockStatusPanel(
                      status: adBlockStatus,
                      busy: _adBlockBusy,
                      progress: _adBlockProgress,
                      l10n: l10n,
                    ),
                    const Gap(12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _adBlockBusy
                                ? null
                                : () => _downloadAdBlock(),
                            icon: _adBlockBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    adBlockStatus.available
                                        ? Icons.refresh_rounded
                                        : Icons.download_rounded,
                                  ),
                            label: Text(
                              adBlockStatus.available
                                  ? l10n.adBlockUpdateAction
                                  : l10n.adBlockDownloadAction,
                            ),
                          ),
                        ),
                        if (adBlockStatus.available) ...[
                          const Gap(10),
                          OutlinedButton(
                            onPressed: _adBlockBusy ? null : _deleteAdBlock,
                            child: Text(l10n.delete),
                          ),
                        ],
                      ],
                    ),
                    const Gap(12),
                    _CompactSwitchRow(
                      icon: Icons.shield_moon_rounded,
                      title: l10n.adBlockEnableTitle,
                      subtitle: adBlockStatus.available
                          ? l10n.adBlockEnabledSubtitle
                          : l10n.adBlockMissingSubtitle,
                      value: adBlockEnabled,
                      onChanged: _adBlockBusy ? null : _setAdBlock,
                    ),
                  ],
                ),
              ),
            ),
            const Gap(settingsIslandGap),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SettingsLeadingIcon(
                          icon: Icons.alt_route_rounded,
                          color: cs.primary,
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.splitRoutingTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                l10n.splitRoutingSubtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              if (!_splitRoutingTemporarilyDisabled &&
                                  !vpnInboundEnabled) ...[
                                const Gap(8),
                                _InlineWarning(text: l10n.splitRoutingTunOnly),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    if (_splitRoutingTemporarilyDisabled) ...[
                      _DisabledFeatureNotice(
                        title: l10n.splitRoutingUnavailableTitle,
                        message: l10n.splitRoutingUnavailableMessage,
                      ),
                      const Gap(18),
                    ],
                    IgnorePointer(
                      ignoring: _splitRoutingTemporarilyDisabled,
                      child: Opacity(
                        opacity: _splitRoutingTemporarilyDisabled ? .42 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.splitRoutingModeTitle,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Gap(10),
                            _RoutingModeCard(
                              icon: Icons.block_rounded,
                              title: l10n.splitRoutingModeDisabled,
                              subtitle: l10n.splitRoutingModeDisabledSubtitle,
                              selected:
                                  splitRoutingMode ==
                                  SplitRoutingMode.disabled,
                              onTap: _splitRoutingTemporarilyDisabled
                                  ? null
                                  : () => commands.setSplitRoutingMode(
                                        SplitRoutingMode.disabled,
                                      ),
                            ),
                            const Gap(10),
                            _RoutingModeCard(
                              icon: Icons.north_east_rounded,
                              title: l10n.splitRoutingModeProxySelected,
                              subtitle:
                                  l10n.splitRoutingModeProxySelectedSubtitle,
                              selected:
                                  splitRoutingMode ==
                                  SplitRoutingMode.proxySelected,
                              onTap: splitAvailable
                                  ? () => commands.setSplitRoutingMode(
                                        SplitRoutingMode.proxySelected,
                                      )
                                  : null,
                            ),
                            const Gap(10),
                            _RoutingModeCard(
                              icon: Icons.south_east_rounded,
                              title: l10n.splitRoutingModeBypassSelected,
                              subtitle:
                                  l10n.splitRoutingModeBypassSelectedSubtitle,
                              selected:
                                  splitRoutingMode ==
                                  SplitRoutingMode.bypassSelected,
                              onTap: splitAvailable
                                  ? () => commands.setSplitRoutingMode(
                                        SplitRoutingMode.bypassSelected,
                                      )
                                  : null,
                            ),
                            if (splitRoutingMode ==
                                SplitRoutingMode.bypassSelected) ...[
                              const Gap(10),
                              _InlineWarning(
                                text: l10n.splitRoutingLockdownWarning,
                              ),
                            ],
                            if (splitRoutingMode !=
                                SplitRoutingMode.disabled) ...[
                              const Gap(18),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.splitRoutingAppsTitle,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: .10),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      l10n.splitRoutingSelectedCount(
                                        selectedPackages.length,
                                      ),
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: cs.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(6),
                              Text(
                                l10n.splitRoutingAppVisibilityNotice,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const Gap(10),
                              if (isAndroid)
                                FilledButton.tonalIcon(
                                  onPressed: !_loadingInstalledApps
                                      ? _openAppPicker
                                      : null,
                                  icon: _loadingInstalledApps
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.apps_rounded),
                                  label: Text(l10n.splitRoutingPickAppsAction),
                                ),
                              if (!isAndroid) ...[
                                const Gap(8),
                                Text(
                                  l10n.splitRoutingAndroidOnly,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ] else if (_installedAppsError != null) ...[
                                const Gap(8),
                                Text(
                                  l10n.splitRoutingLoadAppsFailed,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.error,
                                  ),
                                ),
                              ],
                              const Gap(12),
                              _SelectedAppsPanel(
                                apps: selectedApps,
                                loadingMetadata: _loadingInstalledApps,
                                emptyTitle: l10n.splitRoutingNoAppsTitle,
                                emptySubtitle: l10n.splitRoutingNoAppsSubtitle,
                                unknownAppLabel:
                                    l10n.splitRoutingUnknownAppLabel,
                                loadingAppLabel:
                                    l10n.splitRoutingLoadingAppLabel,
                                onRemove: _removeSelectedPackage,
                              ),
                              const Gap(12),
                              Theme(
                                data: theme.copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: EdgeInsets.zero,
                                  initiallyExpanded: _manualEditorExpanded,
                                  onExpansionChanged: (expanded) {
                                    setState(() {
                                      _manualEditorExpanded = expanded;
                                    });
                                  },
                                  title: Text(
                                    l10n.splitRoutingManualEditorTitle,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    l10n.splitRoutingManualEditorSubtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  children: [
                                    const Gap(8),
                                    TextField(
                                      controller: _packagesController,
                                      minLines: 4,
                                      maxLines: 8,
                                      onTapOutside: (_) {
                                        FocusScope.of(context).unfocus();
                                        _commitPackages();
                                      },
                                      onEditingComplete: () {
                                        FocusScope.of(context).unfocus();
                                        _commitPackages();
                                      },
                                      decoration: InputDecoration(
                                        labelText:
                                            l10n.splitRoutingPackagesTitle,
                                        hintText: l10n.splitRoutingPackagesHint,
                                        helperText:
                                            l10n.splitRoutingPackagesHelper,
                                        alignLabelWithHint: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstalledApp {
  factory _InstalledApp({
    required String packageName,
    required String label,
    required bool system,
    required bool launchable,
  }) {
    final preparedLabel = _prepareAppSearchText(label);
    final preparedPackage = _prepareAppSearchText(packageName);
    return _InstalledApp._(
      packageName: packageName,
      label: label,
      system: system,
      launchable: launchable,
      normalizedLabel: preparedLabel.normalized,
      normalizedPackage: preparedPackage.normalized,
      compactLabel: preparedLabel.compact,
      compactPackage: preparedPackage.compact,
      searchWords: List<String>.unmodifiable(<String>[
        ...preparedLabel.words,
        ...preparedPackage.words,
      ]),
      compactSearchWords: List<String>.unmodifiable(<String>[
        ...preparedLabel.compactWords,
        ...preparedPackage.compactWords,
      ]),
    );
  }

  const _InstalledApp._({
    required this.packageName,
    required this.label,
    required this.system,
    required this.launchable,
    required this.normalizedLabel,
    required this.normalizedPackage,
    required this.compactLabel,
    required this.compactPackage,
    required this.searchWords,
    required this.compactSearchWords,
  });

  final String packageName;
  final String label;
  final bool system;
  final bool launchable;
  final String normalizedLabel;
  final String normalizedPackage;
  final String compactLabel;
  final String compactPackage;
  final List<String> searchWords;
  final List<String> compactSearchWords;

  String displayLabel(String fallback) {
    final normalized = label.trim();
    if (normalized.isEmpty ||
        normalized.toLowerCase() == packageName.trim().toLowerCase()) {
      return fallback;
    }
    return normalized;
  }

  factory _InstalledApp.fromMap(Map<String, dynamic> map) {
    return _InstalledApp(
      packageName: map['packageName']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      system: map['system'] == true,
      launchable: map['launchable'] == true,
    );
  }
}

class _InstalledAppIconCache {
  _InstalledAppIconCache({required this.maxEntries});

  final int maxEntries;
  final LinkedHashMap<String, Uint8List> _entries =
      LinkedHashMap<String, Uint8List>();

  Uint8List? get(String key) {
    final value = _entries.remove(key);
    if (value == null) {
      return null;
    }
    _entries[key] = value;
    return value;
  }

  void put(String key, Uint8List value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}

class _InstalledAppIcon extends StatefulWidget {
  const _InstalledAppIcon({
    required this.packageName,
    required this.system,
    this.size = 38,
  });

  final String packageName;
  final bool system;
  final double size;

  @override
  State<_InstalledAppIcon> createState() => _InstalledAppIconState();
}

class _InstalledAppIconState extends State<_InstalledAppIcon> {
  Uint8List? _bytes;
  int _generation = 0;
  int _pixelSize = 0;

  String get _cacheKey => '${widget.packageName}|$_pixelSize';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPixelSize = (widget.size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(48, 96);
    if (nextPixelSize != _pixelSize) {
      _pixelSize = nextPixelSize;
      _loadIcon();
    }
  }

  @override
  void didUpdateWidget(covariant _InstalledAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName ||
        oldWidget.size != widget.size) {
      _pixelSize = (widget.size * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(48, 96);
      _loadIcon();
    }
  }

  Future<void> _loadIcon() async {
    final key = _cacheKey;
    final cached = _installedAppIconCache.get(key);
    final generation = ++_generation;
    if (cached != null) {
      setState(() {
        _bytes = cached;
      });
      return;
    }
    setState(() {
      _bytes = null;
    });
    final bytes = await _loadInstalledAppIcon(
      key,
      widget.packageName,
      _pixelSize,
    );
    if (!mounted || generation != _generation) {
      return;
    }
    if (bytes != null && bytes.isNotEmpty) {
      _installedAppIconCache.put(key, bytes);
    }
    setState(() {
      _bytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) {
      return SettingsLeadingIcon(
        icon: widget.system ? Icons.memory_rounded : Icons.android_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: widget.size,
        iconSize: 18,
      );
    }
    return SizedBox.square(
      dimension: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

Future<Uint8List?> _loadInstalledAppIcon(
  String key,
  String packageName,
  int sizePx,
) {
  final inFlight = _installedAppIconLoads[key];
  if (inFlight != null) {
    return inFlight;
  }
  late final Future<Uint8List?> tracked;
  tracked = SingboxRuntime.instance
      .getInstalledAppIcon(packageName, sizePx: sizePx)
      .whenComplete(() {
        if (identical(_installedAppIconLoads[key], tracked)) {
          _installedAppIconLoads.remove(key);
        }
      });
  _installedAppIconLoads[key] = tracked;
  return tracked;
}

class _ScoredInstalledApp {
  const _ScoredInstalledApp(this.app, this.score, this.index);

  final _InstalledApp app;
  final int score;
  final int index;
}

class _InstalledAppSearchQuery {
  factory _InstalledAppSearchQuery(String rawValue) {
    final prepared = _prepareAppSearchText(rawValue);
    return _InstalledAppSearchQuery._(
      normalized: prepared.normalized,
      compact: prepared.compact,
      tokens: prepared.words,
    );
  }

  const _InstalledAppSearchQuery._({
    required this.normalized,
    required this.compact,
    required this.tokens,
  });

  final String normalized;
  final String compact;
  final List<String> tokens;
}

class _PreparedAppSearchText {
  const _PreparedAppSearchText({
    required this.normalized,
    required this.compact,
    required this.words,
    required this.compactWords,
  });

  final String normalized;
  final String compact;
  final List<String> words;
  final List<String> compactWords;
}

_PreparedAppSearchText _prepareAppSearchText(String value) {
  final lowercase = value.toLowerCase();
  final normalized = lowercase
      .replaceAll(_appSearchSeparatorsPattern, ' ')
      .replaceAll(_appSearchWhitespacePattern, ' ')
      .trim();
  final words = normalized.isEmpty
      ? const <String>[]
      : List<String>.unmodifiable(normalized.split(' '));
  final compactWords = List<String>.unmodifiable(
    words
        .map((word) => word.replaceAll(_appSearchNonAlphaNumericPattern, ''))
        .where((word) => word.isNotEmpty),
  );
  return _PreparedAppSearchText(
    normalized: normalized,
    compact: lowercase.replaceAll(_appSearchNonAlphaNumericPattern, ''),
    words: words,
    compactWords: compactWords,
  );
}

int _installedAppSearchScore(_InstalledApp app, String rawQuery) {
  return _installedAppSearchScorePrepared(
    app,
    _InstalledAppSearchQuery(rawQuery),
  );
}

int _installedAppSearchScorePrepared(
  _InstalledApp app,
  _InstalledAppSearchQuery search,
) {
  final query = search.normalized;
  if (query.isEmpty) {
    return 0;
  }
  final queryCompact = search.compact;
  final label = app.normalizedLabel;
  final packageName = app.normalizedPackage;
  final labelCompact = app.compactLabel;
  final packageCompact = app.compactPackage;
  final tokens = search.tokens;
  final words = app.searchWords;

  if (label == query || packageName == query) return 0;
  if (label.startsWith(query)) return 4;
  if (packageName.startsWith(query)) return 6;
  if (label.contains(query)) return 10;
  if (packageName.contains(query)) return 12;
  if (queryCompact.isNotEmpty &&
      (labelCompact.contains(queryCompact) ||
          packageCompact.contains(queryCompact))) {
    return 14;
  }
  if (tokens.isNotEmpty && _allTokensStartWithWords(tokens, words)) {
    return 18;
  }
  if (tokens.isNotEmpty && _allTokensContained(tokens, label, packageName)) {
    return 24;
  }
  if (queryCompact.length >= 3) {
    for (final word in app.compactSearchWords) {
      if (_isCloseAppSearchMatch(queryCompact, word)) {
        return 34;
      }
    }
  }
  return -1;
}

bool _allTokensStartWithWords(List<String> tokens, List<String> words) {
  for (final token in tokens) {
    var matched = false;
    for (final word in words) {
      if (word.startsWith(token)) {
        matched = true;
        break;
      }
    }
    if (!matched) {
      return false;
    }
  }
  return true;
}

bool _allTokensContained(
  List<String> tokens,
  String label,
  String packageName,
) {
  for (final token in tokens) {
    if (!label.contains(token) && !packageName.contains(token)) {
      return false;
    }
  }
  return true;
}

@visibleForTesting
int installedAppSearchScoreForTest({
  required String label,
  required String packageName,
  required String query,
}) {
  return _installedAppSearchScore(
    _InstalledApp(
      packageName: packageName,
      label: label,
      system: false,
      launchable: true,
    ),
    query,
  );
}

bool _isCloseAppSearchMatch(String query, String compactWord) {
  if (compactWord.length < 3) {
    return false;
  }
  if (compactWord.startsWith(query) || compactWord.contains(query)) {
    return true;
  }
  final lengthDelta = (compactWord.length - query.length).abs();
  if (lengthDelta > 2) {
    return false;
  }
  return _boundedEditDistance(query, compactWord, 2) <= 2;
}

int _boundedEditDistance(String a, String b, int maxDistance) {
  if ((a.length - b.length).abs() > maxDistance) {
    return maxDistance + 1;
  }
  var previous = List<int>.generate(b.length + 1, (index) => index);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowMin = i;
    for (var j = 1; j <= b.length; j++) {
      final substitutionCost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1)
          ? 0
          : 1;
      final deletion = previous[j] + 1;
      final insertion = current[j - 1] + 1;
      final substitution = previous[j - 1] + substitutionCost;
      var value = deletion < insertion ? deletion : insertion;
      if (substitution < value) {
        value = substitution;
      }
      current[j] = value;
      if (value < rowMin) {
        rowMin = value;
      }
    }
    if (rowMin > maxDistance) {
      return maxDistance + 1;
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

class _RoutingModeCard extends StatelessWidget {
  const _RoutingModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: .10)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              SettingsLeadingIcon(
                icon: icon,
                color: !enabled
                    ? cs.onSurfaceVariant.withValues(alpha: .55)
                    : selected
                    ? cs.primary
                    : cs.onSurfaceVariant,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: enabled ? null : cs.onSurfaceVariant,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(
                          alpha: enabled ? 1 : .7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: !enabled
                    ? cs.onSurfaceVariant.withValues(alpha: .55)
                    : selected
                    ? cs.primary
                    : cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.onTertiaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DisabledFeatureNotice extends StatelessWidget {
  const _DisabledFeatureNotice({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: .64),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: .24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.construction_rounded, color: cs.onErrorContainer),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(3),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedAppsPanel extends StatelessWidget {
  const _SelectedAppsPanel({
    required this.apps,
    required this.loadingMetadata,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.unknownAppLabel,
    required this.loadingAppLabel,
    required this.onRemove,
  });

  final List<_InstalledApp> apps;
  final bool loadingMetadata;
  final String emptyTitle;
  final String emptySubtitle;
  final String unknownAppLabel;
  final String loadingAppLabel;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (apps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emptyTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(4),
            Text(
              emptySubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: SizedBox(
        height: (apps.length * 66.0).clamp(66.0, 396.0),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: apps.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final app = apps[index];
            return ListTile(
              dense: true,
              minVerticalPadding: 8,
              titleAlignment: ListTileTitleAlignment.center,
              contentPadding: EdgeInsets.zero,
              leading: _InstalledAppIcon(
                packageName: app.packageName,
                system: app.system,
                size: 38,
              ),
              title: Text(
                app.displayLabel(
                  loadingMetadata && app.label.trim().isEmpty
                      ? loadingAppLabel
                      : unknownAppLabel,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                app.packageName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () => onRemove(app.packageName),
                icon: const Icon(Icons.close_rounded),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AppPickerSheet extends StatefulWidget {
  const _AppPickerSheet({required this.apps, required this.initialSelected});

  final List<_InstalledApp> apps;
  final Set<String> initialSelected;

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  static const _searchDebounce = Duration(milliseconds: 150);

  late final TextEditingController _searchController;
  late final Set<String> _selected;
  Timer? _searchDebounceTimer;
  String _query = '';
  List<_InstalledApp> _visibleApps = const <_InstalledApp>[];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selected = Set<String>.from(widget.initialSelected);
    _rebuildVisibleApps();
  }

  @override
  void didUpdateWidget(covariant _AppPickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.apps, widget.apps)) {
      _rebuildVisibleApps();
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _rebuildVisibleApps() {
    if (_query.isEmpty) {
      _visibleApps = widget.apps;
      return;
    }
    final search = _InstalledAppSearchQuery(_query);
    final scoredApps = <_ScoredInstalledApp>[];
    for (var index = 0; index < widget.apps.length; index++) {
      final app = widget.apps[index];
      final score = _installedAppSearchScorePrepared(app, search);
      if (score >= 0) {
        scoredApps.add(_ScoredInstalledApp(app, score, index));
      }
    }
    scoredApps.sort((a, b) {
      final scoreCompare = a.score.compareTo(b.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.index.compareTo(b.index);
    });
    _visibleApps = scoredApps.map((entry) => entry.app).toList(growable: false);
  }

  void _onSearchChanged(String value) {
    final nextQuery = value.trim();
    _searchDebounceTimer?.cancel();
    if (nextQuery == _query) {
      return;
    }

    // Clearing a query should feel immediate. Non-empty searches wait for the
    // user to pause typing so a large installed-app list is not rescored and
    // resorted on every keystroke.
    if (nextQuery.isEmpty) {
      setState(() {
        _query = '';
        _rebuildVisibleApps();
      });
      return;
    }
    _searchDebounceTimer = Timer(_searchDebounce, () {
      if (!mounted || nextQuery == _query) {
        return;
      }
      setState(() {
        _query = nextQuery;
        _rebuildVisibleApps();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.splitRoutingPickAppsTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: Text(l10n.continueAction),
              ),
            ],
          ),
          const Gap(12),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l10n.splitRoutingSearchHint,
            ),
          ),
          const Gap(12),
          Expanded(
            child: ListView.builder(
              itemCount: _visibleApps.length,
              scrollCacheExtent: const ScrollCacheExtent.pixels(0),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              addSemanticIndexes: false,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemBuilder: (context, index) {
                final app = _visibleApps[index];
                final selected = _selected.contains(app.packageName);
                return CheckboxListTile(
                  value: selected,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.trailing,
                  secondary: _InstalledAppIcon(
                    packageName: app.packageName,
                    system: app.system,
                    size: 38,
                  ),
                  title: Text(
                    app.displayLabel(l10n.splitRoutingUnknownAppLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selected.add(app.packageName);
                      } else {
                        _selected.remove(app.packageName);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSwitchRow extends StatelessWidget {
  const _CompactSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .72)),
      ),
      child: Row(
        children: [
          SettingsLeadingIcon(icon: icon, color: cs.primary),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AdBlockStatusPanel extends StatelessWidget {
  const _AdBlockStatusPanel({
    required this.status,
    required this.busy,
    required this.progress,
    required this.l10n,
  });

  final AdBlockRuleSetStatus status;
  final bool busy;
  final AdBlockUpdateProgress? progress;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final updatedAt = status.downloadedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status.providerName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(10),
          Text(
            busy
                ? _stageLabel(l10n, progress?.stage)
                : status.available
                ? l10n.adBlockReadyStatus(status.blockedDomainCount)
                : l10n.adBlockMissingStatus,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(4),
          Text(
            busy
                ? _progressHint(l10n, progress)
                : status.available
                ? l10n.adBlockMeta(
                    updatedAt == null ? '—' : _formatDateTime(updatedAt),
                    status.allowedDomainCount,
                  )
                : l10n.adBlockMissingHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          if (busy) ...[
            const Gap(12),
            LinearProgressIndicator(minHeight: 4, value: progress?.fraction),
          ],
        ],
      ),
    );
  }

  static String _stageLabel(AppLocalizations l10n, AdBlockUpdateStage? stage) =>
      switch (stage) {
        AdBlockUpdateStage.connecting => l10n.adBlockStageConnecting,
        AdBlockUpdateStage.retryingWithoutVpn =>
          l10n.remoteDownloadRetryWithoutVpn,
        AdBlockUpdateStage.downloading => l10n.adBlockStageDownloading,
        AdBlockUpdateStage.compiling => l10n.adBlockStageCompiling,
        AdBlockUpdateStage.activating => l10n.adBlockStageActivating,
        AdBlockUpdateStage.complete => l10n.adBlockStageComplete,
        null => l10n.adBlockDownloadingStatus,
      };

  static String _progressHint(
    AppLocalizations l10n,
    AdBlockUpdateProgress? progress,
  ) {
    if (progress == null || progress.completedBytes <= 0) {
      if (progress?.stage == AdBlockUpdateStage.retryingWithoutVpn) {
        return l10n.remoteDownloadRetryWithoutVpnHint;
      }
      return l10n.adBlockPreparingHint;
    }
    final completed = _RussiaRouteDataStatusPanel._formatBytes(
      progress.completedBytes,
    );
    if (progress.totalBytes <= 0) {
      return l10n.adBlockDownloadedProgress(completed);
    }
    final total = _RussiaRouteDataStatusPanel._formatBytes(progress.totalBytes);
    final eta = progress.estimatedSecondsRemaining;
    return eta == null
        ? l10n.adBlockDownloadProgress(completed, total)
        : l10n.adBlockDownloadProgressEta(completed, total, eta);
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }
}

class _RussiaRouteDataStatusPanel extends StatelessWidget {
  const _RussiaRouteDataStatusPanel({
    required this.status,
    required this.busy,
    required this.progress,
    required this.l10n,
  });

  final RussiaRouteDataStatus status;
  final bool busy;
  final RussiaRouteUpdateProgress? progress;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final releaseTimestamp = parseRussiaRouteVersionTimestamp(
      status.releaseTag ?? status.versionTag,
    );
    final verifiedAt = releaseTimestamp ?? status.verifiedAt;
    final versionLabel = releaseTimestamp == null
        ? status.versionTag.replaceFirst('bundled-', '')
        : _AdBlockStatusPanel._formatDateTime(releaseTimestamp);
    final routeSource =
        status.sourceKind == RussiaRouteDataService.sourceKindLive
        ? l10n.russiaRoutesLiveSource
        : l10n.russiaRoutesBundledSource;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.russiaRoutesRunetFreedomBadge,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.secondary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.russiaRoutesDomainListBadge,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Gap(10),
          Text(
            busy
                ? _stageLabel(l10n, progress?.stage)
                : status.available
                ? l10n.russiaRoutesReadyStatus(versionLabel)
                : l10n.russiaRoutesMissingStatus,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(4),
          Text(
            busy
                ? _progressHint(l10n, progress)
                : status.available
                ? l10n.russiaRoutesReadyHint
                : l10n.russiaRoutesMissingHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          if (status.available) ...[
            const Gap(4),
            Text(
              l10n.russiaRoutesSourceMeta(
                routeSource,
                verifiedAt == null
                    ? '—'
                    : _AdBlockStatusPanel._formatDateTime(verifiedAt),
                status.verifiedFiles.length,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
          if (busy) ...[
            const Gap(12),
            LinearProgressIndicator(minHeight: 4, value: progress?.fraction),
          ],
        ],
      ),
    );
  }

  static String _stageLabel(
    AppLocalizations l10n,
    RussiaRouteUpdateStage? stage,
  ) => switch (stage) {
    RussiaRouteUpdateStage.checking => l10n.russiaRoutesStageChecking,
    RussiaRouteUpdateStage.retryingWithoutVpn =>
      l10n.remoteDownloadRetryWithoutVpn,
    RussiaRouteUpdateStage.downloadingPackage =>
      l10n.russiaRoutesStageDownloading,
    RussiaRouteUpdateStage.verifyingPackage => l10n.russiaRoutesStageVerifying,
    RussiaRouteUpdateStage.extractingPackage =>
      l10n.russiaRoutesStageExtracting,
    RussiaRouteUpdateStage.downloadingCategories =>
      l10n.russiaRoutesStageCategories,
    RussiaRouteUpdateStage.compiling => l10n.russiaRoutesStageCompiling,
    RussiaRouteUpdateStage.activating => l10n.russiaRoutesStageActivating,
    RussiaRouteUpdateStage.complete => l10n.russiaRoutesStageComplete,
    null => l10n.russiaRoutesPreparingStatus,
  };

  static String _progressHint(
    AppLocalizations l10n,
    RussiaRouteUpdateProgress? progress,
  ) {
    if (progress == null) return l10n.russiaRoutesPreparingHint;
    if (progress.stage == RussiaRouteUpdateStage.retryingWithoutVpn) {
      return l10n.remoteDownloadRetryWithoutVpnHint;
    }
    if (progress.totalBytes > 0) {
      return l10n.russiaRoutesDownloadProgress(
        _formatBytes(progress.completedBytes),
        _formatBytes(progress.totalBytes),
      );
    }
    if (progress.totalItems > 0) {
      return l10n.russiaRoutesItemsProgress(
        progress.completedItems,
        progress.totalItems,
      );
    }
    if (progress.completedItems > 0) {
      return l10n.russiaRoutesItemsProcessed(progress.completedItems);
    }
    return l10n.russiaRoutesPreparingHint;
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
