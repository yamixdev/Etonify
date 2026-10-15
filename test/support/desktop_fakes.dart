import 'dart:async';
import 'dart:typed_data';
import 'package:meow_client/platform/windows/desktop_transport.dart';

/// Test-only transport, without native APIs or a Windows runtime dependency.
class FakeDesktopTransport implements DesktopTransport {
  final _controller = StreamController<Uint8List>();
  final sentFrames = <Uint8List>[];
  bool _open = false;
  @override
  Stream<Uint8List> get frames => _controller.stream;
  @override
  Future<void> open() async {
    _open = true;
  }

  @override
  Future<void> send(Uint8List frame) async {
    if (!_open) throw StateError('Transport is not open');
    sentFrames.add(Uint8List.fromList(frame));
  }

  void inject(Uint8List frame, {int? chunkSize}) {
    final size = chunkSize ?? frame.length;
    if (size <= 0) throw ArgumentError.value(size, 'chunkSize');
    for (var offset = 0; offset < frame.length; offset += size) {
      _controller.add(
        Uint8List.fromList(
          frame.sublist(offset, (offset + size).clamp(0, frame.length)),
        ),
      );
    }
  }

  void injectCloseError(Object error) {
    _controller.addError(error);
  }

  @override
  Future<void> close() async {
    _open = false;
    await _controller.close();
  }
}
