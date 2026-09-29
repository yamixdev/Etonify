import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/platform/quick_settings_tile_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('meow_client/quick_settings');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('quick tile installer reports already-added tile', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'requestAddTile');
          return 'already_added';
        });

    expect(
      await QuickSettingsTileInstaller.requestAdd(),
      QuickSettingsTileAddResult.alreadyAdded,
    );
  });

  test(
    'quick tile installer falls back when platform channel is unavailable',
    () async {
      expect(
        await QuickSettingsTileInstaller.requestAdd(),
        QuickSettingsTileAddResult.unavailable,
      );
    },
  );
}
