package com.etonify.meow_client.singbox

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class NetworkServerRuntimeConfigTest {
    @Test
    fun `startup primes the selector and binds only independent proxy sockets`() {
        val config = """
            {"outbounds":[
              {"type":"selector","tag":"select","default":"lte","outbounds":["lte","wifi"]},
              {"type":"vless","tag":"wifi","server":"wifi.example"},
              {"type":"vless","tag":"lte","server":"lte.example","detour":"wifi"},
              {"type":"direct","tag":"direct"}
            ],"experimental":{"cache_file":{"store_dns":true}}}
        """.trimIndent()
        val prepared = JSONObject(prepareNetworkServerRuntime(config, "wifi", "/tmp/fresh", "@binder"))
        val outbounds = prepared.getJSONArray("outbounds")
        assertEquals("wifi", outbounds.getJSONObject(0).getString("default"))
        assertEquals("@binder", outbounds.getJSONObject(1).getString("protect_path"))
        assertFalse(outbounds.getJSONObject(2).has("protect_path"))
        assertFalse(outbounds.getJSONObject(3).has("protect_path"))
        val cache = prepared.getJSONObject("experimental").getJSONObject("cache_file")
        assertEquals("/tmp/fresh", cache.getString("path"))
        assertEquals(true, cache.getBoolean("store_dns"))
    }
}
