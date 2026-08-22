package com.etonify.meow_client.singbox

internal const val RUNTIME_MEASUREMENT_MIN_DURATION_SECONDS = 15L
internal const val RUNTIME_MEASUREMENT_MAX_DURATION_SECONDS = 3_600L

private const val LOW_TRAFFIC_BYTES_PER_SECOND = 128L * 1024L
private const val HIGH_CPU_PERCENT = 40.0
private const val MEMORY_GROWTH_KB = 24L * 1024L
private const val GOROUTINE_GROWTH = 24

internal fun normalizeRuntimeMeasurementDurationSeconds(requested: Long): Long =
    requested.coerceIn(
        RUNTIME_MEASUREMENT_MIN_DURATION_SECONDS,
        RUNTIME_MEASUREMENT_MAX_DURATION_SECONDS,
    )

internal data class RuntimeMeasurementSample(
    val elapsedRealtimeMs: Long,
    val elapsedSeconds: Long,
    val processCpuMs: Long,
    val cpuPercent: Double?,
    val totalPssKb: Long,
    val nativeHeapKb: Long,
    val coreMemoryBytes: Long,
    val coreGoroutines: Int,
    val connectionsIn: Int,
    val connectionsOut: Int,
    val trafficBytesPerSecond: Long,
    val totalRssKb: Long? = null,
    val totalSwapPssKb: Long? = null,
    val totalPrivateDirtyKb: Long? = null,
    val dalvikPssKb: Long? = null,
    val nativePssKb: Long? = null,
    val graphicsPssKb: Long? = null,
    val codePssKb: Long? = null,
)

internal data class RuntimeMeasurementAssessment(
    val code: String,
    val detail: String,
)

internal fun assessRuntimeMeasurement(
    samples: List<RuntimeMeasurementSample>,
): RuntimeMeasurementAssessment {
    if (samples.size < 2) {
        return RuntimeMeasurementAssessment(
            code = "collecting",
            detail = "More samples are needed before an assessment is available.",
        )
    }
    val averageCpu = samples.mapNotNull { it.cpuPercent }.averageOrNull() ?: 0.0
    val averageTraffic = samples.map { it.trafficBytesPerSecond }.averageOrNull() ?: 0.0
    val pssStart = samples.firstOrNull { it.totalPssKb > 0L }?.totalPssKb ?: 0L
    val pssEnd = samples.lastOrNull { it.totalPssKb > 0L }?.totalPssKb ?: pssStart
    val goroutinesStart = samples.first().coreGoroutines
    val goroutinesEnd = samples.last().coreGoroutines
    val peakConnections = samples.maxOfOrNull { it.connectionsIn + it.connectionsOut } ?: 0

    if (averageCpu >= HIGH_CPU_PERCENT && averageTraffic < LOW_TRAFFIC_BYTES_PER_SECOND) {
        return RuntimeMeasurementAssessment(
            code = "high_cpu_low_traffic",
            detail = "High process CPU was observed while routed traffic stayed low. This points to background native/core work, not normal transfer load.",
        )
    }
    if (goroutinesEnd >= goroutinesStart + GOROUTINE_GROWTH) {
        return RuntimeMeasurementAssessment(
            code = "goroutine_growth",
            detail = "The number of core goroutines increased during the run. A longer run and native profile are needed to identify the owner.",
        )
    }
    if (pssEnd >= pssStart + MEMORY_GROWTH_KB) {
        return RuntimeMeasurementAssessment(
            code = "memory_growth",
            detail = "Process PSS grew by more than 24 MB during the run. This can be cache growth or retained work; repeat for 15 minutes to confirm.",
        )
    }
    if (peakConnections >= 32 && averageTraffic < LOW_TRAFFIC_BYTES_PER_SECOND) {
        return RuntimeMeasurementAssessment(
            code = "connection_churn",
            detail = "Many core connections were present while traffic was low. The report can help investigate connection churn.",
        )
    }
    return RuntimeMeasurementAssessment(
        code = "healthy",
        detail = "No abnormal CPU, memory, goroutine, or connection growth was detected in this interval.",
    )
}

private fun Iterable<Number>.averageOrNull(): Double? {
    val values = toList()
    return if (values.isEmpty()) null else values.map(Number::toDouble).average()
}
