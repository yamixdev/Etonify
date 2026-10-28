import 'package:flutter/services.dart';

class BatteryOptimization {
  static const _channel = MethodChannel('meow_client/battery_optimization');

  static Future<bool> openSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
