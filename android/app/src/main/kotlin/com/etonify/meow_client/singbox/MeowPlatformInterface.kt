package com.etonify.meow_client.singbox

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.DnsResolver
import android.net.IpPrefix
import android.net.Network
import android.net.NetworkCapabilities
import android.net.ProxyInfo
import android.net.VpnService
import android.os.CancellationSignal
import android.os.Build
import android.os.Process
import android.system.ErrnoException
import android.system.OsConstants
import androidx.annotation.RequiresApi
import com.etonify.meow_client.MeowApplication
import io.nekohasekai.libbox.BridgeOptions
import io.nekohasekai.libbox.BridgeSession
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.ExchangeContext
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NetworkInterface
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.NeighborUpdateListener
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.PlatformUser
import io.nekohasekai.libbox.RoutePrefix
import io.nekohasekai.libbox.RoutePrefixIterator
import io.nekohasekai.libbox.ShellSession
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface as JavaNetworkInterface
import java.net.UnknownHostException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

abstract class MeowBasePlatformInterface(
    protected val context: Context,
) : PlatformInterface {
    override fun autoDetectInterfaceControl(fd: Int) = Unit

    override fun cancelNotification(identifier: String, typeID: Int) {
        // Core-originated notifications are currently mirrored to Etonify's
        // logs only, so there is no Android notification ID to cancel here.
        MeowDiagnostics.log(
            "MeowPlatform",
            "core notification cancelled identifier=$identifier typeID=$typeID",
        )
    }

    override fun checkPlatformShell() {
        throw UnsupportedOperationException("platform shell is not supported on Android")
    }

    override fun clearDNSCache() {
        val cancelled = MeowLocalResolver.cancelPendingQueries()
        MeowDiagnostics.log(
            "MeowPlatform",
            "platform DNS cache cleared by core pendingQueriesCancelled=$cancelled",
        )
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        MeowDefaultNetworkMonitor.setListener(null)
    }

    override fun closeNeighborMonitor(listener: NeighborUpdateListener?) {
        // libbox currently advertises the platform neighbor resolver for every
        // mobile platform. Etonify has no Android ARP/NDP bridge, so keep the
        // lifecycle callback harmless instead of failing ordinary VPN startup.
        MeowDiagnostics.log("MeowPlatform", "neighbor monitor closed (not provided by Android client)")
    }

    override fun createBridge(options: BridgeOptions): BridgeSession {
        throw UnsupportedOperationException("platform bridge is not used by Android VpnService")
    }

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String?,
        sourcePort: Int,
        destinationAddress: String?,
        destinationPort: Int,
    ): ConnectionOwner {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw UnsupportedOperationException("connection owner lookup requires Android 10+")
        }
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        try {
            val uid = connectivity.getConnectionOwnerUid(
                ipProtocol,
                InetSocketAddress(sourceAddress ?: "", sourcePort),
                InetSocketAddress(destinationAddress ?: "", destinationPort),
            )
            if (uid == Process.INVALID_UID) {
                error("android: connection owner not found")
            }
            val packages = context.packageManager.getPackagesForUid(uid)
            val owner = ConnectionOwner()
            owner.userId = uid
            owner.userName = packages?.firstOrNull() ?: ""
            owner.setAndroidPackageNames(SimpleStringIterator(packages.orEmpty().asIterable()))
            return owner
        } catch (error: Exception) {
            MeowDiagnostics.log("MeowPlatform", "getConnectionOwnerUid failed", error)
            throw error
        }
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val javaInterfaces = JavaNetworkInterface.getNetworkInterfaces()?.toList().orEmpty()
        val interfaces = mutableListOf<NetworkInterface>()
        for (network in connectivity.allNetworks) {
            val linkProperties = connectivity.getLinkProperties(network) ?: continue
            val capabilities = connectivity.getNetworkCapabilities(network) ?: continue
            val javaInterface = javaInterfaces.firstOrNull { it.name == linkProperties.interfaceName } ?: continue
            val boxInterface = NetworkInterface().apply {
                index = javaInterface.index
                mtu = runCatching { javaInterface.mtu }.getOrDefault(1500)
                name = javaInterface.name
                addresses = SimpleStringIterator(
                    javaInterface.interfaceAddresses
                        .mapNotNull { interfaceAddress ->
                            val hostAddress = interfaceAddress.address.hostAddress ?: return@mapNotNull null
                            "${hostAddress.substringBefore('%')}/${interfaceAddress.networkPrefixLength}"
                        },
                )
                dnsServer = SimpleStringIterator(linkProperties.dnsServers.mapNotNull { it.hostAddress })
                type = when {
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Libbox.InterfaceTypeCellular
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Libbox.InterfaceTypeEthernet
                    else -> Libbox.InterfaceTypeOther
                }
                metered = !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
                var dumpFlags = 0
                if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                    dumpFlags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
                }
                if (javaInterface.isLoopback) {
                    dumpFlags = dumpFlags or OsConstants.IFF_LOOPBACK
                }
                if (javaInterface.isPointToPoint) {
                    dumpFlags = dumpFlags or OsConstants.IFF_POINTOPOINT
                }
                if (runCatching { javaInterface.supportsMulticast() }.getOrDefault(false)) {
                    dumpFlags = dumpFlags or OsConstants.IFF_MULTICAST
                }
                flags = dumpFlags
            }
            interfaces += boxInterface
        }
        return object : NetworkInterfaceIterator {
            private val iterator = interfaces.iterator()
            override fun hasNext(): Boolean = iterator.hasNext()
            override fun next(): NetworkInterface = iterator.next()
        }
    }

    override fun includeAllNetworks(): Boolean = false

    override fun localDNSTransport(): LocalDNSTransport? = MeowLocalResolver

    override fun lookupSFTPServer(): String {
        throw UnsupportedOperationException("SFTP server lookup is not supported on Android")
    }

    override fun lookupUser(username: String): PlatformUser {
        throw UnsupportedOperationException("platform user lookup is not supported on Android")
    }

    override fun openShellSession(
        user: PlatformUser,
        command: String,
        environ: StringIterator,
        term: String,
        rows: Int,
        cols: Int,
    ): ShellSession {
        throw UnsupportedOperationException("platform shell is not supported on Android")
    }

    override fun readSystemSSHHostKey(): String {
        throw UnsupportedOperationException("system SSH host keys are not available on Android")
    }

    override fun readWIFIState(): WIFIState = WIFIState("", "")

    override fun registerMyInterface(name: String) {
        MeowDiagnostics.log("MeowPlatform", "core registered interface name=$name")
    }

    override fun sendNotification(notification: Notification?) {
        if (notification == null) return
        SingboxController.log("info", notification.title + ": " + notification.body)
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        if (listener != null) {
            MeowDefaultNetworkMonitor.setListener(listener)
        }
    }

    override fun startNeighborMonitor(listener: NeighborUpdateListener?) {
        MeowDiagnostics.log("MeowPlatform", "neighbor monitor skipped (not provided by Android client)")
    }

    override fun tailscaleHostname(): String = ""

    override fun underNetworkExtension(): Boolean = false

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun usePlatformBridge(): Boolean = false

    override fun usePlatformShell(): Boolean = false

    override fun useProcFS(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
}

