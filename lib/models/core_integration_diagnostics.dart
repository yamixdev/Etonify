class CoreIntegrationDiagnosticsSnapshot {
  const CoreIntegrationDiagnosticsSnapshot({
    required this.applyStatus,
    required this.applyReason,
    required this.applyError,
    required this.configGeneration,
    required this.configRuntimeGeneration,
    required this.configSchemaVersion,
    required this.settingsApplyPending,
    required this.lastApplyAtMillis,
  });

  const CoreIntegrationDiagnosticsSnapshot.empty()
    : applyStatus = 'not_applied_yet',
      applyReason = 'not_applied_yet',
      applyError = '',
      configGeneration = 0,
      configRuntimeGeneration = 0,
      configSchemaVersion = 0,
      settingsApplyPending = false,
      lastApplyAtMillis = 0;

  final String applyStatus;
  final String applyReason;
  final String applyError;
  final int configGeneration;
  final int configRuntimeGeneration;
  final int configSchemaVersion;
  final bool settingsApplyPending;
  final int lastApplyAtMillis;
}
