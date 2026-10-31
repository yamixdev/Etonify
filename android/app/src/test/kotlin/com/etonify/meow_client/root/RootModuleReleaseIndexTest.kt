package com.etonify.meow_client.root

import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class RootModuleReleaseIndexTest {
    private fun release(tag: String, draft: Boolean = false, url: String = "https://github.com/yamixdev/Etonify/releases/download/$tag/etonify-root-arm64-v8a.zip") =
        """{"tag_name":"$tag","draft":$draft,"published_at":"2026-10-30T12:00:00Z","assets":[{"name":"etonify-root-arm64-v8a.zip","browser_download_url":"$url"}]}"""

    @Test fun `ignores app releases and draft modules then selects newest published module`() {
        val index = "[${release("v0.3.12")},${release("root-module-v0.3.0", true)},${release("root-module-v0.2.0")},${release("root-module-v0.1.0")}]"
        assertEquals("root-module-v0.2.0", RootModuleReleaseIndex.parse(index.toByteArray()).tag)
    }

    @Test fun `asset metadata cannot redirect download to another host`() {
        val index = "[${release("root-module-v0.2.0", url = "https://evil.example/etonify-root-arm64-v8a.zip")}]"
        assertEquals("release_asset_invalid", assertThrows(RootModuleException::class.java) {
            RootModuleReleaseIndex.parse(index.toByteArray())
        }.code)
    }

    @Test fun `asset metadata cannot choose another repository or add URL parameters`() {
        for (url in listOf(
            "https://github.com/other/repo/releases/download/root-module-v0.2.0/etonify-root-arm64-v8a.zip",
            "https://github.com/yamixdev/Etonify/releases/download/root-module-v0.2.0/etonify-root-arm64-v8a.zip?redirect=evil",
        )) {
            assertEquals("release_asset_invalid", assertThrows(RootModuleException::class.java) {
                RootModuleReleaseIndex.parse("[${release("root-module-v0.2.0", url = url)}]".toByteArray())
            }.code)
        }
    }

    @Test fun `malformed module tag and unpublished release cannot become update candidates`() {
        val index = "[${release("root-module-v1.2.3-extra")},${release("root-module-v1.2.3").replace("\"2026-10-30T12:00:00Z\"", "null")}]"
        assertEquals("module_release_unavailable", assertThrows(RootModuleException::class.java) {
            RootModuleReleaseIndex.parse(index.toByteArray())
        }.code)
    }

    @Test fun `oversized release metadata is rejected before parsing`() {
        assertEquals("release_index_size_exceeded", assertThrows(RootModuleException::class.java) {
            RootModuleReleaseIndex.parse(ByteArray(512 * 1024 + 1))
        }.code)
    }
}
