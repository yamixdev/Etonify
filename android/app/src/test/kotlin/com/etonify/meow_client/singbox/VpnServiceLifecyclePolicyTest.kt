package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnServiceLifecyclePolicyTest {
    @Test
    fun `active VPN runtime survives task removal`() {
        assertEquals(
            VpnTaskRemovalAction.RECOVER_RUNTIME_AND_ARM_RESTART,
            VpnServiceLifecyclePolicy.taskRemovalAction(
                runtimeRunning = true,
                activeRuntimeOwner = true,
            ),
        )
    }

    @Test
    fun `stale service stops when native runtime is not running`() {
        assertEquals(
            VpnTaskRemovalAction.STOP_LINGERING_SERVICE,
            VpnServiceLifecyclePolicy.taskRemovalAction(
                runtimeRunning = false,
                activeRuntimeOwner = true,
            ),
        )
    }

    @Test
    fun `service without VPN runtime ownership stops on task removal`() {
        assertEquals(
            VpnTaskRemovalAction.STOP_LINGERING_SERVICE,
            VpnServiceLifecyclePolicy.taskRemovalAction(
                runtimeRunning = true,
                activeRuntimeOwner = false,
            ),
        )
    }

    @Test
    fun `destroy cancels restart only after runtime stopped`() {
        assertTrue(
            VpnServiceLifecyclePolicy.shouldCancelScheduledRestartOnDestroy(
                runtimeRunning = false,
            ),
        )
        assertFalse(
            VpnServiceLifecyclePolicy.shouldCancelScheduledRestartOnDestroy(
                runtimeRunning = true,
            ),
        )
    }

    @Test
    fun `hung native stop triggers force stop only for the stale owning service`() {
        assertTrue(
            VpnServiceLifecyclePolicy.shouldForceStopServiceAfterTimeout(
                runtimeRunning = true,
                activeRuntimeOwner = true,
                freshRuntimeIntent = false,
            ),
        )
        assertFalse(
            VpnServiceLifecyclePolicy.shouldForceStopServiceAfterTimeout(
                runtimeRunning = false,
                activeRuntimeOwner = true,
                freshRuntimeIntent = false,
            ),
        )
        assertFalse(
            VpnServiceLifecyclePolicy.shouldForceStopServiceAfterTimeout(
                runtimeRunning = true,
                activeRuntimeOwner = false,
                freshRuntimeIntent = false,
            ),
        )
        assertFalse(
            VpnServiceLifecyclePolicy.shouldForceStopServiceAfterTimeout(
                runtimeRunning = true,
                activeRuntimeOwner = true,
                freshRuntimeIntent = true,
            ),
        )
    }

    @Suppress("DEPRECATION")
    @Test
    fun `hung native stop terminates only the stale owning process`() {
        assertTrue(
            VpnServiceLifecyclePolicy.shouldTerminateProcessAfterStopTimeout(
                runtimeRunning = true,
                activeRuntimeOwner = true,
                freshRuntimeIntent = false,
            ),
        )
        assertFalse(
            VpnServiceLifecyclePolicy.shouldTerminateProcessAfterStopTimeout(
                runtimeRunning = false,
                activeRuntimeOwner = true,
                freshRuntimeIntent = false,
            ),
        )
        assertFalse(
            VpnServiceLifecyclePolicy.shouldTerminateProcessAfterStopTimeout(
                runtimeRunning = true,
                activeRuntimeOwner = false,
                freshRuntimeIntent = false,
            ),
        )
        assertFalse(
            VpnServiceLifecyclePolicy.shouldTerminateProcessAfterStopTimeout(
                runtimeRunning = true,
                activeRuntimeOwner = true,
                freshRuntimeIntent = true,
            ),
        )
    }
}
