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
}
