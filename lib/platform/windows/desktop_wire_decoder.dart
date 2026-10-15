import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'desktop_contract.dart';
import 'desktop_transport.dart';

/// One long-lived worker owns UTF-8/JSON decoding and large stream assembly.
/// The UI receives decoded objects, never re-encoded multi-megabyte frames.
class DesktopWireDecoder {
  DesktopWireDecoder._();
  final _port = ReceivePort();
  final _ready = Completer<SendPort>();
  final _pending = <int, (Completer<List<RuntimeEnvelope>>, int)>{};
  final _errors = StreamController<Object>.broadcast();
  Isolate? _worker;
  StreamSubscription<Object?>? _subscription;
  late SendPort _input;
  var _sequence = 0;
  var _queuedBytes = 0;
  var _closed = false;
  var _finished = false;
  Stream<Object> get errors => _errors.stream;

  static Future<DesktopWireDecoder> create() async {
    final decoder = DesktopWireDecoder._();
    decoder._subscription = decoder._port.listen(decoder._receive);
    try {
      decoder._worker = await Isolate.spawn(
        _decodeWorker,
        decoder._port.sendPort,
        onExit: decoder._port.sendPort,
        onError: decoder._port.sendPort,
        debugName: 'Etonify desktop wire',
      );
      decoder._input = await decoder._ready.future.timeout(
        const Duration(seconds: 10),
      );
      return decoder;
    } on Object {
      await decoder.close();
      rethrow;
    }
  }

  Future<List<RuntimeEnvelope>> decode(Uint8List bytes) {
    if (_closed || _finished) {
      return Future.error(StateError('Desktop decoder closed'));
    }
    if (_pending.length >= 8 ||
        _queuedBytes + bytes.length > 2 * (16777216 + 4)) {
      const error = FormatException('Desktop decoder queue limit exceeded');
      _fail(error);
      return Future.error(error);
    }
    return _request(
      'data',
      TransferableTypedData.fromList([bytes]),
      bytes.length,
    );
  }

  Future<List<RuntimeEnvelope>> _request(
    String operation,
    Object? data,
    int length,
  ) {
    final completion = Completer<List<RuntimeEnvelope>>();
    final id = ++_sequence;
    _pending[id] = (completion, length);
    _queuedBytes += length;
    _input.send([id, operation, data]);
    return completion.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        const error = FormatException('Desktop decoding timed out');
        _fail(error);
        throw error;
      },
    );
  }

  void _receive(Object? message) {
    if (_closed) return;
    if (message is SendPort) {
      if (!_ready.isCompleted) _ready.complete(message);
      return;
    }
    if (message is! List<Object?> ||
        message.length != 3 ||
        message[0] is! int) {
      _fail(const FormatException('Desktop decoder worker terminated'));
      return;
    }
    if (message[1] != true) {
      _fail(const FormatException('Invalid or incomplete desktop message'));
      return;
    }
    final pending = _pending.remove(message[0]);
    if (pending == null) return;
    _queuedBytes -= pending.$2;
    final envelopes = message[2];
    if (envelopes is! List<RuntimeEnvelope>) {
      _fail(const FormatException('Invalid desktop decoder result'));
      pending.$1.completeError(
        const FormatException('Invalid desktop decoder result'),
      );
      return;
    }
    pending.$1.complete(envelopes);
  }

  Future<void> finish() async {
    if (_closed) throw StateError('Desktop decoder closed');
    if (_finished) return;
    await _request('finish', null, 0);
    _finished = true;
  }

  void _fail(Object error, {bool notify = true}) {
    if (_closed) return;
    _closed = true;
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final pending in _pending.values) {
      pending.$1.completeError(error);
    }
    _pending.clear();
    _queuedBytes = 0;
    if (notify) _errors.add(error);
    _worker?.kill(priority: Isolate.immediate);
    _port.close();
    unawaited(_subscription?.cancel());
    unawaited(_errors.close());
  }

  Future<void> close() async {
    if (!_closed) _fail(StateError('Desktop decoder closed'), notify: false);
  }
}

void _decodeWorker(SendPort owner) {
  final commands = ReceivePort();
  final frames = DesktopFrameDecoder();
  final streams = DesktopWireAssembler();
  var terminal = false;
  late Timer expiry;
  void fail(int id) {
    if (terminal) return;
    terminal = true;
    owner.send([id, false, null]);
    expiry.cancel();
    commands.close();
  }

  expiry = Timer.periodic(const Duration(seconds: 1), (_) {
    try {
      streams.expire();
    } on Object {
      fail(-1);
    }
  });
  commands.listen((Object? value) {
    if (terminal) return;
    final command = value! as List<Object?>;
    final id = command[0]! as int;
    try {
      final output = <RuntimeEnvelope>[];
      if (command[1] == 'finish') {
        frames.finish();
        streams.finish();
        expiry.cancel();
      } else {
        final bytes = (command[2]! as TransferableTypedData)
            .materialize()
            .asUint8List();
        for (final envelope in frames.add(bytes)) {
          output.addAll(streams.accept(envelope).map(_materializeDownload));
        }
      }
      owner.send([id, true, output]);
    } on Object {
      // Do not send parser excerpts containing subscription URLs or secrets.
      fail(id);
    }
  });
  owner.send(commands.sendPort);
}

