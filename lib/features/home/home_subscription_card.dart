import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/formatting.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/theme/app_theme.dart';

class HomeSubscriptionCard extends StatelessWidget {
  const HomeSubscriptionCard({
    super.key,
    required this.profile,
    required this.margin,
    required this.onTap,
    this.onOpenTrafficDashboard,
    this.onRefresh,
    this.refreshing = false,
    this.showRefreshAction = false,
  });

  final AppProfileSummary profile;
  final EdgeInsets margin;
  final VoidCallback onTap;
  final VoidCallback? onOpenTrafficDashboard;
  final Future<void> Function()? onRefresh;
  final bool refreshing;
  final bool showRefreshAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final surfaces =
        theme.extension<AppSurfaceTheme>() ?? AppSurfaceTheme.standard;
    final cardRadius = BorderRadius.circular(surfaces.mediumRadius);
    final usageText = profile.hasUsage
        ? l10n.trafficUsage(
            formatBytes(profile.consumed),
            formatBytes(profile.total),
          )
        : l10n.trafficUsage(
            formatBytes(profile.consumed),
            l10n.unlimitedSymbol,
          );
    final remainingDays = profile.remainingDays;
    final remainingText = remainingDays == null
        ? l10n.daysLeftUnlimited
        : remainingDays > 0
        ? l10n.daysLeft(remainingDays)
        : l10n.expired;

    return Card(
      margin: margin,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: cardRadius,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .42),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showRefreshAction) ...[
                _ProfileRefreshAction(
                  refreshing: refreshing,
                  enabled: onRefresh != null && !refreshing,
                  onTap: onRefresh == null
                      ? null
                      : () => unawaited(onRefresh!.call()),
                ),
                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: .52,
                  ),
                ),
              ],
              Expanded(
                child: InkWell(
                  borderRadius: showRefreshAction
                      ? BorderRadius.horizontal(right: cardRadius.topRight)
                      : cardRadius,
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                profile.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            if (onOpenTrafficDashboard != null) ...[
                              const Gap(4),
                              Tooltip(
                                message: l10n.openTrafficDashboard,
                                child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: l10n.openTrafficDashboard,
                                  onPressed: onOpenTrafficDashboard,
                                  icon: const Icon(Icons.monitor_heart_rounded),
                                ),
                              ),
                            ],
                            const Gap(6),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        if (profile.hasUsage) ...[
                          const Gap(6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: profile.ratio,
                              minHeight: 5,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          const Gap(6),
                        ] else
                          const Gap(1),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                usageText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Gap(12),
                            Text(
                              remainingText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _ProfileRefreshAction extends StatelessWidget {
  const _ProfileRefreshAction({
    required this.refreshing,
    required this.enabled,
    required this.onTap,
  });

  final bool refreshing;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tooltip = enabled || refreshing
        ? l10n.refreshActiveSubscription
        : l10n.refreshActiveSubscriptionUnavailable;
    return SizedBox(
      width: 48,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(20),
            ),
            onTap: enabled ? onTap : null,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: refreshing
                    ? SizedBox(
                        key: const ValueKey('profile-refresh-progress'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.update_rounded,
                        key: const ValueKey('profile-refresh-icon'),
                        color: enabled
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.disabledColor,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
