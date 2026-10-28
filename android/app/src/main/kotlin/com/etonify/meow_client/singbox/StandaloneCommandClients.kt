package com.etonify.meow_client.singbox

import java.util.Collections
import java.util.IdentityHashMap

/** Control calls stay on their existing serial executor; lookups own independent clients.
 * The lock protects ownership only, never a network RPC or disconnect.
 */
internal class StandaloneCommandClients<C : Any>(
    private val create: () -> C,
    private val disconnect: (C) -> Unit,
) {
    private val lock = Any()
    private var commandClient: C? = null
    private val lookups = Collections.newSetFromMap(IdentityHashMap<C, Boolean>())

    fun <T> control(block: (C) -> T): T {
        val client = synchronized(lock) {
            commandClient ?: create().also { commandClient = it }
        }
        return try {
            block(client)
        } catch (error: Throwable) {
            val owned = synchronized(lock) {
                if (commandClient === client) {
                    commandClient = null
                    true
                } else false
            }
            if (owned) close(client)
            throw error
        }
    }

    fun <T> lookup(block: (C) -> T): T {
        val client = synchronized(lock) { create().also { lookups.add(it) } }
        return try {
            block(client)
        } finally {
            val owned = synchronized(lock) { lookups.remove(client) }
            if (owned) close(client)
        }
    }

    fun clear() {
        val retired = synchronized(lock) {
            buildList {
                commandClient?.let { add(it) }
                addAll(lookups)
            }.also {
                commandClient = null
                lookups.clear()
            }
        }
        retired.forEach(::close)
    }

    private fun close(client: C) { runCatching { disconnect(client) } }
}
