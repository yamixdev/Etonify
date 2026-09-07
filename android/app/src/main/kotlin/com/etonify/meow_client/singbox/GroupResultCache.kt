package com.etonify.meow_client.singbox

/** One immutable result per concrete outbound, scoped to a command client. */
internal class GroupResultCache {
    private val values = HashMap<String, Map<String, Any?>>()

    fun result(
        tag: String, type: String?, delay: Long, time: Long,
        status: String?, error: String?, errorCode: String?,
    ): Map<String, Any?> {
        val previous = values[tag]
        if (previous != null && previous["type"] == type &&
            previous["delay"] == delay && previous["time"] == time &&
            previous["status"] == status && previous["error"] == error &&
            previous["errorCode"] == errorCode
        ) return previous
        return mapOf(
            "tag" to tag, "type" to type, "delay" to delay, "time" to time,
            "status" to status, "error" to error, "errorCode" to errorCode,
        ).also { values[tag] = it }
    }

    fun retain(tags: Set<String>) {
        values.keys.retainAll(tags)
    }
}
