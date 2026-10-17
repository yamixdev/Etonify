package com.etonify.meow_client

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class StartupTaskRunnerTest {
    @Test
    fun `slow key work does not block caller and capability work stays serialized`() {
        val release = CountDownLatch(1)
        val started = CountDownLatch(1)
        val completed = CountDownLatch(2)
        val order = mutableListOf<String>()
        val caller = Thread.currentThread()
        val runner = StartupTaskRunner(Executor(Runnable::run))
        try {
            runner.execute({
                assertNotSame(caller, Thread.currentThread())
                started.countDown()
                assertTrue(release.await(2, TimeUnit.SECONDS))
                order.add("key")
                32
            }) { assertEquals(32, it.getOrThrow()); completed.countDown() }
            assertTrue(started.await(2, TimeUnit.SECONDS))
            runner.execute({ order.add("core"); "compatible" }) {
                assertEquals("compatible", it.getOrThrow()); completed.countDown()
            }
            assertEquals(2L, completed.count)
            release.countDown()
            assertTrue(completed.await(2, TimeUnit.SECONDS))
            assertEquals(listOf("key", "core"), order)
        } finally { release.countDown(); runner.close() }
    }

    @Test
    fun `detached engine never receives a queued reply`() {
        val delivery = mutableListOf<Runnable>()
        val queued = CountDownLatch(1)
        val runner = StartupTaskRunner(Executor { synchronized(delivery) { delivery.add(it) }; queued.countDown() })
        var delivered = false
        runner.execute({ 32 }) { delivered = true }
        assertTrue(queued.await(2, TimeUnit.SECONDS))
        runner.close()
        synchronized(delivery) { delivery.toList() }.forEach(Runnable::run)
        assertFalse(delivered)
    }
}
