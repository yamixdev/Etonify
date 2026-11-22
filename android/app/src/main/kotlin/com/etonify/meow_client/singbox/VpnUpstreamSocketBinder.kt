package com.etonify.meow_client.singbox

import android.net.LocalServerSocket
import android.net.LocalSocket
import android.os.Process
import android.system.Os
import java.io.IOException
import java.util.UUID
import kotlin.concurrent.thread

/** Handles sing-box's per-outbound protect_path protocol on a private abstract socket. */
internal class VpnUpstreamSocketBinder : AutoCloseable {
    private val name = "etonify-vpn-${UUID.randomUUID()}"
    private val server = LocalServerSocket(name)
    val path = "@$name"
    @Volatile var enabled = false
    @Volatile private var closed = false

    init {
        thread(name = "etonify-vpn-upstream", isDaemon = true) {
            while (!closed) {
                val socket = try {
                    server.accept()
                } catch (error: IOException) {
                    if (!closed) MeowDiagnostics.log("VpnUpstreamSocketBinder", "accept failed", error)
                    break
                }
                runCatching { socket.use(::bind) }
                    .onFailure { if (!closed) MeowDiagnostics.log("VpnUpstreamSocketBinder", "socket bind failed", it) }
            }
        }
    }

    private fun bind(socket: LocalSocket) {
        if (socket.peerCredentials.uid != Process.myUid()) return
        socket.soTimeout = 1_000
        if (socket.inputStream.read() != 1) return
        val descriptors = socket.ancillaryFileDescriptors ?: return
        try {
            val fd = descriptors.singleOrNull() ?: return
            if (enabled) {
                val network = MeowDefaultNetworkMonitor.selectedVpnUpstream()
                if (network != null) {
                    try {
                        network.bindSocket(fd)
                    } catch (error: IOException) {
                        val replacement = MeowDefaultNetworkMonitor.selectedVpnUpstream()
                        if (replacement == null || replacement == network) throw error
                        replacement.bindSocket(fd)
                    }
                }
            }
            socket.outputStream.write(1)
        } finally {
            descriptors.forEach { runCatching { Os.close(it) } }
        }
    }

    override fun close() {
        closed = true
        server.close()
    }
}
