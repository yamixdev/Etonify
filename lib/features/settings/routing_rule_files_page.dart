import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/network/remote_download_error_message.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows the on-device sing-box rule-set files separately from preset choice.
///
/// Rule selection stays lightweight: this screen owns preparing and refreshing
/// the bundled `.srs` files, while [TrafficRulesPage] only applies one preset.
class RoutingRuleFilesPage extends StatefulWidget {
  const RoutingRuleFilesPage({
    super.key,
    required this.currentStatus,
    required this.onRefresh,
  });

  final RussiaRouteDataStatus currentStatus;
  final Future<RussiaRouteDataStatus> Function() onRefresh;

  @override
  State<RoutingRuleFilesPage> createState() => _RoutingRuleFilesPageState();
}

class _RoutingRuleFilesPageState extends State<RoutingRuleFilesPage> {
  static final Uri _sourceUri = Uri.parse(
    RussiaRouteDataService.sourceRepositoryUrl,
  );

  late RussiaRouteDataStatus _status;
  List<RussiaRouteDataFile> _files = const <RussiaRouteDataFile>[];
  RussiaRouteUpdateProgress? _progress;
  DateTime? _operationStartedAt;
  Timer? _etaTicker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus;
    final service = RussiaRouteDataService.instance;
    _busy = service.isUpdating;
    _progress = service.progress.value;
    service.progress.addListener(_handleProgress);
    unawaited(_loadFiles());
    if (!_status.available && !_busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_refresh(initialPreparation: true));
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant RoutingRuleFilesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy && !identical(oldWidget.currentStatus, widget.currentStatus)) {
      _status = widget.currentStatus;
      unawaited(_loadFiles());
    }
  }

  @override
  void dispose() {
    _etaTicker?.cancel();
    RussiaRouteDataService.instance.progress.removeListener(_handleProgress);
    super.dispose();
  }

  void _handleProgress() {
    if (!mounted) return;
    final service = RussiaRouteDataService.instance;
    setState(() {
      _progress = service.progress.value;
      _busy = service.isUpdating || _busy;
    });
  }

  Future<void> _loadFiles() async {
    final files = await RussiaRouteDataService.instance.listInstalledFiles();
    if (!mounted) return;
    setState(() => _files = files);
  }

  Future<void> _openSource() async {
    final opened = await launchUrl(
      _sourceUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      AppNotice.show(
        context,
        AppLocalizations.of(context).routingRuleFilesOpenSourceFailed,
        tone: AppNoticeTone.error,
      );
    }
  }

  Future<void> _refresh({bool initialPreparation = false}) async {
    if (_busy) return;
    _operationStartedAt = DateTime.now();
    _etaTicker?.cancel();
    _etaTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _busy) {
        setState(() {});
      }
    });
    setState(() => _busy = true);
    try {
      final status = await widget.onRefresh();
      if (!mounted) return;
      setState(() => _status = status);
      await _loadFiles();
    } catch (error) {
      if (mounted && !initialPreparation) {
        AppNotice.show(
          context,
          remoteDownloadErrorMessage(AppLocalizations.of(context), error) ??
              AppLocalizations.of(context).trafficRulesPrepareFailed,
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      _etaTicker?.cancel();
      _etaTicker = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = RussiaRouteDataService.instance.progress.value;
          _operationStartedAt = null;
        });
      }
    }
  }

  String _progressText(AppLocalizations l10n) {
    final progress = _progress;
    if (progress == null) return l10n.russiaRoutesPreparingHint;
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

  String? _etaText(AppLocalizations l10n) {
    final progress = _progress;
    final startedAt = _operationStartedAt;
    if (progress == null || startedAt == null || progress.totalBytes <= 0) {
      return null;
    }
    final completed = progress.completedBytes;
    final remaining = progress.totalBytes - completed;
    final elapsed = DateTime.now().difference(startedAt);
    if (completed <= 0 || remaining <= 0 || elapsed.inSeconds < 2) {
      return null;
    }
    final bytesPerSecond = completed / elapsed.inMilliseconds * 1000;
    if (!bytesPerSecond.isFinite || bytesPerSecond <= 0) return null;
    final seconds = (remaining / bytesPerSecond).ceil();
    if (seconds <= 0) return null;
    return l10n.routingRuleFilesEta(_shortDuration(l10n, seconds));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalSizeBytes = _files.fold<int>(
      0,
      (total, file) => total + file.sizeBytes,
    );

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.routingRuleFilesTitle)),
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
            SettingsTileGroup(
              dividerIndent: 64,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  leading: SettingsLeadingIcon(
                    icon: Icons.folder_copy_rounded,
                    color: cs.primary,
                  ),
                  title: Text(
                    _busy
                        ? _stageLabel(l10n, _progress?.stage)
                        : _status.available
                        ? l10n.routingRuleFilesReadyTitle
                        : l10n.routingRuleFilesPreparingTitle,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _busy
                              ? _progressText(l10n)
                              : _status.available
                              ? l10n.routingRuleFilesReadySubtitle
                              : l10n.routingRuleFilesPreparingSubtitle,
                        ),
                        if (_busy) ...[
                          const Gap(10),
                          LinearProgressIndicator(
                            value: _progress?.fraction,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          if (_etaText(l10n) case final eta?) ...[
                            const Gap(6),
                            Text(
                              eta,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                _RouteMetadataTile(
                  icon: Icons.source_rounded,
                  label: l10n.routingRuleFilesSourceTitle,
                  value: l10n.russiaRoutesLiveSource,
                  trailingIcon: Icons.open_in_new_rounded,
                  onTap: _openSource,
                  link: true,
                ),
                _RouteMetadataTile(
                  icon: Icons.event_rounded,
                  label: l10n.routingRuleFilesVersionTitle,
                  value: _formatRouteVersion(_status.versionTag),
                ),
                _RouteMetadataTile(
                  icon: Icons.inventory_2_outlined,
                  label: l10n.routingRuleFilesCountTitle,
                  value: '${_files.length}',
                ),
                _RouteMetadataTile(
                  icon: Icons.data_usage_rounded,
                  label: l10n.routingRuleFilesTotalSizeTitle,
                  value: _formatBytes(totalSizeBytes),
                ),
                ListTile(
                  enabled: !_busy,
                  onTap: _busy ? null : _refresh,
                  leading: SettingsLeadingIcon(
                    icon: Icons.refresh_rounded,
                    color: cs.primary,
                    size: 36,
                    iconSize: 18,
                  ),
                  title: Text(
                    _busy
                        ? l10n.routingRuleFilesUpdatingAction
                        : l10n.routingRuleFilesUpdateAction,
                  ),
                  trailing: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                ),
              ],
            ),
            const Gap(settingsIslandGap),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                leading: SettingsLeadingIcon(
                  icon: Icons.travel_explore_rounded,
                  color: cs.tertiary,
                ),
                title: Text(l10n.routingRuleFilesScopeTitle),
                subtitle: Text(l10n.routingRuleFilesScopeSubtitle),
              ),
            ),
            const Gap(settingsSectionGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.routingRuleFilesListTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Gap(settingsSectionLabelGap),
            if (_files.isEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.folder_off_rounded),
                  title: Text(l10n.routingRuleFilesEmptyTitle),
                  subtitle: Text(l10n.routingRuleFilesEmptySubtitle),
                ),
              )
            else
              SettingsTileGroup(
                dividerIndent: 64,
                children: [
                  for (final file in _files) _RoutingRuleFileTile(file: file),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteMetadataTile extends StatelessWidget {
  const _RouteMetadataTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailingIcon,
    this.onTap,
    this.link = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final bool link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      link: link,
      button: onTap != null && !link,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        onTap: onTap,
        leading: SettingsLeadingIcon(
          icon: icon,
          color: cs.primary,
          size: 36,
          iconSize: 18,
        ),
        title: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .48,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onTap == null ? cs.onSurface : cs.primary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (trailingIcon case final icon?) ...[
                const Gap(6),
                Icon(icon, size: 18, color: cs.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutingRuleFileTile extends StatelessWidget {
  const _RoutingRuleFileTile({required this.file});

  final RussiaRouteDataFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: SettingsLeadingIcon(
        icon: file.isGeoIp ? Icons.public_rounded : Icons.language_rounded,
        color: file.isGeoIp ? cs.primary : cs.secondary,
        size: 36,
        iconSize: 18,
      ),
      title: Text(
        file.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Text(
        _formatBytes(file.sizeBytes),
        style: theme.textTheme.labelLarge?.copyWith(
          color: cs.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

String _stageLabel(
  AppLocalizations l10n,
  RussiaRouteUpdateStage? stage,
) => switch (stage) {
  RussiaRouteUpdateStage.checking => l10n.russiaRoutesStageChecking,
  RussiaRouteUpdateStage.retryingWithoutVpn =>
    l10n.remoteDownloadRetryWithoutVpn,
  RussiaRouteUpdateStage.downloadingPackage =>
    l10n.russiaRoutesStageDownloading,
  RussiaRouteUpdateStage.verifyingPackage => l10n.russiaRoutesStageVerifying,
  RussiaRouteUpdateStage.extractingPackage => l10n.russiaRoutesStageExtracting,
  RussiaRouteUpdateStage.downloadingCategories =>
    l10n.russiaRoutesStageCategories,
  RussiaRouteUpdateStage.compiling => l10n.russiaRoutesStageCompiling,
  RussiaRouteUpdateStage.activating => l10n.russiaRoutesStageActivating,
  RussiaRouteUpdateStage.complete => l10n.russiaRoutesStageComplete,
  null => l10n.russiaRoutesPreparingStatus,
};

String _shortDuration(AppLocalizations l10n, int seconds) {
  if (seconds >= 60) {
    return l10n.routingRuleFilesMinutesShort((seconds / 60).ceil());
  }
  return l10n.routingRuleFilesSecondsShort(seconds);
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

String _formatRouteVersion(String value) {
  final timestamp = parseRussiaRouteVersionTimestamp(value);
  if (timestamp == null) return value.replaceFirst('bundled-', '');
  final month = timestamp.month.toString().padLeft(2, '0');
  final day = timestamp.day.toString().padLeft(2, '0');
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  return '$day.$month.${timestamp.year} $hour:$minute';
}
