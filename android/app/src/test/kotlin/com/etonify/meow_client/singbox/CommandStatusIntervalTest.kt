package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Test

class CommandStatusIntervalTest {
    @Test
    fun `status interval is expressed in Go duration nanoseconds`() {
        assertEquals(1_000_000_000L, commandStatusIntervalNanos("standard"))
        assertEquals(2_000_000_000L, commandStatusIntervalNanos("economy"))
    }
}
