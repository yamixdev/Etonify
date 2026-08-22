package com.etonify.meow_client.singbox

import java.io.File

internal enum class DnsCacheClearResult {
    NOT_REQUESTED,
    DEFERRED_RUNTIME_ACTIVE,
    CLEARED,
    FAILED,
}

/**
 * Coordinates deletion of sing-box's persistent cache database.
 *
 * The database belongs to the native runtime and must never be removed while
 * libbox is using it. A marker survives process/service recreation; the next
 * confirmed stopped state consumes it before a new runtime is created.
 */
internal object PersistentDnsCache {
    private const val PENDING_MARKER = ".dns-cache-clear.pending"
    private val databaseNames = listOf(
        "cache.db",
        "cache.db-shm",
        "cache.db-wal",
        "cache.db-journal",
    )

    fun requestClear(workingDirectory: File, reason: String) {
        workingDirectory.mkdirs()
        val marker = File(workingDirectory, PENDING_MARKER)
        if (marker.isFile) return

        val temporary = File(workingDirectory, "$PENDING_MARKER.tmp")
        temporary.writeText(reason.trim().ifEmpty { "unspecified" }, Charsets.UTF_8)
        if (!temporary.renameTo(marker)) {
            temporary.delete()
            if (!marker.isFile) {
                error("Failed to persist DNS cache clear marker")
            }
        }
    }

    fun isClearPending(workingDirectory: File): Boolean =
        File(workingDirectory, PENDING_MARKER).isFile

    fun clearIfPending(
        workingDirectory: File,
        runtimeActive: Boolean,
    ): DnsCacheClearResult {
        val marker = File(workingDirectory, PENDING_MARKER)
        if (!marker.isFile) return DnsCacheClearResult.NOT_REQUESTED
        if (runtimeActive) return DnsCacheClearResult.DEFERRED_RUNTIME_ACTIVE

        var allDeleted = true
        for (name in databaseNames) {
            val file = File(workingDirectory, name)
            if (file.exists() && !file.delete()) {
                allDeleted = false
            }
        }
        if (!allDeleted) return DnsCacheClearResult.FAILED
        return if (!marker.exists() || marker.delete()) {
            DnsCacheClearResult.CLEARED
        } else {
            DnsCacheClearResult.FAILED
        }
    }
}
