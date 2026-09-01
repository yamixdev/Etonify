package com.etonify.meow_client.singbox

import android.content.Context
import android.os.Process
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import kotlin.math.max

/**
 * An opt-in, bounded runtime probe for diagnosing VPN background behaviour.
 *
 * The probe samples twice per second only while explicitly running. It
 * reuses the status values already received from libbox and never changes the
 * active VPN configuration, network routing, or URLTest state.
 */
internal object RuntimeMeasurement {
    private const val SAMPLE_INTERVAL_MS = 500L
    private const val LOG_TAG = "MeowRuntimeProbe"

    private val lock = Any()
    private val executor = Executors.newSingleThreadScheduledExecutor { runnable ->
        Thread(runnable, "MeowRuntimeProbe").apply { isDaemon = true }
    }
    private var ticker: ScheduledFuture<*>? = null
    private var session: Session? = null

    fun start(context: Context, requestedDurationSeconds: Long): Map<String, Any?> = synchronized(lock) {
        session?.takeIf { it.state == State.RUNNING }?.let(::snapshotLocked)?.let { return it }

        stopTickerLocked()
        val nowElapsed = SystemClock.elapsedRealtime()
        val nowEpoch = System.currentTimeMillis()
        val durationSeconds = normalizeRuntimeMeasurementDurationSeconds(
            requestedDurationSeconds,
        )
        val created = Session(
            applicationContext = context.applicationContext,
            startedAtEpochMs = nowEpoch,
            startedAtElapsedMs = nowElapsed,
            durationSeconds = durationSeconds,
        )
        session = created
        sampleLocked(created)
        ticker = executor.scheduleWithFixedDelay(
            {
                synchronized(lock) {
                    val active = session ?: return@synchronized
                    if (active.state != State.RUNNING) return@synchronized
                    sampleLocked(active)
                    if (elapsedSeconds(active) >= active.durationSeconds) {
                        completeLocked(active, State.COMPLETED)
                    }
                }
            },
            SAMPLE_INTERVAL_MS,
            SAMPLE_INTERVAL_MS,
            TimeUnit.MILLISECONDS,
        )
        snapshotLocked(created)
    }

    fun stop(): Map<String, Any?> = synchronized(lock) {
        val active = session ?: return emptySnapshot()
        if (active.state == State.RUNNING) {
            sampleLocked(active)
            completeLocked(active, State.STOPPED)
        }
        snapshotLocked(active)
    }

    fun snapshot(): Map<String, Any?> = synchronized(lock) {
        val active = session ?: return emptySnapshot()
        if (active.state == State.RUNNING && elapsedSeconds(active) >= active.durationSeconds) {
            sampleLocked(active)
            completeLocked(active, State.COMPLETED)
        }
        snapshotLocked(active)
    }

    fun report(): String = synchronized(lock) {
        val active = session ?: return "Etonify runtime measurement\nstate: idle\n"
        buildReport(active)
    }

    private fun sampleLocked(active: Session) {
        val nowElapsed = SystemClock.elapsedRealtime()
        val cpuMs = Process.getElapsedCpuTime()
        val previous = active.samples.lastOrNull()
        val cpuPercent = previous?.let {
            val elapsedDelta = nowElapsed - it.elapsedRealtimeMs
            val cpuDelta = cpuMs - it.processCpuMs
            if (elapsedDelta > 0L && cpuDelta >= 0L) {
                cpuDelta.toDouble() * 100.0 / elapsedDelta.toDouble()
            } else {
                null
            }
        }
        val processMemory = OwnProcessMemory.capture()
        active.samples += RuntimeMeasurementSample(
            elapsedRealtimeMs = nowElapsed,
            elapsedSeconds = elapsedSeconds(active, nowElapsed),
            processCpuMs = cpuMs,
            cpuPercent = cpuPercent,
            totalPssKb = processMemory.totalPssKb,
            nativeHeapKb = processMemory.nativeHeapAllocatedKb,
            coreMemoryBytes = SingboxController.coreMemoryBytes,
            coreGoroutines = SingboxController.coreGoroutines,
            connectionsIn = SingboxController.connectionsIn,
            connectionsOut = SingboxController.connectionsOut,
            trafficBytesPerSecond = max(0L, SingboxController.uplink) +
                max(0L, SingboxController.downlink),
            totalRssKb = processMemory.totalRssKb,
            totalSwapPssKb = processMemory.totalSwapPssKb,
            totalPrivateDirtyKb = processMemory.totalPrivateDirtyKb,
            dalvikPssKb = processMemory.dalvikPssKb,
            nativePssKb = processMemory.nativePssKb,
            graphicsPssKb = processMemory.graphicsPssKb,
            codePssKb = processMemory.codePssKb,
        )
    }

