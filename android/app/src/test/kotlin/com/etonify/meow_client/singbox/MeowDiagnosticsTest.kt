package com.etonify.meow_client.singbox

import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MeowDiagnosticsTest {

    @Test
    fun `rotateIfNeeded does nothing when file is within max limit`() {
        val dir = Files.createTempDirectory("meow-diag-test").toFile()
        try {
            val logFile = dir.resolve("test.log").apply { writeText("hello world\n") }
            val backupFile = dir.resolve("test.log.1")

            val rotated = MeowDiagnostics.rotateIfNeeded(logFile, backupFile, maxBytes = 1024)

            assertFalse(rotated)
            assertTrue(logFile.exists())
            assertFalse(backupFile.exists())
            assertEquals("hello world\n", logFile.readText())
        } finally {
            dir.deleteRecursively()
        }
    }

    @Test
    fun `rotateIfNeeded renames file to backup when exceeding limit`() {
        val dir = Files.createTempDirectory("meow-diag-test").toFile()
        try {
            val logFile = dir.resolve("test.log").apply { writeText("first-content\n") }
            val backupFile = dir.resolve("test.log.1")

            val rotated = MeowDiagnostics.rotateIfNeeded(logFile, backupFile, maxBytes = 5)

            assertTrue(rotated)
            assertFalse(logFile.exists())
            assertTrue(backupFile.exists())
            assertEquals("first-content\n", backupFile.readText())

            // Second rotation replaces old backup cleanly
            logFile.writeText("second-content\n")
            val rotatedSecond = MeowDiagnostics.rotateIfNeeded(logFile, backupFile, maxBytes = 5)

            assertTrue(rotatedSecond)
            assertFalse(logFile.exists())
            assertTrue(backupFile.exists())
            assertEquals("second-content\n", backupFile.readText())
        } finally {
            dir.deleteRecursively()
        }
    }

    @Test
    fun `readFileTail aligns to next line boundary`() {
        val dir = Files.createTempDirectory("meow-diag-test").toFile()
        try {
            val logFile = dir.resolve("test.log").apply {
                writeText("line1\nline2\nline3\nline4\nline5\n")
            }
            // Tail of 14 bytes falls into "line3"
            val tail = MeowDiagnostics.readFileTail(logFile, 14)
            assertEquals("line4\nline5", tail)
        } finally {
            dir.deleteRecursively()
        }
    }

    @Test
    fun `readTailFromFiles merges backup and active files chronologically`() {
        val dir = Files.createTempDirectory("meow-diag-test").toFile()
        try {
            val backupFile = dir.resolve("test.log.1").apply {
                writeText("backup-event-1\nbackup-event-2\n")
            }
            val logFile = dir.resolve("test.log").apply {
                writeText("active-event-1\nactive-event-2\n")
            }

            val tail = MeowDiagnostics.readTailFromFiles(logFile, backupFile, maxBytes = 200)

            assertTrue(tail.contains("backup-event-1"))
            assertTrue(tail.contains("active-event-2"))
            val backupIdx = tail.indexOf("backup-event-2")
            val activeIdx = tail.indexOf("active-event-1")
            assertTrue(backupIdx < activeIdx)
        } finally {
            dir.deleteRecursively()
        }
    }

    @Test
    fun `readTailFromFiles reads only active file if sufficient`() {
        val dir = Files.createTempDirectory("meow-diag-test").toFile()
        try {
            val backupFile = dir.resolve("test.log.1").apply {
                writeText("ancient-log-line\n")
            }
            val logFile = dir.resolve("test.log").apply {
                writeText("line1\nline2\nline3\nline4\nline5\n")
            }

            val tail = MeowDiagnostics.readTailFromFiles(logFile, backupFile, maxBytes = 12)

            assertFalse(tail.contains("ancient-log-line"))
            assertEquals("line4\nline5", tail)
        } finally {
            dir.deleteRecursively()
        }
    }
}
