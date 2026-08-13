package com.etonify.meow_client.singbox

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationActionPolicyTest {
    @Test
    fun `stop action reaches an active runtime without starting a service`() {
        assertEquals(
            NotificationActionDecision.STOP_ACTIVE_RUNTIME,
            notificationActionDecision(
                MeowNotificationActionReceiver.ACTION_STOP_RUNTIME,
                hasActiveRuntimeOwner = true,
            ),
        )
    }

    @Test
    fun `actions from a stale notification only clear local state`() {
        assertEquals(
            NotificationActionDecision.CLEAR_STALE_NOTIFICATION,
            notificationActionDecision(
                MeowNotificationActionReceiver.ACTION_STOP_RUNTIME,
                hasActiveRuntimeOwner = false,
            ),
        )
        assertEquals(
            NotificationActionDecision.IGNORE_STALE_ACTION,
            notificationActionDecision(
                MeowNotificationActionReceiver.ACTION_REFRESH_LATENCY,
                hasActiveRuntimeOwner = false,
            ),
        )
    }
}
