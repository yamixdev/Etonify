import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:meow_client/logging/app_log_store.dart';

class HiveStorageDiagnostics {
  HiveStorageDiagnostics._();

  static final Set<String> _loggedBoxes = <String>{};

  static Future<void> logBoxOnce({
    required String label,
    required BoxBase<dynamic> box,
    required Duration openElapsed,
  }) async {
    if (!_loggedBoxes.add(label)) {
      return;
    }
    var fileBytes = -1;
    final path = box.path;
    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) {
          fileBytes = await file.length();
        }
      } catch (_) {
        fileBytes = -1;
      }
    }
    AppLogStore.info(
      'storage metrics',
      'box=$label entries=${box.length} fileBytes=$fileBytes '
          'openMs=${openElapsed.inMilliseconds}',
    );
  }
}
