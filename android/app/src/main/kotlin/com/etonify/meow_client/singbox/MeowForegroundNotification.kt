package com.etonify.meow_client.singbox

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.etonify.meow_client.MainActivity
import com.etonify.meow_client.MeowApplication
import com.etonify.meow_client.R
import com.etonify.meow_client.generated.notificationTrafficModeBoth
import com.etonify.meow_client.generated.notificationTrafficModeSpeed
import com.etonify.meow_client.generated.notificationTrafficModeTotal
import kotlin.math.max
import org.json.JSONObject

/**
 * Owns the foreground notification while a libbox runtime is active.
 *
 * The service, rather than Flutter, owns this state intentionally: a VPN
 * foreground service can outlive the Activity and Flutter engine. Flutter only
 * supplies the currently selected outbound and localized labels; transfer
 * speeds remain native status-stream values.
 */
internal class MeowForegroundNotification(
    private val service: Service,
    private val notificationId: Int,
    private val latencyTestRunner: ((UrlTestRequest, Boolean, (Result<Unit>) -> Unit) -> Unit)? = null,
) {
    companion object {
        const val CHANNEL_ID = "etonify_vpn_status"
        const val PROBE_CHANNEL_ID = "etonify_server_check"
        const val ACTION_REFRESH_LATENCY = "com.etonify.meow_client.singbox.REFRESH_LATENCY"

        private const val ACTION_REFRESH_REQUEST_CODE = 4201
        private const val ACTION_STOP_REQUEST_CODE = 4202
        private const val CONTENT_REQUEST_CODE = 4203
        private const val DEFAULT_LATENCY_TIMEOUT_MS = 20_000L
        private const val MAX_TEXT_LENGTH = 120
        private const val DEFAULT_TRAFFIC_REFRESH_SECONDS = 2
        private const val DEFAULT_PROBE_URL = "https://www.gstatic.com/generate_204"
        private const val PRESENTATION_PREFS = "meow_foreground_notification"
        private const val PREF_DETAILED = "detailed"
        private const val PREF_TRAFFIC_DISPLAY_MODE = "traffic_display_mode"
        private const val PREF_TRAFFIC_REFRESH_SECONDS = "traffic_refresh_seconds"
        private const val PREF_TITLE = "title"
        private const val PREF_LATENCY = "latency"
        private const val PREF_CONNECTED_TEXT = "connected_text"
        private const val PREF_CHECKING_TEXT = "checking_text"
        private const val PREF_UNAVAILABLE_TEXT = "unavailable_text"
        private const val PREF_TOTAL_LABEL = "total_label"
        private const val PREF_REFRESH_LABEL = "refresh_label"
        private const val PREF_STOP_LABEL = "stop_label"
        private const val PREF_URLTEST_GROUP = "urltest_group"
        private const val PREF_URLTEST_TARGET = "urltest_target"
        private const val PREF_URLTEST_PRIORITY = "urltest_priority"
        private const val PREF_URLTEST_EXCLUDE = "urltest_exclude"
        private const val PREF_URLTEST_URL = "urltest_url"
        private const val PREF_URLTEST_TIMEOUT = "urltest_timeout"
        private const val PREF_URLTEST_CONCURRENCY = "urltest_concurrency"
        private const val PREF_URLTEST_DEADLINE = "urltest_deadline"

        fun clearPersistedState(context: Context, notificationId: Int) {
            context.getSharedPreferences(PRESENTATION_PREFS, Context.MODE_PRIVATE)
                .edit()
                // Labels and display preferences also belong to the next
                // tile-only start. Only the old runtime's measurement expires.
                .remove(PREF_LATENCY)
                .apply()
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(notificationId)
        }

        fun savePresentation(context: Context, arguments: Map<*, *>) {
            persistPresentation(context, Presentation.fromArguments(arguments).copy(latencyMillis = null))
        }

        private fun persistPresentation(context: Context, value: Presentation) {
            val request = value.urlTestRequest
            context.getSharedPreferences(PRESENTATION_PREFS, Context.MODE_PRIVATE).edit().apply {
                putBoolean(PREF_DETAILED, value.detailed)
                putString(PREF_TRAFFIC_DISPLAY_MODE, value.trafficDisplayMode)
                putInt(PREF_TRAFFIC_REFRESH_SECONDS, value.trafficRefreshSeconds)
                putString(PREF_TITLE, value.title)
                putString(PREF_CONNECTED_TEXT, value.connectedText)
                putString(PREF_CHECKING_TEXT, value.checkingText)
                putString(PREF_UNAVAILABLE_TEXT, value.unavailableText)
                putString(PREF_TOTAL_LABEL, value.totalLabel)
                putString(PREF_REFRESH_LABEL, value.refreshLabel)
                putString(PREF_STOP_LABEL, value.stopLabel)
                if (value.latencyMillis == null) remove(PREF_LATENCY)
                else putLong(PREF_LATENCY, value.latencyMillis)
                if (request == null) {
                    remove(PREF_URLTEST_GROUP)
                    remove(PREF_URLTEST_TARGET)
                    remove(PREF_URLTEST_PRIORITY)
                    remove(PREF_URLTEST_EXCLUDE)
                    remove(PREF_URLTEST_URL)
                    remove(PREF_URLTEST_TIMEOUT)
                    remove(PREF_URLTEST_CONCURRENCY)
                    remove(PREF_URLTEST_DEADLINE)
                } else {
                    putString(PREF_URLTEST_GROUP, request.groupTag)
                    putString(PREF_URLTEST_TARGET, request.targetOutboundTag)
                    putString(PREF_URLTEST_PRIORITY, request.priorityOutboundTag)
                    putString(PREF_URLTEST_EXCLUDE, request.excludeOutboundTag)
                    putString(PREF_URLTEST_URL, request.url)
                    putInt(PREF_URLTEST_TIMEOUT, request.timeoutMillis)
                    putInt(PREF_URLTEST_CONCURRENCY, request.concurrency)
                    putInt(PREF_URLTEST_DEADLINE, request.deadlineMillis)
                }
                apply()
            }
        }
    }

    internal data class UrlTestRequest(
        val groupTag: String,
        val targetOutboundTag: String,
        val priorityOutboundTag: String,
        val excludeOutboundTag: String,
        val url: String,
        val timeoutMillis: Int,
        val concurrency: Int,
        val deadlineMillis: Int,
    ) {
        companion object {
            fun fromArguments(arguments: Map<*, *>): UrlTestRequest? {
                fun text(key: String): String =
                    arguments[key]?.toString()?.trim()?.take(MAX_TEXT_LENGTH).orEmpty()
                fun tag(key: String): String = arguments[key]?.toString()?.trim().orEmpty()
                fun number(key: String, fallback: Int): Int =
                    (arguments[key] as? Number)?.toInt()?.takeIf { it > 0 } ?: fallback

                val target = tag("targetOutboundTag")
                val url = text("url")
                // Flutter also sends probe settings while disconnected. Keep
                // those settings even though there is no active target yet.
                if (url.isEmpty()) {
                    return null
                }
                val timeout = number("timeoutMillis", 15_000).coerceIn(1_000, 30_000)
                return UrlTestRequest(
                    groupTag = tag("groupTag").ifEmpty { "select" },
                    targetOutboundTag = target,
                    priorityOutboundTag = tag("priorityOutboundTag").ifEmpty { target },
                    excludeOutboundTag = tag("excludeOutboundTag"),
                    url = url,
                    timeoutMillis = timeout,
                    concurrency = number("concurrency", 1).coerceIn(1, 4),
                    deadlineMillis = number("deadlineMillis", timeout + 5_000)
                        .coerceIn(timeout, 35_000),
                )
            }
        }
    }

    private data class Presentation(
        val detailed: Boolean = true,
        val trafficDisplayMode: String = notificationTrafficModeSpeed,
        val trafficRefreshSeconds: Int = DEFAULT_TRAFFIC_REFRESH_SECONDS,
        val title: String = "",
        val latencyMillis: Long? = null,
        val connectedText: String = "VPN подключён",
        val checkingText: String = "...",
        val unavailableText: String = "Пинг недоступен",
        val totalLabel: String = "Всего трафика",
        val refreshLabel: String = "Проверить пинг",
        val stopLabel: String = "Остановить",
        val urlTestRequest: UrlTestRequest? = null,
    ) {
        companion object {
            fun fromArguments(arguments: Map<*, *>): Presentation {
                fun text(key: String, fallback: String): String =
                    arguments[key]?.toString()?.trim()?.take(MAX_TEXT_LENGTH)?.ifEmpty { fallback }
                        ?: fallback
                return Presentation(
                    detailed = arguments["detailed"] as? Boolean ?: true,
                    trafficDisplayMode = when (arguments["trafficDisplayMode"]?.toString()) {
                        notificationTrafficModeTotal -> notificationTrafficModeTotal
                        notificationTrafficModeBoth -> notificationTrafficModeBoth
                        else -> notificationTrafficModeSpeed
                    },
                    trafficRefreshSeconds = (arguments["trafficRefreshSeconds"] as? Number)?.toInt()
                        ?.coerceIn(1, 10) ?: DEFAULT_TRAFFIC_REFRESH_SECONDS,
                    title = text("title", ""),
                    latencyMillis = (arguments["latencyMillis"] as? Number)?.toLong()?.takeIf { it >= 0L },
                    connectedText = text("connectedText", "VPN подключён"),
                    checkingText = text("checkingText", "..."),
                    unavailableText = text("unavailableText", "Пинг недоступен"),
                    totalLabel = text("totalLabel", "Всего трафика"),
                    refreshLabel = text("refreshLabel", "Проверить пинг"),
                    stopLabel = text("stopLabel", "Остановить"),
                    urlTestRequest = UrlTestRequest.fromArguments(arguments),
                )
            }
        }
    }

    private val notificationManager =
        service.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val presentationPrefs = service.getSharedPreferences(
        PRESENTATION_PREFS,
        Context.MODE_PRIVATE,
    )

    private var foregroundStarted = false
    private var notificationGeneration = 0L
    private var lifecycleStatus = "Starting"
    private var presentation = restorePresentation()
    private var uplinkTotal = 0L
    private var downlinkTotal = 0L
    private var trafficAvailable = false
    private var displayedUplink = 0L
    private var displayedDownlink = 0L
    private val trafficRateWindow = NotificationTrafficRateWindow()
    private var refreshPending = false
    private var latencyChecking = false
    private var latencyActionGeneration = 0L
    private var latencyActionStartedAtSeconds = 0L
    private var latencyActionInFlight = false
    private var measurementNotBeforeSeconds = 0L
    private var latencyTimeoutRunnable: Runnable? = null
    private data class Outbound(
        val type: String,
        val members: List<String>,
        val defaultTag: String,
    )
    private var configuredOutbounds: Map<String, Outbound>? = null
    private var rootOutboundTag = "select"
    private var selectedOutbounds: Map<String, String> = emptyMap()
    private var selectedOutboundsReady = false
    private var startupRuntimeGeneration = 0L
    private var startupNetworkGeneration = 0L
    private var tileStartup = false
    private var startupMeasurementFinished = false
    @Volatile private var selectionEpoch = 0L
    val currentSelectionEpoch: Long get() = selectionEpoch
    private var nativeStartupToken: Long? = null
    private data class ClientStartupRequest(
        val id: Long, val runtime: Long, val network: Long,
        val group: String, val target: String, val included: List<String>, val excluded: String,
        var ownershipToken: Long? = null,
        val logicalSessionId: String = "",
    )
    private var clientStartupRequest: ClientStartupRequest? = null
    private var clientRequestSequence = 0L
    private val startupOwnership = StartupLatencyOwnership()

    fun buildForForeground(status: String): Notification {
        synchronized(this) {
            if (status != lifecycleStatus && status in setOf("Starting", "Restarting", "Reloading")) {
                configuredOutbounds = null
                selectedOutbounds = emptyMap()
                selectedOutboundsReady = false
                clientStartupRequest = null
            }
            if (status == "Connected" && lifecycleStatus != "Connected") {
                restoreCurrentPingTarget()
            }
            lifecycleStatus = status
            if (status in setOf("Starting", "Restarting", "Reloading", "Stopping")) {
                startupRuntimeGeneration = 0L
                startupOwnership.update(0L, startupNetworkGeneration, "", false, tileStartup)
            }
            if (!foregroundStarted) {
                notificationGeneration++
                trafficRateWindow.reset()
                displayedUplink = 0L
                displayedDownlink = 0L
            }
            foregroundStarted = true
            ensureChannel()
            return buildNotification()
        }
    }

    fun updatePresentation(arguments: Map<*, *>): Boolean {
        synchronized(this) {
            val previous = presentation
            val incoming = Presentation.fromArguments(arguments)
            if (foregroundStarted && lifecycleStatus == "Connected") {
                val oldTarget = previous.urlTestRequest?.targetOutboundTag.orEmpty()
                val nativeTarget = resolveCurrentPingTarget()
                val target = if (selectedOutboundsReady || incoming.urlTestRequest?.targetOutboundTag.isNullOrEmpty())
                    nativeTarget else incoming.urlTestRequest.targetOutboundTag
                val request = (incoming.urlTestRequest ?: previous.urlTestRequest)?.copy(
                    targetOutboundTag = target, priorityOutboundTag = target, excludeOutboundTag = "",
                )
                presentation = incoming.copy(
                    urlTestRequest = request,
                    latencyMillis = incoming.latencyMillis ?: previous.latencyMillis.takeIf { target == oldTarget },
                )
                // UI attachment commonly has no runtime target yet. It changes
                // labels/settings, not the native leaf's in-flight ownership.
                if (target != oldTarget || request == null) setPingTarget(target, clearMeasurement = true)
                updateStartupContext()
            } else {
                presentation = incoming
            }
            persistPresentation(presentation)
            trafficRateWindow.requestImmediateEmission()
            if (!latencyChecking) {
                // Flutter delivers the last known successful result on every
                // selected-outbound update. Do not leave an old action result
                // visible after a real selection change.
                latencyActionInFlight = false
            }
            refreshLocked()
        }
        return true
    }

    @Suppress("UNUSED_PARAMETER")
    fun updateTraffic(
        uplink: Long,
        downlink: Long,
        uplinkTotal: Long,
        downlinkTotal: Long,
        trafficAvailable: Boolean,
    ) {
        synchronized(this) {
            this.uplinkTotal = uplinkTotal
            this.downlinkTotal = downlinkTotal
            this.trafficAvailable = trafficAvailable
            val rate = trafficRateWindow.update(
                uplinkTotal = uplinkTotal,
                downlinkTotal = downlinkTotal,
                trafficAvailable = trafficAvailable,
                nowMillis = SystemClock.elapsedRealtime(),
                refreshIntervalMillis = presentation.trafficRefreshSeconds * 1_000L,
            )
            if (rate != null) {
                displayedUplink = rate.uplinkBytesPerSecond
                displayedDownlink = rate.downlinkBytesPerSecond
                refreshLocked()
            }
        }
    }

    fun stopAndClear() {
        stopPublishing()
        synchronized(this) {
            presentation = presentation.copy(latencyMillis = null)
        }
        clearPersistedState(service, notificationId)
    }

    fun stopPublishing() {
        val timeoutCallback = synchronized(this) { deactivateLocked() }
        if (timeoutCallback != null) {
            mainHandler.removeCallbacks(timeoutCallback)
        }
    }

    private fun deactivateLocked(): Runnable? {
        foregroundStarted = false
        notificationGeneration++
        refreshPending = false
        latencyChecking = false
        latencyActionInFlight = false
        latencyActionGeneration++
        startupRuntimeGeneration = 0L
        startupOwnership.update(0L, 0L, "", false, false)
        val pendingTimeout = latencyTimeoutRunnable
        latencyTimeoutRunnable = null
        uplinkTotal = 0L
        downlinkTotal = 0L
        trafficAvailable = false
        displayedUplink = 0L
        displayedDownlink = 0L
        trafficRateWindow.reset()
        return pendingTimeout
    }

    fun onUrlTestResult(
        tag: String?,
        delayMillis: Long,
        timeSeconds: Long,
        status: String?,
        runtimeGeneration: Long? = null,
        networkGeneration: Long? = null,
        measuredAtMillis: Long = timeSeconds * 1_000L,
        revision: Long = 0L,
        sessionId: Long = 0L,
        error: String = "",
        selectionEpoch: Long? = null,
    ) {
        val normalizedTag = tag?.trim().orEmpty()
        synchronized(this) {
            val request = presentation.urlTestRequest ?: return
            if (runtimeGeneration != null && runtimeGeneration != startupRuntimeGeneration) return
            if (networkGeneration != null && networkGeneration != startupNetworkGeneration) return
            if (selectionEpoch != null && selectionEpoch != this.selectionEpoch) return
            // Legacy group timestamps have only second precision and cannot
            // distinguish A -> B -> A. Only attributed deltas may repaint
            // after an authoritative selected leaf has changed.
            if (selectionEpoch == null && this.selectionEpoch > 0L) return
            if (!foregroundStarted || lifecycleStatus != "Connected" || normalizedTag != request.targetOutboundTag) {
                return
            }
            val actionStartedAtSeconds = if (latencyActionInFlight) latencyActionStartedAtSeconds else measurementNotBeforeSeconds
            // Cached group snapshots are often delivered immediately after an
            // Activity reattaches. Do not paint one as the answer to a fresh
            // notification action; the core timestamp must be newer than the
            // tap that started this targeted URLTest.
            if (timeSeconds <= 0L || timeSeconds < actionStartedAtSeconds) {
                return
            }
            val attributed = runtimeGeneration != null && networkGeneration != null && revision > 0L && sessionId > 0L
            if (nativeStartupToken == null || attributed) {
                latencyActionInFlight = false
                latencyChecking = false
                latencyTimeoutRunnable?.let(mainHandler::removeCallbacks)
                latencyTimeoutRunnable = null
            }
            presentation = presentation.copy(
                latencyMillis = delayMillis.takeIf { it > 0L },
            )
            // CommandGroup snapshots have no request identity/revision. They
            // may repaint, but only a real attributed delta can own startup.
            if (attributed) {
                startupOwnership.clientRequest(true)
                if (startupOwnership.complete(
                startupRuntimeGeneration, startupNetworkGeneration, normalizedTag,
                delayMillis.takeIf { it > 0L }, measuredAtMillis, status.orEmpty(), revision, sessionId, error,
                selectionEpoch ?: this.selectionEpoch,
                )) startupMeasurementFinished = true
                clientStartupRequest = null
            }
            persistPresentation(presentation)
            refreshLocked()
        }
    }

    fun requestLatencyRefresh(startup: Boolean = false): Boolean {
        val request: UrlTestRequest
        val actionGeneration: Long
        val timeoutCallback: Runnable
        synchronized(this) {
            request = presentation.urlTestRequest ?: return false
            if (request.targetOutboundTag.isEmpty() || lifecycleStatus != "Connected" || latencyActionInFlight) {
                return false
            }
            latencyActionInFlight = true
            latencyChecking = true
            if (!startup) nativeStartupToken = null
            actionGeneration = ++latencyActionGeneration
            latencyActionStartedAtSeconds = System.currentTimeMillis() / 1_000L
            latencyTimeoutRunnable?.let(mainHandler::removeCallbacks)
            timeoutCallback = Runnable { completeLatencyAction(actionGeneration, null) }
            latencyTimeoutRunnable = timeoutCallback
            refreshLocked()
        }
        mainHandler.postDelayed(
            timeoutCallback,
            max(request.deadlineMillis.toLong(), DEFAULT_LATENCY_TIMEOUT_MS) + 1_000L,
        )
        val callback: (Result<Unit>) -> Unit = { result ->
            if (result.isFailure) completeLatencyAction(actionGeneration, null)
        }
        val runner = latencyTestRunner
        if (runner != null) {
            runner(request, !startup, callback)
        } else SingboxController.urlTest(
            groupTag = request.groupTag,
            targetOutboundTag = request.targetOutboundTag,
            priorityOutboundTag = request.priorityOutboundTag,
            excludeOutboundTag = request.excludeOutboundTag,
            url = request.url,
            timeoutMillis = request.timeoutMillis,
            concurrency = request.concurrency,
            deadlineMillis = request.deadlineMillis,
            force = !startup,
            notificationStartup = startup,
            notificationStartupToken = if (startup) nativeStartupToken ?: 0L else 0L,
            callback = callback,
        )
        return true
    }

    private fun completeLatencyAction(
        actionGeneration: Long,
        latencyMillis: Long?,
    ) {
        synchronized(this) {
            if (!latencyActionInFlight || latencyActionGeneration != actionGeneration) {
                return
            }
            latencyActionInFlight = false
            latencyChecking = false
            nativeStartupToken?.let { token ->
                // Dispatch failure and no-result deadline both release the
                // lease without inventing a core measurement. Later client
                // work may join the original non-force core request safely.
                startupOwnership.nativeFailed(token)
                startupMeasurementFinished = true
            }
            nativeStartupToken = null
            latencyTimeoutRunnable?.let(mainHandler::removeCallbacks)
            latencyTimeoutRunnable = null
            if (latencyMillis != null) {
                presentation = presentation.copy(latencyMillis = latencyMillis)
                persistPresentation(presentation)
            }
            refreshLocked()
        }
    }

    private fun restorePresentation(): Presentation {
        fun text(key: String, fallback: String): String =
            presentationPrefs.getString(key, fallback)
                ?.trim()
                ?.take(MAX_TEXT_LENGTH)
                ?.ifEmpty { fallback }
                ?: fallback
        fun value(key: String, fallback: Int): Int =
            presentationPrefs.getInt(key, fallback)
        fun tag(key: String, fallback: String): String =
            presentationPrefs.getString(key, fallback)?.trim()?.ifEmpty { fallback } ?: fallback

        val target = tag(PREF_URLTEST_TARGET, "")
        val url = text(PREF_URLTEST_URL, "")
        val request = if (url.isEmpty()) {
            null
        } else {
            val timeout = value(PREF_URLTEST_TIMEOUT, 15_000).coerceIn(1_000, 30_000)
            UrlTestRequest(
                groupTag = tag(PREF_URLTEST_GROUP, "select"),
                targetOutboundTag = target,
                priorityOutboundTag = tag(PREF_URLTEST_PRIORITY, target),
                excludeOutboundTag = tag(PREF_URLTEST_EXCLUDE, ""),
                url = url,
                timeoutMillis = timeout,
                concurrency = value(PREF_URLTEST_CONCURRENCY, 1).coerceIn(1, 4),
                deadlineMillis = value(PREF_URLTEST_DEADLINE, timeout + 5_000)
                    .coerceIn(timeout, 35_000),
            )
        }
        return Presentation(
            detailed = presentationPrefs.getBoolean(PREF_DETAILED, true),
            trafficDisplayMode = when (text(PREF_TRAFFIC_DISPLAY_MODE, notificationTrafficModeSpeed)) {
                notificationTrafficModeTotal -> notificationTrafficModeTotal
                notificationTrafficModeBoth -> notificationTrafficModeBoth
                else -> notificationTrafficModeSpeed
            },
            trafficRefreshSeconds = value(
                PREF_TRAFFIC_REFRESH_SECONDS,
                DEFAULT_TRAFFIC_REFRESH_SECONDS,
            ).coerceIn(1, 10),
            title = text(PREF_TITLE, ""),
            latencyMillis = if (presentationPrefs.contains(PREF_LATENCY)) {
                presentationPrefs.getLong(PREF_LATENCY, -1L).takeIf { it >= 0L }
            } else {
                null
            },
            connectedText = text(PREF_CONNECTED_TEXT, "VPN подключён"),
            checkingText = text(PREF_CHECKING_TEXT, "..."),
            unavailableText = text(PREF_UNAVAILABLE_TEXT, "Пинг недоступен"),
            totalLabel = text(PREF_TOTAL_LABEL, "Всего трафика"),
            refreshLabel = text(PREF_REFRESH_LABEL, "Проверить пинг"),
            stopLabel = text(PREF_STOP_LABEL, "Остановить"),
            urlTestRequest = request,
        )
    }

    private fun persistPresentation(value: Presentation) {
        persistPresentation(service, value)
    }

    private fun restoreCurrentPingTarget() {
        if (configuredOutbounds == null) {
            val config = runCatching { JSONObject(MeowApplication.configFile.readText()) }.getOrNull()
            val outbounds = config?.optJSONArray("outbounds")
            val byTag = mutableMapOf<String, Outbound>()
            if (outbounds != null) for (index in 0 until outbounds.length()) {
                val outbound = outbounds.optJSONObject(index) ?: continue
                val members = outbound.optJSONArray("outbounds")
                byTag[outbound.optString("tag")] = Outbound(
                    type = outbound.optString("type"),
                    members = if (members == null) emptyList() else
                        (0 until members.length()).map { members.optString(it) },
                    defaultTag = outbound.optString("default"),
                )
            }
            // Retain only selection metadata, not credentials or the full JSON.
            configuredOutbounds = byTag
            rootOutboundTag = if (byTag.containsKey("select")) "select" else
                config?.optJSONObject("route")?.optString("final").orEmpty()
        }
        setPingTarget(resolveCurrentPingTarget(), clearMeasurement = true)
    }

    private fun resolveCurrentPingTarget(): String {
        var tag = rootOutboundTag
        val visited = mutableSetOf<String>()
        while (tag.isNotEmpty() && visited.add(tag)) {
            val outbound = configuredOutbounds?.get(tag) ?: break
            when (outbound.type) {
                "selector", "urltest" -> {
                    tag = selectedOutbounds[tag]?.takeIf { it in outbound.members }
                        ?: outbound.defaultTag.takeIf { it in outbound.members }
                        ?: outbound.members.firstOrNull().orEmpty()
                }
                "direct", "block", "dns", "" -> break
                else -> return tag
            }
        }
        return ""
    }

    private fun setPingTarget(target: String, clearMeasurement: Boolean): Boolean {
        val oldRequest = presentation.urlTestRequest
        if (!clearMeasurement && target == oldRequest?.targetOutboundTag.orEmpty()) return false
        val request = oldRequest?.copy(
            targetOutboundTag = target,
            priorityOutboundTag = target,
            excludeOutboundTag = "",
        ) ?: target.takeIf { it.isNotEmpty() }?.let {
            // Outbound tags are identifiers, not display labels. Abbreviating
            // a long provider tag would address a nonexistent core outbound.
            UrlTestRequest(
                groupTag = "select",
                targetOutboundTag = it,
                priorityOutboundTag = it,
                excludeOutboundTag = "",
                url = DEFAULT_PROBE_URL,
                timeoutMillis = 15_000,
                concurrency = 1,
                deadlineMillis = 20_000,
            )
        }
        // An outstanding action belongs to the previous outbound/network.
        latencyTimeoutRunnable?.let(mainHandler::removeCallbacks)
        latencyTimeoutRunnable = null
        latencyActionGeneration++
        latencyActionInFlight = false
        latencyChecking = false
        measurementNotBeforeSeconds = System.currentTimeMillis() / 1_000L
        presentation = presentation.copy(latencyMillis = null, urlTestRequest = request)
        persistPresentation(presentation)
        return true
    }

    fun updateSelectedOutbounds(selected: Map<String, String>, runtimeGeneration: Long? = null, networkGeneration: Long? = null, startProbe: Boolean = true) {
        synchronized(this) {
            if (!foregroundStarted || lifecycleStatus !in setOf("Connected", "Waiting for network")) return
            if (runtimeGeneration != null && runtimeGeneration != startupRuntimeGeneration) return
            if (networkGeneration != null && networkGeneration != startupNetworkGeneration) return
            val oldTarget = presentation.urlTestRequest?.targetOutboundTag.orEmpty()
            val wasReady = selectedOutboundsReady
            selectedOutbounds = selected.toMap()
            if (setPingTarget(resolveCurrentPingTarget(), clearMeasurement = false)) refreshLocked()
            if (wasReady && oldTarget != presentation.urlTestRequest?.targetOutboundTag.orEmpty()) selectionEpoch++
            selectedOutboundsReady = hasAuthoritativePingTarget()
            updateStartupContext()
            if (startProbe) onGroupsSnapshotReady()
        }
    }

    fun onRuntimeReady(runtimeGeneration: Long, networkGeneration: Long, tileStartup: Boolean) {
        synchronized(this) {
            if (runtimeGeneration != this.startupRuntimeGeneration) {
                startupMeasurementFinished = false
                selectionEpoch = 0L
                selectedOutboundsReady = false
            }
            this.startupRuntimeGeneration = runtimeGeneration
            this.startupNetworkGeneration = networkGeneration
            this.tileStartup = tileStartup
            updateStartupContext()
            requestStartupLatencyIfReady()
        }
    }

    fun onNetworkGenerationChanged(networkGeneration: Long) {
        synchronized(this) {
            if (networkGeneration == startupNetworkGeneration) return
            startupNetworkGeneration = networkGeneration
            selectedOutboundsReady = false
            setPingTarget(resolveCurrentPingTarget(), clearMeasurement = true)
            updateStartupContext()
            refreshLocked()
        }
    }

    private fun updateStartupContext() {
        startupOwnership.update(
            startupRuntimeGeneration, startupNetworkGeneration,
            presentation.urlTestRequest?.targetOutboundTag.orEmpty(),
            foregroundStarted && lifecycleStatus == "Connected" && selectedOutboundsReady,
            tileStartup,
            selectionEpoch,
        )
        clientStartupRequest?.takeIf {
            it.runtime == startupRuntimeGeneration && it.network == startupNetworkGeneration &&
                coversPingTarget(it.group, it.target, it.included, it.excluded)
        }?.let { it.ownershipToken = startupOwnership.clientRequest(true) }
    }

    private fun hasAuthoritativePingTarget(): Boolean {
        var tag = rootOutboundTag
        val visited = mutableSetOf<String>()
        while (tag.isNotEmpty() && visited.add(tag)) {
            val outbound = configuredOutbounds?.get(tag) ?: return false
            if (outbound.type !in setOf("selector", "urltest"))
                return outbound.type !in setOf("direct", "block", "dns", "")
            tag = selectedOutbounds[tag]?.takeIf { it in outbound.members } ?: return false
        }
        return false
    }

    private fun requestStartupLatencyIfReady() {
        if (startupMeasurementFinished || latencyActionInFlight) return
        if (selectedOutboundsReady && lifecycleStatus == "Connected") {
            val leaf = presentation.urlTestRequest?.targetOutboundTag.orEmpty()
            SingboxController.cachedNotificationLatency(leaf, startupRuntimeGeneration, startupNetworkGeneration, selectionEpoch)?.let {
                onUrlTestResult(it.tag, it.delay, it.measuredAtMillis / 1_000L, it.status,
                    it.runtime, it.network, it.measuredAtMillis, it.revision, it.sessionId, it.error, it.selection)
            }
            if (startupMeasurementFinished) return
        }
        val token = startupOwnership.claimNative() ?: return
        nativeStartupToken = token
        if (!requestLatencyRefresh(startup = true)) {
            startupOwnership.nativeFailed(token)
        }
    }

    fun onGroupsSnapshotReady() {
        synchronized(this) {
            requestStartupLatencyIfReady()
        }
    }

    fun prepareStartupUrlTest(runtimeGeneration: Long, tags: Set<String>, callback: (Map<String?, Any?>) -> Unit) {
        synchronized(this) {
            updateStartupContext()
            val networkGeneration = startupNetworkGeneration
            val requestedTarget = presentation.urlTestRequest?.targetOutboundTag.orEmpty()
            val requestedSelection = selectionEpoch
            var reservation: Long? = null
            var delivered = false
            fun deliver(borrowed: StartupLatencyOwnership.Measurement?, pendingTag: String = "") {
                val selectedSnapshot = selectedOutbounds.toMap()
                mainHandler.post {
                    if (delivered) return@post
                    delivered = true
                    callback(mapOf(
                        "valid" to (runtimeGeneration == startupRuntimeGeneration && networkGeneration == startupNetworkGeneration &&
                            requestedTarget == presentation.urlTestRequest?.targetOutboundTag.orEmpty() && requestedSelection == selectionEpoch),
                        "runtimeGeneration" to runtimeGeneration,
                        "networkGeneration" to networkGeneration,
                        "borrowedTag" to (borrowed?.tag ?: pendingTag),
                        "startupLeaseToken" to if (borrowed == null && pendingTag.isEmpty()) (reservation ?: 0L) else 0L,
                        "delayMillis" to borrowed?.delayMillis,
                        "measuredAtMillis" to borrowed?.measuredAtMillis,
                        "status" to borrowed?.status.orEmpty(),
                        "revision" to borrowed?.revision,
                        "sessionId" to borrowed?.sessionId,
                        "error" to borrowed?.error.orEmpty(),
                        "selectedOutbounds" to selectedSnapshot,
                    ))
                }
            }
            reservation = startupOwnership.prepareClient(runtimeGeneration, tags) { deliver(it) }
            if (reservation != null) mainHandler.postDelayed({
                synchronized(this) {
                    if (startupOwnership.expireReservation(reservation)) requestStartupLatencyIfReady()
                }
            }, 5_000L)
            // A client-owned manual/full session may outlive the notification
            // probe budget. Report ownership, not a fabricated measurement.
            val waitingTag = presentation.urlTestRequest?.targetOutboundTag.orEmpty()
            mainHandler.postDelayed({ deliver(null, waitingTag.takeIf { it in tags }.orEmpty()) }, 36_000L)
        }
    }

    fun onClientUrlTestRequested(group: String, target: String, included: List<String>, excluded: String,
        deadlineMillis: Int = 20_000, requestId: String = "",
    ): Long? {
        synchronized(this) {
            if (!tileStartup || startupRuntimeGeneration <= 0L ||
                (selectedOutboundsReady && !coversPingTarget(group, target, included, excluded))
            ) return null
            val request = ClientStartupRequest(
                ++clientRequestSequence, startupRuntimeGeneration, startupNetworkGeneration,
                group, target, included.toList(), excluded,
                startupOwnership.clientRequest(true),
                requestId,
            )
            clientStartupRequest = request
            mainHandler.postDelayed({
                synchronized(this) {
                    if (clientStartupRequest?.id != request.id) return@synchronized
                    request.ownershipToken?.let { token ->
                        if (startupOwnership.expireClient(token)) {
                            clientStartupRequest = null
                            // Non-force native refresh joins a still-capable
                            // full session; it does not create a parallel leaf.
                            requestStartupLatencyIfReady()
                        }
                    }
                }
            }, (if (deadlineMillis > 0) deadlineMillis.toLong() else 120_000L) + 1_000L)
            return request.id
        }
    }

    fun dispatchStartupUrlTest(token: Long, runtime: Long, network: Long, group: String, target: String,
        included: List<String>, excluded: String, deadlineMillis: Int, requestId: String,
    ): Long? {
        synchronized(this) {
            if (runtime != startupRuntimeGeneration || network != startupNetworkGeneration ||
                !coversPingTarget(group, target, included, excluded) || !startupOwnership.dispatchClient(token)
            ) return null
            return onClientUrlTestRequested(group, target, included, excluded, deadlineMillis, requestId)
        }
    }

    fun validateNativeStartup(token: Long, runtime: Long, network: Long, selection: Long): Boolean = synchronized(this) {
        runtime == startupRuntimeGeneration && network == startupNetworkGeneration &&
            selection == selectionEpoch && startupOwnership.dispatchNative(token)
    }

    fun onClientStartupSessionTerminal(requestId: String, runtime: Long, network: Long) {
        synchronized(this) {
            val request = clientStartupRequest?.takeIf {
                requestId.isNotEmpty() && it.logicalSessionId == requestId && it.runtime == runtime && it.network == network
            } ?: return
            request.ownershipToken?.let { token ->
                if (startupOwnership.expireClient(token)) {
                    clientStartupRequest = null
                    requestStartupLatencyIfReady()
                }
            }
        }
    }

    private fun coversPingTarget(group: String, target: String, included: List<String>, excluded: String): Boolean {
        val leaf = presentation.urlTestRequest?.targetOutboundTag.orEmpty()
        if (leaf.isEmpty() || excluded == leaf) return false
        if (target.isNotEmpty()) return target == leaf
        if (included.isNotEmpty()) return leaf in included
        val visited = mutableSetOf<String>()
        fun contains(tag: String): Boolean = tag == leaf ||
            (visited.add(tag) && configuredOutbounds?.get(tag)?.members.orEmpty().any(::contains))
        return contains(group)
    }

    fun onClientUrlTestDispatchFailed(token: Long) {
        synchronized(this) {
            val request = clientStartupRequest?.takeIf { it.id == token } ?: return
            clientStartupRequest = null
            request.ownershipToken?.let { if (startupOwnership.clientFailed(it)) requestStartupLatencyIfReady() }
        }
    }

    private fun ensureChannel() {
        val channel = NotificationChannel(
            if (service is MeowProbeService) PROBE_CHANNEL_ID else CHANNEL_ID,
            if (service is MeowProbeService) "Etonify: проверка серверов" else "Etonify VPN",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = if (service is MeowProbeService) {
                "Проверка доступности прокси-серверов"
            } else {
                "VPN connection status"
            }
            setShowBadge(false)
            setSound(null, null)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun refreshLocked() {
        if (!foregroundStarted || refreshPending) {
            return
        }
        // Several core events can arrive in one main-loop turn. Coalescing
        // them prevents Android from seeing a burst of foreground-notification
        // reposts, which can make an ongoing VPN notification jump around the
        // shade relative to navigation and media notifications.
        val queuedGeneration = notificationGeneration
        refreshPending = true
        mainHandler.post {
            synchronized(this) {
                if (
                    foregroundRefreshCanDeliver(
                        foregroundStarted = foregroundStarted,
                        queuedGeneration = queuedGeneration,
                        currentGeneration = notificationGeneration,
                    )
                ) {
                    refreshPending = false
                    notificationManager.notify(notificationId, buildNotification())
                }
            }
        }
    }

    private fun buildNotification(): Notification {
        val connected = lifecycleStatus == "Connected"
        val showDetails = connected && presentation.detailed
        val title = if (showDetails && presentation.title.isNotEmpty()) {
            presentation.title
        } else {
            "Etonify"
        }
        val content = when {
            !connected -> lifecycleStatusText(lifecycleStatus)
            !showDetails -> presentation.connectedText
            else -> detailedContent()
        }
        val channelId = if (service is MeowProbeService) PROBE_CHANNEL_ID else CHANNEL_ID
        val builder = Notification.Builder(service, channelId)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.drawable.ic_meow_status)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(contentIntent())

        if (showDetails) {
            // OEM notification layouts often collapse line breaks in
            // setContentText(). BigTextStyle preserves the dedicated totals
            // line when both current speed and total traffic are shown.
            builder.setStyle(Notification.BigTextStyle().bigText(content))
        }

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            foregroundPresentationNeedsImmediateDelivery(lifecycleStatus)
        ) {
            // IMMEDIATE is needed only while a new foreground service is
            // becoming visible. Reapplying it to the long-running Connected
            // notification asks Android to promote every traffic refresh.
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        if (showDetails && !presentation.urlTestRequest?.targetOutboundTag.isNullOrEmpty()) {
            builder.addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(service, android.R.drawable.ic_popup_sync),
                    presentation.refreshLabel,
                    notificationActionIntent(
                        MeowNotificationActionReceiver.ACTION_REFRESH_LATENCY,
                        ACTION_REFRESH_REQUEST_CODE,
                    ),
                ).build(),
            )
        }
        builder.addAction(
            Notification.Action.Builder(
                Icon.createWithResource(service, android.R.drawable.ic_menu_close_clear_cancel),
                presentation.stopLabel,
                // A receiver can stop an existing service without creating a
                // new one when Android delivers a stale notification action.
                notificationActionIntent(
                    MeowNotificationActionReceiver.ACTION_STOP_RUNTIME,
                    ACTION_STOP_REQUEST_CODE,
                ),
            ).build(),
        )
        return builder.build()
    }

    private fun detailedContent(): String {
        val speed = "↓ ${formatRate(displayedDownlink)}  ↑ ${formatRate(displayedUplink)}"
        val totals = "↓ ${formatBytes(downlinkTotal)}  ↑ ${formatBytes(uplinkTotal)}"
        val latency = when {
            latencyChecking -> presentation.checkingText
            presentation.latencyMillis != null -> "${presentation.latencyMillis} мс"
            else -> presentation.unavailableText
        }
        return notificationDetailedContent(
            trafficDisplayMode = presentation.trafficDisplayMode,
            speed = speed,
            totals = totals,
            totalLabel = presentation.totalLabel,
            latency = latency,
        )
    }

    private fun lifecycleStatusText(status: String): String = when (status) {
        "Starting" -> "Подключение…"
        "Restarting" -> "Перезапуск…"
        "Reloading" -> "Применение настроек…"
        "Waiting for network" -> "Ожидание сети…"
        "Stopping" -> "Отключение…"
        else -> status
    }

    private fun notificationActionIntent(action: String, requestCode: Int): PendingIntent =
        MeowNotificationActionReceiver.pendingIntent(service, action, requestCode)

    private fun contentIntent(): PendingIntent {
        val intent = Intent(service, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            service,
            CONTENT_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun formatBytes(bytes: Long): String {
        if (bytes <= 0L) return "0 Б"
        val units = arrayOf("Б", "КБ", "МБ", "ГБ", "ТБ")
        var value = bytes.toDouble()
        var index = 0
        while (value >= 1024.0 && index < units.lastIndex) {
            value /= 1024.0
            index++
        }
        val precision = when {
            value >= 100.0 || index == 0 -> 0
            value >= 10.0 -> 1
            else -> 2
        }
        return "%.${precision}f%s".format(java.util.Locale.US, value, units[index])
    }

    private fun formatRate(bytesPerSecond: Long): String =
        "${formatBytes(max(0L, bytesPerSecond))}/с"
}

/**
 * A foreground service needs immediate notification delivery only while it is
 * being created. Once connected, leave ordering and visual timing to Android
 * so Etonify's regular traffic refreshes do not compete with navigation or
 * media notifications.
 */
internal fun foregroundPresentationNeedsImmediateDelivery(status: String): Boolean =
    status == "Starting" || status == "Restarting"

internal fun foregroundRefreshCanDeliver(
    foregroundStarted: Boolean,
    queuedGeneration: Long,
    currentGeneration: Long,
): Boolean = foregroundStarted && queuedGeneration == currentGeneration

internal fun notificationDetailedContent(
    trafficDisplayMode: String,
    speed: String,
    totals: String,
    totalLabel: String,
    latency: String,
): String = when (trafficDisplayMode) {
    notificationTrafficModeTotal -> "$totalLabel: $totals  ·  $latency"
    notificationTrafficModeBoth -> "$speed  ·  $latency\n$totalLabel: $totals"
    else -> "$speed  ·  $latency"
}
