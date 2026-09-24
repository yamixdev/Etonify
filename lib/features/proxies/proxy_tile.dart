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
    this.showGroupHandle = false,
    this.animate = true,
    this.runtimeState,
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
  final bool showGroupHandle;
  final bool animate;
  final ProxyRuntimeVisualState? runtimeState;
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
    final latency = latencyFresh
        ? (state == null ? proxy.latency : state.latency)
        : null;
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
    final groupHandleVisible = showGroupHandle || onOpenGroup != null;
    final animationDuration = animate
        ? const Duration(milliseconds: 220)
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
    final rowChild = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          animate
              ? AnimatedContainer(
                  duration: animationDuration,
                  width: 4,
                  height: 46,
                  decoration: indicatorDecoration,
                )
              : Container(
                  width: 4,
                  height: 46,
                  decoration: indicatorDecoration,
                ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            height: 36,
            child: CountryFlagBadge(countryCode: proxy.countryCode, size: 36),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleOverride ?? _localizedProxyTitle(l10n, proxy),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
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
          const SizedBox(width: 10),
          SizedBox(
            width: groupHandleVisible ? 120 : (selecting ? 104 : 72),
            child: !groupHandleVisible
                ? latencyLabel
                : Row(
                    children: [
                      Expanded(child: latencyLabel),
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          key: ValueKey('proxy-group-action-${proxy.tag}'),
                          tooltip: _localizedProxyTitle(l10n, proxy),
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: onOpenGroup == null
                              ? null
                              : () {
                                  final box =
                                      context.findRenderObject() as RenderBox?;
                                  final rect = box != null && box.attached
                                      ? box.localToGlobal(Offset.zero) &
                                            box.size
                                      : Rect.zero;
                                  onOpenGroup!(rect);
                                },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
    final child = animate
        ? InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            onLongPress: onLongPress,
            child: rowChild,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onLongPress: onLongPress,
            child: rowChild,
          );
    if (animate) {
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
