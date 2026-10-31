package com.etonify.meow_client.root

import org.json.JSONArray

internal data class RootModuleRelease(val tag: String, val downloadUrl: String) {
    val moduleVersion: String get() = tag.removePrefix("root-module-v")
}

internal object RootModuleReleaseIndex {
    const val MAX_BYTES = 512L * 1024
    const val API_URL = "https://api.github.com/repos/yamixdev/Etonify/releases?per_page=30"
    const val ASSET_NAME = "etonify-root-arm64-v8a.zip"
    private val TAG = Regex("root-module-v[0-9]+\\.[0-9]+\\.[0-9]+")

    fun parse(bytes: ByteArray): RootModuleRelease {
        if (bytes.size > MAX_BYTES) throw RootModuleException("release_index_size_exceeded")
        try {
            val releases = JSONArray(String(bytes, Charsets.UTF_8))
            if (releases.length() > 30) throw RootModuleException("release_index_invalid")
            for (i in 0 until releases.length()) {
                val release = releases.optJSONObject(i) ?: continue
                val tag = release.optString("tag_name")
                if (!TAG.matches(tag) || release.opt("draft") != false ||
                    release.opt("published_at") !is String || release.getString("published_at").isBlank()) continue
                val assets = release.optJSONArray("assets") ?: continue
                val matches = (0 until assets.length()).mapNotNull { assets.optJSONObject(it) }
                    .filter { it.optString("name") == ASSET_NAME }
                if (matches.isEmpty()) continue
                if (matches.size != 1) throw RootModuleException("release_asset_invalid")
                val expected = "https://github.com/yamixdev/Etonify/releases/download/$tag/$ASSET_NAME"
                if (matches.single().opt("browser_download_url") != expected) throw RootModuleException("release_asset_invalid")
                return RootModuleRelease(tag, expected)
            }
            throw RootModuleException("module_release_unavailable")
        } catch (error: RootModuleException) { throw error
        } catch (_: Exception) { throw RootModuleException("release_index_invalid") }
    }
}
