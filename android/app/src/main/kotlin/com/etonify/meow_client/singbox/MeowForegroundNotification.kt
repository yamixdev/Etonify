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
import com.etonify.meow_client.R
import com.etonify.meow_client.generated.notificationTrafficModeBoth
import com.etonify.meow_client.generated.notificationTrafficModeSpeed
import com.etonify.meow_client.generated.notificationTrafficModeTotal
import kotlin.math.max

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
) {
    companion object {
        const val CHANNEL_ID = "etonify_vpn_status"
        const val ACTION_REFRESH_LATENCY = "com.etonify.meow_client.singbox.REFRESH_LATENCY"

        private const val ACTION_REFRESH_REQUEST_CODE = 4201
        private const val ACTION_STOP_REQUEST_CODE = 4202
        private const val CONTENT_REQUEST_CODE = 4203
        private const val DEFAULT_LATENCY_TIMEOUT_MS = 20_000L
        private const val MAX_TEXT_LENGTH = 120
        private const val DEFAULT_TRAFFIC_REFRESH_SECONDS = 2
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
                .clear()
                .apply()
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(notificationId)
        }
    }

    private data class UrlTestRequest(
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
                fun number(key: String, fallback: Int): Int =
                    (arguments[key] as? Number)?.toInt()?.takeIf { it > 0 } ?: fallback

                val target = text("targetOutboundTag")
                val url = text("url")
                if (target.isEmpty() || url.isEmpty()) {
                    return null
                }
                val timeout = number("timeoutMillis", 15_000).coerceIn(1_000, 30_000)
                return UrlTestRequest(
                    groupTag = text("groupTag").ifEmpty { "select" },
                    targetOutboundTag = target,
                    priorityOutboundTag = text("priorityOutboundTag").ifEmpty { target },
                    excludeOutboundTag = text("excludeOutboundTag"),
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
    )

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
    private var latencyActionInFlight = false
    private var latencyTimeoutRunnable: Runnable? = null

    fun buildForForeground(status: String): Notification {
        synchronized(this) {
            lifecycleStatus = status
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
            fun text(key: String, fallback: String): String =
                arguments[key]?.toString()?.trim()?.take(MAX_TEXT_LENGTH)?.ifEmpty { fallback }
                    ?: fallback

            val detailed = arguments["detailed"] as? Boolean ?: true
            val trafficDisplayMode = when (arguments["trafficDisplayMode"]?.toString()) {
                notificationTrafficModeTotal -> notificationTrafficModeTotal
                notificationTrafficModeBoth -> notificationTrafficModeBoth
                else -> notificationTrafficModeSpeed
            }
            val trafficRefreshSeconds =
                (arguments["trafficRefreshSeconds"] as? Number)?.toInt()
                    ?.coerceIn(1, 10)
                    ?: DEFAULT_TRAFFIC_REFRESH_SECONDS
            val latency = (arguments["latencyMillis"] as? Number)?.toLong()?.takeIf { it >= 0L }
            presentation = Presentation(
                detailed = detailed,
                trafficDisplayMode = trafficDisplayMode,
                trafficRefreshSeconds = trafficRefreshSeconds,
                title = text("title", ""),
                latencyMillis = latency,
                connectedText = text("connectedText", "VPN подключён"),
                checkingText = text("checkingText", "..."),
                unavailableText = text("unavailableText", "Пинг недоступен"),
                totalLabel = text("totalLabel", "Всего трафика"),
                refreshLabel = text("refreshLabel", "Проверить пинг"),
                stopLabel = text("stopLabel", "Остановить"),
                urlTestRequest = UrlTestRequest.fromArguments(arguments),
            )
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
            presentation = Presentation()
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
    ) {
        val normalizedTag = tag?.trim().orEmpty()
        synchronized(this) {
            val request = presentation.urlTestRequest ?: return
            if (!latencyActionInFlight || normalizedTag != request.targetOutboundTag) {
                return
            }
            val actionStartedAtSeconds = latencyActionGeneration
            // Cached group snapshots are often delivered immediately after an
            // Activity reattaches. Do not paint one as the answer to a fresh
            // notification action; the core timestamp must be newer than the
            // tap that started this targeted URLTest.
            if (timeSeconds <= 0L || timeSeconds < actionStartedAtSeconds) {
                return
            }
            latencyActionInFlight = false
            latencyChecking = false
            latencyTimeoutRunnable?.let(mainHandler::removeCallbacks)
            latencyTimeoutRunnable = null
            presentation = presentation.copy(
                latencyMillis = delayMillis.takeIf { it > 0L },
            )
            persistPresentation(presentation)
            refreshLocked()
        }
    }

    fun requestLatencyRefresh(): Boolean {
        val request: UrlTestRequest
        val actionGeneration: Long
        val timeoutCallback: Runnable
        synchronized(this) {
            request = presentation.urlTestRequest ?: return false
            if (lifecycleStatus != "Connected" || latencyActionInFlight) {
                return false
            }
            latencyActionInFlight = true
            latencyChecking = true
            actionGeneration = System.currentTimeMillis() / 1_000L
            latencyActionGeneration = actionGeneration
            latencyTimeoutRunnable?.let(mainHandler::removeCallbacks)
            timeoutCallback = Runnable { completeLatencyAction(actionGeneration, null) }
            latencyTimeoutRunnable = timeoutCallback
            refreshLocked()
        }
        mainHandler.postDelayed(
            timeoutCallback,
            max(request.deadlineMillis.toLong(), DEFAULT_LATENCY_TIMEOUT_MS) + 1_000L,
        )
        SingboxController.urlTest(
            groupTag = request.groupTag,
            targetOutboundTag = request.targetOutboundTag,
            priorityOutboundTag = request.priorityOutboundTag,
            excludeOutboundTag = request.excludeOutboundTag,
            url = request.url,
            timeoutMillis = request.timeoutMillis,
            concurrency = request.concurrency,
            deadlineMillis = request.deadlineMillis,
            force = true,
        ) { result ->
            if (result.isFailure) {
                completeLatencyAction(actionGeneration, null)
            }
        }
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

        val target = text(PREF_URLTEST_TARGET, "")
        val url = text(PREF_URLTEST_URL, "")
        val request = if (target.isEmpty() || url.isEmpty()) {
            null
        } else {
            val timeout = value(PREF_URLTEST_TIMEOUT, 15_000).coerceIn(1_000, 30_000)
            UrlTestRequest(
                groupTag = text(PREF_URLTEST_GROUP, "select"),
                targetOutboundTag = target,
                priorityOutboundTag = text(PREF_URLTEST_PRIORITY, target),
                excludeOutboundTag = text(PREF_URLTEST_EXCLUDE, ""),
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
        val request = value.urlTestRequest
        presentationPrefs.edit().apply {
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
            if (value.latencyMillis == null) {
                remove(PREF_LATENCY)
            } else {
                putLong(PREF_LATENCY, value.latencyMillis)
            }
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

    private fun ensureChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Etonify VPN",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "VPN connection status"
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
        val builder = Notification.Builder(service, CHANNEL_ID)
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
        if (showDetails && presentation.urlTestRequest != null) {
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
