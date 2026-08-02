package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationTrafficRateTest {
    @Test
    fun `uses the newest core sample without smoothing it down`() {
        assertEquals(
            1_048_576L,
            currentTrafficRate(
                incomingBytesPerSecond = 1_048_576L,
                available = true,
            ),
        )
    }

    @Test
    fun `does not show a stale rate when traffic is unavailable`() {
        assertEquals(
            0L,
            currentTrafficRate(
                incomingBytesPerSecond = 24_000L,
                available = false,
            ),
        )
    }

    @Test
    fun `clamps malformed negative samples to zero`() {
        assertEquals(
            0L,
            currentTrafficRate(
                incomingBytesPerSecond = -1L,
                available = true,
            ),
        )
    }
}
