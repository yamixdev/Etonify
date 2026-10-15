import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/local/secure_hive_storage.dart';
import 'package:meow_client/data/local/payload_box_opener.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'support/windows_storage_fixture.dart';

void main() {
  test(
    'Windows bootstrap retry revalidates a missing key instead of using its cache',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'etonify-key-retry-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await bootstrapWindowsStorageFixture(directory);
      final paths = AppDataPaths.current;
      await File('${paths.hiveRoot}/present.hive').writeAsBytes([1]);
      await File('${paths.userRoot}/storage.key').delete();
      await expectLater(
        SecureHiveStorage.initWindows(paths, portable: true),
        throwsA(isA<StateError>()),
      );
      expect(await File('${paths.userRoot}/storage.key').exists(), isFalse);
    },
    skip: !Platform.isWindows,
  );
  test(
    'Windows corrupted lazy payload fails without truncating its source',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'etonify-corrupt-gcm-',
      );
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      Hive.init(directory.path);
      final cipher = HiveAesGcmCipher(List.generate(32, (i) => i));
      final box = await openPayloadBox(name: 'corrupt-payload', cipher: cipher);
      await box.put('secret', 'keep my original bytes');
      await box.flush();
      await Hive.close();
      final file = File('${directory.path}/corrupt-payload.hive');
      final bytes = await file.readAsBytes();
      bytes[bytes.length - 1] ^= 1;
      await file.writeAsBytes(bytes, flush: true);
      await expectLater(
        openPayloadBox(name: 'corrupt-payload', cipher: cipher),
        throwsA(anything),
      );
      expect(await file.readAsBytes(), bytes);
    },
    skip: !Platform.isWindows ? 'Windows fail-closed storage contract' : false,
  );
  test('AES-GCM Hive cipher authenticates and round-trips frames', () {
    final cipher = HiveAesGcmCipher(List<int>.generate(32, (index) => index));
    final input = Uint8List.fromList(<int>[
      99,
      ...'secret-value'.codeUnits,
      88,
    ]);
    final first = Uint8List(cipher.maxEncryptedSize(input));
    final second = Uint8List(cipher.maxEncryptedSize(input));

    final firstLength = cipher.encrypt(input, 1, input.length - 2, first, 0);
    final secondLength = cipher.encrypt(input, 1, input.length - 2, second, 0);
    expect(firstLength, secondLength);
    expect(
      first.sublist(0, firstLength),
      isNot(equals(second.sublist(0, secondLength))),
    );

    final output = Uint8List(input.length + 4);
    final plaintextLength = cipher.decrypt(first, 0, firstLength, output, 2);
    expect(
      output.sublist(2, 2 + plaintextLength),
      equals('secret-value'.codeUnits),
    );

    first[firstLength - 1] ^= 1;
    expect(
      () => cipher.decrypt(first, 0, firstLength, output, 0),
      throwsA(anything),
    );
  });

  test('encrypted Hive box does not persist a plaintext secret', () async {
    final directory = await Directory.systemTemp.createTemp('etonify-gcm-');
    addTearDown(() async {
      await Hive.close();
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    Hive.init(directory.path);
    final key = List<int>.generate(32, (index) => 255 - index);
    final box = await Hive.openBox<String>(
      'secrets',
      encryptionCipher: HiveAesGcmCipher(key),
    );
    await box.put('subscription', 'vless://private-credential@example.com');
    await box.flush();
    await box.close();

    final bytes = await File('${directory.path}/secrets.hive').readAsBytes();
    expect(String.fromCharCodes(bytes), isNot(contains('private-credential')));

    final reopened = await Hive.openBox<String>(
      'secrets',
      encryptionCipher: HiveAesGcmCipher(key),
    );
    expect(
      reopened.get('subscription'),
      'vless://private-credential@example.com',
    );
  });
}