RuntimeEnvelope _materializeDownload(RuntimeEnvelope envelope) {
  if (envelope.kind != RuntimeEnvelopeKind.response ||
      envelope.method != 'fetchUrlViaOutbound' ||
      envelope.error != null) {
    return envelope;
  }
  final payload = objectMap(envelope.payload);
  final body = payload['body'];
  if (body is! List<Object?> || body.length > 16777216) {
    throw const FormatException('Invalid download body');
  }
  for (final byte in body) {
    if (byte is! int || byte < 0 || byte > 255) {
      throw const FormatException('Invalid download byte');
    }
  }
  return RuntimeEnvelope(
    kind: envelope.kind,
    id: envelope.id,
    sessionId: envelope.sessionId,
    configGeneration: envelope.configGeneration,
    networkGeneration: envelope.networkGeneration,
    method: envelope.method,
    payload: {...payload, 'body': Uint8List.fromList(body.cast<int>())},
  );
}

/// Stateful wire validation, run only by the decoder worker in production.
class DesktopWireAssembler {
  DesktopWireAssembler({int Function()? clockMillis}) : _clock = clockMillis;
  final int Function()? _clock;
  final _elapsed = Stopwatch()..start();
  int get _now => _clock?.call() ?? _elapsed.elapsedMilliseconds;
  final _active = <String, _Assembly>{};
  final _completed = <String>{};
  final _retired = <String, (String, String, int, int)>{};
  final _cancelledReplies = <String, (String, String, int, int)>{};
  (String, int, int)? _subscriptionTuple;
  var _subscriptionsStopped = false;
  var _reserved = 0;

  List<RuntimeEnvelope> accept(RuntimeEnvelope envelope) {
    _applyControl(envelope);
    expire();
    final chunk = envelope.method == 'streamChunk';
    final payload = envelope.payload;
    final descriptor =
        envelope.kind == RuntimeEnvelopeKind.response &&
        payload is Map &&
        payload.containsKey('streamId') &&
        payload.containsKey('encoding');
    if (!chunk && !descriptor) return [envelope];
    if (envelope.id.isNotEmpty && _cancelledReplies.containsKey(envelope.id)) {
      if (_cancelledReplies[envelope.id] != _identity(envelope)) {
        throw const FormatException('Cancelled reply identity changed');
      }
      return [];
    }
    final current = _subscriptionTuple;
    if (envelope.id.isEmpty &&
        current != null &&
        (envelope.configGeneration < current.$2 ||
            (envelope.configGeneration == current.$2 &&
                (envelope.sessionId != current.$1 ||
                    envelope.networkGeneration < current.$3)) ||
            (_tuple(envelope) == current && _subscriptionsStopped))) {
      return [];
    }
    final data = objectMap(payload);
    final streamId = stringValue(data['streamId'], 'streamId');
    final method = stringValue(data['method'], 'method');
    final total = integerValue(data['total'], 'total');
    final size = integerValue(data['totalBytes'], 'totalBytes');
    if (streamId.isEmpty ||
        streamId.length > 128 ||
        method.isEmpty ||
        method == 'streamChunk' ||
        data['encoding'] != 'base64-json' ||
        size <= 0 ||
        size > 16777216 ||
        total != (size + 45055) ~/ 45056 ||
        _completed.contains(streamId)) {
      throw const FormatException('Invalid desktop stream declaration');
    }
    if (descriptor && (envelope.id.isEmpty || envelope.method != method)) {
      throw const FormatException('Invalid desktop stream response');
    }
    if (chunk && envelope.kind != RuntimeEnvelopeKind.event) {
      throw const FormatException('Invalid desktop stream chunk kind');
    }
    if (_retired.containsKey(streamId)) {
      if (_retired[streamId] != _identity(envelope)) {
        throw const FormatException('Retired stream identity changed');
      }
      return [];
    }
    final state =
        _active[streamId] ?? _begin(streamId, envelope, method, total, size);
    state.check(envelope, method, total, size);
    if (descriptor) {
      if (state.response != null) {
        throw const FormatException('Duplicate stream descriptor');
      }
      state.response = envelope;
    } else {
      final index = integerValue(data['index'], 'index');
      final encoded = stringValue(data['data'], 'data');
      if (index != state.nextIndex ||
          index >= total ||
          encoded.length > 60076) {
        throw const FormatException('Invalid desktop stream order');
      }
      final bytes = base64Decode(encoded);
      final expected = index == total - 1 ? size - index * 45056 : 45056;
      if (bytes.length != expected ||
          DesktopFrameCodec.encode(envelope).length > 65536) {
        throw const FormatException('Invalid desktop stream chunk size');
      }
      state.bytes.add(bytes);
      state.nextIndex++;
    }
    if (state.nextIndex != total ||
        (envelope.id.isNotEmpty && state.response == null)) {
      return [];
    }
    final decoded = jsonDecode(
      utf8.decode(state.bytes.takeBytes(), allowMalformed: false),
    );
    final original = state.response ?? state.first;
    final result = RuntimeEnvelope(
      kind: state.response == null
          ? RuntimeEnvelopeKind.event
          : RuntimeEnvelopeKind.response,
      id: original.id,
      sessionId: original.sessionId,
      configGeneration: original.configGeneration,
      networkGeneration: original.networkGeneration,
      method: method,
      payload: decoded,
    );
    _active.remove(streamId);
    _reserved -= size;
    _completed.add(streamId);
    if (_completed.length > 256) _completed.remove(_completed.first);
    return [result];
  }

