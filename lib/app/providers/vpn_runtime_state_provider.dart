import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/app/runtime_connection_controller.dart';

class VpnRuntimeState {
  const VpnRuntimeState({
    this.phase = AppConnectionPhase.idle,
    this.retryScheduled = false,
    this.networkUsable,
    this.networkGeneration = 0,
  });

  final AppConnectionPhase phase;
  final bool retryScheduled;
  final bool? networkUsable;
  final int networkGeneration;

  bool get connected => phase == AppConnectionPhase.connected;
  bool get starting => switch (phase) {
    AppConnectionPhase.preparing ||
    AppConnectionPhase.starting ||
    AppConnectionPhase.recovering => true,
    _ => false,
  };
  bool get transitionInProgress => switch (phase) {
    AppConnectionPhase.preparing ||
    AppConnectionPhase.starting ||
    AppConnectionPhase.stopping ||
    AppConnectionPhase.recovering => true,
    _ => false,
  };

  VpnRuntimeState copyWith({
    AppConnectionPhase? phase,
    bool? retryScheduled,
    bool? networkUsable,
    bool clearNetworkUsable = false,
    int? networkGeneration,
  }) {
    return VpnRuntimeState(
      phase: phase ?? this.phase,
      retryScheduled: retryScheduled ?? this.retryScheduled,
      networkUsable: clearNetworkUsable
          ? null
          : networkUsable ?? this.networkUsable,
      networkGeneration: networkGeneration ?? this.networkGeneration,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VpnRuntimeState &&
        other.phase == phase &&
        other.retryScheduled == retryScheduled &&
        other.networkUsable == networkUsable &&
        other.networkGeneration == networkGeneration;
  }

  @override
  int get hashCode =>
      Object.hash(phase, retryScheduled, networkUsable, networkGeneration);
}

class VpnRuntimeStateNotifier extends Notifier<VpnRuntimeState> {
  @override
  VpnRuntimeState build() => const VpnRuntimeState();

  void transitionTo(AppConnectionPhase phase, {required bool retryScheduled}) {
    final next = state.copyWith(phase: phase, retryScheduled: retryScheduled);
    if (next != state) {
      state = next;
    }
  }

  void updateNetwork({required int generation, required bool usable}) {
    final next = state.copyWith(
      networkGeneration: generation,
      networkUsable: usable,
    );
    if (next != state) {
      state = next;
    }
  }

  void clearNetwork() {
    final next = state.copyWith(clearNetworkUsable: true);
    if (next != state) {
      state = next;
    }
  }
}

final vpnRuntimeStateProvider =
    NotifierProvider<VpnRuntimeStateNotifier, VpnRuntimeState>(
      VpnRuntimeStateNotifier.new,
      name: 'vpnRuntimeStateProvider',
    );
