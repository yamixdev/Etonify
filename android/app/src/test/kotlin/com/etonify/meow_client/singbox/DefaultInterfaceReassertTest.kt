package com.etonify.meow_client.singbox

import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.net.NetworkInfo
import android.net.Network
import android.net.VpnService
import com.etonify.meow_client.MeowApplication
import com.etonify.meow_client.root.RootRuntimeService
import com.etonify.meow_client.root.RootRuntimeSession
import java.net.InetAddress
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
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Robolectric
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implements
import org.robolectric.annotation.Implementation
import org.robolectric.shadows.ShadowNetwork
import org.robolectric.shadows.ShadowNetworkInfo
import org.robolectric.util.ReflectionHelpers

@RunWith(RobolectricTestRunner::class)
@Config(application = MeowApplication::class, sdk = [28], manifest = Config.NONE,
    shadows = [DefaultInterfaceReassertTest.BindingShadow::class])
class DefaultInterfaceReassertTest {
    @Test fun `root monitor dispatches without app-side libbox listener including DNS-only updates`() {
        installInterface { }
        MeowDefaultNetworkMonitor.setListener(null)
        val service = Robolectric.buildService(RootRuntimeService::class.java).create().get()
        val session = ReflectionHelpers.getField<RootRuntimeSession>(service, "session")
        session.markReady(session.beginStart(0)!!, 0)
        val generation = ReflectionHelpers.getField<AtomicLong>(MeowDefaultNetworkMonitor, "networkInterfaceGeneration")
        val worker = ReflectionHelpers.getField<ExecutorService>(MeowDefaultNetworkMonitor, "notifyExecutor")
        try {
            val before = generation.get()
            MeowDefaultNetworkMonitor.reassertDefaultInterface("root_test")
            shadowOf(android.os.Looper.getMainLooper()).idle()
            val networkHandler = ReflectionHelpers.getField<android.os.Handler>(MeowDefaultNetworkMonitor, "networkHandler")
            shadowOf(networkHandler.looper).idle()
            worker.submit {}.get(3, TimeUnit.SECONDS)
            assertTrue("root path must be reached without a platform listener", generation.get() > before)
            val current = generation.get()
            val shadow = shadowOf(MeowApplication.connectivity)
            val network = ShadowNetwork.newInstance(101)
            val properties = MeowApplication.connectivity.getLinkProperties(network)!!
            LinkProperties::class.java.getDeclaredMethod("setDnsServers", Collection::class.java)
                .apply { isAccessible = true }.invoke(properties, listOf(InetAddress.getByName("192.168.1.1")))
            shadow.setLinkProperties(network, properties)
            val notifyGeneration = ReflectionHelpers.getField<AtomicLong>(MeowDefaultNetworkMonitor, "notifyDebounceGeneration")
            val method = MeowDefaultNetworkMonitor::class.java.getDeclaredMethod("notifyListenerInternal", java.lang.Long.TYPE, Network::class.java, java.lang.Boolean.TYPE).apply { isAccessible = true }
            method.invoke(MeowDefaultNetworkMonitor, notifyGeneration.incrementAndGet(), network, false)
            assertTrue("DNS-only changes must not be treated as duplicates", generation.get() > current)
        } finally {
            ReflectionHelpers.setStaticField(RootRuntimeService::class.java, "owner", null)
        }
    }
    private var originalRetryDelays: LongArray? = null
    @Implements(VpnService::class)
    class BindingShadow {
        companion object {
            @Volatile var accept = true
            @Volatile var acceptFallback = false
            @Volatile var lastExplicitNetwork: Network? = null
            val attempts = AtomicInteger()
        }

        @Implementation
        fun setUnderlyingNetworks(networks: Array<Network>?): Boolean {
            attempts.incrementAndGet()
            if (networks != null) lastExplicitNetwork = networks.firstOrNull()
            return accept || (networks == null && acceptFallback)
        }
    }

    @After
    fun tearDown() {
        MeowDefaultNetworkMonitor.setListener(null)
        MeowDefaultNetworkMonitor.stop()
        ReflectionHelpers.setStaticField(MeowVpnService::class.java, "currentService", null)
        BindingShadow.accept = true
        BindingShadow.acceptFallback = false
        BindingShadow.lastExplicitNetwork = null
        BindingShadow.attempts.set(0)
        originalRetryDelays?.let { saved ->
            val delays = ReflectionHelpers.getField<LongArray>(MeowDefaultNetworkMonitor, "interfaceRetryDelaysMillis")
            saved.copyInto(delays)
        }
    }

