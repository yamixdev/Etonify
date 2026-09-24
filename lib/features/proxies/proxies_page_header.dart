part of 'proxies_page.dart';

/// Width of the strip at the bottom of the header where the backdrop fades
/// out, so rows dissolve under it instead of stopping on a hard edge.
const _kProxySheetHeaderEdgeFade = 10.0;

/// Backdrop painted behind the pinned header, which list rows scroll under.
///
/// Stays fully opaque across the whole header except for the last
/// [_kProxySheetHeaderEdgeFade] pixels: this gradient is the only thing
/// separating the header from the list, so any transparency inside the title's
/// band draws row text through the title and the progress line.
LinearGradient _proxySheetHeaderGradient(Color surface, double height) {
  final fadeStart = ((height - _kProxySheetHeaderEdgeFade) / height).clamp(
    0.0,
    1.0,
  );
  return LinearGradient(
    colors: [surface, surface, surface.withValues(alpha: 0)],
    stops: [0, fadeStart, 1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class _ProxySheetHeaderBackdrop extends StatelessWidget {
  const _ProxySheetHeaderBackdrop({
    required this.enabled,
    required this.cornerRadius,
    required this.height,
    required this.child,
  });

  final bool enabled;
  final double cornerRadius;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).scaffoldBackgroundColor;
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(cornerRadius),
    );
    if (!enabled) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _proxySheetHeaderGradient(color, height),
            ),
            child: child,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        child: RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: height,
                child: IgnorePointer(
                  child: _ProxySheetProgressiveBlur(height: height),
                ),
              ),
              Positioned(left: 0, right: 0, top: 0, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header backdrop for device tiers that opt in to the layered sheet.
class _ProxySheetProgressiveBlur extends StatelessWidget {
  const _ProxySheetProgressiveBlur({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _proxySheetHeaderGradient(
          Theme.of(context).scaffoldBackgroundColor,
          height,
        ),
      ),
    );
  }
}

class _ProxySheetHeader extends StatelessWidget {
  const _ProxySheetHeader({
    required this.height,
    required this.progress,
    required this.scrollCollapse,
    required this.canFillScreen,
    required this.activeProxy,
    required this.activeProxyHideIp,
    required this.l10n,
    required this.sort,
    required this.connected,
    required this.serverCount,
    required this.urlTestInFlight,
    this.urlTestInFlightListenable,
    this.urlTestProgressListenable,
    required this.hapticEnabled,
    required this.speedBytesPerSecond,
    required this.trafficBytes,
    required this.trafficListenable,
    required this.onSortSelected,
    required this.onUrlTest,
    required this.onRefreshIp,
    required this.onTap,
  });

