package com.etonify.meow_client

import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class MainActivityImportLinkTest {
    @Test
    fun `shared parser ignores opaque Happ links and accepts import links`() {
        val activity = Robolectric.buildActivity(MainActivity::class.java).get()

        assertNull(activity.buildImportDeepLinkPayload(Uri.parse("happ:payload?name=proxy")))
        assertNull(activity.buildImportDeepLinkPayload(Uri.parse("happ://routing/example")))
        val result = activity.buildImportDeepLinkPayload(
            Uri.parse("happ://add?url=https%3A%2F%2Fexample.com%2Fsub&name=Test"),
        )
        assertEquals("happAdd", result?.get("sourceType"))
        assertEquals("https://example.com/sub", result?.get("url"))
        assertEquals("Test", result?.get("name"))
    }
}