    @Test
    fun `rejected Android binding is not reported ready despite successful core delivery`() {
        installVpnOwner()
        BindingShadow.accept = false
        val updates = AtomicInteger()
        installInterface { updates.incrementAndGet() }

        assertTrue("libbox still needs the physical interface before TUN establishment", updates.get() > 0)
        assertFalse("a failed Android binding must not report ready", MeowDefaultNetworkMonitor.currentInterfaceState().available)
        assertFalse(MeowDefaultNetworkMonitor.reassertDefaultInterfaceAndWait("rejected", 300))
    }

    @Test
    fun `callback during handover delivery cannot suppress recovery of scan readiness`() {
        installVpnOwner()
        val supersede = AtomicBoolean(false)
        val updates = AtomicInteger()
        val generation = ReflectionHelpers.getField<AtomicLong>(MeowDefaultNetworkMonitor, "notifyDebounceGeneration")
        installInterface {
            updates.incrementAndGet()
            if (supersede.compareAndSet(true, false)) generation.incrementAndGet()
        }
        assertTrue(MeowDefaultNetworkMonitor.currentInterfaceState().available)
        val beforeGeneration = MeowDefaultNetworkMonitor.currentInterfaceState().generation
        val shadow = shadowOf(MeowApplication.connectivity)
        shadow.clearAllNetworks()
        val nextNetwork = ShadowNetwork.newInstance(202)
        shadow.addNetwork(nextNetwork, ShadowNetworkInfo.newInstance(
            NetworkInfo.DetailedState.CONNECTED, ConnectivityManager.TYPE_MOBILE, 0, true, true,
        ))
        val capabilities = NetworkCapabilities()
        shadowOf(capabilities).apply {
            addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        }
        shadow.setNetworkCapabilities(nextNetwork, capabilities)
        val physical = NetworkInterface.getNetworkInterfaces().toList().first { it.index >= 0 }
        shadow.setLinkProperties(nextNetwork, LinkProperties().apply { interfaceName = physical.name })
        assertFalse(MeowDefaultNetworkMonitor.currentInterfaceState().available)
        val beforeUpdates = updates.get()
        supersede.set(true)
        assertFalse(deliverOrdinaryInterfaceUpdate(generation.get()))
        assertTrue("a superseding callback must retry an uncommitted handover", deliverOrdinaryInterfaceUpdate(generation.get()))
        assertTrue("URLTest can start again only after native delivery is committed", MeowDefaultNetworkMonitor.currentInterfaceState().available)
        assertTrue(MeowDefaultNetworkMonitor.currentInterfaceState().generation > beforeGeneration)
        assertEquals(beforeUpdates + 2, updates.get())
        repeat(10) { assertTrue(deliverOrdinaryInterfaceUpdate(generation.get())) }
        assertEquals("committed duplicates must not keep resetting connections", beforeUpdates + 2, updates.get())
    }

    private fun deliverOrdinaryInterfaceUpdate(generation: Long): Boolean =
        ReflectionHelpers.callInstanceMethod(
            MeowDefaultNetworkMonitor,
            "notifyListenerInternal",
            ReflectionHelpers.ClassParameter.from(Long::class.javaPrimitiveType, generation),
            ReflectionHelpers.ClassParameter.from(Network::class.java, null),
            ReflectionHelpers.ClassParameter.from(Boolean::class.javaPrimitiveType, false),
        )

    @Test
    fun `failed forced binding clears previously ready interface`() {
        installVpnOwner()
        installInterface {}
        assertTrue(MeowDefaultNetworkMonitor.currentInterfaceState().available)
        BindingShadow.accept = false

        assertFalse(MeowDefaultNetworkMonitor.reassertDefaultInterfaceAndWait("binding_lost", 300))
        assertFalse(MeowDefaultNetworkMonitor.currentInterfaceState().available)
    }

    private fun installVpnOwner() {
        val service = Robolectric.buildService(MeowVpnService::class.java).get()
        // Do not start JNI. This is the same native owner used by monitor binding.
        ReflectionHelpers.setStaticField(MeowVpnService::class.java, "currentService", service)
    }