    private fun completeLocked(active: Session, finalState: State) {
        active.state = finalState
        active.finishedAtEpochMs = System.currentTimeMillis()
        stopTickerLocked()
        persistReportLocked(active)
    }

    private fun stopTickerLocked() {
        ticker?.cancel(false)
        ticker = null
    }

    private fun snapshotLocked(active: Session): Map<String, Any?> {
        val samples = active.samples
        val cpuValues = samples.mapNotNull { it.cpuPercent }
        val pssValues = samples.map { it.totalPssKb }.filter { it > 0L }
        val rssValues = samples.mapNotNull { it.totalRssKb }.filter { it > 0L }
        val swapPssValues = samples.mapNotNull { it.totalSwapPssKb }
        val privateDirtyValues = samples.mapNotNull { it.totalPrivateDirtyKb }
        val goroutineValues = samples.map { it.coreGoroutines }
        val connectionValues = samples.map { it.connectionsIn + it.connectionsOut }
        val trafficValues = samples.map { it.trafficBytesPerSecond }
        val assessment = assessRuntimeMeasurement(samples)
        return linkedMapOf(
            "state" to active.state.wireName,
            "durationSeconds" to active.durationSeconds,
            "sampleIntervalMillis" to SAMPLE_INTERVAL_MS,
            "elapsedSeconds" to elapsedSeconds(active),
            "startedAtMillis" to active.startedAtEpochMs,
            "finishedAtMillis" to active.finishedAtEpochMs,
            "sampleCount" to samples.size,
            "cpuAveragePercent" to cpuValues.averageOrNull(),
            "cpuPeakPercent" to cpuValues.maxOrNull(),
            "trafficAverageBytesPerSecond" to trafficValues.averageOrNull(),
            "trafficPeakBytesPerSecond" to trafficValues.maxOrNull(),
            "pssStartKb" to pssValues.firstOrNull(),
            "pssEndKb" to pssValues.lastOrNull(),
            "pssPeakKb" to pssValues.maxOrNull(),
            "rssPeakKb" to rssValues.maxOrNull(),
            "swapPssPeakKb" to swapPssValues.maxOrNull(),
            "privateDirtyPeakKb" to privateDirtyValues.maxOrNull(),
            "coreGoroutinesStart" to goroutineValues.firstOrNull(),
            "coreGoroutinesEnd" to goroutineValues.lastOrNull(),
            "coreGoroutinesPeak" to goroutineValues.maxOrNull(),
            "connectionsPeak" to connectionValues.maxOrNull(),
            "assessmentCode" to assessment.code,
            "assessmentDetail" to assessment.detail,
            "reportAvailable" to (active.state != State.RUNNING && samples.isNotEmpty()),
            "reportPersisted" to (
                active.state != State.RUNNING &&
                    samples.isNotEmpty() &&
                    active.reportPersistenceError == null
                ),
            "reportPersistenceError" to active.reportPersistenceError,
        )
    }

    private fun emptySnapshot(): Map<String, Any?> = linkedMapOf(
        "state" to State.IDLE.wireName,
        "durationSeconds" to RUNTIME_MEASUREMENT_MIN_DURATION_SECONDS,
        "elapsedSeconds" to 0L,
        "sampleCount" to 0,
        "assessmentCode" to "idle",
        "assessmentDetail" to "No measurement has been started.",
        "reportAvailable" to false,
        "reportPersisted" to false,
        "reportPersistenceError" to null,
    )

