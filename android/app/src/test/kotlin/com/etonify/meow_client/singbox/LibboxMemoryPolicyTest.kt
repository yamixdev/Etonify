package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class LibboxMemoryPolicyTest {
    @Test
    fun `enabled policy limits Go without enabling process OOM killer`() {
        val policy = LibboxMemoryPolicy.forAndroid(
            softLimitEnabled = true,
            memoryClassMegabytes = 512,
        )

        assertEquals(256L * 1024L * 1024L, policy.goMemoryLimitBytes)
        assertFalse(policy.processOomKillerEnabled)
        assertEquals(0L, policy.processOomMemoryLimitBytes)
    }

    @Test
    fun `disabled policy removes all application memory limits`() {
        val policy = LibboxMemoryPolicy.forAndroid(
            softLimitEnabled = false,
            memoryClassMegabytes = 512,
        )

        assertEquals(0L, policy.goMemoryLimitBytes)
        assertFalse(policy.processOomKillerEnabled)
        assertEquals(0L, policy.processOomMemoryLimitBytes)
    }

    @Test
    fun `enabled policy stays inside safe adaptive bounds`() {
        val lowMemoryClass = LibboxMemoryPolicy.forAndroid(
            softLimitEnabled = true,
            memoryClassMegabytes = 128,
        )
        val highMemoryClass = LibboxMemoryPolicy.forAndroid(
            softLimitEnabled = true,
            memoryClassMegabytes = 2048,
        )

        assertEquals(256L * 1024L * 1024L, lowMemoryClass.goMemoryLimitBytes)
        assertEquals(512L * 1024L * 1024L, highMemoryClass.goMemoryLimitBytes)
    }
}
