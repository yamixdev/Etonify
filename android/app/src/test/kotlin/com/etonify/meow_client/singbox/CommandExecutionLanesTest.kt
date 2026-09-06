package com.etonify.meow_client.singbox

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CommandExecutionLanesTest {
    @Test
    fun `blocked RPC does not block stream connect or disconnect`() {
        val lanes = CommandExecutionLanes()
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val streamFinished = CountDownLatch(1)
        val nextCommand = CountDownLatch(1)
        val events = mutableListOf<String>()
        try {
            lanes.commands.execute {
                entered.countDown()
                check(release.await(5, TimeUnit.SECONDS))
            }
            assertTrue(entered.await(1, TimeUnit.SECONDS))
            lanes.commands.execute { nextCommand.countDown() }
            lanes.stream.execute { events.add("connect") }
            lanes.stream.execute {
                events.add("disconnect")
                streamFinished.countDown()
            }
            assertTrue(streamFinished.await(1, TimeUnit.SECONDS))
            assertEquals(listOf("connect", "disconnect"), events)
            assertEquals(1L, nextCommand.count)
            release.countDown()
            assertTrue(nextCommand.await(1, TimeUnit.SECONDS))
        } finally {
            release.countDown()
            lanes.close()
        }
    }
}
