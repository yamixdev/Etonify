package com.etonify.meow_client.singbox

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.Looper
import com.etonify.meow_client.MeowApplication
import java.time.Duration
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(application = MeowApplication::class, sdk = [28], manifest = Config.NONE)
class ForegroundNotificationRecoveryTest {
    class HostService : Service() {
        override fun onBind(intent: Intent?): IBinder? = null
    }

    private lateinit var notification: MeowForegroundNotification
    private val requests = mutableListOf<MeowForegroundNotification.UrlTestRequest>()
    private val dispatches = mutableListOf<(Result<Unit>) -> Unit>()
    private val completions = mutableListOf<NetworkHandoverProbeOutcome>()

    @Before fun setUp() {
        startNotification(
            """{"outbounds":[{"type":"selector","tag":"select","outbounds":["a","b"]},{"type":"vless","tag":"a"},{"type":"vless","tag":"b"}]}""",
            mapOf("select" to "a"),
        )
    }

    private fun startNotification(config: String, selected: Map<String, String>) {
        val service = Robolectric.buildService(HostService::class.java).create().get()
        service.getSharedPreferences("meow_foreground_notification", 0).edit().clear().commit()
        MeowApplication.configFile.writeText(config)
        notification = MeowForegroundNotification(service, 42) { request, _, callback ->
            requests += request
            dispatches += callback
        }
        notification.buildForForeground("Connected")
        notification.onRuntimeReady(7L, 3L, false)
        notification.updateSelectedOutbounds(selected, startProbe = false)
    }

    @Test fun `background recovery probes only the chosen outbound in manual mode`() {
        assertTrue(notification.requestRecoveryProbe(7L, 3L, 0L, { true }, completions::add))
        assertEquals("select", requests.single().groupTag)
        assertEquals("a", requests.single().targetOutboundTag)
    }

    @Test fun `explicit refresh measures only the chosen manual outbound`() {
        assertTrue(notification.requestLatencyRefresh())
        val request = requests.single()
        assertEquals("select", request.groupTag)
        assertEquals("a", request.targetOutboundTag)
    }

    @Test fun `background group snapshot shows latency for the newly selected leaf`() {
        notification.stopPublishing()
        startNotification(
            """
            {"outbounds":[
              {"type":"selector","tag":"select","outbounds":["provider"]},
              {"type":"urltest","tag":"provider","outbounds":["a","b"]},
              {"type":"vless","tag":"a"},{"type":"vless","tag":"b"}
            ]}
            """.trimIndent(),
            mapOf("select" to "provider", "provider" to "a"),
        )
        val now = System.currentTimeMillis() / 1_000L
        val history = listOf(
            mapOf("tag" to "a", "delay" to 70L, "time" to now),
            mapOf("tag" to "b", "delay" to 24L, "time" to now),
        )
        val selected = mapOf("select" to "provider", "provider" to "b")
        val prefs = MeowApplication.application.getSharedPreferences("meow_foreground_notification", 0)
        notification.updateGroupsSnapshot(selected, history, 7L, 3L)
        assertEquals(24L, prefs.getLong("latency", -1L))
        assertTrue(requests.isEmpty())

        notification.onNetworkGenerationChanged(4L)
        notification.updateGroupsSnapshot(selected, history, 7L, 4L)
        assertEquals(-1L, prefs.getLong("latency", -1L))
    }

