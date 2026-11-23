part of 'traffic_route_inspector.dart';

/// Reads the serialized SRS rules, including the domain succinct trie and
/// inclusive address ranges used by sing-box's binary rule sets.
class _SrsReader {
  _SrsReader(this._bytes, this._domain, this._ip, this._queryType);

  static const maxBytes = 32 * 1024 * 1024;

  final Uint8List _bytes;
  final String? _domain;
  final Uint8List? _ip;
  final int? _queryType;
  var _offset = 0;

  static Uint8List decode(Uint8List file) {
    if (file.length < 5 ||
        file[0] != 0x53 ||
        file[1] != 0x52 ||
        file[2] != 0x53 ||
        file[3] < 1 ||
        file[3] > 5) {
      throw const FormatException('Unsupported SRS header');
    }
    final output = _BoundedByteSink(maxBytes);
    final decoder = ZLibDecoder().startChunkedConversion(output);
    decoder.add(Uint8List.sublistView(file, 4));
    decoder.close();
    return output.takeBytes();
  }

  _Match match() {
    final count = _uvarint();
    var result = _Match.no;
    for (var index = 0; index < count; index++) {
      result = result.or(_rule(0));
    }
    if (_offset != _bytes.length) {
      throw const FormatException('Unexpected SRS data');
    }
    return result;
  }

  _Match _rule(int depth) {
    if (depth > 100) throw const FormatException('SRS logical rule depth');
    final type = _byte();
    if (type == 0) return _defaultRule();
    if (type != 1) throw const FormatException('Unknown SRS rule');
    final mode = _byte();
    if (mode > 1) throw const FormatException('Unknown SRS logical mode');
    final count = _uvarint();
    var result = mode == 0 ? _Match.yes : _Match.no;
    for (var index = 0; index < count; index++) {
      final child = _rule(depth + 1);
      result = mode == 0 ? result.and(child) : result.or(child);
    }
    return _bool() ? result.inverted : result;
  }

  _Match _defaultRule() {
    _Match? address;
    var result = _Match.yes;
    while (true) {
      final item = _byte();
      switch (item) {
        case 0: // query_type
          final values = _uint16List();
          result = result.and(_Match.of(values.contains(_queryType)));
        case 2: // domain / domain_suffix
          address = (address ?? _Match.no).or(_domainMatcher());
        case 3 || 4: // domain_keyword / domain_regex
          final patterns = _strings();
          final domain = _domain;
          address = (address ?? _Match.no).or(
            domain == null
                ? _Match.no
                : _matchesAny(
                    patterns,
                    (pattern) => item == 3
                        ? _Match.of(domain.contains(pattern))
                        : _matchRegex(domain, pattern),
                  ),
          );
        case 5: // source_ip_cidr
          _ipRanges(null);
          result = result.and(_Match.unknown);
        case 6: // ip_cidr
          address = (address ?? _Match.no).or(_ipRanges(_ip));
        case 7 || 9: // source_port / port
          _take(_uvarint() * 2);
          result = result.and(_Match.unknown);
        case 1 || 8 || 10 || 11 || 12 || 13 || 14 || 15 || 17 || 23:
          // String-list fields which require connection metadata.
          final count = _uvarint();
          for (var index = 0; index < count; index++) {
            _take(_uvarint());
          }
          result = result.and(_Match.unknown);
        case 18: // network_type
          _take(_uvarint());
          result = result.and(_Match.unknown);
        case 19 || 20: // network_is_expensive / network_is_constrained
          result = result.and(_Match.unknown);
        case 0xff:
          result = result.and(address ?? _Match.yes);
          return _bool() ? result.inverted : result;
        default:
          throw const FormatException('Unsupported SRS rule item');
      }
    }
  }

  _Match _domainMatcher() {
    _byte(); // Reserved marker, normally 0 or 1 in existing SRS files.
    final leaves = _take(_uvarint() * 8);
    final bitmap = _take(_uvarint() * 8);
    final labels = _take(_uvarint());
    final domain = _domain;
    if (domain == null) return _Match.no;
    final starts = _domainNodeStarts(bitmap, labels.length);
    final key = utf8.encode(
      String.fromCharCodes(domain.runes.toList().reversed),
    );
    var node = 0;
    for (final character in key) {
      var next = -1;
      for (var offset = starts[node]; offset < starts[node + 1] - 1; offset++) {
        final labelIndex = offset - node;
        final label = labels[labelIndex];
        if (label == 13 ||
            (label == 10 &&
                character == 46 &&
                _isLeaf(leaves, labelIndex + 1))) {
          return _Match.yes;
        }
        if (label == character) {
          next = labelIndex + 1;
          break;
        }
      }
      if (next == -1) return _Match.no;
      node = next;
    }
    if (_isLeaf(leaves, node)) return _Match.yes;
    for (var offset = starts[node]; offset < starts[node + 1] - 1; offset++) {
      final label = labels[offset - node];
      if (label == 10 || label == 13) return _Match.yes;
    }
    return _Match.no;
  }

