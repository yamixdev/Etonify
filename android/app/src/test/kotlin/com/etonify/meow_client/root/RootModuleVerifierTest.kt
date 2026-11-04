package com.etonify.meow_client.root

import java.security.KeyPairGenerator
import java.security.Signature
import java.util.Base64
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
    private fun manifest(path: String = "etonify-root") =
        """{"protocol":1,"moduleVersion":"0.1.0","versionCode":1,"coreCommit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","abi":"arm64-v8a","minAndroidApi":26,"minClientVersionCode":41,"files":[{"path":"$path","size":3,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}""".toByteArray()
    private fun sign(bytes: ByteArray) = Signature.getInstance("SHA256withRSA").apply { initSign(key.private); update(bytes) }.sign()
    private fun verify(bytes: ByteArray, signature: ByteArray = sign(bytes), publicKey: String = trustedKey) =
        RootModuleVerifier(publicKey, "arm64-v8a", 28, 41).verifyManifest(bytes, signature)

    @Test fun `signed legacy manifest retains exact binary hash for cleanup`() {
        assertEquals("a".repeat(64), verify(manifest()).sha256)
        assertEquals(1, verify(manifest()).versionCode)
    }
    @Test fun `tampered cached metadata fails signature verification`() {
        val original = manifest()
        val tampered = String(original).replace("\"size\":3", "\"size\":4").toByteArray()
        assertEquals("signature_invalid", assertThrows(RootModuleException::class.java) { verify(tampered, sign(original)) }.code)
    }
    @Test fun `missing trust fails before any executable can be authorized`() {
        assertEquals("signing_not_configured", assertThrows(RootModuleException::class.java) { verify(manifest(), publicKey = "") }.code)
    }
    @Test fun `signed manifest cannot select another executable`() {
        assertEquals("manifest_invalid", assertThrows(RootModuleException::class.java) { verify(manifest("../other")) }.code)
    }
}
