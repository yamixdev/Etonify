package com.etonify.meow_client.singbox

import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicBoolean

/**
 * One close operation per native service lifetime. A timeout only bounds the
 * caller's wait: interrupting JNI does not cancel Go cleanup. Retain the
 * original result instead of queuing more JNI calls or replacing a failed
 * close with a subsequent no-op's successful result.
 */
internal class NativeServiceCloseTask(close: () -> Unit) {
    private val started = AtomicBoolean(false)
    private val result = FutureTask { runCatching(close) }

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
        false
    } catch (_: InterruptedException) {
        Thread.currentThread().interrupt()
        false
    }
}
