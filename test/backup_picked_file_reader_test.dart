import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/backup/etonify_backup_service.dart';
import 'package:meow_client/features/settings/backup_picked_file_reader.dart';

void main() {
  test('reads a backup from a streamed document', () async {
    final file = _TestPlatformFile(
      knownLength: 3,
      chunks: Stream<Uint8List>.fromIterable([
        Uint8List.fromList([1]),
        Uint8List.fromList([2, 3]),
      ]),
    );

    expect(await readBackupPickedFile(file), [1, 2, 3]);
  });

  test(
    'rejects a backup larger than the limit when length is unknown',
    () async {
      final file = _TestPlatformFile(
        chunks: Stream<Uint8List>.value(
          Uint8List(EtonifyBackupService.maxImportBytes + 1),
        ),
      );

      await expectLater(
        readBackupPickedFile(file),
        throwsA(isA<EtonifyBackupException>()),
      );
    },
  );
}

base class _TestPlatformFile extends PlatformFile {
  _TestPlatformFile({this.knownLength, required this.chunks});

  final int? knownLength;
  final Stream<Uint8List> chunks;

  @override
  String get name => 'backup.etonify-profile';

  @override
  Uri get uri => Uri.parse('test:///backup');

  @override
  Never get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => knownLength;

  @override
  Future<int?> length() async => knownLength;

  @override
  Future<Uint8List> readAsBytes() async =>
      throw UnimplementedError('Backup imports must stream files');

  @override
  Stream<Uint8List> readAsByteStream() => chunks;
}
