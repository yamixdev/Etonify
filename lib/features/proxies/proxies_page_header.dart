part of 'proxies_page.dart';

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
    final theme = Theme.of(context);
    final color = theme.scaffoldBackgroundColor;
    final fallbackGradient = LinearGradient(
      colors: [
        color.withValues(alpha: .36),
        color.withValues(alpha: .18),
        Colors.transparent,
      ],
      stops: const [0, .72, 1],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    if (!enabled) {
      return ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(cornerRadius)),
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: fallbackGradient),
            child: child,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(cornerRadius)),
      child: SizedBox(
        height: height,
        child: RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (enabled)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: height,
                  child: const IgnorePointer(
                    child: _ProxySheetProgressiveBlur(),
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

/// Lightweight header merge effect for Android cool/balanced paths.
class _ProxySheetProgressiveBlur extends StatelessWidget {
  const _ProxySheetProgressiveBlur();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.scaffoldBackgroundColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.94),
            color.withValues(alpha: 0.70),
            color.withValues(alpha: 0.0),
          ],
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
              left: 16,
              right: 16,
              top: toolbarTop,
              bottom: toolbarBottom,
              child: Opacity(
                opacity: headerOpacity,
                child: Center(
                  child: Text(
                    l10n.proxiesTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
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
                        if (connected)
                          IconButton(
                            onPressed: () => onUrlTest(),
                            tooltip: l10n.urlTestTitle,
                            icon: const Icon(FluentIcons.flash_24_filled),
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
