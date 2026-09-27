import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/subscriptions/subscription_file_reader.dart';

void main() {
  test('reads a picked txt file from its stream', () async {
    final source = utf8.encode(
      'vless://uuid@server.example:443?security=tls#Node',
    );
    final file = _TestPlatformFile(
      name: 'nodes.txt',
      knownLength: source.length,
      chunks: Stream<Uint8List>.fromIterable([
        Uint8List.fromList(source.sublist(0, 12)),
        Uint8List.fromList(source.sublist(12)),
      ]),
    );

    expect(await readSubscriptionFile(file), utf8.decode(source));
  });

  test('removes an UTF-8 BOM from a picked json file', () async {
    const json = '{"outbounds":[{"type":"direct","tag":"direct"}]}';
    final bytes = Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode(json)]);
    final file = _TestPlatformFile(
      name: 'profile.json',
      knownLength: bytes.length,
      chunks: Stream<Uint8List>.value(bytes),
    );

    expect(await readSubscriptionFile(file), json);
  });

  test('reports a picked file without readable data', () async {
    final file = _TestPlatformFile(name: 'nodes.txt', knownLength: 12);

    await expectLater(
      readSubscriptionFile(file),
      throwsA(isA<SubscriptionFileReadException>()),
    );
  });

  test('rejects an oversized file even when its length is unknown', () async {
    final file = _TestPlatformFile(
      name: 'nodes.txt',
      chunks: Stream<Uint8List>.value(Uint8List(64 * 1024 * 1024 + 1)),
    );

    await expectLater(
      readSubscriptionFile(file),
      throwsA(isA<SubscriptionFileReadException>()),
    );
  });
}

base class _TestPlatformFile extends PlatformFile {
  _TestPlatformFile({
    required this.name,
    this.knownLength,
    Stream<Uint8List>? chunks,
  }) : _chunks = chunks;

  @override
  final String name;

  final int? knownLength;
  final Stream<Uint8List>? _chunks;

  @override
  Uri get uri => Uri.parse('test:///$name');

  @override
  Never get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => knownLength;

  @override
  Future<int?> length() async => knownLength;

  @override
  Future<Uint8List> readAsBytes() async =>
      throw UnimplementedError('The reader must stream files');

  @override
  Stream<Uint8List> readAsByteStream() =>
      _chunks ?? Stream<Uint8List>.error(StateError('no readable data'));
}
