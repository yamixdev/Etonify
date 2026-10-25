import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/server_connection_info.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

class HomeCurrentProxyCard extends StatelessWidget {
  const HomeCurrentProxyCard({
    super.key,
    required this.proxy,
    required this.onTap,
    this.onOpenGroup,
    this.onOpenInfo,
    this.connectionInfo = const ServerConnectionInfo(),
    this.hideIp = false,
    this.connectionListenable,
  });

  final AppProxySummary proxy;
  final VoidCallback onTap;
  final VoidCallback? onOpenGroup;
  final VoidCallback? onOpenInfo;
  final ServerConnectionInfo connectionInfo;
  final bool hideIp;
  final ValueListenable<ServerConnectionInfo>? connectionListenable;

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

  @override
  Widget build(BuildContext context) {
    final source = connectionListenable;
    return source == null
        ? _buildCard(context, connectionInfo)
        : ValueListenableBuilder<ServerConnectionInfo>(
            valueListenable: source,
            builder: (context, info, _) => _buildCard(context, info),
          );
  }

  Widget _buildCard(BuildContext context, ServerConnectionInfo connectionInfo) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = _title(l10n);
    final matches = connectionInfo.selectedProxyTag.isNotEmpty
        ? connectionInfo.selectedProxyTag == proxy.tag &&
              connectionInfo.presentedChildTag ==
                  (proxy.selectedChildTag ?? '') &&
              connectionInfo.presentedEndpoint == proxy.endpointLabel
        : connectionInfo.outboundTag == proxy.tag ||
              connectionInfo.outboundTag == proxy.selectedChildTag;
    final ip = connectionInfo.connected && matches ? connectionInfo.exitIp : '';
    final ipText = !connectionInfo.connected
        ? l10n.trafficDashboardStateDisconnected
        : ip.isNotEmpty
        ? networkAddressText(ip, hidden: hideIp)
        : connectionInfo.ipChecking
        ? l10n.loading
        : l10n.notAvailableShort;
    final subtitle = Text(
      ipText,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final openGroup = proxy.isGroup ? onOpenGroup : null;

    final ipAction = onOpenInfo == null
        ? subtitle
        : Tooltip(
            message: l10n.serverNetworkTitle,
            child: TextButton(
              key: const ValueKey('home-server-ip-action'),
              onPressed: onOpenInfo,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                minimumSize: const Size(48, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: subtitle,
            ),
          );
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
                      if (openGroup == null)
                        ipAction
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: ipAction),
                            IconButton(
                              key: ValueKey('proxy-open-group-${proxy.tag}'),
                              tooltip: l10n.proxyOpenGroup(title),
                              onPressed: openGroup,
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
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
