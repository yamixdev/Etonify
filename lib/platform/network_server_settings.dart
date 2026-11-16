import 'package:meow_client/singbox/singbox_api.g.dart';

enum ServerNetwork { wifi, mobile }

class NetworkServerSettings {
  NetworkServerSettings._(NetworkServerSettingsMessage value)
    : enabled = value.enabled,
      remember = value.remember,
      configured = _choices(value.configuredWifi, value.configuredMobile),
      remembered = _choices(value.rememberedWifi, value.rememberedMobile);

  static final _api = NetworkServerHostApi();

  final bool enabled;
  final bool remember;
  final Map<ServerNetwork, String> configured;
  final Map<ServerNetwork, String> remembered;

  static Map<ServerNetwork, String> _choices(String? wifi, String? mobile) => {
    ServerNetwork.wifi: ?wifi,
    ServerNetwork.mobile: ?mobile,
  };

  static Future<NetworkServerSettings> read(String profileId) async =>
      NetworkServerSettings._(await _api.read(profileId));

  static Future<NetworkServerSettings> setEnabled(
    String profileId,
    bool enabled,
  ) async => NetworkServerSettings._(await _api.setEnabled(profileId, enabled));

  static Future<NetworkServerSettings> setRemember(
    String profileId,
    bool remember,
  ) async =>
      NetworkServerSettings._(await _api.setRemember(profileId, remember));

  static Future<NetworkServerSettings> setConfigured(
    String profileId,
    ServerNetwork network,
    String? tag,
  ) async => NetworkServerSettings._(
    await _api.setConfigured(profileId, switch (network) {
      ServerNetwork.wifi => NetworkServerKind.wifi,
      ServerNetwork.mobile => NetworkServerKind.mobile,
    }, tag),
  );

  static Future<void> selectManual(String profileId, String tag) =>
      _api.selectManual(profileId, tag);

  static Future<void> reassertAfterStart(String tag) =>
      _api.reassertAfterStart(tag);

  static Future<void> rememberOffline(String profileId, String tag) =>
      _api.rememberOffline(profileId, tag);
}
