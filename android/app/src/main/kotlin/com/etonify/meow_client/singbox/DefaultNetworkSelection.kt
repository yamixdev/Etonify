package com.etonify.meow_client.singbox

internal data class DefaultNetworkCandidate<T>(
    val value: T,
    val isActive: Boolean,
    val isValidated: Boolean,
    val hasUsableInterface: Boolean,
    val score: Int,
    val isCaptivePortal: Boolean = false,
)

/**
 * Prefer a validated physical network. The Android default breaks ties within
 * that tier, but a Wi-Fi link without internet must not hide working cellular.
 */
internal fun <T> selectDefaultNetworkCandidate(
    candidates: List<DefaultNetworkCandidate<T>>,
    current: T?,
): DefaultNetworkCandidate<T>? {
    val usable = candidates.filter { it.hasUsableInterface }
    val preferred = usable.filterNot { it.isCaptivePortal }.ifEmpty { usable }
    return preferred.filter { it.isValidated }
        .maxWithOrNull(compareBy<DefaultNetworkCandidate<T>> { it.isActive }
            .thenBy { it.score }.thenBy { it.value == current })
        ?: preferred.filter { it.isActive }.maxByOrNull { it.score }
        ?: preferred.firstOrNull { it.value == current }
        ?: preferred.maxByOrNull { it.score }
}
