import 'package:meow_client/data/subscription/outbound_schema.dart';
import 'package:meow_client/models/core_settings.dart';

/// Mutates only the freshly built config, never the stored subscription.
void applyCoreSettings(
  Map<String, dynamic> config,
  CoreSettings settings, {
  required String profileId,
  Set<String>? multiplexEligibleTags,
}) {
  final rawRoute = config['route'];
  if (rawRoute is Map &&
      settings.networkStrategy != CoreNetworkStrategy.defaults) {
    final route = Map<String, dynamic>.from(rawRoute);
    config['route'] = route;
    route['default_network_strategy'] = settings.networkStrategy.name;
    if (settings.networkType != CoreNetworkType.defaults) {
      route['default_network_type'] = [settings.networkType.name];
    }
    if (settings.networkStrategy == CoreNetworkStrategy.fallback) {
      if (settings.fallbackNetworkType != CoreNetworkType.defaults) {
        route['default_fallback_network_type'] = [
          settings.fallbackNetworkType.name,
        ];
      }
      if (settings.fallbackDelayMs > 0) {
        route['default_fallback_delay'] = '${settings.fallbackDelayMs}ms';
      }
    }
  }
  for (final inbound in (config['inbounds'] as List? ?? const [])) {
    if (inbound is! Map || inbound['type'] != 'tun') continue;
    if (settings.udpMapping != CoreNatBehavior.defaults) {
      inbound['udp_mapping'] = settings.udpMapping.wireName;
    }
    if (settings.udpFiltering != CoreNatBehavior.defaults) {
      inbound['udp_filtering'] = settings.udpFiltering.wireName;
    }
    if (settings.udpNatMax > 0) inbound['udp_nat_max'] = settings.udpNatMax;
    if (settings.udpTimeoutSeconds > 0) {
      inbound['udp_timeout'] = '${settings.udpTimeoutSeconds}s';
    }
  }
  const dialTypes = {
    'vless',
    'vmess',
    'trojan',
    'shadowsocks',
    'socks',
    'http',
    'hysteria',
    'hysteria2',
    'tuic',
    'anytls',
    'naive',
    'shadowtls',
  };
  for (final outbound in (config['outbounds'] as List? ?? const [])) {
    if (outbound is! Map<String, dynamic> ||
        !dialTypes.contains(outbound['type'])) {
      continue;
    }
    final isQuic = ParsedOutboundSchema.isQuicOutbound(outbound);
    final isNaive = outbound['type'] == 'naive';
    // A detour owns the socket; dial overrides on this hop would be misleading.
    if (outbound['detour'] == null || outbound['detour'] == '') {
      if (settings.connectTimeoutSeconds > 0) {
        outbound['connect_timeout'] = '${settings.connectTimeoutSeconds}s';
      }
      if (!isQuic && !isNaive) {
        if (settings.keepAlive != CoreKeepAlive.defaults) {
          outbound['disable_tcp_keep_alive'] =
              settings.keepAlive == CoreKeepAlive.disabled;
          outbound.remove('tcp_keep_alive');
          outbound.remove('tcp_keep_alive_interval');
          if (settings.keepAlive == CoreKeepAlive.manual) {
            outbound['tcp_keep_alive'] = '${settings.keepAliveSeconds}s';
            outbound['tcp_keep_alive_interval'] =
                '${settings.keepAliveIntervalSeconds}s';
          }
        }
      }
      if (settings.udpFragment != CoreUdpFragment.defaults) {
        outbound['udp_fragment'] =
            settings.udpFragment == CoreUdpFragment.enabled;
      }
    }
    final tls = outbound['tls'];
    if (settings.tlsHandshakeTimeoutSeconds > 0 &&
        !isQuic &&
        !isNaive &&
        tls is Map &&
        tls['enabled'] == true) {
      outbound['tls'] = {
        ...Map<String, dynamic>.from(tls),
        'handshake_timeout': '${settings.tlsHandshakeTimeoutSeconds}s',
      };
    }
    final mux =
        settings.multiplex[CoreMuxSettings.key(
          profileId,
          outbound['tag']?.toString() ?? '',
        )];
    if (mux != null &&
        (multiplexEligibleTags == null ||
            multiplexEligibleTags.contains(outbound['tag'])) &&
        mux.mode != CoreMuxMode.auto &&
        CoreMuxSettings.supports(outbound)) {
      outbound['multiplex'] = mux.config;
    }
  }
}
