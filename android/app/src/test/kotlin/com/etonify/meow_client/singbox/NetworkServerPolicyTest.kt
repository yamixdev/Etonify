package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NetworkServerPolicyTest {
    private val wifi = ServerNetworkSnapshot(ServerNetwork.WIFI, 4)
    private val mobile = ServerNetworkSnapshot(ServerNetwork.MOBILE, 5)
    private val configured = mapOf(ServerNetwork.WIFI to "wifi", ServerNetwork.MOBILE to "mobile")
    private val policy = NetworkServerPolicy(
        enabled = true,
        remember = true,
        configured = configured,
        remembered = mapOf(ServerNetwork.WIFI to "last-wifi", ServerNetwork.MOBILE to "last-mobile"),
    )

    @Test fun `each network uses its own available remembered server`() {
        val tags = configured.values.toSet() + setOf("last-wifi", "last-mobile")
        assertEquals("last-wifi", policy.target(wifi.network, tags))
        assertEquals("last-mobile", policy.target(mobile.network, tags))
        assertEquals("wifi", policy.copy(remember = false).target(wifi.network, tags))
        assertEquals("mobile", policy.target(mobile.network, tags - "last-mobile"))
        assertNull(policy.target(mobile.network, tags - setOf("last-mobile", "mobile")))
        assertNull(policy.target(null, tags))
        assertNull(policy.copy(enabled = false).target(wifi.network, tags))
    }

    @Test fun `manual selection only belongs to the network where it started`() {
        assertTrue(policy.remembers(wifi, wifi))
        assertFalse(policy.remembers(wifi, mobile))
        assertFalse(policy.remembers(wifi, wifi.copy(generation = 6)))
        assertFalse(policy.remembers(wifi, null))
        assertFalse(policy.copy(remember = false).remembers(wifi, wifi))
        assertFalse(policy.copy(enabled = false).remembers(wifi, wifi))
    }

    @Test fun `cold start selects for current wifi instead of the previous mobile default`() {
        val tags = setOf("wifi", "mobile", "last-wifi", "last-mobile")
        assertEquals("last-wifi", policy.startTarget(ServerNetwork.WIFI, tags, ServerNetwork.MOBILE, "mobile"))
        assertEquals("last-mobile", policy.startTarget(ServerNetwork.MOBILE, tags, ServerNetwork.WIFI, "wifi"))
        assertEquals("last-mobile", policy.startTarget(ServerNetwork.MOBILE, tags))
        assertEquals("last-wifi", policy.startTarget(ServerNetwork.WIFI, tags))
    }

    @Test fun `reload preserves the explicit manual selection for the same transport`() {
        val tags = setOf("wifi", "manual")
        assertEquals("manual", policy.startTarget(ServerNetwork.WIFI, tags, ServerNetwork.WIFI, "manual"))
        assertEquals("wifi", policy.startTarget(ServerNetwork.WIFI, tags, ServerNetwork.MOBILE, "manual"))
        assertNull(policy.copy(enabled = false).startTarget(ServerNetwork.WIFI, tags, ServerNetwork.WIFI, "manual"))
    }
}
