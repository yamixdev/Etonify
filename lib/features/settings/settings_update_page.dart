import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/network/remote_download_error_message.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/update/app_update_channel.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';
import 'package:meow_client/widgets/release_notes_card.dart';

class SettingsUpdatePage extends StatefulWidget {
  const SettingsUpdatePage({
    super.key,
    required this.currentVersion,
    this.installMode = AppUpdateInstallMode.ask,
    this.updateChannel = AppUpdateChannel.stable,
    this.onInstallModeChanged,
    this.onUpdateChannelChanged,
  });

  final String currentVersion;
  final AppUpdateInstallMode installMode;
  final AppUpdateChannel updateChannel;
  final ValueChanged<AppUpdateInstallMode>? onInstallModeChanged;
  final ValueChanged<AppUpdateChannel>? onUpdateChannelChanged;

  @override
  State<SettingsUpdatePage> createState() => _SettingsUpdatePageState();
}

class _SettingsUpdatePageState extends State<SettingsUpdatePage>
    with WidgetsBindingObserver {
  AppUpdateCheckResult? _result;
  AppUpdateDownloadProgress? _downloadProgress;
  bool _checking = false;
  bool _downloading = false;
  bool _installing = false;
  bool _clearingUpdateCache = false;
  bool? _canInstallApks;
  AppUpdateVerificationResult? _verification;
  String? _downloadedFilePath;
  late String _currentVersion = widget.currentVersion;
  int _currentVersionCode = 0;
  late AppUpdateInstallMode _installMode = widget.installMode;
  late AppUpdateChannel _updateChannel = widget.updateChannel;
  AppUpdateInfo? _pendingAutoInstallInfo;
  bool _resumingAutoInstall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshInstalledVersion());
      unawaited(_resumePendingAutoInstall());
    }
  }

  Future<void> _resumePendingAutoInstall() async {
    if (_resumingAutoInstall) return;
    _resumingAutoInstall = true;
    try {
      final canInstall = await _refreshInstallPermissionStatus(
        showFeedback: true,
      );
      final pending = _pendingAutoInstallInfo;
      if (!canInstall || pending == null || !mounted || _downloading) return;
      _pendingAutoInstallInfo = null;
      await _download(pending, installAfterDownload: true);
    } finally {
      _resumingAutoInstall = false;
    }
  }

  Future<void> _bootstrap() async {
    await _refreshInstalledVersion();
    await _check(manual: false);
  }

  Future<void> _refreshInstalledVersion() async {
    final info = await SingboxRuntime.instance.getAppVersionInfo();
    if (!mounted) return;
    final next = info.displayVersion;
    final nextBuildNumber = info.updateBuildNumber;
    if (next != _currentVersion || nextBuildNumber != _currentVersionCode) {
      setState(() {
        _currentVersion = next;
        _currentVersionCode = nextBuildNumber;
      });
    }
  }

  Future<void> _check({required bool manual}) async {
    if (_checking || _downloading || _clearingUpdateCache) return;
    await _refreshInstalledVersion();
    if (!mounted || _checking || _downloading || _clearingUpdateCache) return;
    setState(() {
      _checking = true;
      if (manual) {
        _downloadProgress = null;
      }
    });
    final result = await AppUpdateService.instance.checkForUpdates(
      currentVersion: _currentVersion,
      currentBuildNumber: _currentVersionCode,
      manual: manual,
      channel: _updateChannel,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _checking = false;
      _downloadedFilePath = result.downloadedFilePath;
    });
    await _refreshDownloadedVerification();
  }

  String _channelName(AppLocalizations l10n, AppUpdateChannel channel) =>
      switch (channel) {
        AppUpdateChannel.stable => l10n.updatesChannelStable,
        AppUpdateChannel.beta => l10n.updatesChannelBeta,
      };

  Future<void> _chooseUpdateChannel() async {
    if (_checking || _downloading || _installing || _clearingUpdateCache) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = await showModalBottomSheet<AppUpdateChannel>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.updatesChannelTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Gap(8),
              _UpdateChannelTile(
                channel: AppUpdateChannel.stable,
                selected: _updateChannel == AppUpdateChannel.stable,
                title: l10n.updatesChannelStable,
                subtitle: l10n.updatesChannelStableSubtitle,
                icon: Icons.verified_rounded,
              ),
              _UpdateChannelTile(
                channel: AppUpdateChannel.beta,
                selected: _updateChannel == AppUpdateChannel.beta,
                title: l10n.updatesChannelBeta,
                subtitle: l10n.updatesChannelBetaSubtitle,
                icon: Icons.science_rounded,
              ),
              const Gap(8),
              Text(
                l10n.updatesChannelBetaWarning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected == _updateChannel || !mounted) return;
    setState(() {
      _updateChannel = selected;
      _result = null;
      _downloadProgress = null;
      _downloadedFilePath = null;
      _verification = null;
    });
    widget.onUpdateChannelChanged?.call(selected);
    await _check(manual: true);
  }

  Future<void> _startUpdateFlow(AppUpdateInfo info) async {
    if (_downloading || _checking || _clearingUpdateCache) return;
    var mode = _installMode;
    if (mode == AppUpdateInstallMode.ask) {
      final decision = await _showInstallModeSheet();
      if (decision == null || !mounted) return;
      mode = decision.mode;
      if (decision.remember) {
        setState(() => _installMode = mode);
        widget.onInstallModeChanged?.call(mode);
      }
    }

    if (mode == AppUpdateInstallMode.auto) {
      _pendingAutoInstallInfo = info;
      final canInstall = await _ensureInstallPermission();
      if (!canInstall || !mounted) return;
      _pendingAutoInstallInfo = null;
    }
    await _download(
      info,
      installAfterDownload: mode == AppUpdateInstallMode.auto,
    );
  }

  Future<_InstallModeDecision?> _showInstallModeSheet() {
    final l10n = AppLocalizations.of(context);
    var selected = AppUpdateInstallMode.auto;
    var remember = false;
    return showModalBottomSheet<_InstallModeDecision>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget option({
              required AppUpdateInstallMode value,
              required IconData icon,
              required String title,
              required String subtitle,
            }) {
              return RadioListTile<AppUpdateInstallMode>(
                value: value,
                secondary: Icon(icon),
                title: Text(title),
                subtitle: Text(subtitle),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.updatesInstallMethodTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(8),
                    RadioGroup<AppUpdateInstallMode>(
                      groupValue: selected,
                      onChanged: (next) {
                        if (next == null) return;
                        setSheetState(() => selected = next);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          option(
                            value: AppUpdateInstallMode.manual,
                            icon: Icons.download_done_rounded,
                            title: l10n.updatesInstallMethodManualTitle,
                            subtitle: l10n.updatesInstallMethodManualSubtitle,
                          ),
                          option(
                            value: AppUpdateInstallMode.auto,
                            icon: Icons.install_mobile_rounded,
                            title: l10n.updatesInstallMethodAutoTitle,
                            subtitle: l10n.updatesInstallMethodAutoSubtitle,
                          ),
                        ],
                      ),
                    ),
                    CheckboxListTile(
                      value: remember,
                      onChanged: (value) {
                        setSheetState(() => remember = value ?? false);
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.updatesInstallMethodRemember),
                    ),
                    const Gap(8),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        _InstallModeDecision(
                          mode: selected,
                          remember: remember,
                        ),
                      ),
                      child: Text(l10n.continueAction),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _download(
    AppUpdateInfo info, {
    bool installAfterDownload = false,
  }) async {
    if (_downloading || _checking || _clearingUpdateCache) return;
    setState(() {
      _downloading = true;
      _verification = null;
      _downloadProgress = const AppUpdateDownloadProgress(
        downloadedBytes: 0,
        totalBytes: 0,
        bytesPerSecond: 0,
        done: false,
      );
    });
    try {
      await AppUpdateService.instance.downloadUpdate(
        info,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _downloadProgress = progress);
        },
      );
      if (!mounted) return;
      final filePath = _downloadProgress?.filePath;
      final verification = filePath == null
          ? null
          : await AppUpdateService.instance.verifyDownloadedApk(info, filePath);
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _downloadedFilePath = filePath;
        _verification = verification;
        _result = AppUpdateCheckResult(
          status: AppUpdateStatus.downloaded,
          checkedAt: DateTime.now(),
          info: info,
          downloadedFilePath: filePath,
        );
      });
      if (installAfterDownload) {
        await _installDownloaded();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _result = AppUpdateCheckResult(
          status: AppUpdateStatus.error,
          checkedAt: DateTime.now(),
          info: info,
          error:
              remoteDownloadErrorMessage(AppLocalizations.of(context), error) ??
              error.toString(),
        );
      });
    }
  }

  Future<void> _installDownloaded() async {
    if (_checking || _downloading || _installing || _clearingUpdateCache) {
      return;
    }
    final path = _cachedInstallerPath ?? '';
    if (path.isEmpty) {
      setState(() {
        _result = AppUpdateCheckResult(
          status: AppUpdateStatus.error,
          checkedAt: DateTime.now(),
          info: _result?.info,
          error: AppLocalizations.of(context).updatesDownloadedFileMissing,
        );
      });
      return;
    }
    await _refreshDownloadedVerification();
    if (!mounted) return;
    if (_verification?.ok == false) {
      setState(() {
        _result = AppUpdateCheckResult(
          status: AppUpdateStatus.error,
          checkedAt: DateTime.now(),
          info: _result?.info,
          error: _verification?.error,
          downloadedFilePath: path,
        );
      });
      return;
    }
    setState(() => _installing = true);
    try {
      final canInstall = await _ensureInstallPermission();
      if (!canInstall) {
        setState(() => _installing = false);
        return;
      }
      await SingboxRuntime.instance.installDownloadedApk();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _result = AppUpdateCheckResult(
          status: AppUpdateStatus.error,
          checkedAt: DateTime.now(),
          info: _result?.info,
          error: error.toString(),
          downloadedFilePath: path,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _installing = false);
      }
    }
  }

  Future<void> _refreshDownloadedVerification() async {
    final info = _result?.info;
    final path = _cachedInstallerPath;
    if (info == null || path == null) {
      if (mounted) setState(() => _verification = null);
      return;
    }
    final verification = await AppUpdateService.instance.verifyDownloadedApk(
      info,
      path,
    );
    if (!mounted) return;
    setState(() => _verification = verification);
  }

  Future<bool> _refreshInstallPermissionStatus({
    bool showFeedback = false,
  }) async {
    final canInstall = await SingboxRuntime.instance.canInstallApks();
    if (!mounted) return canInstall;
    final previous = _canInstallApks;
    setState(() => _canInstallApks = canInstall);
    if (showFeedback && previous == false && canInstall) {
      AppNotice.show(
        context,
        AppLocalizations.of(context).updatesInstallPermissionGranted,
        tone: AppNoticeTone.success,
      );
    }
    return canInstall;
  }

  Future<bool> _ensureInstallPermission() async {
    final canInstall = await _refreshInstallPermissionStatus();
    if (canInstall || !mounted) return canInstall;
    final l10n = AppLocalizations.of(context);
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.updatesInstallPermissionTitle),
        content: Text(l10n.updatesInstallPermissionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.updatesInstallPermissionOpen),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await SingboxRuntime.instance.openApkInstallSettings();
    }
    return false;
  }

  String? get _cachedInstallerPath {
    final savedPath = _downloadedFilePath?.trim();
    if (savedPath != null && savedPath.isNotEmpty) return savedPath;
    final progressPath = _downloadProgress?.filePath?.trim();
    if (progressPath != null && progressPath.isNotEmpty) return progressPath;
    return null;
  }

  Future<void> _deleteCachedInstaller() async {
    if (_checking || _downloading || _installing || _clearingUpdateCache) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final version = _result?.info?.displayVersion.trim().isNotEmpty == true
        ? 'v${_result!.info!.displayVersion}'
        : _currentVersion;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.updatesDeleteCachedApkTitle),
        content: Text(l10n.updatesDeleteCachedApkMessage(version)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_sweep_rounded),
            label: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearingUpdateCache = true);
    final deleted = await AppUpdateService.instance.deleteCachedInstallers(
      currentVersion: _currentVersion,
      currentBuildNumber: _currentVersionCode,
    );
    final metadata = await AppUpdateService.instance.loadMetadata();
    if (!mounted) return;
    setState(() {
      _clearingUpdateCache = false;
      _downloadedFilePath = null;
      _downloadProgress = null;
      _verification = null;
      _result = AppUpdateCheckResult(
        status: metadata.lastStatus,
        checkedAt: metadata.lastCheckAt ?? DateTime.now(),
        info: metadata.latestInfo,
        error: metadata.lastError,
      );
    });
    AppNotice.show(
      context,
      l10n.updatesDeleteCachedApkDone(deleted),
      tone: AppNoticeTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = _result;
    final info = result?.info;
    final cachedInstallerPath = _cachedInstallerPath;

    return ProgressiveBlurScaffold(
      appBar: AppBar(
        title: Text(l10n.updatesTitle),
        actions: [
          UpdateOverflowMenu(
            enabled: !_checking && !_downloading && !_installing,
            checkLabel: l10n.updatesCheckAction,
            channelLabel: l10n.updatesChannelMenuAction,
            currentChannelLabel: _channelName(l10n, _updateChannel),
            onCheck: () => _check(manual: true),
            onChangeChannel: _chooseUpdateChannel,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          settingsScreenPadding.left,
          progressiveHeaderTopPadding(context, 24),
          settingsScreenPadding.right,
          appBottomSafePadding(context, 112),
        ),
        children: [
          _UpdateHero(
            checking: _checking,
            title: _titleFor(context, result),
            subtitle: _subtitleFor(context, result),
          ),
          const Gap(18),
          _UpdateInfoCard(
            currentVersion: _currentVersion,
            info: info,
            checkedAt: result?.checkedAt,
            action: _UpdateActionButton(
              result: result,
              checking: _checking,
              downloading: _downloading,
              installing: _installing,
              onCheck: () => _check(manual: true),
              onDownload: info == null ? null : () => _startUpdateFlow(info),
              onInstall: cachedInstallerPath == null
                  ? null
                  : _installDownloaded,
            ),
            verification: _verification,
            cacheAction: cachedInstallerPath == null
                ? null
                : _CachedInstallerButton(
                    clearing: _clearingUpdateCache,
                    onDelete: _deleteCachedInstaller,
                  ),
          ),
          if (_downloading || _downloadProgress != null) ...[
            const Gap(12),
            _DownloadProgressCard(progress: _downloadProgress),
          ],
          if (info != null) ...[
            const Gap(12),
            ReleaseNotesCard(body: info.body),
          ],
          if (result?.status == AppUpdateStatus.error) ...[
            const Gap(12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  result?.error?.trim().isNotEmpty == true
                      ? result!.error!
                      : l10n.updatesErrorSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.colorScheme.surface,
    );
  }

  String _titleFor(BuildContext context, AppUpdateCheckResult? result) {
    final l10n = AppLocalizations.of(context);
    if (_checking) return 'Etonify';
    if (_downloading) return l10n.updatesDownloadingTitle;
    return switch (result?.status) {
      AppUpdateStatus.updateAvailable => l10n.updatesAvailableTitle,
      AppUpdateStatus.unsupportedAndroid => l10n.updatesUnsupportedAndroidTitle,
      AppUpdateStatus.downloaded => l10n.updatesDownloadedTitle,
      AppUpdateStatus.upToDate => l10n.updatesUpToDateTitle,
      AppUpdateStatus.currentVersionNewer =>
        l10n.updatesCurrentVersionNewerTitle,
      AppUpdateStatus.noReleaseAvailable => l10n.updatesNoChannelReleaseTitle,
      AppUpdateStatus.error => l10n.updatesErrorTitle,
      _ => l10n.updatesTitle,
    };
  }

  String _subtitleFor(BuildContext context, AppUpdateCheckResult? result) {
    final l10n = AppLocalizations.of(context);
    if (_checking) return l10n.updatesChecking;
    if (_downloading) return l10n.updatesDownloadWarning;
    final info = result?.info;
    return switch (result?.status) {
      AppUpdateStatus.updateAvailable when info != null =>
        l10n.updatesAvailableSubtitle(
          info.displayVersion,
          _formatBytes(info.asset.sizeBytes, l10n),
        ),
      AppUpdateStatus.unsupportedAndroid when info != null =>
        l10n.updatesUnsupportedAndroidSubtitle(
          info.displayVersion,
          info.minimumAndroidSdk ?? 0,
        ),
      AppUpdateStatus.downloaded => l10n.updatesDownloadedSubtitle(
        (_downloadedFilePath ?? _downloadProgress?.filePath) == null
            ? ''
            : File(
                (_downloadedFilePath ?? _downloadProgress!.filePath)!,
              ).uri.pathSegments.last,
      ),
      AppUpdateStatus.upToDate => l10n.updatesUpToDateSubtitle(_currentVersion),
      AppUpdateStatus.currentVersionNewer when info != null =>
        l10n.updatesCurrentVersionNewerSubtitle(
          _versionWithBuild(_currentVersion, _currentVersionCode),
          _versionWithBuild(info.displayVersion, info.buildNumber),
        ),
      AppUpdateStatus.noReleaseAvailable =>
        _updateChannel == AppUpdateChannel.beta
            ? l10n.updatesNoBetaReleaseSubtitle
            : l10n.updatesNoStableReleaseSubtitle,
      AppUpdateStatus.error => l10n.updatesErrorSubtitle,
      _ => l10n.updatesSubtitle,
    };
  }

  String _versionWithBuild(String version, int? buildNumber) {
    if (buildNumber == null || buildNumber <= 0) return version;
    return '$version+$buildNumber';
  }
}

class _InstallModeDecision {
  const _InstallModeDecision({required this.mode, required this.remember});

  final AppUpdateInstallMode mode;
  final bool remember;
}

enum _UpdateMenuAction { check, channel }

class UpdateOverflowMenu extends StatelessWidget {
  const UpdateOverflowMenu({
    super.key,
    required this.enabled,
    required this.checkLabel,
    required this.channelLabel,
    required this.currentChannelLabel,
    required this.onCheck,
    required this.onChangeChannel,
  });

  final bool enabled;
  final String checkLabel;
  final String channelLabel;
  final String currentChannelLabel;
  final VoidCallback onCheck;
  final VoidCallback onChangeChannel;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_UpdateMenuAction>(
      key: const ValueKey('update-overflow-menu'),
      enabled: enabled,
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) {
        switch (action) {
          case _UpdateMenuAction.check:
            onCheck();
          case _UpdateMenuAction.channel:
            onChangeChannel();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_UpdateMenuAction>(
          key: const ValueKey('update-menu-check'),
          value: _UpdateMenuAction.check,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.refresh_rounded),
            title: Text(checkLabel),
          ),
        ),
        PopupMenuItem<_UpdateMenuAction>(
          key: const ValueKey('update-menu-channel'),
          value: _UpdateMenuAction.channel,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_rounded),
            title: Text(channelLabel),
            subtitle: Text(currentChannelLabel),
          ),
        ),
      ],
    );
  }
}

