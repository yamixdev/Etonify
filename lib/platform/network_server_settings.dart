import 'package:flutter/services.dart';

enum ServerNetwork { wifi, mobile }

class NetworkServerSettings {
  NetworkServerSettings._(Map<String, Object?> value)
    : enabled = value['enabled'] == true,
      remember = value['remember'] == true,
      configured = _choices(value['configured']),
      remembered = _choices(value['remembered']);

  static const _channel = MethodChannel(
    'com.etonify.meow_client/network_servers',
  );

  final bool enabled;
  final bool remember;
  final Map<ServerNetwork, String> configured;
  final Map<ServerNetwork, String> remembered;

  static Map<ServerNetwork, String> _choices(Object? raw) {
    if (raw is! Map<Object?, Object?>) return const {};
    return {
      for (final network in ServerNetwork.values)
        if (raw[network.name] case final String tag) network: tag,
    };
  }

  static Future<NetworkServerSettings> read(String profileId) async =>
      NetworkServerSettings._(
        await _channel.invokeMapMethod<String, Object?>('read', {
              'profileId': profileId,
            }) ??
            const {},
      );

  static Future<NetworkServerSettings> update(
    String profileId,
    String field,
    Object? value,
  ) async => NetworkServerSettings._(
    await _channel.invokeMapMethod<String, Object?>('update', {
          'profileId': profileId,
          'field': field,
          'value': value,
        }) ??
        const {},
  );

  static Future<void> selectManual(String profileId, String tag) => _channel
      .invokeMethod<void>('selectManual', {'profileId': profileId, 'tag': tag});

  static Future<void> reassertAfterStart(String tag) =>
      _channel.invokeMethod<void>('reassertAfterStart', {'tag': tag});

  static Future<void> rememberOffline(String profileId, String tag) =>
      _channel.invokeMethod<void>('rememberOffline', {
        'profileId': profileId,
        'tag': tag,
      });
}
