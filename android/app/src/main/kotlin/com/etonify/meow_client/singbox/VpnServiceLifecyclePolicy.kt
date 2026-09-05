package com.etonify.meow_client.singbox

internal enum class VpnTaskRemovalAction {
    STOP_LINGERING_SERVICE,
    RECOVER_RUNTIME_AND_ARM_RESTART,
}

/**
 * Pure lifecycle decisions kept outside [MeowVpnService] so task-removal and
 * process-recovery behavior can be covered by local JVM tests.
 */
internal object VpnServiceLifecyclePolicy {
    fun taskRemovalAction(
        runtimeRunning: Boolean,
        activeRuntimeOwner: Boolean,
    ): VpnTaskRemovalAction {
        return if (runtimeRunning && activeRuntimeOwner) {
            VpnTaskRemovalAction.RECOVER_RUNTIME_AND_ARM_RESTART
        } else {
            VpnTaskRemovalAction.STOP_LINGERING_SERVICE
        }
    }

    fun shouldCancelScheduledRestartOnDestroy(runtimeRunning: Boolean): Boolean {
        return !runtimeRunning
    }

    /**
     * Governs whether the active VPN service should execute an emergency forced
     * teardown (stopSelf + SingboxController reset) after a normal stop sequence
     * has timed out, without terminating the host application process.
     */
    fun shouldForceStopServiceAfterTimeout(
        runtimeRunning: Boolean,
        activeRuntimeOwner: Boolean,
        freshRuntimeIntent: Boolean,
    ): Boolean {
        return runtimeRunning && activeRuntimeOwner && !freshRuntimeIntent
    }

    @Deprecated(
        "Renamed to shouldForceStopServiceAfterTimeout to reflect graceful teardown without process exit",
        ReplaceWith("shouldForceStopServiceAfterTimeout(runtimeRunning, activeRuntimeOwner, freshRuntimeIntent)"),
    )
    fun shouldTerminateProcessAfterStopTimeout(
        runtimeRunning: Boolean,
        activeRuntimeOwner: Boolean,
        freshRuntimeIntent: Boolean,
    ): Boolean {
        return shouldForceStopServiceAfterTimeout(
            runtimeRunning = runtimeRunning,
            activeRuntimeOwner = activeRuntimeOwner,
            freshRuntimeIntent = freshRuntimeIntent,
        )
    }
}
