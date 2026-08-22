package com.etonify.meow_client.singbox

import io.nekohasekai.libbox.StringIterator

// One additional entry is reserved for Etonify itself when the user enables
// "Through VPN" split routing. User settings remain capped at 128 packages.
internal const val MAX_SPLIT_TUNNEL_PACKAGE_COUNT = 129

internal data class SplitTunnelPackages(
    val included: List<String>,
    val excluded: List<String>,
)

internal class SplitTunnelConfigurationException(
    message: String,
) : IllegalArgumentException(message)

internal fun readSplitTunnelPackages(
    includePackage: () -> StringIterator,
    excludePackage: () -> StringIterator,
): SplitTunnelPackages {
    // A gomobile property access crosses JNI and may construct a new iterator.
    // Resolve each getter exactly once before consuming it.
    val included = readBoundedPackageIterator("include_package", includePackage())
    val excluded = readBoundedPackageIterator("exclude_package", excludePackage())
    requireExclusiveSplitTunnelPackages(included, excluded)
    return SplitTunnelPackages(included = included, excluded = excluded)
}

internal fun requireExclusiveSplitTunnelPackages(
    included: List<String>,
    excluded: List<String>,
) {
    if (included.isNotEmpty() && excluded.isNotEmpty()) {
        throw SplitTunnelConfigurationException(
            "include_package and exclude_package cannot be used at the same time",
        )
    }
}

internal fun requireAppliedIncludedPackages(
    requested: List<String>,
    applied: List<String>,
) {
    if (requested.isNotEmpty() && applied.isEmpty()) {
        throw SplitTunnelConfigurationException(
            "include_package did not contain an installed application",
        )
    }
}

internal fun keepVpnOwnerRouted(
    excluded: List<String>,
    ownerPackage: String,
): List<String> {
    val normalizedOwner = ownerPackage.trim()
    if (excluded.isEmpty() || normalizedOwner.isEmpty()) {
        return excluded
    }
    return excluded.filterNot { it == normalizedOwner }
}

internal fun shouldApplyTunPackage(
    packageName: String,
    ownerPackage: String,
    allowed: Boolean,
): Boolean = allowed || packageName != ownerPackage

private fun readBoundedPackageIterator(
    fieldName: String,
    iterator: StringIterator,
): List<String> {
    val packages = linkedSetOf<String>()
    var readCount = 0
    while (iterator.hasNext()) {
        if (readCount >= MAX_SPLIT_TUNNEL_PACKAGE_COUNT) {
            throw SplitTunnelConfigurationException(
                "$fieldName exceeds the limit of $MAX_SPLIT_TUNNEL_PACKAGE_COUNT packages",
            )
        }
        readCount++
        val packageName = iterator.next().trim()
        if (packageName.isNotEmpty()) {
            packages += packageName
        }
    }
    return packages.toList()
}
