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

internal class NetworkHandoverRecovery(private val restartCooldownMillis: Long) {
    private var resetRuntime = 0L
    private var resetNetwork = 0L
    private var restartedContext: NetworkRecoveryContext? = null
    private var lastRestartAt: Long? = null

    @Synchronized
    fun resetIfChanged(expected: NetworkRecoveryContext, current: NetworkRecoveryContext, reset: () -> Unit): Boolean {
        if (!expected.matches(current) || (resetRuntime == expected.runtime && resetNetwork == expected.network)) return false
        reset()
        resetRuntime = expected.runtime
        resetNetwork = expected.network
        return true
    }

    @Synchronized
    fun takeRestart(expected: NetworkRecoveryContext, current: NetworkRecoveryContext, nowMillis: Long): Boolean {
        if (!expected.matches(current) || restartedContext == expected) return false
        val previous = lastRestartAt
        if (previous != null && (nowMillis < previous || nowMillis - previous < restartCooldownMillis)) return false
        restartedContext = expected
        lastRestartAt = nowMillis
        return true
    }
}
