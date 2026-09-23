class SubscriptionProfilePageSession {
  const SubscriptionProfilePageSession({
    required this.activeProfileId,
    required this.selectedProxyTag,
    required this.metadataFingerprint,
    required this.activeRuntimeFingerprint,
  });

  final String activeProfileId;
  final String selectedProxyTag;
  final String metadataFingerprint;
  final String? activeRuntimeFingerprint;
}

enum SubscriptionProfileFlowKind {
  unchanged,
  reloadCurrentProfile,
  selectProfile,
}

class SubscriptionReloadPlan {
  const SubscriptionReloadPlan({
    required this.preferredSubscriptionId,
    required this.preferredProxyTag,
    required this.applyRuntime,
    required this.resetRuntimeState,
    required this.restartRuntimeOnApply,
    required this.urlTestAfterApply,
  });

  final String preferredSubscriptionId;
  final String preferredProxyTag;
  final bool applyRuntime;
  final bool resetRuntimeState;
  final bool restartRuntimeOnApply;
  final bool urlTestAfterApply;
}

class SubscriptionProfileFlowDecision {
  const SubscriptionProfileFlowDecision._({
    required this.kind,
    this.reloadPlan,
    this.stopReason,
  });

  const SubscriptionProfileFlowDecision.unchanged()
    : this._(kind: SubscriptionProfileFlowKind.unchanged);

  final SubscriptionProfileFlowKind kind;
  final SubscriptionReloadPlan? reloadPlan;

  /// Why the tunnel has to come down before the plan is applied, or null when
  /// a running session may be left alone. [shouldStopRuntime] is derived from
  /// this so the two can never disagree.
  final String? stopReason;

  bool get shouldReload => reloadPlan != null;
  bool get shouldStopRuntime => stopReason != null;
  bool get isProfileSwitch => kind == SubscriptionProfileFlowKind.selectProfile;

  /// A failed stop leaves the old tunnel active, even when its profile was
  /// deleted from storage. Do not present another profile as the live one.
  bool canApplyReloadAfterStop(bool stopped) => !shouldStopRuntime || stopped;
}

/// Remembers a deleted active profile when its VPN tunnel could not stop.
/// The catalog is reconciled only after the old tunnel has actually stopped.
class DeferredProfileDeletionReload {
  String? _pendingProfileId;

  void defer(String profileId) {
    final normalized = profileId.trim();
    if (normalized.isNotEmpty) _pendingProfileId = normalized;
  }

  String? takeAfterStop({required bool stopped}) {
    if (!stopped) return null;
    final pending = _pendingProfileId;
    _pendingProfileId = null;
    return pending;
  }
}

/// Decides how to apply the result returned by the subscriptions sheet.
///
/// This class owns no Flutter state and performs no I/O. The caller keeps
/// ownership of stopping the runtime and applying the reload plan.
class SubscriptionProfileFlowController {
  const SubscriptionProfileFlowController();

  SubscriptionProfileFlowDecision decide({
    required SubscriptionProfilePageSession session,
    required String? selectedProfileId,
    required String afterMetadataFingerprint,
    required String? afterActiveRuntimeFingerprint,
    required bool activeProfileRemoved,
    required bool runtimeActiveOrRequested,
    required bool connected,
  }) {
    final selectedId = selectedProfileId?.trim() ?? '';
    if (selectedId.isEmpty) {
      final subscriptionsChanged =
          session.metadataFingerprint != afterMetadataFingerprint;
      final activeRuntimeChanged =
          session.activeRuntimeFingerprint != afterActiveRuntimeFingerprint;
      if (!subscriptionsChanged && !activeRuntimeChanged) {
        return const SubscriptionProfileFlowDecision.unchanged();
      }
      if (activeProfileRemoved) {
        // The subscription the running tunnel was built from is gone. Bring
        // the connection down rather than carrying it over onto whichever
        // profile the catalog happens to fall back to: silently switching
        // servers the user never picked is worse than a disconnected app.
        return SubscriptionProfileFlowDecision._(
          kind: SubscriptionProfileFlowKind.reloadCurrentProfile,
          stopReason: runtimeActiveOrRequested
              ? 'active_profile_deleted'
              : null,
          reloadPlan: SubscriptionReloadPlan(
            preferredSubscriptionId: session.activeProfileId,
            preferredProxyTag: session.selectedProxyTag,
            applyRuntime: false,
            resetRuntimeState: true,
            restartRuntimeOnApply: false,
            urlTestAfterApply: false,
          ),
        );
      }
      return SubscriptionProfileFlowDecision._(
        kind: SubscriptionProfileFlowKind.reloadCurrentProfile,
        reloadPlan: SubscriptionReloadPlan(
          preferredSubscriptionId: session.activeProfileId,
          preferredProxyTag: session.selectedProxyTag,
          applyRuntime: activeRuntimeChanged,
          resetRuntimeState: activeRuntimeChanged,
          restartRuntimeOnApply: connected && activeRuntimeChanged,
          urlTestAfterApply: connected && activeRuntimeChanged,
        ),
      );
    }

    final switchingProfile = selectedId != session.activeProfileId;
    return SubscriptionProfileFlowDecision._(
      kind: SubscriptionProfileFlowKind.selectProfile,
      stopReason: switchingProfile && runtimeActiveOrRequested
          ? 'profile_switch'
          : null,
      reloadPlan: SubscriptionReloadPlan(
        preferredSubscriptionId: selectedId,
        preferredProxyTag: '',
        applyRuntime: false,
        resetRuntimeState: false,
        restartRuntimeOnApply: false,
        urlTestAfterApply: false,
      ),
    );
  }
}
