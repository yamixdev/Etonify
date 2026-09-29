import 'package:flutter/services.dart';

enum QuickSettingsTileAddResult {
  added,
  alreadyAdded,
  notAdded,
  manual,
  unavailable,
}

class QuickSettingsTileInstaller {
  static const MethodChannel _channel = MethodChannel(
    'meow_client/quick_settings',
  );

  static Future<QuickSettingsTileAddResult> requestAdd() async {
    try {
      final result = await _channel.invokeMethod<String>('requestAddTile');
      return switch (result) {
        'added' => QuickSettingsTileAddResult.added,
        'already_added' => QuickSettingsTileAddResult.alreadyAdded,
        'not_added' => QuickSettingsTileAddResult.notAdded,
        'manual' => QuickSettingsTileAddResult.manual,
        _ => QuickSettingsTileAddResult.unavailable,
      };
    } on PlatformException {
      return QuickSettingsTileAddResult.unavailable;
    } on MissingPluginException {
      return QuickSettingsTileAddResult.unavailable;
    }
  }
}
