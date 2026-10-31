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
        if (result.exitCode == 0 && (result.stdout == "0\n" || result.stdout == "0")) "granted" else "denied"
    } catch (_: IOException) { "noSu"
    } catch (_: Exception) { "denied" }
}

open class RootProcessRunner {
    open fun execute(command: String, input: ByteArray? = null, timeoutMs: Long = 30_000): RootCommandResult {
        return executeStreaming(command, input?.inputStream(), timeoutMs)
    }

    open fun executeStreaming(command: String, input: java.io.InputStream?, timeoutMs: Long = 30_000): RootCommandResult {
        val process = ProcessBuilder("su", "-c", command).start()
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

    fun startRuntime(configJson: String, appUid: Int, socketPath: String): RootRuntimeProcess {
        val canonicalConfig = try { JSONObject(configJson).toString() } catch (_: Exception) {
            throw RootModuleException("runtime_arguments_invalid")
        }
        if (appUid < 10000 || !socketPath.startsWith("/data/") || socketPath.contains('\n') || socketPath.contains('\u0000') ||
            canonicalConfig.toByteArray(Charsets.UTF_8).size > 16 * 1024 * 1024) {
            throw RootModuleException("runtime_arguments_invalid")
        }
        val token = java.util.UUID.randomUUID().toString().replace("-", "")
        val pidFile = "$ROOT/runtime/session-$token.pid"
        val script = "set -eu; umask 077; mkdir -p $ROOT/runtime; chown 0:0 $ROOT/runtime; chmod 700 $ROOT/runtime; " +
            "echo \$\$ > $pidFile; exec $ROOT/current/etonify-root run --uid $appUid --socket ${quote(socketPath)} --work-dir $ROOT/runtime"
        val process = ProcessBuilder("su", "-c", script).start()
        return RootRuntimeProcess(process, this, pidFile, canonicalConfig)
    }

    companion object {
        const val ROOT = "/data/adb/etonify"
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

class RootRuntimeProcess internal constructor(
    val process: Process,
    private val runner: RootProcessRunner,
    private val pidFile: String,
    configJson: String,
) : Closeable {
    @Volatile var failureCode: String? = null
        private set
    private val io = Executors.newFixedThreadPool(3) { runnable -> Thread(runnable, "etonify-root-runtime-io").apply { isDaemon = true } }
    private val writer = io.submit {
        process.outputStream.write((configJson + "\n").toByteArray(Charsets.UTF_8))
        process.outputStream.flush()
    }
    private val ready = io.submit<Boolean> {
        val line = ByteArrayOutputStream()
        while (true) {
            val next = process.inputStream.read()
            if (next < 0) { failureCode = "runtime_start_failed"; return@submit false }
            if (next == 10) break
            if (line.size() >= 4096) { failureCode = "runtime_start_failed"; return@submit false }
            line.write(next)
        }
        val result = RootRuntimeHandshake.parse(line.toString("UTF-8"))
        failureCode = result.failureCode
        if (result.ready) io.submit { RootProcessRunner.captureAndDrain(process.inputStream) }
        result.ready
    }
    private val stderr = io.submit<String> { RootProcessRunner.captureAndDrain(process.errorStream) }

    fun awaitReady(timeoutMs: Long = 30_000): Boolean = try {
        val started = System.nanoTime()
        writer.get(timeoutMs, TimeUnit.MILLISECONDS)
        val remaining = maxOf(1L, TimeUnit.MILLISECONDS.toNanos(timeoutMs) - (System.nanoTime() - started))
        ready.get(remaining, TimeUnit.NANOSECONDS)
    } catch (_: java.util.concurrent.TimeoutException) { failureCode = "runtime_start_timeout"; false
    } catch (_: InterruptedException) { Thread.currentThread().interrupt(); failureCode = "operation_cancelled"; false
    } catch (_: Exception) { if (failureCode == null) failureCode = "runtime_start_failed"; false }

    fun closeLease() { process.outputStream.runCatching { close() } }

    private fun confirmExitedCleanup(): Boolean {
        if (process.exitValue() == 0) return true
        // A crash/SIGKILL skips deferred teardown. The trusted, root-owned
        // module must recover its journal before ownership can be released.
        return runner.execute(
            "exec timeout -s KILL 15 ${RootProcessRunner.ROOT}/current/etonify-root cleanup --work-dir ${RootProcessRunner.ROOT}/runtime",
            timeoutMs = 20_000,
        ).exitCode == 0
    }

    fun stop(timeoutMs: Long = 8_000): Boolean {
        val restoreInterrupt = Thread.interrupted()
        closeLease()
        try {
            if (process.waitFor(timeoutMs, TimeUnit.MILLISECONDS)) return confirmExitedCleanup()
            val root = RootProcessRunner.ROOT
            val script = "set -eu; p=\$(cat $pidFile); case \"\$p\" in ''|*[!0-9]*) exit 1;; esac; " +
                "test \"\$(readlink /proc/\$p/exe)\" = \"\$(readlink -f $root/current/etonify-root)\"; " +
                "kill -TERM -- -\$p; sleep 1; " +
                "if test \"\$(readlink /proc/\$p/exe 2>/dev/null)\" = \"\$(readlink -f $root/current/etonify-root)\"; then kill -KILL -- -\$p; fi"
            runner.execute(script, timeoutMs = 4_000)
            return process.waitFor(2_000, TimeUnit.MILLISECONDS) && confirmExitedCleanup()
        } catch (_: Exception) { return false
        } finally {
            if (process.isAlive) process.destroyForcibly()
            process.inputStream.runCatching { close() }
            process.errorStream.runCatching { close() }
            stderr.cancel(true)
            io.shutdownNow()
            if (restoreInterrupt) Thread.currentThread().interrupt()
        }
    }

    override fun close() { stop() }
}
