package com.etonify.meow_client.singbox

/** Results can precede running events; attribution must originate at dispatch. */
internal class NativeUrlTestAttribution {
    data class Context(val runtime: Long, val network: Long, val selection: Long = 0L)
    private val requests = LinkedHashMap<String, Context>()
    private val sessions = LinkedHashMap<Long, Context>()
    @Synchronized fun register(id: String, runtime: Long, network: Long, selection: Long = 0L) {
        requests[id] = Context(runtime, network, selection)
        while (requests.size > 512) requests.remove(requests.keys.first())
    }
    @Synchronized fun running(session: Long, id: String): Context? = requests[id]?.also {
        sessions[session] = it
        while (sessions.size > 512) sessions.remove(sessions.keys.first())
    }
    @Synchronized fun result(session: Long, id: String): Context? = requests[id] ?: sessions[session]
    @Synchronized fun clear() { requests.clear(); sessions.clear() }
}

internal data class NativeLatencyResult(
    val runtime: Long, val network: Long, val tag: String, val delay: Long,
    val measuredAtMillis: Long, val status: String, val revision: Long,
    val sessionId: Long, val error: String,
    val selection: Long = 0L,
)
