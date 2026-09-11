import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/local/payload_box_opener.dart';
import 'package:meow_client/data/local/secure_hive_storage.dart';

void main() {
  late Directory directory;
  late _CountingCipher cipher;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('payload-open-');
    Hive.init(directory.path);
    cipher = _CountingCipher();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'opening decrypts only current frames, not old large revisions',
    () async {
      var box = await Hive.openBox<dynamic>(
        'payload',
        encryptionCipher: cipher,
        compactionStrategy: (_, _) => false,
      );
      final content = 'private-proxy-credential-' * 8192;
      for (var revision = 0; revision < 8; revision++) {
        await box.put('large', '$revision:$content');
      }
      await box.put('other', 'other-profile');
      await box.put('removed', 'deleted-profile');
      await box.delete('removed');
      await box.close();
      final file = File('${directory.path}/payload.hive');
      final originalSize = await file.length();

      cipher.decryptions = 0;
      final watch = Stopwatch()..start();
      box = await Hive.openBox<dynamic>(
        'payload',
        encryptionCipher: cipher,
        compactionStrategy: (_, _) => false,
      );
      final eagerDecryptions = cipher.decryptions;
      final eagerMs = watch.elapsedMilliseconds;
      await box.close();

      cipher.decryptions = 0;
      watch.reset();
      final lazyBox = await openPayloadBox(name: 'payload', cipher: cipher);
      final optimizedMs = watch.elapsedMilliseconds;
      // Diagnostic only: machine speed must not make this regression test flaky.
      // ignore: avoid_print
      print('payload open: eager=${eagerMs}ms lazy=${optimizedMs}ms');
      expect(eagerDecryptions, 10);
      expect(cipher.decryptions, 0);
      expect(await lazyBox.get('large'), '7:$content');
      expect(cipher.decryptions, 1);
      expect(await lazyBox.get('other'), 'other-profile');
      expect(cipher.decryptions, 2);
      expect(lazyBox.containsKey('removed'), isFalse);
      await lazyBox.compact();
      expect(await file.length(), lessThan(originalSize ~/ 4));
      expect(
        String.fromCharCodes(await file.readAsBytes()),
        isNot(contains('private-proxy-credential')),
      );
      expect(await openPayloadBox(name: 'payload', cipher: cipher), same(lazyBox));
    },
  );

  test(
    'new stores and repeated updates retain durable latest values',
    () async {
      final box = await openPayloadBox(name: 'fresh', cipher: cipher);
      for (var i = 0; i < 8; i++) {
        await box.put('a', 'revision-$i');
        await box.put('b', 'other-$i');
      }
      await box.close();
      final reopened = await openPayloadBox(name: 'fresh', cipher: cipher);
      expect(await reopened.get('a'), 'revision-7');
      expect(await reopened.get('b'), 'other-7');
    },
  );
}

class _CountingCipher implements HiveCipher {
  final HiveCipher delegate = HiveAesGcmCipher(List.generate(32, (i) => i));
  int decryptions = 0;
  @override
  int calculateKeyCrc() => delegate.calculateKeyCrc();
  @override
  int maxEncryptedSize(Uint8List inp) => delegate.maxEncryptedSize(inp);
  @override
  int encrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) => delegate.encrypt(inp, inpOff, inpLength, out, outOff);
  @override
  int decrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    decryptions++;
    return delegate.decrypt(inp, inpOff, inpLength, out, outOff);
  }
}
