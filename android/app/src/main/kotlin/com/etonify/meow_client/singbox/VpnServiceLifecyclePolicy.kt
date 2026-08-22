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

    fun shouldTerminateProcessAfterStopTimeout(
        runtimeRunning: Boolean,
        activeRuntimeOwner: Boolean,
        freshRuntimeIntent: Boolean,
    ): Boolean {
        return runtimeRunning && activeRuntimeOwner && !freshRuntimeIntent
    }
}
