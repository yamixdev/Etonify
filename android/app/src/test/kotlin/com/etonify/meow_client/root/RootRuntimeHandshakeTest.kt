package com.etonify.meow_client.root

import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class RootRuntimeHandshakeTest {
    @Test fun `native safe reason survives failed readiness handshake`() {
        val result = RootRuntimeHandshake.parse("""{"ready":false,"protocol":1,"reason":"dns_bootstrap_unsupported"}""")
        assertFalse(result.ready)
        assertEquals("dns_bootstrap_unsupported", result.failureCode)
    }
    @Test fun `unknown or secret-like reason is not exposed`() {
        val result = RootRuntimeHandshake.parse("""{"ready":false,"protocol":1,"reason":"password_12345"}""")
        assertEquals("runtime_start_failed", result.failureCode)
    }
    @Test fun `root config unsupported is explicit without raw config text`() {
        val result = RootRuntimeHandshake.parse("""{"ready":false,"protocol":1,"reason":"config_unsupported"}""")
        assertEquals("root_config_unsupported", result.failureCode)
    }
    @Test fun `readiness requires exact boolean and protocol`() {
        assertTrue(RootRuntimeHandshake.parse("""{"ready":true,"protocol":1}""").ready)
        assertFalse(RootRuntimeHandshake.parse("""{"ready":"true","protocol":1}""").ready)
        assertFalse(RootRuntimeHandshake.parse("""{"ready":true,"protocol":2}""").ready)
    }
}
