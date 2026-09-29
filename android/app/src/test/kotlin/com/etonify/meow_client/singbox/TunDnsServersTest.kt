package com.etonify.meow_client.singbox

import org.junit.Assert.assertThrows
import org.junit.Test

class TunDnsServersTest {
    @Test
    fun `VPN TUN rejects an empty DNS server list`() {
        assertThrows(IllegalStateException::class.java) {
            requireTunDnsServers(emptyList<String>())
        }
    }

    @Test
    fun `VPN TUN accepts a DNS server supplied by the core`() {
        requireTunDnsServers(listOf("172.19.0.2"))
    }
}
