import 'dart:async';

import 'package:flutter/services.dart';

enum BatteryOptimizationStatus { exempt, restricted, unavailable }

class BatteryOptimization {
  static const _channel = MethodChannel('meow_client/battery_optimization');

  static Future<BatteryOptimizationStatus> getStatus() async {
    try {
      return switch (await _channel
          .invokeMethod<String>('getStatus')
          .timeout(const Duration(seconds: 2))) {
        'exempt' => BatteryOptimizationStatus.exempt,
        'restricted' => BatteryOptimizationStatus.restricted,
        _ => BatteryOptimizationStatus.unavailable,
      };
    } on TimeoutException {
      return BatteryOptimizationStatus.unavailable;
    } on PlatformException {
      return BatteryOptimizationStatus.unavailable;
    } on MissingPluginException {
      return BatteryOptimizationStatus.unavailable;
    }
  }

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
