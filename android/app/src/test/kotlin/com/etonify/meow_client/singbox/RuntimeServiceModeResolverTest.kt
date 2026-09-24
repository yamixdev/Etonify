package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RuntimeServiceModeResolverTest {
    @Test
    fun `tun takes priority when local proxy is also enabled`() {
        assertEquals(
            RuntimeServiceModeResolver.VPN,
            RuntimeServiceModeResolver.configuredMode(listOf("mixed", "tun")),
        )
    }

    @Test
    fun `proxy-only config selects proxy service`() {
        assertEquals(
            RuntimeServiceModeResolver.PROXY,
            RuntimeServiceModeResolver.configuredMode(listOf("mixed")),
        )
    }

    @Test
    fun `config without supported inbound has no service mode`() {
        assertNull(RuntimeServiceModeResolver.configuredMode(emptyList()))
    }

    @Test
    fun `running mode wins over stale recorded state`() {
        assertEquals(
            RuntimeServiceModeResolver.PROXY,
            RuntimeServiceModeResolver.activeMode("proxy", vpnRecorded = true, proxyRecorded = false),
        )
    }

    @Test
    fun `explicit probe mode cannot be mistaken for VPN`() {
        assertEquals(
            RuntimeServiceModeResolver.PROBE,
            RuntimeServiceModeResolver.requestedMode("probe", emptyList()),
        )
        assertEquals(
            RuntimeServiceModeResolver.PROBE,
            RuntimeServiceModeResolver.activeMode(
                "probe",
                vpnRecorded = false,
                proxyRecorded = false,
                probeRecorded = true,
            ),
        )
        assertNull(RuntimeServiceModeResolver.configuredMode(emptyList()))
    }
}
