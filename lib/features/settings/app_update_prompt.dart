import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/core/formatting.dart';
import 'package:meow_client/core/network/remote_download_error_message.dart';
import 'package:meow_client/core/network/vpn_aware_remote_download.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/release_notes_card.dart';

class AppUpdatePromptHost extends StatefulWidget {
  const AppUpdatePromptHost({
    super.key,
    required this.offer,
    required this.service,
    required this.navigatorKey,
    required this.installMode,
    required this.install,
    required this.child,
  });

  final ValueListenable<AppUpdateCheckResult?> offer;
  final AppUpdateService service;
  final GlobalKey<NavigatorState> navigatorKey;
  final AppUpdateInstallMode installMode;
  final Future<void> Function() install;
  final Widget child;

  @override
  State<AppUpdatePromptHost> createState() => _AppUpdatePromptHostState();
}

class _AppUpdatePromptHostState extends State<AppUpdatePromptHost>
    with WidgetsBindingObserver {
  AppUpdateCheckResult? _offer;
  AppUpdateDownloadOperation? _operation;
  Object? _announced;
  bool _sheetOpen = false;
  bool _dismissed = false;
  bool _downloaded = false;
  bool _installing = false;
  bool _autoInstallPending = false;

  Object _offerKey(AppUpdateInfo info) =>
      (info.tagName, info.buildNumber, info.channel, info.asset.name);

  bool get _foreground => switch (WidgetsBinding.instance.lifecycleState) {
    null || AppLifecycleState.resumed => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.offer.addListener(_onOfferChanged);
    _onOfferChanged();
  }

  @override
  void didUpdateWidget(covariant AppUpdatePromptHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offer != widget.offer) {
      oldWidget.offer.removeListener(_onOfferChanged);
      widget.offer.addListener(_onOfferChanged);
      _onOfferChanged();
    }
  }

  @override
  void dispose() {
    widget.offer.removeListener(_onOfferChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_autoInstallPending) {
      unawaited(_install());
    } else {
      _scheduleAnnouncement();
    }
  }

  void _onOfferChanged() {
    final offer = widget.offer.value;
    if (_operation != null) return;
    setState(() {
      _offer = offer;
      _downloaded = offer?.status == AppUpdateStatus.downloaded;
    });
    _scheduleAnnouncement();
  }

  void _scheduleAnnouncement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final info = _offer?.info;
      if (!mounted ||
          !_foreground ||
          _dismissed ||
          _sheetOpen ||
          _operation != null ||
          info == null ||
          widget.navigatorKey.currentState?.overlay == null) {
        return;
      }
      final key = _offerKey(info);
      if (_announced == key) return;
      _announced = key;
      unawaited(_showOffer());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _showOffer() async {
    final context = widget.navigatorKey.currentState?.overlay?.context;
    final info = _offer?.info;
    if (context == null ||
        info == null ||
        _dismissed ||
        _sheetOpen ||
        _operation != null) {
      return;
    }
    final downloaded = _downloaded;
    setState(() => _sheetOpen = true);
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      constraints: const BoxConstraints(maxWidth: 560),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => AppUpdateOfferSheet(info: info, downloaded: downloaded),
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    final current = _offer?.info;
    if (accepted != true ||
        current == null ||
        _offerKey(current) != _offerKey(info)) {
      _scheduleAnnouncement();
      return;
    }
    if (downloaded) {
      await _install();
    } else {
      await _download(info);
    }
  }

  Future<void> _download(AppUpdateInfo info) async {
    if (_operation != null) return;
    try {
      final ownsDownload = widget.service.activeDownload == null;
      final operation = widget.service.startDownload(info);
      setState(() => _operation = operation);
      await operation.completed;
      if (!mounted) return;
      setState(() => _downloaded = true);
      if (ownsDownload && widget.installMode == AppUpdateInstallMode.auto) {
        _autoInstallPending = true;
      }
    } on RemoteDownloadCancelled {
      // The service has already stopped the writer and removed the partial APK.
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _operation = null);
    }
    if (mounted && _foreground && _autoInstallPending) await _install();
  }

  Future<void> _install() async {
    if (_installing || !_downloaded || _operation != null) return;
    _autoInstallPending = false;
    setState(() => _installing = true);
    try {
      await widget.install();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  void _showError(Object error) {
    final context = widget.navigatorKey.currentState?.overlay?.context;
    if (!mounted || context == null) return;
    AppNotice.show(
      context,
      remoteDownloadErrorMessage(AppLocalizations.of(context), error) ??
          error.toString(),
      tone: AppNoticeTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _offer?.info;
    final operation = _operation;
    final visible =
        !_dismissed && _announced != null && info != null && !_sheetOpen;
    return Column(
      children: [
        Expanded(child: widget.child),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            alignment: Alignment.bottomCenter,
            sizeFactor: animation,
            child: child,
          ),
          child: visible
              ? AppUpdateDownloadBar(
                  key: const ValueKey('app-update-bar'),
                  info: info,
                  operation: operation,
                  downloaded: _downloaded,
                  installing: _installing,
                  onOpen: _downloaded ? _install : _showOffer,
                  onDismiss: () => setState(() => _dismissed = true),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class AppUpdateOfferSheet extends StatelessWidget {
  const AppUpdateOfferSheet({
    super.key,
    required this.info,
    this.downloaded = false,
  });

  final AppUpdateInfo info;
  final bool downloaded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final prerelease =
        info.isPrerelease ||
        AppUpdateService.isPrereleaseVersion(info.displayVersion);
    final abi = switch (info.asset.androidAbi) {
      'arm64-v8a' => 'ARMv8 (64-bit)',
      'armeabi-v7a' => 'ARMv7 (32-bit)',
      'x86_64' => 'x86_64',
      'universal' => l10n.updatesUniversalApk,
      _ => 'APK',
    };
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .79,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('app-update-changelog'),
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Etonify',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            info.displayVersion,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (prerelease)
                            Tooltip(
                              message: l10n.updatesPrereleaseVersionTooltip,
                              child: Icon(
                                Icons.science_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.memory_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                abi,
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                info.asset.sizeBytes > 0
                                    ? formatBytes(
                                        info.asset.sizeBytes.toDouble(),
                                      )
                                    : l10n.updatesUnknownSize,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ReleaseNotesCard(
                      body: info.body,
                      useCard: false,
                      limitBody: false,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: const StadiumBorder(),
              ),
              child: Text(
                downloaded
                    ? l10n.updatesInstallAction
                    : l10n.updatesDownloadAction,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              child: Text(l10n.updatesLaterAction),
            ),
          ],
        ),
      ),
    );
  }
}

class AppUpdateDownloadBar extends StatelessWidget {
  const AppUpdateDownloadBar({
    super.key,
    required this.info,
    required this.operation,
    required this.downloaded,
    required this.installing,
    required this.onOpen,
    required this.onDismiss,
  });

  final AppUpdateInfo info;
  final AppUpdateDownloadOperation? operation;
  final bool downloaded;
  final bool installing;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final operation = this.operation;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: operation == null
            ? _content(context, null)
            : ListenableBuilder(
                listenable: operation,
                builder: (context, _) => _content(context, operation),
              ),
      ),
    );
  }

  Widget _content(BuildContext context, AppUpdateDownloadOperation? operation) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = operation?.progress;
    final received = progress?.downloadedBytes ?? 0;
    final total = (progress?.totalBytes ?? 0) > 0
        ? progress!.totalBytes
        : info.asset.sizeBytes;
    final size = total > 0
        ? formatBytes(total.toDouble())
        : l10n.updatesUnknownSize;
    final fraction = total > 0
        ? (received / total).clamp(0.0, 1.0).toDouble()
        : null;
    final stage = operation?.isCancelling == true
        ? l10n.updatesCancellingDownload
        : switch (progress?.stage) {
            AppUpdateDownloadStage.cleaning => l10n.updatesStageCleaning,
            AppUpdateDownloadStage.verifying => l10n.updatesStageVerifying,
            AppUpdateDownloadStage.retryingWithoutVpn ||
            AppUpdateDownloadStage.downloading ||
            AppUpdateDownloadStage.ready => l10n.updatesDownloadingTitle,
            null =>
              installing
                  ? l10n.updatesOpeningInstaller
                  : downloaded
                  ? l10n.updatesInstallAction
                  : l10n.updatesEtonifyTitle,
          };
    final VoidCallback? action = operation != null
        ? (operation.canCancel ? operation.cancel : null)
        : (installing ? null : onOpen);
    final body = InkWell(
      onTap: action,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 12, 8),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (operation != null)
                      CircularProgressIndicator(
                        value: fraction,
                        strokeWidth: 2.5,
                      ),
                    Icon(
                      downloaded
                          ? Icons.system_update_alt_rounded
                          : Icons.arrow_downward_rounded,
                      size: 17,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  operation == null
                      ? info.displayVersion
                      : total > 0
                      ? l10n.updatesProgressBytes(
                          formatBytes(received.toDouble()),
                          size,
                        )
                      : formatBytes(received.toDouble()),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: operation?.canCancel == true
              ? Tooltip(message: l10n.updatesCancelDownload, child: body)
              : body,
        ),
        if (operation == null && !installing)
          IconButton(
            tooltip: l10n.close,
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    );
  }
}
