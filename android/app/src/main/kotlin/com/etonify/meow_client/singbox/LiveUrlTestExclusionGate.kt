package com.etonify.meow_client.singbox

/** Binds queued policy updates to one native runtime, not whichever daemon is newest. */
internal class LiveUrlTestExclusionGate {
    private var generation = 0L
    private var startedAt = 0L

    @Synchronized
    fun apply(
        requestedGeneration: Long,
        tags: List<String>,
        currentGeneration: () -> Long,
        readStartedAt: () -> Long,
        send: (List<String>, Long) -> Unit,
    ) {
        fun requireCurrent() = check(requestedGeneration > 0 && currentGeneration() == requestedGeneration) {
            "stale runtime for URL test exclusions"
        }
        requireCurrent()
        if (generation != requestedGeneration) {
            val stamp = readStartedAt()
            requireCurrent()
            check(stamp > 0) { "runtime start time unavailable" }
            generation = requestedGeneration
            startedAt = stamp
        }
        requireCurrent()
        send(tags.distinct(), startedAt)
        requireCurrent()
    }
}
