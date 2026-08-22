package com.etonify.meow_client.singbox

import io.nekohasekai.libbox.StringIterator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SplitTunnelPackagesTest {
    @Test
    fun `simple string iterator reports its original size`() {
        val iterator = SimpleStringIterator(listOf("one", "two", "three"))

        assertEquals(3, iterator.len())
        assertEquals("one", iterator.next())
        assertEquals(3, iterator.len())
        assertEquals(listOf("two", "three"), buildList {
            while (iterator.hasNext()) add(iterator.next())
        })
    }

    @Test
    fun `resolves each JNI iterator getter once`() {
        var includeGetterCalls = 0
        var excludeGetterCalls = 0

        val packages = readSplitTunnelPackages(
            includePackage = {
                includeGetterCalls++
                ListStringIterator(listOf("com.example.one", "com.example.two"))
            },
            excludePackage = {
                excludeGetterCalls++
                ListStringIterator(emptyList())
            },
        )

        assertEquals(1, includeGetterCalls)
        assertEquals(1, excludeGetterCalls)
        assertEquals(listOf("com.example.one", "com.example.two"), packages.included)
        assertEquals(emptyList<String>(), packages.excluded)
    }

    @Test
    fun `rejects an iterator that exceeds the package limit`() {
        val iterator = InfiniteStringIterator()

        assertThrows(SplitTunnelConfigurationException::class.java) {
            readSplitTunnelPackages(
                includePackage = { iterator },
                excludePackage = { ListStringIterator(emptyList()) },
            )
        }

        assertEquals(MAX_SPLIT_TUNNEL_PACKAGE_COUNT, iterator.nextCalls)
    }

    @Test
    fun `rejects simultaneous include and exclude modes`() {
        assertThrows(SplitTunnelConfigurationException::class.java) {
            readSplitTunnelPackages(
                includePackage = { ListStringIterator(listOf("com.example.included")) },
                excludePackage = { ListStringIterator(listOf("com.example.excluded")) },
            )
        }
    }

    @Test
    fun `rejects include mode when Android applied no selected package`() {
        assertThrows(SplitTunnelConfigurationException::class.java) {
            requireAppliedIncludedPackages(
                requested = listOf("org.telegram.messenger"),
                applied = emptyList(),
            )
        }
    }

    @Test
    fun `accepts include mode when Android applied a selected package`() {
        requireAppliedIncludedPackages(
            requested = listOf("org.telegram.messenger", "com.example.removed"),
            applied = listOf("org.telegram.messenger"),
        )
    }

    @Test
    fun `exclude mode keeps the VPN owner routed through its own tunnel`() {
        assertEquals(
            listOf("com.example.direct"),
            keepVpnOwnerRouted(
                excluded = listOf("com.example.direct", "com.etonify.meow_client"),
                ownerPackage = "com.etonify.meow_client",
            ),
        )
        assertEquals(
            listOf("com.example.direct"),
            keepVpnOwnerRouted(
                excluded = listOf("com.example.direct"),
                ownerPackage = "com.etonify.meow_client",
            ),
        )
    }

    @Test
    fun `full tunnel mode does not implicitly exclude the VPN owner`() {
        assertEquals(
            emptyList<String>(),
            keepVpnOwnerRouted(
                excluded = emptyList(),
                ownerPackage = "com.etonify.meow_client",
            ),
        )
    }

    @Test
    fun `VPN owner is allowed into TUN but never added to the bypass list`() {
        assertEquals(
            true,
            shouldApplyTunPackage(
                packageName = "com.etonify.meow_client",
                ownerPackage = "com.etonify.meow_client",
                allowed = true,
            ),
        )
        assertEquals(
            false,
            shouldApplyTunPackage(
                packageName = "com.etonify.meow_client",
                ownerPackage = "com.etonify.meow_client",
                allowed = false,
            ),
        )
    }
}

private class ListStringIterator(
    private val values: List<String>,
) : StringIterator {
    private val iterator = values.iterator()

    override fun hasNext(): Boolean = iterator.hasNext()

    override fun len(): Int = values.size

    override fun next(): String = iterator.next()
}

private class InfiniteStringIterator : StringIterator {
    var nextCalls = 0
        private set

    override fun hasNext(): Boolean = true

    override fun len(): Int = Int.MAX_VALUE

    override fun next(): String {
        nextCalls++
        return "com.example.repeated"
    }
}