  static (String, String, int, int) _identity(RuntimeEnvelope e) =>
      (e.id, e.sessionId, e.configGeneration, e.networkGeneration);
  static (String, int, int) _tuple(RuntimeEnvelope e) =>
      (e.sessionId, e.configGeneration, e.networkGeneration);

  void _retireWhere(bool Function(_Assembly) predicate) {
    for (final entry in _active.entries.toList()) {
      if (!predicate(entry.value)) continue;
      _active.remove(entry.key);
      _reserved -= entry.value.size;
      entry.value.bytes.clear();
      _retired[entry.key] = _identity(entry.value.first);
      if (_retired.length > 256) _retired.remove(_retired.keys.first);
    }
  }

  void _applyControl(RuntimeEnvelope envelope) {
    // A failed response explicitly completes its request, including a partial
    // body. Already queued chunks from that exact request are retired as well.
    if (envelope.kind == RuntimeEnvelopeKind.response &&
        envelope.error != null &&
        envelope.id.isNotEmpty) {
      _cancelledReplies[envelope.id] = _identity(envelope);
      if (_cancelledReplies.length > 256) {
        _cancelledReplies.remove(_cancelledReplies.keys.first);
      }
      _retireWhere((state) => _identity(state.first) == _identity(envelope));
    }
    // Event snapshots carry the actual producer tuple. RPC snapshot response
    // headers are correlation, so must never be interpreted as producer state.
    if (envelope.kind != RuntimeEnvelopeKind.event ||
        envelope.method != 'snapshot') {
      return;
    }
    final value = objectMap(envelope.payload);
    if (value['sessionId'] != envelope.sessionId ||
        value['configGeneration'] != envelope.configGeneration ||
        value['networkGeneration'] != envelope.networkGeneration) {
      throw const FormatException('Snapshot producer identity changed');
    }
    final next = _tuple(envelope);
    final current = _subscriptionTuple;
    if (current != null &&
        (next.$2 < current.$2 ||
            (next.$2 == current.$2 &&
                (next.$1 != current.$1 || next.$3 < current.$3)))) {
      return;
    }
    if (next != current) {
      _subscriptionTuple = next;
      _subscriptionsStopped = false;
      _retireWhere(
        (state) => state.first.id.isEmpty && _tuple(state.first) != next,
      );
    }
    if (const {'stopping', 'stopped', 'failed'}.contains(value['phase'])) {
      _subscriptionsStopped = true;
      _retireWhere(
        (state) => state.first.id.isEmpty && _tuple(state.first) == next,
      );
    }
  }

  _Assembly _begin(
    String id,
    RuntimeEnvelope first,
    String method,
    int total,
    int size,
  ) {
    if (_active.length >= 4 || _reserved + size > 67108864) {
      throw const FormatException('Desktop stream assembly budget exceeded');
    }
    final state = _Assembly(first, method, total, size, _now);
    _active[id] = state;
    _reserved += size;
    return state;
  }

  void expire() {
    if (_active.values.any((state) => _now - state.createdAt > 15000)) {
      throw const FormatException('Desktop stream assembly expired');
    }
  }

  void finish() {
    if (_active.isNotEmpty) {
      throw const FormatException('Incomplete desktop stream');
    }
  }
}

class _Assembly {
  _Assembly(this.first, this.method, this.total, this.size, this.createdAt);
  final RuntimeEnvelope first;
  final String method;
  final int total;
  final int size;
  final int createdAt;
  final bytes = BytesBuilder(copy: false);
  var nextIndex = 0;
  RuntimeEnvelope? response;
  void check(RuntimeEnvelope next, String nextMethod, int count, int length) {
    if (next.id != first.id ||
        next.sessionId != first.sessionId ||
        next.configGeneration != first.configGeneration ||
        next.networkGeneration != first.networkGeneration ||
        nextMethod != method ||
        count != total ||
        length != size) {
      throw const FormatException('Desktop stream identity changed');
    }
  }
}
