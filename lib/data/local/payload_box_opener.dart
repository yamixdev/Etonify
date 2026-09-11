import 'package:hive_ce/hive.dart';
import 'package:meow_client/logging/app_log_store.dart';

/// Opens the encrypted payload box lazily.
///
/// LazyBox reads only the binary key-offset index into memory upon opening,
/// deferring decryption and memory allocation for each multi-megabyte payload
/// until its specific key is requested.
Future<LazyBox<dynamic>> openPayloadBox({
  required String name,
  required HiveCipher? cipher,
}) async {
  if (Hive.isBoxOpen(name)) return Hive.lazyBox<dynamic>(name);

  final watch = Stopwatch()..start();
  final box = await Hive.openLazyBox<dynamic>(
    name,
    encryptionCipher: cipher,
    compactionStrategy: shouldCompactPayloadBox,
  );
  final elapsedMs = watch.elapsedMilliseconds;
  AppLogStore.info(
    'storage metrics',
    'payloadOpenMs=$elapsedMs entries=${box.length}',
  );
  return box;
}

/// Payload entries can be megabytes long. Hive's generic default waits for
/// many obsolete entries, which is unsuitable for a handful of big profiles.
bool shouldCompactPayloadBox(int entries, int deletedEntries) =>
    deletedEntries >= 2 && deletedEntries >= entries;
