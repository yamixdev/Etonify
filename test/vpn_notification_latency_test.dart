import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/vpn_notification_latency.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';

void main() {
  const proxy = AppProxySummary(
    tag: 'server-1',
    displayName: 'Server 1',
    countryCode: '',
    type: 'vless',
    server: 'example.com',
    port: 443,
    detailText: '',
    ip: '',
    latency: 240,
    latencyFresh: false,
    latencyChecking: false,
    latencyUnavailable: false,
    latencyError: null,
    protocolLabel: 'VLESS',
    endpointLabel: 'example.com:443',
  );

  test('notification uses the same fresh latency as the visible proxy', () {
    const state = ProxyRuntimeVisualState(latency: 110, latencyFresh: true);
    final visible = applyProxyRuntimeVisualState(proxy, state);

    expect(visible.latency, 110);
    expect(vpnNotificationLatencyMillis(proxy, state), 110);
  });

  test('notification clears a failed or network-stale measurement', () {
    expect(
      vpnNotificationLatencyMillis(
        proxy,
        const ProxyRuntimeVisualState(latencyUnavailable: true),
      ),
      isNull,
    );
    expect(
      vpnNotificationLatencyMillis(
        proxy,
        const ProxyRuntimeVisualState(latency: 240, networkUnavailable: true),
      ),
      isNull,
    );
  });

  test('notification retains the same historical latency as the client', () {
    expect(vpnNotificationLatencyMillis(proxy, null), 240);
  });
}
