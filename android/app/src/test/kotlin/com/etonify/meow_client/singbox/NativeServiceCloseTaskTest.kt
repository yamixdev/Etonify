package com.etonify.meow_client.singbox

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeServiceCloseTaskTest {
    private val restart = NativeRestartRequest("network_handover_unhealthy", 10L, 2L, 5L, requireRuntimeIntent = true)

    @Test
    fun `late success consumes the newest deferred restart exactly once`() {
        val release = CountDownLatch(1)
        val task = NativeServiceCloseTask { check(release.await(5, TimeUnit.SECONDS)) }
        val newer = restart.copy(startToken = 11L)
        task.start {}
        try {
            assertTrue(task.deferRestart(restart))
            assertFalse(task.awaitClosed(5))
            assertNull(task.takeRestart())
            assertTrue(task.deferRestart(newer))
            release.countDown()
            assertTrue(task.awaitClosed(1_000))
            assertEquals(newer, task.takeRestart())
            assertNull(task.takeRestart())
        } finally {
            release.countDown()
        }
    }

    @Test
    fun `stop can discard a deferred restart before the original close succeeds`() {
        val release = CountDownLatch(1)
        val task = NativeServiceCloseTask { check(release.await(5, TimeUnit.SECONDS)) }
        task.start {}
        try {
            assertTrue(task.deferRestart(restart))
            task.cancelRestart()
            release.countDown()
            assertTrue(task.awaitClosed(1_000))
            assertNull(task.takeRestart())
        } finally {
            release.countDown()
        }
    }

    @Test
    fun `failed close never releases a restart or accepts another one`() {
        val release = CountDownLatch(1)
        val completed = CountDownLatch(1)
        val task = NativeServiceCloseTask {
            check(release.await(5, TimeUnit.SECONDS))
            error("native close failed")
        }
        task.start { completed.countDown() }
        try {
            assertTrue(task.deferRestart(restart))
            release.countDown()
            assertTrue(completed.await(1, TimeUnit.SECONDS))
            assertNull(task.takeRestart())
            assertFalse(task.deferRestart(restart.copy(startToken = 11L)))
        } finally {
            release.countDown()
        }
    }

    @Test
    fun `completed restart requires the same owner and a still valid start request`() {
        assertTrue(restart.canResume(true, 2L, 5L, 5L, true))
        assertFalse(restart.canResume(false, 2L, 5L, 5L, true))
        assertFalse(restart.canResume(true, 3L, 5L, 5L, true))
        assertFalse(restart.canResume(true, 2L, 6L, 6L, true))
        assertFalse(restart.canResume(true, 2L, 5L, 6L, true))
        assertFalse(restart.canResume(true, 2L, 5L, 5L, false))
        assertTrue(restart.copy(requireRuntimeIntent = false).canResume(true, 2L, 5L, 5L, false))
    }

    @Test
    fun `stalled close reports diagnostics once without blocking waiters or cancelling cleanup`() {
        val closeRelease = CountDownLatch(1)
        val reportEntered = CountDownLatch(1)
        val reportRelease = CountDownLatch(1)
        val reports = AtomicInteger()
        val task = NativeServiceCloseTask(onTimeout = {
            reports.incrementAndGet()
            reportEntered.countDown()
            check(reportRelease.await(5, TimeUnit.SECONDS))
        }) { check(closeRelease.await(5, TimeUnit.SECONDS)) }
        task.start {}
        try {
            assertFalse(task.awaitClosed(5))
            assertTrue(reportEntered.await(1, TimeUnit.SECONDS))
            repeat(3) { assertFalse(task.awaitClosed(5)) }
            assertEquals(1, reports.get())
            closeRelease.countDown()
            assertTrue(task.awaitClosed(1_000))
        } finally {
            closeRelease.countDown()
            reportRelease.countDown()
        }
    }

    @Test
    fun `completed close does not collect a stalled dump`() {
        val reports = AtomicInteger()
        val task = NativeServiceCloseTask(onTimeout = { reports.incrementAndGet() }) {}
        task.start {}
        assertTrue(task.awaitClosed(1_000))
        assertEquals(0, reports.get())
    }

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