    private fun buildReport(active: Session): String {
        val snapshot = snapshotLocked(active)
        return buildString {
            appendLine("Etonify runtime measurement")
            appendLine("state: ${snapshot["state"]}")
            appendLine("started_at_ms: ${active.startedAtEpochMs}")
            appendLine("duration_seconds: ${snapshot["durationSeconds"]}")
            appendLine("elapsed_seconds: ${snapshot["elapsedSeconds"]}")
            appendLine("sample_interval_ms: $SAMPLE_INTERVAL_MS")
            appendLine("samples: ${snapshot["sampleCount"]}")
            appendLine("cpu_average_percent: ${formatNumber(snapshot["cpuAveragePercent"])}")
            appendLine("cpu_peak_percent: ${formatNumber(snapshot["cpuPeakPercent"])}")
            appendLine("traffic_average_bytes_per_second: ${formatNumber(snapshot["trafficAverageBytesPerSecond"])}")
            appendLine("traffic_peak_bytes_per_second: ${formatNumber(snapshot["trafficPeakBytesPerSecond"])}")
            appendLine("pss_start_kb: ${snapshot["pssStartKb"] ?: "n/a"}")
            appendLine("pss_end_kb: ${snapshot["pssEndKb"] ?: "n/a"}")
            appendLine("pss_peak_kb: ${snapshot["pssPeakKb"] ?: "n/a"}")
            appendLine("rss_peak_kb: ${snapshot["rssPeakKb"] ?: "n/a"}")
            appendLine("swap_pss_peak_kb: ${snapshot["swapPssPeakKb"] ?: "n/a"}")
            appendLine("private_dirty_peak_kb: ${snapshot["privateDirtyPeakKb"] ?: "n/a"}")
            appendLine("core_goroutines_start: ${snapshot["coreGoroutinesStart"] ?: "n/a"}")
            appendLine("core_goroutines_end: ${snapshot["coreGoroutinesEnd"] ?: "n/a"}")
            appendLine("core_goroutines_peak: ${snapshot["coreGoroutinesPeak"] ?: "n/a"}")
            appendLine("connections_peak: ${snapshot["connectionsPeak"] ?: "n/a"}")
            appendLine("assessment: ${snapshot["assessmentCode"]}")
            appendLine("assessment_detail: ${snapshot["assessmentDetail"]}")
            appendLine()
            appendLine("samples:")
            appendLine(
                "elapsed_ms,elapsed_s,cpu_percent,pss_kb,rss_kb,swap_pss_kb,private_dirty_kb," +
                    "dalvik_pss_kb,native_pss_kb,graphics_pss_kb,code_pss_kb," +
                    "native_heap_kb,process_rss_reported_by_core_bytes,goroutines,connections_in," +
                    "connections_out,traffic_bps",
            )
            active.samples.forEach { sample ->
                appendLine(
                    listOf(
                        sample.elapsedRealtimeMs - active.startedAtElapsedMs,
                        sample.elapsedSeconds,
                        formatNumber(sample.cpuPercent),
                        sample.totalPssKb,
                        sample.totalRssKb ?: "n/a",
                        sample.totalSwapPssKb ?: "n/a",
                        sample.totalPrivateDirtyKb ?: "n/a",
                        sample.dalvikPssKb ?: "n/a",
                        sample.nativePssKb ?: "n/a",
                        sample.graphicsPssKb ?: "n/a",
                        sample.codePssKb ?: "n/a",
                        sample.nativeHeapKb,
                        sample.coreMemoryBytes,
                        sample.coreGoroutines,
                        sample.connectionsIn,
                        sample.connectionsOut,
                        sample.trafficBytesPerSecond,
                    ).joinToString(","),
                )
            }
        }
    }

    private fun persistReportLocked(active: Session) {
        val failure = runCatching {
            val directory = File(active.applicationContext.filesDir, "diagnostics/runtime-measurements")
            check(directory.exists() || directory.mkdirs()) {
                "Unable to create ${directory.absolutePath}"
            }
            File(directory, "latest.txt").writeText(buildReport(active), Charsets.UTF_8)
        }.exceptionOrNull()
        active.reportPersistenceError = failure?.let { error ->
            "${error.javaClass.simpleName}: ${error.message ?: "unknown error"}"
        }
        if (failure != null) {
            Log.w(LOG_TAG, "Unable to persist runtime measurement report", failure)
        }
    }

    private fun elapsedSeconds(active: Session, nowElapsedMs: Long = SystemClock.elapsedRealtime()): Long =
        ((nowElapsedMs - active.startedAtElapsedMs).coerceAtLeast(0L)) / 1_000L

    private fun Iterable<Number>.averageOrNull(): Double? {
        val values = toList()
        return if (values.isEmpty()) null else values.map(Number::toDouble).average()
    }

    private fun formatNumber(value: Any?): String = when (value) {
        is Double -> String.format(Locale.US, "%.2f", value)
        null -> "n/a"
        else -> value.toString()
    }

    private data class Session(
        val applicationContext: Context,
        val startedAtEpochMs: Long,
        val startedAtElapsedMs: Long,
        val durationSeconds: Long,
        val samples: MutableList<RuntimeMeasurementSample> = mutableListOf(),
        var state: State = State.RUNNING,
        var finishedAtEpochMs: Long? = null,
        var reportPersistenceError: String? = null,
    )

    private enum class State(val wireName: String) {
        IDLE("idle"),
        RUNNING("running"),
        COMPLETED("completed"),
        STOPPED("stopped"),
    }
}
