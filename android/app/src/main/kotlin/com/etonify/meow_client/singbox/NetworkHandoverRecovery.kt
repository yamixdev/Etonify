package com.etonify.meow_client.singbox

internal data class NetworkRecoveryContext(
    val runtime: Long,
    val network: Long,
    val externalStop: Long,
    val selection: Long,
    val startToken: Long,
    val cancellation: Long,
) {
    fun matches(current: NetworkRecoveryContext): Boolean = runtime > 0L && network > 0L && this == current
}

internal enum class NetworkHandoverProbeOutcome {
    HEALTHY,
    UNHEALTHY,
    INCONCLUSIVE,
}

internal class NetworkHandoverRecovery {
    private var resetRuntime = 0L
    private var resetNetwork = 0L
    private var probeContext: NetworkRecoveryContext? = null
    private var probeWakeAt: Long? = null
    private var probeRetryTaken = false

    @Synchronized
    fun takeProbe(
        expected: NetworkRecoveryContext,
        current: NetworkRecoveryContext,
        retry: Boolean,
        wakeAt: Long? = null,
    ): Boolean {
        if (!expected.matches(current)) return false
        val sameProbe = probeContext == expected && probeWakeAt == wakeAt
        if (retry) {
            if (!sameProbe || probeRetryTaken) return false
            probeRetryTaken = true
        } else {
            if (sameProbe) return false
            probeContext = expected
            probeWakeAt = wakeAt
            probeRetryTaken = false
        }
        return true
    }

    @Synchronized
    fun resetIfChanged(expected: NetworkRecoveryContext, current: NetworkRecoveryContext, reset: () -> Unit): Boolean {
        if (!expected.matches(current) || (resetRuntime == expected.runtime && resetNetwork == expected.network)) return false
        reset()
        resetRuntime = expected.runtime
        resetNetwork = expected.network
        return true
    }
}