class _UpdateChannelTile extends StatelessWidget {
  const _UpdateChannelTile({
    required this.channel,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final AppUpdateChannel channel;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: selected ? theme.colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: () => Navigator.of(context).pop(channel),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: selected ? const Icon(Icons.check_rounded) : null,
      ),
    );
  }
}

class _UpdateActionButton extends StatelessWidget {
  const _UpdateActionButton({
    required this.result,
    required this.checking,
    required this.downloading,
    required this.installing,
    required this.onCheck,
    required this.onDownload,
    required this.onInstall,
  });

  final AppUpdateCheckResult? result;
  final bool checking;
  final bool downloading;
  final bool installing;
  final VoidCallback onCheck;
  final VoidCallback? onDownload;
  final VoidCallback? onInstall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (downloading || installing) {
      return Text(
        installing ? l10n.updatesOpeningInstaller : l10n.updatesDownloadWarning,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (result?.status == AppUpdateStatus.downloaded) {
      return FilledButton.icon(
        onPressed: checking ? null : onInstall,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        icon: const Icon(Icons.install_mobile_rounded),
        label: Text(
          l10n.updatesInstallAction,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (result?.status == AppUpdateStatus.updateAvailable) {
      return FilledButton(
        onPressed: checking ? null : onDownload,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        child: Text(
          l10n.updatesDownloadAction,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (result?.status == AppUpdateStatus.error) {
      return FilledButton.tonal(
        onPressed: checking ? null : onCheck,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        child: Text(
          l10n.updatesRetryAction,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (result?.status == AppUpdateStatus.unsupportedAndroid) {
      return OutlinedButton(
        onPressed: checking ? null : onCheck,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(l10n.updatesCheckAction),
      );
    }
    return OutlinedButton(
      onPressed: checking ? null : onCheck,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: Text(
        l10n.updatesCheckAction,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CachedInstallerButton extends StatelessWidget {
  const _CachedInstallerButton({
    required this.clearing,
    required this.onDelete,
  });

  final bool clearing;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      onPressed: clearing ? null : onDelete,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
      icon: clearing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : const Icon(Icons.delete_sweep_rounded),
      label: Text(
        l10n.updatesDeleteCachedApkAction,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _UpdateHero extends StatelessWidget {
  const _UpdateHero({
    required this.checking,
    required this.title,
    required this.subtitle,
  });

  final bool checking;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final compact = MediaQuery.sizeOf(context).height < 720;
    return Padding(
      padding: EdgeInsets.fromLTRB(6, compact ? 18 : 44, 6, compact ? 18 : 34),
      child: Column(
        children: [
          Text(
            'Etonify',
            style: theme.textTheme.displaySmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          Gap(compact ? 10 : 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: checking
                ? SizedBox(
                    key: const ValueKey('checking'),
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: cs.primary,
                    ),
                  )
                : Text(
                    key: ValueKey(title),
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          Gap(compact ? 8 : 14),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateInfoCard extends StatelessWidget {
  const _UpdateInfoCard({
    required this.currentVersion,
    required this.info,
    required this.checkedAt,
    required this.action,
    required this.verification,
    required this.cacheAction,
  });

  final String currentVersion;
  final AppUpdateInfo? info;
  final DateTime? checkedAt;
  final Widget action;
  final AppUpdateVerificationResult? verification;
  final Widget? cacheAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: l10n.updatesCurrentVersion, value: currentVersion),
            const Gap(8),
            _InfoRow(
              label: l10n.updatesLatestVersion,
              value: info?.displayVersion ?? '—',
            ),
            const Gap(14),
            action,
            if (cacheAction != null) ...[const Gap(8), cacheAction!],
            if (verification != null) ...[
              const Gap(10),
              _InfoRow(
                label: l10n.updatesApkVerificationTitle,
                value: verification!.checksumAvailable
                    ? verification!.ok
                          ? l10n.updatesApkVerificationVerified
                          : l10n.updatesApkVerificationFailed
                    : l10n.updatesApkVerificationUnavailable,
                valueMaxLines: 2,
              ),
            ],
            const Gap(8),
            _InfoRow(
              label: l10n.updatesAsset,
              value: info?.asset.name ?? '—',
              valueMaxLines: 2,
              vertical: true,
            ),
            if (checkedAt != null) ...[
              const Gap(8),
              Text(
                l10n.updatesLastChecked(_formatTime(checkedAt!)),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DownloadProgressCard extends StatelessWidget {
  const _DownloadProgressCard({required this.progress});

  final AppUpdateDownloadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final value = progress?.fraction;
    final downloaded = _formatBytes(progress?.downloadedBytes ?? 0, l10n);
    final total = progress?.totalBytes != null && progress!.totalBytes > 0
        ? _formatBytes(progress!.totalBytes, l10n)
        : l10n.updatesUnknownSize;
    final eta = _formatEta(context, progress?.etaSeconds);
    final stage = progress?.stage ?? AppUpdateDownloadStage.downloading;
    final title = switch (stage) {
      AppUpdateDownloadStage.cleaning => l10n.updatesStageCleaning,
      AppUpdateDownloadStage.retryingWithoutVpn =>
        l10n.remoteDownloadRetryWithoutVpn,
      AppUpdateDownloadStage.downloading => l10n.updatesDownloadingTitle,
      AppUpdateDownloadStage.verifying => l10n.updatesStageVerifying,
      AppUpdateDownloadStage.ready => l10n.updatesDownloadedTitle,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Gap(12),
            LinearProgressIndicator(value: value, minHeight: 4),
            const Gap(10),
            if (stage == AppUpdateDownloadStage.retryingWithoutVpn)
              Text(l10n.remoteDownloadRetryWithoutVpnHint),
            if (stage == AppUpdateDownloadStage.downloading)
              Text(l10n.updatesProgressBytes(downloaded, total)),
            if (stage == AppUpdateDownloadStage.downloading &&
                progress != null &&
                progress!.bytesPerSecond > 0) ...[
              const Gap(4),
              Text(
                l10n.updatesProgressSpeedEta(
                  _formatBytes(progress!.bytesPerSecond.round(), l10n),
                  eta,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueMaxLines = 1,
    this.vertical = false,
  });

  final String label;
  final String value;
  final int valueMaxLines;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const Gap(4),
          Text(
            value,
            maxLines: valueMaxLines,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const Gap(12),
        Flexible(
          child: Text(
            value,
            maxLines: valueMaxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}

String _formatBytes(int bytes, AppLocalizations l10n) {
  if (bytes <= 0) return l10n.updatesUnknownSize;
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

String _formatEta(BuildContext context, int? seconds) {
  final l10n = AppLocalizations.of(context);
  if (seconds == null || seconds < 0) return '—';
  if (seconds < 60) return l10n.updatesEtaSeconds(seconds);
  return l10n.updatesEtaMinutes(seconds ~/ 60, seconds % 60);
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
