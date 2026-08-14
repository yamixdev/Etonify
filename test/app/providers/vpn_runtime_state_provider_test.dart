import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/providers/vpn_runtime_state_provider.dart';
import 'package:meow_client/app/runtime_connection_controller.dart';

void main() {
  test('derives connection flags from one immutable phase', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(vpnRuntimeStateProvider.notifier);

    notifier.transitionTo(AppConnectionPhase.starting, retryScheduled: false);
    expect(container.read(vpnRuntimeStateProvider).starting, isTrue);
    expect(
      container.read(vpnRuntimeStateProvider).transitionInProgress,
      isTrue,
    );

    notifier.transitionTo(AppConnectionPhase.connected, retryScheduled: false);
    expect(container.read(vpnRuntimeStateProvider).connected, isTrue);
    expect(
      container.read(vpnRuntimeStateProvider).transitionInProgress,
      isFalse,
    );
  });

  test('network handover replaces generation atomically', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(vpnRuntimeStateProvider.notifier);

    notifier.updateNetwork(generation: 12, usable: false);
    expect(container.read(vpnRuntimeStateProvider).networkUsable, isFalse);
    expect(container.read(vpnRuntimeStateProvider).networkGeneration, 12);

    notifier.updateNetwork(generation: 13, usable: true);
    expect(container.read(vpnRuntimeStateProvider).networkUsable, isTrue);
    expect(container.read(vpnRuntimeStateProvider).networkGeneration, 13);
  });
}
