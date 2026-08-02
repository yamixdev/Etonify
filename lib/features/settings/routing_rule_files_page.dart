import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/network/remote_download_error_message.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

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
    final source = _status.sourceKind == RussiaRouteDataService.sourceKindLive
        ? l10n.russiaRoutesLiveSource
        : l10n.russiaRoutesBundledSource;

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
                          icon: Icons.folder_copy_rounded,
                          color: cs.primary,
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _status.available
                                    ? l10n.routingRuleFilesReadyTitle
                                    : l10n.routingRuleFilesPreparingTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                _status.available
                                    ? l10n.routingRuleFilesReadySubtitle
                                    : l10n.routingRuleFilesPreparingSubtitle,
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
                    Container(
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
                          Text(
                            _busy
                                ? _stageLabel(l10n, _progress?.stage)
                                : l10n.routingRuleFilesSourceTitle,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            _busy
                                ? _progressText(l10n)
                                : _status.available
                                ? l10n.routingRuleFilesSourceMeta(
                                    source,
                                    _status.versionTag,
                                    _files.length,
                                  )
                                : l10n.routingRuleFilesPreparingSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                          if (_busy) ...[
                            const Gap(10),
                            LinearProgressIndicator(
                              value: _progress?.fraction,
                              minHeight: 4,
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
                    const Gap(12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _busy ? null : _refresh,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(
                          _busy
                              ? l10n.routingRuleFilesUpdatingAction
                              : l10n.routingRuleFilesUpdateAction,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(settingsIslandGap),
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
              for (final file in _files) ...[
                _RoutingRuleFileCard(file: file),
                const Gap(settingsIslandGap),
              ],
          ],
        ),
      ),
    );
  }
}

class _RoutingRuleFileCard extends StatelessWidget {
  const _RoutingRuleFileCard({required this.file});

  final RussiaRouteDataFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SettingsLeadingIcon(
          icon: file.isGeoIp ? Icons.public_rounded : Icons.language_rounded,
          color: cs.primary,
        ),
        title: Text(
          file.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${_formatBytes(file.sizeBytes)} · ${_formatDateTime(file.updatedAt)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        trailing: Icon(Icons.verified_rounded, color: cs.primary),
      ),
    );
  }
}

String _stageLabel(
  AppLocalizations l10n,
  RussiaRouteUpdateStage? stage,
) => switch (stage) {
  RussiaRouteUpdateStage.checking => l10n.russiaRoutesStageChecking,
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

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}
