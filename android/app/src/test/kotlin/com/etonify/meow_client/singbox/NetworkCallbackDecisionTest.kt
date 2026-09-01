package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NetworkCallbackDecisionTest {
    @Test
    fun repeatedCallbackKeepsNetworkAndUsesDeduplicatedCheck() {
        val decision = decideUsableNetworkCallback(
            currentNetwork = "wifi",
            preferredNetwork = "wifi",
            eventNetwork = "wifi",
        )

        assertEquals("wifi", decision.nextNetwork)
        assertTrue(decision.shouldCheckInterface)
    }

    @Test
    fun realHandoverSwitchesToPreferredNetwork() {
        val decision = decideUsableNetworkCallback(
            currentNetwork = "wifi",
            preferredNetwork = "cellular",
            eventNetwork = "cellular",
        )

        assertEquals("cellular", decision.nextNetwork)
        assertTrue(decision.shouldCheckInterface)
    }

    @Test
    fun callbackForUnselectedUsableNetworkDoesNotRecheckCurrentInterface() {
        val decision = decideUsableNetworkCallback(
            currentNetwork = "wifi",
            preferredNetwork = "wifi",
            eventNetwork = "ethernet",
        )

        assertEquals("wifi", decision.nextNetwork)
        assertFalse(decision.shouldCheckInterface)
    }

    @Test
    fun losingCurrentNetworkSelectsReplacement() {
        val decision = decideLostNetworkCallback(
            currentNetwork = "wifi",
            replacementNetwork = "cellular",
            eventNetwork = "wifi",
        )

        assertEquals("cellular", decision.nextNetwork)
        assertTrue(decision.shouldCheckInterface)
    }

    @Test
    fun losingUnselectedNetworkDoesNotNotifyListener() {
        val decision = decideLostNetworkCallback(
            currentNetwork = "wifi",
            replacementNetwork = "cellular",
            eventNetwork = "ethernet",
        )

        assertEquals("wifi", decision.nextNetwork)
        assertFalse(decision.shouldCheckInterface)
    }

    @Test
    fun losingCurrentNetworkWithoutReplacementClearsSelection() {
        val decision = decideLostNetworkCallback(
            currentNetwork = "wifi",
            replacementNetwork = null,
            eventNetwork = "wifi",
        )

        assertNull(decision.nextNetwork)
        assertTrue(decision.shouldCheckInterface)
    }

    @Test
    fun missingPreferredNetworkDoesNotClearUnrelatedSelection() {
        val decision = decideUsableNetworkCallback(
            currentNetwork = "wifi",
            preferredNetwork = null,
            eventNetwork = "cellular",
        )

        assertEquals("wifi", decision.nextNetwork)
        assertFalse(decision.shouldCheckInterface)
    }

    @Test
    fun fiftyIdenticalCallbacksDispatchOnlyFirstInterfaceUpdate() {
        val gate = InterfaceUpdateGate()

        val dispatchCount = (0 until 50).count {
            gate.evaluate("wifi:wlan0:12", force = false).shouldDispatch
        }

        assertEquals(1, dispatchCount)
    }

    @Test
    fun explicitRecoveryCanReassertUnchangedInterface() {
        val gate = InterfaceUpdateGate()
        gate.evaluate("wifi:wlan0:12", force = false)

        val recovery = gate.evaluate("wifi:wlan0:12", force = true)

        assertTrue(recovery.duplicate)
        assertTrue(recovery.shouldDispatch)
    }
}
