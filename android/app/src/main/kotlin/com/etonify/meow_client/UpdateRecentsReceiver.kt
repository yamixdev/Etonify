package com.etonify.meow_client

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import com.etonify.meow_client.singbox.MeowDiagnostics

class UpdateRecentsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "UpdateRecentsReceiver"
        // Both the receiver and MainActivity run on the main thread.
        private val openedTaskIds = mutableSetOf<Int>()

        internal fun noteOpenedTask(taskId: Int) {
            openedTaskIds.add(taskId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val activityManager = context.getSystemService(ActivityManager::class.java) ?: return
        for (task in activityManager.appTasks) {
            runCatching {
                val info = task.taskInfo ?: return@runCatching
                val taskId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    info.taskId
                } else {
                    @Suppress("DEPRECATION")
                    info.persistentId
                }
                if (taskId !in openedTaskIds) task.finishAndRemoveTask()
            }.onFailure { error ->
                MeowDiagnostics.log(TAG, "Failed to remove previous app task", error)
            }
        }
    }
}
