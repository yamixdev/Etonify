package com.etonify.meow_client.root

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.security.KeyPairGenerator
import java.security.Signature
import java.util.Base64

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class RootLegacyCleanupTest {
    private val context get() = RuntimeEnvironment.getApplication()
    @Before fun reset() {
        context.getSharedPreferences("etonify_root_module", 0).edit().clear().commit()
        context.getSharedPreferences("etonify_legacy_module_cleanup", 0).edit().clear().commit()
    }

    @Test fun `invalid legacy metadata is a local candidate for one cleanup prompt`() {
        context.getSharedPreferences("etonify_root_module", 0).edit().putString("manifest", "invalid").commit()
        val manager = RootModuleManager(context, "", runner = forbiddenRoot())
        assertEquals(true, manager.snapshot()["legacyModuleCandidate"])
        assertEquals(true, manager.snapshot()["promptPending"])
        assertEquals("failed", manager.snapshot()["moduleState"])
    }

    @Test fun `fresh install has no cleanup prompt or root request`() {
        val snapshot = RootModuleManager(context, "", runner = forbiddenRoot()).snapshot()
        assertEquals(false, snapshot["legacyModuleCandidate"])
        assertEquals(false, snapshot["promptPending"])
    }

    @Test fun `acknowledged cleanup prompt remains handled after process recreation without root`() {
        context.getSharedPreferences("etonify_root_module", 0).edit().putString("signature", "invalid").commit()
        val first = RootModuleManager(context, "", runner = forbiddenRoot())
        assertEquals(true, first.snapshot()["promptPending"])
        assertEquals(false, first.acknowledgePrompt()["promptPending"])
        val recreated = RootModuleManager(context, "", runner = forbiddenRoot()).snapshot()
        assertEquals(false, recreated["promptPending"])
        assertEquals(true, recreated["legacyModuleCandidate"])
        assertNotNull(context.getSharedPreferences("etonify_root_module", 0).getString("signature", null))
    }

    @Test fun `opening cleanup resets legacy enabled preference without requesting root`() {
        val prefs = context.getSharedPreferences("etonify_root_module", 0)
        prefs.edit().putBoolean("enabled", true).commit()
        val manager = RootModuleManager(context, "", runner = forbiddenRoot())
        assertFalse(prefs.getBoolean("enabled", true))
        assertEquals(false, manager.snapshot()["enabled"])
    }

    @Test fun `missing signed metadata cannot execute old binary or delete root files`() {
        val manager = RootModuleManager(context, "", runner = forbiddenRoot())
        assertEquals("module_metadata_missing", manager.remove()["reason"])
    }

    @Test fun `active VPN prevents migration cleanup without requesting root`() {
        val manager = RootModuleManager(context, "", isRuntimeActive = { true }, runner = forbiddenRoot())
        assertEquals("runtime_busy", manager.remove()["reason"])
    }

    private fun forbiddenRoot() = object : RootProcessRunner() {
        override fun execute(command: String, input: ByteArray?, timeoutMs: Long): RootCommandResult =
            throw AssertionError("Unexpected root command: $command")
    }

    @Test fun `orphan download copies can be removed without root or installed metadata`() {
        val copy = java.io.File(context.cacheDir, "root-module-11111111-1111-1111-1111-111111111111").apply { mkdirs() }
        java.io.File(copy, "download.zip").writeText("orphan")
        val unrelated = java.io.File(context.cacheDir, "profile-backup").apply { writeText("keep") }
        // Robolectric's Windows filesystem has a host UID, not the app's
        // Android UID. Model app ownership at this OS boundary.
        val originalUid = android.os.Process.myUid()
        org.robolectric.shadows.ShadowProcess.setUid(android.system.Os.lstat(copy.absolutePath).st_uid)
        try {
            val result = RootModuleManager(context, "", runner = forbiddenRoot()).snapshot()
            assertNull(result["reason"])
            assertFalse("orphan download must not be stranded behind a root check", copy.exists())
            assertTrue(unrelated.exists())
        } finally {
            org.robolectric.shadows.ShadowProcess.setUid(originalUid)
            copy.deleteRecursively(); unrelated.delete()
        }
    }

    @Test fun `excessive cache depth is rejected before deletion or root request`() {
        val copy = java.io.File(context.cacheDir, "root-module-22222222-2222-2222-2222-222222222222").apply { mkdirs() }
        var nested = copy
        repeat(10) { nested = java.io.File(nested, "nested").apply { mkdir() } }
        java.io.File(nested, "keep").writeText("deep")
        val originalUid = android.os.Process.myUid()
        org.robolectric.shadows.ShadowProcess.setUid(android.system.Os.lstat(copy.absolutePath).st_uid)
        try {
            val result = RootModuleManager(context, "", runner = forbiddenRoot()).snapshot()
            assertEquals("module_cache_cleanup_failed", result["reason"])
            assertTrue(java.io.File(nested, "keep").exists())
        } finally {
            org.robolectric.shadows.ShadowProcess.setUid(originalUid)
            copy.deleteRecursively()
        }
    }

    private fun installed(runner: RootProcessRunner): RootModuleManager {
        val key = KeyPairGenerator.getInstance("RSA").apply { initialize(3072) }.generateKeyPair()
        val publicKey = Base64.getEncoder().encodeToString(key.public.encoded)
        val manifest = """{"protocol":1,"moduleVersion":"0.1.0","versionCode":1,"coreCommit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","abi":"arm64-v8a","minAndroidApi":26,"minClientVersionCode":41,"files":[{"path":"etonify-root","size":3,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}""".toByteArray()
        val signature = Signature.getInstance("SHA256withRSA").apply { initSign(key.private); update(manifest) }.sign()
        context.getSharedPreferences("etonify_root_module", 0).edit()
            .putString("manifest", Base64.getEncoder().encodeToString(manifest))
            .putString("signature", Base64.getEncoder().encodeToString(signature)).commit()
        return RootModuleManager(context, publicKey, runner = runner,
            verifier = RootModuleVerifier(publicKey, "arm64-v8a", 28, 41))
    }

    @Test fun `failed integrity check cannot run cleanup or delete anything`() {
        val calls = mutableListOf<String>()
        val runner = object : RootProcessRunner() {
            override fun execute(command: String, input: ByteArray?, timeoutMs: Long): RootCommandResult {
                calls.add(command)
                return if (command == "id -u") RootCommandResult(0, "0\n", "") else RootCommandResult(1, "", "")
            }
        }
        val manager = installed(runner)
        manager.acknowledgePrompt()
        val result = manager.remove()
        assertEquals("module_integrity_failed", result["reason"])
        assertEquals(2, calls.size)
        assertTrue(calls.none { it.startsWith("exec timeout") || it.contains("rm -rf") })
        assertNotNull(context.getSharedPreferences("etonify_root_module", 0).getString("manifest", null))
    }

    @Test fun `failed network cleanup preserves module and signed metadata`() {
        val calls = mutableListOf<String>()
        val runner = object : RootProcessRunner() {
            override fun execute(command: String, input: ByteArray?, timeoutMs: Long): RootCommandResult {
                calls.add(command)
                return when {
                    command == "id -u" -> RootCommandResult(0, "0\n", "")
                    command.startsWith("exec timeout") -> RootCommandResult(1, """{"protocol":1,"ready":false,"reason":"journal_denied"}""", "")
                    else -> RootCommandResult(0, "", "")
                }
            }
        }
        assertEquals("module_cleanup_journal_denied", installed(runner).remove()["reason"])
        assertEquals(3, calls.size)
        assertTrue(calls.none { it.contains("rm -rf") })
        assertNotNull(context.getSharedPreferences("etonify_root_module", 0).getString("manifest", null))
    }

    @Test fun `successful cleanup deletes only exact module root and clears preference`() {
        val calls = mutableListOf<String>()
        val runner = object : RootProcessRunner() {
            override fun execute(command: String, input: ByteArray?, timeoutMs: Long): RootCommandResult {
                calls.add(command)
                return RootCommandResult(0, if (command == "id -u") "0\n" else "", "")
            }
        }
        val manager = installed(runner)
        manager.acknowledgePrompt()
        val result = manager.remove()
        assertNull(result["reason"])
        assertEquals("notInstalled", result["moduleState"])
        assertEquals(4, calls.size)
        assertTrue(calls[2].startsWith("exec timeout"))
        assertTrue(calls[3].endsWith("rm -rf -- /data/adb/etonify"))
        assertNull(context.getSharedPreferences("etonify_root_module", 0).getString("manifest", null))
        assertFalse(context.getSharedPreferences("etonify_root_module", 0).getBoolean("enabled", true))
        assertTrue(context.getSharedPreferences("etonify_legacy_module_cleanup", 0).getBoolean("prompt_handled_v1", false))
    }
}
