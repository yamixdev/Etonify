package com.etonify.meow_client.singbox

internal data class DefaultNetworkCandidate<T>(
    val value: T,
    val isActive: Boolean,
    val isValidated: Boolean,
    val hasUsableInterface: Boolean,
    val score: Int,
)

/**
 * Keeps the current usable physical network when Android reports the VPN itself as
 * active and temporarily removes VALIDATED from its underlying network. When a
 * callback identifies a different physical network as the new best candidate,
 * that callback network wins over an unvalidated stale interface. Outside an
 * active VPN, Android's active physical network wins so a lingering validated
 * Wi-Fi network cannot capture a cellular fallback request.
 */
internal fun <T> selectDefaultNetworkCandidate(
    candidates: List<DefaultNetworkCandidate<T>>,
    current: T?,
    preferred: T? = null,
): DefaultNetworkCandidate<T>? {
    val usable = candidates.filter { it.hasUsableInterface }
    return usable
        .filter { it.isActive }
        .maxByOrNull { it.score }
        ?: usable
            .filter { it.value == preferred && it.isValidated }
            .maxByOrNull { it.score }
        ?: usable
            .filter { it.value == current && it.isValidated }
            .maxByOrNull { it.score }
        ?: usable
            .filter { it.isValidated }
            .maxByOrNull { it.score }
        ?: usable.firstOrNull { it.value == preferred }
        ?: usable.firstOrNull { it.value == current }
        ?: usable
            .maxByOrNull { it.score }
}
