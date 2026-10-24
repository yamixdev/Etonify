package com.etonify.meow_client

import android.content.Intent
import android.os.Looper
import com.etonify.meow_client.singbox.MeowVpnService
import com.etonify.meow_client.singbox.RuntimeServiceModeResolver
import com.etonify.meow_client.singbox.SingboxController
import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import org.robolectric.shadows.ShadowProcess
import org.robolectric.util.ReflectionHelpers

@RunWith(RobolectricTestRunner::class)
@Config(application = MeowApplication::class, sdk = [28], manifest = Config.NONE)
@LooperMode(LooperMode.Mode.PAUSED)
class QuickTileStopCleanupTest {
    private lateinit var tile: MeowQuickSettingsTileService

    @Before
    fun setUp() {
        ShadowProcess.setPid(12_345)
        tile = Robolectric.buildService(MeowQuickSettingsTileService::class.java).create().get()
        MeowApplication.clearRuntimeIntent()
        MeowApplication.clearServiceState()
        ReflectionHelpers.setField(SingboxController, "running", false)
    }

    @Test
    fun `old stop callback preserves a newer start waiting for network`() {
        stopFromTile()
        val token = SingboxController.nextStartToken("test_start_waiting_for_network")
        SingboxController.writeIntentForStartToken(token, "vpn", "test_start_waiting_for_network")
        MeowApplication.writeServiceState("vpn")
        val newIntent = MeowApplication.readRuntimeIntent()
        assertNotNull(newIntent)
        assertNotNull(MeowApplication.readServiceState())

        runCleanup()

        assertFalse(SingboxController.running)
        assertEquals(newIntent, MeowApplication.readRuntimeIntent())
        assertNotNull(MeowApplication.readServiceState())
        assertNull(shadowOf(MeowApplication.application).nextStoppedService)
    }

    @Test
    fun `old stop callback preserves a newer start before it writes intent`() {
        stopFromTile()
        SingboxController.nextStartToken("test_start_queued")
        MeowApplication.writeServiceState("vpn")
        assertNotNull(MeowApplication.readServiceState())

        runCleanup()

        assertNotNull(MeowApplication.readServiceState())
        assertNull(shadowOf(MeowApplication.application).nextStoppedService)
    }

    @Test
    fun `old stop callback preserves a tile start still queued in Android`() {
        stopFromTile()
        ReflectionHelpers.callInstanceMethod<Void>(
            tile,
            "startRuntimeService",
            ReflectionHelpers.ClassParameter.from(String::class.java, "vpn"),
        )
        MeowApplication.writeServiceState("vpn")
        assertNotNull(MeowApplication.readServiceState())

        runCleanup()

        assertNotNull(MeowApplication.readServiceState())
        assertNull(shadowOf(MeowApplication.application).nextStoppedService)
    }

    @Test
    fun `old stop callback preserves an activity start before Android dispatch`() {
        stopFromTile()
        val activity = Robolectric.buildActivity(MainActivity::class.java).get()
        ReflectionHelpers.callInstanceMethod<Intent>(
            activity,
            "runtimeStartIntent",
            ReflectionHelpers.ClassParameter.from(Class::class.java, MeowVpnService::class.java),
            ReflectionHelpers.ClassParameter.from(Long::class.javaObjectType, null),
        )
        MeowApplication.writeServiceState("vpn")
        assertNotNull(MeowApplication.readServiceState())

        runCleanup()

        assertNotNull(MeowApplication.readServiceState())
        assertNull(shadowOf(MeowApplication.application).nextStoppedService)
    }

    @Test
    fun `stopped runtime without a newer start is cleaned up`() {
        MeowApplication.writeServiceState("vpn")
        MeowApplication.writeRuntimeIntent("vpn", "old_start")
        assertNotNull(MeowApplication.readServiceState())
        assertNotNull(MeowApplication.readRuntimeIntent())
        stopFromTile()

        runCleanup()

        assertNull(MeowApplication.readRuntimeIntent())
        assertNull(MeowApplication.readServiceState())
        val stopped = generateSequence { shadowOf(MeowApplication.application).nextStoppedService }
            .map { it.component!!.className.substringAfterLast('.') }.toList()
        assertEquals(listOf("MeowVpnService", "MeowProxyService", "MeowProbeService"), stopped)
    }

    private fun stopFromTile() {
        ReflectionHelpers.callInstanceMethod<Void>(
            tile,
            "stopRuntime",
            ReflectionHelpers.ClassParameter.from(String::class.java, RuntimeServiceModeResolver.VPN),
        )
    }

    private fun runCleanup() {
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(1_200L))
    }
}
