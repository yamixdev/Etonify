import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'package:meow_client/data/local/secure_hive_storage.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';
import 'package:meow_client/platform/windows/windows_storage_key.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('etonify/windows_storage');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'protectKey' || call.method == 'unprotectKey') {
            return (call.arguments as Map)['key'];
          }
          return null;
        }),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  Future<AppDataPaths> resolve(String root) => AppDataPaths.resolve(
    DesktopLaunchContext(
      installationId: 'test',
      distribution: DesktopDistribution.portable,
      dataRoot: root,
      startedAtLogin: false,
      minimized: false,
      ownerPid: 1,
    ),
  );
  for (final portable in [true, false]) {
    test(
      'native key permission request selects ${portable ? 'portable' : 'installed'} policy',
      () async {
        final temp = await Directory.systemTemp.createTemp('etonify-policy-');
        addTearDown(() => temp.delete(recursive: true));
        final paths = await resolve(temp.path);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'restrictKeyFile') {
                if ((call.arguments as Map)['portable'] != portable) {
                  throw PlatformException(code: 'wrong_permission_policy');
                }
              }
              if (call.method == 'protectKey' ||
                  call.method == 'unprotectKey') {
                return (call.arguments as Map)['key'];
              }
              return null;
            });
        final key = await WindowsStorageKey.loadOrCreate(
          paths,
          portable: portable,
        );
        expect(key.length, 32);
        expect(
          await WindowsStorageKey.loadOrCreate(paths, portable: portable),
          key,
        );
      },
      skip: !Platform.isWindows,
    );
  }
  test(
    'portable key and encrypted Hive survive moving the complete folder',
    () async {
      final parent = await Directory.systemTemp.createTemp('etonify-portable-');
      addTearDown(() async {
        await Hive.close();
        await parent.delete(recursive: true);
      });
      final first = await resolve('${parent.path}/first/data/user');
      final key = await WindowsStorageKey.loadOrCreate(first, portable: true);
      expect(key.length, 32);
      expect(await WindowsStorageKey.loadOrCreate(first, portable: true), key);
      Hive.init(first.hiveRoot);
      final box = await Hive.openBox<String>(
        'private',
        encryptionCipher: HiveAesGcmCipher(key),
      );
      await box.put('secret', 'portable secret');
      await box.flush();
      await Hive.close();
      await Directory('${parent.path}/first').rename('${parent.path}/second');
      final second = await resolve('${parent.path}/second/data/user');
      final moved = await WindowsStorageKey.loadOrCreate(
        second,
        portable: true,
      );
      expect(moved, key);
      Hive.init(second.hiveRoot);
      final reopened = await Hive.openBox<String>(
        'private',
        encryptionCipher: HiveAesGcmCipher(moved),
      );
      expect(reopened.get('secret'), 'portable secret');
    },
  );
  test(
    'missing key with existing data cannot generate a replacement',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'etonify-missing-key-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final paths = await resolve(temp.path);
      await File('${paths.hiveRoot}/private.hive').writeAsBytes([1, 2, 3]);
      await expectLater(
        WindowsStorageKey.loadOrCreate(paths, portable: true),
        throwsA(isA<StateError>()),
      );
      expect(await File('${paths.userRoot}/storage.key').exists(), isFalse);
    },
  );
  test('concurrent loaders retain one persisted portable key', () async {
    final temp = await Directory.systemTemp.createTemp('etonify-key-race-');
    addTearDown(() => temp.delete(recursive: true));
    final paths = await resolve(temp.path);
    final keys = await Future.wait(
      List.generate(
        8,
        (_) => WindowsStorageKey.loadOrCreate(paths, portable: true),
      ),
    );
    final saved = await File('${paths.userRoot}/storage.key').readAsBytes();
    expect(saved.length, 32);
    for (final key in keys) {
      expect(key, saved);
    }
    expect(
      await File('${paths.userRoot}/storage.key.pending').exists(),
      isFalse,
    );
  });
  test(
    'valid pending creation journal is recovered without a new key',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'etonify-key-journal-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final paths = await resolve(temp.path);
      final key = List.generate(32, (i) => i);
      await File(
        '${paths.userRoot}/storage.key.pending',
      ).writeAsBytes(key, flush: true);
      expect(await WindowsStorageKey.loadOrCreate(paths, portable: true), key);
      expect(await File('${paths.userRoot}/storage.key').readAsBytes(), key);
    },
  );
  test('corrupt key remains untouched even without existing boxes', () async {
    final temp = await Directory.systemTemp.createTemp('etonify-corrupt-key-');
    addTearDown(() => temp.delete(recursive: true));
    final paths = await resolve(temp.path);
    final file = File('${paths.userRoot}/storage.key');
    await file.writeAsBytes([1, 2]);
    await expectLater(
      WindowsStorageKey.loadOrCreate(paths, portable: true),
      throwsA(isA<StateError>()),
    );
    expect(await file.readAsBytes(), [1, 2]);
  });
  test(
    'installed key round trip uses protection boundary and rejects invalid data',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'etonify-installed-key-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final paths = await resolve(temp.path);
      final Uint8List key = await WindowsStorageKey.loadOrCreate(
        paths,
        portable: false,
      );
      expect(key.length, 32);
      expect(await WindowsStorageKey.loadOrCreate(paths, portable: false), key);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => Uint8List(2));
      await expectLater(
        WindowsStorageKey.loadOrCreate(paths, portable: false),
        throwsA(isA<StateError>()),
      );
    },
  );
}
