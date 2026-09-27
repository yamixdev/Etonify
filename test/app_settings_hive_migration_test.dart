import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/local/app_settings_store.dart';

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
}
