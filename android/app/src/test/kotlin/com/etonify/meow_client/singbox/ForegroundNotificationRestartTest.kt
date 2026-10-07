package com.etonify.meow_client.singbox

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.etonify.meow_client.MeowApplication
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers

@RunWith(RobolectricTestRunner::class)
@Config(application = MeowApplication::class, sdk = [28], manifest = Config.NONE)
class ForegroundNotificationRestartTest {
    class HostService : Service() {
        override fun onBind(intent: Intent?): IBinder? = null
    }

    private lateinit var service: HostService

    @Before
    fun setUp() {
        service = Robolectric.buildService(HostService::class.java).create().get()
        service.getSharedPreferences("meow_foreground_notification", 0).edit().clear().commit()
        MeowApplication.configFile.writeText(
            """{"outbounds":[{"type":"selector","tag":"select","default":"node-new","outbounds":["node-old","node-new"]},{"type":"vless","tag":"node-old"},{"type":"vless","tag":"node-new"}]}""",
        )
    }

    private fun presentation() = mapOf<String, Any>(
        "detailed" to true,
        "title" to "My server",
        "latencyMillis" to 42L,
        "targetOutboundTag" to "node-old",
        "url" to "https://example.com/check",
        "refreshLabel" to "Check ping",
        "stopLabel" to "Stop VPN",
        "trafficDisplayMode" to "both",
        "trafficRefreshSeconds" to 7,
    )

    @Test
    fun `stop preserves notification preferences but clears the old ping`() {
        val notification = MeowForegroundNotification(service, 42)
        notification.updatePresentation(presentation())
        notification.buildForForeground("Connected")
        notification.stopAndClear()

        val restarted = MeowForegroundNotification(service, 42).buildForForeground("Connected")
        assertEquals("My server", restarted.extras.getCharSequence(Notification.EXTRA_TITLE))
        assertTrue(restarted.actions.any { it.title == "Check ping" })
        assertTrue(restarted.actions.any { it.title == "Stop VPN" })
        assertFalse(restarted.extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("42 мс"))
        val prefs = service.getSharedPreferences("meow_foreground_notification", 0)
        assertEquals("both", prefs.getString("traffic_display_mode", ""))
        assertEquals(7, prefs.getInt("traffic_refresh_seconds", 0))
    }

    @Test
    fun `stale notification cleanup does not erase the next quick-tile presentation`() {
        MeowForegroundNotification(service, 42).updatePresentation(presentation())
        MeowForegroundNotification.clearPersistedState(service, 42)
        val restarted = MeowForegroundNotification(service, 42).buildForForeground("Connected")
        assertTrue(restarted.actions.any { it.title == "Check ping" })
        assertEquals("My server", restarted.extras.getCharSequence(Notification.EXTRA_TITLE))
    }

    @Test
    fun `quick-tile startup derives the current ping target without Flutter`() {
        val notification = MeowForegroundNotification(service, 42)
        val built = notification.buildForForeground("Connected")
        assertTrue(built.actions.any { it.title == "Проверить пинг" })
        assertEquals("node-new", targetOf(notification))
    }

    @Test
    fun `restart does not probe the previous profile target`() {
        MeowForegroundNotification(service, 42).updatePresentation(presentation())
        val restarted = MeowForegroundNotification(service, 42)
        restarted.buildForForeground("Connected")
        assertEquals("node-new", targetOf(restarted))
    }

    @Test
    fun `presentation updates while stopped are available to a tile-only startup`() {
        MeowBoxService.updateNotificationPresentation(presentation())
        val restarted = MeowForegroundNotification(service, 42).buildForForeground("Connected")
        assertTrue(restarted.actions.any { it.title == "Check ping" })
        assertEquals("My server", restarted.extras.getCharSequence(Notification.EXTRA_TITLE))
    }

    @Test
    fun `idle settings retain the custom URL even without an active outbound`() {
        MeowBoxService.updateNotificationPresentation(presentation() + mapOf("targetOutboundTag" to "", "timeoutMillis" to 9000))
        val restarted = MeowForegroundNotification(service, 42)
        restarted.buildForForeground("Connected")
        val prefs = service.getSharedPreferences("meow_foreground_notification", 0)
        assertEquals("https://example.com/check", prefs.getString("urltest_url", ""))
        assertEquals(9000, prefs.getInt("urltest_timeout", 0))
        assertEquals("node-new", targetOf(restarted))
    }

    @Test
    fun `native selection updates change the ping target without Flutter`() {
        val notification = MeowForegroundNotification(service, 42)
        notification.buildForForeground("Connected")
        notification.updateSelectedOutbounds(mapOf("select" to "node-old"))
        assertEquals("node-old", targetOf(notification))
    }

