import 'package:hive_ce/hive.dart';
import 'package:meow_client/logging/app_log_store.dart';

/// Drops obsolete encrypted frames before eager opening would decrypt them.
/// Lazy compaction copies the latest frames verbatim; it does not change the
/// cipher, key, payload format or the authentication check on the final read.
Future<Box<dynamic>> openPayloadBox({
  required String name,
  required HiveCipher? cipher,
}) async {
  if (Hive.isBoxOpen(name)) return Hive.box<dynamic>(name);

  final watch = Stopwatch()..start();
  final index = await Hive.openLazyBox<dynamic>(
    name,
    encryptionCipher: cipher,
    compactionStrategy: (_, _) => false,
  );
  final indexMs = watch.elapsedMilliseconds;
  try {
    try {
      await index.compact();
    } catch (error) {
      // Compaction is maintenance, not a prerequisite for reading the box.
      // Hive retains the original file if replacing the compacted file fails.
      AppLogStore.warning('storage', 'Payload compaction deferred: $error');
    }
  } finally {
    await index.close();
  }
  final compactedMs = watch.elapsedMilliseconds;
  final box = await Hive.openBox<dynamic>(
    name,
    encryptionCipher: cipher,
    compactionStrategy: shouldCompactPayloadBox,
  );
  AppLogStore.info(
    'storage metrics',
    'payloadIndexMs=$indexMs '
        'payloadCompactMs=${compactedMs - indexMs} '
        'payloadDecodeMs=${watch.elapsedMilliseconds - compactedMs} '
        'entries=${box.length}',
  );
  return box;
}

/// Payload entries can be megabytes long. Hive's generic default waits for
/// many obsolete entries, which is unsuitable for a handful of big profiles.
bool shouldCompactPayloadBox(int entries, int deletedEntries) =>
    deletedEntries >= 2 && deletedEntries >= entries;
