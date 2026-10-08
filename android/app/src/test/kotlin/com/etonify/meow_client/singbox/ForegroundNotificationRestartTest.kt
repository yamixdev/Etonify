package com.etonify.meow_client.singbox

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.etonify.meow_client.MeowApplication
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers
import org.robolectric.Shadows.shadowOf
import android.os.Looper

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
    fun `a fresh client measurement populates notification ping without a manual tap`() {
        val notification = MeowForegroundNotification(service, 42)
        notification.buildForForeground("Connected")
        notification.onUrlTestResult("node-new", 27L, System.currentTimeMillis() / 1000L, "available")
        val built = notification.buildForForeground("Connected")
        assertTrue(built.extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("27 мс"))
    }

    @Test
    fun `a cached measurement from before startup is not borrowed`() {
        val notification = MeowForegroundNotification(service, 42)
        notification.buildForForeground("Connected")
        notification.onUrlTestResult("node-new", 27L, System.currentTimeMillis() / 1000L - 30L, "available")
        val built = notification.buildForForeground("Connected")
        assertFalse(built.extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("27 мс"))
    }

    @Test
    fun `tile start probes the authoritative leaf once without enabling a sweep`() {
        val requests = mutableListOf<Pair<String, Boolean>>()
        val notification = MeowForegroundNotification(service, 42) { request, force, callback ->
            requests += request.targetOutboundTag to force
            callback(Result.success(Unit))
        }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        assertTrue(requests.isEmpty())
        notification.updateSelectedOutbounds(mapOf("select" to "node-old"))
        assertEquals(listOf("node-old" to false), requests)
        notification.updateSelectedOutbounds(mapOf("select" to "node-old"))
        notification.onRuntimeReady(7L, 3L, true)
        assertEquals(1, requests.size)
        notification.onUrlTestResult("node-old", 27L, System.currentTimeMillis() / 1000L, "available",
            runtimeGeneration = 7L, networkGeneration = 3L, revision = 18L, sessionId = 9L, selectionEpoch = 0L)
        assertTrue(notification.buildForForeground("Connected").extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("27 мс"))
        assertTrue(notification.requestLatencyRefresh())
        assertEquals("node-old" to true, requests.last())
    }

    @Test
    fun `a client group already dispatched before the first snapshot owns startup`() {
        var requests = 0
        val notification = MeowForegroundNotification(service, 42) { _, _, _ -> requests++ }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        val token = notification.onClientUrlTestRequested("select", "", emptyList(), "")
        assertTrue(token != null)
        notification.updateSelectedOutbounds(mapOf("select" to "node-old"))
        assertEquals(0, requests)
    }

    @Test
    fun `client bridge borrows the completed native result without another request`() {
        var requests = 0
        val notification = MeowForegroundNotification(service, 42) { _, _, _ -> requests++ }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"))
        var reply: Map<String?, Any?>? = null
        notification.prepareStartupUrlTest(7L, setOf("node-new", "node-old")) { reply = it }
        assertEquals(null, reply)
        notification.onUrlTestResult("node-new", 31L, System.currentTimeMillis() / 1000L, "available",
            runtimeGeneration = 7L, networkGeneration = 3L, revision = 18L, sessionId = 9L, selectionEpoch = 0L)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals("node-new", reply!!["borrowedTag"])
        assertEquals(31L, reply["delayMillis"])
        assertEquals(1, requests)
    }

    @Test
    fun `client-only startup has no notification fallback`() {
        var requests = 0
        val notification = MeowForegroundNotification(service, 42) { _, _, _ -> requests++ }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, false)
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"))
        assertEquals(0, requests)
    }

    @Test
    fun `an attaching UI preserves the pending native startup probe`() {
        val notification = MeowForegroundNotification(service, 42) { _, _, _ -> }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"))
        notification.updatePresentation(presentation() + mapOf("targetOutboundTag" to "", "latencyMillis" to null))
        assertTrue(ReflectionHelpers.getField<Boolean>(notification, "latencyActionInFlight"))
        notification.onUrlTestResult("node-new", 31L, System.currentTimeMillis() / 1000L, "available",
            runtimeGeneration = 7L, networkGeneration = 3L, revision = 18L, sessionId = 9L, selectionEpoch = 0L)
        assertTrue(notification.buildForForeground("Connected").extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("31 мс"))
    }

    @Test
    fun `same second old network result cannot answer the next startup context`() {
        val notification = MeowForegroundNotification(service, 42) { _, _, _ -> }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"))
        notification.onNetworkGenerationChanged(4L)
        notification.onRuntimeReady(7L, 4L, true)
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"), 7L, 4L)
        val now = System.currentTimeMillis() / 1000L
        notification.onUrlTestResult("node-new", 91L, now, "available", runtimeGeneration = 7L, networkGeneration = 3L)
        assertFalse(notification.buildForForeground("Connected").extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("91 мс"))
        notification.onUrlTestResult("node-new", 28L, now, "available", runtimeGeneration = 7L, networkGeneration = 4L,
            revision = 19L, sessionId = 10L, selectionEpoch = 0L)
        assertTrue(notification.buildForForeground("Connected").extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("28 мс"))
    }

    @Test
    fun `selection ABA rejects the old same leaf delta even in the same second`() {
        val notification = MeowForegroundNotification(service, 42) { _, _, _ -> }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"))
        notification.updateSelectedOutbounds(mapOf("select" to "node-old"))
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"))
        val now = System.currentTimeMillis() / 1000L
        notification.onUrlTestResult("node-new", 91L, now, "available", 7L, 3L,
            revision = 18L, sessionId = 9L, selectionEpoch = 0L)
        notification.onUrlTestResult("node-new", 92L, now, "available", 7L, 3L)
        assertFalse(notification.buildForForeground("Connected").extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("9"))
        notification.onUrlTestResult("node-new", 28L, now, "available", 7L, 3L,
            revision = 19L, sessionId = 10L, selectionEpoch = 2L)
        assertTrue(notification.buildForForeground("Connected").extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("28 мс"))
    }

    @Test
    fun `late reserved dispatch is rejected when native fallback already won`() {
        var requests = 0
        val notification = MeowForegroundNotification(service, 42) { _, _, _ -> requests++ }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"), startProbe = false)
        var reply: Map<String?, Any?>? = null
        notification.prepareStartupUrlTest(7L, setOf("node-new")) { reply = it }
        shadowOf(Looper.getMainLooper()).idle()
        val token = reply!!["startupLeaseToken"] as Long
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofSeconds(5))
        assertEquals(1, requests)
        assertNull(notification.dispatchStartupUrlTest(token, 7L, 3L, "select", "node-new", emptyList(), "", 20_000, "late"))
        assertEquals(1, requests)
    }

    @Test
    fun `only the covering owned session terminal releases a dispatched full startup before its leaf`() {
        var requests = 0
        val notification = MeowForegroundNotification(service, 42) { _, _, _ -> requests++ }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        notification.onClientUrlTestRequested("select", "", emptyList(), "", 20_000, "owned")
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"))
        notification.onClientStartupSessionTerminal("manual", 7L, 3L)
        assertEquals(0, requests)
        notification.onClientStartupSessionTerminal("owned", 7L, 3L)
        assertEquals(1, requests)
        notification.onClientStartupSessionTerminal("owned", 7L, 3L)
        assertEquals(1, requests)
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

    @Test fun `tile waits for the nested auto leaf not a configuration default`() {
        MeowApplication.configFile.writeText("""{"outbounds":[{"type":"selector","tag":"select","default":"auto","outbounds":["auto"]},{"type":"urltest","tag":"auto","outbounds":["node-old","node-new"]},{"type":"vless","tag":"node-old"},{"type":"vless","tag":"node-new"}]}""")
        val targets = mutableListOf<String>()
        val notification = MeowForegroundNotification(service, 42) { request, _, _ -> targets += request.targetOutboundTag }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        notification.updateSelectedOutbounds(mapOf("select" to "auto"))
        assertTrue(targets.isEmpty())
        notification.updateSelectedOutbounds(mapOf("select" to "auto", "auto" to "node-new"))
        assertEquals(listOf("node-new"), targets)
    }

    @Test fun `completed attributed core cache satisfies a cold startup with no new event`() {
        val cache = ReflectionHelpers.getField<java.util.concurrent.ConcurrentHashMap<String, NativeLatencyResult>>(SingboxController, "notificationLatencyCache")
        val now = System.currentTimeMillis()
        cache["node-new"] = NativeLatencyResult(7L, 3L, "node-new", 33L, now, "available", 18L, 9L, "", 0L)
        try {
            var requests = 0
            val notification = MeowForegroundNotification(service, 42) { _, _, _ -> requests++ }
            notification.buildForForeground("Connected")
            notification.onRuntimeReady(7L, 3L, true)
            notification.updateSelectedOutbounds(mapOf("select" to "node-new"))
            var reply: Map<String?, Any?>? = null
            notification.prepareStartupUrlTest(7L, setOf("node-new")) { reply = it }
            shadowOf(Looper.getMainLooper()).idle()
            assertEquals(0, requests)
            assertEquals(33L, reply!!["delayMillis"])
            assertEquals(18L, reply["revision"])
            assertEquals(9L, reply["sessionId"])
        } finally { cache.clear() }
    }

    @Test fun `legacy snapshot does not cancel native startup watchdog or fabricate a borrowed result`() {
        val notification = MeowForegroundNotification(service, 42) { _, _, _ -> }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"))
        notification.onUrlTestResult("node-new", 31L, System.currentTimeMillis() / 1000L, "available", 7L, 3L)
        assertTrue(ReflectionHelpers.getField<Boolean>(notification, "latencyActionInFlight"))
        var reply: Map<String?, Any?>? = null
        notification.prepareStartupUrlTest(7L, setOf("node-new")) { reply = it }
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofSeconds(36))
        assertEquals("", reply!!["borrowedTag"])
        assertNull(reply["sessionId"])
    }

    @Test fun `accepted full client request without terminal or leaf releases after its actual deadline`() {
        var requests = 0
        val notification = MeowForegroundNotification(service, 42) { _, _, _ -> requests++ }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        notification.onClientUrlTestRequested("select", "", emptyList(), "", 600, "abandoned")
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"))
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofMillis(1599))
        assertEquals(0, requests)
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofMillis(1))
        assertEquals(1, requests)
    }

    @Test fun `native dispatch failure is not borrowed as a fabricated unavailable measurement`() {
        val notification = MeowForegroundNotification(service, 42) { _, _, callback -> callback(Result.failure(IllegalStateException("dispatch failed"))) }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, true)
        notification.updateSelectedOutbounds(mapOf("select" to "node-new"))
        var reply: Map<String?, Any?>? = null
        notification.prepareStartupUrlTest(7L, setOf("node-new")) { reply = it }
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals("", reply!!["borrowedTag"])
        assertTrue((reply["startupLeaseToken"] as Long) > 0L)
        assertNull(reply["sessionId"])
    }
}
