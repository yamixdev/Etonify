package com.etonify.meow_client.singbox

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class NativeTunStackMigrationTest {
    @Test fun cachedSystemConfigUsesDefaultStackWithoutChangingRoutes() {
        val inbound = JSONObject("""{"type":"tun","stack":"system","mtu":1400,"include_package":["example.app"],"auto_route":true}""")
        assertTrue(migrateNativeTunStack(inbound))
        assertFalse(inbound.has("stack"))
        assertEquals(1400, inbound.getInt("mtu"))
        assertEquals("example.app", inbound.getJSONArray("include_package").getString(0))
        assertTrue(inbound.getBoolean("auto_route"))
        assertFalse(migrateNativeTunStack(inbound))
    }

    @Test fun otherInboundFieldsAreNotInterpretedAsTunStack() {
        val inbound = JSONObject("""{"type":"mixed","stack":"system"}""")
        assertFalse(migrateNativeTunStack(inbound))
        assertEquals("system", inbound.getString("stack"))
    }
}
