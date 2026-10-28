package com.etonify.meow_client

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class SubscriptionRefreshScheduleTest {
    private val plan = JSONObject().put("token", "a").put("dueAt", 100L)
        .put("intervalMillis", 3_600_000L)

    @Test fun `successful download is checked again without opening app`() {
        val previous = JSONObject().put("token", "a").put("time", 100L)
        assertFalse(SubscriptionRefreshSchedule.isDue(plan, previous, 3_600_099L))
        assertTrue(SubscriptionRefreshSchedule.isDue(plan, previous, 3_600_100L))
    }

    @Test fun `failed download retries with bounded backoff`() {
        val previous = JSONObject().put("token", "a").put("time", 100L)
            .put("failure", "timeout").put("failures", 1)
        assertFalse(SubscriptionRefreshSchedule.isDue(plan, previous, 900_099L))
        assertTrue(SubscriptionRefreshSchedule.isDue(plan, previous, 900_100L))
        previous.put("failures", 20)
        assertTrue(SubscriptionRefreshSchedule.isDue(plan, previous, 21_600_100L))
    }

    @Test fun `changed source ignores previous attempt but respects new due time`() {
        val previous = JSONObject().put("token", "old").put("time", Long.MAX_VALUE)
        assertFalse(SubscriptionRefreshSchedule.isDue(plan, previous, 99L))
        assertTrue(SubscriptionRefreshSchedule.isDue(plan, previous, 100L))
    }

    @Test fun `failed refresh keeps unapplied success without nesting history`() {
        val success = JSONObject().put("token", "a").put("time", 100L).put("body", "valid")
        val failure = JSONObject().put("token", "a").put("time", 200L).put("failure", "dns")
        SubscriptionRefreshSchedule.retainPendingSuccess(failure, success)
        assertEquals("valid", failure.getJSONObject("pendingSuccess").getString("body"))
        val next = JSONObject().put("token", "a").put("time", 300L).put("failure", "dns")
        SubscriptionRefreshSchedule.retainPendingSuccess(next, failure)
        assertEquals(100L, next.getJSONObject("pendingSuccess").getLong("time"))
        assertFalse(next.getJSONObject("pendingSuccess").has("pendingSuccess"))
        val changed = JSONObject().put("token", "b").put("failure", "dns")
        SubscriptionRefreshSchedule.retainPendingSuccess(changed, success)
        assertFalse(changed.has("pendingSuccess"))
    }
}
