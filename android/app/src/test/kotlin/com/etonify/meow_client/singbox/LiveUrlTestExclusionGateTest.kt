package com.etonify.meow_client.singbox

import org.junit.Assert.*
import org.junit.Test

class LiveUrlTestExclusionGateTest {
    @Test fun staleRequestNeverReadsOrMutatesReplacementRuntime() {
        val gate = LiveUrlTestExclusionGate()
        var touched = false
        try {
            gate.apply(1, listOf("a"), { 2 }, { touched = true; 100 }) { _, _ -> touched = true }
            fail("stale request accepted")
        } catch (_: IllegalStateException) { }
        assertFalse(touched)
    }

    @Test fun restartDuringStampCaptureNeverDispatchesPolicy() {
        val gate = LiveUrlTestExclusionGate()
        var generation = 1L
        var sent = false
        try {
            gate.apply(1, listOf("a"), { generation }, { generation = 2; 100 }) { _, _ -> sent = true }
            fail("replaced runtime accepted")
        } catch (_: IllegalStateException) { }
        assertFalse(sent)
    }

    @Test fun stampIsBoundToGenerationAndEmptyPolicyClearsExclusions() {
        val gate = LiveUrlTestExclusionGate()
        var reads = 0
        val requests = mutableListOf<Pair<List<String>, Long>>()
        gate.apply(1, listOf("a", "a"), { 1 }, { reads++; 100 }) { tags, stamp -> requests += tags to stamp }
        gate.apply(1, emptyList(), { 1 }, { reads++; 200 }) { tags, stamp -> requests += tags to stamp }
        gate.apply(2, listOf("b"), { 2 }, { reads++; 300 }) { tags, stamp -> requests += tags to stamp }
        assertEquals(2, reads)
        assertEquals(listOf(listOf("a") to 100L, emptyList<String>() to 100L, listOf("b") to 300L), requests)
    }
}
