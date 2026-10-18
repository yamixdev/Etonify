import 'package:flutter/material.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

class HomeCurrentProxyCard extends StatelessWidget {
  const HomeCurrentProxyCard({
    super.key,
    required this.proxy,
    required this.onTap,
    this.onOpenGroup,
  });

  final AppProxySummary proxy;
  final VoidCallback onTap;
  final VoidCallback? onOpenGroup;

  String _title(AppLocalizations l10n) {
    if (!isLowestProxyTag(proxy.tag)) return proxy.displayName;
    var selected = proxy.selectedChildName?.trim() ?? '';
    final prefix = '${lowestProxyBaseLabel(proxy.tag)} · ';
    if (selected.isEmpty && proxy.displayName.startsWith(prefix)) {
      selected = proxy.displayName.substring(prefix.length).trim();
    }
    return selected.isEmpty
        ? l10n.proxyLowestName
        : '${l10n.proxyLowestName} · $selected';
  }

  String _subtitle(AppLocalizations l10n) {
    if (proxy.isGroup && !isLowestProxyTag(proxy.tag) && proxy.childCount > 0) {
      return '${l10n.proxyAutomaticSelectionLabel} · '
          '${l10n.subscriptionServersCount(proxy.childCount)}';
    }
    final protocol = proxy.protocolLabel.trim();
    if (protocol == 'URLTest' || protocol == 'URLTest · auto') {
      return l10n.proxyAutomaticSelectionLabel;
    }
    if (protocol.startsWith('URLTest · ')) {
      return '${l10n.proxyAutomaticSelectionLabel} · '
          '${protocol.substring('URLTest · '.length).trim()}';
    }
    if (protocol == 'Chain') return l10n.proxyChainLabel;
    if (protocol.startsWith('Chain · ')) {
      return '${l10n.proxyChainLabel} · '
          '${protocol.substring('Chain · '.length)}';
    }
    if (proxy.isGroup && proxy.childCount > 0 && protocol.isEmpty) {
      return '${l10n.proxyAutomaticSelectionLabel} · '
          '${l10n.subscriptionServersCount(proxy.childCount)}';
    }
    return protocol;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = _title(l10n);
    final subtitle = Text(
      _subtitle(l10n),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final openGroup = proxy.isGroup ? onOpenGroup : null;

    final card = Material(
      key: const ValueKey('home-current-proxy-card'),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: .7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60, maxWidth: 300),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CountryFlagBadge(countryCode: proxy.countryCode, size: 34),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (openGroup != null)
                        Tooltip(
                          message: l10n.proxyOpenGroup(title),
                          child: TextButton(
                            key: ValueKey('proxy-open-group-${proxy.tag}'),
                            onPressed: openGroup,
                            style: TextButton.styleFrom(
                              alignment: Alignment.center,
                              foregroundColor:
                                  theme.colorScheme.onSurfaceVariant,
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              visualDensity: VisualDensity.standard,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(child: subtitle),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        const SizedBox(height: 3),
                        subtitle,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      return Align(heightFactor: 1, child: card);
    }
    return Align(
      heightFactor: 1,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('home-current-proxy-entrance-${proxy.tag}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: card,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - value)),
            child: child,
          ),
        ),
      ),
    );
  }
}