class MeowVpnPlatformInterface(
    private val service: VpnService,
) : MeowBasePlatformInterface(service) {
    companion object {
        @Volatile
        private var lastTunPackageSummary = "not_opened"

        fun describeLastTunPackages(): String = lastTunPackageSummary
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        val protected = runCatching { service.protect(fd) }.getOrElse { error ->
            MeowDiagnostics.log("MeowVpnPlatform", "protect fd=$fd failed", error)
            throw error
        }
        if (!protected) {
            val error = IllegalStateException("VpnService.protect returned false for fd=$fd")
            MeowDiagnostics.log("MeowVpnPlatform", "protect fd=$fd returned false", error)
            throw error
        }
    }

    override fun openTun(options: TunOptions): Int {
        check(VpnService.prepare(service) == null) { "VPN permission is not granted" }
        MeowDiagnostics.log(
            "MeowVpnPlatform",
            "openTun begin mtu=${options.mtu} autoRoute=${options.autoRoute} " +
                "current=${MeowDefaultNetworkMonitor.describeCurrentState()}",
        )
        val builder = service.Builder()
            .setSession("Etonify")
            .setMtu(options.mtu)
        var hasIpv4Address = false
        var hasIpv6Address = false
        lastTunPackageSummary = "autoRoute=${options.autoRoute} allowed=0 disallowed=0"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        val inet4Address = options.inet4Address
        while (inet4Address.hasNext()) {
            val address = inet4Address.next()
            builder.addAddress(address.address(), address.prefix())
            hasIpv4Address = true
            MeowDiagnostics.log(
                "MeowVpnPlatform",
                "openTun add IPv4 address=${address.address()}/${address.prefix()}",
            )
        }

        val inet6Address = options.inet6Address
        while (inet6Address.hasNext()) {
            val address = inet6Address.next()
            builder.addAddress(address.address(), address.prefix())
            hasIpv6Address = true
            MeowDiagnostics.log(
                "MeowVpnPlatform",
                "openTun add IPv6 address=${address.address()}/${address.prefix()}",
            )
        }

        if (options.autoRoute) {
            val splitPackages = readSplitTunnelPackages(
                includePackage = { options.includePackage },
                excludePackage = { options.excludePackage },
            )
            val includedPackages = splitPackages.included
            // Etonify's ordinary HTTP must remain inside the VPN so the first
            // update attempt really uses the selected outbound. Explicit
            // fallback uses Network.openConnection() on a physical network;
            // libbox protects its own sockets through VpnService.protect().
            val excludedPackages = keepVpnOwnerRouted(
                splitPackages.excluded,
                service.packageName,
            )
            val dnsAddresses = runCatching {
                val iterator: StringIterator? = options.dnsServerAddress
                iterator?.toList().orEmpty()
                    .map(String::trim)
                    .filter(String::isNotEmpty)
                    .distinct()
            }.getOrElse { error ->
                MeowDiagnostics.log("MeowVpnPlatform", "openTun read DNS addresses failed", error)
                throw error
            }
            for (dnsAddress in dnsAddresses) {
                builder.addDnsServer(dnsAddress)
                MeowDiagnostics.log("MeowVpnPlatform", "openTun dns=$dnsAddress")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val inet4RouteAddress = options.inet4RouteAddress
                if (inet4RouteAddress.hasNext()) {
                    while (inet4RouteAddress.hasNext()) {
                        val route = inet4RouteAddress.next()
                        builder.addRoute(route.toIpPrefix())
                        MeowDiagnostics.log(
                            "MeowVpnPlatform",
                            "openTun add IPv4 route=${route.address()}/${route.prefix()}",
                        )
                    }
                } else if (hasIpv4Address) {
                    builder.addRoute("0.0.0.0", 0)
                    MeowDiagnostics.log("MeowVpnPlatform", "openTun add default IPv4 route")
                }

                val inet6RouteAddress = options.inet6RouteAddress
                if (inet6RouteAddress.hasNext()) {
                    while (inet6RouteAddress.hasNext()) {
                        val route = inet6RouteAddress.next()
                        builder.addRoute(route.toIpPrefix())
                        MeowDiagnostics.log(
                            "MeowVpnPlatform",
                            "openTun add IPv6 route=${route.address()}/${route.prefix()}",
                        )
                    }
                } else if (hasIpv6Address) {
                    builder.addRoute("::", 0)
                    MeowDiagnostics.log("MeowVpnPlatform", "openTun add default IPv6 route")
                }

                val inet4RouteExcludeAddress = options.inet4RouteExcludeAddress
                while (inet4RouteExcludeAddress.hasNext()) {
                    val route = inet4RouteExcludeAddress.next()
                    builder.excludeRoute(route.toIpPrefix())
                    MeowDiagnostics.log(
                        "MeowVpnPlatform",
                        "openTun exclude IPv4 route=${route.address()}/${route.prefix()}",
                    )
                }

                val inet6RouteExcludeAddress = options.inet6RouteExcludeAddress
                while (inet6RouteExcludeAddress.hasNext()) {
                    val route = inet6RouteExcludeAddress.next()
                    builder.excludeRoute(route.toIpPrefix())
                    MeowDiagnostics.log(
                        "MeowVpnPlatform",
                        "openTun exclude IPv6 route=${route.address()}/${route.prefix()}",
                    )
                }
            } else {
                // Older Android versions do not expose excludeRoute(). The core
                // normally supplies the calculated route ranges, but some
                // platform/core combinations return an empty iterator. Without
                // a fallback Android only routes the implicit DNS server into
                // the VPN, so per-app allowlists resolve domains but never send
                // ordinary TCP/UDP traffic through TUN.
                addRoutes(builder, options.inet4RouteRange, "0.0.0.0", 0, hasIpv4Address)
                addRoutes(builder, options.inet6RouteRange, "::", 0, hasIpv6Address)
            }

            val appliedIncludedPackages = addPackages(builder, includedPackages.iterator(), true)
            val appliedExcludedPackages = addPackages(builder, excludedPackages.iterator(), false)
            requireAppliedIncludedPackages(includedPackages, appliedIncludedPackages)
            lastTunPackageSummary = buildString {
                append("autoRoute=true requestedAllowed=")
                append(includedPackages.size)
                append(" appliedAllowed=")
                append(appliedIncludedPackages.size)
                append(" requestedDisallowed=")
                append(excludedPackages.size)
                append(" appliedDisallowed=")
                append(appliedExcludedPackages.size)
                if (appliedIncludedPackages.isNotEmpty()) {
                    append(" allowedPackages=")
                    append(appliedIncludedPackages.joinToString(","))
                }
                if (appliedExcludedPackages.isNotEmpty()) {
                    append(" disallowedPackages=")
                    append(appliedExcludedPackages.joinToString(","))
                }
            }
            MeowDiagnostics.log(
                "MeowVpnPlatform",
                "openTun packages $lastTunPackageSummary",
            )
        }

        if (options.isHTTPProxyEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setHttpProxy(
                ProxyInfo.buildDirectProxy(
                    options.httpProxyServer,
                    options.httpProxyServerPort,
                    options.httpProxyBypassDomain.toList(),
                ),
            )
            MeowDiagnostics.log(
                "MeowVpnPlatform",
                "openTun httpProxy=${options.httpProxyServer}:${options.httpProxyServerPort}",
            )
        }

        MeowDiagnostics.log("MeowVpnPlatform", "openTun establish()")
        val pfd = runCatching {
            builder.establish() ?: error("android: the application is not prepared or is revoked")
        }.onFailure {
            MeowDiagnostics.log("MeowVpnPlatform", "openTun establish failed", it)
        }.getOrThrow()
        val fd = pfd.detachFd()
        // Ownership is transferred to libbox. Its Go platform wrapper always
        // closes this original descriptor after duplicating it (or on every
        // failure path), so Kotlin must never retain or close this integer.
        MeowDiagnostics.log(
            "MeowVpnPlatform",
            "openTun established fd=$fd detached=true ownership=libbox",
        )
        return fd
    }

    private fun addRoutes(
        builder: VpnService.Builder,
        iterator: RoutePrefixIterator,
        defaultAddress: String,
        defaultPrefix: Int,
        addDefault: Boolean,
    ) {
        var hasAny = false
        while (iterator.hasNext()) {
            val route = iterator.next()
            builder.addRoute(route.address(), route.prefix())
            hasAny = true
            MeowDiagnostics.log(
                "MeowVpnPlatform",
                "openTun add route=${route.address()}/${route.prefix()}",
            )
        }
        if (!hasAny && addDefault) {
            builder.addRoute(defaultAddress, defaultPrefix)
            MeowDiagnostics.log(
                "MeowVpnPlatform",
                "openTun add default route=$defaultAddress/$defaultPrefix",
            )
        }
    }

    private fun addPackages(
        builder: VpnService.Builder,
        iterator: Iterator<String>,
        allowed: Boolean,
    ): List<String> {
        val applied = mutableListOf<String>()
        while (iterator.hasNext()) {
            val packageName = iterator.next().trim()
            if (packageName.isBlank()) {
                continue
            }
            if (!shouldApplyTunPackage(packageName, service.packageName, allowed)) {
                MeowDiagnostics.log(
                    "MeowVpnPlatform",
                    "openTun keep own package routed=$packageName",
                )
                continue
            }
            if (!isAndroidPackageName(packageName)) {
                MeowDiagnostics.log(
                    "MeowVpnPlatform",
                    "openTun skip invalid package=$packageName allowed=$allowed",
                )
                continue
            }
            runCatching {
                if (allowed) {
                    builder.addAllowedApplication(packageName)
                    MeowDiagnostics.log(
                        "MeowVpnPlatform",
                        "openTun allow package=$packageName",
                    )
                } else {
                    builder.addDisallowedApplication(packageName)
                    MeowDiagnostics.log(
                        "MeowVpnPlatform",
                        "openTun disallow package=$packageName",
                    )
                }
                applied += packageName
            }.onFailure { error ->
                if (error !is PackageManager.NameNotFoundException) {
                    throw error
                }
                MeowDiagnostics.log(
                    "MeowVpnPlatform",
                    "openTun skip missing package=$packageName allowed=$allowed",
                )
            }
        }
        return applied
    }

    private fun isAndroidPackageName(value: String): Boolean =
        value.length <= 255 &&
            Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$").matches(value)

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun RoutePrefix.toIpPrefix(): IpPrefix {
        return IpPrefix(InetAddress.getByName(address()), prefix())
    }

    private fun StringIterator.toList(): List<String> = buildList {
        while (hasNext()) {
            add(next())
        }
    }
}

