part of 'subscriptions_page.dart';

class _SubscriptionsSheetHeader extends StatelessWidget {
  const _SubscriptionsSheetHeader({
    required this.title,
    required this.selectionMode,
    required this.loading,
    required this.canSort,
    required this.canRefreshAll,
    required this.onSortSelected,
    required this.onRefreshAll,
    required this.onAdd,
    required this.onDeleteSelected,
    required this.onClearSelection,
    required this.onClose,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  final String title;
  final bool selectionMode;
  final bool loading;
  final bool canSort;
  final bool canRefreshAll;
  final ValueChanged<_SubscriptionSortMode> onSortSelected;
  final VoidCallback onRefreshAll;
  final VoidCallback onAdd;
  final VoidCallback onDeleteSelected;
  final VoidCallback onClearSelection;
  final VoidCallback onClose;
  final ValueChanged<DragUpdateDetails> onVerticalDragUpdate;
  final ValueChanged<DragEndDetails> onVerticalDragEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      child: SizedBox(
        height: _kSubscriptionSheetHeaderHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.surface,
                cs.surface.withValues(alpha: .96),
                cs.surface.withValues(alpha: .0),
              ],
              stops: const [0, .74, 1],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 12),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: .34),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (selectionMode) ...[
                      IconButton(
                        onPressed: loading ? null : onDeleteSelected,
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: AppLocalizations.of(context).delete,
                      ),
                      IconButton(
                        onPressed: onClearSelection,
                        icon: const Icon(Icons.close_rounded),
                        tooltip: AppLocalizations.of(context).close,
                      ),
                    ] else ...[
                      _SubscriptionSortMenuButton(
                        enabled: !loading && canSort,
                        onSelected: onSortSelected,
                      ),
                      IconButton(
                        onPressed: loading || !canRefreshAll
                            ? null
                            : onRefreshAll,
                        icon: const Icon(Icons.update_rounded),
                        tooltip: AppLocalizations.of(
                          context,
                        ).refreshSubscriptions,
                      ),
                      IconButton(
                        onPressed: loading ? null : onAdd,
                        icon: const Icon(Icons.add_rounded),
                        tooltip: AppLocalizations.of(context).addSubscription,
                      ),
                      IconButton(
                        onPressed: loading ? null : onClose,
                        icon: const Icon(Icons.close_rounded),
                        tooltip: AppLocalizations.of(context).close,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscriptionSortMenuButton extends StatelessWidget {
  const _SubscriptionSortMenuButton({
    required this.enabled,
    required this.onSelected,
  });

  final bool enabled;
  final ValueChanged<_SubscriptionSortMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MenuAnchor(
      alignmentOffset: const Offset(-184, 4),
      menuChildren: [
        _sortItem(
          mode: _SubscriptionSortMode.manual,
          icon: Icons.drag_indicator_rounded,
          label: l10n.subscriptionSortManual,
        ),
        _sortItem(
          mode: _SubscriptionSortMode.name,
          icon: Icons.sort_by_alpha_rounded,
          label: l10n.subscriptionSortByName,
        ),
        _sortItem(
          mode: _SubscriptionSortMode.updated,
          icon: Icons.update_rounded,
          label: l10n.subscriptionSortByUpdated,
        ),
        _sortItem(
          mode: _SubscriptionSortMode.servers,
          icon: Icons.hub_outlined,
          label: l10n.subscriptionSortByServers,
        ),
      ],
      builder: (context, controller, child) => IconButton(
        onPressed: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
        icon: const Icon(Icons.sort_rounded),
        tooltip: l10n.sort,
      ),
    );
  }

  MenuItemButton _sortItem({
    required _SubscriptionSortMode mode,
    required IconData icon,
    required String label,
  }) {
    return MenuItemButton(
      leadingIcon: Icon(icon),
      onPressed: () => onSelected(mode),
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(label),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.subscription,
    required this.serverCount,
    required this.rawLooksNonEmpty,
    required this.active,
    required this.multiSelected,
    required this.selectionMode,
    required this.loading,
    required this.onSelect,
    required this.onLongPress,
    required this.onRefresh,
    required this.onCopyUrl,
    required this.onShowQr,
    required this.onCopyJson,
    required this.onEdit,
    required this.onDelete,
  });

  final Subscription subscription;
  final int serverCount;
  final bool rawLooksNonEmpty;
  final bool active;
  final bool multiSelected;
  final bool selectionMode;
  final bool loading;
  final VoidCallback onSelect;
  final VoidCallback onLongPress;
  final VoidCallback onRefresh;
  final VoidCallback onCopyUrl;
  final VoidCallback onShowQr;
  final VoidCallback onCopyJson;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    final info = subscription.info;
    final totalBytes = info?.total;
    final consumedBytes = info?.consumed;
    final remainingDays = info?.remainingDays;
    final hasTraffic = totalBytes != null && totalBytes > 0;
    final hasUnlimitedTraffic = info != null && !hasTraffic;
    final remainingText = remainingDays != null
        ? remainingDays > 0
              ? l10n.daysLeft(remainingDays)
              : l10n.expired
        : info == null
        ? null
        : l10n.daysLeftUnlimited;
    String? usageText;
    if (hasTraffic && consumedBytes != null) {
      usageText = l10n.trafficUsage(
        formatBytes(consumedBytes.toDouble()),
        formatBytes(totalBytes.toDouble()),
      );
    } else if (hasUnlimitedTraffic) {
      usageText = l10n.trafficUsage(
        formatBytes((consumedBytes ?? 0).toDouble()),
        l10n.unlimitedSymbol,
      );
    }
    final refreshable = !SubscriptionStore.isLocalFileImportUrl(
      subscription.url,
    );
    final lastUpdatedText = subscription.lastUpdated > 0
        ? _subscriptionLastUpdatedText(context, subscription.lastUpdated)
        : null;
    final metaParts = <String>[
      l10n.subscriptionServersCount(serverCount),
      ...?(lastUpdatedText == null ? null : <String>[lastUpdatedText]),
      if (serverCount == 0 && rawLooksNonEmpty)
        l10n.subscriptionReparseRecommended,
    ];
    final highlighted = active || multiSelected;
    return Material(
      color: highlighted
          ? cs.secondaryContainer.withValues(alpha: .28)
          : cs.surfaceContainerLowest.withValues(alpha: .18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highlighted
              ? cs.primary.withValues(alpha: .55)
              : cs.outlineVariant.withValues(alpha: .44),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (loading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 54,
                height: 92,
                child: selectionMode
                    ? InkWell(
                        onTap: onSelect,
                        onLongPress: onLongPress,
                        child: Icon(
                          multiSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: multiSelected
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                      )
                    : _SubscriptionActionsMenu(
                        refreshable: refreshable,
                        loading: loading,
                        onRefresh: onRefresh,
                        onCopyUrl: onCopyUrl,
                        onShowQr: onShowQr,
                        onCopyJson: onCopyJson,
                        onEdit: onEdit,
                        onDelete: onDelete,
                      ),
              ),
              SizedBox(
                width: 1,
                height: 70,
                child: ColoredBox(
                  color: highlighted
                      ? cs.primary.withValues(alpha: .34)
                      : cs.outline.withValues(alpha: .24),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: onSelect,
                  onLongPress: onLongPress,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 44,
                          decoration: BoxDecoration(
                            color: highlighted
                                ? cs.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      subscription.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0,
                                          ),
                                    ),
                                  ),
                                  if (remainingText != null) ...[
                                    const Gap(12),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 116,
                                      ),
                                      child: Text(
                                        remainingText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color:
                                                  remainingDays != null &&
                                                      remainingDays <= 3
                                                  ? cs.error
                                                  : cs.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Gap(5),
                              if (info != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: hasTraffic
                                        ? (info.ratio.clamp(0, 1)).toDouble()
                                        : 0,
                                    minHeight: 5,
                                    backgroundColor: cs.surfaceContainerHighest,
                                  ),
                                ),
                              const Gap(5),
                              Text(
                                metaParts.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              if (usageText != null) ...[
                                const Gap(4),
                                Text(
                                  usageText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubscriptionActionsMenu extends StatelessWidget {
  const _SubscriptionActionsMenu({
    required this.refreshable,
    required this.loading,
    required this.onRefresh,
    required this.onCopyUrl,
    required this.onShowQr,
    required this.onCopyJson,
    required this.onEdit,
    required this.onDelete,
  });

  final bool refreshable;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onCopyUrl;
  final VoidCallback onShowQr;
  final VoidCallback onCopyJson;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.refresh_rounded),
          onPressed: refreshable && !loading ? onRefresh : null,
          child: Text(l10n.refresh),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.ios_share_rounded),
          menuChildren: [
            MenuItemButton(
              onPressed: refreshable ? onCopyUrl : null,
              child: Text(l10n.subscriptionCopyUrl),
            ),
            MenuItemButton(
              onPressed: refreshable ? onShowQr : null,
              child: Text(l10n.subscriptionShowUrlQr),
            ),
            MenuItemButton(
              onPressed: onCopyJson,
              child: Text(l10n.subscriptionCopyJson),
            ),
          ],
          child: Text(l10n.shareProxyTitle),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_rounded),
          onPressed: onEdit,
          child: Text(l10n.subscriptionDetailsTitle),
        ),
        MenuItemButton(
          leadingIcon: Icon(Icons.delete_outline_rounded, color: cs.error),
          onPressed: loading ? null : onDelete,
          child: Text(
            l10n.delete,
            style: TextStyle(color: loading ? null : cs.error),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return Tooltip(
          message: MaterialLocalizations.of(context).showMenuTooltip,
          child: InkWell(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Center(
              child: Icon(
                Icons.more_vert_rounded,
                size: 22,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptySubscriptionsPanel extends StatelessWidget {
  const _EmptySubscriptionsPanel({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Center(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: .54),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: .42)),
          ),
          child: Column(
            children: [
              SettingsLeadingIcon(
                icon: Icons.add_link_rounded,
                color: cs.primary,
              ),
              const Gap(14),
              Text(
                l10n.noSubscriptions,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const Gap(8),
              Text(
                l10n.addSubscriptionQuickSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Gap(18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.addSubscription),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
