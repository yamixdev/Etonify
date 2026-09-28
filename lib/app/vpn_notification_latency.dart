import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';

int? vpnNotificationLatencyMillis(
  AppProxySummary proxy,
  ProxyRuntimeVisualState? state,
) {
  if (state?.networkUnavailable == true) {
    return null;
  }
  final visibleProxy = applyProxyRuntimeVisualState(proxy, state);
  return visibleProxy.latencyUnavailable ? null : visibleProxy.latency;
}
