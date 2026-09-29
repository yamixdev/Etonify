package com.etonify.meow_client.singbox

internal fun requireTunDnsServers(addresses: List<String>) {
    check(addresses.isNotEmpty()) {
        "VPN TUN has no DNS server address; refusing to use the physical network DNS"
    }
}
