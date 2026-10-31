package com.etonify.meow_client.root

import org.junit.Assert.assertEquals
import org.junit.Test

class RootCapabilityProbeTest {
    @Test fun `su success with nonroot uid is not root authorization`() {
        assertEquals("denied", RootCapabilityProbe { RootCommandResult(0, "2000\n", "") }.requestAuthorization())
    }

    @Test fun `only exact zero uid confirms authorization`() {
        assertEquals("granted", RootCapabilityProbe { RootCommandResult(0, "0\n", "") }.requestAuthorization())
        assertEquals("denied", RootCapabilityProbe { RootCommandResult(0, "hello\n0\n", "") }.requestAuthorization())
        assertEquals("denied", RootCapabilityProbe { RootCommandResult(1, "0\n", "denied") }.requestAuthorization())
    }

    @Test fun `missing su is separate from refusal`() {
        assertEquals("noSu", RootCapabilityProbe { throw java.io.IOException("missing") }.requestAuthorization())
    }
}