  // A node's children occupy consecutive zero bits, then a one ends the
  // node. Every zero introduces one new node in breadth-first order.
  Uint32List _domainNodeStarts(Uint8List bitmap, int labelCount) {
    if (bitmap.length * 8 < labelCount * 2 + 1) {
      throw const FormatException('Invalid SRS domain bitmap');
    }
    final starts = Uint32List(labelCount + 2);
    var offset = 0;
    var labels = 0;
    for (var node = 0; node <= labelCount; node++) {
      if (node > labels) throw const FormatException('Invalid SRS domain node');
      starts[node] = offset;
      while (offset < bitmap.length * 8 && !_bitmapBit(bitmap, offset)) {
        ++labels;
        ++offset;
        if (labels > labelCount) {
          throw const FormatException('Invalid SRS domain label');
        }
      }
      if (offset >= bitmap.length * 8) {
        throw const FormatException('Incomplete SRS domain bitmap');
      }
      ++offset;
    }
    if (labels != labelCount) {
      throw const FormatException('Invalid SRS domain label count');
    }
    starts[labelCount + 1] = offset;
    return starts;
  }

  static bool _bitmapBit(Uint8List words, int offset) {
    // Words use big-endian serialization. Bit indices within a word are
    // counted from the least-significant bit.
    final byteOffset = (offset ~/ 64) * 8 + 7 - (offset % 64) ~/ 8;
    return (words[byteOffset] & (1 << (offset % 8))) != 0;
  }

  static bool _isLeaf(Uint8List leaves, int node) =>
      node < leaves.length * 8 && _bitmapBit(leaves, node);

  _Match _ipRanges(Uint8List? target) {
    if (_byte() != 1) throw const FormatException('Unsupported SRS IP set');
    final count = ByteData.sublistView(_take(8)).getUint64(0);
    if (count < 0 || count > (_bytes.length - _offset) ~/ 10) {
      throw const FormatException('Invalid SRS IP range count');
    }
    var matched = false;
    for (var index = 0; index < count; index++) {
      final from = _take(_uvarint());
      final to = _take(_uvarint());
      if ((from.length != 4 && from.length != 16) ||
          from.length != to.length ||
          _compare(from, to) > 0) {
        throw const FormatException('Invalid SRS IP range');
      }
      if (!matched && target != null && target.length == from.length) {
        matched = _compare(target, from) >= 0 && _compare(target, to) <= 0;
      }
    }
    if (_queryType != null) return _Match.unknown;
    return _Match.of(matched);
  }

  static int _compare(Uint8List a, Uint8List b) {
    for (var index = 0; index < a.length; index++) {
      final difference = a[index] - b[index];
      if (difference != 0) return difference;
    }
    return 0;
  }

  List<String> _strings() {
    final count = _uvarint();
    return [
      for (var index = 0; index < count; index++)
        utf8.decode(_take(_uvarint())),
    ];
  }

  List<int> _uint16List() {
    final count = _uvarint();
    final values = ByteData.sublistView(_take(count * 2));
    return [
      for (var index = 0; index < count; index++) values.getUint16(index * 2),
    ];
  }

  bool _bool() {
    final value = _byte();
    if (value > 1) throw const FormatException('Invalid SRS boolean');
    return value == 1;
  }

  int _uvarint() {
    var value = 0;
    for (var shift = 0; shift <= 28; shift += 7) {
      final byte = _byte();
      value |= (byte & 0x7f) << shift;
      if (byte < 0x80 && value <= maxBytes) return value;
    }
    throw const FormatException('Invalid SRS length');
  }

  int _byte() {
    if (_offset >= _bytes.length) {
      throw const FormatException('Truncated SRS file');
    }
    return _bytes[_offset++];
  }

  Uint8List _take(int count) {
    if (count > _bytes.length - _offset) {
      throw const FormatException('Truncated SRS file');
    }
    final start = _offset;
    _offset += count;
    return Uint8List.sublistView(_bytes, start, _offset);
  }
}

class _BoundedByteSink implements Sink<List<int>> {
  _BoundedByteSink(this._limit);

  final int _limit;
  final _builder = BytesBuilder(copy: false);

  @override
  void add(List<int> data) {
    if (data.length > _limit - _builder.length) {
      throw const FormatException('SRS file is too large');
    }
    _builder.add(data);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _builder.takeBytes();
}
