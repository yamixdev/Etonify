package com.etonify.meow_client

import java.util.concurrent.Executor
import java.util.concurrent.Executors
import com.etonify.meow_client.singbox.CallbackTaskExecutor

internal class StartupTaskRunner(private val delivery: Executor) : AutoCloseable {
    private val worker = Executors.newSingleThreadExecutor()
    private val tasks = CallbackTaskExecutor(worker, delivery)
    @Volatile private var closed = false

    fun <T> execute(task: () -> T, callback: (Result<T>) -> Unit) {
        if (closed) return
        tasks.execute(task) { result ->
            if (!closed) callback(result)
        }
    }

    override fun close() {
        closed = true
        // Keystore writes must finish atomically even if the engine detaches.
        worker.shutdown()
    }
}
