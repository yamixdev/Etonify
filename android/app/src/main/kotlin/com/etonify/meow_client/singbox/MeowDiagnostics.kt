package com.etonify.meow_client.singbox

import android.util.Log
import com.etonify.meow_client.MeowApplication
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

object MeowDiagnostics {
    private const val MAX_LOG_BYTES = 256 * 1024
    private const val KEEP_LOG_BYTES = 160 * 1024
    private const val CRASH_LOG_BYTES = 64 * 1024
    private const val FLUSH_DELAY_MS = 250L
    private const val IMMEDIATE_FLUSH_CHARS = 8 * 1024
    private val fileLock = Any()
    private val pendingLock = Any()
    private val pendingLines = StringBuilder()
    private val flushScheduled = AtomicBoolean(false)
    private val writer = Executors.newSingleThreadScheduledExecutor { runnable ->
        Thread(runnable, "MeowDiagnosticsWriter").apply { isDaemon = true }
    }
    private val timestampFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", Locale.US)

    private val diagnosticsFile: File
        get() = File(MeowApplication.application.filesDir, "meow-native-diagnostics.log")

    private val diagnosticsBackupFile: File
        get() = File(MeowApplication.application.filesDir, "meow-native-diagnostics.log.1")

    fun log(tag: String, message: String, error: Throwable? = null) {
        runCatching {
            val flushNow = synchronized(pendingLock) {
                val safeMessage = MeowLogSanitizer.redact(message)
                val line = buildString {
                    append('[')
                    append(timestampFormat.format(Date()))
                    append("] ")
                    append(tag)
                    append(": ")
                    append(safeMessage)
                    if (error != null) {
                        append('\n')
                        append(MeowLogSanitizer.redact(Log.getStackTraceString(error).trim()))
                    }
                    append('\n')
                }
                pendingLines.append(line)
                pendingLines.length >= IMMEDIATE_FLUSH_CHARS || error != null
            }
            if (flushNow) {
                writer.execute(::flushPending)
            } else if (flushScheduled.compareAndSet(false, true)) {
                writer.schedule(::flushPending, FLUSH_DELAY_MS, TimeUnit.MILLISECONDS)
            }
        }
    }

    fun readTail(maxBytes: Int = KEEP_LOG_BYTES): String {
        flushPendingBlocking()
        return runCatching {
            synchronized(fileLock) {
                readTailFromFiles(diagnosticsFile, diagnosticsBackupFile, maxBytes)
            }
        }.getOrDefault("")
    }

    fun readCrashReportTail(maxBytes: Int = CRASH_LOG_BYTES): String {
        return runCatching {
            synchronized(fileLock) {
                val workingDir = MeowApplication.singboxWorkingDirectory
                val report = workingDir.listFiles()
                    ?.filter { it.isFile && it.name.startsWith("CrashReport-") && it.length() > 0L }
                    ?.maxByOrNull { it.lastModified() }
                    ?: return ""
                MeowLogSanitizer.redact(
                    "file=${report.name} modifiedAtMillis=${report.lastModified()}\n" +
                        readFileTail(report, maxBytes),
                )
            }
        }.getOrDefault("")
    }

    fun readLatestOomReportMetadata(): String {
        return runCatching {
            synchronized(fileLock) {
                val workingDir = File(MeowApplication.singboxWorkingDirectory, "oom_reports")
                val metadata = workingDir.walkTopDown()
                    .filter { it.isFile && it.name == "metadata.json" }
                    .maxByOrNull { it.lastModified() }
                    ?: return ""
                MeowLogSanitizer.redact(metadata.readText().trim())
            }
        }.getOrDefault("")
    }

    private fun flushPendingBlocking() {
        runCatching {
            writer.submit(::flushPending).get(1, TimeUnit.SECONDS)
        }
    }

    private fun flushPending() {
        val payload = synchronized(pendingLock) {
            if (pendingLines.isEmpty()) {
                flushScheduled.set(false)
                return
            }
            pendingLines.toString().also {
                pendingLines.setLength(0)
                flushScheduled.set(false)
            }
        }
        runCatching {
            synchronized(fileLock) {
                val file = diagnosticsFile
                file.parentFile?.mkdirs()
                file.appendText(payload)
                rotateIfNeeded(file, diagnosticsBackupFile, MAX_LOG_BYTES)
            }
        }
    }

    fun pruneLegacyRuntimeFiles() {
        val filesDir = runCatching {
            MeowApplication.application.getExternalFilesDir(null)
        }.getOrNull() ?: MeowApplication.application.filesDir
        val legacyFiles = listOf(
            File(filesDir, "meow-runtime.log"),
            File(filesDir, "meow-runtime.level"),
        )
        runCatching {
            for (file in legacyFiles) {
                if (file.exists()) {
                    file.delete()
                }
            }
        }
    }

    internal fun rotateIfNeeded(file: File, backup: File, maxBytes: Int = MAX_LOG_BYTES): Boolean {
        if (!file.exists() || file.length() <= maxBytes) {
            return false
        }
        if (backup.exists()) {
            backup.delete()
        }
        val renamed = file.renameTo(backup)
        if (!renamed) {
            runCatching {
                file.copyTo(backup, overwrite = true)
                file.delete()
            }
        }
        return true
    }

    internal fun readTailFromFiles(file: File, backup: File, maxBytes: Int): String {
        val fileExists = file.exists() && file.length() > 0L
        val backupExists = backup.exists() && backup.length() > 0L

        if (!fileExists && !backupExists) {
            return ""
        }

        val fileTail = if (fileExists) readFileTail(file, maxBytes) else ""
        val fileTailByteCount = fileTail.toByteArray(Charsets.UTF_8).size
        val remainingBytes = maxBytes - fileTailByteCount

        val result = if (remainingBytes > 0 && backupExists) {
            val backupTail = readFileTail(backup, remainingBytes)
            if (backupTail.isNotEmpty() && fileTail.isNotEmpty()) {
                "$backupTail\n$fileTail"
            } else if (backupTail.isNotEmpty()) {
                backupTail
            } else {
                fileTail
            }
        } else {
            fileTail
        }
        return MeowLogSanitizer.redact(result)
    }

    internal fun readFileTail(file: File, maxBytes: Int): String {
        if (!file.exists() || file.length() == 0L || maxBytes <= 0) {
            return ""
        }
        val bytes = file.readBytes()
        var start = (bytes.size - maxBytes.coerceAtLeast(0)).coerceAtLeast(0)
        if (start > 0) {
            while (start < bytes.size && bytes[start - 1] != '\n'.code.toByte()) {
                start++
            }
        }
        return bytes.copyOfRange(start, bytes.size).toString(Charsets.UTF_8).trim()
    }
}
