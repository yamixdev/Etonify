import 'dart:async';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/core/formatting.dart';
import 'package:meow_client/core/network/remote_download_error_message.dart';
import 'package:meow_client/core/network/vpn_aware_remote_download.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/app_loading_indicator.dart';
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
      final previous = _offer?.info;
      final next = offer?.info;
      if (previous == null ||
          next == null ||
          _offerKey(previous) != _offerKey(next)) {
        _dismissed = false;
      }
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
          _downloaded ||
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
        _downloaded ||
        _sheetOpen ||
        _operation != null) {
      return;
    }
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
      builder: (_) => AppUpdateOfferSheet(info: info),
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    final current = _offer?.info;
    if (accepted != true ||
        current == null ||
        _downloaded ||
        _offerKey(current) != _offerKey(info)) {
      _scheduleAnnouncement();
      return;
    }
    await _download(info);
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
        info != null &&
        !_sheetOpen &&
        (_downloaded || (!_dismissed && _announced != null));
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
  const AppUpdateOfferSheet({super.key, required this.info});

  final AppUpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            Flexible(child: _AppUpdateChangelog(info: info)),
            const Divider(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: const StadiumBorder(),
              ),
              child: Text(l10n.updatesDownloadAction),
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

class _AppUpdateChangelog extends StatefulWidget {
  const _AppUpdateChangelog({required this.info});

  final AppUpdateInfo info;

  @override
  State<_AppUpdateChangelog> createState() => _AppUpdateChangelogState();
}

class _AppUpdateChangelogState extends State<_AppUpdateChangelog> {
  final _controller = ScrollController();
  final _scrolledUnder = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateScroll);
  }

  void _updateScroll() {
    _scrolledUnder.value = _controller.offset > 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrolledUnder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canBlur =
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.highContrastOf(context);
    final header = _AppUpdateHeader(info: widget.info);
    return LayoutBuilder(
      builder: (context, constraints) {
        final pinHeader =
            constraints.maxHeight >= 220 &&
            MediaQuery.textScalerOf(context).scale(20) <= 30;
        return CustomScrollView(
          key: const ValueKey('app-update-changelog'),
          controller: _controller,
          primary: false,
          shrinkWrap: true,
          slivers: [
            if (pinHeader)
              PinnedHeaderSliver(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _scrolledUnder,
                  child: header,
                  builder: (context, scrolledUnder, child) {
                    if (!scrolledUnder || !canBlur) {
                      return ColoredBox(
                        color: colors.surfaceContainerLow,
                        child: child,
                      );
                    }
                    return ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: ColoredBox(
                          color: colors.surfaceContainerLow.withValues(
                            alpha: .9,
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              SliverToBoxAdapter(child: header),
            SliverToBoxAdapter(
              child: ReleaseNotesCard(
                body: widget.info.body,
                useCard: false,
                limitBody: false,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AppUpdateHeader extends StatelessWidget {
  const _AppUpdateHeader({required this.info});

  final AppUpdateInfo info;

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
    return Column(
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.memory_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(abi, style: theme.textTheme.labelLarge)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.asset.sizeBytes > 0
                        ? formatBytes(info.asset.sizeBytes.toDouble())
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
      ],
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
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: operation != null
              ? ListenableBuilder(
                  listenable: operation,
                  builder: (context, _) => _progress(context, operation),
                )
              : downloaded
              ? _install(context)
              : _offer(context),
        ),
      ),
    );
  }

  Widget _install(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: FilledButton.icon(
        onPressed: installing ? null : onOpen,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        icon: installing
            ? const AppLoadingIndicator.compact(size: 18)
            : const Icon(Icons.system_update_alt_rounded),
        label: Text(
          installing ? l10n.updatesOpeningInstaller : l10n.updatesUpdateNow,
        ),
      ),
    );
  }

  Widget _offer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.arrow_downward_rounded, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.updatesEtonifyTitle,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      info.displayVersion,
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
        ),
        IconButton(
          tooltip: l10n.close,
          onPressed: onDismiss,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _progress(BuildContext context, AppUpdateDownloadOperation operation) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = operation.progress;
    final total = progress.totalBytes > 0
        ? progress.totalBytes
        : info.asset.sizeBytes;
    final fraction = total > 0
        ? (progress.downloadedBytes / total).clamp(0.0, 1.0)
        : null;
    final transferring = switch (progress.stage) {
      AppUpdateDownloadStage.retryingWithoutVpn ||
      AppUpdateDownloadStage.downloading => !operation.isCancelling,
      _ => false,
    };
    final stage = operation.isCancelling
        ? l10n.updatesCancellingDownload
        : switch (progress.stage) {
            AppUpdateDownloadStage.cleaning => l10n.updatesStageCleaning,
            AppUpdateDownloadStage.verifying => l10n.updatesStageVerifying,
            _ => l10n.updatesDownloadingTitle,
          };
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      stage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: AppLinearProgressIndicator(
                      value: transferring ? fraction : null,
                      semanticsLabel: stage,
                    ),
                  ),
                  if (fraction != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${(fraction * 100).round()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (operation.canCancel)
          IconButton(
            tooltip: l10n.updatesCancelDownload,
            onPressed: operation.cancel,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    );
  }
}
