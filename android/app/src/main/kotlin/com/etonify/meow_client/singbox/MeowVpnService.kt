package com.etonify.meow_client.singbox

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Network
import android.net.VpnService
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import com.etonify.meow_client.MeowApplication
import java.net.Socket

class MeowVpnService : VpnService() {
    companion object {
        private const val TAG = "MeowVpnService"
        private const val WAKE_LOCK_TAG = "meow:vpn"
        private const val RESTART_REQUEST_CODE = 1
        @Volatile
        private var currentService: MeowVpnService? = null

        fun protectSocket(socket: Socket): Boolean {
            return currentService?.protect(socket) == true
        }

        fun setUnderlyingNetwork(network: Network?, reason: String): Boolean {
            val service = currentService
            if (service == null) {
                MeowDiagnostics.log(TAG, "underlying_network_skipped reason=$reason service=null")
                return false
            }
            return runCatching {
                val applied = service.setUnderlyingNetworks(network?.let { arrayOf(it) })
                if (!applied) {
                    Log.w(TAG, "setUnderlyingNetworks rejected reason=$reason network=$network")
                    MeowDiagnostics.log(
                        TAG,
                        "underlying_network_rejected reason=$reason network=$network",
                    )
                    if (network != null) {
                        // Do not leave a dead Wi-Fi network pinned after Android
                        // rejects the requested cellular network. Returning to
                        // system-managed selection is the safest fallback.
                        val fallbackApplied = service.setUnderlyingNetworks(null)
                        MeowDiagnostics.log(
                            TAG,
                            "underlying_network_fallback_default reason=$reason " +
                                "applied=$fallbackApplied",
                        )
                        return@runCatching fallbackApplied
                    }
                    return@runCatching false
                }
                MeowDiagnostics.log(
                    TAG,
                    if (network == null) {
                        "underlying_network_lost reason=$reason"
                    } else {
                        "underlying_network_set reason=$reason network=$network"
                    },
                )
                true
            }.getOrElse {
                Log.w(TAG, "setUnderlyingNetworks failed reason=$reason", it)
                MeowDiagnostics.log(TAG, "underlying_network_failed reason=$reason error=${it.message}")
                false
            }
        }

        /**
         * Network callbacks are delivered while Flutter can be paused or its
         * event sink detached. Keep recovery owned by the VPN foreground
         * service so Wi-Fi/mobile handovers do not require reopening Etonify.
         */
        fun requestRuntimeRecoveryAfterNetworkChange(reason: String) {
            val service = currentService ?: return
            val boxService = runCatching { service.boxService }.getOrNull()
                ?: return
            boxService.requestRuntimeRecovery("network_change:$reason")
        }

        fun cancelScheduledRestart(context: Context, reason: String) {
            val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            val restartIntent = Intent(context, MeowVpnService::class.java)
                .setAction(MeowBoxService.ACTION_START)
            val pending = PendingIntent.getForegroundService(
                context,
                RESTART_REQUEST_CODE,
                restartIntent,
                flags,
            ) ?: return
            runCatching {
                val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                alarm.cancel(pending)
                pending.cancel()
                MeowDiagnostics.log(TAG, "scheduled_restart_cancelled reason=$reason")
            }.onFailure {
                Log.w(TAG, "cancelScheduledRestart failed reason=$reason", it)
            }
        }
    }

