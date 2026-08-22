package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NotificationTrafficRateTest {
    @Test
    fun `calculates one second notification interval from totals`() {
        val window = NotificationTrafficRateWindow()

        assertRate(window.update(10L, 20L, true, 1_000L, 1_000L), 0L, 0L)
        assertNull(window.update(522L, 1_044L, true, 1_500L, 1_000L))
        assertRate(window.update(1_034L, 2_068L, true, 2_000L, 1_000L), 1_024L, 2_048L)
    }

    @Test
    fun `normalizes economy samples reported every two seconds`() {
        val window = NotificationTrafficRateWindow()

        assertRate(window.update(0L, 0L, true, 0L, 2_000L), 0L, 0L)
        assertRate(window.update(2_048L, 4_096L, true, 2_000L, 2_000L), 1_024L, 2_048L)
    }

    @Test
    fun `averages totals across a ten second display interval`() {
        val window = NotificationTrafficRateWindow()

        assertRate(window.update(100L, 200L, true, 1_000L, 10_000L), 0L, 0L)
        assertNull(window.update(5_100L, 10_200L, true, 6_000L, 10_000L))
        assertRate(window.update(10_100L, 20_200L, true, 11_000L, 10_000L), 1_000L, 2_000L)
    }

    @Test
    fun `publishes zero after traffic becomes idle`() {
        val window = NotificationTrafficRateWindow()

        assertRate(window.update(0L, 0L, true, 0L, 1_000L), 0L, 0L)
        assertRate(window.update(2_000L, 4_000L, true, 1_000L, 1_000L), 2_000L, 4_000L)
        assertRate(window.update(2_000L, 4_000L, true, 2_000L, 1_000L), 0L, 0L)
    }

    @Test
    fun `counter reset starts a new runtime window without a spike`() {
        val window = NotificationTrafficRateWindow()

        assertRate(window.update(10_000L, 20_000L, true, 0L, 1_000L), 0L, 0L)
        assertRate(window.update(11_000L, 22_000L, true, 1_000L, 1_000L), 1_000L, 2_000L)
        assertRate(window.update(50L, 100L, true, 2_000L, 1_000L), 0L, 0L)
        assertRate(window.update(1_050L, 2_100L, true, 3_000L, 1_000L), 1_000L, 2_000L)
    }

    @Test
    fun `unavailable traffic clears a stale rate and restarts the baseline`() {
        val window = NotificationTrafficRateWindow()

        assertRate(window.update(0L, 0L, true, 0L, 1_000L), 0L, 0L)
        assertRate(window.update(1_000L, 2_000L, true, 1_000L, 1_000L), 1_000L, 2_000L)
        assertRate(window.update(1_000L, 2_000L, false, 1_500L, 1_000L), 0L, 0L)
        assertNull(window.update(1_000L, 2_000L, false, 2_500L, 1_000L))
        assertRate(window.update(1_500L, 3_000L, true, 3_000L, 1_000L), 0L, 0L)
    }

    @Test
    fun `restart resets the baseline explicitly`() {
        val window = NotificationTrafficRateWindow()

        assertRate(window.update(0L, 0L, true, 0L, 1_000L), 0L, 0L)
        assertRate(window.update(1_000L, 2_000L, true, 1_000L, 1_000L), 1_000L, 2_000L)
        window.reset()
        assertRate(window.update(50_000L, 80_000L, true, 2_000L, 1_000L), 0L, 0L)
    }

    private fun assertRate(
        actual: NotificationTrafficRate?,
        expectedUplink: Long,
        expectedDownlink: Long,
    ) {
        assertEquals(expectedUplink, actual?.uplinkBytesPerSecond)
        assertEquals(expectedDownlink, actual?.downlinkBytesPerSecond)
    }
}
