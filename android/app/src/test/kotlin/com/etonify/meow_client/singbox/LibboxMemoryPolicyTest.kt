package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class LibboxMemoryPolicyTest {
    @Test
    fun `enabled policy limits Go without enabling process OOM killer`() {
        val policy = LibboxMemoryPolicy.forAndroid(softLimitEnabled = true)

        assertEquals(30L * 1024L * 1024L, policy.goMemoryLimitBytes)
        assertFalse(policy.processOomKillerEnabled)
        assertEquals(0L, policy.processOomMemoryLimitBytes)
    }

    @Test
    fun `disabled policy removes all application memory limits`() {
        val policy = LibboxMemoryPolicy.forAndroid(softLimitEnabled = false)

        assertEquals(0L, policy.goMemoryLimitBytes)
        assertFalse(policy.processOomKillerEnabled)
        assertEquals(0L, policy.processOomMemoryLimitBytes)
    }
}