    @Test
    fun `system managed fallback does not acknowledge rejected explicit binding`() {
        installVpnOwner()
        BindingShadow.accept = false
        BindingShadow.acceptFallback = true
        installInterface {}
        assertFalse(MeowDefaultNetworkMonitor.currentInterfaceState().available)
    }

    @Test
    fun `rejected binding is retried in background without an Activity`() {
        installVpnOwner()
        BindingShadow.accept = false
        installInterface {}
        BindingShadow.accept = true
        drainPendingInterfaceJobs()

        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(3)
        while (!MeowDefaultNetworkMonitor.currentInterfaceState().available && System.nanoTime() < deadline) {
            Thread.sleep(10)
        }
        assertTrue("native retries must recover without Flutter", MeowDefaultNetworkMonitor.currentInterfaceState().available)
    }

    private fun drainPendingInterfaceJobs() {
        val handler = ReflectionHelpers.getField<android.os.Handler>(MeowDefaultNetworkMonitor, "networkHandler")
        shadowOf(handler.looper).idle()
        val executor = ReflectionHelpers.getField<ExecutorService>(MeowDefaultNetworkMonitor, "notifyExecutor")
        executor.submit {}.get(2, TimeUnit.SECONDS)
    }

    @Test
    fun `stop cancels pending native retry even when listener has not detached yet`() {
        installVpnOwner()
        MeowDefaultNetworkMonitor.start()
        BindingShadow.accept = false
        installInterface {}
        drainPendingInterfaceJobs()
        MeowDefaultNetworkMonitor.stop()
        val afterStop = BindingShadow.attempts.get()
        Thread.sleep(400)
        assertEquals(afterStop, BindingShadow.attempts.get())
    }

    @Test
    fun `failed binding retries end instead of looping indefinitely`() {
        val delays = ReflectionHelpers.getField<LongArray>(MeowDefaultNetworkMonitor, "interfaceRetryDelaysMillis")
        originalRetryDelays = delays.clone()
        delays.fill(50)
        installVpnOwner()
        BindingShadow.accept = false
        installInterface {}
        drainPendingInterfaceJobs()
        val afterInitial = BindingShadow.attempts.get()
        Thread.sleep(550)
        val afterRetries = BindingShadow.attempts.get()
        assertEquals("six retries, each with explicit binding and safe fallback", afterInitial + 12, afterRetries)
        Thread.sleep(200)
        assertEquals(afterRetries, BindingShadow.attempts.get())
        assertFalse(MeowDefaultNetworkMonitor.currentInterfaceState().available)
    }

    @Test
    fun `late link properties recover without another Android callback`() {
        installVpnOwner()
        installInterface(includeLinkProperties = false) {}
        drainPendingInterfaceJobs()
        assertFalse(MeowDefaultNetworkMonitor.currentInterfaceState().available)
        val network = ShadowNetwork.newInstance(101)
        val physical = NetworkInterface.getNetworkInterfaces().toList().first { it.index >= 0 }
        shadowOf(MeowApplication.connectivity).setLinkProperties(network, LinkProperties().apply { interfaceName = physical.name })
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(3)
        while (!MeowDefaultNetworkMonitor.currentInterfaceState().available && System.nanoTime() < deadline) Thread.sleep(10)
        assertTrue(MeowDefaultNetworkMonitor.currentInterfaceState().available)
    }

    @Test
    fun `listener replacement cancels retries belonging to the old listener`() {
        installVpnOwner()
        BindingShadow.accept = false
        val oldUpdates = AtomicInteger()
        installInterface { oldUpdates.incrementAndGet() }
        drainPendingInterfaceJobs()
        BindingShadow.accept = true
        val newUpdates = AtomicInteger()
        installInterface { newUpdates.incrementAndGet() }
        val oldUpdatesAfterReplacement = oldUpdates.get()
        Thread.sleep(400)
        drainPendingInterfaceJobs()
        assertEquals(oldUpdatesAfterReplacement, oldUpdates.get())
        assertTrue(newUpdates.get() > 0)
        assertTrue(MeowDefaultNetworkMonitor.currentInterfaceState().available)
    }

