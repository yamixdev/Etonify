package com.etonify.meow_client.singbox

import java.util.concurrent.Executors

/** A blocked control RPC must not prevent the status stream from disconnecting. */
internal class CommandExecutionLanes : AutoCloseable {
    val commands = Executors.newSingleThreadExecutor { task ->
        Thread(task, "MeowCommand").apply { isDaemon = true }
    }
    val stream = Executors.newSingleThreadExecutor { task ->
        Thread(task, "MeowCommandStream").apply { isDaemon = true }
    }

    override fun close() {
        commands.shutdown()
        stream.shutdown()
    }
}