    @Test
    fun `nested auto selection follows the core rather than the first member`() {
        MeowApplication.configFile.writeText("""{"outbounds":[{"type":"selector","tag":"select","default":"auto","outbounds":["auto"]},{"type":"urltest","tag":"auto","outbounds":["node-old","node-new"]},{"type":"vless","tag":"node-old"},{"type":"vless","tag":"node-new"}]}""")
        val notification = MeowForegroundNotification(service, 42)
        notification.buildForForeground("Connected")
        notification.updateSelectedOutbounds(mapOf("select" to "auto", "auto" to "node-new"))
        assertEquals("node-new", targetOf(notification))
    }

    @Test
    fun `cyclic groups do not reuse a target from a different profile`() {
        MeowForegroundNotification(service, 42).updatePresentation(presentation())
        MeowApplication.configFile.writeText("""{"outbounds":[{"type":"selector","tag":"select","outbounds":["loop"]},{"type":"selector","tag":"loop","outbounds":["select"]}]}""")
        val notification = MeowForegroundNotification(service, 42)
        val built = notification.buildForForeground("Connected")
        assertEquals(null, targetOf(notification))
        assertFalse(built.actions.any { it.title == "Check ping" })
    }

    @Test
    fun `a minimal notification stays minimal after tile restart`() {
        MeowForegroundNotification(service, 42).updatePresentation(presentation() + ("detailed" to false))
        val built = MeowForegroundNotification(service, 42).buildForForeground("Connected")
        assertFalse(built.actions.any { it.title == "Check ping" })
        assertEquals("Etonify", built.extras.getCharSequence(Notification.EXTRA_TITLE))
    }

    @Test
    fun `a delayed native selection cannot revive a stopped notification`() {
        val notification = MeowForegroundNotification(service, 42)
        notification.buildForForeground("Connected")
        notification.stopAndClear()
        notification.updateSelectedOutbounds(mapOf("select" to "node-old"))
        assertEquals("node-new", targetOf(notification))
    }

    @Test
    fun `an attaching UI without runtime state cannot remove the native ping target`() {
        val notification = MeowForegroundNotification(service, 42)
        notification.buildForForeground("Connected")
        notification.updatePresentation(presentation() + ("targetOutboundTag" to ""))
        assertEquals("node-new", targetOf(notification))
        assertTrue(notification.buildForForeground("Connected").actions.any { it.title == "Check ping" })
    }

    @Test
    fun `reload resolves the next profile rather than cached auto selections`() {
        val notification = MeowForegroundNotification(service, 42)
        notification.buildForForeground("Connected")
        notification.updateSelectedOutbounds(mapOf("select" to "node-old"))
        notification.buildForForeground("Reloading")
        MeowApplication.configFile.writeText("""{"outbounds":[{"type":"selector","tag":"select","outbounds":["next-profile"]},{"type":"vless","tag":"next-profile"}]}""")
        notification.buildForForeground("Connected")
        assertEquals("next-profile", targetOf(notification))
    }

    @Test
    fun `unknown native members cannot select a server outside the current profile`() {
        val notification = MeowForegroundNotification(service, 42)
        notification.buildForForeground("Connected")
        notification.updateSelectedOutbounds(mapOf("select" to "absent-profile-server"))
        assertEquals("node-new", targetOf(notification))
    }

    @Test
    fun `changing native leaf invalidates the previous measurement and pending action`() {
        val notification = MeowForegroundNotification(service, 42)
        notification.buildForForeground("Connected")
        notification.updatePresentation(presentation() + ("targetOutboundTag" to "node-new"))
        ReflectionHelpers.setField(notification, "latencyActionInFlight", true)
        notification.updateSelectedOutbounds(mapOf("select" to "node-old"))
        assertFalse(ReflectionHelpers.getField<Boolean>(notification, "latencyActionInFlight"))
        assertFalse(notification.buildForForeground("Connected").extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("42 мс"))
    }

    @Test
    fun `a long outbound tag is not truncated during a cold native startup`() {
        val tag = "provider-server-" + "x".repeat(150)
        MeowApplication.configFile.writeText("""{"outbounds":[{"type":"selector","tag":"select","outbounds":["$tag"]},{"type":"vless","tag":"$tag"}]}""")
        val notification = MeowForegroundNotification(service, 42)
        notification.buildForForeground("Connected")
        assertEquals(tag, targetOf(notification))
    }

    @Test
    fun `long outbound identifiers survive UI updates and persisted restoration`() {
        val tag = "provider-server-" + "x".repeat(150)
        val notification = MeowForegroundNotification(service, 42)
        notification.updatePresentation(presentation() + ("targetOutboundTag" to tag))
        assertEquals(tag, targetOf(notification))
        assertEquals(tag, targetOf(MeowForegroundNotification(service, 42)))
    }

    private fun targetOf(notification: MeowForegroundNotification): String? {
        val presentation = ReflectionHelpers.getField<Any>(notification, "presentation")
        val request = ReflectionHelpers.getField<Any?>(presentation, "urlTestRequest") ?: return null
        return ReflectionHelpers.getField<String>(request, "targetOutboundTag").takeIf { it.isNotEmpty() }
    }
}
