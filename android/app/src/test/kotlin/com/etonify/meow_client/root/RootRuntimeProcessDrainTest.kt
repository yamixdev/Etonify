package com.etonify.meow_client.root

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class RootRuntimeProcessDrainTest {
    @Test fun `crashed process is not proof of successful cleanup`() {
        assertFalse(stoppedAfterCrash(cleanupExit = 1))
        assertTrue(stoppedAfterCrash(cleanupExit = 0))
    }

    private fun stoppedAfterCrash(cleanupExit: Int): Boolean {
        val child = object : Process() {
            override fun getInputStream() = ByteArrayInputStream(ByteArray(0))
            override fun getErrorStream() = ByteArrayInputStream(ByteArray(0))
            override fun getOutputStream() = ByteArrayOutputStream()
            override fun waitFor() = 1
            override fun waitFor(timeout: Long, unit: TimeUnit) = true
            override fun exitValue() = 1
            override fun destroy() {}
            override fun isAlive() = false
        }
        val runner = object : RootProcessRunner() {
            override fun execute(command: String, input: ByteArray?, timeoutMs: Long): RootCommandResult {
                assertTrue(command.contains("/etonify-root cleanup --work-dir /data/adb/etonify/runtime"))
                return RootCommandResult(cleanupExit, "", "")
            }
        }
        return RootRuntimeProcess(child, runner, "/data/adb/etonify/runtime/session-test.pid", "{}").stop(100)
    }

    @Test fun `running process stderr remains drained after capture limit`() {
        val reachedEof = CountDownLatch(1)
        val diagnostics = object : ByteArrayInputStream(ByteArray(1024 * 1024) { 'x'.code.toByte() }) {
            override fun read(buffer: ByteArray, offset: Int, length: Int): Int = super.read(buffer, offset, length).also {
                if (it < 0) reachedEof.countDown()
            }
        }
        val child = object : Process() {
            private val stdout = ByteArrayInputStream("{\"ready\":true,\"protocol\":1}\n".toByteArray())
            private val stdin = ByteArrayOutputStream()
            override fun getInputStream() = stdout
            override fun getErrorStream() = diagnostics
            override fun getOutputStream() = stdin
            override fun waitFor() = 0
            override fun waitFor(timeout: Long, unit: TimeUnit) = true
            override fun exitValue() = 0
            override fun destroy() {}
            override fun isAlive() = false
        }
        val runtime = RootRuntimeProcess(child, RootProcessRunner(), "/data/adb/etonify/runtime/session-test.pid", "{}")
        try {
            assertTrue(runtime.awaitReady(2000))
            assertTrue(reachedEof.await(2, TimeUnit.SECONDS))
            assertEquals(0, diagnostics.available())
        } finally { runtime.close() }
    }
}
