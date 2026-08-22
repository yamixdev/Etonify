package com.etonify.meow_client.singbox

import kotlin.math.roundToLong

internal data class NotificationTrafficRate(
    val uplinkBytesPerSecond: Long,
    val downlinkBytesPerSecond: Long,
)

/**
 * Converts the core's cumulative byte counters into a rate over real elapsed
 * time. The command stream interval and the notification redraw interval are
 * deliberately independent: economy mode can report every two seconds while
 * the user can choose a notification interval from one to ten seconds.
 */
internal class NotificationTrafficRateWindow {
    private var initialized = false
    private var lastTrafficAvailable: Boolean? = null
    private var baselineAtMillis = 0L
    private var baselineUplinkTotal = 0L
    private var baselineDownlinkTotal = 0L
    private var forceNextEmission = true

    fun reset() {
        initialized = false
        lastTrafficAvailable = null
        baselineAtMillis = 0L
        baselineUplinkTotal = 0L
        baselineDownlinkTotal = 0L
        forceNextEmission = true
    }

    fun requestImmediateEmission() {
        forceNextEmission = true
    }

    fun update(
        uplinkTotal: Long,
        downlinkTotal: Long,
        trafficAvailable: Boolean,
        nowMillis: Long,
        refreshIntervalMillis: Long,
    ): NotificationTrafficRate? {
        val safeUplinkTotal = uplinkTotal.coerceAtLeast(0L)
        val safeDownlinkTotal = downlinkTotal.coerceAtLeast(0L)
        val safeNow = nowMillis.coerceAtLeast(0L)

        if (!trafficAvailable) {
            val shouldEmit = lastTrafficAvailable != false || forceNextEmission
            initialized = false
            lastTrafficAvailable = false
            forceNextEmission = false
            return if (shouldEmit) NotificationTrafficRate(0L, 0L) else null
        }

        val countersReset = initialized && (
            safeUplinkTotal < baselineUplinkTotal ||
                safeDownlinkTotal < baselineDownlinkTotal ||
                safeNow <= baselineAtMillis
            )
        if (!initialized || lastTrafficAvailable != true || countersReset) {
            initialized = true
            lastTrafficAvailable = true
            baselineAtMillis = safeNow
            baselineUplinkTotal = safeUplinkTotal
            baselineDownlinkTotal = safeDownlinkTotal
            forceNextEmission = false
            return NotificationTrafficRate(0L, 0L)
        }

        val elapsedMillis = safeNow - baselineAtMillis
        val interval = refreshIntervalMillis.coerceAtLeast(1L)
        if (!forceNextEmission && elapsedMillis < interval) {
            return null
        }
        if (elapsedMillis <= 0L) {
            forceNextEmission = false
            return NotificationTrafficRate(0L, 0L)
        }

        val result = NotificationTrafficRate(
            uplinkBytesPerSecond = bytesPerSecond(
                safeUplinkTotal - baselineUplinkTotal,
                elapsedMillis,
            ),
            downlinkBytesPerSecond = bytesPerSecond(
                safeDownlinkTotal - baselineDownlinkTotal,
                elapsedMillis,
            ),
        )
        baselineAtMillis = safeNow
        baselineUplinkTotal = safeUplinkTotal
        baselineDownlinkTotal = safeDownlinkTotal
        forceNextEmission = false
        return result
    }

    private fun bytesPerSecond(deltaBytes: Long, elapsedMillis: Long): Long =
        (deltaBytes.coerceAtLeast(0L).toDouble() * 1_000.0 / elapsedMillis.toDouble())
            .roundToLong()
            .coerceAtLeast(0L)
}
