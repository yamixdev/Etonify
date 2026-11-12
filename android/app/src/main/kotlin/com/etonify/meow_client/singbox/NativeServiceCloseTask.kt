package com.etonify.meow_client.singbox

import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicBoolean

internal data class NativeRestartRequest(
    val source: String,
    val startToken: Long,
    val externalStopRevision: Long,
    val runtimeGeneration: Long,
    val requireRuntimeIntent: Boolean,
) {
    fun canResume(
        startTokenCurrent: Boolean,
        currentExternalStopRevision: Long,
        currentServiceGeneration: Long,
        activeRuntimeGeneration: Long,
        hasRuntimeIntent: Boolean,
    ): Boolean = startTokenCurrent &&
        externalStopRevision == currentExternalStopRevision &&
        runtimeGeneration == currentServiceGeneration &&
        runtimeGeneration == activeRuntimeGeneration &&
        (!requireRuntimeIntent || hasRuntimeIntent)
}

/**
 * One close operation per native service lifetime. A timeout only bounds the
 * caller's wait: interrupting JNI does not cancel Go cleanup. Retain the
 * original result instead of queuing more JNI calls or replacing a failed
 * close with a subsequent no-op's successful result.
 */
internal class NativeServiceCloseTask(
    private val onTimeout: (() -> Unit)? = null,
    close: () -> Unit,
) {
    private val started = AtomicBoolean(false)
    private val timeoutReported = AtomicBoolean(false)
    private val result = FutureTask { runCatching(close) }
    // Owned by the service executor, including the posted completion handler.
    private var pendingRestart: NativeRestartRequest? = null

    val hasDeferredRestart: Boolean get() = pendingRestart != null

    fun deferRestart(request: NativeRestartRequest): Boolean {
        if (result.isDone && result.get().isFailure) return false
        pendingRestart = request
        return true
    }

    fun takeRestart(): NativeRestartRequest? {
        if (!result.isDone || result.get().isFailure) return null
        return pendingRestart.also { pendingRestart = null }
    }

    fun cancelRestart() {
        pendingRestart = null
    }

    fun start(onComplete: (Result<Unit>) -> Unit) {
        if (!started.compareAndSet(false, true)) return
        Thread({
            result.run()
            onComplete(result.get())
        }, "MeowNativeServiceClose").apply {
            isDaemon = true
            start()
        }
    }

    fun awaitClosed(timeoutMs: Long): Boolean = try {
        result.get(timeoutMs, TimeUnit.MILLISECONDS).isSuccess
    } catch (_: TimeoutException) {
        if (onTimeout != null && !result.isDone && timeoutReported.compareAndSet(false, true)) {
            Thread({ runCatching(onTimeout) }, "MeowNativeCloseDiagnostics").apply {
                isDaemon = true
                start()
            }
        }
        false
    } catch (_: InterruptedException) {
        Thread.currentThread().interrupt()
        false
    }
}
