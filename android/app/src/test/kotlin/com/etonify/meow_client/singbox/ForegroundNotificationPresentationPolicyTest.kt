package com.etonify.meow_client.singbox

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ForegroundNotificationPresentationPolicyTest {
    @Test
    fun `only a new foreground-service startup requests immediate delivery`() {
        assertTrue(foregroundPresentationNeedsImmediateDelivery("Starting"))
        assertTrue(foregroundPresentationNeedsImmediateDelivery("Restarting"))
    }

    @Test
    fun `connected status updates do not request foreground promotion`() {
        assertFalse(foregroundPresentationNeedsImmediateDelivery("Connected"))
        assertFalse(foregroundPresentationNeedsImmediateDelivery("Reloading"))
        assertFalse(foregroundPresentationNeedsImmediateDelivery("Stopping"))
    }

    @Test
    fun `queued refresh cannot resurrect a stopped notification`() {
        assertFalse(
            foregroundRefreshCanDeliver(
                foregroundStarted = false,
                queuedGeneration = 7L,
                currentGeneration = 8L,
            ),
        )
    }

    @Test
    fun `queued refresh from an older runtime cannot update a new notification`() {
        assertFalse(
            foregroundRefreshCanDeliver(
                foregroundStarted = true,
                queuedGeneration = 7L,
                currentGeneration = 9L,
            ),
        )
        assertTrue(
            foregroundRefreshCanDeliver(
                foregroundStarted = true,
                queuedGeneration = 9L,
                currentGeneration = 9L,
            ),
        )
    }
}
