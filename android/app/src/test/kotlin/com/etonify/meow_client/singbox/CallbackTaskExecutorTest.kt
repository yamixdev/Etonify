package com.etonify.meow_client.singbox

import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CallbackTaskExecutorTest {
    @Test
    fun `rejected task completes its callback with the queue error`() {
        val worker = Executor { throw RejectedExecutionException("lookup queue is full") }
        val executor = CallbackTaskExecutor(worker, Executor(Runnable::run))
        var delivered: Result<Int>? = null

        executor.execute(task = { 42 }) { delivered = it }

        assertNotNull(delivered)
        val result = requireNotNull(delivered)
        assertTrue(result.isFailure)
        assertEquals("lookup queue is full", result.exceptionOrNull()?.message)
    }

    @Test
    fun `accepted task delivers its result through the callback executor`() {
        val executor = CallbackTaskExecutor(
            worker = Executor(Runnable::run),
            callbackExecutor = Executor(Runnable::run),
        )
        var delivered: Result<Int>? = null

        executor.execute(task = { 42 }) { delivered = it }

        assertEquals(42, delivered?.getOrNull())
    }
}
