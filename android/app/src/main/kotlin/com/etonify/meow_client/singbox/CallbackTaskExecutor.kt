package com.etonify.meow_client.singbox

import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException

/** Executes bounded background work without ever losing its completion callback. */
internal class CallbackTaskExecutor(
    private val worker: Executor,
    private val callbackExecutor: Executor,
) {
    fun <T> execute(task: () -> T, callback: (Result<T>) -> Unit) {
        fun deliver(result: Result<T>) {
            callbackExecutor.execute { callback(result) }
        }

        try {
            worker.execute { deliver(runCatching(task)) }
        } catch (error: RejectedExecutionException) {
            deliver(Result.failure(error))
        }
    }
}