  final double height;
  final double progress;
  final double scrollCollapse;
  final bool canFillScreen;
  final AppProxySummary? activeProxy;
  final bool activeProxyHideIp;
  final AppLocalizations l10n;
  final ProxySort sort;
  final bool connected;
  final int serverCount;
  final bool urlTestInFlight;
  final ValueListenable<bool>? urlTestInFlightListenable;
  final ValueListenable<UrlTestProgressState>? urlTestProgressListenable;
  final bool hapticEnabled;
  final double speedBytesPerSecond;
  final double trafficBytes;
  final ValueListenable<TrafficUiSnapshot>? trafficListenable;
  final ValueChanged<ProxySort> onSortSelected;
  final Future<void> Function() onUrlTest;
  final VoidCallback? onRefreshIp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolbarOpacity = ((progress - .48) / .28).clamp(0.0, 1.0).toDouble();
    final headerOpacity = Curves.easeOutCubic.transform(toolbarOpacity);
    final collapse = Curves.easeOutCubic.transform(
      scrollCollapse.clamp(0.0, 1.0).toDouble(),
    );
    final handleOpacity = canFillScreen
        ? (1 - Curves.easeInCubic.transform(scrollCollapse))
              .clamp(0.0, 1.0)
              .toDouble()
        : (1 - collapse * .72).clamp(0.0, 1.0).toDouble();
    final activeProxyFade = (1 - (progress / .34)).clamp(0.0, 1.0).toDouble();
    final activeProxyOpacity = Curves.easeOutCubic.transform(activeProxyFade);
    final showHandle = handleOpacity >= .08;
    final toolbarTop = lerpDouble(18, 8, collapse)!;
    final toolbarBottom = lerpDouble(0, 4, collapse)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        key: const ValueKey('proxy-sheet-header'),
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (showHandle)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: const AppBottomSheetDragHandle(),
                ),
              ),
            if (activeProxy != null)
              Positioned(
                left: 16,
                right: 16,
                top: 24,
                bottom: 4,
                child: IgnorePointer(
                  ignoring: activeProxyOpacity < .85,
                  child: Opacity(
                    opacity: activeProxyOpacity,
                    child: trafficListenable == null
                        ? _ActiveProxyLabel(
                            connected: connected,
                            proxy: activeProxy!,
                            hideIp: activeProxyHideIp,
                            hapticEnabled: hapticEnabled,
                            speedBytesPerSecond: speedBytesPerSecond,
                            trafficBytes: trafficBytes,
                            unknownText: '—',
                            onRefreshIp: onRefreshIp,
                          )
                        : ValueListenableBuilder<TrafficUiSnapshot>(
                            valueListenable: trafficListenable!,
                            builder: (context, traffic, _) {
                              return _ActiveProxyLabel(
                                connected: connected,
                                proxy: activeProxy!,
                                hideIp: activeProxyHideIp,
                                hapticEnabled: hapticEnabled,
                                speedBytesPerSecond:
                                    traffic.speedBytesPerSecond,
                                trafficBytes: traffic.trafficBytes,
                                unknownText: '—',
                                onRefreshIp: onRefreshIp,
                              );
                            },
                          ),
                  ),
                ),
              ),
            Positioned(
              left: 96,
              right: 96,
              top: toolbarTop,
              bottom: toolbarBottom,
              child: Opacity(
                opacity: headerOpacity,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.proxiesTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (urlTestProgressListenable != null)
                        ValueListenableBuilder<UrlTestProgressState>(
                          valueListenable: urlTestProgressListenable!,
                          builder: (context, progressState, _) {
                            if (!connected &&
                                !(progressState.isOfflineSession &&
                                    (progressState.isRunning ||
                                        progressState.isPaused ||
                                        progressState.hasResults))) {
                              if (serverCount <= 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  l10n.proxiesTotal(serverCount),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            }
                            final showProgress =
                                progressState.total > 0 &&
                                (progressState.isRunning ||
                                    progressState.hasResults ||
                                    progressState.isCancelled);
                            if (!showProgress) {
                              return const SizedBox.shrink();
                            }
                            final showTested =
                                progressState.isRunning ||
                                progressState.isCancelled ||
                                progressState.tested < progressState.total;
                            final workingColor =
                                theme.brightness == Brightness.dark
                                ? Colors.lightGreen
                                : Colors.green;
                            return Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l10n.proxiesProgressWorking(
                                      progressState.working,
                                      progressState.total,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: workingColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (showTested || progressState.isPaused)
                                    Text(
                                      progressState.isPaused
                                          ? l10n.proxiesCheckPaused
                                          : l10n.proxiesProgressTested(
                                              progressState.tested,
                                              progressState.total,
                                            ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  const SizedBox(height: 3),
                                  _ProxyTestProgressBar(
                                    key: const ValueKey(
                                      'proxy-test-progress-bar',
                                    ),
                                    total: progressState.total,
                                    working: progressState.working,
                                    failed: progressState.failed,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: toolbarTop,
              bottom: toolbarBottom,
              child: IgnorePointer(
                ignoring: headerOpacity < .85,
                child: Opacity(
                  opacity: headerOpacity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onTap,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      icon: const Icon(FluentIcons.chevron_left_24_regular),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: toolbarTop,
              bottom: toolbarBottom,
              child: IgnorePointer(
                ignoring: headerOpacity < .85,
                child: Opacity(
                  opacity: headerOpacity,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (serverCount > 0)
                          urlTestInFlightListenable != null
                              ? ValueListenableBuilder<bool>(
                                  valueListenable: urlTestInFlightListenable!,
                                  builder: (context, inFlight, _) =>
                                      _buildUrlTestButton(
                                        l10n: l10n,
                                        inFlight: inFlight,
                                      ),
                                )
                              : _buildUrlTestButton(
                                  l10n: l10n,
                                  inFlight: urlTestInFlight,
                                ),
                        IconButton(
                          tooltip: l10n.sort,
                          onPressed: () => _showProxySortPicker(
                            context,
                            l10n: l10n,
                            current: sort,
                            onSelected: onSortSelected,
                          ),
                          icon: const Icon(FluentIcons.arrow_sort_24_regular),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlTestButton({
    required AppLocalizations l10n,
    required bool inFlight,
  }) {
    return IconButton(
      onPressed: () => onUrlTest(),
      tooltip: inFlight ? l10n.cancel : l10n.urlTestTitle,
      icon: Icon(
        inFlight ? FluentIcons.dismiss_24_filled : FluentIcons.flash_24_filled,
      ),
    );
  }
}

class _ActiveProxyLabel extends StatelessWidget {
  const _ActiveProxyLabel({
    required this.connected,
    required this.proxy,
    required this.hideIp,
    required this.hapticEnabled,
    required this.speedBytesPerSecond,
    required this.trafficBytes,
    required this.unknownText,
    required this.onRefreshIp,
  });

  final bool connected;
  final AppProxySummary proxy;
  final bool hideIp;
  final bool hapticEnabled;
  final double speedBytesPerSecond;
  final double trafficBytes;
  final String unknownText;
  final VoidCallback? onRefreshIp;

  String _maskIp(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.*.*';
    }
    if (ip.length > 8) {
      return '${ip.substring(0, ip.length ~/ 2)}****';
    }
    return ip;
  }

  String get _displayIp {
    if (!connected) return '—';
    final ip = proxy.ip;
    if (ip.isEmpty) return unknownText;
    if (hideIp) return _maskIp(ip);
    return ip;
  }

  void _refreshIp() {
    if (!connected || onRefreshIp == null) return;
    if (hapticEnabled) {
      HapticFeedback.lightImpact();
    }
    onRefreshIp?.call();
  }

  Widget _ipDisplay(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    if (connected && proxy.ipChecking && proxy.ip.trim().isEmpty) {
      return IpRefreshDots(
        key: const ValueKey('ip-refresh-checking'),
        color: color,
      );
    }
    return Text(
      _displayIp,
      key: ValueKey(_displayIp),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final speedText = formatSpeed(connected ? speedBytesPerSecond : 0);
    final trafficText = formatBytes(connected ? trafficBytes : 0);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 74),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CountryFlagBadge(countryCode: proxy.countryCode, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [...previousChildren, ?currentChild],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.12),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _localizedProxyTitle(l10n, proxy),
                          key: ValueKey(_localizedProxyTitle(l10n, proxy)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: connected ? _refreshIp : null,
                    child: SizedBox(
                      height: 24,
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.centerLeft,
                              children: [...previousChildren, ?currentChild],
                            );
                          },
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.12),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _ipDisplay(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActiveProxyStatLine(
                  icon: FluentIcons.arrow_download_20_regular,
                  text: speedText,
                ),
                const SizedBox(height: 8),
                _ActiveProxyStatLine(
                  icon: FluentIcons.arrow_bidirectional_up_down_20_regular,
                  text: trafficText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveProxyStatLine extends StatelessWidget {
  const _ActiveProxyStatLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }
}

class _AddProxyChainTile extends StatelessWidget {
  const _AddProxyChainTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                FluentIcons.link_add_24_regular,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '+ ${l10n.proxyChainAddTile}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProxyListDivider extends StatelessWidget {
  const _ProxyListDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('proxy-list-divider'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.center,
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _ProxyTestProgressBar extends StatelessWidget {
  const _ProxyTestProgressBar({
    super.key,
    required this.total,
    required this.working,
    required this.failed,
  });

  final int total;
  final int working;
  final int failed;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final workingColor = theme.brightness == Brightness.dark
        ? Colors.lightGreen
        : Colors.green;
    final failedColor = theme.colorScheme.error;
    final pendingColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.38,
    );

    final safeWorking = working.clamp(0, total);
    final safeFailed = failed.clamp(0, total - safeWorking);
    final safePending = (total - safeWorking - safeFailed).clamp(0, total);

    return ClipRRect(
      borderRadius: BorderRadius.circular(1.5),
      child: SizedBox(
        height: 2.5,
        width: 140,
        child: Row(
          children: [
            if (safeWorking > 0)
              Expanded(
                flex: safeWorking,
                child: ColoredBox(color: workingColor),
              ),
            if (safeFailed > 0)
              Expanded(
                flex: safeFailed,
                child: ColoredBox(color: failedColor),
              ),
            if (safePending > 0)
              Expanded(
                flex: safePending,
                child: ColoredBox(color: pendingColor),
              ),
          ],
        ),
      ),
    );
  }
}
