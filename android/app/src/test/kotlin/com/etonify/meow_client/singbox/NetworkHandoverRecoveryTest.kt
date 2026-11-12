package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NetworkHandoverRecoveryTest {
    private val wifi = NetworkRecoveryContext(1L, 4L, 0L, 2L, 10L, 0L)

    @Test fun `handover owns one probe and at most one inconclusive retry`() {
        val recovery = NetworkHandoverRecovery(60_000L)
        assertFalse(recovery.takeProbe(wifi, wifi, retry = true))
        assertTrue(recovery.takeProbe(wifi, wifi, retry = false))
        assertFalse(recovery.takeProbe(wifi, wifi, retry = false))
        assertTrue(recovery.takeProbe(wifi, wifi, retry = true))
        assertFalse(recovery.takeProbe(wifi, wifi, retry = true))
        assertFalse(recovery.takeProbe(wifi, wifi, retry = false))
    }

    @Test fun `stale handover cannot retry and the replacement has its own probe budget`() {
        val recovery = NetworkHandoverRecovery(60_000L)
        assertTrue(recovery.takeProbe(wifi, wifi, retry = false))
        for (newContext in listOf(
            wifi.copy(runtime = 2L), wifi.copy(network = 5L), wifi.copy(externalStop = 1L),
            wifi.copy(selection = 3L), wifi.copy(startToken = 11L), wifi.copy(cancellation = 1L),
        )) {
            assertFalse(recovery.takeProbe(wifi, newContext, retry = true))
        }
        val mobile = wifi.copy(network = 5L)
        assertTrue(recovery.takeProbe(mobile, mobile, retry = false))
        assertTrue(recovery.takeProbe(mobile, mobile, retry = true))
    }

    @Test fun `physical generation resets transports once even if interface remains unchanged`() {
        val recovery = NetworkHandoverRecovery(60_000L)
        var resets = 0
        assertTrue(recovery.resetIfChanged(wifi, wifi) { resets++ })
        repeat(5) { assertFalse(recovery.resetIfChanged(wifi, wifi) { resets++ }) }
        val reconnected = wifi.copy(network = 5L)
        assertTrue(recovery.resetIfChanged(reconnected, reconnected) { resets++ })
        assertEquals(2, resets)
    }

    @Test fun `failed reset is retryable without pretending transports were repaired`() {
        val recovery = NetworkHandoverRecovery(60_000L)
        runCatching { recovery.resetIfChanged(wifi, wifi) { error("reset failed") } }
        var resets = 0
        assertTrue(recovery.resetIfChanged(wifi, wifi) { resets++ })
        assertEquals(1, resets)
    }

    @Test fun `stale runtime network selection stop or pending start cannot reset or restart`() {
        val newerContexts = listOf(
            wifi.copy(runtime = 2L), wifi.copy(network = 5L), wifi.copy(externalStop = 1L),
            wifi.copy(selection = 3L), wifi.copy(startToken = 11L), wifi.copy(cancellation = 1L),
        )
        for (current in newerContexts) {
            val recovery = NetworkHandoverRecovery(60_000L)
            var resets = 0
            assertFalse(recovery.resetIfChanged(wifi, current) { resets++ })
            assertFalse(recovery.takeRestart(wifi, current, 1_000L))
            assertEquals(0, resets)
        }
    }

    @Test fun `failed handover permits only one restart even after cooldown`() {
        val recovery = NetworkHandoverRecovery(60_000L)
        assertTrue(recovery.takeRestart(wifi, wifi, 1_000L))
        assertFalse(recovery.takeRestart(wifi, wifi, 1_001L))
        assertFalse(recovery.takeRestart(wifi, wifi, 90_000L))
    }

    @Test fun `restart cooldown survives new runtime and interface generations`() {
        val recovery = NetworkHandoverRecovery(60_000L)
        assertTrue(recovery.takeRestart(wifi, wifi, 1_000L))
        val restarted = wifi.copy(runtime = 2L, network = 5L, startToken = 11L)
        assertFalse(recovery.takeRestart(restarted, restarted, 2_000L))
        assertTrue(recovery.takeRestart(restarted, restarted, 61_000L))
    }

    @Test fun `stopped or unidentified runtime never attempts recovery`() {
        val recovery = NetworkHandoverRecovery(60_000L)
        for (invalid in listOf(wifi.copy(runtime = 0L), wifi.copy(network = 0L))) {
            assertFalse(recovery.resetIfChanged(invalid, invalid) { error("must not reset") })
            assertFalse(recovery.takeRestart(invalid, invalid, 1_000L))
        }
    }
}
