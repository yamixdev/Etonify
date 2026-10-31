package com.etonify.meow_client.root

import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class RootModuleInstallerTest {
    private class RootFixture(private val health: String, private val failActivate: Boolean = false, private val runtimeBusy: Boolean = false) : RootProcessRunner() {
        var activated = false
        override fun executeStreaming(command: String, input: java.io.InputStream?, timeoutMs: Long): RootCommandResult {
            input?.readBytes()
            return RootCommandResult(0, health, "")
        }
        override fun execute(command: String, input: ByteArray?, timeoutMs: Long): RootCommandResult {
            if (Thread.currentThread().isInterrupted) throw InterruptedException()
            if (runtimeBusy && command.contains(" cleanup --work-dir ")) {
                return RootCommandResult(1, """{"ready":false,"protocol":1,"reason":"already_running"}""", "")
            }
            if (command.startsWith("set -eu; if test -f")) {
                activated = false
            } else if (command.contains("mv -Tf")) {
                if (failActivate) return RootCommandResult(1, "", "")
                activated = true
            }
            return RootCommandResult(0, "", "")
        }
    }
    private fun module(): VerifiedRootModule {
        val binary = Files.createTempFile("etonify-root-installer-test", ".bin").toFile()
        binary.writeBytes(byteArrayOf(1, 2, 3))
        return VerifiedRootModule(RootModuleManifest("0.1.0", 1, "a".repeat(40), "arm64-v8a", 3, "b".repeat(64)), binary, byteArrayOf(), byteArrayOf())
    }
    private val health = """{"protocol":1,"moduleVersion":"0.1.0","abi":"arm64-v8a","coreCommit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}"""

    @Test fun `metadata becomes ready only after successful activation`() {
        val root = RootFixture(health)
        val module = module()
        var committed = false
        try {
            RootModuleInstaller(root).install(module) { assertTrue(root.activated); committed = true }
            assertTrue(committed)
            assertTrue(root.activated)
        } finally { module.binary.delete() }
    }

    @Test fun `healthcheck mismatch cannot activate module or commit metadata`() {
        val root = RootFixture(health.replace("arm64-v8a", "x86_64"))
        val module = module()
        var committed = false
        try {
            assertEquals("module_healthcheck_failed", assertThrows(RootModuleException::class.java) {
                RootModuleInstaller(root).install(module) { committed = true }
            }.code)
            assertFalse(root.activated)
            assertFalse(committed)
        } finally { module.binary.delete() }
    }

    @Test fun `daemon from previous app process blocks activation through native lock`() {
        val root = RootFixture(health, runtimeBusy = true)
        val module = module()
        var committed = false
        try {
            assertEquals("runtime_busy", assertThrows(RootModuleException::class.java) {
                RootModuleInstaller(root).install(module) { committed = true }
            }.code)
            assertFalse(root.activated)
            assertFalse(committed)
        } finally { module.binary.delete() }
    }

    @Test fun `failed activation never commits ready metadata`() {
        val root = RootFixture(health, failActivate = true)
        val module = module()
        var committed = false
        try {
            assertEquals("module_activation_failed", assertThrows(RootModuleException::class.java) {
                RootModuleInstaller(root).install(module) { committed = true }
            }.code)
            assertFalse(committed)
        } finally { module.binary.delete() }
    }

    @Test fun `metadata failure restores previous active module`() {
        val root = RootFixture(health)
        val module = module()
        try {
            assertThrows(RootModuleException::class.java) {
                RootModuleInstaller(root).install(module) { throw RootModuleException("module_metadata_failed") }
            }
            assertFalse(root.activated)
        } finally { module.binary.delete() }
    }

    @Test fun `cancellation after activation rolls back before restoring interrupt state`() {
        val root = RootFixture(health)
        val module = module()
        try {
            assertThrows(RootModuleException::class.java) {
                RootModuleInstaller(root).install(module) {
                    Thread.currentThread().interrupt()
                    throw RootModuleException("operation_cancelled")
                }
            }
            assertFalse(root.activated)
            assertTrue(Thread.currentThread().isInterrupted)
        } finally { Thread.interrupted(); module.binary.delete() }
    }
}
