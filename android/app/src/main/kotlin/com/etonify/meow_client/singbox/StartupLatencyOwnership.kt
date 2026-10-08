package com.etonify.meow_client.singbox

import java.util.concurrent.atomic.AtomicLong

internal class StartupUrlTestLeaseExpiredException : IllegalStateException("startup URLTest ownership lease expired")

/** One startup leaf has one owner, independent of whether Flutter or the tile arrives first. */
internal class StartupLatencyOwnership {
    companion object { private val sequence = AtomicLong() }
    data class Measurement(
        val tag: String, val delayMillis: Long?, val measuredAtMillis: Long, val status: String,
        val revision: Long = 0L, val sessionId: Long = 0L, val error: String = "",
    )
    private data class Context(val runtime: Long, val network: Long, val tag: String, val selection: Long = 0L)
    private enum class Owner { NONE, CLIENT_RESERVED, CLIENT_RUNNING, NATIVE }
    private var context = Context(0L, 0L, "")
    private var ready = false
    private var armed = false
    private var owner = Owner.NONE
    private var token = 0L
    private var measurement: Measurement? = null
    private val borrowers = mutableListOf<(Measurement?) -> Unit>()

    @Synchronized
    fun update(runtime: Long, network: Long, tag: String, ready: Boolean, armed: Boolean, selection: Long = 0L) {
        val next = Context(runtime, network, tag, selection)
        if (next != context || !armed || (this.ready && !ready)) {
            context = next
            token = sequence.incrementAndGet()
            owner = Owner.NONE
            measurement = null
            val pending = borrowers.toList()
            borrowers.clear()
            pending.forEach { it(null) }
        }
        this.ready = ready && runtime > 0L && network > 0L && tag.isNotEmpty()
        this.armed = armed
    }

    @Synchronized
    fun claimNative(): Long? {
        if (!armed || !ready || owner != Owner.NONE) return null
        owner = Owner.NATIVE
        token = sequence.incrementAndGet()
        return token
    }

    @Synchronized
    fun prepareClient(runtime: Long, tags: Set<String>, callback: (Measurement?) -> Unit): Long? {
        if (!armed || !ready || runtime != context.runtime || context.tag !in tags) {
            callback(null)
            return null
        }
        if (owner == Owner.NATIVE || owner == Owner.CLIENT_RUNNING) {
            val result = measurement
            if (result != null) callback(result) else borrowers += callback
            return null
        }
        if (owner == Owner.NONE) {
            owner = Owner.CLIENT_RESERVED
            token = sequence.incrementAndGet()
        }
        callback(null)
        return token.takeIf { owner == Owner.CLIENT_RESERVED }
    }

    @Synchronized
    fun clientRequest(coversTarget: Boolean): Long? {
        if (!armed || !ready || !coversTarget || owner == Owner.NATIVE) return null
        if (owner == Owner.NONE) token = sequence.incrementAndGet()
        owner = Owner.CLIENT_RUNNING
        return token
    }

    @Synchronized
    fun expireReservation(token: Long): Boolean {
        if (this.token != token || owner != Owner.CLIENT_RESERVED) return false
        owner = Owner.NONE
        this.token = sequence.incrementAndGet()
        return true
    }

    @Synchronized
    fun clientFailed(token: Long): Boolean {
        if (this.token != token || owner !in setOf(Owner.CLIENT_RESERVED, Owner.CLIENT_RUNNING)) return false
        owner = Owner.NONE
        this.token = sequence.incrementAndGet()
        return true
    }

    @Synchronized
    fun expireClient(token: Long): Boolean {
        if (this.token != token || owner != Owner.CLIENT_RUNNING || measurement != null) return false
        owner = Owner.NONE
        this.token = sequence.incrementAndGet()
        return true
    }

    @Synchronized
    fun dispatchClient(token: Long): Boolean {
        if (!armed || !ready || this.token != token || owner != Owner.CLIENT_RESERVED) return false
        owner = Owner.CLIENT_RUNNING
        return true
    }

    @Synchronized
    fun dispatchNative(token: Long): Boolean = armed && ready && this.token == token && owner == Owner.NATIVE

    @Synchronized
    fun nativeFailed(token: Long): Boolean {
        if (this.token != token || owner != Owner.NATIVE || measurement != null) return false
        owner = Owner.NONE
        this.token = sequence.incrementAndGet()
        val pending = borrowers.toList()
        borrowers.clear()
        pending.forEach { it(null) }
        return true
    }

    @Synchronized
    fun complete(runtime: Long, network: Long, tag: String, delay: Long?, measuredAt: Long, status: String,
        revision: Long = 0L, sessionId: Long = 0L, error: String = "",
        selection: Long = 0L,
    ): Boolean {
        if (!armed || !ready || context != Context(runtime, network, tag, selection) || owner == Owner.NONE) return false
        measurement = Measurement(tag, delay?.takeIf { it > 0L }, measuredAt, status, revision, sessionId, error)
        val pending = borrowers.toList()
        borrowers.clear()
        pending.forEach { it(measurement) }
        return true
    }
}
