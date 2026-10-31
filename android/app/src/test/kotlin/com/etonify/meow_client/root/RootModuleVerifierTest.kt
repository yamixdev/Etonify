package com.etonify.meow_client.root

import java.io.ByteArrayOutputStream
import java.nio.file.Files
import java.security.KeyPairGenerator
import java.security.MessageDigest
import java.security.Signature
import java.util.Base64
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class RootModuleVerifierTest {
    private val key = KeyPairGenerator.getInstance("RSA").apply { initialize(3072) }.generateKeyPair()
    private val trustedKey = Base64.getEncoder().encodeToString(key.public.encoded)
    private val binary = "synthetic-test-binary".toByteArray()
    private val digest = MessageDigest.getInstance("SHA-256").digest(binary).joinToString("") { "%02x".format(it) }
    private fun manifest(versionCode: Int = 1, path: String = "etonify-root", abi: String = "arm64-v8a") =
        """{"protocol":1,"moduleVersion":"0.1.0","versionCode":$versionCode,"coreCommit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","abi":"$abi","minAndroidApi":26,"minClientVersionCode":41,"files":[{"path":"$path","size":${binary.size},"sha256":"$digest"}]}""".toByteArray()

    private fun archive(manifest: ByteArray = manifest(), payload: ByteArray = binary, extra: String? = null): ByteArray {
        val signature = Signature.getInstance("SHA256withRSA").apply { initSign(key.private); update(manifest) }.sign()
        return ByteArrayOutputStream().also { bytes ->
            ZipOutputStream(bytes).use { zip ->
                listOf("manifest.json" to manifest, "manifest.sig" to signature, "etonify-root" to payload)
                    .plus(if (extra == null) emptyList() else listOf(extra to byteArrayOf(1)))
                    .forEach { (name, data) -> zip.putNextEntry(ZipEntry(name)); zip.write(data); zip.closeEntry() }
            }
        }.toByteArray()
    }

    private fun verify(zip: ByteArray, installed: Int = 0, publicKey: String = trustedKey, client: Long = 41): VerifiedRootModule {
        val dir = Files.createTempDirectory("etonify-root-test").toFile()
        try {
            return RootModuleVerifier(publicKey, "arm64-v8a", 28, client).verify(zip.inputStream(), dir, installed)
        } finally { dir.deleteRecursively() }
    }

    @Test fun `valid signature authorizes only the exact hashed payload`() {
        val result = verify(archive())
        assertEquals(digest, result.manifest.sha256)
        assertEquals(1, result.manifest.versionCode)
    }

    @Test fun `missing trust key fails closed`() {
        assertEquals("signing_not_configured", assertThrows(RootModuleException::class.java) { verify(archive(), publicKey = "") }.code)
    }

    @Test fun `payload tampering fails despite valid manifest signature`() {
        assertEquals("binary_hash_mismatch", assertThrows(RootModuleException::class.java) { verify(archive(payload = ByteArray(binary.size))) }.code)
    }

    @Test fun `unlisted traversal member is rejected`() {
        assertEquals("archive_entry_invalid", assertThrows(RootModuleException::class.java) { verify(archive(extra = "../escape")) }.code)
    }

    @Test fun `downgrade is rejected before installation`() {
        assertEquals("downgrade_rejected", assertThrows(RootModuleException::class.java) { verify(archive(), installed = 2) }.code)
    }

    @Test fun `signed but incompatible abi is rejected`() {
        assertEquals("abi_unsupported", assertThrows(RootModuleException::class.java) { verify(archive(manifest(abi = "x86_64"))) }.code)
    }

    @Test fun `ABI split version prefix cannot bypass minimum client version`() {
        val needsNewer = String(manifest()).replace("\"minClientVersionCode\":41", "\"minClientVersionCode\":42").toByteArray()
        assertEquals("client_incompatible", assertThrows(RootModuleException::class.java) {
            verify(archive(needsNewer), client = 2041)
        }.code)
    }

    @Test fun `signed newer compatible module does not require a new app build`() {
        val newer = String(manifest(versionCode = 2)).replace("\"0.1.0\"", "\"0.2.0\"").toByteArray()
        val result = verify(archive(manifest = newer), installed = 1)
        assertEquals(2, result.manifest.versionCode)
        assertEquals("0.2.0", result.manifest.moduleVersion)
    }

    @Test fun `signed manifest cannot name another executable`() {
        assertEquals("manifest_invalid", assertThrows(RootModuleException::class.java) { verify(archive(manifest(path = "other"))) }.code)
    }
}
