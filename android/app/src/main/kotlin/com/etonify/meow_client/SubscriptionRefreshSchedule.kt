package com.etonify.meow_client

import org.json.JSONObject

internal object SubscriptionRefreshSchedule {
    fun retainPendingSuccess(result: JSONObject, previous: JSONObject?) {
        if (!result.has("failure") || previous?.optString("token") != result.getString("token")) return
        val success = if (previous.has("body")) previous else previous.optJSONObject("pendingSuccess")
        if (success != null) result.put("pendingSuccess", success)
    }

    fun isDue(plan: JSONObject, previous: JSONObject?, now: Long): Boolean {
        if (now < plan.getLong("dueAt")) return false
        if (previous == null || previous.optString("token") != plan.getString("token")) return true
        val delay = if (previous.has("failure")) {
            when (previous.optInt("failures", 1)) {
                1 -> 15L
                2 -> 60L
                3 -> 180L
                else -> 360L
            } * 60_000L
        } else {
            plan.optLong("intervalMillis", 3_600_000L).coerceAtLeast(900_000L)
        }
        return now >= previous.optLong("time") + delay
    }
}
