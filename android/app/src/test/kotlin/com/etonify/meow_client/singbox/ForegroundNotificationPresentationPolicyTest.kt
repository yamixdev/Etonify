package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
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

    @Test
    fun `current speed and total traffic use separate notification lines`() {
        assertEquals(
            "↓ 1 МБ/с  ↑ 2 МБ/с  ·  40 мс\nВсего трафика: ↓ 10 МБ  ↑ 20 МБ",
            notificationDetailedContent(
                trafficDisplayMode = "both",
                speed = "↓ 1 МБ/с  ↑ 2 МБ/с",
                totals = "↓ 10 МБ  ↑ 20 МБ",
                totalLabel = "Всего трафика",
                latency = "40 мс",
            ),
        )
    }

    @Test
    fun `total-only notification uses the supplied localized label`() {
        assertEquals(
            "Total traffic: ↓ 10 MB  ↑ 20 MB  ·  40 ms",
            notificationDetailedContent(
                trafficDisplayMode = "total",
                speed = "↓ 1 MB/s  ↑ 2 MB/s",
                totals = "↓ 10 MB  ↑ 20 MB",
                totalLabel = "Total traffic",
                latency = "40 ms",
            ),
        )
    }
}
