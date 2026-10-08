package com.etonify.meow_client.singbox

import org.junit.Assert.*
import org.junit.Test

class NativeUrlTestAttributionTest {
    @Test fun `long running runtimes bound identity retention`() {
        val attribution = NativeUrlTestAttribution()
        for (i in 1L..600L) {
            attribution.register("request-$i", 7L, 3L, 2L)
            attribution.running(i, "request-$i")
        }
        assertNull(attribution.result(1L, ""))
        assertEquals(NativeUrlTestAttribution.Context(7L, 3L, 2L), attribution.result(600L, ""))
    }
    @Test fun `a result before running retains its dispatch network rather than the current one`() {
        val attribution = NativeUrlTestAttribution()
        attribution.register("old", 7L, 3L)
        attribution.register("new", 7L, 4L)
        assertEquals(NativeUrlTestAttribution.Context(7L, 3L), attribution.result(5L, "old"))
        assertEquals(NativeUrlTestAttribution.Context(7L, 4L), attribution.result(6L, "new"))
        assertNull(attribution.result(7L, "unknown"))
    }

    @Test fun `unknown and cleared identities cannot borrow a current runtime attribution`() {
        val attribution = NativeUrlTestAttribution()
        attribution.register("old", 7L, 3L)
        attribution.running(5L, "old")
        assertEquals(NativeUrlTestAttribution.Context(7L, 3L), attribution.result(5L, ""))
        attribution.clear()
        assertNull(attribution.result(5L, "old"))
        assertNull(attribution.result(5L, ""))
    }
}
