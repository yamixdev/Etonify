import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/subscription_profile_flow_controller.dart';

void main() {
  const controller = SubscriptionProfileFlowController();
  const session = SubscriptionProfilePageSession(
    activeProfileId: 'profile-a',
    selectedProxyTag: 'proxy-a',
    metadataFingerprint: 'metadata-a',
    activeRuntimeFingerprint: 'runtime-a',
  );

  test('does nothing when the sheet closes without changes', () {
    final decision = controller.decide(
      session: session,
      selectedProfileId: null,
      afterMetadataFingerprint: 'metadata-a',
      afterActiveRuntimeFingerprint: 'runtime-a',
      activeProfileRemoved: false,
      runtimeActiveOrRequested: true,
      connected: true,
    );

    expect(decision.kind, SubscriptionProfileFlowKind.unchanged);
    expect(decision.shouldReload, isFalse);
  });

  test('reloads metadata changes without restarting an unchanged runtime', () {
    final decision = controller.decide(
      session: session,
      selectedProfileId: null,
      afterMetadataFingerprint: 'metadata-b',
      afterActiveRuntimeFingerprint: 'runtime-a',
      activeProfileRemoved: false,
      runtimeActiveOrRequested: true,
      connected: true,
    );

    final plan = decision.reloadPlan!;
    expect(decision.kind, SubscriptionProfileFlowKind.reloadCurrentProfile);
    expect(plan.preferredSubscriptionId, 'profile-a');
    expect(plan.preferredProxyTag, 'proxy-a');
    expect(plan.applyRuntime, isFalse);
    expect(plan.restartRuntimeOnApply, isFalse);
  });

  test(
    'reapplies the active runtime after current profile settings change',
    () {
      final decision = controller.decide(
        session: session,
        selectedProfileId: null,
        afterMetadataFingerprint: 'metadata-b',
        afterActiveRuntimeFingerprint: 'runtime-b',
        activeProfileRemoved: false,
        runtimeActiveOrRequested: true,
        connected: true,
      );

      final plan = decision.reloadPlan!;
      expect(plan.applyRuntime, isTrue);
      expect(plan.resetRuntimeState, isTrue);
      expect(plan.restartRuntimeOnApply, isTrue);
      expect(plan.urlTestAfterApply, isTrue);
    },
  );

  test('switching to another profile stops an active runtime first', () {
    final decision = controller.decide(
      session: session,
      selectedProfileId: 'profile-b',
      afterMetadataFingerprint: 'metadata-a',
      afterActiveRuntimeFingerprint: 'runtime-a',
      activeProfileRemoved: false,
      runtimeActiveOrRequested: true,
      connected: true,
    );

    expect(decision.isProfileSwitch, isTrue);
    expect(decision.shouldStopRuntime, isTrue);
    expect(decision.reloadPlan!.preferredSubscriptionId, 'profile-b');
    expect(decision.reloadPlan!.applyRuntime, isFalse);
  });

  test('reselecting the active profile keeps the runtime running', () {
    final decision = controller.decide(
      session: session,
      selectedProfileId: 'profile-a',
      afterMetadataFingerprint: 'metadata-a',
      afterActiveRuntimeFingerprint: 'runtime-a',
      activeProfileRemoved: false,
      runtimeActiveOrRequested: true,
      connected: true,
    );

    expect(decision.isProfileSwitch, isTrue);
    expect(decision.shouldStopRuntime, isFalse);
    expect(decision.reloadPlan!.preferredProxyTag, isEmpty);
  });

  test(
    'deleting the active profile stops the tunnel instead of adopting one',
    () {
      final decision = controller.decide(
        session: session,
        selectedProfileId: null,
        afterMetadataFingerprint: 'metadata-b',
        afterActiveRuntimeFingerprint: null,
        activeProfileRemoved: true,
        runtimeActiveOrRequested: true,
        connected: true,
      );

      expect(decision.isProfileSwitch, isFalse);
      expect(decision.shouldStopRuntime, isTrue);
      expect(decision.stopReason, 'active_profile_deleted');

      final plan = decision.reloadPlan!;
      expect(plan.applyRuntime, isFalse);
      expect(plan.resetRuntimeState, isTrue);
      expect(plan.restartRuntimeOnApply, isFalse);
      expect(plan.urlTestAfterApply, isFalse);
    },
  );

  test('deleting the active profile while disconnected reloads only', () {
    final decision = controller.decide(
      session: session,
      selectedProfileId: null,
      afterMetadataFingerprint: 'metadata-b',
      afterActiveRuntimeFingerprint: null,
      activeProfileRemoved: true,
      runtimeActiveOrRequested: false,
      connected: false,
    );

    expect(decision.shouldStopRuntime, isFalse);
    expect(decision.reloadPlan!.applyRuntime, isFalse);
  });

  test('deleting some other profile leaves the running tunnel up', () {
    final decision = controller.decide(
      session: session,
      selectedProfileId: null,
      afterMetadataFingerprint: 'metadata-b',
      afterActiveRuntimeFingerprint: 'runtime-a',
      activeProfileRemoved: false,
      runtimeActiveOrRequested: true,
      connected: true,
    );

    expect(decision.shouldStopRuntime, isFalse);
    expect(decision.reloadPlan!.restartRuntimeOnApply, isFalse);
  });
}
