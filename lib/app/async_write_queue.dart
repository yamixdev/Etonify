/// Serializes asynchronous writes while keeping each caller's completion and
/// error tied to the write it requested.
final class AsyncWriteQueue<T> {
  AsyncWriteQueue(this._write);

  final Future<void> Function(T value) _write;
  Future<void> _tail = Future<void>.value();

  Future<void> add(T value) {
    final operation = _tail.then((_) => _write(value));
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> get idle => _tail;
}
