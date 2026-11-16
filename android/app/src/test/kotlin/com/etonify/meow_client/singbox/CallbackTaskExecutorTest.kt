package com.etonify.meow_client.singbox

import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
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
        val workQueue = ArrayDeque<Runnable>()
        val callbackQueue = ArrayDeque<Runnable>()
        val executor = CallbackTaskExecutor(
            worker = Executor { workQueue.addLast(it) },
            callbackExecutor = Executor { callbackQueue.addLast(it) },
        )
        var workRan = false
        var delivered: Result<Int>? = null

        executor.execute(task = {
            workRan = true
            42
        }) { delivered = it }

        assertFalse(workRan)
        assertTrue(callbackQueue.isEmpty())
        workQueue.removeFirst().run()
        assertTrue(workRan)
        assertNull(delivered)
        callbackQueue.removeFirst().run()
        assertEquals(42, delivered?.getOrNull())
    }
}
