package com.etonify.meow_client.singbox

internal data class LibboxMemoryPolicy(
    val goMemoryLimitBytes: Long,
    val processOomKillerEnabled: Boolean,
    val processOomMemoryLimitBytes: Long,
) {
    companion object {
        private const val MEBIBYTE = 1024L * 1024L
        private const val MIN_GO_MEMORY_LIMIT_BYTES = 256L * MEBIBYTE
        private const val MAX_GO_MEMORY_LIMIT_BYTES = 512L * MEBIBYTE

        fun forAndroid(
            softLimitEnabled: Boolean,
            memoryClassMegabytes: Int,
        ): LibboxMemoryPolicy =
            LibboxMemoryPolicy(
                // This is a soft budget for Go-managed memory only. Keep
                // enough headroom for gVisor, DNS and large rule sets: a limit
                // below the live Go runtime footprint makes GC run almost
                // continuously and trades a little RAM for excessive CPU and
                // battery use. It must never be reused as an RSS threshold for
                // the whole Android process.
                goMemoryLimitBytes = if (softLimitEnabled) {
                    val adaptiveLimit = memoryClassMegabytes
                        .coerceAtLeast(0)
                        .toLong() * MEBIBYTE / 2L
                    adaptiveLimit.coerceIn(
                        MIN_GO_MEMORY_LIMIT_BYTES,
                        MAX_GO_MEMORY_LIMIT_BYTES,
                    )
                } else {
                    0L
                },
                // Android owns process-level memory pressure and termination.
                // Resetting the VPN network from an in-process RSS threshold
                // can break healthy tunnels without releasing Flutter memory.
                processOomKillerEnabled = false,
                processOomMemoryLimitBytes = 0L,
            )
    }
}
