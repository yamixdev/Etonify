package com.etonify.meow_client.singbox

import org.junit.Assert.*
import org.junit.Test

class StartupLatencyOwnershipTest {
    @Test fun `native dispatch fence does not survive a selection ABA`() {
        val gate = ready()
        val token = gate.claimNative()!!
        assertTrue(gate.dispatchNative(token))
        gate.update(7L, 3L, "other", true, true, 1L)
        gate.update(7L, 3L, "leaf", true, true, 2L)
        assertFalse(gate.dispatchNative(token))
        assertFalse(gate.complete(7L, 3L, "leaf", 10L, 2000L, "available", selection = 0L))
        assertNotNull(gate.claimNative())
    }
    private fun ready() = StartupLatencyOwnership().apply { update(7L, 3L, "leaf", true, true) }

    @Test fun `tile fallback waits for runtime network and authoritative selection`() {
        val gate = StartupLatencyOwnership()
        gate.update(0L, 3L, "leaf", false, true)
        assertNull(gate.claimNative())
        gate.update(7L, 3L, "", true, true)
        assertNull(gate.claimNative())
        gate.update(7L, 3L, "leaf", true, true)
        assertNotNull(gate.claimNative())
        assertNull(gate.claimNative())
    }

    @Test fun `a covering client claim prevents a parallel native measurement`() {
        val gate = ready()
        var borrowed: StartupLatencyOwnership.Measurement? = null
        val reservation = gate.prepareClient(7L, setOf("leaf", "other")) { borrowed = it }
        assertNotNull(reservation)
        assertNull(gate.claimNative())
        val request = gate.clientRequest(true)
        assertNotNull(request)
        assertFalse(gate.expireReservation(reservation!!))
        assertTrue(gate.complete(7L, 3L, "leaf", 42L, 1000L, "available"))
        assertNull(borrowed)
        assertNull(gate.claimNative())
    }

    @Test fun `native first lends its real result to a later client startup`() {
        val gate = ready()
        assertNotNull(gate.claimNative())
        var borrowed: StartupLatencyOwnership.Measurement? = null
        assertNull(gate.prepareClient(7L, setOf("leaf")) { borrowed = it })
        assertNull(borrowed)
        assertTrue(gate.complete(7L, 3L, "leaf", 26L, 2000L, "available"))
        assertEquals(26L, borrowed!!.delayMillis)
        assertEquals("leaf", borrowed!!.tag)
        assertEquals(2000L, borrowed!!.measuredAtMillis)
        var cached: StartupLatencyOwnership.Measurement? = null
        gate.prepareClient(7L, setOf("leaf", "other")) { cached = it }
        assertEquals(borrowed, cached)
        assertNull(gate.claimNative())
    }

    @Test fun `unrelated client group does not suppress the tile leaf`() {
        val gate = ready()
        assertNull(gate.prepareClient(7L, setOf("other")) {})
        assertNotNull(gate.claimNative())
    }

    @Test fun `abandoned reservation allows the native fallback`() {
        val gate = ready()
        val reservation = gate.prepareClient(7L, setOf("leaf")) {}!!
        assertTrue(gate.expireReservation(reservation))
        assertNotNull(gate.claimNative())
        assertFalse(gate.expireReservation(reservation))
    }

    @Test fun `failed client dispatch releases only its own claim`() {
        val gate = ready()
        gate.prepareClient(7L, setOf("leaf")) {}
        val request = gate.clientRequest(true)!!
        assertFalse(gate.clientFailed(request + 1))
        assertTrue(gate.clientFailed(request))
        assertNotNull(gate.claimNative())
    }

    @Test fun `restart selection and network invalidate borrowed work`() {
        for (context in listOf(Triple(8L, 3L, "leaf"), Triple(7L, 4L, "leaf"), Triple(7L, 3L, "other"))) {
            val gate = ready()
            gate.claimNative()
            var replies = 0
            var borrowed: StartupLatencyOwnership.Measurement? = null
            gate.prepareClient(7L, setOf("leaf")) { replies++; borrowed = it }
            gate.update(context.first, context.second, context.third, true, true)
            assertEquals(1, replies)
            assertNull(borrowed)
            assertFalse(gate.complete(7L, 3L, "leaf", 10L, 2000L, "available"))
            assertNotNull(gate.claimNative())
        }
    }

    @Test fun `client-only start never arms a native fallback`() {
        val gate = StartupLatencyOwnership()
        gate.update(7L, 3L, "leaf", true, false)
        assertNull(gate.claimNative())
    }

    @Test fun `losing network readiness cancels a borrower even before generation changes`() {
        val gate = ready()
        gate.claimNative()
        var replies = 0
        gate.prepareClient(7L, setOf("leaf")) { replies++ }
        gate.update(7L, 3L, "leaf", false, true)
        assertEquals(1, replies)
        gate.update(7L, 3L, "leaf", true, true)
        assertNotNull(gate.claimNative())
    }

    @Test fun `accepted client dispatch without a leaf result eventually releases ownership`() {
        val gate = ready()
        gate.prepareClient(7L, setOf("leaf", "other")) {}
        val token = gate.clientRequest(true)!!
        assertTrue(gate.expireClient(token))
        assertNotNull(gate.claimNative())
        assertFalse(gate.expireClient(token))
    }

    @Test fun `a completed client leaf is not retried when its old lease expires`() {
        val gate = ready()
        gate.prepareClient(7L, setOf("leaf")) {}
        val token = gate.clientRequest(true)!!
        gate.complete(7L, 3L, "leaf", 22L, 2000L, "available")
        assertFalse(gate.expireClient(token))
        assertNull(gate.claimNative())
    }

    @Test fun `a late client dispatch cannot use an expired reservation after native won`() {
        val gate = ready()
        val token = gate.prepareClient(7L, setOf("leaf")) {}!!
        gate.expireReservation(token)
        gate.claimNative()
        assertFalse(gate.dispatchClient(token))
    }

    @Test fun `dispatch fence converts only the current reservation into client work`() {
        val gate = ready()
        val token = gate.prepareClient(7L, setOf("leaf")) {}!!
        assertFalse(gate.dispatchClient(token - 1))
        assertTrue(gate.dispatchClient(token))
        assertFalse(gate.expireReservation(token))
        assertNull(gate.claimNative())
    }
}
