package com.etonify.meow_client.root

import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.json.JSONObject

data class RootCommandResult(val exitCode: Int, val stdout: String, val stderr: String)

class RootCapabilityProbe(private val command: () -> RootCommandResult = { RootProcessRunner().execute("id -u") }) {
    fun requestAuthorization(): String = try {
        val result = command()
        if (result.exitCode == 0 && result.stdout.trim() == "0") "granted" else "denied"
    } catch (error: RootModuleException) { throw error
    } catch (_: IOException) { "noSu"
    } catch (_: Exception) { "denied" }
}

open class RootProcessRunner(private val startProcess: (ProcessBuilder) -> Process = { it.start() }) {
    open fun execute(command: String, input: ByteArray? = null, timeoutMs: Long = 30_000): RootCommandResult {
        return executeStreaming(command, input?.inputStream(), timeoutMs)
    }

    open fun executeStreaming(command: String, input: java.io.InputStream?, timeoutMs: Long = 30_000): RootCommandResult {
        val process = startTrustedProcess(command)
        val workers = Executors.newFixedThreadPool(3) { runnable -> Thread(runnable, "etonify-root-io").apply { isDaemon = true } }
        val out = workers.submit<String> { boundedText(process.inputStream) }
        val err = workers.submit<String> { boundedText(process.errorStream) }
        val writer = workers.submit { process.outputStream.use { if (input != null) input.copyTo(it, 32768) } }
        val deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(timeoutMs)
        try {
            if (!process.waitFor(timeoutMs, TimeUnit.MILLISECONDS)) throw RootModuleException("root_command_timeout")
            val remaining = { maxOf(1L, deadline - System.nanoTime()) }
            writer.get(remaining(), TimeUnit.NANOSECONDS)
            return RootCommandResult(process.exitValue(), out.get(remaining(), TimeUnit.NANOSECONDS), err.get(remaining(), TimeUnit.NANOSECONDS))
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
            throw RootModuleException("operation_cancelled")
        } finally {
            process.outputStream.runCatching { close() }
            process.inputStream.runCatching { close() }
            process.errorStream.runCatching { close() }
            if (process.isAlive) { process.destroy(); process.destroyForcibly() }
            workers.shutdownNow()
        }
    }

    private fun startTrustedProcess(command: String): Process {
        var failure: IOException? = null
        for (executable in SU_EXECUTABLES) {
            // Fixed privileged locations only: never search the inherited PATH.
            // Execute the spelling itself; KernelSU may provide virtual sucompat
            // and Magisk may expose su as a symlink to its multi-call binary.
            val builder = ProcessBuilder(executable, "-c", "PATH=$TRUSTED_PATH; export PATH; $command")
            builder.environment()["PATH"] = TRUSTED_PATH
            try { return startProcess(builder) }
            catch (error: IOException) { failure = error }
        }
        throw failure ?: IOException("su_not_found")
    }

    companion object {
        const val ROOT = "/data/adb/etonify"
        private const val TRUSTED_PATH = "/system/bin:/system/xbin"
        private val SU_EXECUTABLES = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/debug_ramdisk/su",
            "/su/bin/su", "/data/adb/ksu/bin/su", "/data/adb/ap/bin/su",
        )
        internal fun quote(value: String): String {
            require(!value.contains('\u0000'))
            return "'" + value.replace("'", "'\"'\"'") + "'"
        }

        internal fun boundedText(input: java.io.InputStream): String {
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(4096)
            var total = 0
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                total += count
                if (total > 65536) throw RootModuleException("root_output_exceeded")
                output.write(buffer, 0, count)
            }
            return output.toString("UTF-8")
        }

        internal fun captureAndDrain(input: java.io.InputStream): String {
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(4096)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) return output.toString("UTF-8")
                val capture = minOf(count, 65536 - output.size())
                if (capture > 0) output.write(buffer, 0, capture)
            }
        }
    }
}
