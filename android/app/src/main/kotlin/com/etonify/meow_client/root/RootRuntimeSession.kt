package com.etonify.meow_client.root

/** Lifecycle fence; late authorization and ready events cannot undo a user's Stop. */
internal class RootRuntimeSession {
    data class Ticket(val generation: Long, val stopRevision: Long)
    private enum class Phase { IDLE, PREPARING, RUNNING, STOPPING, CLEANUP_BLOCKED }
    private var generation = 0L
    private var phase = Phase.IDLE

    val isRunning: Boolean @Synchronized get() = phase == Phase.RUNNING
    val isActive: Boolean @Synchronized get() = phase != Phase.IDLE
    val isPreparing: Boolean @Synchronized get() = phase == Phase.PREPARING

    @Synchronized fun beginStart(stopRevision: Long): Ticket? {
        if (phase != Phase.IDLE) return null
        phase = Phase.PREPARING
        return Ticket(++generation, stopRevision)
    }

    @Synchronized fun isCurrent(ticket: Ticket, stopRevision: Long): Boolean =
        ticket.generation == generation && ticket.stopRevision == stopRevision &&
            (phase == Phase.PREPARING || phase == Phase.RUNNING)

    @Synchronized fun markReady(ticket: Ticket, stopRevision: Long): Boolean {
        if (!isCurrent(ticket, stopRevision)) return false
        phase = Phase.RUNNING
        return true
    }

    @Synchronized fun beginStop(): Long? {
        if (phase == Phase.STOPPING) return null
        phase = Phase.STOPPING
        return ++generation
    }

    @Synchronized fun markStopUnconfirmed(stopGeneration: Long): Boolean {
        if (generation != stopGeneration || phase != Phase.STOPPING) return false
        phase = Phase.CLEANUP_BLOCKED
        return true
    }

    @Synchronized fun markStopped(stopGeneration: Long): Boolean {
        if (generation != stopGeneration || phase != Phase.STOPPING) return false
        phase = Phase.IDLE
        return true
    }
}