    @Test fun `explicit refresh looks up the selected group once when selection is unknown`() {
        notification.stopPublishing()
        startNotification(
            """
            {"outbounds":[
              {"type":"selector","tag":"select","outbounds":["a","provider"],"default":"a"},
              {"type":"urltest","tag":"provider","outbounds":["a","b"]},
              {"type":"vless","tag":"a"},{"type":"vless","tag":"b"}
            ]}
            """.trimIndent(),
            emptyMap(),
        )
        var finish: ((Result<Map<String, Any?>>) -> Unit)? = null
        assertTrue(notification.requestManualLatencyRefresh { finish = it })
        assertFalse(notification.requestManualLatencyRefresh { error("Duplicate selector lookup") })
        assertTrue(requests.isEmpty())

        requireNotNull(finish)(Result.success(mapOf(
            "runtimeGeneration" to 7L,
            "networkGeneration" to 3L,
            "selectedOutbounds" to mapOf("select" to "provider", "provider" to "b"),
        )))
        assertEquals("provider", requests.single().groupTag)
        assertEquals("", requests.single().targetOutboundTag)
        assertEquals("b", requests.single().priorityOutboundTag)
    }

    @Test fun `group history cannot finish a manual latency request`() {
        assertTrue(notification.requestManualLatencyRefresh())
        val time = System.currentTimeMillis() / 1_000L + 2L
        notification.updateGroupsSnapshot(
            mapOf("select" to "a"),
            listOf(mapOf("tag" to "a", "delay" to 32L, "time" to time)),
            7L, 3L,
        )
        assertFalse(notification.requestManualLatencyRefresh())
        assertEquals(1, requests.size)
    }

    @Test fun `handover refresh looks up the new network instead of testing the previous group`() {
        notification.stopPublishing()
        startNotification(
            """
            {"outbounds":[
              {"type":"selector","tag":"select","outbounds":["provider","c"]},
              {"type":"urltest","tag":"provider","outbounds":["a","b"]},
              {"type":"vless","tag":"a"},{"type":"vless","tag":"b"},{"type":"vless","tag":"c"}
            ]}
            """.trimIndent(),
            mapOf("select" to "provider", "provider" to "a"),
        )
        notification.onNetworkGenerationChanged(4L)

        var finish: ((Result<Map<String, Any?>>) -> Unit)? = null
        assertTrue(notification.requestManualLatencyRefresh { finish = it })
        assertTrue(requests.isEmpty())
        requireNotNull(finish)(Result.success(mapOf(
            "runtimeGeneration" to 7L,
            "networkGeneration" to 4L,
            "selectedOutbounds" to mapOf("select" to "c"),
        )))

        assertEquals("select", requests.single().groupTag)
        assertEquals("c", requests.single().targetOutboundTag)
    }

    @Test fun `handover cannot restore stale Flutter latency for the same leaf`() {
        notification.onNetworkGenerationChanged(4L)
        notification.updateSelectedOutbounds(mapOf("select" to "a"), 7L, 4L, startProbe = false)
        notification.updatePresentation(mapOf(
            "url" to "http://ping.example",
            "targetOutboundTag" to "a",
            "latencyMillis" to 35L,
        ))
        val prefs = MeowApplication.application.getSharedPreferences("meow_foreground_notification", 0)
        assertEquals(-1L, prefs.getLong("latency", -1L))
    }

