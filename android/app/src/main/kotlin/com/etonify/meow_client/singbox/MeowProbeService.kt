package com.etonify.meow_client.singbox

import android.app.Service
import android.content.Intent
import android.os.IBinder

/** Owns one inbound-free sing-box instance for user-initiated offline URLTest. */
class MeowProbeService : Service() {
    private val boxService by lazy {
        MeowBoxService(this, MeowProxyPlatformInterface(this))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        boxService.onStartCommand(intent, startId)

    override fun onBind(intent: Intent): IBinder? = null

    override fun onDestroy() {
        boxService.onDestroy()
        super.onDestroy()
    }
}
