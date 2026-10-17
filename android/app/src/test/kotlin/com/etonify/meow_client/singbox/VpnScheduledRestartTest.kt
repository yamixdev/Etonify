package com.etonify.meow_client.singbox

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import com.etonify.meow_client.MeowApplication
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowProcess
import org.robolectric.util.ReflectionHelpers
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit
import java.nio.file.FileSystems
import java.nio.file.StandardWatchEventKinds

@RunWith(RobolectricTestRunner::class)
@Config(application = MeowApplication::class, sdk = [28], manifest = Config.NONE)
class VpnScheduledRestartTest {
    @Test
    fun `explicit stop cancels the one shot foreground restart alarm`() {
        val context = MeowApplication.application
        val pending = PendingIntent.getForegroundService(
            context, 1,
            Intent(context, MeowVpnService::class.java).setAction(MeowBoxService.ACTION_START),
            PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarm.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, 1_000L, pending)

        MeowVpnService.cancelScheduledRestart(context, "test_explicit_stop")

        assertTrue(shadowOf(alarm).scheduledAlarms.isEmpty())
        assertTrue(shadowOf(pending).isCanceled)
    }

    @Test
    fun `delivered recovery start cannot recreate cleared user intent`() {
        withBlockedBox { service, box, _, _ ->
            MeowApplication.clearRuntimeIntent()
            val result = box.onStartCommand(
                Intent(service, MeowVpnService::class.java)
                    .setAction(MeowBoxService.ACTION_START)
                    .putExtra("scheduled_restart", true),
                1,
            )

            assertEquals(Service.START_NOT_STICKY, result)
            assertEquals(null, MeowApplication.readRuntimeIntent())
        }
    }

    @Test
    fun `ordinary user and tile starts remain accepted without an existing runtime intent`() {
        for (tileStart in listOf(false, true)) {
            withBlockedBox { service, box, _, _ ->
                MeowApplication.clearRuntimeIntent()
                assertEquals(Service.START_STICKY, box.onStartCommand(
                    Intent(service, MeowVpnService::class.java)
                        .setAction(MeowBoxService.ACTION_START)
                        .putExtra(MeowBoxService.EXTRA_TILE_START, tileStart),
                    1,
                ))
            }
        }
    }

    @Test
    fun `queued scheduled recovery rechecks runtime intent before starting`() {
        withBlockedBox { service, box, executor, release ->
            MeowApplication.configFile.writeText("{}")
            ShadowProcess.setPid(1234)
            MeowApplication.writeRuntimeIntent("vpn", "test_running")
            assertEquals(Service.START_STICKY, box.onStartCommand(
                Intent(service, MeowVpnService::class.java)
                    .setAction(MeowBoxService.ACTION_START)
                    .putExtra("scheduled_restart", true),
                1,
            ))
            MeowApplication.clearRuntimeIntent()
            FileSystems.getDefault().newWatchService().use { watcher ->
                MeowApplication.runtimeIntentFile.parentFile!!.toPath()
                    .register(watcher, StandardWatchEventKinds.ENTRY_CREATE)
                release.countDown()
                executor.submit {}.get(5, TimeUnit.SECONDS)
                val created = watcher.poll(500, TimeUnit.MILLISECONDS)?.pollEvents().orEmpty()
                    .map { it.context().toString() }
                assertTrue("recovery must not recreate desired runtime state", MeowApplication.runtimeIntentFile.name !in created)
            }
        }
    }

    private fun withBlockedBox(
        block: (MeowVpnService, MeowBoxService, ExecutorService, CountDownLatch) -> Unit,
    ) {
        val service = Robolectric.buildService(MeowVpnService::class.java).get()
        val box = MeowBoxService(service, MeowVpnPlatformInterface(service))
        val executor = ReflectionHelpers.getField<ExecutorService>(box, "executor")
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        executor.execute {
            entered.countDown()
            release.await(10, TimeUnit.SECONDS)
        }
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        try {
            block(service, box, executor, release)
        } finally {
            box.onDestroy()
            release.countDown()
            assertTrue(executor.awaitTermination(10, TimeUnit.SECONDS))
        }
    }
}
