import 'dart:io';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/local/secure_hive_storage.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';

/// Shared by the native startup surface and every durable app bootstrap/Retry.
/// Checking the persisted key must happen even when Hive is already initialized.
class WindowsStorageBootstrap {
  WindowsStorageBootstrap._();

  static Future<DesktopLaunchContext> prepare() async {
    final raw = await AppDataPaths.channel.invokeMethod<Map<Object?, Object?>>(
      'getLaunchContext',
    );
    if (raw == null) throw StateError('Windows launch context is unavailable.');
    final launch = DesktopLaunchContext.fromMap(Map<String, Object?>.from(raw));
    final paths = await AppDataPaths.resolve(launch);
    await paths.ensureNoUnmigratedLegacyData(
      await AppDataPaths.channel.invokeMethod<String>('getLegacyHiveRoot'),
    );
    await SecureHiveStorage.initWindows(
      paths,
      portable: launch.distribution == DesktopDistribution.portable,
    );
    await HiveAppSettingsStore.initHive();
    return launch;
  }

  static Future<void> initializeHive() async {
    if (Platform.isWindows) {
      await prepare();
    } else {
      await HiveAppSettingsStore.initHive();
    }
  }
}
