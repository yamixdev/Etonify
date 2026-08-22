package com.etonify.meow_client.singbox

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RuntimeRecoveryGateTest {
    @Test
    fun `screen wake burst is coalesced`() {
        val gate = RuntimeRecoveryGate(minimumIntervalMillis = 1_000L)

        assertTrue(gate.tryAcquire(10_000L))
        assertFalse(gate.tryAcquire(10_250L))
        assertFalse(gate.tryAcquire(10_999L))
        assertTrue(gate.tryAcquire(11_000L))
    }

    @Test
    fun `reset immediately allows service recovery`() {
        val gate = RuntimeRecoveryGate(minimumIntervalMillis = 1_000L)

        assertTrue(gate.tryAcquire(50_000L))
        gate.reset()

        assertTrue(gate.tryAcquire(50_001L))
    }

    @Test
    fun `elapsed realtime reset does not block recovery`() {
        val gate = RuntimeRecoveryGate(minimumIntervalMillis = 1_000L)

        assertTrue(gate.tryAcquire(50_000L))

        assertTrue(gate.tryAcquire(100L))
    }

    @Test
    fun `only latest handover probe remains current`() {
        val gate = NetworkHandoverProbeGate()

        val wifiProbe = gate.replace()
        val mobileProbe = gate.replace()

        assertFalse(gate.isCurrent(wifiProbe))
        assertTrue(gate.isCurrent(mobileProbe))
    }

    @Test
    fun `only the latest handover probe can be consumed once`() {
        val gate = NetworkHandoverProbeGate()

        val wifiProbe = gate.replace()
        val mobileProbe = gate.replace()

        assertFalse(gate.tryConsume(wifiProbe))
        assertTrue(gate.tryConsume(mobileProbe))
        assertFalse(gate.tryConsume(mobileProbe))
    }

    @Test
    fun `stopping runtime invalidates delayed handover probe`() {
        val gate = NetworkHandoverProbeGate()
        val probe = gate.replace()

        gate.invalidate()

        assertFalse(gate.isCurrent(probe))
    }

    @Test
    fun `handover probe is limited to physical network events`() {
        assertTrue(isNetworkHandoverRecoverySource("network_change:wifi_to_mobile"))
        assertTrue(isNetworkHandoverRecoverySource("network_change:wifi_identity"))
        assertFalse(isNetworkHandoverRecoverySource("screen_on"))
        assertFalse(isNetworkHandoverRecoverySource("user_present"))
    }
}
