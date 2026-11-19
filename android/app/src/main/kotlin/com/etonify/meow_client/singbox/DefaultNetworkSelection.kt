package com.etonify.meow_client.singbox

internal data class DefaultNetworkCandidate<T>(
    val value: T,
    val isActive: Boolean,
    val isValidated: Boolean,
    val hasUsableInterface: Boolean,
    val score: Int,
)

/**
 * Honor Android's active physical network when it is visible. Behind a VPN,
 * rank validated physical networks by transport and keep the current interface
 * on a tie or when none is validated.
 */
internal fun <T> selectDefaultNetworkCandidate(
    candidates: List<DefaultNetworkCandidate<T>>,
    current: T?,
): DefaultNetworkCandidate<T>? {
    val usable = candidates.filter { it.hasUsableInterface }
    return usable
        .filter { it.isActive }
        .maxByOrNull { it.score }
        ?: usable
            .filter { it.isValidated }
            .maxWithOrNull(compareBy<DefaultNetworkCandidate<T>> { it.score }.thenBy { it.value == current })
        ?: usable.firstOrNull { it.value == current }
        ?: usable
            .maxByOrNull { it.score }
}
