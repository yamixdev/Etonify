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
    final proxy = runtimeState?.presentation ?? this.proxy;
    final theme = Theme.of(context);
    final highlighted = runtimeState?.highlighted ?? this.highlighted;
    final selecting = runtimeState?.selecting ?? false;
    final latencyLabel = _ProxyLatencyAction(
      key: ValueKey('proxy-latency-action-${proxy.tag}'),
      proxy: proxy,
      state: runtimeState,
      onPressed: onTestLatency,
      animate: animate,
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
    final VoidCallback? openGroup = onOpenGroup == null
        ? null
        : () {
            final box = context.findRenderObject() as RenderBox?;
            onOpenGroup!(
              box != null && box.attached
                  ? box.localToGlobal(Offset.zero) & box.size
                  : Rect.zero,
            );
          };
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
                  child: _ProxyTileActions(
                    animate: shouldAnimate,
                    onOpenGroup: openGroup,
                    child:
                        (proxy.displayName == this.proxy.displayName &&
                                proxy.countryCode == this.proxy.countryCode &&
                                proxy.protocolLabel ==
                                    this.proxy.protocolLabel &&
                                proxy.childCount == this.proxy.childCount &&
                                proxy.selectedChildName ==
                                    this.proxy.selectedChildName
                            ? identityChild
                            : null) ??
                        _ProxyTileIdentity(
                          proxy: proxy,
                          titleOverride: titleOverride,
                          subtitleOverride: subtitleOverride,
                        ),
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
    final interactiveRow = Material(
      type: MaterialType.transparency,
      child: Semantics(
        selected: selected,
        child: InkWell(
          key: ValueKey('proxy-select-${proxy.tag}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress:
              onLongPress ?? openGroup ?? (proxy.isGroup ? () {} : null),
          child: rowChild,
        ),
      ),
    );
    if (shouldAnimate) {
      return AnimatedContainer(
        duration: animationDuration,
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.fromLTRB(horizontalInset, 1, 6, 1),
        decoration: decoration,
        child: interactiveRow,
      );
    }
    return Container(
      margin: EdgeInsets.fromLTRB(horizontalInset, 1, 6, 1),
      decoration: decoration,
      child: interactiveRow,
    );
  }
}

// Callbacks are looked up when an action runs, keeping the cached identity
// subtree independent of frequent latency updates.
class _ProxyTileActions extends InheritedWidget {
  const _ProxyTileActions({
    required this.animate,
    required this.onOpenGroup,
    required super.child,
  });

  final bool animate;
  final VoidCallback? onOpenGroup;

  static _ProxyTileActions of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ProxyTileActions>()!;

  @override
  bool updateShouldNotify(_ProxyTileActions oldWidget) =>
      animate != oldWidget.animate ||
      (onOpenGroup == null) != (oldWidget.onOpenGroup == null);
}

class _ProxyLatencyAction extends StatelessWidget {
  const _ProxyLatencyAction({
    super.key,
    required this.proxy,
    this.state,
    this.onPressed,
    this.animate = true,
  });

  final AppProxySummary proxy;
  final ProxyRuntimeVisualState? state;
  final VoidCallback? onPressed;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final latency = state == null ? proxy.latency : state!.latency;
    final fresh = state?.latencyFresh ?? proxy.latencyFresh;
    final checking = state?.latencyChecking ?? proxy.latencyChecking;
    final unavailable = state?.latencyUnavailable ?? proxy.latencyUnavailable;
    final error = state == null ? proxy.latencyError : state!.latencyError;
    final selecting = state?.selecting ?? false;
    final unconfirmed = state?.selectionUnconfirmed ?? false;
    final hasError = error?.trim().isNotEmpty == true;
    final noResult = !selecting && !checking && !unavailable && latency == null;
    final text = selecting
        ? l10n.proxySwitching
        : unconfirmed
        ? l10n.proxySelectionUnconfirmed
        : checking
        ? '... ms'
        : latency == null
        ? l10n.proxyLatencyNoResult
        : latency >= 1000
        ? '${(latency / 1000).toStringAsFixed(1)} s'
        : '$latency ms';
    final color = selecting || (checking && !unconfirmed)
        ? theme.colorScheme.primary
        : unconfirmed || unavailable
        ? theme.colorScheme.error
        : !fresh || latency == null
        ? theme.colorScheme.onSurfaceVariant
        : latency < 800
        ? (theme.brightness == Brightness.dark
              ? Colors.lightGreen
              : Colors.green)
        : (theme.brightness == Brightness.dark
              ? Colors.orange
              : Colors.deepOrangeAccent);
    return ProxyLatencyButton(
      label: '${l10n.urlTestTitle}: ${_localizedProxyTitle(l10n, proxy)}',
      onPressed: selecting ? null : onPressed,
      child: _ProxyLatencyLabel(
        text: text,
        color: color,
        checking: checking && !selecting && !unconfirmed,
        unavailable: unavailable && !checking && !selecting && !unconfirmed,
        unavailableLabel: l10n.proxyUnavailable,
        emphasized:
            selecting || unconfirmed || fresh || unavailable || hasError,
        animate: animate,
        tooltip: hasError
            ? _latencyErrorTooltip(error)
            : noResult
            ? l10n.proxyLatencyNoResultDescription
            : null,
      ),
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
    final actions = context
        .dependOnInheritedWidgetOfExactType<_ProxyTileActions>()!;
    Widget identityPart(Widget child, {double height = 24, Key? key}) =>
        ConstrainedBox(
          key: key,
          constraints: BoxConstraints(minWidth: 44, minHeight: height),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              widthFactor: 1,
              heightFactor: 1,
              child: child,
            ),
          ),
        );
    final subtitle = Text(
      subtitleOverride ?? _localizedProxySubtitle(l10n, proxy),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return Row(
      children: [
        identityPart(
          SizedBox(
            width: 36,
            height: 48,
            child: Center(
              child: CountryFlagBadge(countryCode: proxy.countryCode, size: 34),
            ),
          ),
          height: 48,
          key: ValueKey('proxy-flag-${proxy.tag}'),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identityPart(
                Text(
                  titleOverride ?? _localizedProxyTitle(l10n, proxy),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (actions.onOpenGroup != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 3),
                  child: Tooltip(
                    message: l10n.proxyOpenGroup(
                      _localizedProxyTitle(l10n, proxy),
                    ),
                    child: OutlinedButton(
                      key: ValueKey('proxy-open-group-${proxy.tag}'),
                      onPressed: () =>
                          _ProxyTileActions.of(context).onOpenGroup?.call(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.standard,
                        animationDuration: actions.animate
                            ? const Duration(milliseconds: 120)
                            : Duration.zero,
                      ),
                      child: subtitle,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 3),
                  child: subtitle,
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
  final subtitleHeight =
      scaler.scale(subtitle?.fontSize ?? 12) * (subtitle?.height ?? 1.4);
  // The group button has a minimum height even at ordinary text sizes.
  final groupActionHeight = max(28.0, subtitleHeight + 8);
  return max(
    _kProxySheetRowExtent,
    scaler.scale(title?.fontSize ?? 14) * (title?.height ?? 1.4) * 2 +
        groupActionHeight +
        // Outer padding/margins (10), title gap (3), pixel rounding (1).
        14,
  );
}
