package com.etonify.meow_client.singbox

object RuntimeServiceModeResolver {
    const val VPN = "vpn"
    const val PROXY = "proxy"
    const val PROBE = "probe"

    fun requestedMode(explicitMode: String?, inboundTypes: Iterable<String>): String? {
        return if (explicitMode?.trim()?.lowercase() == PROBE &&
            configuredMode(inboundTypes) == null
        ) PROBE else configuredMode(inboundTypes)
    }

    fun configuredMode(inboundTypes: Iterable<String>): String? {
        val normalized = inboundTypes.map { it.trim().lowercase() }
        return when {
            normalized.any { it == "tun" } -> VPN
            normalized.any { it == "mixed" || it == "http" || it == "socks" } -> PROXY
            else -> null
        }
    }

    fun activeMode(
        runningMode: String?,
        vpnRecorded: Boolean,
        proxyRecorded: Boolean,
        probeRecorded: Boolean = false,
    ): String? {
        return when (runningMode?.trim()?.lowercase()) {
            VPN -> VPN
            PROXY -> PROXY
            PROBE -> PROBE
            else -> when {
                vpnRecorded -> VPN
                proxyRecorded -> PROXY
                probeRecorded -> PROBE
                else -> null
            }
        }
    }
}
