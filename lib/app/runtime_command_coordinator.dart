import 'dart:async';

typedef SelectOutboundCommand =
    Future<void> Function(String groupTag, String outboundTag);

enum RuntimeSelectionStatus { applied, stale, failed }

class RuntimeSelectionResult {
  const RuntimeSelectionResult._(this.status, this.elapsed, [this.error]);

  final RuntimeSelectionStatus status;
  final Duration elapsed;
  final Object? error;

  bool get applied => status == RuntimeSelectionStatus.applied;
}

/// Owns control-command policy for the single libbox runtime.
///
/// A timed-out native RPC can still finish later, so selector commands are
/// never retried automatically. Retrying would enqueue the same mutation
/// twice and used to trigger restart races with URLTest.
class RuntimeCommandCoordinator {
  RuntimeCommandCoordinator({
    required SelectOutboundCommand selectOutbound,
    this.selectionTimeout = const Duration(seconds: 20),
  }) : _selectOutbound = selectOutbound;

  final SelectOutboundCommand _selectOutbound;
  final Duration selectionTimeout;

  int _generation = 0;
  bool _disposed = false;

  void invalidate() {
    _generation++;
  }

  Future<RuntimeSelectionResult> selectOutbound(
    String outboundTag, {
    SelectOutboundCommand? command,
  }) async {
    final normalizedTag = outboundTag.trim();
    final generation = ++_generation;
    final stopwatch = Stopwatch()..start();
    if (_disposed || normalizedTag.isEmpty) {
      stopwatch.stop();
      return RuntimeSelectionResult._(
        RuntimeSelectionStatus.stale,
        stopwatch.elapsed,
      );
    }

    try {
      await (command ?? _selectOutbound)(
        'select',
        normalizedTag,
      ).timeout(selectionTimeout);
      stopwatch.stop();
      if (_disposed || generation != _generation) {
        return RuntimeSelectionResult._(
          RuntimeSelectionStatus.stale,
          stopwatch.elapsed,
        );
      }
      return RuntimeSelectionResult._(
        RuntimeSelectionStatus.applied,
        stopwatch.elapsed,
      );
    } catch (error) {
      stopwatch.stop();
      if (_disposed || generation != _generation) {
        return RuntimeSelectionResult._(
          RuntimeSelectionStatus.stale,
          stopwatch.elapsed,
          error,
        );
      }
      return RuntimeSelectionResult._(
        RuntimeSelectionStatus.failed,
        stopwatch.elapsed,
        error,
      );
    }
  }

  void dispose() {
    _disposed = true;
    invalidate();
  }
}
