import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

const _defaultReadTimeout = Duration(seconds: 20);
const _maxSubscriptionFileBytes = 64 * 1024 * 1024;

class SubscriptionFileReadException implements Exception {
  const SubscriptionFileReadException(this.reason);

  final String reason;

  @override
  String toString() => 'Subscription file read failed: $reason';
}

Future<String> readSubscriptionFile(
  PlatformFile file, {
  Duration timeout = _defaultReadTimeout,
}) async {
  if ((file.lengthSync() ?? 0) > _maxSubscriptionFileBytes) {
    throw const SubscriptionFileReadException('file is larger than 64 MiB');
  }

  final bytes = await _readFileBytes(file).timeout(timeout);
  if (bytes.isEmpty) {
    throw const SubscriptionFileReadException('file is empty');
  }

  final transferable = TransferableTypedData.fromList([bytes]);
  final content = await Isolate.run(
    () => _decodeTextFile(transferable.materialize().asUint8List()),
    debugName: 'etonify-read-subscription-file',
  ).timeout(timeout);
  if (content.isEmpty) {
    throw const SubscriptionFileReadException('decoded content is empty');
  }
  return content;
}

Future<Uint8List> _readFileBytes(PlatformFile file) async {
  try {
    return await _collectBytes(file.readAsByteStream());
  } on SubscriptionFileReadException {
    rethrow;
  } catch (_) {
    throw const SubscriptionFileReadException(
      'the document provider returned no readable data',
    );
  }
}

Future<Uint8List> _collectBytes(Stream<List<int>> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (builder.length + chunk.length > _maxSubscriptionFileBytes) {
      throw const SubscriptionFileReadException('file is larger than 64 MiB');
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}

String _decodeTextFile(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true).trim();
  }
  if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
    return _decodeUtf16(bytes, littleEndian: true).trim();
  }
  if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
    return _decodeUtf16(bytes, littleEndian: false).trim();
  }
  return utf8.decode(bytes, allowMalformed: true).trim();
}

String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
  final codeUnits = <int>[];
  for (var index = 2; index + 1 < bytes.length; index += 2) {
    final first = bytes[index];
    final second = bytes[index + 1];
    codeUnits.add(littleEndian ? first | (second << 8) : (first << 8) | second);
  }
  return String.fromCharCodes(codeUnits);
}
