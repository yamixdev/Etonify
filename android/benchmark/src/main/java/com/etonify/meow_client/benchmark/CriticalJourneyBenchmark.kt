package com.etonify.meow_client.benchmark

import androidx.benchmark.macro.CompilationMode
import androidx.benchmark.macro.FrameTimingMetric
import androidx.benchmark.macro.StartupMode
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@LargeTest
class CriticalJourneyBenchmark {
    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    @Test
    fun homeSettingsAndProxyList() {
        benchmarkRule.measureRepeated(
            packageName = TARGET_PACKAGE,
            metrics = listOf(FrameTimingMetric()),
            compilationMode = CompilationMode.Partial(),
            startupMode = StartupMode.WARM,
            iterations = 5,
            setupBlock = { pressHome() },
            measureBlock = {
                prepareMainScreen()
                openSettingsAndReturn()
                openAndScrollProxyList()
            },
        )
    }

    @Test
    fun repeatedProxyPanelOpenCloseAndScroll() {
        benchmarkRule.measureRepeated(
            packageName = TARGET_PACKAGE,
            metrics = listOf(FrameTimingMetric()),
            compilationMode = CompilationMode.Partial(),
            startupMode = StartupMode.WARM,
            iterations = 3,
            setupBlock = { pressHome() },
            measureBlock = {
                prepareMainScreen()
                // Run once at 60 Hz and once at 120 Hz. FrameTimingMetric
                // records the actual frame cost for each device configuration.
                exerciseProxyPanel(repetitions = 20)
            },
        )
    }
}
