package com.etonify.meow_client.root

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class RootTrustedProcessTest {
    @Test fun `root executable is absolute and shell cannot inherit an untrusted PATH`() {
        val calls = mutableListOf<List<String>>()
        val runner = RootProcessRunner { builder ->
            calls.add(builder.command().toList())
            assertEquals("/system/bin:/system/xbin", builder.environment()["PATH"])
            CompletedProcess(0, "0\n")
        }
        assertEquals("granted", RootCapabilityProbe { runner.execute("id -u") }.requestAuthorization())
        assertEquals(listOf(listOf("/system/bin/su", "-c", "PATH=/system/bin:/system/xbin; export PATH; id -u")), calls)
    }

    @Test fun `missing absolute candidate falls through to another fixed absolute path`() {
        val calls = mutableListOf<String>()
        val runner = RootProcessRunner { builder ->
            calls.add(builder.command()[0])
            if (calls.size == 1) throw IOException("not found")
            CompletedProcess(0, "0\n")
        }
        assertEquals("granted", RootCapabilityProbe { runner.execute("id -u") }.requestAuthorization())
        assertEquals(listOf("/system/bin/su", "/system/xbin/su"), calls)
    }

    @Test fun `launched refusal or nonroot result never tries another provider`() {
        for (process in listOf(CompletedProcess(1, "0\n"), CompletedProcess(0, "2000\n"))) {
            var calls = 0
            val runner = RootProcessRunner { calls++; process }
            assertEquals("denied", RootCapabilityProbe { runner.execute("id -u") }.requestAuthorization())
            assertEquals(1, calls)
        }
    }

    @Test fun `missing all trusted candidates is noSu without any relative executable`() {
        val calls = mutableListOf<String>()
        val runner = RootProcessRunner { builder -> calls.add(builder.command()[0]); throw IOException("missing") }
        assertEquals("noSu", RootCapabilityProbe { runner.execute("id -u") }.requestAuthorization())
        assertEquals(listOf("/system/bin/su", "/system/xbin/su", "/sbin/su", "/debug_ramdisk/su", "/su/bin/su", "/data/adb/ksu/bin/su", "/data/adb/ap/bin/su"), calls)
    }

    @Test fun `launched timeout is preserved without retrying root authorization`() {
        var calls = 0
        val process = object : CompletedProcess(0, "") {
            override fun waitFor(timeout: Long, unit: TimeUnit) = false
        }
        val runner = RootProcessRunner { calls++; process }
        val error = assertThrows(RootModuleException::class.java) { runner.execute("id -u", timeoutMs = 1) }
        assertEquals("root_command_timeout", error.code)
        assertEquals(1, calls)
    }

    private open class CompletedProcess(private val code: Int, text: String) : Process() {
        private val stdout = ByteArrayInputStream(text.toByteArray())
        private val stderr = ByteArrayInputStream(byteArrayOf())
        private val stdin = ByteArrayOutputStream()
        override fun getInputStream() = stdout
        override fun getErrorStream() = stderr
        override fun getOutputStream() = stdin
        override fun waitFor() = code
        override fun waitFor(timeout: Long, unit: TimeUnit) = true
        override fun exitValue() = code
        override fun destroy() = Unit
    }
}
