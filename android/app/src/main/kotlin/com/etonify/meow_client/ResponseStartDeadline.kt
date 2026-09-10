package com.etonify.meow_client

import java.net.SocketTimeoutException
import java.util.concurrent.atomic.AtomicBoolean

/** Distinguish our deliberate socket cancellation from a peer closing it. */
internal class ResponseStartDeadline(private val timeoutMillis: Int) {
    private val expired = AtomicBoolean(false)
    fun expire(disconnect: () -> Unit) {
        expired.set(true)
        disconnect()
    }
    fun failure(error: Exception): Exception = if (expired.get()) {
        SocketTimeoutException("HTTP response timed out after ${timeoutMillis}ms")
            .apply { initCause(error) }
    } else error
}
