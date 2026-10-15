import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'package:meow_client/data/local/secure_hive_storage.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';
import 'package:meow_client/platform/windows/windows_storage_key.dart';

Uint8List? _fixtureKey;

/// Only the unavailable native validation/ACL boundary is faked. Paths, raw
/// key persistence, AES-GCM and all Hive reads/writes remain real. The fixture
/// shares one key across temporary roots in one isolate because the production
/// cipher has one process lifetime, not a test reset interface.
Future<void> bootstrapWindowsStorageFixture(Directory directory) async {
  if (!Platform.isWindows) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('etonify/windows_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getLaunchContext') {
          return DesktopLaunchContext(
            installationId: 'fixture',
            distribution: DesktopDistribution.portable,
            dataRoot: directory.path,
            startedAtLogin: false,
            minimized: false,
            ownerPid: 1,
          ).toMap();
        }
        return null;
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  final paths = await AppDataPaths.resolve(
    DesktopLaunchContext(
      installationId: 'fixture',
      distribution: DesktopDistribution.portable,
      dataRoot: directory.path,
      startedAtLogin: false,
      minimized: false,
      ownerPid: 1,
    ),
  );
  final key = _fixtureKey;
  if (key == null) {
    _fixtureKey = await WindowsStorageKey.loadOrCreate(paths, portable: true);
  } else {
    await File('${directory.path}/storage.key').writeAsBytes(key, flush: true);
  }
  await SecureHiveStorage.initWindows(paths, portable: true);
}
