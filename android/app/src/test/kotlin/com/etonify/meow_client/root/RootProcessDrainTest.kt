package com.etonify.meow_client.root

import org.junit.Assert.*
import org.junit.Test

class RootProcessDrainTest {
    @Test fun `diagnostic capture stays bounded but drains a large stream to EOF`() {
        val input = java.io.ByteArrayInputStream(ByteArray(1024 * 1024) { 'x'.code.toByte() })
        val captured = RootProcessRunner.captureAndDrain(input)
        assertEquals(65536, captured.length)
        assertEquals(0, input.available())
    }
}