    @Test
    fun `pending retry resolves the new physical network instead of its captured network`() {
        installVpnOwner()
        BindingShadow.accept = false
        installInterface {}
        drainPendingInterfaceJobs()
        val shadow = shadowOf(MeowApplication.connectivity)
        shadow.clearAllNetworks()
        val nextNetwork = ShadowNetwork.newInstance(202)
        val info = ShadowNetworkInfo.newInstance(
            NetworkInfo.DetailedState.CONNECTED, ConnectivityManager.TYPE_MOBILE, 0, true, true,
        )
        shadow.addNetwork(nextNetwork, info)
        val capabilities = NetworkCapabilities()
        shadowOf(capabilities).apply {
            addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        }
        shadow.setNetworkCapabilities(nextNetwork, capabilities)
        val physical = NetworkInterface.getNetworkInterfaces().toList().first { it.index >= 0 }
        shadow.setLinkProperties(nextNetwork, LinkProperties().apply { interfaceName = physical.name })
        BindingShadow.accept = true
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(3)
        while (!MeowDefaultNetworkMonitor.currentInterfaceState().available && System.nanoTime() < deadline) Thread.sleep(10)
        assertTrue(MeowDefaultNetworkMonitor.currentInterfaceState().available)
        assertEquals(nextNetwork, BindingShadow.lastExplicitNetwork)
    }

    @Test
    fun `post TUN rejection keeps native recovery alive until delayed binding succeeds`() {
        installVpnOwner()
        installInterface {}
        BindingShadow.accept = false
        BindingShadow.acceptFallback = true
        assertFalse(MeowDefaultNetworkMonitor.reassertDefaultInterfaceAfterStart())
        drainPendingInterfaceJobs()
        Thread.sleep(500)
        BindingShadow.accept = true
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(3)
        while (!MeowDefaultNetworkMonitor.currentInterfaceState().available && System.nanoTime() < deadline) Thread.sleep(10)
        assertTrue("post-TUN binding rejection must not cancel background recovery", MeowDefaultNetworkMonitor.currentInterfaceState().available)
    }

    @Test
    fun `post TUN retry exhaustion stays not ready and does not loop`() {
        val delays = ReflectionHelpers.getField<LongArray>(MeowDefaultNetworkMonitor, "interfaceRetryDelaysMillis")
        originalRetryDelays = delays.clone()
        delays.fill(50)
        installVpnOwner()
        installInterface {}
        BindingShadow.accept = false
        assertFalse(MeowDefaultNetworkMonitor.reassertDefaultInterfaceAfterStart())
        drainPendingInterfaceJobs()
        Thread.sleep(550)
        val exhaustedAttempts = BindingShadow.attempts.get()
        Thread.sleep(200)
        assertEquals(exhaustedAttempts, BindingShadow.attempts.get())
        assertFalse(MeowDefaultNetworkMonitor.currentInterfaceState().available)
    }

    @Test
    fun `user stop cancels post TUN binding recovery`() {
        installVpnOwner()
        MeowDefaultNetworkMonitor.start()
        installInterface {}
        BindingShadow.accept = false
        assertFalse(MeowDefaultNetworkMonitor.reassertDefaultInterfaceAfterStart())
        drainPendingInterfaceJobs()
        MeowDefaultNetworkMonitor.stop()
        val stoppedAttempts = BindingShadow.attempts.get()
        BindingShadow.accept = true
        Thread.sleep(400)
        drainPendingInterfaceJobs()
        assertEquals(stoppedAttempts, BindingShadow.attempts.get())
        assertFalse(MeowDefaultNetworkMonitor.currentInterfaceState().available)
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

    private fun installInterface(includeLinkProperties: Boolean = true, onUpdate: () -> Unit) {
        val connectivity = MeowApplication.connectivity
        val shadow = shadowOf(connectivity)
        shadow.clearAllNetworks()
        val network = ShadowNetwork.newInstance(101)
        val info = ShadowNetworkInfo.newInstance(
            NetworkInfo.DetailedState.CONNECTED, ConnectivityManager.TYPE_WIFI, 0, true, true,
        )
        shadow.addNetwork(network, info)
        val capabilities = NetworkCapabilities()
        shadowOf(capabilities).apply {
            addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        }
        shadow.setNetworkCapabilities(network, capabilities)
        val physical = NetworkInterface.getNetworkInterfaces().toList().first { it.index >= 0 }
        if (includeLinkProperties) shadow.setLinkProperties(network, LinkProperties().apply { interfaceName = physical.name })
        MeowDefaultNetworkMonitor.setListener(object : InterfaceUpdateListener {
            override fun updateNetworkPath(networkPath: String?) = Unit
            override fun updateDefaultInterface(name: String?, index: Int, expensive: Boolean, constrained: Boolean) {
                onUpdate()
            }
        })
    }
}
