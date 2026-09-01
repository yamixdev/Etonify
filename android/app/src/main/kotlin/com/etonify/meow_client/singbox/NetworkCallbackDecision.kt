package com.etonify.meow_client.singbox

/**
 * Pure network-selection decisions shared by the Android callback paths.
 *
 * A callback for the network that is already selected still asks the monitor
 * to verify the interface. That verification is deliberately non-forced, so
 * [MeowDefaultNetworkMonitor] can ignore an unchanged interface key while
 * still noticing a real LinkProperties/interface change on the same Network.
 */
internal data class NetworkCallbackDecision<T>(
    val nextNetwork: T?,
    val shouldCheckInterface: Boolean,
)

internal data class InterfaceUpdateDecision(
    val duplicate: Boolean,
    val shouldDispatch: Boolean,
)

/** Keeps duplicate suppression consistent for every interface state. */
internal class InterfaceUpdateGate {
    private var lastKey: String? = null

    @Synchronized
    fun reset() {
        lastKey = null
    }

    @Synchronized
    fun evaluate(key: String, force: Boolean): InterfaceUpdateDecision {
        val duplicate = lastKey == key
        lastKey = key
        return InterfaceUpdateDecision(
            duplicate = duplicate,
            shouldDispatch = force || !duplicate,
        )
    }
}

internal fun <T> decideUsableNetworkCallback(
    currentNetwork: T?,
    preferredNetwork: T?,
    eventNetwork: T,
): NetworkCallbackDecision<T> = when {
    preferredNetwork == null && currentNetwork == eventNetwork ->
        NetworkCallbackDecision(nextNetwork = null, shouldCheckInterface = true)

    preferredNetwork == null ->
        NetworkCallbackDecision(nextNetwork = currentNetwork, shouldCheckInterface = false)

    currentNetwork == preferredNetwork ->
        NetworkCallbackDecision(
            nextNetwork = currentNetwork,
            shouldCheckInterface = eventNetwork == preferredNetwork,
        )

    else ->
        NetworkCallbackDecision(nextNetwork = preferredNetwork, shouldCheckInterface = true)
}

internal fun <T> decideLostNetworkCallback(
    currentNetwork: T?,
    replacementNetwork: T?,
    eventNetwork: T,
): NetworkCallbackDecision<T> = if (currentNetwork == eventNetwork) {
    NetworkCallbackDecision(
        nextNetwork = replacementNetwork,
        shouldCheckInterface = true,
    )
} else {
    NetworkCallbackDecision(
        nextNetwork = currentNetwork,
        shouldCheckInterface = false,
    )
}
