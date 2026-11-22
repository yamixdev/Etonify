package com.etonify.meow_client.singbox

import com.etonify.meow_client.MeowApplication
import org.json.JSONObject

internal enum class ServerNetwork(val key: String) {
    WIFI("wifi"),
    MOBILE("mobile"),
}

internal data class ServerNetworkSnapshot(val network: ServerNetwork, val generation: Long)

internal data class NetworkServerPolicy(
    val enabled: Boolean = false,
    val remember: Boolean = false,
    val configured: Map<ServerNetwork, String> = emptyMap(),
    val remembered: Map<ServerNetwork, String> = emptyMap(),
) {
    fun target(network: ServerNetwork?, selectableTags: Set<String>): String? {
        if (!enabled || network == null) return null
        return remembered[network]?.takeIf { remember && it in selectableTags }
            ?: configured[network]?.takeIf { it in selectableTags }
    }

    fun startTarget(
        network: ServerNetwork?,
        selectableTags: Set<String>,
        previousNetwork: ServerNetwork? = null,
        manualTag: String? = null,
    ): String? {
        if (!enabled || network == null) return null
        return manualTag?.takeIf { previousNetwork == network && it in selectableTags }
            ?: target(network, selectableTags)
    }

    fun remembers(requested: ServerNetworkSnapshot?, current: ServerNetworkSnapshot?): Boolean =
        enabled && remember && requested != null && requested == current
}

internal object NetworkServerPreferences {
    private val preferences get() = MeowApplication.application.getSharedPreferences("network_servers", 0)

    @Synchronized
    fun read(profileId: String): NetworkServerPolicy = NetworkServerPolicy(
        enabled = preferences.getBoolean("enabled", false),
        remember = preferences.getBoolean("remember", false),
        configured = choices(profileId, "configured"),
        remembered = choices(profileId, "remembered"),
    )

    private fun choices(profileId: String, source: String): Map<ServerNetwork, String> =
        ServerNetwork.entries.mapNotNull { network ->
            preferences.getString(key(profileId, source, network), null)?.let { network to it }
        }.toMap()

    private fun key(profileId: String, source: String, network: ServerNetwork) =
        "$profileId:$source:${network.key}"

    @Synchronized
    fun setEnabled(profileId: String, enabled: Boolean): NetworkServerPolicy {
        preferences.edit().putBoolean("enabled", enabled).apply()
        return read(profileId)
    }

    @Synchronized
    fun setRemember(profileId: String, remember: Boolean): NetworkServerPolicy {
        preferences.edit().putBoolean("remember", remember).apply()
        return read(profileId)
    }

    @Synchronized
    fun setConfigured(profileId: String, network: ServerNetwork, tag: String?): NetworkServerPolicy {
        preferences.edit()
            .putString(key(profileId, "configured", network), tag?.takeIf(String::isNotBlank))
            .remove(key(profileId, "remembered", network))
            .apply()
        return read(profileId)
    }

    @Synchronized
    fun remember(
        profileId: String,
        tag: String,
        requested: ServerNetworkSnapshot?,
        current: ServerNetworkSnapshot?,
    ) {
        if (requested == null || !read(profileId).remembers(requested, current)) return
        preferences.edit().putString(key(profileId, "remembered", requested.network), tag).apply()
    }
}

internal data class NetworkServerProfile(
    val id: String,
    val selectableTags: Set<String>,
    val defaultTag: String,
    val labels: Map<String, String> = emptyMap(),
) {
    fun choice(tag: String) = NetworkServerChoice(id, tag, labels[tag])

    companion object {
        const val CONFIG_KEY = "etonify_profile_id"
        const val LABELS_CONFIG_KEY = "etonify_profile_server_labels"

        fun removeFrom(config: JSONObject): NetworkServerProfile? {
            val labels = config.remove(LABELS_CONFIG_KEY) as? JSONObject
            val id = (config.remove(CONFIG_KEY) as? String)?.takeIf(String::isNotBlank) ?: return null
            val outbounds = config.optJSONArray("outbounds") ?: return null
            for (index in 0 until outbounds.length()) {
                val outbound = outbounds.optJSONObject(index) ?: continue
                if (outbound.optString("type") != "selector" || outbound.optString("tag") != "select") continue
                val members = outbound.optJSONArray("outbounds") ?: return null
                val tags = buildSet {
                    for (member in 0 until members.length()) {
                        val tag = members.optString(member)
                        if (tag.isNotBlank() && tag != "direct") add(tag)
                    }
                }
                val names = tags.mapNotNull { tag ->
                    val label = labels?.optString(tag)?.trim().orEmpty()
                    label.takeIf(String::isNotEmpty)?.let { tag to it }
                }.toMap()
                return NetworkServerProfile(id, tags, outbound.optString("default"), names)
            }
            return null
        }

        fun coreConfig(config: String): String {
            if (!config.contains("\"$CONFIG_KEY\"") && !config.contains("\"$LABELS_CONFIG_KEY\"")) return config
            val root = JSONObject(config)
            root.remove(CONFIG_KEY)
            root.remove(LABELS_CONFIG_KEY)
            return root.toString()
        }
    }
}

internal data class NetworkServerChoice(val profileId: String, val tag: String, val label: String?)

private val outboundSocketOptions = listOf(
    "protect_path", "bind_interface", "inet4_bind_address", "inet6_bind_address",
    "network_strategy", "network_type", "fallback_network_type",
)

internal fun prepareNetworkServerRuntime(
    config: String,
    startupTag: String?,
    freshCachePath: String?,
    protectPath: String,
): String {
    val root = JSONObject(config)
    val outbounds = root.getJSONArray("outbounds")
    for (index in 0 until outbounds.length()) {
        val outbound = outbounds.getJSONObject(index)
        if (startupTag != null && outbound.optString("tag") == "select") {
            outbound.put("default", startupTag)
        }
        // Only the proxy which opens the physical socket needs this hook.
        // The direct outbound must keep Android's own route to local hosts.
        if (outbound.optString("server").isNotBlank() &&
            outbound.optString("detour").isBlank() &&
            outboundSocketOptions.none(outbound::has)
        ) {
            outbound.put("protect_path", protectPath)
        }
    }
    if (freshCachePath != null) {
        val experimental = root.optJSONObject("experimental") ?: JSONObject()
        val cache = experimental.optJSONObject("cache_file") ?: JSONObject()
        cache.put("path", freshCachePath)
        experimental.put("cache_file", cache)
        root.put("experimental", experimental)
    }
    return root.toString()
}
