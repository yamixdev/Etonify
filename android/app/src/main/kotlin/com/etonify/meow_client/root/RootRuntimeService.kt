package com.etonify.meow_client.root

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.system.Os
import com.etonify.meow_client.MeowApplication
import com.etonify.meow_client.MeowQuickSettingsTileService
import com.etonify.meow_client.singbox.MeowBoxService
import com.etonify.meow_client.singbox.MeowDefaultNetworkMonitor
import com.etonify.meow_client.singbox.MeowForegroundNotification
import com.etonify.meow_client.singbox.SingboxController
import com.etonify.meow_client.singbox.MeowVpnService
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** Android owns the user-visible lifetime; the separate root process owns networking. */
class RootRuntimeService : Service() {
    companion object {
        const val MODE = "root"
        private const val NOTIFICATION_ID = 42
        @Volatile private var owner: RootRuntimeService? = null

        @Synchronized private fun claim(service: RootRuntimeService): Boolean {
            if (owner?.session?.isActive == true && owner !== service) return false
            owner = service
            return true
        }

        fun hasActiveOwner(): Boolean = owner?.session?.isActive == true
        fun hasRunningOwner(): Boolean = owner?.session?.isRunning == true
        fun isStartPending(): Boolean = owner?.session?.isPreparing == true
        fun requestStop(reason: String): Boolean = owner?.takeIf { it.session.isActive }?.let {
            it.stopRuntime(reason)
            true
        } ?: false
        internal fun notification(): MeowForegroundNotification? = owner?.takeIf { it.session.isActive }?.foregroundNotification
        internal fun runtimeGeneration(): Long = owner?.runtimeGeneration ?: 0L
        internal fun onPhysicalDnsChanged(addresses: List<String>) {
            val service = owner ?: return
            if (service.session.isRunning && service.usedDeviceDns && addresses.isNotEmpty() && addresses != service.appliedDns) {
                // Event-triggered, only when the device resolver actually
                // changes. No periodic su checks or reconnect attempts.
                service.stopRuntime("physical_dns_changed", restart = true)
            }
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor { task -> Thread(task, "EtonifyRootRuntime").apply { isDaemon = true } }
    private val session = RootRuntimeSession()
    private val lifecycle = Any()
    @Volatile private var runtimeProcess: RootRuntimeProcess? = null
    @Volatile private var runtimeGeneration = 0L
    @Volatile private var destroyed = false
    @Volatile private var usedDeviceDns = false
    @Volatile private var appliedDns: List<String> = emptyList()
    @Volatile private var restartAfterStop = false
    @Volatile private var startupThread: Thread? = null
    private lateinit var foregroundNotification: MeowForegroundNotification

    override fun onCreate() {
        super.onCreate()
        foregroundNotification = MeowForegroundNotification(this, NOTIFICATION_ID)
        if (!claim(this)) stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (owner !== this) { stopSelf(); return START_NOT_STICKY }
        when (intent?.action) {
            MeowBoxService.ACTION_STOP -> stopRuntime("service_stop")
            MeowBoxService.ACTION_RELOAD, MeowBoxService.ACTION_RESTART_CORE -> {
                // Root config is validated in the privileged process on each
                // launch. Until a transactional reload exists, never silently
                // continue with a config different from the selected profile.
                stopRuntime("config_changed", restart = true)
            }
            MeowBoxService.ACTION_START -> beginStart(intent)
            else -> stopSelf()
        }
        // Android must not resurrect root mode after a manual stop/process kill.
        return START_NOT_STICKY
    }

    private fun beginStart(intent: Intent) {
        if (!RootModuleManager.enabled(this)) {
            failWithoutOwner("root_mode_disabled")
            return
        }
        val revision = intent.getLongExtra(MeowBoxService.EXTRA_EXPECTED_EXTERNAL_STOP_REVISION, SingboxController.externalStopRevision)
        if (revision != SingboxController.externalStopRevision) { stopSelf(); return }
        if (session.isActive) return
        if (MeowBoxService.hasActiveRuntimeOwner()) { failWithoutOwner("runtime_busy"); return }
        val ticket = session.beginStart(revision) ?: return
        MeowVpnService.cancelScheduledRestart(this, "root_service_start")
        val startToken = SingboxController.nextStartToken("root_service_start")
        showForeground("Starting")
        executor.execute {
            startupThread = Thread.currentThread()
            var staged: File? = null
            try {
                val manager = RootModeBridge.manager(this)
                if (manager.isBusy) throw RootModuleException("operation_busy")
                if (!manager.authorizeRuntime()) throw RootModuleException(manager.snapshot()["reason"] as? String ?: "root_denied")
                if (!session.isCurrent(ticket, SingboxController.externalStopRevision)) return@execute
                MeowApplication.ensureLibboxSetup()
                MeowDefaultNetworkMonitor.start()
                val physical = MeowDefaultNetworkMonitor.requirePhysicalNetwork()
                val dns = MeowApplication.connectivity.getLinkProperties(physical)?.dnsServers
                    ?.mapNotNull { it.hostAddress } ?: emptyList()
                val rootStage = File(filesDir, "root-rule-staging").apply { mkdirs(); Os.chmod(absolutePath, 448) }
                staged = File(rootStage, UUID.randomUUID().toString()).apply { mkdir(); Os.chmod(absolutePath, 448) }
                val allowedRoots = listOfNotNull(filesDir, getExternalFilesDir(null)).map { it.canonicalFile }
                var stagedBytes = 0L
                val rawConfig = MeowApplication.configFile.readText()
                usedDeviceDns = org.json.JSONObject(rawConfig).optJSONObject("dns")?.optJSONArray("servers")?.let { servers ->
                    (0 until servers.length()).any { servers.optJSONObject(it)?.optString("type") == "local" }
                } == true
                appliedDns = dns
                val config = RootConfigAdapter.adapt(rawConfig, dns) { raw ->
                    val source = File(raw).canonicalFile
                    if (allowedRoots.none { source.path.startsWith(it.path + File.separator) } || !source.isFile || source.length() > 64L * 1024 * 1024) {
                        throw RootModuleException("root_rule_file_rejected")
                    }
                    val target = File(staged, "${UUID.randomUUID()}.srs")
                    source.inputStream().use { input -> target.outputStream().use { output ->
                        val buffer = ByteArray(32768)
                        while (true) {
                            if (Thread.currentThread().isInterrupted) throw RootModuleException("operation_cancelled")
                            val count = input.read(buffer)
                            if (count < 0) break
                            stagedBytes += count
                            if (stagedBytes > 256L * 1024 * 1024) throw RootModuleException("root_rule_size_exceeded")
                            output.write(buffer, 0, count)
                        }
                    } }
                    Os.chmod(target.absolutePath, 384)
                    target.absolutePath
                }
                val child = synchronized(lifecycle) {
                    if (!session.isCurrent(ticket, SingboxController.externalStopRevision) || !SingboxController.isStartTokenCurrent(startToken)) {
                        stopRuntime("start_superseded")
                        return@execute
                    }
                    RootProcessRunner().startRuntime(config, android.os.Process.myUid(), File(filesDir, "singbox-base/command.sock").absolutePath)
                        .also { runtimeProcess = it }
                }
                if (!child.awaitReady()) throw RootModuleException(child.failureCode ?: "root_start_failed")
                synchronized(lifecycle) {
                    if (!session.markReady(ticket, SingboxController.externalStopRevision) || !SingboxController.isStartTokenCurrent(startToken)) {
                        child.closeLease()
                        stopRuntime("start_superseded")
                        return@execute
                    }
                    if (!SingboxController.writeIntentForStartToken(startToken, MODE, "root_service_ready")) {
                        child.closeLease()
                        stopRuntime("start_superseded")
                        return@execute
                    }
                    runtimeGeneration = SingboxController.markServiceStarted(MODE)
                    MeowApplication.writeServiceState(MODE)
                }
                main.post {
                    if (!session.isRunning) return@post
                    showForeground("Connected")
                    foregroundNotification.onRuntimeReady(runtimeGeneration, SingboxController.currentNetworkGeneration,
                        intent.getBooleanExtra(MeowBoxService.EXTRA_TILE_START, false))
                    MeowQuickSettingsTileService.requestRefresh(this)
                    MeowDefaultNetworkMonitor.reassertDefaultInterface("root_ready")
                }
                // Event-driven EOF, no root polling or automatic restart loop.
                Thread({
                    runCatching { child.process.waitFor() }
                    if (runtimeProcess === child && session.isRunning) stopRuntime("root_process_exited", error = true)
                }, "EtonifyRootExit").apply { isDaemon = true; start() }
            } catch (error: Exception) {
                if (!session.isCurrent(ticket, SingboxController.externalStopRevision)) return@execute
                val code = (error as? RootModuleException)?.code ?: when (error.message) {
                    "root_dns_unavailable" -> "root_dns_unavailable"
                    else -> "root_start_failed"
                }
                stopRuntime(code, error = true)
            } finally {
                // The daemon has already copied local rules into root-owned
                // snapshots before reporting ready (or rejected the config).
                staged?.deleteRecursively()
                startupThread = null
                Thread.interrupted()
            }
        }
    }

    private fun stopRuntime(reason: String, restart: Boolean = false, error: Boolean = false) {
        val stopRevision = SingboxController.externalStopRevision
        val stopGeneration: Long
        synchronized(lifecycle) {
            if (!session.isActive && runtimeProcess == null) {
                if (owner === this) owner = null
                main.post { stopSelf() }
                return
            }
            if (!restart) restartAfterStop = false
            stopGeneration = session.beginStop() ?: return
            restartAfterStop = restart
            runtimeProcess?.closeLease()
            startupThread?.takeIf { it !== Thread.currentThread() }?.interrupt()
            MeowApplication.clearRuntimeIntent()
        }
        executor.execute {
            val child = runtimeProcess
            val stopped = child?.stop() ?: true
            if (!stopped) {
                SingboxController.log("error", "root stop not confirmed; retaining runtime ownership")
                session.markStopUnconfirmed(stopGeneration)
                main.post {
                    SingboxController.setRunning(false, error = "root_cleanup_unconfirmed")
                    if (!destroyed) showForeground("Stopping")
                }
                return@execute
            }
            main.post {
                synchronized(lifecycle) {
                    if (!session.markStopped(stopGeneration)) return@post
                    runtimeProcess = null
                    SingboxController.markServiceStopped(runtimeGeneration, reason)
                    runtimeGeneration = 0
                    MeowApplication.clearServiceState()
                    MeowDefaultNetworkMonitor.stop()
                }
                foregroundNotification.stopAndClear()
                MeowQuickSettingsTileService.requestRefresh(this)
                if (error) SingboxController.setRunning(false, error = reason)
                if (!destroyed && restartAfterStop && stopRevision == SingboxController.externalStopRevision && RootModuleManager.enabled(this)) {
                    beginStart(Intent(this, RootRuntimeService::class.java).setAction(MeowBoxService.ACTION_START)
                        .putExtra(MeowBoxService.EXTRA_EXPECTED_EXTERNAL_STOP_REVISION, stopRevision))
                } else {
                    if (owner === this) owner = null
                    stopSelf()
                    if (destroyed) executor.shutdown()
                }
            }
        }
    }

    private fun failWithoutOwner(code: String) {
        if (!SingboxController.running) SingboxController.setRunning(false, error = code)
        stopSelf()
    }

    private fun showForeground(status: String) {
        val notification = foregroundNotification.buildForForeground(status)
        if (Build.VERSION.SDK_INT >= 34) startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(NOTIFICATION_ID, notification)
    }

    override fun onDestroy() {
        destroyed = true
        if (session.isActive) stopRuntime("service_destroyed")
        else {
            if (owner === this) owner = null
            executor.shutdown()
        }
        super.onDestroy()
    }
}
