package com.etonify.meow_client.singbox

import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PersistentDnsCacheTest {
    @Test
    fun `cache deletion is deferred while native runtime is active`() {
        val directory = Files.createTempDirectory("etonify-dns-cache").toFile()
        try {
            val database = directory.resolve("cache.db").apply { writeText("cache") }
            PersistentDnsCache.requestClear(directory, "dns_changed")

            assertEquals(
                DnsCacheClearResult.DEFERRED_RUNTIME_ACTIVE,
                PersistentDnsCache.clearIfPending(directory, runtimeActive = true),
            )
            assertTrue(database.exists())
            assertTrue(PersistentDnsCache.isClearPending(directory))
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun `confirmed stopped runtime clears database sidecars and marker`() {
        val directory = Files.createTempDirectory("etonify-dns-cache").toFile()
        try {
            for (name in listOf("cache.db", "cache.db-shm", "cache.db-wal", "cache.db-journal")) {
                directory.resolve(name).writeText(name)
            }
            PersistentDnsCache.requestClear(directory, "dns_changed")

            assertEquals(
                DnsCacheClearResult.CLEARED,
                PersistentDnsCache.clearIfPending(directory, runtimeActive = false),
            )
            assertFalse(PersistentDnsCache.isClearPending(directory))
            assertFalse(directory.resolve("cache.db").exists())
            assertFalse(directory.resolve("cache.db-shm").exists())
            assertFalse(directory.resolve("cache.db-wal").exists())
            assertFalse(directory.resolve("cache.db-journal").exists())
        } finally {
            directory.deleteRecursively()
        }
    }
}
