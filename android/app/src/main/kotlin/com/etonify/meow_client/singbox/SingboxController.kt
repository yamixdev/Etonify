package com.etonify.meow_client.singbox

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.etonify.meow_client.MeowApplication
import io.flutter.plugin.common.EventChannel
import io.nekohasekai.libbox.CommandClient
import io.nekohasekai.libbox.CommandClientHandler
import io.nekohasekai.libbox.CommandClientOptions
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LogEntry
import io.nekohasekai.libbox.LogIterator
import io.nekohasekai.libbox.OutboundGroupIterator
import io.nekohasekai.libbox.StatusMessage
import io.nekohasekai.libbox.StringIterator
import java.util.ArrayDeque
import java.util.concurrent.Executors
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

object SingboxController {
    private const val TAG = "MeowSingbox"
    private const val STATUS_EVENT_THROTTLE_MS = 1_000L
    private const val GROUPS_EVENT_THROTTLE_COOL_MS = 1_500L
    private const val GROUPS_EVENT_THROTTLE_BALANCED_MS = 750L
    private const val GROUPS_EVENT_THROTTLE_PERFORMANCE_MS = 500L
    private const val GROUPS_DIAGNOSTIC_LOG_THROTTLE_MS = 2_000L
    private const val NO_INTERFACE_REASSERT_THROTTLE_MS = 2_000L
    private const val INTERFACE_DIAL_FAILURE_WINDOW_MS = 8_000L
    private const val INTERFACE_DIAL_FAILURE_THRESHOLD = 4
    private val INTERFACE_DIAL_FAILURE_REGEX =
        Regex(
            """\bdial\s+(?:ccmni|wlan|rmnet|swlan|eth|usb|ap)\w*\s*\(\d+\).*?\b(?:network is unreachable|no route to host)\b""",
            RegexOption.IGNORE_CASE,
        )
    private val mainHandler = Handler(Looper.getMainLooper())
    // Standalone clients still control one daemon/runtime. Keep command RPCs
    // on one lane: concurrent URLTest and selector clients can otherwise see
    // different runtime state and interfere with the active outbound.
    private val commandExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "MeowCommand").apply { isDaemon = true }
    }
    private val lookupExecutor = ThreadPoolExecutor(
        4,
        4,
        30L,
        TimeUnit.SECONDS,
        LinkedBlockingQueue(),
        { runnable -> Thread(runnable, "MeowLookup").apply { isDaemon = true } },
    ).apply {
        allowCoreThreadTimeOut(true)
    }
    private val statusEventScheduled = AtomicBoolean(false)
    private val groupsEventScheduled = AtomicBoolean(false)
    private val runtimeGeneration = AtomicLong(0)
    private val runtimeStartGeneration = AtomicLong(0)
    private val lastNoInterfaceReassertUptimeMs = AtomicLong(0L)
    private val interfaceFailureLock = Any()
    private val interfaceDialFailureUptimes = ArrayDeque<Long>()
    private val stopWaiterLock = Any()
    private val stopWaiters = mutableListOf<(Boolean) -> Unit>()

    private val eventSinkRegistry = RuntimeEventSinkRegistry<EventChannel.EventSink>()
    private val eventSink: EventChannel.EventSink?
        get() = eventSinkRegistry.current()
    @Volatile
    private var uiForeground = true
    @Volatile
    private var latestStatusPayload: Map<String, Any?>? = null
    @Volatile
    private var latestGroupsPayload: Map<String, Any?>? = null
    @Volatile
    private var lastEmittedStatusPayload: Map<String, Any?>? = null
    @Volatile
    private var lastEmittedGroupsPayload: Map<String, Any?>? = null
    private var lastStatusEventUptimeMs: Long = 0
    private var lastGroupsEventUptimeMs: Long = 0
    private var lastGroupsDiagnosticLogUptimeMs: Long = 0

    @Volatile
    var running: Boolean = false
        private set

    @Volatile
    var serviceMode: String = ""
        private set

    @Volatile
    var activeRuntimeGeneration: Long = 0
        private set

    @Volatile
    var uplink: Long = 0
        private set

    @Volatile
    var downlink: Long = 0
        private set

    @Volatile
    var uplinkTotal: Long = 0
        private set

    @Volatile
    var downlinkTotal: Long = 0
        private set

    /**
     * Latest lightweight runtime counters from the libbox status stream.
     * They are diagnostic data only: no polling is added on the Android side.
     */
    @Volatile
    var coreMemoryBytes: Long = 0
        private set

    @Volatile
    var coreGoroutines: Int = 0
        private set

    @Volatile
    var connectionsIn: Int = 0
        private set

    @Volatile
    var connectionsOut: Int = 0
        private set

    @Volatile
    private var trafficAvailable: Boolean = false

    @Volatile
    private var commandClient: CommandClient? = null
    private val commandClientLifecycle = CommandClientLifecycle()
    private val commandReconnectLock = Any()
    private var commandReconnectRunnable: Runnable? = null

    private fun createCommandClientHandler(epoch: Long) = object : CommandClientHandler {
        override fun connected() {
            handleCommandClientConnected(epoch)
        }

        override fun disconnected(message: String?) {
            handleCommandClientDisconnected(epoch, message)
        }

        override fun clearLogs() {
            if (!commandClientLifecycle.acceptsEvents(epoch)) return
            emit(mapOf("type" to "clearLogs"))
        }

        override fun initializeClashMode(modeList: StringIterator?, currentMode: String?) = Unit

        override fun setDefaultLogLevel(level: Int) {
            if (!commandClientLifecycle.acceptsEvents(epoch)) return
            emit(mapOf("type" to "logLevel", "level" to level))
        }

        override fun updateClashMode(newMode: String?) = Unit

        override fun writeConnectionEvents(events: io.nekohasekai.libbox.ConnectionEvents?) = Unit

        override fun writeGroups(message: OutboundGroupIterator?) {
            if (message == null || !commandClientLifecycle.acceptsEvents(epoch)) return
            val now = SystemClock.uptimeMillis()
            val groups = mutableListOf<Map<String, Any?>>()
            val selectedGroups = mutableListOf<String>()
            var itemCount = 0
            val uniqueItemTags = mutableSetOf<String>()
            var availableCount = 0
            var unavailableCount = 0
            var maxDelay = 0L
            var maxDelayTag = ""
            while (message.hasNext()) {
                val group = message.next()
                val selected = group.selected
                if (!selected.isNullOrBlank()) {
                    selectedGroups += "${group.tag}=$selected"
                }
                val items = mutableListOf<GroupItemPayload>()
                val iterator = group.items
                while (iterator.hasNext()) {
                    val item = iterator.next()
                    val delay = item.urlTestDelay
                    val time = item.urlTestTime
                    val status = item.urlTestStatus
                    val error = item.urlTestError
                    val errorCode = item.urlTestErrorCode
                    if (delay <= 0L &&
                        time <= 0L &&
                        status.isNullOrBlank() &&
                        error.isNullOrBlank() &&
                        errorCode.isNullOrBlank()
                    ) {
                        continue
                    }
                    itemCount++
                    item.tag?.takeIf { it.isNotBlank() }?.let(uniqueItemTags::add)
                    if (delay > 0L) {
                        availableCount++
                        if (delay > maxDelay) {
                            maxDelay = delay.toLong()
                            maxDelayTag = item.tag.orEmpty()
                        }
                    }
                    if ((status ?: "").equals("unavailable", ignoreCase = true)) {
                        unavailableCount++
                    }
                    items += GroupItemPayload(
                        tag = item.tag,
                        type = item.type,
                        delay = delay.toLong(),
                        time = time,
                        status = status,
                        error = error,
                        errorCode = errorCode,
                    )
                    // A notification action can outlive Flutter's event sink.
                    // Feed its targeted URLTest from the same native stream that
                    // backs the proxy list, never from a synthetic TCP probe.
                    MeowBoxService.publishNotificationUrlTestResult(
                        tag = item.tag,
                        delayMillis = delay.toLong(),
                        timeSeconds = time,
                        status = status,
                    )
                }
                groups += mapOf(
                    "tag" to group.tag,
                    "type" to group.type,
                    "selectable" to group.selectable,
                    "selected" to group.selected,
                    "expanded" to group.isExpand,
                    "items" to limitedGroupItems(group.tag, group.selected, items),
                )
            }
            if (itemCount > 0 && now - lastGroupsDiagnosticLogUptimeMs >= GROUPS_DIAGNOSTIC_LOG_THROTTLE_MS) {
                lastGroupsDiagnosticLogUptimeMs = now
                val summary =
                    "urltest_groups_event groups=${groups.size} memberships=$itemCount " +
                        "uniqueTags=${uniqueItemTags.size} " +
                        "available=$availableCount unavailable=$unavailableCount " +
                        "maxDelayMs=$maxDelay maxDelayTag=$maxDelayTag " +
                        "selected=${selectedGroups.take(6).joinToString(",")}"
                MeowDiagnostics.log(TAG, summary)
                if (maxDelay >= 1000L) {
                    log("warning", "urltest_high_delay $summary")
                }
            }
            emitCoalescedGroups(
                mapOf(
                    "type" to "groups",
                    "groups" to groups,
                    "runtimeGeneration" to activeRuntimeGeneration,
                ),
            )
        }

        override fun writeLogs(messageList: LogIterator?) {
            if (messageList == null || !commandClientLifecycle.acceptsEvents(epoch)) return
            val logs = mutableListOf<Map<String, Any?>>()
            while (messageList.hasNext()) {
                val entry: LogEntry = messageList.next()
                val message = entry.message ?: ""
                maybeReassertDefaultInterfaceFromCoreLog(message)
                logs += mapOf(
                    "level" to entry.level,
                    "message" to message,
                )
                // Debug/info streams are already forwarded to Flutter. Persisting
                // every DNS/connection line caused heavy synchronous file I/O and
                // retained browsing details in exported diagnostics.
                if (entry.level <= 3) {
                    MeowDiagnostics.log(TAG, "libbox log level=${entry.level} message=$message")
                }
            }
            emit(mapOf("type" to "logs", "logs" to logs))
        }

        override fun writeStatus(message: StatusMessage?) {
            if (message == null || !commandClientLifecycle.acceptsEvents(epoch)) return
            uplink = message.uplink
            downlink = message.downlink
            uplinkTotal = message.uplinkTotal
            downlinkTotal = message.downlinkTotal
            coreMemoryBytes = message.memory
            coreGoroutines = message.goroutines.toInt()
            connectionsIn = message.connectionsIn.toInt()
            connectionsOut = message.connectionsOut.toInt()
            // Some libbox builds briefly report trafficAvailable=false while
            // their cumulative counters are already populated. Treat a
            // non-zero rate or total as authoritative so the foreground
            // notification never regresses to an empty traffic state.
            trafficAvailable = message.trafficAvailable ||
                uplink > 0L ||
                downlink > 0L ||
                uplinkTotal > 0L ||
                downlinkTotal > 0L
            MeowBoxService.publishNotificationTraffic(
                uplink = uplink,
                downlink = downlink,
                uplinkTotal = uplinkTotal,
                downlinkTotal = downlinkTotal,
                trafficAvailable = trafficAvailable,
            )
            emitCoalescedStatus(
                mapOf(
                    "type" to "status",
                    "uplink" to uplink,
                    "downlink" to downlink,
                    "uplinkTotal" to uplinkTotal,
                    "downlinkTotal" to downlinkTotal,
                    "coreMemoryBytes" to coreMemoryBytes,
                    "coreGoroutines" to coreGoroutines,
                    "connectionsIn" to connectionsIn,
                    "connectionsOut" to connectionsOut,
                    "trafficAvailable" to trafficAvailable,
                ),
            )
        }
    }

    private data class GroupItemPayload(
        val tag: String?,
        val type: String?,
        val delay: Long,
        val time: Long,
        val status: String?,
        val error: String?,
        val errorCode: String?,
    ) {
        fun toEventMap(): Map<String, Any?> = mapOf(
            "tag" to tag,
            "type" to type,
            "delay" to delay,
            "time" to time,
            "status" to status,
            "error" to error,
            "errorCode" to errorCode,
        )
    }

    private fun limitedGroupItems(
        groupTag: String?,
        selectedTag: String?,
        items: List<GroupItemPayload>,
    ): List<Map<String, Any?>> {
        if (items.isEmpty()) {
            return emptyList()
        }
        val selected = selectedTag?.trim().orEmpty()
        val sorted = items.sortedWith(
            compareBy<GroupItemPayload> {
                if (it.tag == selected) 0 else 1
            }.thenBy {
                if (it.delay > 0L) 0 else 1
            }.thenBy {
                if ((it.status ?: "").equals("unavailable", ignoreCase = true)) 1 else 0
            }.thenBy {
                if (it.delay > 0L) it.delay else Long.MAX_VALUE
            }.thenByDescending {
                it.time
            },
        )
        return sorted.map { it.toEventMap() }
    }

    fun registerEventSink(sink: EventChannel.EventSink): Long {
        val registration = eventSinkRegistry.register(sink)
        // A fresh Flutter subscription is authoritative evidence that a UI
        // engine has been attached. The previous engine may have left this
        // flag false when its task was removed.
        uiForeground = true
        MeowDiagnostics.log(
            TAG,
            "runtime event sink attached registration=$registration running=$running",
        )
        emitCurrentState()
        emitCurrentStatus()
        emitCurrentGroups()
        if (running) {
            // Always enqueue reconciliation. CommandClientLifecycle suppresses
            // duplicates, while a queued disconnect from the old engine is
            // followed by this connect request instead of leaving diagnostics
            // permanently detached.
            connectClient()
        }
        return registration
    }

    fun clearEventSink(registration: Long) {
        if (!eventSinkRegistry.clear(registration)) {
            MeowDiagnostics.log(
                TAG,
                "runtime event sink detach ignored stale registration=$registration",
            )
            return
        }
        MeowDiagnostics.log(TAG, "runtime event sink detached registration=$registration")
        // The command stream is also the source of native foreground-service
        // telemetry. Do not stop it just because Flutter is detached: the VPN
        // notification must continue receiving traffic totals and a refresh
        // action must still be able to receive its URLTest result.
        if (running) {
            connectClient()
        } else {
            disconnectClient()
        }
    }

    fun setRunning(value: Boolean, mode: String = serviceMode, error: String? = null) {
        running = value
        serviceMode = if (value) mode else ""
        MeowDiagnostics.log(TAG, "setRunning value=$value mode=$serviceMode error=$error")
        if (!value) {
            uplink = 0
            downlink = 0
            uplinkTotal = 0
            downlinkTotal = 0
            coreMemoryBytes = 0
            coreGoroutines = 0
            connectionsIn = 0
            connectionsOut = 0
            trafficAvailable = false
        }
        emitCurrentState(error)
        emitCurrentStatus()
        if (value) {
            // Keep the native stream alive with the foreground VPN service.
            // Flutter may be paused or completely detached in the background.
            connectClient()
        } else {
            disconnectClient()
        }
    }

    fun setUiForeground(value: Boolean, registration: Long = 0L) {
        if (!eventSinkRegistry.canControl(registration)) {
            MeowDiagnostics.log(
                TAG,
                "ui foreground ignored stale registration=$registration value=$value",
            )
            return
        }
        val changed = uiForeground != value
        uiForeground = value
        MeowDiagnostics.log(
            TAG,
            "ui foreground=$value changed=$changed registration=$registration running=$running",
        )
        if (value && running && eventSink != null) {
            emitCurrentState()
            emitCurrentStatus()
            emitCurrentGroups()
        }
        if (running) {
            connectClient()
        }
    }

    fun markServiceStarted(mode: String): Long {
        val generation = runtimeGeneration.incrementAndGet()
        activeRuntimeGeneration = generation
        setRunning(true, mode)
        MeowDiagnostics.log(TAG, "markServiceStarted generation=$generation mode=$mode")
        return generation
    }

    fun nextStartToken(reason: String): Long {
        val token = runtimeStartGeneration.incrementAndGet()
        MeowDiagnostics.log(TAG, "nextStartToken token=$token reason=$reason")
        return token
    }

    fun cancelStartTokens(reason: String): Long {
        val token = runtimeStartGeneration.incrementAndGet()
        MeowDiagnostics.log(TAG, "cancelStartTokens token=$token reason=$reason")
        return token
    }

    fun isStartTokenCurrent(token: Long): Boolean = runtimeStartGeneration.get() == token

    fun markServiceStopped(generation: Long, reason: String) {
        val currentGeneration = activeRuntimeGeneration
        if (generation != 0L && generation != currentGeneration) {
            MeowDiagnostics.log(
                TAG,
                "markServiceStopped ignored stale generation=$generation current=$currentGeneration reason=$reason",
            )
            return
        }
        activeRuntimeGeneration = 0
        setRunning(false)
        MeowDiagnostics.log(TAG, "markServiceStopped generation=$generation reason=$reason")
        notifyStopWaiters(true)
    }

    fun forceMarkServiceStopped(reason: String) {
        val previousGeneration = activeRuntimeGeneration
        activeRuntimeGeneration = 0
        setRunning(false)
        MeowDiagnostics.log(
            TAG,
            "forceMarkServiceStopped previousGeneration=$previousGeneration reason=$reason",
        )
        notifyStopWaiters(true)
    }

    fun awaitStopped(timeoutMs: Long = 5_000L, callback: (Boolean) -> Unit) {
        if (!running) {
            mainHandler.post { callback(true) }
            return
        }
        var fired = false
        lateinit var waiter: (Boolean) -> Unit
        waiter = { success ->
            if (!fired) {
                fired = true
                callback(success)
            }
        }
        synchronized(stopWaiterLock) {
            stopWaiters += waiter
        }
        mainHandler.postDelayed({
            val removed = synchronized(stopWaiterLock) {
                stopWaiters.remove(waiter)
            }
            if (removed) {
                waiter(false)
            }
        }, timeoutMs)
    }

    private fun notifyStopWaiters(success: Boolean) {
        val waiters = synchronized(stopWaiterLock) {
            stopWaiters.toList().also { stopWaiters.clear() }
        }
        for (waiter in waiters) {
            mainHandler.post { waiter(success) }
        }
    }

    fun log(level: String, message: String) {
        val safeMessage = MeowLogSanitizer.redact(message)
        when (level.lowercase()) {
            "error" -> Log.e(TAG, safeMessage)
            "debug" -> Log.d(TAG, safeMessage)
            else -> Log.i(TAG, safeMessage)
        }
        MeowDiagnostics.log(TAG, "nativeLog level=$level message=$message")
        emit(mapOf("type" to "nativeLog", "level" to level, "message" to message))
    }

    private fun maybeReassertDefaultInterfaceFromCoreLog(message: String) {
        if (!running) return
        val reason = classifyCoreInterfaceFailure(message) ?: return
        val now = SystemClock.uptimeMillis()
        val failureCount = if (reason == "dial_interface_failure") {
            recordInterfaceDialFailure(now)
        } else {
            clearInterfaceDialFailures()
            1
        }
        if (reason == "dial_interface_failure" && failureCount < INTERFACE_DIAL_FAILURE_THRESHOLD) {
            return
        }
        val last = lastNoInterfaceReassertUptimeMs.get()
        if (now - last < NO_INTERFACE_REASSERT_THROTTLE_MS) return
        if (!lastNoInterfaceReassertUptimeMs.compareAndSet(last, now)) return
        val state = MeowDefaultNetworkMonitor.currentInterfaceState("core_$reason")
        val shortMessage = message.take(180)
        log(
            "warning",
            "core_interface_reassert reason=$reason interface=${state.interfaceName} " +
                "index=${state.interfaceIndex} generation=${state.generation} " +
                "failures=$failureCount message=$shortMessage",
        )
        MeowDefaultNetworkMonitor.reassertDefaultInterface("core_$reason")
    }

    private fun classifyCoreInterfaceFailure(message: String): String? {
        val lower = message.lowercase()
        if (lower.contains("no available network interface")) {
            return "no_available_interface"
        }
        if (lower.contains("no usable network interface") || lower.contains("error=no_interface")) {
            return "no_usable_interface"
        }
        if (INTERFACE_DIAL_FAILURE_REGEX.containsMatchIn(message)) {
            return "dial_interface_failure"
        }
        return null
    }

    private fun recordInterfaceDialFailure(now: Long): Int {
        synchronized(interfaceFailureLock) {
            interfaceDialFailureUptimes.addLast(now)
            while (interfaceDialFailureUptimes.isNotEmpty() &&
                now - interfaceDialFailureUptimes.first > INTERFACE_DIAL_FAILURE_WINDOW_MS
            ) {
                interfaceDialFailureUptimes.removeFirst()
            }
            val count = interfaceDialFailureUptimes.size
            if (count >= INTERFACE_DIAL_FAILURE_THRESHOLD) {
                interfaceDialFailureUptimes.clear()
            }
            return count
        }
    }

    private fun clearInterfaceDialFailures() {
        synchronized(interfaceFailureLock) {
            interfaceDialFailureUptimes.clear()
        }
    }

    // CommandStatus is consumed by the native foreground-service notification,
    // not only by Flutter. Its lifetime therefore follows the VPN runtime,
    // rather than Activity visibility or the EventChannel subscription.
    private fun shouldCommandClientBeConnected(): Boolean = running

    private fun handleCommandClientConnected(epoch: Long) {
        if (!commandClientLifecycle.onConnected(epoch)) {
            MeowDiagnostics.log(
                TAG,
                "command_stream_connected stale=true epoch=$epoch " +
                    "current=${commandClientLifecycle.currentEpoch()}",
            )
            return
        }
        if (!shouldCommandClientBeConnected()) {
            MeowDiagnostics.log(
                TAG,
                "command_stream_connected expected=false epoch=$epoch reason=not_desired",
            )
            disconnectClient()
            return
        }
        Log.i(TAG, "command client connected epoch=$epoch")
        MeowDiagnostics.log(TAG, "command_stream_connected epoch=$epoch")
        emit(mapOf("type" to "client", "connected" to true))
    }

    private fun handleCommandClientDisconnected(epoch: Long, message: String?) {
        val decision = commandClientLifecycle.onDisconnected(
            callbackEpoch = epoch,
            shouldConnect = shouldCommandClientBeConnected(),
        )
        when (decision.kind) {
            CommandDisconnectKind.STALE -> {
                MeowDiagnostics.log(
                    TAG,
                    "command_stream_disconnect stale=true epoch=$epoch " +
                        "current=${commandClientLifecycle.currentEpoch()}",
                )
            }
            CommandDisconnectKind.DUPLICATE -> {
                MeowDiagnostics.log(
                    TAG,
                    "command_stream_disconnect duplicate=true epoch=$epoch",
                )
            }
            CommandDisconnectKind.EXPECTED -> {
                if (commandClientLifecycle.isCurrent(epoch)) {
                    commandClient = null
                }
                Log.i(TAG, "command client disconnected expected=true epoch=$epoch")
                MeowDiagnostics.log(
                    TAG,
                    "command_stream_disconnect expected=true epoch=$epoch",
                )
                emit(
                    mapOf(
                        "type" to "client",
                        "connected" to false,
                        "expected" to true,
                    ),
                )
            }
            CommandDisconnectKind.UNEXPECTED -> {
                if (commandClientLifecycle.isCurrent(epoch)) {
                    commandClient = null
                }
                Log.w(TAG, "command client disconnected unexpected=true epoch=$epoch message=$message")
                MeowDiagnostics.log(
                    TAG,
                    "command_stream_disconnect unexpected=true epoch=$epoch error=${message.orEmpty()}",
                )
                // Do not forward EOF as a user-facing error. Flutter only needs
                // to know that diagnostics are recovering in the background.
                emit(
                    mapOf(
                        "type" to "client",
                        "connected" to false,
                        "recovering" to true,
                    ),
                )
                scheduleCommandClientReconnect(decision)
            }
        }
    }

    private fun scheduleCommandClientReconnect(decision: CommandDisconnectDecision) {
        if (!decision.scheduleReconnect) return
        lateinit var reconnect: Runnable
        reconnect = Runnable {
            val claimed = synchronized(commandReconnectLock) {
                if (commandReconnectRunnable !== reconnect) {
                    false
                } else {
                    commandReconnectRunnable = null
                    true
                }
            }
            if (!claimed) return@Runnable
            if (!commandClientLifecycle.claimReconnect(
                    callbackEpoch = decision.epoch,
                    shouldConnect = shouldCommandClientBeConnected(),
                )
            ) {
                MeowDiagnostics.log(
                    TAG,
                    "command_stream_reconnect cancelled=true epoch=${decision.epoch}",
                )
                return@Runnable
            }
            connectClient()
        }
        synchronized(commandReconnectLock) {
            commandReconnectRunnable?.let(mainHandler::removeCallbacks)
            commandReconnectRunnable = reconnect
        }
        MeowDiagnostics.log(
            TAG,
            "command_stream_reconnect attempt=${decision.reconnectAttempt} " +
                "delayMs=${decision.reconnectDelayMs} epoch=${decision.epoch}",
        )
        mainHandler.postDelayed(reconnect, decision.reconnectDelayMs)
    }

    private fun cancelCommandClientReconnect(reason: String) {
        val reconnect = synchronized(commandReconnectLock) {
            commandReconnectRunnable.also { commandReconnectRunnable = null }
        }
        if (reconnect != null) {
            mainHandler.removeCallbacks(reconnect)
            MeowDiagnostics.log(TAG, "command_stream_reconnect cancelled=true reason=$reason")
        }
        commandClientLifecycle.cancelReconnect()
    }

    fun connectClient() {
        commandExecutor.execute {
            val epoch = commandClientLifecycle.beginConnect(
                shouldConnect = shouldCommandClientBeConnected(),
            ) ?: return@execute
            var client: CommandClient? = null
            try {
                MeowApplication.ensureLibboxSetup()
                Log.i(TAG, "connecting command client epoch=$epoch")
                MeowDiagnostics.log(TAG, "command_stream_connecting epoch=$epoch")
                val options = CommandClientOptions().apply {
                    addCommand(Libbox.CommandGroup)
                    addCommand(Libbox.CommandLog)
                    addCommand(Libbox.CommandStatus)
                    // CommandClientOptions carries a Go time.Duration, i.e.
                    // nanoseconds, not milliseconds. Passing 1_000 here used
                    // to sample status every microsecond, so the byte delta was
                    // displayed as a one-second rate and severely understated
                    // notification traffic while burning needless CPU.
                    statusInterval = commandStatusIntervalNanos(MeowApplication.performanceMode)
                }
                client = Libbox.newCommandClient(createCommandClientHandler(epoch), options)
                commandClient = client
                client.connect()
            } catch (error: Throwable) {
                if (commandClientLifecycle.isCurrent(epoch) && commandClient === client) {
                    commandClient = null
                }
                val decision = commandClientLifecycle.onDisconnected(
                    callbackEpoch = epoch,
                    shouldConnect = shouldCommandClientBeConnected(),
                )
                Log.w(TAG, "command client connect failed epoch=$epoch", error)
                MeowDiagnostics.log(TAG, "command_stream_connect_failed epoch=$epoch", error)
                runCatching { client?.disconnect() }
                if (decision.kind == CommandDisconnectKind.UNEXPECTED) {
                    emit(
                        mapOf(
                            "type" to "client",
                            "connected" to false,
                            "recovering" to true,
                        ),
                    )
                    scheduleCommandClientReconnect(decision)
                }
            }
        }
    }

    fun disconnectClient() {
        cancelCommandClientReconnect("async_disconnect")
        commandExecutor.execute {
            disconnectClientOnExecutor("async")
        }
    }

    fun disconnectClientBlocking(timeoutMs: Long = 1_500L): Boolean {
        cancelCommandClientReconnect("blocking_disconnect")
        val latch = CountDownLatch(1)
        commandExecutor.execute {
            try {
                disconnectClientOnExecutor("blocking")
            } finally {
                latch.countDown()
            }
        }
        return runCatching { latch.await(timeoutMs, TimeUnit.MILLISECONDS) }
            .getOrDefault(false)
    }

    private fun disconnectClientOnExecutor(reason: String) {
        cancelCommandClientReconnect(reason)
        val disconnectEpoch = commandClientLifecycle.beginExpectedDisconnect()
        val client = commandClient
        commandClient = null
        if (client == null) {
            commandClientLifecycle.finishExpectedDisconnect(disconnectEpoch)
            return
        }
        Log.i(TAG, "disconnecting command client reason=$reason")
        MeowDiagnostics.log(TAG, "disconnecting command client reason=$reason")
        try {
            client.disconnect()
            MeowDiagnostics.log(
                TAG,
                "command_stream_disconnect expected=true reason=$reason epoch=$disconnectEpoch",
            )
        } catch (error: Throwable) {
            Log.w(TAG, "command client disconnect failed reason=$reason", error)
            MeowDiagnostics.log(TAG, "command client disconnect failed reason=$reason", error)
        } finally {
            commandClientLifecycle.finishExpectedDisconnect(disconnectEpoch)
            emit(
                mapOf(
                    "type" to "client",
                    "connected" to false,
                    "expected" to true,
                ),
            )
        }
    }

    private fun <T> withStandaloneCommandClient(block: (CommandClient) -> T): T {
        MeowApplication.ensureLibboxSetup()
        val client = Libbox.newStandaloneCommandClient()
        try {
            return block(client)
        } finally {
            runCatching { client.disconnect() }.onFailure {
                MeowDiagnostics.log(TAG, "standalone command client disconnect failed", it)
            }
        }
    }

    fun selectOutbound(groupTag: String, outboundTag: String, callback: (Result<Unit>) -> Unit) {
        log("info", "libbox selectOutbound group=$groupTag outbound=$outboundTag")
        val operationGeneration = activeRuntimeGeneration
        commandExecutor.execute {
            var result = runCatching {
                check(operationGeneration > 0L && operationGeneration == activeRuntimeGeneration && running) {
                    "stale runtime before select outbound"
                }
                withStandaloneCommandClient { client ->
                    client.selectOutbound(groupTag, outboundTag)
                }
            }
            if (result.isSuccess && operationGeneration != activeRuntimeGeneration) {
                result = Result.failure(IllegalStateException("stale runtime after select outbound"))
            }
            result.onFailure {
                log("error", "libbox selectOutbound failed group=$groupTag outbound=$outboundTag error=${it.message}")
            }
            mainHandler.post { callback(result.map { Unit }) }
        }
    }

    fun addOutbound(selectorTag: String, outboundJson: String, callback: (Result<Unit>) -> Unit) {
        val tag = runCatching { org.json.JSONObject(outboundJson).optString("tag") }.getOrDefault("")
        val type = runCatching { org.json.JSONObject(outboundJson).optString("type") }.getOrDefault("")
        val detour = runCatching { org.json.JSONObject(outboundJson).optString("detour") }.getOrDefault("")
        log(
            "info",
            "libbox addOutbound selector=$selectorTag tag=$tag type=$type detour=$detour jsonChars=${outboundJson.length}",
        )
        callback(
            Result.failure(
                UnsupportedOperationException(
                    "Dynamic outbound insertion is unavailable; rebuild and apply the runtime config",
                ),
            ),
        )
    }

    fun removeOutbound(selectorTag: String, outboundTag: String, callback: (Result<Unit>) -> Unit) {
        log("info", "libbox removeOutbound selector=$selectorTag outbound=$outboundTag")
        callback(
            Result.failure(
                UnsupportedOperationException(
                    "Dynamic outbound removal is unavailable; rebuild and apply the runtime config",
                ),
            ),
        )
    }

    fun urlTest(
        groupTag: String,
        targetOutboundTag: String,
        priorityOutboundTag: String,
        excludeOutboundTag: String,
        url: String,
        timeoutMillis: Int,
        concurrency: Int,
        deadlineMillis: Int,
        force: Boolean,
        callback: (Result<Unit>) -> Unit,
    ) {
        log(
            "info",
            "libbox urlTest group=$groupTag target=$targetOutboundTag priority=$priorityOutboundTag " +
                "timeoutMs=$timeoutMillis concurrency=$concurrency deadlineMs=$deadlineMillis",
        )
        val operationGeneration = activeRuntimeGeneration
        commandExecutor.execute {
            var result: Result<Unit> = runCatching {
                check(operationGeneration > 0L && operationGeneration == activeRuntimeGeneration && running) {
                    "stale runtime before URL test"
                }
                withStandaloneCommandClient { client ->
                    client.urlTestWithOptions(
                        groupTag,
                        targetOutboundTag,
                        priorityOutboundTag,
                        excludeOutboundTag,
                        url,
                        timeoutMillis,
                        concurrency,
                        deadlineMillis,
                        force,
                    )
                }
            }
            if (operationGeneration != activeRuntimeGeneration) {
                result = Result.failure(IllegalStateException("stale runtime after URL test"))
            }
            result.onFailure {
                val stale = operationGeneration != activeRuntimeGeneration || !running
                log(
                    if (stale) "debug" else "error",
                    "libbox urlTest failed group=$groupTag stale=$stale error=${it.message}",
                )
            }
            mainHandler.post { callback(result.map { Unit }) }
        }
    }

    fun removeUrlTestOutbounds(groupTag: String, outboundTags: List<String>, callback: (Result<Unit>) -> Unit) {
        log(
            "info",
            "libbox removeURLTestOutbounds group=$groupTag count=${outboundTags.size} tags=${outboundTags.take(12).joinToString(",")}",
        )
        callback(
            Result.failure(
                UnsupportedOperationException(
                    "Dynamic URLTest group mutation is unavailable; rebuild and apply the runtime config",
                ),
            ),
        )
    }

    fun lookupOutboundExternalInfo(outboundTag: String, callback: (Result<Map<String, String>>) -> Unit) {
        val operationGeneration = activeRuntimeGeneration
        lookupExecutor.execute {
            var result = runCatching {
                check(operationGeneration > 0L && operationGeneration == activeRuntimeGeneration && running) {
                    "stale runtime before outbound IP lookup"
                }
                fetchOutboundExternalInfo(outboundTag)
            }
            if (operationGeneration != activeRuntimeGeneration) {
                result = Result.failure(IllegalStateException("stale runtime after outbound IP lookup"))
            }
            mainHandler.post { callback(result) }
        }
    }

    fun reloadService(callback: (Result<Unit>) -> Unit) {
        commandExecutor.execute {
            val result = runCatching {
                withStandaloneCommandClient { client ->
                    client.serviceReload()
                }
            }
            mainHandler.post { callback(result.map { Unit }) }
        }
    }

    fun emitNetworkChanged(
        reason: String,
        description: String,
        interfaceName: String?,
        interfaceIndex: Int,
        networkGeneration: Long,
    ) {
        emit(
            mapOf(
                "type" to "network",
                "reason" to reason,
                "description" to description,
                "interfaceName" to interfaceName,
                "interfaceIndex" to interfaceIndex,
                "networkGeneration" to networkGeneration,
                "uptimeMs" to SystemClock.uptimeMillis(),
            ),
        )
    }

    private fun emit(payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private fun emitCoalescedStatus(payload: Map<String, Any?>) {
        latestStatusPayload = payload
        if (!statusEventScheduled.compareAndSet(false, true)) {
            return
        }
        mainHandler.post { drainStatusEvent() }
    }

    private fun emitCoalescedGroups(payload: Map<String, Any?>) {
        latestGroupsPayload = payload
        if (!groupsEventScheduled.compareAndSet(false, true)) {
            return
        }
        mainHandler.post { drainGroupsEvent() }
    }

    private fun drainStatusEvent() {
        val payload = latestStatusPayload
        if (payload == null || payload == lastEmittedStatusPayload) {
            statusEventScheduled.set(false)
            return
        }
        val now = SystemClock.uptimeMillis()
        val remaining = STATUS_EVENT_THROTTLE_MS - (now - lastStatusEventUptimeMs)
        if (remaining > 0) {
            mainHandler.postDelayed({ drainStatusEvent() }, remaining)
            return
        }
        lastStatusEventUptimeMs = now
        lastEmittedStatusPayload = payload
        statusEventScheduled.set(false)
        eventSink?.success(payload)
    }

    private fun drainGroupsEvent() {
        val payload = latestGroupsPayload
        if (payload == null || payload == lastEmittedGroupsPayload) {
            groupsEventScheduled.set(false)
            return
        }
        val now = SystemClock.uptimeMillis()
        val throttleMs = when (MeowApplication.performanceMode) {
            "performance" -> GROUPS_EVENT_THROTTLE_PERFORMANCE_MS
            "balanced" -> GROUPS_EVENT_THROTTLE_BALANCED_MS
            else -> GROUPS_EVENT_THROTTLE_COOL_MS
        }
        val remaining = throttleMs - (now - lastGroupsEventUptimeMs)
        if (remaining > 0) {
            mainHandler.postDelayed({ drainGroupsEvent() }, remaining)
            return
        }
        lastGroupsEventUptimeMs = now
        lastEmittedGroupsPayload = payload
        groupsEventScheduled.set(false)
        eventSink?.success(payload)
    }

    private fun emitCurrentState(error: String? = null) {
        emit(
            mapOf(
                "type" to "state",
                "running" to running,
                "mode" to serviceMode,
                "runtimeGeneration" to activeRuntimeGeneration,
                "error" to error,
            ),
        )
    }

    private fun emitCurrentStatus() {
        emit(
            mapOf(
                "type" to "status",
                "uplink" to uplink,
                "downlink" to downlink,
                "uplinkTotal" to uplinkTotal,
                "downlinkTotal" to downlinkTotal,
                "trafficAvailable" to trafficAvailable,
            ),
        )
    }

    private fun emitCurrentGroups() {
        latestGroupsPayload?.let(::emit)
    }

    private fun fetchOutboundExternalInfo(outboundTag: String): Map<String, String> {
        val normalizedTag = outboundTag.trim()
        require(normalizedTag.isNotEmpty()) { "Outbound tag is empty" }
        val info = withStandaloneCommandClient { client ->
            val externalInfo = client.lookupOutboundExternalInfo(normalizedTag)
            (externalInfo.ip?.trim().orEmpty()) to (externalInfo.countryCode?.trim().orEmpty())
        }
        return buildMap {
            val ip = info.first
            val countryCode = info.second
            if (ip.isNotEmpty()) {
                put("ip", ip)
            }
            if (countryCode.isNotEmpty()) {
                put("countryCode", countryCode)
            }
        }
    }
}

internal fun commandStatusIntervalNanos(performanceMode: String): Long =
    if (performanceMode == "economy") 2_000_000_000L else 1_000_000_000L
