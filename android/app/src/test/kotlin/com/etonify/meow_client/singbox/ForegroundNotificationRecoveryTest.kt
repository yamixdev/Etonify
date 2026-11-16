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

    @Test fun `wake fallback does not probe other servers for a manual selection`() {
        assertFalse(notification.requestAutoGroupRecovery(7L, 3L, 0L) { true })
        assertTrue(requests.isEmpty())
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

    @Test fun `wake fallback probes only the selected auto group`() {
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
        assertFalse(notification.requestAutoGroupRecovery(7L, 3L, 0L) { false })
        assertFalse(notification.requestAutoGroupRecovery(7L, 4L, 0L) { true })
        assertTrue(requests.isEmpty())
        assertTrue(notification.requestAutoGroupRecovery(7L, 3L, 0L) { true })
        val request = requests.single()
        assertEquals("auto", request.groupTag)
        assertEquals("", request.targetOutboundTag)
        assertEquals("a", request.priorityOutboundTag)
        assertEquals(20_000, request.deadlineMillis)
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
        assertTrue(notification.requestAutoGroupRecovery(7L, 3L, 0L) { true })

        val request = requests.single()
        assertEquals("lowest", request.groupTag)
        assertEquals("", request.targetOutboundTag)
        assertEquals("", request.priorityOutboundTag)
        assertEquals("http://ping.example", request.url)
        assertEquals(12_000, request.timeoutMillis)

        notification.updateSelectedOutbounds(mapOf("select" to "c"), startProbe = false)
        assertFalse(notification.requestAutoGroupRecovery(7L, 3L, 0L) { true })
        assertEquals(1, requests.size)
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
