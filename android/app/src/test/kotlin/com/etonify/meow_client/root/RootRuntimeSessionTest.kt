package com.etonify.meow_client.root

import org.junit.Assert.*
import org.junit.Test

class RootRuntimeSessionTest {
    @Test fun unconfirmedStopRetainsOwnershipButAllowsAnExplicitCleanupRetry() {
        val session = RootRuntimeSession()
        session.beginStart(1)
        val stop = session.beginStop()!!
        assertTrue(session.markStopUnconfirmed(stop))
        assertTrue(session.isActive)
        assertNull(session.beginStart(1))
        val retry = session.beginStop()!!
        assertTrue(session.markStopped(retry))
        assertFalse(session.isActive)
    }
    @Test fun repeatedStopKeepsTheAlreadyQueuedCleanupAuthoritative() {
        val session = RootRuntimeSession()
        session.beginStart(4)
        val cleanup = session.beginStop()!!
        assertNull(session.beginStop())
        assertTrue(session.markStopped(cleanup))
        assertFalse(session.isActive)
        assertNotNull(session.beginStart(5))
    }
    @Test fun duplicateStartDoesNotCreateAnotherOwner() {
        val session = RootRuntimeSession()
        val ticket = session.beginStart(4)!!
        assertNull(session.beginStart(4))
        assertTrue(session.markReady(ticket, 4))
        assertNull(session.beginStart(4))
    }

    @Test fun stopDuringAuthorizationRejectsLateReady() {
        val session = RootRuntimeSession()
        val old = session.beginStart(4)!!
        val stop = session.beginStop()!!
        assertFalse(session.markReady(old, 4))
        assertTrue(session.markStopped(stop))
        val next = session.beginStart(5)!!
        assertFalse(session.markStopped(stop))
        assertTrue(session.markReady(next, 5))
    }

    @Test fun notificationStopRevisionPreventsStartupCompletion() {
        val session = RootRuntimeSession()
        val ticket = session.beginStart(4)!!
        assertFalse(session.markReady(ticket, 5))
        assertFalse(session.isRunning)
    }
}
