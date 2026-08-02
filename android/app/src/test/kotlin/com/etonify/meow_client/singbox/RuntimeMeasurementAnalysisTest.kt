package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Test

class RuntimeMeasurementAnalysisTest {
    @Test
    fun `duration is clamped to safe bounds`() {
        assertEquals(15L, normalizeRuntimeMeasurementDurationSeconds(0L))
        assertEquals(120L, normalizeRuntimeMeasurementDurationSeconds(120L))
        assertEquals(3_600L, normalizeRuntimeMeasurementDurationSeconds(Long.MAX_VALUE))
    }

    @Test
    fun `one sample keeps assessment in collecting state`() {
        assertEquals("collecting", assessRuntimeMeasurement(listOf(sample())).code)
    }

    @Test
    fun `high cpu with low traffic is reported first`() {
        val result = assessRuntimeMeasurement(
            listOf(sample(cpuPercent = 45.0), sample(cpuPercent = 55.0)),
        )

        assertEquals("high_cpu_low_traffic", result.code)
    }

    @Test
    fun `goroutine growth is detected`() {
        val result = assessRuntimeMeasurement(
            listOf(sample(goroutines = 10), sample(goroutines = 34)),
        )

        assertEquals("goroutine_growth", result.code)
    }

    @Test
    fun `memory growth is detected`() {
        val result = assessRuntimeMeasurement(
            listOf(sample(pssKb = 100_000), sample(pssKb = 124_576)),
        )

        assertEquals("memory_growth", result.code)
    }

    @Test
    fun `connection churn is detected when traffic stays low`() {
        val result = assessRuntimeMeasurement(
            listOf(sample(connectionsIn = 16, connectionsOut = 16), sample()),
        )

        assertEquals("connection_churn", result.code)
    }

    @Test
    fun `normal transfer load remains healthy`() {
        val result = assessRuntimeMeasurement(
            listOf(
                sample(cpuPercent = 45.0, trafficBytesPerSecond = 512 * 1024),
                sample(cpuPercent = 45.0, trafficBytesPerSecond = 512 * 1024),
            ),
        )

        assertEquals("healthy", result.code)
    }

    private fun sample(
        cpuPercent: Double? = 5.0,
        pssKb: Long = 100_000,
        goroutines: Int = 10,
        connectionsIn: Int = 1,
        connectionsOut: Int = 1,
        trafficBytesPerSecond: Long = 0,
    ) = RuntimeMeasurementSample(
        elapsedRealtimeMs = 0,
        elapsedSeconds = 0,
        processCpuMs = 0,
        cpuPercent = cpuPercent,
        totalPssKb = pssKb,
        nativeHeapKb = 0,
        coreMemoryBytes = 0,
        coreGoroutines = goroutines,
        connectionsIn = connectionsIn,
        connectionsOut = connectionsOut,
        trafficBytesPerSecond = trafficBytesPerSecond,
    )
}
