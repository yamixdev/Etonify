import 'dart:convert';

/// Serializes policy writes and coalesces only identical latest requests.
/// Failed writes are never remembered as successfully applied policies.
class ProxyExclusionSync {
  ProxyExclusionSync({required this.apply});
  final Future<void> Function(List<String> tags, int runtimeGeneration) apply;
  String? _appliedKey;
  String? _pendingKey;
  Future<void>? _pending;
  Future<void> _tail = Future.value();

  bool get hasPolicy => _appliedKey != null || _pending != null;

  Future<void> synchronize({
    required List<String> tags,
    required int runtimeGeneration,
  }) {
    final normalized = tags.toSet().toList()..sort();
    final key = '$runtimeGeneration:${jsonEncode(normalized)}';
    if (_pending == null && _appliedKey == key) return Future.value();
    if (_pendingKey == key) return _pending!;
    final task = _tail
        .then((_) => apply(List.unmodifiable(normalized), runtimeGeneration))
        .then((_) {
          _appliedKey = key;
        });
    _pendingKey = key;
    _pending = task;
    void clear() {
      if (identical(_pending, task)) {
        _pending = null;
        _pendingKey = null;
      }
    }

    _tail = task.then<void>(
      (_) => clear(),
      onError: (Object error, StackTrace stack) => clear(),
    );
    return task;
  }
}
