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

    fun remembers(requested: ServerNetworkSnapshot?, current: ServerNetworkSnapshot?): Boolean =
        enabled && remember && requested != null && requested == current
}

internal object NetworkServerPreferences {
    const val CHANNEL = "com.etonify.meow_client/network_servers"
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
    fun update(profileId: String, field: String, value: Any?): NetworkServerPolicy {
        val editor = preferences.edit()
        when (field) {
            "enabled", "remember" -> editor.putBoolean(field, value as Boolean)
            else -> {
                val network = ServerNetwork.entries.first { it.key == field }
                val tag = (value as? String)?.takeIf(String::isNotBlank)
                editor.putString(key(profileId, "configured", network), tag)
                editor.remove(key(profileId, "remembered", network))
            }
        }
        editor.apply()
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

    fun wireValue(policy: NetworkServerPolicy): Map<String, Any> = mapOf(
        "enabled" to policy.enabled,
        "remember" to policy.remember,
        "configured" to policy.configured.mapKeys { it.key.key },
        "remembered" to policy.remembered.mapKeys { it.key.key },
    )
}

internal data class NetworkServerProfile(
    val id: String,
    val selectableTags: Set<String>,
    val defaultTag: String,
) {
    companion object {
        const val CONFIG_KEY = "etonify_profile_id"

        fun removeFrom(config: JSONObject): NetworkServerProfile? {
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
                return NetworkServerProfile(id, tags, outbound.optString("default"))
            }
            return null
        }

        fun coreConfig(config: String): String {
            if (!config.contains("\"$CONFIG_KEY\"")) return config
            val root = JSONObject(config)
            return if (root.remove(CONFIG_KEY) != null) root.toString() else config
        }
    }
}
