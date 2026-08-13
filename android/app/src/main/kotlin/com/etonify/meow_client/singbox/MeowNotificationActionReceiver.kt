package com.etonify.meow_client.singbox

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.etonify.meow_client.MeowApplication
import com.etonify.meow_client.MeowQuickSettingsTileService

/**
 * Handles notification buttons without starting a VPN Service just to deliver
 * an action. This matters when Android still displays a stale notification
 * after the runtime has already gone away.
 */
class MeowNotificationActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_REFRESH_LATENCY = "com.etonify.meow_client.singbox.NOTIFICATION_REFRESH_LATENCY"
        const val ACTION_STOP_RUNTIME = "com.etonify.meow_client.singbox.NOTIFICATION_STOP"

        fun pendingIntent(
            context: Context,
            action: String,
            requestCode: Int,
        ): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                requestCode,
                Intent(context, MeowNotificationActionReceiver::class.java).setAction(action),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val pendingResult = goAsync()
        val applicationContext = context.applicationContext
        when (notificationActionDecision(intent?.action, MeowBoxService.hasActiveRuntimeOwner())) {
            NotificationActionDecision.REFRESH_ACTIVE_RUNTIME -> {
                val accepted = MeowBoxService.requestNotificationLatencyRefresh()
                MeowDiagnostics.log(
                    "NotificationAction",
                    "refresh accepted=$accepted running=${SingboxController.running}",
                )
                pendingResult.finish()
            }
            NotificationActionDecision.STOP_ACTIVE_RUNTIME -> {
                MeowApplication.clearRuntimeIntent()
                MeowVpnService.cancelScheduledRestart(applicationContext, "notification_stop")
                MeowBoxService.requestStopAll("notification_stop")
                SingboxController.awaitStopped(4_000L) { stopped ->
                    if (stopped) {
                        clearStaleNotification(applicationContext, "notification_stop_confirmed")
                    } else {
                        MeowDiagnostics.log(
                            "NotificationAction",
                            "stop remains unconfirmed; retaining foreground notification",
                        )
                    }
                    pendingResult.finish()
                }
            }
            NotificationActionDecision.CLEAR_STALE_NOTIFICATION -> {
                clearStaleNotification(applicationContext, "notification_stale_action")
                pendingResult.finish()
            }
            NotificationActionDecision.IGNORE_STALE_ACTION -> {
                MeowDiagnostics.log(
                    "NotificationAction",
                    "ignored action from a stale notification action=${intent?.action}",
                )
                pendingResult.finish()
            }
        }
    }

    private fun clearStaleNotification(context: Context, reason: String) {
        MeowVpnService.cancelScheduledRestart(context, reason)
        context.stopService(Intent(context, MeowVpnService::class.java))
        context.stopService(Intent(context, MeowProxyService::class.java))
        MeowDefaultNetworkMonitor.stop()
        if (SingboxController.running && !MeowBoxService.hasActiveRuntimeOwner()) {
            // With no foreground service in this process there is no live
            // runtime owner left to clean up; do not keep a stale UI state.
            SingboxController.forceMarkServiceStopped(reason)
        }
        MeowApplication.clearServiceState()
        MeowApplication.clearRuntimeIntent()
        MeowForegroundNotification.clearPersistedState(context, NOTIFICATION_ID)
        MeowQuickSettingsTileService.requestRefresh(context)
        MeowDiagnostics.log("NotificationAction", "cleared stale notification reason=$reason")
    }

}

private const val NOTIFICATION_ID = 42

internal enum class NotificationActionDecision {
    REFRESH_ACTIVE_RUNTIME,
    STOP_ACTIVE_RUNTIME,
    CLEAR_STALE_NOTIFICATION,
    IGNORE_STALE_ACTION,
}

internal fun notificationActionDecision(
    action: String?,
    hasActiveRuntimeOwner: Boolean,
): NotificationActionDecision = when {
    action == MeowNotificationActionReceiver.ACTION_REFRESH_LATENCY && hasActiveRuntimeOwner ->
        NotificationActionDecision.REFRESH_ACTIVE_RUNTIME
    action == MeowNotificationActionReceiver.ACTION_STOP_RUNTIME && hasActiveRuntimeOwner ->
        NotificationActionDecision.STOP_ACTIVE_RUNTIME
    action == MeowNotificationActionReceiver.ACTION_STOP_RUNTIME ->
        NotificationActionDecision.CLEAR_STALE_NOTIFICATION
    else -> NotificationActionDecision.IGNORE_STALE_ACTION
}