class MeowProxyPlatformInterface(
    context: Context,
) : MeowBasePlatformInterface(context) {
    override fun openTun(options: TunOptions): Int {
        error("TUN is not available in proxy mode")
    }
}

class SimpleStringIterator(
    values: Iterable<String>,
) : StringIterator {
    private val items = values.toList()
    private var index = 0

    override fun hasNext(): Boolean = index < items.size

    override fun next(): String = items[index++]

    override fun len(): Int = items.size
}

private object MeowLocalResolver : LocalDNSTransport {
    private const val RCODE_NXDOMAIN = 3
    private val pendingQueries = ConcurrentHashMap.newKeySet<PendingDnsQuery>()

    fun cancelPendingQueries(): Int {
        val snapshot = pendingQueries.toList()
        for (query in snapshot) {
            query.cancel(OsConstants.ECANCELED)
        }
        return snapshot.size
    }

    private fun registerPendingQuery(
        ctx: ExchangeContext,
        signal: CancellationSignal,
        latch: CountDownLatch,
        completed: AtomicBoolean,
    ): PendingDnsQuery {
        return PendingDnsQuery(ctx, signal, latch, completed).also(pendingQueries::add)
    }

    private class PendingDnsQuery(
        private val context: ExchangeContext,
        private val signal: CancellationSignal,
        private val latch: CountDownLatch,
        private val completed: AtomicBoolean,
    ) {
        fun cancel(errno: Int) {
            signal.cancel()
            if (completed.compareAndSet(false, true)) {
                context.errnoCode(errno)
                latch.countDown()
            }
        }
    }

