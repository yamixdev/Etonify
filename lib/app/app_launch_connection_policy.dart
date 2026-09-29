bool shouldAutoConnectOnLaunch({
  required bool enabled,
  required bool onboardingCompleted,
  required bool legalAccepted,
  required bool hasActiveProfile,
  required bool vpnInboundEnabled,
  required bool runtimeActive,
}) =>
    enabled &&
    onboardingCompleted &&
    legalAccepted &&
    hasActiveProfile &&
    vpnInboundEnabled &&
    !runtimeActive;
