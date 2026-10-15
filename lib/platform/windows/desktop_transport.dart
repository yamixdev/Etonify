import 'dart:convert';
import 'dart:typed_data';
import 'desktop_contract.dart';

abstract interface class DesktopTransport {
  Future<void> open();
  Future<void> send(Uint8List frame);
  Stream<Uint8List> get frames;
  Future<void> close();
}

/// Native transports may decode/assemble on a worker. Exactly one source is
/// consumed; raw-frame transports retain the existing A1/A3 contract.
abstract interface class DecodedDesktopTransport implements DesktopTransport {
  Stream<RuntimeEnvelope> get envelopes;
}

class DesktopFrameCodec {
  static const maximumBodyLength = 16 * 1024 * 1024;
  static Uint8List encode(RuntimeEnvelope envelope) {
    final body = utf8.encode(jsonEncode(_ordered(envelope.toMap())));
    if (body.length > maximumBodyLength) {
      throw const FormatException('Desktop frame exceeds 16 MiB');
    }
    final frame = Uint8List(body.length + 4);
    ByteData.sublistView(frame).setUint32(0, body.length, Endian.little);
    frame.setRange(4, frame.length, body);
    return frame;
  }

  static Object? _ordered(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _ordered(value[key])};
    }
    if (value is List) return value.map(_ordered).toList();
    return value;
  }
}

/// Incremental, bounded decoder. Any malformed/truncated frame is terminal.
/// There is deliberately no request-ID state: completion ownership is in A3.
class DesktopFrameDecoder {
  final _header = Uint8List(4);
  int _headerUsed = 0;
  Uint8List? _body;
  int _bodyUsed = 0;
  bool _closed = false;

  List<RuntimeEnvelope> add(Uint8List chunk) {
    if (_closed) throw const FormatException('Desktop decoder is closed');
    final result = <RuntimeEnvelope>[];
    var offset = 0;
    try {
      while (offset < chunk.length) {
        if (_body == null) {
          final count = (4 - _headerUsed).clamp(0, chunk.length - offset);
          _header.setRange(_headerUsed, _headerUsed + count, chunk, offset);
          _headerUsed += count;
          offset += count;
          if (_headerUsed < 4) continue;
          final length = ByteData.sublistView(
            _header,
          ).getUint32(0, Endian.little);
          if (length == 0 || length > DesktopFrameCodec.maximumBodyLength) {
            throw const FormatException('Invalid desktop frame length');
          }
          // Allocate only after validating the complete header.
          _body = Uint8List(length);
        }
        final body = _body!;
        final count = (body.length - _bodyUsed).clamp(0, chunk.length - offset);
        body.setRange(_bodyUsed, _bodyUsed + count, chunk, offset);
        _bodyUsed += count;
        offset += count;
        if (_bodyUsed == body.length) {
          final decoded = jsonDecode(utf8.decode(body, allowMalformed: false));
          result.add(RuntimeEnvelope.fromMap(objectMap(decoded)));
          _body = null;
          _bodyUsed = 0;
          _headerUsed = 0;
        }
      }
      return result;
    } on Object {
      _closed = true;
      _body = null;
      rethrow;
    }
  }

  void finish() {
    if (_closed) throw const FormatException('Desktop decoder is closed');
    _closed = true;
    if (_headerUsed != 0 || _body != null) {
      _body = null;
      throw const FormatException('Truncated desktop frame');
    }
  }
}
