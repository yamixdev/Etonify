import 'dart:async';
import 'package:flutter/services.dart';
import 'desktop_contract.dart';
import 'desktop_transport.dart';
import 'desktop_wire_decoder.dart';

class MethodChannelDesktopTransport implements DecodedDesktopTransport {
  MethodChannelDesktopTransport() {
    _envelopes = StreamController<RuntimeEnvelope>(onListen: _startReading);
  }
  static const _channel = MethodChannel('com.etonify.desktop/runtime');
  late final StreamController<RuntimeEnvelope> _envelopes;
  DesktopWireDecoder? _decoder;
  StreamSubscription<Object>? _decoderErrors;
  Future<void>? _opening;
  Future<void>? _closing;
  int? _lease;
  bool _closed = false;
  bool _reading = false;

  @override
  Future<void> open() => _opening ??= _open();

  Future<void> _open() async {
    if (_closed) throw StateError('Windows transport closed');
    final decoder = await DesktopWireDecoder.create();
    _decoder = decoder;
    if (_closed) {
      await decoder.close();
      throw StateError('Windows transport closed');
    }
    _decoderErrors = decoder.errors.listen(_fail);
    try {
      final lease = await _channel.invokeMethod<int>('open');
      if (lease == null || lease <= 0) {
        throw const FormatException('Invalid Windows transport lease');
      }
      if (_closed) {
        await _channel.invokeMethod<void>('close', {'lease': lease});
        throw StateError('Windows transport closed');
      }
      _lease = lease;
      _startReading();
    } on Object {
      await close();
      rethrow;
    }
  }

  void _startReading() {
    if (_reading || _closed || _lease == null || !_envelopes.hasListener) {
      return;
    }
    _reading = true;
    unawaited(_read());
  }

  Future<void> _read() async {
    try {
      while (!_closed) {
        final data = await _channel.invokeMethod<Uint8List>('read', {
          'lease': _lease,
        });
        if (_closed) return;
        if (data == null) {
          await _decoder!.finish();
          await close();
          return;
        }
        if (data.isEmpty || data.length > 65536) {
          throw const FormatException('Invalid native read size');
        }
        final decoded = await _decoder!.decode(data);
        if (_closed) return;
        for (final envelope in decoded) {
          _envelopes.add(envelope);
        }
      }
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) {
    if (_closed) return;
    _envelopes.addError(
      error is FormatException
          ? const FormatException('Invalid Windows runtime message')
          : StateError('Windows runtime transport ended'),
    );
    unawaited(close());
  }

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    final lease = _lease;
    _lease = null;
    try {
      if (lease != null) {
        await _channel.invokeMethod<void>('close', {'lease': lease});
      }
    } finally {
      await _decoderErrors?.cancel();
      await _decoder?.close();
      // An unopened/listener-less controller must not delay native teardown.
      unawaited(_envelopes.close());
    }
  }

  @override
  Future<void> send(Uint8List frame) async {
    if (_closed || _lease == null) throw StateError('Windows transport closed');
    if (frame.length < 5 ||
        frame.length > DesktopFrameCodec.maximumBodyLength + 4) {
      throw const FormatException('Invalid outbound desktop frame size');
    }
    await _channel.invokeMethod<void>('write', {
      'lease': _lease,
      'frame': frame,
    });
  }

  @override
  Stream<Uint8List> get frames =>
      throw StateError('Use decoded Windows envelopes');
  @override
  Stream<RuntimeEnvelope> get envelopes => _envelopes.stream;
}
