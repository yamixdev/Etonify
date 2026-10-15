bool shouldAutoConnectOnLaunch({
  required bool enabled,
  required bool onboardingCompleted,
  required bool legalAccepted,
  required bool hasActiveProfile,
  required bool vpnInboundEnabled,
  required bool runtimeActive,
  bool isWindows = false,
}) =>
    enabled &&
    onboardingCompleted &&
    legalAccepted &&
    hasActiveProfile &&
    (isWindows || vpnInboundEnabled) &&
    !runtimeActive;
