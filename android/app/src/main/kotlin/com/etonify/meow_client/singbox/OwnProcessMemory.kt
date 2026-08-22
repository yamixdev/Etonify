package com.etonify.meow_client.singbox

import android.os.Debug
import java.io.File

internal data class OwnProcessMemorySnapshot(
    val totalPssKb: Long,
    val totalRssKb: Long?,
    val totalSwapPssKb: Long,
    val totalSwapKb: Long?,
    val totalPrivateDirtyKb: Long,
    val dalvikPssKb: Long,
    val nativePssKb: Long,
    val otherPssKb: Long,
    val graphicsPssKb: Long?,
    val codePssKb: Long?,
    val stackPssKb: Long?,
    val privateOtherPssKb: Long?,
    val systemPssKb: Long?,
    val nativeHeapAllocatedKb: Long,
    val nativeHeapSizeKb: Long,
)

internal object OwnProcessMemory {
    private val procStatusFile = File("/proc/self/status")

    fun capture(): OwnProcessMemorySnapshot {
        val memoryInfo = Debug.MemoryInfo()
        Debug.getMemoryInfo(memoryInfo)
        val procStatus = runCatching {
            parseProcStatus(procStatusFile.readLines())
        }.getOrDefault(emptyMap())

        fun memoryStatKb(name: String): Long? {
            return memoryInfo.getMemoryStat(name)?.toLongOrNull()
        }

        return OwnProcessMemorySnapshot(
            totalPssKb = memoryInfo.totalPss.toLong(),
            totalRssKb = procStatus["VmRSS"],
            totalSwapPssKb = memoryStatKb("summary.total-swap")
                ?: memoryInfo.totalSwappablePss.toLong(),
            totalSwapKb = procStatus["VmSwap"],
            totalPrivateDirtyKb = memoryInfo.totalPrivateDirty.toLong(),
            dalvikPssKb = memoryInfo.dalvikPss.toLong(),
            nativePssKb = memoryInfo.nativePss.toLong(),
            otherPssKb = memoryInfo.otherPss.toLong(),
            graphicsPssKb = memoryStatKb("summary.graphics"),
            codePssKb = memoryStatKb("summary.code"),
            stackPssKb = memoryStatKb("summary.stack"),
            privateOtherPssKb = memoryStatKb("summary.private-other"),
            systemPssKb = memoryStatKb("summary.system"),
            nativeHeapAllocatedKb = Debug.getNativeHeapAllocatedSize() / 1024L,
            nativeHeapSizeKb = Debug.getNativeHeapSize() / 1024L,
        )
    }

    internal fun parseProcStatus(lines: Iterable<String>): Map<String, Long> {
        val wanted = setOf("VmRSS", "VmSwap")
        return buildMap {
            for (line in lines) {
                val separator = line.indexOf(':')
                if (separator <= 0) continue
                val key = line.substring(0, separator)
                if (key !in wanted) continue
                val valueKb = line
                    .substring(separator + 1)
                    .trim()
                    .substringBefore(' ')
                    .toLongOrNull()
                    ?: continue
                put(key, valueKb)
            }
        }
    }
}