    override fun raw(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    override fun exchange(ctx: ExchangeContext, message: ByteArray) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            ctx.errnoCode(OsConstants.ENOSYS)
            return
        }
        val network = runCatching {
            MeowDefaultNetworkMonitor.requirePhysicalNetwork()
        }.getOrElse {
            MeowDiagnostics.log(
                "MeowLocalResolver",
                "exchange raw require failed current=${MeowDefaultNetworkMonitor.describeCurrentState()}",
                it,
            )
            ctx.errnoCode(OsConstants.ENETUNREACH)
            return
        }
        MeowDiagnostics.log(
            "MeowLocalResolver",
            "exchange raw bytes=${message.size} active=${MeowDefaultNetworkMonitor.describeNetwork(network)}",
        )
        val latch = CountDownLatch(1)
        val signal = CancellationSignal()
        val completed = AtomicBoolean(false)
        val pendingQuery = registerPendingQuery(ctx, signal, latch, completed)
        ctx.onCancel { pendingQuery.cancel(OsConstants.ECANCELED) }
        val callback = object : DnsResolver.Callback<ByteArray> {
            override fun onAnswer(answer: ByteArray, rcode: Int) {
                if (!completed.compareAndSet(false, true)) {
                    return
                }
                MeowDiagnostics.log(
                    "MeowLocalResolver",
                    "exchange raw answer rcode=$rcode bytes=${answer.size} active=${MeowDefaultNetworkMonitor.describeNetwork(network)}",
                )
                if (rcode == 0) {
                    ctx.rawSuccess(answer)
                } else {
                    ctx.errorCode(rcode)
                }
                latch.countDown()
            }

            override fun onError(error: DnsResolver.DnsException) {
                if (!completed.compareAndSet(false, true)) {
                    return
                }
                MeowDiagnostics.log(
                    "MeowLocalResolver",
                    "exchange raw error active=${MeowDefaultNetworkMonitor.describeNetwork(network)}",
                    error,
                )
                when (val cause = error.cause) {
                    is ErrnoException -> ctx.errnoCode(cause.errno)
                    else -> ctx.errnoCode(OsConstants.EIO)
                }
                latch.countDown()
            }
        }
        try {
            DnsResolver.getInstance().rawQuery(
                network,
                message,
                // Let Android retry across the DNS servers configured for the
                // selected underlying network. A single lost cellular response
                // must not fail the whole sing-box lookup immediately.
                DnsResolver.FLAG_EMPTY,
                Runnable::run,
                signal,
                callback,
            )
            if (!latch.await(15, TimeUnit.SECONDS)) {
                MeowDiagnostics.log(
                    "MeowLocalResolver",
                    "exchange raw timeout active=${MeowDefaultNetworkMonitor.describeNetwork(network)}",
                )
                pendingQuery.cancel(OsConstants.ETIMEDOUT)
            }
        } finally {
            pendingQueries.remove(pendingQuery)
        }
    }

    override fun lookup(ctx: ExchangeContext, network: String?, domain: String?) {
        val host = domain?.trim().orEmpty()
        if (host.isEmpty()) {
            ctx.errorCode(RCODE_NXDOMAIN)
            return
        }
        val active = runCatching {
            MeowDefaultNetworkMonitor.requirePhysicalNetwork()
        }.getOrElse {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                runCatching {
                    val answer = InetAddress.getAllByName(host)
                    ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
                }.onFailure {
                    if (it is UnknownHostException) {
                        ctx.errorCode(RCODE_NXDOMAIN)
                    } else {
                        ctx.errnoCode(OsConstants.EIO)
                    }
                }
            } else {
                ctx.errnoCode(OsConstants.ENETUNREACH)
            }
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            runCatching {
                val answer = InetAddress.getAllByName(host)
                ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
            }.onFailure {
                if (it is UnknownHostException) {
                    ctx.errorCode(RCODE_NXDOMAIN)
                } else {
                    ctx.errnoCode(OsConstants.EIO)
                }
            }
            return
        }

        val latch = CountDownLatch(1)
        val signal = CancellationSignal()
        val completed = AtomicBoolean(false)
        val pendingQuery = registerPendingQuery(ctx, signal, latch, completed)
        ctx.onCancel { pendingQuery.cancel(OsConstants.ECANCELED) }
        val callback = object : DnsResolver.Callback<Collection<java.net.InetAddress>> {
            override fun onAnswer(answer: Collection<java.net.InetAddress>, rcode: Int) {
                if (!completed.compareAndSet(false, true)) {
                    return
                }
                if (rcode == 0) {
                    ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
                } else {
                    ctx.errorCode(rcode)
                }
                latch.countDown()
            }

            override fun onError(error: DnsResolver.DnsException) {
                if (!completed.compareAndSet(false, true)) {
                    return
                }
                when (val cause = error.cause) {
                    is ErrnoException -> ctx.errnoCode(cause.errno)
                    else -> ctx.errnoCode(OsConstants.EIO)
                }
                latch.countDown()
            }
        }
        val queryType = when {
            network?.endsWith("4") == true -> DnsResolver.TYPE_A
            network?.endsWith("6") == true -> DnsResolver.TYPE_AAAA
            else -> null
        }
        MeowDiagnostics.log(
            "MeowLocalResolver",
            "lookup dispatch host=$host queryType=${queryType ?: -1} active=${MeowDefaultNetworkMonitor.describeNetwork(active)}",
        )
        try {
            if (queryType != null) {
                DnsResolver.getInstance().query(
                    active,
                    host,
                    queryType,
                    DnsResolver.FLAG_EMPTY,
                    Runnable::run,
                    signal,
                    callback,
                )
            } else {
                DnsResolver.getInstance().query(
                    active,
                    host,
                    DnsResolver.FLAG_EMPTY,
                    Runnable::run,
                    signal,
                    callback,
                )
            }
            if (!latch.await(15, TimeUnit.SECONDS)) {
                MeowDiagnostics.log(
                    "MeowLocalResolver",
                    "lookup timeout host=$host active=${MeowDefaultNetworkMonitor.describeNetwork(active)}",
                )
                pendingQuery.cancel(OsConstants.ETIMEDOUT)
            }
        } finally {
            pendingQueries.remove(pendingQuery)
        }
    }
}