    private lateinit var boxService: MeowBoxService
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "onCreate")
        MeowDiagnostics.log(TAG, "onCreate")
        boxService = MeowBoxService(
            this,
            MeowVpnPlatformInterface(this),
        )
        currentService = this
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand action=${intent?.action}")
        MeowDiagnostics.log(TAG, "onStartCommand action=${intent?.action} startId=$startId")
        return boxService.onStartCommand(intent, startId)
    }

    override fun onBind(intent: Intent): IBinder? {
        return super.onBind(intent)
    }

    override fun onDestroy() {
        Log.i(TAG, "onDestroy")
        MeowDiagnostics.log(TAG, "onDestroy")
        try {
            if (currentService === this) {
                setUnderlyingNetwork(null, "service_onDestroy")
            }
            if (::boxService.isInitialized) {
                boxService.onDestroy()
            }
        } finally {
            if (
                VpnServiceLifecyclePolicy.shouldCancelScheduledRestartOnDestroy(
                    runtimeRunning = SingboxController.running,
                )
            ) {
                cancelScheduledRestart("service_destroyed_runtime_stopped")
            }
            releaseWakeLock()
            if (currentService === this) {
                currentService = null
            }
            super.onDestroy()
        }
    }

    override fun onRevoke() {
        Log.w(TAG, "onRevoke")
        MeowDiagnostics.log(TAG, "onRevoke")
        MeowApplication.clearRuntimeIntent()
        cancelScheduledRestart("vpn_permission_revoked")
        try {
            if (::boxService.isInitialized) {
                boxService.serviceStop()
            }
        } finally {
            super.onRevoke()
        }
    }

    @SuppressLint("WakelockTimeout")
    private fun acquireWakeLock() {
        if (wakeLock != null) {
            SingboxController.log("debug", "wakelock acquire skipped: already held tag=$WAKE_LOCK_TAG")
            return
        }
        if (!MeowApplication.wakeLockEnabled) {
            SingboxController.log(
                "info",
                "wakelock disabled: keeping VPN core active without partial wakelock tag=$WAKE_LOCK_TAG",
            )
            return
        }
        runCatching {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG).apply {
                setReferenceCounted(false)
                acquire()
            }
            SingboxController.log("info", "wakelock acquired tag=$WAKE_LOCK_TAG")
        }.onFailure {
            Log.w(TAG, "acquireWakeLock failed", it)
            SingboxController.log("error", "wakelock acquire failed tag=$WAKE_LOCK_TAG error=${it.message}")
        }
    }

    private fun releaseWakeLock() {
        val lock = wakeLock ?: return
        wakeLock = null
        runCatching {
            val wasHeld = lock.isHeld
            if (wasHeld) lock.release()
            SingboxController.log("info", "wakelock released tag=$WAKE_LOCK_TAG wasHeld=$wasHeld")
        }.onFailure {
            Log.w(TAG, "releaseWakeLock failed", it)
            SingboxController.log("error", "wakelock release failed tag=$WAKE_LOCK_TAG error=${it.message}")
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        val action = VpnServiceLifecyclePolicy.taskRemovalAction(
            runtimeRunning = SingboxController.running,
            activeRuntimeOwner = MeowBoxService.hasActiveRuntimeOwner("vpn"),
        )
        if (action == VpnTaskRemovalAction.STOP_LINGERING_SERVICE) {
            Log.i(TAG, "onTaskRemoved – runtime is stopped; stopping lingering VPN service")
            MeowDiagnostics.log(TAG, "onTaskRemoved – runtime is stopped; stopping lingering VPN service")
            cancelScheduledRestart("task_removed_without_vpn_runtime")
            boxService.requestStop("task_removed_runtime_stopped")
            stopSelf()
            return
        }
        Log.i(TAG, "onTaskRemoved – scheduling service restart")
        MeowDiagnostics.log(TAG, "onTaskRemoved – scheduling service restart")
        boxService.requestRuntimeRecovery("task_removed")
        // Arm a foreground-service recovery so the VPN survives an OEM killing
        // the process together with the task. If the service stayed alive,
        // startInternal() wakes the existing runtime and re-applies its physical
        // upstream without rebuilding TUN.
        val restartIntent = Intent(this, MeowVpnService::class.java)
            .setAction(MeowBoxService.ACTION_START)
        val flags = PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_ONE_SHOT or
            PendingIntent.FLAG_IMMUTABLE
        val pending = PendingIntent.getForegroundService(
            this,
            RESTART_REQUEST_CODE,
            restartIntent,
            flags,
        )
        val alarm = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarm.setAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + 1_000,
            pending,
        )
    }

    private fun cancelScheduledRestart(reason: String) {
        cancelScheduledRestart(this, reason)
    }

}
