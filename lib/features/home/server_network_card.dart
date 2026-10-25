import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meow_client/features/home/server_ip_metadata.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/server_connection_info.dart';
import 'package:meow_client/widgets/app_loading_indicator.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

class ServerNetworkCard extends StatefulWidget {
  const ServerNetworkCard({
    super.key,
    required this.connection,
    required this.hideIp,
    this.controller,
    this.onRefreshExitIp,
  });

  final ServerConnectionInfo connection;
  final bool hideIp;
  final ServerIpMetadataController? controller;
  final VoidCallback? onRefreshExitIp;

  @override
  State<ServerNetworkCard> createState() => _ServerNetworkCardState();
}

class _ServerNetworkCardState extends State<ServerNetworkCard> {
  @override
  void initState() {
    super.initState();
    _select();
  }

  void _select() => widget.controller?.select(
    widget.connection.key,
    widget.connection.connected ? widget.connection.exitIp : '',
  );

  @override
  void didUpdateWidget(ServerNetworkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.cancel();
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.connection != widget.connection) {
      _select();
    }
  }

  @override
  void dispose() {
    widget.controller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.controller == null
      ? _content(context)
      : ListenableBuilder(
          listenable: widget.controller!,
          builder: (context, _) => _content(context),
        );

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final info = widget.connection;
    final metadata = widget.controller?.info;
    final available = info.connected && info.exitIp.isNotEmpty;
    String value(String text) => text.isEmpty ? l10n.notAvailableShort : text;
    String address(String text) =>
        value(networkAddressText(text, hidden: widget.hideIp));
    return Card(
      key: const ValueKey('server-network-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dns_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.serverNetworkTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.serverNetworkRefresh,
                  onPressed:
                      !info.connected || widget.controller?.loading == true
                      ? null
                      : available && widget.controller != null
                      ? () => unawaited(widget.controller!.refresh())
                      : widget.onRefreshExitIp,
                  icon: widget.controller?.loading == true
                      ? const AppLoadingIndicator.compact()
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            _NetworkRow(l10n.trafficDashboardActiveProxy, value(info.name)),
            _NetworkRow(
              l10n.serverNetworkExitIp,
              available
                  ? address(info.exitIp)
                  : info.connected
                  ? l10n.serverNetworkPending
                  : l10n.trafficDashboardStateDisconnected,
            ),
            if (info.countryCode.isNotEmpty && available)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CountryFlagBadge(
                  countryCode: info.countryCode,
                  size: 24,
                ),
              ),
            _NetworkRow(
              l10n.serverNetworkOrganization,
              value(available ? metadata?.organization ?? '' : ''),
            ),
            _NetworkRow(
              'ASN',
              available && metadata?.asn != null
                  ? 'AS${metadata!.asn}'
                  : l10n.notAvailableShort,
            ),
            _NetworkRow(
              l10n.serverNetworkCountry,
              value(available ? metadata?.countryName ?? '' : ''),
            ),
            if (metadata?.city.isNotEmpty == true && available)
              _NetworkRow(l10n.serverNetworkCity, metadata!.city),
            if (metadata?.timezone.isNotEmpty == true && available)
              _NetworkRow(l10n.serverNetworkTimezone, metadata!.timezone),
            if (metadata?.network.isNotEmpty == true && available)
              _NetworkRow(l10n.serverNetworkPrefix, address(metadata!.network)),
            const Divider(height: 24),
            _NetworkRow(l10n.serverNetworkEndpoint, address(info.endpointHost)),
            _NetworkRow(
              l10n.serverNetworkPort,
              info.endpointPort > 0
                  ? '${info.endpointPort}'
                  : l10n.notAvailableShort,
            ),
            _NetworkRow(l10n.serverNetworkProtocol, value(info.protocol)),
            _NetworkRow(l10n.serverNetworkTransport, value(info.transport)),
            _NetworkRow(l10n.serverNetworkSecurity, value(info.security)),
            if (widget.controller?.failed == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.serverNetworkError,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              l10n.serverNetworkSource,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
