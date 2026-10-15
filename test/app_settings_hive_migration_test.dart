import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'package:meow_client/data/local/secure_hive_storage.dart';
import 'support/windows_storage_fixture.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'etonify-settings-migration-',
    );
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('URLTest migration marker is written only on first load', () async {
    final box = await Hive.openBox<dynamic>('settings-migration-test');
    addTearDown(box.close);
    await box.put('urltest_concurrency', '4');
    final markerEvents = <BoxEvent>[];
    final subscription = box
        .watch(key: 'urltest_concurrency_default_migrated')
        .listen(markerEvents.add);
    addTearDown(subscription.cancel);

    await Future.wait([
      migrateUrlTestConcurrencyDefault(box),
      migrateUrlTestConcurrencyDefault(box),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(box.get('urltest_concurrency'), '10');
    expect(box.get('urltest_concurrency_default_migrated'), '1');
    expect(markerEvents, hasLength(1));

    await migrateUrlTestConcurrencyDefault(box);
    await Future<void>.delayed(Duration.zero);
    expect(markerEvents, hasLength(1));
  });
  test(
    'failed Windows migration closes the new box so retry cannot bypass copying',
    () async {
      await bootstrapWindowsStorageFixture(tempDir);
      final paths = AppDataPaths.current;
      await HiveAppSettingsStore.initHive();
      final legacy = await Hive.openBox<dynamic>(
        AppSettingsStore.legacyBoxName,
      );
      await legacy.put('locale_code', 'ru');
      await legacy.flush();
      await legacy.close();
      final secure = await Hive.openBox<dynamic>(
        AppSettingsStore.boxName,
        encryptionCipher: SecureHiveStorage.cipher,
        crashRecovery: false,
      );
      await secure.delete(AppSettingsStore.storageSchemaVersionKey);
      await secure.flush();
      await secure.close();
      final journal = File('${paths.stagingRoot}/settings-migration.json');
      if (await journal.exists()) await journal.delete();
      final blocked = await Directory(journal.path).create();
      await expectLater(
        HiveAppSettingsStore.open(),
        throwsA(isA<FileSystemException>()),
      );
      expect(Hive.isBoxOpen(AppSettingsStore.boxName), isFalse);
      expect(Hive.isBoxOpen(AppSettingsStore.legacyBoxName), isFalse);
      await blocked.delete();
      final restored = await HiveAppSettingsStore.open();
      expect((await restored.loadState()).localeCode, 'ru');
      await restored.close();
    },
    skip: !Platform.isWindows,
  );
  test(
    'Windows settings migration retains source and durable recovery journal',
    () async {
      await bootstrapWindowsStorageFixture(tempDir);
      final paths = AppDataPaths.current;
      Hive.init(paths.hiveRoot);
      final source = await Hive.openBox<dynamic>(
        AppSettingsStore.legacyBoxName,
      );
      await source.put('locale_code', 'ru');
      await source.flush();
      await source.close();
      final sourceFile = File(
        '${paths.hiveRoot}/${AppSettingsStore.legacyBoxName}.hive',
      );
      final sourceBytes = await sourceFile.readAsBytes();
      final store = await HiveAppSettingsStore.open();
      await store.close();
      expect(await sourceFile.exists(), isTrue);
      expect(await sourceFile.readAsBytes(), sourceBytes);
      final reopened = await Hive.openBox<dynamic>(
        AppSettingsStore.boxName,
        encryptionCipher: SecureHiveStorage.cipher,
        crashRecovery: false,
      );
      expect(reopened.get('locale_code'), 'ru');
      final journal =
          jsonDecode(
                await File(
                  '${paths.stagingRoot}/settings-migration.json',
                ).readAsString(),
              )
              as Map;
      expect(journal['state'], 'copied');
      expect(journal['sourceRetained'], isTrue);
      await reopened.close();
    },
    skip: !Platform.isWindows,
  );
}
