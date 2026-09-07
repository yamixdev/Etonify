package com.etonify.meow_client.singbox

import org.junit.Assert.*
import org.junit.Test

class GroupResultCacheTest {
    @Test
    fun `unchanged history reuses payload and fresh timestamp replaces it`() {
        val cache = GroupResultCache()
        val first = cache.result("a", "vless", 50, 100, null, null, null)
        assertSame(first, cache.result("a", "vless", 50, 100, null, null, null))
        val fresh = cache.result("a", "vless", 50, 101, null, null, null)
        assertNotSame(first, fresh)
        assertEquals(100L, first["time"])
        val failed = cache.result("a", "vless", 0, 102, "unavailable", "timeout", "timeout")
        assertEquals("timeout", failed["error"])
        cache.retain(emptySet())
        assertNotSame(failed, cache.result("a", "vless", 0, 102, "unavailable", "timeout", "timeout"))
    }
}
