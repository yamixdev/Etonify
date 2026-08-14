import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/app/latency_coordinator.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';

/// Lightweight state for the current URLTest session.
///
/// Per-proxy latency values intentionally stay in [ProxyRuntimeVisualStore].
/// Publishing thousands of proxy rows through a Riverpod state object would
/// copy collections and rebuild unrelated rows for every native event.
class ProxyLatencySessionState {
  const ProxyLatencySessionState({
    this.running = false,
    this.kind,
    this.targetTag = '',
    this.generation = 0,
  });

  final bool running;
  final LatencySessionKind? kind;
  final String targetTag;
  final int generation;

  @override
  bool operator ==(Object other) {
    return other is ProxyLatencySessionState &&
        other.running == running &&
        other.kind == kind &&
        other.targetTag == targetTag &&
        other.generation == generation;
  }

  @override
  int get hashCode => Object.hash(running, kind, targetTag, generation);
}

class ProxyLatencySessionNotifier extends Notifier<ProxyLatencySessionState> {
  @override
  ProxyLatencySessionState build() => const ProxyLatencySessionState();

  void update({
    required bool running,
    LatencySessionKind? kind,
    String targetTag = '',
  }) {
    final normalizedTarget = running ? targetTag.trim() : '';
    final normalizedKind = running ? kind : null;
    if (state.running == running &&
        state.kind == normalizedKind &&
        state.targetTag == normalizedTarget) {
      return;
    }
    state = ProxyLatencySessionState(
      running: running,
      kind: normalizedKind,
      targetTag: normalizedTarget,
      generation: state.generation + 1,
    );
  }
}

final proxyLatencySessionProvider =
    NotifierProvider<ProxyLatencySessionNotifier, ProxyLatencySessionState>(
      ProxyLatencySessionNotifier.new,
      name: 'proxyLatencySessionProvider',
    );

/// Owns the high-frequency, per-row runtime store for the lifetime of the
/// application ProviderScope.
final proxyRuntimeVisualStoreProvider = Provider<ProxyRuntimeVisualStore>((
  ref,
) {
  final store = ProxyRuntimeVisualStore();
  ref.onDispose(store.dispose);
  return store;
}, name: 'proxyRuntimeVisualStoreProvider');
