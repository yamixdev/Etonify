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
class RootModuleManagerTest {
    private val context get() = RuntimeEnvironment.getApplication()
    private class ForbiddenRoot : RootProcessRunner() {
        override fun execute(command: String, input: ByteArray?, timeoutMs: Long): RootCommandResult =
            throw AssertionError("Unexpected su request")
    }
    @Before fun reset() { context.getSharedPreferences("etonify_root_module", 0).edit().clear().commit() }

    @Test fun `snapshot never requests root or trusts enabled preference without verified module`() {
        context.getSharedPreferences("etonify_root_module", 0).edit().putBoolean("enabled", true).commit()
        val manager = RootModuleManager(context, "", { false }, ForbiddenRoot())
        assertEquals("unknown", manager.snapshot()["rootAvailability"])
        assertEquals("notInstalled", manager.snapshot()["moduleState"])
        assertEquals(false, manager.snapshot()["enabled"])
    }

    @Test fun `missing signing configuration fails before any root request or download`() {
        val manager = RootModuleManager(context, "", { false }, ForbiddenRoot())
        assertEquals("signing_not_configured", manager.install()["reason"])
    }

    @Test fun `active runtime prevents destructive module operation before root request`() {
        val manager = RootModuleManager(context, "", { true }, ForbiddenRoot())
        assertEquals("runtime_busy", manager.remove()["reason"])
    }

    @Test fun `nonroot authorization never enables root mode`() {
        val nonRoot = object : RootProcessRunner() {
            override fun execute(command: String, input: ByteArray?, timeoutMs: Long) = RootCommandResult(0, "2000\n", "")
        }
        val manager = RootModuleManager(context, "", { false }, nonRoot)
        assertEquals("denied", manager.requestAuthorization()["rootAvailability"])
        assertEquals(false, manager.setEnabled(true)["enabled"])
    }

    @Test fun `update network failure preserves verified installed module and permits disabling`() {
        val key = KeyPairGenerator.getInstance("RSA").apply { initialize(3072) }.generateKeyPair()
        val publicKey = Base64.getEncoder().encodeToString(key.public.encoded)
        val manifest = """{"protocol":1,"moduleVersion":"0.1.0","versionCode":1,"coreCommit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","abi":"arm64-v8a","minAndroidApi":26,"minClientVersionCode":41,"files":[{"path":"etonify-root","size":3,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}""".toByteArray()
        val signature = Signature.getInstance("SHA256withRSA").apply { initSign(key.private); update(manifest) }.sign()
        context.getSharedPreferences("etonify_root_module", 0).edit()
            .putString("manifest", Base64.getEncoder().encodeToString(manifest))
            .putString("signature", Base64.getEncoder().encodeToString(signature))
            .putBoolean("enabled", true).commit()
        val manager = RootModuleManager(context, publicKey, { false }, ForbiddenRoot(),
            RootModuleVerifier(publicKey, "arm64-v8a", 28, 41),
            { throw RootModuleException("release_discovery_failed") })
        assertEquals("ready", manager.snapshot()["moduleState"])
        val result = manager.checkUpdate()
        assertEquals("release_discovery_failed", result["reason"])
        assertEquals("ready", result["moduleState"])
        assertEquals(true, result["enabled"])
        assertEquals(false, manager.setEnabled(false)["enabled"])
        assertFalse(RootModuleManager.enabled(context))
    }

    @Test fun `disable persists even while runtime is active`() {
        context.getSharedPreferences("etonify_root_module", 0).edit().putBoolean("enabled", true).commit()
        val manager = RootModuleManager(context, "", { true }, ForbiddenRoot())
        manager.setEnabled(false)
        assertFalse(RootModuleManager.enabled(context))
    }
}
