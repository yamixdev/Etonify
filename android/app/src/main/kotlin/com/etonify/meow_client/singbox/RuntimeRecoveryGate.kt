package com.etonify.meow_client.singbox

import java.util.concurrent.atomic.AtomicLong

/**
 * Coalesces Android wake signals that commonly arrive as a short burst
 * (for example SCREEN_ON followed by USER_PRESENT).
 */
internal class RuntimeRecoveryGate(
    private val minimumIntervalMillis: Long,
) {
    private val lastAcceptedAtMillis = AtomicLong(NO_TIMESTAMP)

    init {
        require(minimumIntervalMillis >= 0L)
    }

    fun tryAcquire(nowMillis: Long): Boolean {
        while (true) {
            val previous = lastAcceptedAtMillis.get()
            if (
                previous != NO_TIMESTAMP &&
                nowMillis >= previous &&
                nowMillis - previous < minimumIntervalMillis
            ) {
                return false
            }
            if (lastAcceptedAtMillis.compareAndSet(previous, nowMillis)) {
                return true
            }
        }
    }

    fun reset() {
        lastAcceptedAtMillis.set(NO_TIMESTAMP)
    }

    private companion object {
        const val NO_TIMESTAMP = Long.MIN_VALUE
    }
}

/** Keeps only the newest delayed probe after a physical network handover. */
internal class NetworkHandoverProbeGate {
    private val generation = AtomicLong(0L)

    fun replace(): Long = generation.incrementAndGet()

    fun isCurrent(token: Long): Boolean = generation.get() == token

    fun tryConsume(token: Long): Boolean = generation.compareAndSet(token, token + 1L)

    fun invalidate() {
        generation.incrementAndGet()
    }
}

internal fun isNetworkHandoverRecoverySource(source: String): Boolean =
    source.startsWith("network_change:")
