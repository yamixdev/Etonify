package com.etonify.meow_client.root

import org.json.JSONObject

/** Resolves Android-only inputs before the privileged side enforces its own policy. */
internal object RootConfigAdapter {
    fun adapt(config: String, deviceDnsAddresses: List<String>, stageRuleFile: (String) -> String): String {
        require(config.toByteArray(Charsets.UTF_8).size <= 16 * 1024 * 1024) { "root_config_too_large" }
        val result = JSONObject(config)
        val dnsServers = result.optJSONObject("dns")?.optJSONArray("servers")
        if (dnsServers != null) for (index in 0 until dnsServers.length()) {
            val server = dnsServers.optJSONObject(index) ?: continue
            if (server.optString("type") != "local") continue
            val address = deviceDnsAddresses.firstOrNull { it.isNotBlank() }
                ?: error("root_dns_unavailable")
            server.put("type", "udp")
            server.put("server", address)
            server.put("server_port", 53)
            // A device resolver is attached to the physical network, not to a
            // randomly selected proxy. Preserve explicit proxy DNS separately.
            server.put("detour", "direct")
        }
        val ruleSets = result.optJSONObject("route")?.optJSONArray("rule_set")
        if (ruleSets != null) for (index in 0 until ruleSets.length()) {
            val rule = ruleSets.optJSONObject(index) ?: continue
            if (rule.optString("type") != "local" || !rule.has("path")) continue
            rule.put("path", stageRuleFile(rule.getString("path")))
        }
        return result.toString()
    }
}
