package com.etonify.meow_client.singbox

import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.net.NetworkInfo
import com.etonify.meow_client.MeowApplication
import io.nekohasekai.libbox.InterfaceUpdateListener
import java.net.NetworkInterface
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowNetwork
import org.robolectric.shadows.ShadowNetworkInfo
import org.robolectric.util.ReflectionHelpers

@RunWith(RobolectricTestRunner::class)
@Config(application = MeowApplication::class, sdk = [28], manifest = Config.NONE)
class DefaultInterfaceReassertTest {
    @After
    fun tearDown() {
        MeowDefaultNetworkMonitor.setListener(null)
        MeowDefaultNetworkMonitor.stop()
    }

    @Test
    fun `post-start reassert dispatches even when the pre-TUN interface is cached`() {
        val updates = AtomicInteger()
        installInterface { updates.incrementAndGet() }
        assertTrue(MeowDefaultNetworkMonitor.currentInterfaceState().available)
        val before = updates.get()
        assertTrue(MeowDefaultNetworkMonitor.reassertDefaultInterfaceAndWait("after_start_or_reload_service"))
        assertTrue("a cached pre-TUN update must not replace post-TUN binding", updates.get() > before)
    }

    @Test
    fun `a failed forced delivery cannot report the old cached interface as success`() {
        val rejectUpdate = AtomicBoolean(false)
        installInterface {
            check(!rejectUpdate.get()) { "forced interface delivery rejected" }
        }
        assertTrue(MeowDefaultNetworkMonitor.currentInterfaceState().available)
        rejectUpdate.set(true)
        assertFalse(MeowDefaultNetworkMonitor.reassertDefaultInterfaceAndWait("after_start_or_reload_service"))
    }

    @Test
    fun `a superseded forced job retries instead of accepting the pre-TUN cache`() {
        val updates = AtomicInteger()
        installInterface { updates.incrementAndGet() }
        val before = updates.get()
        val executor = ReflectionHelpers.getField<ExecutorService>(MeowDefaultNetworkMonitor, "notifyExecutor")
        val generation = ReflectionHelpers.getField<AtomicLong>(MeowDefaultNetworkMonitor, "notifyDebounceGeneration")
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val caller = Executors.newSingleThreadExecutor()
        executor.submit { entered.countDown(); release.await(3, TimeUnit.SECONDS) }
        try {
            assertTrue(entered.await(1, TimeUnit.SECONDS))
            val initial = generation.get()
            val result = caller.submit<Boolean> {
                MeowDefaultNetworkMonitor.reassertDefaultInterfaceAndWait("after_start_or_reload_service", 2500)
            }
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(1)
            while (generation.get() == initial && System.nanoTime() < deadline) Thread.yield()
            assertTrue("the requested reassert job was queued", generation.get() > initial)
            // Same invalidation performed by a concurrently arriving callback.
            generation.incrementAndGet()
            release.countDown()
            assertTrue(result.get(3, TimeUnit.SECONDS))
            assertTrue("the superseded job must be retried, not replaced by cache", updates.get() > before)
        } finally {
            release.countDown()
            caller.shutdownNow()
        }
    }

    private fun installInterface(onUpdate: () -> Unit) {
        val connectivity = MeowApplication.connectivity
        val shadow = shadowOf(connectivity)
        shadow.clearAllNetworks()
        val network = ShadowNetwork.newInstance(101)
        val info = ShadowNetworkInfo.newInstance(
            NetworkInfo.DetailedState.CONNECTED, ConnectivityManager.TYPE_WIFI, 0, true, true,
        )
        shadow.addNetwork(network, info)
        shadow.setNetworkCapabilities(network, NetworkCapabilities().apply {
            addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        })
        val physical = NetworkInterface.getNetworkInterfaces().toList().first { it.index >= 0 }
        shadow.setLinkProperties(network, LinkProperties().apply { interfaceName = physical.name })
        MeowDefaultNetworkMonitor.setListener(object : InterfaceUpdateListener {
            override fun updateNetworkPath(networkPath: String?) = Unit
            override fun updateDefaultInterface(name: String?, index: Int, expensive: Boolean, constrained: Boolean) {
                onUpdate()
            }
        })
    }
}
