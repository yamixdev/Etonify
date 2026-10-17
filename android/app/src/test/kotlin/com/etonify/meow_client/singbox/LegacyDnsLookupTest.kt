package com.etonify.meow_client.singbox

import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkInfo
import android.system.OsConstants
import com.etonify.meow_client.MeowApplication
import io.nekohasekai.libbox.ExchangeContext
import io.nekohasekai.libbox.Func
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowNetwork
import org.robolectric.shadows.ShadowNetworkInfo
import java.net.InetAddress
import java.net.UnknownHostException

@RunWith(RobolectricTestRunner::class)
@Config(application = MeowApplication::class, sdk = [28], manifest = Config.NONE,
    shadows = [LegacyDnsLookupTest.NetworkDnsShadow::class,
        LegacyDnsLookupTest.ExchangeShadow::class, LegacyDnsLookupTest.LibboxShadow::class])
class LegacyDnsLookupTest {
    @Implements(Network::class)
    class NetworkDnsShadow : ShadowNetwork() {
        companion object {
            var requestedHost: String? = null
            var failure: Exception? = null
            var onResolve: (() -> Unit)? = null
        }

        @Implementation
        fun getAllByName(host: String): Array<InetAddress> {
            requestedHost = host
            onResolve?.invoke()
            failure?.let { throw it }
            return arrayOf(InetAddress.getByAddress(byteArrayOf(192.toByte(), 0, 2, 10)),
                InetAddress.getByAddress(ByteArray(16).apply { this[15] = 1 }))
        }
    }

    @Implements(value = Libbox::class, isInAndroidSdk = false)
    class LibboxShadow {
        companion object {
            @JvmStatic @Implementation fun __staticInitializer__() = Unit
        }
    }

    @Implements(value = ExchangeContext::class, isInAndroidSdk = false)
    class ExchangeShadow {
        var answer: String? = null
        var errno: Int? = null
        var rcode: Int? = null
        var cancel: Func? = null
        @Implementation fun __constructor__() = Unit
        @Implementation fun success(result: String) { answer = result }
        @Implementation fun errnoCode(code: Int) { errno = code }
        @Implementation fun errorCode(code: Int) { rcode = code }
        @Implementation fun onCancel(callback: Func) { cancel = callback }
    }

    @Before
    fun setUp() {
        NetworkDnsShadow.requestedHost = null
        NetworkDnsShadow.failure = null
        NetworkDnsShadow.onResolve = null
        val connectivity = shadowOf(MeowApplication.connectivity)
        connectivity.clearAllNetworks()
        val physical = ShadowNetwork.newInstance(101)
        connectivity.addNetwork(physical, ShadowNetworkInfo.newInstance(
            NetworkInfo.DetailedState.CONNECTED, ConnectivityManager.TYPE_WIFI, 0, true, true,
        ))
        val capabilities = NetworkCapabilities()
        shadowOf(capabilities).apply {
            addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        }
        connectivity.setNetworkCapabilities(physical, capabilities)
        val hostInterface = java.net.NetworkInterface.getNetworkInterfaces().toList().first { it.index >= 0 }
        connectivity.setLinkProperties(physical, LinkProperties().apply { interfaceName = hostInterface.name })
    }

    private fun lookup(family: String = "ip"): ExchangeShadow {
        val context = ExchangeContext()
        val resolver = Class.forName("com.etonify.meow_client.singbox.MeowLocalResolver")
            .getDeclaredField("INSTANCE").apply { isAccessible = true }.get(null) as LocalDNSTransport
        resolver.lookup(context, family, "legacy-dns.invalid")
        return org.robolectric.shadow.api.Shadow.extract(context)
    }

    @Test
    fun `legacy lookup resolves through the selected physical network`() {
        val result = lookup()
        assertEquals("legacy-dns.invalid", NetworkDnsShadow.requestedHost)
        assertEquals("192.0.2.10\n0:0:0:0:0:0:0:1", result.answer)
    }

    @Test
    fun `legacy IPv4 query excludes IPv6 answers`() {
        assertEquals("192.0.2.10", lookup("ip4").answer)
    }

    @Test
    fun `legacy IPv6 query excludes IPv4 answers`() {
        assertEquals("0:0:0:0:0:0:0:1", lookup("ip6").answer)
    }

    @Test
    fun `legacy unknown host remains NXDOMAIN`() {
        NetworkDnsShadow.failure = UnknownHostException("not found")
        assertEquals(3, lookup().rcode)
    }

    @Test
    fun `legacy resolver failure remains EIO`() {
        NetworkDnsShadow.failure = IllegalStateException("lookup failed")
        assertEquals(OsConstants.EIO, lookup().errno)
    }

    @Test
    fun `legacy lookup without a physical network fails without default DNS fallback`() {
        shadowOf(MeowApplication.connectivity).clearAllNetworks()
        assertEquals(OsConstants.ENETUNREACH, lookup().errno)
        assertEquals(null, NetworkDnsShadow.requestedHost)
    }

    @Test
    fun `cancelled legacy lookup cannot deliver a later successful answer`() {
        NetworkDnsShadow.onResolve = {
            MeowBasePlatformInterface.cancelPendingDnsQueries("test_cancel")
        }
        val result = lookup()
        assertEquals(OsConstants.ECANCELED, result.errno)
        assertEquals(null, result.answer)
    }
}
