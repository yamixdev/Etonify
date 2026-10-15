import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:meow_client/core/platform/app_data_paths.dart';

class WindowsStorageKey {
  WindowsStorageKey._();

  /// Portable protection is possession of the entire folder, not Keystore-like
  /// protection: copying storage.key and Hive files exposes their contents.
  static const portabilityWarning =
      'The encryption key is stored beside your portable data. Anyone with a '
      'copy of the complete folder can read the data. It is not protected by '
      'Windows DPAPI and has no account isolation: authenticated users who can '
      'reach the folder can read or change its files. Keep the folder and backups private.';

  static Future<Uint8List> loadOrCreate(
    AppDataPaths paths, {
    required bool portable,
  }) async {
    final root = paths.userRoot;
    if (!await Directory(root).exists()) {
      throw FileSystemException('User data storage is unavailable.', root);
    }
    if (Platform.isWindows) {
      await AppDataPaths.channel.invokeMethod<void>('validateRoot', {
        'root': root,
      });
      await AppDataPaths.channel.invokeMethod<void>('validateRoot', {
        'root': '$root/storage.key.lock',
      });
      await AppDataPaths.channel.invokeMethod<void>('validateRoot', {
        'root': paths.hiveRoot,
      });
    }
    final lock = await File(
      '$root/storage.key.lock',
    ).open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.blockingExclusive);
      final keyFile = File('$root/storage.key');
      final pending = File('$root/storage.key.pending');
      for (final file in [keyFile, pending]) {
        if (Platform.isWindows) {
          await AppDataPaths.channel.invokeMethod<void>('validateRoot', {
            'root': file.path,
          });
        }
      }
      Future<Uint8List> decode(File file) async {
        if (Platform.isWindows) {
          await AppDataPaths.channel.invokeMethod<void>('restrictKeyFile', {
            'path': file.path,
            'portable': portable,
          });
        }
        final bytes = await file.readAsBytes();
        final key = portable
            ? bytes
            : await AppDataPaths.channel.invokeMethod<Uint8List>(
                'unprotectKey',
                {'key': bytes},
              );
        if (key == null || key.length != 32) {
          throw StateError(
            'Storage key is corrupt or belongs to another user.',
          );
        }
        return key;
      }

      if (await keyFile.exists()) return await decode(keyFile);
      final hasData = await Directory(paths.hiveRoot)
          .list(recursive: true, followLinks: false)
          .any((entry) => entry is File && entry.path.endsWith('.hive'));
      if (hasData) {
        throw StateError(
          'Storage key is missing while database files remain. Restore the complete backup.',
        );
      }
      // The pending file is a recoverable creation journal. Never overwrite it
      // after a crash, or create another key while encrypted data remains.
      if (!await pending.exists()) {
        final random = Random.secure();
        final key = Uint8List.fromList(
          List.generate(32, (_) => random.nextInt(256)),
        );
        final encoded = portable
            ? key
            : await AppDataPaths.channel.invokeMethod<Uint8List>('protectKey', {
                'key': key,
              });
        if (encoded == null || encoded.isEmpty) {
          throw StateError('Key protection failed.');
        }
        await pending.create();
        if (Platform.isWindows) {
          await AppDataPaths.channel.invokeMethod<void>('restrictKeyFile', {
            'path': pending.path,
            'portable': portable,
          });
        }
        await pending.writeAsBytes(encoded, flush: true);
        final verified = await decode(pending);
        if (!_same(key, verified)) {
          throw StateError('Persisted storage key verification failed.');
        }
      }
      final key = await decode(pending);
      await pending.rename(keyFile.path);
      if (!_same(key, await decode(keyFile))) {
        throw StateError('Storage key commit verification failed.');
      }
      return key;
    } finally {
      await lock.close();
    }
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var different = 0;
    for (var i = 0; i < a.length; i++) {
      different |= a[i] ^ b[i];
    }
    return different == 0;
  }
}
