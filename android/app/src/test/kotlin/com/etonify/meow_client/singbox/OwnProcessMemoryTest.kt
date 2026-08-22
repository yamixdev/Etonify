package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Test

class OwnProcessMemoryTest {
    @Test
    fun `proc status parser reads rss and swap in kilobytes`() {
        val parsed = OwnProcessMemory.parseProcStatus(
            listOf(
                "Name:\tcom.etonify.meow_client",
                "VmRSS:\t  443125 kB",
                "VmSwap:\t     192 kB",
                "Threads:\t42",
            ),
        )

        assertEquals(443_125L, parsed["VmRSS"])
        assertEquals(192L, parsed["VmSwap"])
        assertEquals(2, parsed.size)
    }
}
