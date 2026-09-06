package com.etonify.meow_client.singbox

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.SystemProxyStatus
import com.etonify.meow_client.MeowApplication
import com.etonify.meow_client.MeowQuickSettingsTileService
import org.json.JSONObject
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

class MeowBoxService(
    private val service: Service,
    private val platformInterface: PlatformInterface,
) : CommandServerHandler {
    companion object {
        private const val TAG = "MeowBoxService"
        const val ACTION_START = "com.etonify.meow_client.singbox.START"
        const val ACTION_STOP = "com.etonify.meow_client.singbox.STOP"
        const val ACTION_RELOAD = "com.etonify.meow_client.singbox.RELOAD"
        const val ACTION_RESTART_CORE = "com.etonify.meow_client.singbox.RESTART_CORE"
        const val EXTRA_STOP_REASON = "stop_reason"
        private const val NOTIFICATION_ID = 42
        private const val COMMAND_CLIENT_DISCONNECT_TIMEOUT_MS = 1_000L
        private const val NATIVE_SERVICE_CLOSE_TIMEOUT_MS = 6_000L
        private const val COMMAND_SERVER_CLOSE_TIMEOUT_MS = 1_000L
        private const val TERMINAL_FORCE_STOP_DELAY_MS = 500L
        private const val NETWORK_WAIT_TIMEOUT_MS = 2_500L
        private const val NETWORK_WAIT_RETRY_DELAY_MS = 1_500L
        private const val NETWORK_WAIT_MAX_RETRIES = 5
        private const val POST_START_INTERFACE_REASSERT_DELAY_MS = 500L
        private const val RUNTIME_RECOVERY_MIN_INTERVAL_MS = 1_000L
        private const val NETWORK_HANDOVER_PROBE_DELAY_MS = 2_500L
        private val activeServices = CopyOnWriteArraySet<MeowBoxService>()

        fun requestStopAll(source: String) {
            for (boxService in activeServices) {
                boxService.requestStop(source)
            }
        }

        fun requestTerminalForceStopAll(source: String): Boolean {
            var requested = false
            for (boxService in activeServices) {
                if (boxService.ownsActiveRuntime()) {
                    requested = true
                    boxService.requestTerminalForceStop(source)
                }
            }
            MeowDiagnostics.log(
                TAG,
                "requestTerminalForceStopAll source=$source requested=$requested active=${activeServices.size}",
            )
            return requested
        }

        fun requestStopForMode(mode: String, source: String): Boolean {
            var requested = false
            for (boxService in activeServices) {
                if (boxService.currentMode() == mode) {
                    requested = true
                    boxService.requestStop(source)
                }
            }
            MeowDiagnostics.log(
                TAG,
                "requestStopForMode mode=$mode source=$source requested=$requested active=${activeServices.size}",
            )
            return requested
        }

        fun hasActiveRuntimeOwner(mode: String? = null): Boolean {
            return activeServices.any { service ->
                service.ownsActiveRuntime(mode)
            }
        }

        /**
         * Flutter may be paused or its event sink detached while the VPN keeps
         * running. Keep the notification snapshot with the foreground service.
         */
        fun updateNotificationPresentation(arguments: Map<*, *>): Boolean {
            var updated = false
            for (boxService in activeServices) {
                updated = boxService.foregroundNotification.updatePresentation(arguments) || updated
            }
            return updated
        }

        fun publishNotificationTraffic(
            uplink: Long,
            downlink: Long,
            uplinkTotal: Long,
            downlinkTotal: Long,
            trafficAvailable: Boolean,
        ) {
            for (boxService in activeServices) {
                boxService.foregroundNotification.updateTraffic(
                    uplink = uplink,
                    downlink = downlink,
                    uplinkTotal = uplinkTotal,
                    downlinkTotal = downlinkTotal,
                    trafficAvailable = trafficAvailable,
                )
            }
        }

        fun publishNotificationUrlTestResult(
            tag: String?,
            delayMillis: Long,
            timeSeconds: Long,
            status: String?,
        ) {
            for (boxService in activeServices) {
                boxService.foregroundNotification.onUrlTestResult(
                    tag = tag,
                    delayMillis = delayMillis,
                    timeSeconds = timeSeconds,
                    status = status,
                )
            }
        }

        fun requestNotificationLatencyRefresh(): Boolean {
            var accepted = false
            for (boxService in activeServices) {
                accepted = boxService.foregroundNotification.requestLatencyRefresh() || accepted
            }
            return accepted
        }
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val retryExecutor = Executors.newSingleThreadScheduledExecutor { runnable ->
        Thread(runnable, "MeowBoxStartRetry").apply { isDaemon = true }
    }
    private val recoveryExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "MeowBoxRecovery").apply { isDaemon = true }
    }
    private val recoveryGate = RuntimeRecoveryGate(RUNTIME_RECOVERY_MIN_INTERVAL_MS)
    private val networkHandoverProbeGate = NetworkHandoverProbeGate()
    private val foregroundNotification = MeowForegroundNotification(
        service = service,
        notificationId = NOTIFICATION_ID,
    )

    @Volatile
    private var commandServer: CommandServer? = null

    @Volatile
    private var receiverRegistered = false

    @Volatile
    private var serviceGeneration = 0L

    private val startRequestGeneration = AtomicLong(0L)
    private val terminalForceStopScheduled = AtomicBoolean(false)
    @Volatile
    private var terminalForceStopRunnable: Runnable? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var pendingStartRetry: ScheduledFuture<*>? = null

    @Volatile
    private var pendingNetworkHandoverProbe: ScheduledFuture<*>? = null

    @Volatile
    private var destroyed = false

    @Volatile
    private var runningConfigHash: Int? = null

    init {
        activeServices += this
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED -> updateDeviceIdleMode()
                Intent.ACTION_SCREEN_ON -> requestRuntimeRecovery("screen_on")
                Intent.ACTION_USER_PRESENT -> requestRuntimeRecovery("user_present")
            }
        }
    }

    fun onStartCommand(intent: Intent?, startId: Int): Int {
        val action = intent?.action
        MeowDiagnostics.log(TAG, "onStartCommand action=$action startId=$startId")
        if (action == null) {
            val mode = currentMode()
            if (shouldRestoreStickyStart(mode)) {
                // A service started with startForegroundService() must enter the
                // foreground before any queued native work. JNI cleanup/startup
                // can legitimately take several seconds during a VPN restart.
                showForeground("Starting")
                Log.w(TAG, "restoring sticky restart mode=$mode")
                SingboxController.log(
                    "warning",
                    "sticky_restart_restore mode=$mode startId=$startId " +
                        "intent=${MeowApplication.describeRuntimeIntent()} " +
                        "serviceState=${MeowApplication.describeRecordedServiceState()}",
                )
                val token = nextStartToken("sticky_restart")
                submitServiceTask("sticky_restart") { startInternal("sticky_restart", token) }
                return Service.START_STICKY
            }
            Log.w(TAG, "ignoring sticky restart without fresh runtime intent")
            MeowDiagnostics.log(
                TAG,
                "ignoring sticky restart without fresh runtime intent mode=$mode " +
                    "intent=${MeowApplication.describeRuntimeIntent()}",
            )
            submitServiceTask("sticky_null_intent") {
                stopInternal("sticky_null_intent", startId = startId)
            }
            return Service.START_NOT_STICKY
        }
        var sticky = false
        when (action) {
            ACTION_START -> {
                showForeground("Starting")
                sticky = true
                val token = nextStartToken("action_start")
                submitServiceTask("action_start") { startInternal("action_start", token) }
            }
            ACTION_STOP -> {
                val reason = intent.getStringExtra(EXTRA_STOP_REASON)?.takeIf { it.isNotBlank() }
                    ?: "unspecified"
                MeowApplication.clearRuntimeIntent()
                showForeground("Stopping")
                submitServiceTask("action_stop:$reason") {
                    stopInternal("action_stop:$reason", startId = startId)
                }
            }
            MeowForegroundNotification.ACTION_REFRESH_LATENCY -> {
                val accepted = foregroundNotification.requestLatencyRefresh()
                MeowDiagnostics.log(
                    TAG,
                    "notification_latency_refresh accepted=$accepted running=${SingboxController.running}",
                )
                return Service.START_STICKY
            }
            ACTION_RESTART_CORE -> {
                showForeground("Restarting")
                sticky = true
                val token = nextStartToken("action_restart_core")
                submitServiceTask("action_restart_core") {
                    restartCoreInternal("action_restart_core", token)
                }
            }
            ACTION_RELOAD -> {
                showForeground("Reloading")
                sticky = true
                val token = nextStartToken("action_reload")
                submitServiceTask("action_reload") { startOrReloadInternal(token) }
            }
            else -> {
                Log.w(TAG, "ignoring unknown action=$action")
                MeowDiagnostics.log(TAG, "ignoring unknown action=$action")
                submitServiceTask("unknown_action") {
                    stopInternal("unknown_action", startId = startId)
                }
                return Service.START_NOT_STICKY
            }
        }
        return if (sticky) Service.START_STICKY else Service.START_NOT_STICKY
    }

    fun onDestroy() {
        if (destroyed) {
            return
        }
        destroyed = true
        MeowDiagnostics.log(TAG, "onDestroy")
        activeServices -= this
        startRequestGeneration.set(Long.MIN_VALUE)
        cancelPendingStartRetry("service_onDestroy")
        cancelPendingNetworkHandoverProbe("service_onDestroy")
        cancelPendingTerminalForceStop("service_onDestroy")
        retryExecutor.shutdownNow()
        recoveryGate.reset()
        recoveryExecutor.shutdownNow()
        submitServiceTask("service_onDestroy", allowAfterDestroy = true) {
            stopInternal("service_onDestroy", stopSelf = false, cancelStarts = false)
        }
        executor.shutdown()
    }

    fun requestStop(source: String) {
        submitServiceTask("requestStop:$source") { stopInternal(source) }
    }

    fun requestRuntimeRecovery(source: String) {
        val server = commandServer
        val ownsRuntime = ownsActiveRuntime()
        if (destroyed || !SingboxController.running || !ownsRuntime || server == null) {
            MeowDiagnostics.log(
                TAG,
                "runtime recovery skipped source=$source destroyed=$destroyed " +
                    "running=${SingboxController.running} owner=$ownsRuntime server=${server != null}",
            )
            return
        }
        scheduleNetworkHandoverProbe(source)
        val now = SystemClock.elapsedRealtime()
        if (!recoveryGate.tryAcquire(now)) {
            MeowDiagnostics.log(TAG, "runtime recovery coalesced source=$source")
            return
        }
        MeowDiagnostics.log(
            TAG,
            "runtime recovery requested source=$source " +
                "current=${MeowDefaultNetworkMonitor.describeCurrentState()}",
        )

        // Re-apply Android's physical upstream immediately. This path remains
        // owned by the foreground service and therefore does not depend on a
        // Flutter Activity or command-event subscription being attached.
        MeowDefaultNetworkMonitor.start()
        MeowDefaultNetworkMonitor.reassertDefaultInterface(
            "runtime_recovery_before_wake:$source",
        )

        try {
            recoveryExecutor.execute {
                if (
                    destroyed ||
                    commandServer !== server ||
                    !SingboxController.running ||
                    !ownsActiveRuntime()
                ) {
                    return@execute
                }
                runCatching {
                    server.wake()
                }.onSuccess {
                    MeowDiagnostics.log(TAG, "runtime recovery wake completed source=$source")
                    MeowDefaultNetworkMonitor.reassertDefaultInterface(
                        "runtime_recovery_after_wake:$source",
                    )
                }.onFailure { error ->
                    MeowDiagnostics.log(TAG, "runtime recovery wake failed source=$source", error)
                    SingboxController.log(
                        "error",
                        "runtime recovery wake failed source=$source error=${error.message}",
                    )
                }
            }
        } catch (_: RejectedExecutionException) {
            MeowDiagnostics.log(TAG, "runtime recovery rejected source=$source destroyed=$destroyed")
        }
    }

    override fun getSystemProxyStatus(): SystemProxyStatus =
        SystemProxyStatus().apply {
            available = false
            enabled = false
        }

    override fun serviceReload() {
        val token = nextStartToken("handler_serviceReload")
        submitServiceTask("handler_serviceReload") { startOrReloadInternal(token) }
    }

    override fun serviceStop() {
        MeowDiagnostics.log(TAG, "serviceStop requested by libbox/platform")
        submitServiceTask("handler_serviceStop") { stopInternal("handler_serviceStop") }
    }

    override fun setSystemProxyEnabled(isEnabled: Boolean) = Unit

    override fun connectSSHAgent(): Int {
        throw UnsupportedOperationException("SSH agent forwarding is not supported on Android")
    }

    override fun triggerNativeCrash() {
        MeowDiagnostics.log(TAG, "native crash request ignored in production Android service")
    }

    override fun writeDebugMessage(message: String?) {
        SingboxController.log("debug", message ?: "")
    }

    private fun currentMode(): String = if (service is MeowVpnService) "vpn" else "proxy"

    private fun ownsActiveRuntime(mode: String? = null): Boolean {
        if (mode != null && mode.isNotBlank() && currentMode() != mode) {
            return false
        }
        val generation = serviceGeneration
        return generation != 0L &&
            generation == SingboxController.activeRuntimeGeneration &&
            commandServer != null
    }

    private fun currentConfigHash(): Int? =
        runCatching { MeowApplication.configFile.readText().hashCode() }.getOrNull()

    private fun shouldRestoreStickyStart(mode: String): Boolean =
        MeowApplication.isRuntimeIntentFresh(mode) &&
            MeowApplication.configFile.exists() &&
            MeowApplication.configFile.length() > 0L

    private fun nextStartToken(reason: String): Long {
        if (destroyed) {
            MeowDiagnostics.log(TAG, "start token ignored after destroy reason=$reason")
            return Long.MIN_VALUE
        }
        val token = SingboxController.nextStartToken("${service.javaClass.simpleName}:$reason")
        startRequestGeneration.set(token)
        return token
    }

    private fun cancelStartRequests(reason: String): Long {
        val token = SingboxController.cancelStartTokens("${service.javaClass.simpleName}:$reason")
        startRequestGeneration.set(token)
        cancelPendingStartRetry(reason)
        return token
    }

    private fun startTokenCurrent(token: Long): Boolean =
        !destroyed &&
            startRequestGeneration.get() == token &&
            SingboxController.isStartTokenCurrent(token)

    private fun cancelPendingStartRetry(reason: String) {
        val pending = pendingStartRetry ?: return
        pendingStartRetry = null
        if (pending.cancel(false)) {
            SingboxController.log(
                "info",
                "service_start_retry_cancelled reason=$reason service=${service.javaClass.simpleName}",
            )
        }
    }

    @Synchronized
    private fun scheduleNetworkHandoverProbe(source: String) {
        if (!isNetworkHandoverRecoverySource(source)) {
            return
        }
        val token = networkHandoverProbeGate.replace()
        pendingNetworkHandoverProbe?.cancel(false)
        pendingNetworkHandoverProbe = null
        try {
            pendingNetworkHandoverProbe = retryExecutor.schedule(
                Runnable {
                    val accepted = synchronized(this@MeowBoxService) {
                        if (!networkHandoverProbeGate.tryConsume(token)) {
                            return@synchronized null
                        }
                        pendingNetworkHandoverProbe = null
                        if (
                            destroyed ||
                            !SingboxController.running ||
                            !ownsActiveRuntime()
                        ) {
                            return@synchronized null
                        }
                        foregroundNotification.requestLatencyRefresh()
                    } ?: return@Runnable
                    MeowDiagnostics.log(
                        TAG,
                        "network handover active-outbound probe " +
                            "source=$source accepted=$accepted",
                    )
                },
                NETWORK_HANDOVER_PROBE_DELAY_MS,
                TimeUnit.MILLISECONDS,
            )
        } catch (_: RejectedExecutionException) {
            networkHandoverProbeGate.invalidate()
            MeowDiagnostics.log(
                TAG,
                "network handover probe rejected source=$source destroyed=$destroyed",
            )
        }
    }

    @Synchronized
    private fun cancelPendingNetworkHandoverProbe(reason: String) {
        networkHandoverProbeGate.invalidate()
        val pending = pendingNetworkHandoverProbe ?: return
        pendingNetworkHandoverProbe = null
        if (pending.cancel(false)) {
            MeowDiagnostics.log(TAG, "network handover probe cancelled reason=$reason")
        }
    }

    @Synchronized
    private fun cancelPendingTerminalForceStop(reason: String) {
        val runnable = terminalForceStopRunnable
        if (runnable != null) {
            mainHandler.removeCallbacks(runnable)
            terminalForceStopRunnable = null
        }
        if (terminalForceStopScheduled.getAndSet(false)) {
            MeowDiagnostics.log(TAG, "terminal force stop cancelled reason=$reason")
        }
    }

    private fun submitServiceTask(
        source: String,
        allowAfterDestroy: Boolean = false,
        task: () -> Unit,
    ): Boolean {
        if (destroyed && !allowAfterDestroy) {
            MeowDiagnostics.log(TAG, "service task ignored after destroy source=$source")
            return false
        }
        return try {
            executor.execute(task)
            true
        } catch (error: RejectedExecutionException) {
            MeowDiagnostics.log(TAG, "service task rejected source=$source", error)
            false
        }
    }

    private fun scheduleRetry(
        source: String,
        task: () -> Unit,
        delayMillis: Long,
    ): ScheduledFuture<*>? {
        if (destroyed) {
            return null
        }
        return try {
            retryExecutor.schedule(task, delayMillis, TimeUnit.MILLISECONDS)
        } catch (error: RejectedExecutionException) {
            MeowDiagnostics.log(TAG, "retry task rejected source=$source", error)
            null
        }
    }

    private fun startInternal(source: String, token: Long) {
        if (!startTokenCurrent(token)) {
            MeowDiagnostics.log(TAG, "start ignored for stale token=$token source=$source")
            return
        }
        val mode = currentMode()
        MeowApplication.writeRuntimeIntent(mode, source)
        val alreadyRunning =
            SingboxController.running && SingboxController.serviceMode == mode && commandServer != null
        if (alreadyRunning) {
            if (PersistentDnsCache.isClearPending(MeowApplication.singboxWorkingDirectory)) {
                MeowDiagnostics.log(TAG, "startInternal forcing core restart for pending DNS cache clear")
                restartCoreInternal("pending_dns_cache_clear:$source", token)
                return
            }
            val configHash = currentConfigHash()
            if (configHash != null && runningConfigHash != null && configHash != runningConfigHash) {
                Log.i(
                    TAG,
                    "startInternal reloading source=$source mode=$mode configHash=$configHash runningConfigHash=$runningConfigHash",
                )
                MeowDiagnostics.log(
                    TAG,
                    "startInternal reload requested source=$source mode=$mode configHash=$configHash runningConfigHash=$runningConfigHash",
                )
                startOrReloadInternal(token)
                return
            }
            Log.i(TAG, "startInternal ignored source=$source already running mode=$mode")
            MeowDiagnostics.log(
                TAG,
                "startInternal ignored source=$source already running mode=$mode " +
                    "current=${MeowDefaultNetworkMonitor.describeCurrentState()}",
            )
            registerRuntimeReceiver()
            MeowDefaultNetworkMonitor.start()
            requestRuntimeRecovery("existing_runtime:$source")
            showForeground("Connected")
            MeowApplication.writeServiceState(mode)
            MeowQuickSettingsTileService.requestRefresh(service)
            return
        }
        startOrReloadInternal(token)
    }

    private fun startOrReloadInternal(
        token: Long = nextStartToken("startOrReloadInternal"),
        networkWaitAttempt: Int = 0,
    ) {
        if (!startTokenCurrent(token)) {
            Log.i(TAG, "startOrReloadInternal ignored stale token=$token")
            MeowDiagnostics.log(TAG, "startOrReloadInternal ignored stale token=$token")
            return
        }
        Log.i(TAG, "startOrReloadInternal begin service=${service.javaClass.simpleName}")
        cancelPendingTerminalForceStop("startOrReloadInternal")
        val mode = currentMode()
        MeowApplication.writeRuntimeIntent(mode, "start_or_reload")
        SingboxController.log(
            "info",
            "native_start_marker phase=begin service=${service.javaClass.simpleName} " +
                "mode=$mode token=$token attempt=$networkWaitAttempt pid=${android.os.Process.myPid()} " +
                "intent=${MeowApplication.describeRuntimeIntent()} " +
                "serviceState=${MeowApplication.describeRecordedServiceState()}",
        )
        MeowDiagnostics.log(
            TAG,
            "startOrReloadInternal begin service=${service.javaClass.simpleName} " +
                "current=${MeowDefaultNetworkMonitor.describeCurrentState()}",
        )
        try {
            SingboxController.log(
                "info",
                "native_start_marker phase=before_libbox_setup memoryLimit=${MeowApplication.memoryLimitEnabled}",
            )
            MeowApplication.ensureLibboxSetup()
            SingboxController.log("info", "native_start_marker phase=after_libbox_setup")
            showForeground("Starting")
            SingboxController.log("info", "native_start_marker phase=foreground_starting")
        } catch (error: Throwable) {
            Log.e(TAG, "startOrReloadInternal setup failed", error)
            MeowDiagnostics.log(TAG, "startOrReloadInternal setup failed", error)
            fail("Native service setup failed: ${error.message ?: error}")
            return
        }
        registerRuntimeReceiver()
        MeowDefaultNetworkMonitor.start()
        if (!MeowDefaultNetworkMonitor.awaitUsableDefaultInterface(NETWORK_WAIT_TIMEOUT_MS)) {
            SingboxController.log(
                "warning",
                "network_interface_wait_timeout attempt=$networkWaitAttempt token=$token " +
                    "current=${MeowDefaultNetworkMonitor.describeCurrentState()}",
            )
            if (networkWaitAttempt < NETWORK_WAIT_MAX_RETRIES) {
                showForeground("Waiting for network")
                cancelPendingStartRetry("replace_network_wait_retry")
                pendingStartRetry = scheduleRetry(
                    "network_wait",
                    {
                        if (startTokenCurrent(token)) {
                            submitServiceTask("network_wait_retry") {
                                startOrReloadInternal(token, networkWaitAttempt + 1)
                            }
                        }
                    },
                    NETWORK_WAIT_RETRY_DELAY_MS,
                )
                SingboxController.log(
                    "info",
                    "service_start_retry_scheduled attempt=${networkWaitAttempt + 1} " +
                        "token=$token service=${service.javaClass.simpleName}",
                )
                return
            }
            fail("No usable network interface")
            return
        }
        SingboxController.log(
            "info",
            "network_interface_ready token=$token current=${MeowDefaultNetworkMonitor.describeCurrentState()}",
        )
        if (!startTokenCurrent(token)) {
            MeowDiagnostics.log(TAG, "start cancelled after network wait token=$token")
            return
        }
        val config = runCatching { MeowApplication.configFile.readText() }.getOrElse {
            Log.e(TAG, "failed to read config", it)
            fail("Failed to read config: ${it.message}")
            return
        }
        if (config.isBlank()) {
            Log.e(TAG, "generated config is empty")
            fail("Generated config is empty")
            return
        }
        val configHash = config.hashCode()
        val preparedRuntimeConfig = prepareRuntimeConfig(config)
        if (!startTokenCurrent(token)) {
            MeowDiagnostics.log(TAG, "start cancelled before command server token=$token")
            return
        }
        try {
            if (commandServer == null && !clearPendingDnsCache(runtimeActive = false, source = "before_start")) {
                fail("Failed to clear persistent DNS cache")
                return
            }
            SingboxController.log(
                "info",
                "native_start_marker phase=before_command_server configChars=${preparedRuntimeConfig.config.length} " +
                    "configHash=$configHash splitMode=$mode",
            )
            val server = commandServer ?: createCommandServer()
            Log.i(TAG, "starting/reloading libbox service")
            SingboxController.log(
                "info",
                "native_start_marker phase=before_start_or_reload_service hasCommandServer=${commandServer != null}",
            )
            MeowDiagnostics.log(
                TAG,
                "starting/reloading libbox service current=${MeowDefaultNetworkMonitor.describeCurrentState()}",
            )
            val startedAt = System.currentTimeMillis()
            server.startOrReloadService(
                preparedRuntimeConfig.config,
                preparedRuntimeConfig.overrideOptions,
            )
            val elapsedMs = System.currentTimeMillis() - startedAt
            SingboxController.log(
                "info",
                "native_start_marker phase=after_start_or_reload_service " +
                    "tun_fd_ownership owner=libbox service=${service.javaClass.simpleName} " +
                    "startElapsedMs=$elapsedMs",
            )
            MeowDefaultNetworkMonitor.reassertDefaultInterface("after_start_or_reload_service")
            scheduleRetry(
                "post_start_interface_reassert",
                {
                    if (startTokenCurrent(token) && commandServer != null) {
                        MeowDefaultNetworkMonitor.reassertDefaultInterface(
                            "after_start_or_reload_service_delayed",
                        )
                    }
                },
                POST_START_INTERFACE_REASSERT_DELAY_MS,
            )
            showForeground("Connected")
            MeowApplication.writeServiceState(mode)
            Log.i(TAG, "libbox service started mode=$mode")
            MeowDiagnostics.log(
                TAG,
                "libbox service started mode=$mode current=${MeowDefaultNetworkMonitor.describeCurrentState()}",
            )
            serviceGeneration = SingboxController.markServiceStarted(mode)
            runningConfigHash = configHash
            SingboxController.log(
                "info",
                "VPN service running mode=$mode generation=$serviceGeneration hasCommandServer=${commandServer != null}",
            )
            cancelPendingStartRetry("start_success")
            MeowQuickSettingsTileService.requestRefresh(service)
        } catch (error: Throwable) {
            Log.e(TAG, "startOrReloadInternal failed", error)
            MeowDiagnostics.log(TAG, "startOrReloadInternal failed", error)
            fail(error.message ?: error.toString())
        }
    }

    private fun stopInternal(
        source: String,
        stopSelf: Boolean = true,
        startId: Int? = null,
        cancelStarts: Boolean = true,
    ) {
        cancelPendingNetworkHandoverProbe("stop:$source")
        val generation = serviceGeneration
        val activeGeneration = SingboxController.activeRuntimeGeneration
        val server = commandServer
        val staleRuntimeStop = generation != 0L && generation != activeGeneration
        val ownsRuntime = generation != 0L && !staleRuntimeStop
        val hasLocalRuntime = generation != 0L || server != null
        val shouldCancelStartRequests = cancelStarts && ownsRuntime
        val shouldStopRuntimeState = ownsRuntime || (cancelStarts && !SingboxController.running)
        if (shouldCancelStartRequests) {
            cancelStartRequests("stop:$source")
        } else {
            cancelPendingStartRetry("stop:$source")
        }
        Log.i(TAG, "stopInternal source=$source service=${service.javaClass.simpleName}")
        SingboxController.log(
            "warning",
            "VPN service stop requested source=$source service=${service.javaClass.simpleName} " +
                "running=${SingboxController.running} mode=${SingboxController.serviceMode} " +
                "generation=$generation activeGeneration=$activeGeneration " +
                "hasCommandServer=${server != null} ownsRuntime=$ownsRuntime",
        )
        MeowDiagnostics.log(
            TAG,
            "stopInternal source=$source service=${service.javaClass.simpleName} " +
                "running=${SingboxController.running} mode=${SingboxController.serviceMode} " +
                "generation=$generation activeGeneration=$activeGeneration " +
                "hasCommandServer=${server != null} ownsRuntime=$ownsRuntime",
        )
        if (!hasLocalRuntime && SingboxController.running) {
            MeowDiagnostics.log(
                TAG,
                "stale empty stop ignored source=$source active=$activeGeneration",
            )
            if (stopSelf) {
                if (startId != null) {
                    service.stopSelfResult(startId)
                } else {
                    service.stopSelf()
                }
            }
            return
        }
        unregisterRuntimeReceiver()

        if (shouldStopRuntimeState) {
            MeowDefaultNetworkMonitor.stop()
        } else {
            // This stale service must not publish another notification after
            // stopForeground(), but it must not clear the active owner's
            // shared presentation state or notification ID either.
            foregroundNotification.stopPublishing()
            MeowDiagnostics.log(
                TAG,
                "network monitor stop skipped source=$source " +
                    "generation=$generation active=$activeGeneration",
            )
        }

        var nativeServiceClosed = true
        var commandServerClosed = true

        // Сначала отключаем активный CommandClient.
        if (shouldStopRuntimeState) {
            val clientDisconnected = SingboxController.disconnectClientBlocking(
                timeoutMs = COMMAND_CLIENT_DISCONNECT_TIMEOUT_MS,
            )

            if (!clientDisconnected) {
                MeowDiagnostics.log(
                    TAG,
                    "command client disconnect timed out source=$source",
                )
            }

            // CommandClient is only the diagnostics/status consumer. A blocked
            // disconnect must not keep the VPN foreground notification alive
            // after the native service itself has successfully closed below.
            // closeService()/close() remain the authoritative cleanup steps.
        }

        // Затем закрываем native runtime и CommandServer.
        if (server != null) {
            nativeServiceClosed = runCleanupStep(
                "closeService source=$source",
                NATIVE_SERVICE_CLOSE_TIMEOUT_MS,
            ) {
                server.closeService()
            }

            // CommandServer is only the local RPC/status endpoint. Once
            // closeService() has acknowledged the native VPN shutdown, a slow
            // CommandServer.close() must not keep the foreground notification
            // and Android service alive indefinitely.
            if (nativeServiceClosed) {
                commandServerClosed = runCleanupStep(
                    "close command server source=$source",
                    COMMAND_SERVER_CLOSE_TIMEOUT_MS,
                ) {
                    server.close()
                }
            }
        }

        if (!nativeServiceClosed) {
            SingboxController.log(
                "error",
                "VPN native service cleanup incomplete source=$source " +
                    "service=${service.javaClass.simpleName}",
            )
            MeowDiagnostics.log(
                TAG,
                "runtime stop not acknowledged source=$source " +
                    "generation=$generation activeGeneration=$activeGeneration " +
                    "nativeServiceClosed=false",
            )

            showForeground("Stopping")
            return
        }

        if (!commandServerClosed) {
            SingboxController.log(
                "warning",
                "VPN command server cleanup incomplete after native stop source=$source " +
                    "service=${service.javaClass.simpleName}",
            )
            MeowDiagnostics.log(
                TAG,
                "command server close not acknowledged after native stop source=$source " +
                    "generation=$generation activeGeneration=$activeGeneration",
            )
        }

        clearPendingDnsCache(runtimeActive = false, source = "after_stop:$source")

        commandServer = null
        runningConfigHash = null
        serviceGeneration = 0L

        if (shouldStopRuntimeState) {
            MeowApplication.clearServiceState()
            MeowApplication.clearRuntimeIntent()
            SingboxController.markServiceStopped(generation, source)
            // Make notification shutdown terminal before stopForeground(). A
            // traffic/latency refresh already queued on the main looper must
            // not be able to publish notification 42 again after removal.
            foregroundNotification.stopAndClear()
            MeowQuickSettingsTileService.requestRefresh(service)
        } else {
            MeowDiagnostics.log(
                TAG,
                "runtime state stop skipped source=$source " +
                    "generation=$generation active=$activeGeneration",
            )
        }

        SingboxController.log(
            "warning",
            "VPN service stopped source=$source " +
                "service=${service.javaClass.simpleName}",
        )

        runCatching {
            service.stopForeground(Service.STOP_FOREGROUND_REMOVE)
        }
        cancelPendingTerminalForceStop("stopInternal_complete:$source")

        if (stopSelf) {
            if (startId != null) {
                val stopped = service.stopSelfResult(startId)
                MeowDiagnostics.log(
                    TAG,
                    "stopSelfResult source=$source startId=$startId result=$stopped",
                )
            } else {
                service.stopSelf()
                MeowDiagnostics.log(TAG, "stopSelf source=$source")
            }
        }
    }

    private fun restartCoreInternal(source: String, token: Long = nextStartToken("restartCoreInternal:$source")) {
        if (!startTokenCurrent(token)) {
            MeowDiagnostics.log(TAG, "core restart ignored for stale token=$token source=$source")
            return
        }
        Log.i(TAG, "restartCoreInternal source=$source service=${service.javaClass.simpleName}")
        MeowDiagnostics.log(
            TAG,
            "restartCoreInternal source=$source service=${service.javaClass.simpleName} " +
                "running=${SingboxController.running} mode=${SingboxController.serviceMode} " +
                "hasCommandServer=${commandServer != null}",
        )
        val server = commandServer
        if (server != null) {
            val closed = runCleanupStep(
                "restart closeService source=$source",
                NATIVE_SERVICE_CLOSE_TIMEOUT_MS,
            ) {
                server.closeService()
            }
            if (!closed) {
                SingboxController.log(
                    "error",
                    "Core restart aborted because native shutdown was not acknowledged source=$source",
                )
                MeowDiagnostics.log(TAG, "restartCoreInternal native close unconfirmed source=$source")
                showForeground("Stopping")
                return
            }
        }
        if (!clearPendingDnsCache(runtimeActive = false, source = "core_restart:$source")) {
            fail("Failed to clear persistent DNS cache")
            return
        }
        runningConfigHash = null
        startOrReloadInternal(token)
    }

    private fun createCommandServer(): CommandServer {
        val server = Libbox.newCommandServer(this, platformInterface)
        try {
            Log.i(TAG, "creating new command server")
            MeowDiagnostics.log(TAG, "creating new command server")
            server.start()
            commandServer = server
            return server
        } catch (error: Throwable) {
            MeowDiagnostics.log(TAG, "command server start failed after allocation; closing", error)
            runCatching { server.closeService() }
            runCatching { server.close() }
            throw error
        }
    }

    private fun runCleanupStep(
        label: String,
        timeoutMs: Long,
        block: () -> Unit,
    ): Boolean {
        var failure: Throwable? = null
        val threadName = "MeowBoxCleanup-${label.take(32).replace(' ', '_')}"
        val thread = Thread(
            {
                try {
                    block()
                } catch (error: Throwable) {
                    failure = error
                }
            },
            threadName,
        ).apply {
            isDaemon = true
            start()
        }
        try {
            thread.join(timeoutMs)
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
            MeowDiagnostics.log(TAG, "$label interrupted during cleanup", error)
            return false
        }
        if (thread.isAlive) {
            MeowDiagnostics.log(
                TAG,
                "$label timed out after ${timeoutMs}ms; stop remains unconfirmed",
            )
            thread.interrupt()
            return false
        }
        val error = failure
        if (error != null) {
            MeowDiagnostics.log(TAG, "$label failed during cleanup", error)
            return false
        }
        return true
    }

    private fun clearPendingDnsCache(runtimeActive: Boolean, source: String): Boolean {
        val result = PersistentDnsCache.clearIfPending(
            MeowApplication.singboxWorkingDirectory,
            runtimeActive = runtimeActive,
        )
        MeowDiagnostics.log(TAG, "persistent DNS cache lifecycle source=$source result=$result")
        return result != DnsCacheClearResult.FAILED &&
            result != DnsCacheClearResult.DEFERRED_RUNTIME_ACTIVE
    }

    private fun requestTerminalForceStop(source: String) {
        if (destroyed) return
        if (!terminalForceStopScheduled.compareAndSet(false, true)) return
        MeowApplication.clearRuntimeIntent()
        cancelStartRequests("terminal_force_stop:$source")
        cancelPendingNetworkHandoverProbe("terminal_force_stop:$source")
        foregroundNotification.stopAndClear()
        runCatching { service.stopForeground(Service.STOP_FOREGROUND_REMOVE) }
        val runnable = Runnable {
            terminalForceStopRunnable = null
            if (destroyed) {
                terminalForceStopScheduled.set(false)
                return@Runnable
            }
            val shouldForceStop = VpnServiceLifecyclePolicy.shouldForceStopServiceAfterTimeout(
                runtimeRunning = SingboxController.running,
                activeRuntimeOwner = ownsActiveRuntime(),
                freshRuntimeIntent = MeowApplication.isRuntimeIntentFresh(currentMode()),
            )
            MeowDiagnostics.log(
                TAG,
                "terminal force stop verification source=$source forceStop=$shouldForceStop " +
                    "running=${SingboxController.running} generation=$serviceGeneration",
            )
            if (!shouldForceStop) {
                terminalForceStopScheduled.set(false)
                return@Runnable
            }
            MeowDiagnostics.log(
                TAG,
                "terminal force stop executing graceful teardown source=$source " +
                    "running=${SingboxController.running} generation=$serviceGeneration",
            )
            val server = commandServer
            var nativeServiceClosed = true
            var commandServerClosed = true
            if (server != null) {
                nativeServiceClosed = runCleanupStep(
                    "terminal force closeService source=$source",
                    NATIVE_SERVICE_CLOSE_TIMEOUT_MS,
                ) {
                    server.closeService()
                }
                if (nativeServiceClosed) {
                    commandServerClosed = runCleanupStep(
                        "terminal force close command server source=$source",
                        COMMAND_SERVER_CLOSE_TIMEOUT_MS,
                    ) {
                        server.close()
                    }
                }
            }
            val cleanupSuccess = nativeServiceClosed && commandServerClosed
            if (cleanupSuccess) {
                commandServer = null
                runningConfigHash = null
                val generation = serviceGeneration
                serviceGeneration = 0L
                clearPendingDnsCache(runtimeActive = false, source = "terminal_force_stop:$source")
                MeowApplication.clearServiceState()
                MeowApplication.clearRuntimeIntent()
                SingboxController.markServiceStopped(generation, "terminal_force_stop:$source")
                foregroundNotification.stopAndClear()
                MeowDefaultNetworkMonitor.stop()
                MeowQuickSettingsTileService.requestRefresh(service)
                runCatching { service.stopForeground(Service.STOP_FOREGROUND_REMOVE) }
                runCatching { service.stopSelf() }
                terminalForceStopScheduled.set(false)
            } else {
                MeowDiagnostics.log(
                    TAG,
                    "terminal force stop cleanup failed source=$source " +
                        "nativeServiceClosed=$nativeServiceClosed commandServerClosed=$commandServerClosed",
                )
                SingboxController.log(
                    "error",
                    "VPN native service cleanup timed out during terminal force stop source=$source",
                )
                foregroundNotification.stopAndClear()
                MeowDefaultNetworkMonitor.stop()
                MeowQuickSettingsTileService.requestRefresh(service)
                runCatching { service.stopForeground(Service.STOP_FOREGROUND_REMOVE) }
                runCatching { service.stopSelf() }
                SingboxController.setRunning(false, error = "runtime_cleanup_timeout")
                SingboxController.notifyStopWaiters(false)
                terminalForceStopScheduled.set(false)
            }
        }
        terminalForceStopRunnable = runnable
        mainHandler.postDelayed(runnable, TERMINAL_FORCE_STOP_DELAY_MS)
    }

    private fun fail(message: String) {
        Log.e(TAG, "fail: $message")
        MeowDiagnostics.log(TAG, "fail: $message")
        SingboxController.log("error", message)
        SingboxController.setRunning(false, error = message)
        stopInternal("fail")
    }

    private fun showForeground(status: String) {
        val notification = foregroundNotification.buildForForeground(status)
        service.startForeground(NOTIFICATION_ID, notification)
    }

    private data class PreparedRuntimeConfig(
        val config: String,
        val overrideOptions: OverrideOptions,
    )

    private class ListStringIterator(
        values: List<String>,
    ) : io.nekohasekai.libbox.StringIterator {
        private val items = values.toList()
        private var index = 0

        override fun hasNext(): Boolean = index < items.size

        override fun len(): Int = items.size

        override fun next(): String = items[index++]
    }

    private fun prepareRuntimeConfig(config: String): PreparedRuntimeConfig {
        val overrideOptions = OverrideOptions()
        return runCatching {
            val root = JSONObject(config)
            val splitIncludePackages = mutableListOf<String>()
            val splitExcludePackages = mutableListOf<String>()
            val inbounds = root.optJSONArray("inbounds")
            val outbounds = root.optJSONArray("outbounds")
            var changed = false
            for (index in 0 until (inbounds?.length() ?: 0)) {
                val inbound = inbounds?.optJSONObject(index) ?: continue
                if (inbound.optString("type") != "tun") {
                    continue
                }
                splitIncludePackages += readPackageList(inbound.optJSONArray("include_package"))
                splitExcludePackages += readPackageList(inbound.optJSONArray("exclude_package"))
                if (inbound.has("include_package")) {
                    inbound.remove("include_package")
                    changed = true
                }
                if (inbound.has("exclude_package")) {
                    inbound.remove("exclude_package")
                    changed = true
                }
            }
            for (index in 0 until (outbounds?.length() ?: 0)) {
                val outbound = outbounds?.optJSONObject(index) ?: continue
                if (outbound.optString("type") == "vless" && outbound.has("packet_encoding")) {
                    val packetEncoding = outbound.opt("packet_encoding")
                    val packetEncodingValue = packetEncoding as? String
                    if (packetEncodingValue !in setOf("", "packetaddr", "xudp")) {
                        val tag = outbound.optString("tag", "#$index")
                        Log.w(
                            TAG,
                            "dropping invalid vless packet_encoding tag=$tag value=$packetEncoding",
                        )
                        MeowDiagnostics.log(
                            TAG,
                            "dropping invalid vless packet_encoding tag=$tag value=$packetEncoding",
                        )
                        outbound.remove("packet_encoding")
                        changed = true
                    }
                }
            }
            val includePackages = normalizePackageList(splitIncludePackages)
            val excludePackages = normalizePackageList(splitExcludePackages)
            requireExclusiveSplitTunnelPackages(includePackages, excludePackages)
            if (includePackages.isNotEmpty()) {
                overrideOptions.includePackage = ListStringIterator(includePackages)
            }
            if (excludePackages.isNotEmpty()) {
                overrideOptions.excludePackage = ListStringIterator(excludePackages)
            }
            if (splitIncludePackages.isNotEmpty() || splitExcludePackages.isNotEmpty()) {
                MeowDiagnostics.log(
                    TAG,
                    "split packages moved to OverrideOptions include=${includePackages.size} " +
                        "exclude=${excludePackages.size} rawInclude=${splitIncludePackages.size} " +
                        "rawExclude=${splitExcludePackages.size}",
                )
            }
            val preparedConfig = if (changed) {
                root.toString()
            } else {
                config
            }
            PreparedRuntimeConfig(preparedConfig, overrideOptions)
        }.getOrElse { error ->
            if (error is SplitTunnelConfigurationException) {
                throw error
            }
            MeowDiagnostics.log(TAG, "prepareConfig parse failed", error)
            PreparedRuntimeConfig(config, overrideOptions)
        }
    }

    private fun readPackageList(array: org.json.JSONArray?): List<String> {
        if (array == null) {
            return emptyList()
        }
        val result = mutableListOf<String>()
        for (index in 0 until array.length()) {
            val value = array.optString(index, "").trim()
            if (value.isNotEmpty()) {
                result += value
            }
        }
        return result
    }

    private fun normalizePackageList(values: List<String>): List<String> {
        val seen = linkedSetOf<String>()
        for (value in values) {
            val packageName = value.trim()
            if (
                packageName.isNotEmpty() &&
                packageName != service.packageName &&
                isAndroidPackageName(packageName)
            ) {
                seen += packageName
            }
            if (seen.size >= MAX_SPLIT_TUNNEL_PACKAGE_COUNT) {
                break
            }
        }
        return seen.toList()
    }

    private fun isAndroidPackageName(value: String): Boolean =
        value.length <= 255 &&
            Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$").matches(value)

    private fun registerRuntimeReceiver() {
        if (receiverRegistered) {
            return
        }
        val filter = IntentFilter().apply {
            addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                service.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                service.registerReceiver(receiver, filter)
            }
            receiverRegistered = true
            MeowDiagnostics.log(TAG, "runtime receiver registered")
            updateDeviceIdleMode()
        }.onFailure {
            MeowDiagnostics.log(TAG, "runtime receiver registration failed", it)
        }
    }

    private fun unregisterRuntimeReceiver() {
        if (!receiverRegistered) {
            return
        }
        runCatching {
            service.unregisterReceiver(receiver)
            receiverRegistered = false
            MeowDiagnostics.log(TAG, "runtime receiver unregistered")
        }.onFailure {
            receiverRegistered = false
            MeowDiagnostics.log(TAG, "runtime receiver unregister failed", it)
        }
    }

    private fun updateDeviceIdleMode() {
        val powerManager = service.getSystemService(Context.POWER_SERVICE) as PowerManager
        val idle = powerManager.isDeviceIdleMode
        MeowDiagnostics.log(TAG, "device idle mode changed idle=$idle")
        if (idle) {
            SingboxController.log(
                "info",
                "Android device idle/doze entered; keeping VPN core active",
            )
            return
        }
        SingboxController.log(
            "info",
            "core wake requested by Android device idle exit",
        )
        requestRuntimeRecovery("device_idle_exit")
    }
}
