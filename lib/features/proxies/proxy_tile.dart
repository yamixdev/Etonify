part of 'proxies_page.dart';

class ProxyTile extends StatelessWidget {
  const ProxyTile({
    super.key,
    required this.proxy,
    required this.selected,
    required this.onTap,
    this.highlighted = false,
    this.titleOverride,
    this.subtitleOverride,
    this.forceBaseInset = false,
    this.animate = true,
    this.runtimeState,
    this.identityChild,
    this.onOpenGroup,
    this.onLongPress,
    this.onTestLatency,
  });

  final AppProxySummary proxy;
  final bool selected;
  final bool highlighted;
  final String? titleOverride;
  final String? subtitleOverride;
  final bool forceBaseInset;
  final bool animate;
  final ProxyRuntimeVisualState? runtimeState;
  final Widget? identityChild;
  final VoidCallback onTap;
  final ValueChanged<Rect>? onOpenGroup;
  final VoidCallback? onLongPress;
  final VoidCallback? onTestLatency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = runtimeState;
    final latencyFresh = state?.latencyFresh ?? proxy.latencyFresh;
    final latency = state == null ? proxy.latency : state.latency;
    final latencyChecking = state?.latencyChecking ?? proxy.latencyChecking;
    final latencyUnavailable =
        state?.latencyUnavailable ?? proxy.latencyUnavailable;
    final latencyError = state == null
        ? proxy.latencyError
        : state.latencyError;
    final hasLatencyError = latencyError?.trim().isNotEmpty == true;
    final highlighted = state?.highlighted ?? this.highlighted;
    final selecting = state?.selecting ?? false;
    final hasNoLatencyResult =
        !selecting &&
        !latencyChecking &&
        !latencyUnavailable &&
        latency == null;
    final latencyText = selecting
        ? l10n.proxySwitching
        : latencyChecking
        ? '... ms'
        : latency == null
        ? l10n.proxyLatencyNoResult
        : latency >= 1000
        ? '${(latency / 1000).toStringAsFixed(1)} s'
        : '$latency ms';
    final delayColor = selecting
        ? theme.colorScheme.primary
        : latencyChecking
        ? theme.colorScheme.primary
        : latencyUnavailable
        ? theme.colorScheme.error
        : !latencyFresh || latency == null
        ? theme.colorScheme.onSurfaceVariant
        : latency < 800
        ? (theme.brightness == Brightness.dark
              ? Colors.lightGreen
              : Colors.green)
        : (theme.brightness == Brightness.dark
              ? Colors.orange
              : Colors.deepOrangeAccent);
    final latencyContent = _ProxyLatencyLabel(
      text: latencyText,
      color: delayColor,
      checking: latencyChecking && !selecting,
      unavailable: latencyUnavailable && !latencyChecking && !selecting,
      unavailableLabel: l10n.proxyUnavailable,
      emphasized:
          selecting || latencyFresh || latencyUnavailable || hasLatencyError,
      animate: animate,
      tooltip: hasLatencyError
          ? _latencyErrorTooltip(latencyError)
          : hasNoLatencyResult
          ? l10n.proxyLatencyNoResultDescription
          : null,
    );

    final latencyLabel = ProxyLatencyButton(
      key: ValueKey('proxy-latency-action-${proxy.tag}'),
      label: '${l10n.urlTestTitle}: ${_localizedProxyTitle(l10n, proxy)}',
      onPressed: selecting ? null : onTestLatency,
      child: latencyContent,
    );
    final horizontalInset = !forceBaseInset && proxy.isGroupChild ? 24.0 : 6.0;
    final emphasized = selected || highlighted;
    final shouldAnimate = animate && !MediaQuery.disableAnimationsOf(context);
    final animationDuration = shouldAnimate
        ? const Duration(milliseconds: 120)
        : Duration.zero;
    final decoration = BoxDecoration(
      color: selected
          ? theme.colorScheme.secondaryContainer.withValues(alpha: .32)
          : highlighted
          ? theme.colorScheme.secondaryContainer.withValues(alpha: .15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
    );
    final indicatorDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: emphasized
          ? theme.colorScheme.primary.withValues(alpha: selected ? 1 : .46)
          : Colors.transparent,
    );
    final longPress =
        onLongPress ??
        (onOpenGroup == null
            ? null
            : () {
                final box = context.findRenderObject() as RenderBox?;
                onOpenGroup!(
                  box != null && box.attached
                      ? box.localToGlobal(Offset.zero) & box.size
                      : Rect.zero,
                );
              });
    final rowChild = Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        PositionedDirectional(
          start: 2,
          child: Container(
            width: 3,
            height: 34,
            decoration: indicatorDecoration,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: _kProxySheetRowExtent - 2,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child:
                      identityChild ??
                      _ProxyTileIdentity(
                        proxy: proxy,
                        titleOverride: titleOverride,
                        subtitleOverride: subtitleOverride,
                      ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: selecting ? 104 : 72, child: latencyLabel),
              ],
            ),
          ),
        ),
      ],
    );
    final child = animate
        ? InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            onLongPress: longPress,
            child: rowChild,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onLongPress: longPress,
            child: rowChild,
          );
    if (shouldAnimate) {
      return AnimatedContainer(
        duration: animationDuration,
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.fromLTRB(horizontalInset, 1, 6, 1),
        decoration: decoration,
        child: child,
      );
    }
    return Container(
      margin: EdgeInsets.fromLTRB(horizontalInset, 1, 6, 1),
      decoration: decoration,
      child: child,
    );
  }
}

// Passed as ValueListenableBuilder.child so ping-only updates do not rebuild
// the flag, localized labels, and text layout of every visible row.
class _ProxyTileIdentity extends StatelessWidget {
  const _ProxyTileIdentity({
    required this.proxy,
    this.titleOverride,
    this.subtitleOverride,
  });

  final AppProxySummary proxy;
  final String? titleOverride;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: CountryFlagBadge(countryCode: proxy.countryCode, size: 34),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleOverride ?? _localizedProxyTitle(l10n, proxy),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitleOverride ?? _localizedProxySubtitle(l10n, proxy),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Retain fixed sliver geometry at ordinary text sizes, but leave room for two
// title lines and a subtitle when the user enlarges the system font.
double _proxyRowExtent(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  final scaler = MediaQuery.textScalerOf(context);
  final title = textTheme.bodyMedium;
  final subtitle = textTheme.bodySmall;
  return max(
    _kProxySheetRowExtent,
    scaler.scale(title?.fontSize ?? 14) * (title?.height ?? 1.4) * 2 +
        scaler.scale(subtitle?.fontSize ?? 12) * (subtitle?.height ?? 1.4) +
        15,
  );
}
