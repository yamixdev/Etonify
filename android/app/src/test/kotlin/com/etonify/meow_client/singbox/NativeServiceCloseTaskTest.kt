package com.etonify.meow_client.singbox

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeServiceCloseTaskTest {
    @Test
    fun `timeout and repeated stop keep waiting for the original native close`() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val completed = CountDownLatch(1)
        val calls = AtomicInteger()
        val task = NativeServiceCloseTask {
            calls.incrementAndGet()
            entered.countDown()
            check(release.await(5, TimeUnit.SECONDS))
        }
        task.start { result ->
            if (result.isSuccess) completed.countDown()
        }
        try {
            assertTrue(entered.await(1, TimeUnit.SECONDS))
            repeat(3) {
                assertFalse(task.awaitClosed(5))
                task.start { error("Must not start a second close") }
            }
            assertEquals(1, calls.get())
            assertEquals(1L, completed.count)
            // JNI cleanup was not interrupted by any of the timed-out waits.
            release.countDown()
            assertTrue(task.awaitClosed(1_000))
            assertTrue(completed.await(1, TimeUnit.SECONDS))
            assertEquals(1, calls.get())
        } finally {
            release.countDown()
        }
    }

    @Test
    fun `close exception stays unconfirmed on every later wait`() {
        val calls = AtomicInteger()
        val reported = CountDownLatch(1)
        val task = NativeServiceCloseTask {
            calls.incrementAndGet()
            error("native close failed")
        }
        task.start { if (it.isFailure) reported.countDown() }
        assertFalse(task.awaitClosed(1_000))
        assertTrue(reported.await(1, TimeUnit.SECONDS))
        task.start { error("Must not retry a failed close as a new operation") }
        assertFalse(task.awaitClosed(1_000))
        assertEquals(1, calls.get())
    }

    @Test
    fun `new native lifetime has an independent close result`() {
        val old = NativeServiceCloseTask { error("old failure") }
        old.start {}
        assertFalse(old.awaitClosed(1_000))
        val next = NativeServiceCloseTask {}
        next.start {}
        assertTrue(next.awaitClosed(1_000))
        assertFalse(old.awaitClosed(1_000))
    }

    @Test
    fun `interrupted waiter does not cancel native cleanup`() {
        val release = CountDownLatch(1)
        val task = NativeServiceCloseTask { check(release.await(5, TimeUnit.SECONDS)) }
        task.start {}
        try {
            Thread.currentThread().interrupt()
            assertFalse(task.awaitClosed(1_000))
            assertTrue(Thread.interrupted())
            release.countDown()
            assertTrue(task.awaitClosed(1_000))
        } finally {
            Thread.interrupted()
            release.countDown()
        }
    }
}