    @Test fun `explicit refresh of a provider group starts a bounded candidate scan`() {
        notification.stopPublishing()
        startNotification(
            """
            {"outbounds":[
              {"type":"selector","tag":"select","outbounds":["provider","c"]},
              {"type":"urltest","tag":"provider","outbounds":["a","b"]},
              {"type":"vless","tag":"a"},{"type":"vless","tag":"b"},{"type":"vless","tag":"c"}
            ]}
            """.trimIndent(),
            mapOf("select" to "provider", "provider" to "a"),
        )
        notification.updatePresentation(mapOf("url" to "http://ping.example", "timeoutMillis" to 5_000))

        assertTrue(notification.requestLatencyRefresh())
        assertFalse(notification.requestLatencyRefresh())
        val request = requests.single()
        assertEquals("provider", request.groupTag)
        assertEquals("", request.targetOutboundTag)
        assertEquals("a", request.priorityOutboundTag)
        assertEquals(3, request.concurrency)
        assertEquals(20_000, request.deadlineMillis)
        assertEquals("http://ping.example", request.url)

        val now = System.currentTimeMillis()
        notification.onUrlTestResult("b", 23L, now / 1_000L, "available", 7L, 3L,
            now, 1L, 1L, selectionEpoch = 0L, logicalSessionId = request.logicalSessionId)
        notification.updateSelectedOutbounds(mapOf("select" to "provider", "provider" to "b"), startProbe = false)
        assertFalse(notification.requestLatencyRefresh())
        val prefs = MeowApplication.application.getSharedPreferences("meow_foreground_notification", 0)
        assertEquals(23L, prefs.getLong("latency", -1L))

        notification.onUrlTestSessionTerminal(request.logicalSessionId, 7L, 3L)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(22))
        notification.updateSelectedOutbounds(mapOf("select" to "provider", "provider" to "a"), startProbe = false)
        notification.updateSelectedOutbounds(mapOf("select" to "provider", "provider" to "b"), startProbe = false)
        assertEquals(-1L, prefs.getLong("latency", -1L))
        assertTrue(notification.requestLatencyRefresh())
        assertEquals("b", requests.last().priorityOutboundTag)
    }

    @Test fun `explicit group refresh supersedes a tile startup leaf measurement`() {
        notification.stopPublishing()
        startNotification(
            """
            {"outbounds":[
              {"type":"selector","tag":"select","outbounds":["provider"]},
              {"type":"urltest","tag":"provider","outbounds":["a","b"]},
              {"type":"vless","tag":"a"},{"type":"vless","tag":"b"}
            ]}
            """.trimIndent(),
            mapOf("select" to "provider", "provider" to "a"),
        )
        notification.onRuntimeReady(7L, 3L, true)
        assertEquals("a", requests.single().targetOutboundTag)

        assertTrue(notification.requestManualLatencyRefresh())
        assertFalse(notification.requestManualLatencyRefresh())
        val group = requests.last()
        assertEquals("provider", group.groupTag)
        assertEquals("", group.targetOutboundTag)

        val measuredAt = System.currentTimeMillis()
        notification.onUrlTestResult(
            "b", 23L, measuredAt / 1_000L, "available", 7L, 3L, measuredAt, 2L, 2L,
            selectionEpoch = 0L, logicalSessionId = group.logicalSessionId,
        )
        notification.onUrlTestSessionTerminal(group.logicalSessionId, 7L, 3L)
        notification.updateSelectedOutbounds(mapOf("select" to "provider", "provider" to "b"), startProbe = false)

        val prefs = MeowApplication.application.getSharedPreferences("meow_foreground_notification", 0)
        assertEquals(23L, prefs.getLong("latency", -1L))
    }

    @Test fun `recovery uses the configured HTTP URL and timeout and rejects changed settings`() {
        notification.updatePresentation(mapOf(
            "url" to "http://ping.example/check",
            "timeoutMillis" to 12_000,
            "deadlineMillis" to 17_000,
        ))
        val previous = checkNotNull(notification.recoveryProbeRequest())
        notification.updatePresentation(mapOf(
            "url" to "http://new.example/check",
            "timeoutMillis" to 15_000,
            "deadlineMillis" to 20_000,
        ))

        assertFalse(notification.requestLatencyRefresh(recoveryRequest = previous) {})
        val current = checkNotNull(notification.recoveryProbeRequest())
        assertTrue(notification.requestLatencyRefresh(recoveryRequest = current) {})
        val request = requests.single()
        assertEquals("a", request.targetOutboundTag)
        assertEquals("http://new.example/check", request.url)
        assertEquals(15_000, request.timeoutMillis)
        assertEquals(20_000, request.deadlineMillis)
    }

    @Test fun `background recovery starts with the active auto group even when its leaf is known`() {
        notification.stopPublishing()
        startNotification(
            """
            {"outbounds":[
              {"type":"selector","tag":"select","outbounds":["auto","c"]},
              {"type":"urltest","tag":"auto","outbounds":["a","b"]},
              {"type":"vless","tag":"a"},{"type":"vless","tag":"b"},{"type":"vless","tag":"c"}
            ]}
            """.trimIndent(),
            mapOf("select" to "auto", "auto" to "a"),
        )
        assertFalse(notification.requestRecoveryProbe(7L, 3L, 0L, { false }, completions::add))
        assertFalse(notification.requestRecoveryProbe(7L, 4L, 0L, { true }, completions::add))
        assertTrue(requests.isEmpty())
        assertTrue(notification.requestRecoveryProbe(7L, 3L, 0L, { true }, completions::add))
        val request = requests.single()
        assertEquals("auto", request.groupTag)
        assertEquals("", request.targetOutboundTag)
        assertEquals("a", request.priorityOutboundTag)
        assertEquals(3, request.concurrency)
        assertEquals(20_000, request.deadlineMillis)
        dispatches.single()(Result.failure(IllegalStateException("command rejected")))
        assertEquals(listOf(NetworkHandoverProbeOutcome.INCONCLUSIVE), completions)

        assertTrue(notification.requestRecoveryProbe(7L, 3L, 0L, { true }, completions::add))
        val next = requests.last()
        notification.onUrlTestSessionTerminal("unrelated", 7L, 3L, NetworkHandoverProbeOutcome.UNHEALTHY)
        assertEquals(1, completions.size)
        notification.onUrlTestSessionTerminal(next.logicalSessionId, 7L, 3L, NetworkHandoverProbeOutcome.UNHEALTHY)
        assertEquals(NetworkHandoverProbeOutcome.UNHEALTHY, completions.last())
    }

    @Test fun `fastest can recover when the core has no current leaf`() {
        notification.stopPublishing()
        startNotification(
            """
            {"outbounds":[
              {"type":"selector","tag":"select","outbounds":["lowest","c"]},
              {"type":"urltest","tag":"lowest","outbounds":["a","b"]},
              {"type":"vless","tag":"a"},{"type":"vless","tag":"b"},{"type":"vless","tag":"c"}
            ]}
            """.trimIndent(),
            mapOf("select" to "lowest"),
        )
        notification.updatePresentation(mapOf("url" to "http://ping.example", "timeoutMillis" to 12_000))

        assertNull(notification.recoveryProbeRequest())
        assertTrue(notification.requestRecoveryProbe(7L, 3L, 0L, { true }, completions::add))

        val request = requests.single()
        assertEquals("lowest", request.groupTag)
        assertEquals("", request.targetOutboundTag)
        assertEquals("", request.priorityOutboundTag)
        assertEquals("http://ping.example", request.url)
        assertEquals(12_000, request.timeoutMillis)

        notification.updateSelectedOutbounds(mapOf("select" to "c"), startProbe = false)
        assertTrue(notification.requestRecoveryProbe(
            7L, 3L, notification.currentSelectionEpoch, { true }, completions::add,
        ))
        assertEquals(2, requests.size)
        assertEquals("select", requests.last().groupTag)
        assertEquals("c", requests.last().targetOutboundTag)
    }

    private fun request(): Boolean {
        return notification.requestLatencyRefresh { success ->
            assertFalse("Completion must run outside notification lock", Thread.holdsLock(notification))
            completions += success
        }
    }

    private fun result(delay: Long = 23L, status: String = "available", runtime: Long = 7L,
        network: Long = 3L, revision: Long = 1L, session: Long = 1L,
        measured: Long = System.currentTimeMillis(), selection: Long = 0L,
        logical: String? = null,
    ) {
        notification.onUrlTestResult("a", delay, measured / 1000L, status, runtime, network,
            measured, revision, session, "", selection, logical ?: requests.last().logicalSessionId)
    }

    @Test fun `fresh attributed selected leaf completes once outside the lock`() {
        assertTrue(request())
        result()
        result()
        assertTrue(completions.isEmpty())
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf(NetworkHandoverProbeOutcome.HEALTHY), completions)
    }

    @Test fun `legacy snapshot cannot consume recovery observer or watchdog`() {
        assertTrue(request())
        notification.onUrlTestResult("a", 30L, System.currentTimeMillis() / 1000L, "available")
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(completions.isEmpty())
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(21))
        assertEquals(listOf(NetworkHandoverProbeOutcome.INCONCLUSIVE), completions)
    }

    @Test fun `old same second cache and unrelated request do not complete recovery`() {
        val cachedAt = System.currentTimeMillis() - 1L
        assertTrue(request())
        result(measured = cachedAt)
        result(logical = "unrelated-manual-probe")
        result(runtime = 6L)
        result(network = 2L)
        result(selection = 2L)
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(completions.isEmpty())
        result(revision = 2L)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf(NetworkHandoverProbeOutcome.HEALTHY), completions)
    }

    @Test fun `attributed failure completes once despite late dispatch failure`() {
        assertTrue(request())
        result(delay = 0L, status = "unavailable")
        dispatches.single()(Result.failure(IllegalStateException("late dispatch")))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(22))
        assertEquals(listOf(NetworkHandoverProbeOutcome.UNHEALTHY), completions)
    }

    @Test fun `dispatch failure reports one inconclusive result`() {
        assertTrue(request())
        dispatches.single()(Result.failure(IllegalStateException("dispatch failed")))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(22))
        assertEquals(listOf(NetworkHandoverProbeOutcome.INCONCLUSIVE), completions)
    }

    @Test fun `same context busy action is joined without a duplicate probe`() {
        assertTrue(notification.requestLatencyRefresh())
        assertTrue(request())
        assertEquals(1, requests.size)
        result()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf(NetworkHandoverProbeOutcome.HEALTHY), completions)
    }

    @Test fun `stop cancels queued completion and watchdog`() {
        assertTrue(request())
        result()
        notification.stopPublishing()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(22))
        assertTrue(completions.isEmpty())
    }

    @Test fun `network change cancels queued completion and late dispatch failure`() {
        assertTrue(request())
        result()
        notification.onNetworkGenerationChanged(4L)
        dispatches.single()(Result.failure(IllegalStateException("old network")))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(22))
        assertTrue(completions.isEmpty())
    }

    @Test fun `target change cancels observer even when target changes back`() {
        assertTrue(request())
        notification.updateSelectedOutbounds(mapOf("select" to "b"), startProbe = false)
        notification.updateSelectedOutbounds(mapOf("select" to "a"), startProbe = false)
        result()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(22))
        assertTrue(completions.isEmpty())
    }

    @Test fun `runtime replacement cancels observer`() {
        assertTrue(request())
        notification.onRuntimeReady(8L, 3L, false)
        result()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(22))
        assertTrue(completions.isEmpty())
    }

    @Test fun `cancelled own probe reports one inconclusive result`() {
        assertTrue(request())
        result(delay = 0L, status = "cancelled")
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(22))
        assertEquals(listOf(NetworkHandoverProbeOutcome.INCONCLUSIVE), completions)
    }

    @Test fun `missing result is unknown and a late result cannot revive its observer`() {
        assertTrue(request())
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(21))
        result()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf(NetworkHandoverProbeOutcome.INCONCLUSIVE), completions)
    }

    @Test fun `covering client startup is declined without duplicate probe or failure`() {
        notification.onRuntimeReady(8L, 3L, true)
        notification.onClientUrlTestRequested("select", "a", emptyList(), "", 20_000, "client-startup")
        notification.updateSelectedOutbounds(mapOf("select" to "a"), startProbe = false)
        assertFalse(request())
        assertTrue(requests.isEmpty())
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(20))
        assertTrue(completions.isEmpty())
    }
}
