package com.etonify.meow_client

import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class PrivateDownloadPathPolicyTest {
    @Test
    fun `accepts a file anywhere under private app data`() {
        withPrivateDataDirectory { dataDir ->
            val destination = dataDir.resolve("app_flutter/downloads/rules.tmp")

            assertEquals(
                destination.canonicalFile,
                PrivateDownloadPathPolicy.requireTarget(
                    destination.path,
                    dataDir,
                ),
            )
        }
    }

    @Test
    fun `rejects a file outside private app data`() {
        withPrivateDataDirectory { dataDir ->
            val destination = requireNotNull(dataDir.parentFile).resolve("shared/rules.tmp")

            assertThrows(IllegalArgumentException::class.java) {
                PrivateDownloadPathPolicy.requireTarget(
                    destination.path,
                    dataDir,
                )
            }
        }
    }

    @Test
    fun `rejects traversal outside private app data`() {
        withPrivateDataDirectory { dataDir ->
            val destination = dataDir.resolve("cache/../../shared/rules.tmp")

            assertThrows(IllegalArgumentException::class.java) {
                PrivateDownloadPathPolicy.requireTarget(
                    destination.path,
                    dataDir,
                )
            }
        }
    }

    private fun withPrivateDataDirectory(block: (java.io.File) -> Unit) {
        val root = Files.createTempDirectory("etonify-private-download-test").toFile()
        try {
            block(root.resolve("data").apply { mkdirs() })
        } finally {
            root.deleteRecursively()
        }
    }
}
