package com.etonify.meow_client.singbox

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class StandaloneCommandClientsTest {
    private class Client {
        val closes = AtomicInteger()
        val cancelled = CountDownLatch(1)
    }

    private fun clients() = StandaloneCommandClients(
        create = { Client() },
        disconnect = { client: Client -> client.closes.incrementAndGet(); client.cancelled.countDown() },
    )

    @Test fun blockedLookupDoesNotDelayControl() {
        val clients = clients()
        val executor = Executors.newFixedThreadPool(2)
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        try {
            val lookup = executor.submit<Client> {
                clients.lookup { client -> started.countDown(); release.await(); client }
            }
            assertTrue(started.await(2, TimeUnit.SECONDS))
            val control = executor.submit<Client> { clients.control { it } }.get(2, TimeUnit.SECONDS)
            assertEquals(0, control.closes.get())
            release.countDown()
            val queried = lookup.get(2, TimeUnit.SECONDS)
            assertNotSame(control, queried)
            assertEquals(1, queried.closes.get())
        } finally { release.countDown(); clients.clear(); executor.shutdownNow() }
    }

    @Test fun clearCancelsInFlightLookupWithoutWaitingForIt() {
        val clients = clients()
        val executor = Executors.newSingleThreadExecutor()
        val started = CountDownLatch(1)
        try {
            val lookup = executor.submit<Client> {
                clients.lookup { client -> started.countDown(); client.cancelled.await(); client }
            }
            assertTrue(started.await(2, TimeUnit.SECONDS))
            clients.clear()
            assertEquals(1, lookup.get(2, TimeUnit.SECONDS).closes.get())
        } finally { clients.clear(); executor.shutdownNow() }
    }

    @Test fun staleControlFailureCannotEvictReplacement() {
        val clients = clients()
        val executor = Executors.newSingleThreadExecutor()
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        try {
            val old = executor.submit<Boolean> {
                runCatching { clients.control<Unit> { started.countDown(); release.await(); error("old") } }.isFailure
            }
            assertTrue(started.await(2, TimeUnit.SECONDS))
            clients.clear()
            val replacement = clients.control { it }
            release.countDown()
            assertTrue(old.get(2, TimeUnit.SECONDS))
            assertSame(replacement, clients.control { it })
            assertEquals(0, replacement.closes.get())
        } finally { release.countDown(); clients.clear(); executor.shutdownNow() }
    }

    @Test fun lookupFailureDoesNotDiscardReusableControl() {
        val clients = clients()
        val control = clients.control { it }
        var failed: Client? = null
        try {
            assertTrue(runCatching { clients.lookup<Unit> { failed = it; error("lookup") } }.isFailure)
            assertEquals(1, failed!!.closes.get())
            assertSame(control, clients.control { it })
            clients.clear()
            clients.clear()
            assertEquals(1, control.closes.get())
        } finally { clients.clear() }
    }
}
