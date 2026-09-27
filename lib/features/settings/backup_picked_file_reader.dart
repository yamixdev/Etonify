import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:meow_client/data/backup/etonify_backup_service.dart';

Future<Uint8List> readBackupPickedFile(PlatformFile file) async {
  const maxBytes = EtonifyBackupService.maxImportBytes;
  if ((file.lengthSync() ?? 0) > maxBytes) {
    throw const EtonifyBackupException('Backup file is too large.');
  }

  final builder = BytesBuilder(copy: false);
  try {
    await for (final chunk in file.readAsByteStream()) {
      if (builder.length + chunk.length > maxBytes) {
        throw const EtonifyBackupException('Backup file is too large.');
      }
      builder.add(chunk);
    }
  } on EtonifyBackupException {
    rethrow;
  } catch (_) {
    throw const EtonifyBackupException('Could not read selected file.');
  }
  return builder.takeBytes();
}
