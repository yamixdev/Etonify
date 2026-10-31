package com.etonify.meow_client.root

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class RootConfigAdapterTest {
    @Test fun deviceDnsBecomesTheActualPhysicalNetworkResolver() {
        val result = JSONObject(RootConfigAdapter.adapt(
            """{"inbounds":[{"type":"tun"}],"dns":{"servers":[{"tag":"dns-local","type":"local"}]}}""",
            listOf("192.168.1.1"),
        ) { error("no rules") })
        val server = result.getJSONObject("dns").getJSONArray("servers").getJSONObject(0)
        assertEquals("udp", server.getString("type"))
        assertEquals("192.168.1.1", server.getString("server"))
        assertEquals("dns-local", server.getString("tag"))
        assertEquals("direct", server.getString("detour"))
    }

    @Test fun missingPhysicalDnsDoesNotInventAnotherProvider() {
        val failure = runCatching {
            RootConfigAdapter.adapt("""{"dns":{"servers":[{"type":"local"}]}}""", emptyList()) { it }
        }.exceptionOrNull()
        assertEquals("root_dns_unavailable", failure?.message)
    }

    @Test fun localRulesAreStagedAndRemoteRulesStayRemote() {
        val result = JSONObject(RootConfigAdapter.adapt(
            """{"route":{"rule_set":[{"type":"local","path":"/old/list.srs"},{"type":"remote","url":"https://example.org/list.srs"}]}}""",
            emptyList(),
        ) { "/private/staged.srs" })
        val rules = result.getJSONObject("route").getJSONArray("rule_set")
        assertEquals("/private/staged.srs", rules.getJSONObject(0).getString("path"))
        assertEquals("https://example.org/list.srs", rules.getJSONObject(1).getString("url"))
    }

    @Test fun protectedDnsSettingsAreNotReplacedByDeviceDns() {
        val result = JSONObject(RootConfigAdapter.adapt(
            """{"dns":{"servers":[{"tag":"secure","type":"https","server":"1.1.1.1","detour":"select"}]}}""",
            listOf("192.168.1.1"),
        ) { it })
        val server = result.getJSONObject("dns").getJSONArray("servers").getJSONObject(0)
        assertEquals("https", server.getString("type"))
        assertEquals("1.1.1.1", server.getString("server"))
        assertEquals("select", server.getString("detour"))
    }
}
