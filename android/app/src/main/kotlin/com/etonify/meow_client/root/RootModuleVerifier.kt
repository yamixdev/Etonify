package com.etonify.meow_client.root

import java.io.File
import java.io.InputStream
import java.security.KeyFactory
import java.security.MessageDigest
import java.security.Signature
import java.security.interfaces.RSAPublicKey
import java.security.spec.X509EncodedKeySpec
import java.util.Base64
import java.util.zip.ZipFile
import org.json.JSONObject

class RootModuleException(val code: String) : Exception(code)

data class RootModuleManifest(
    val moduleVersion: String,
    val versionCode: Int,
    val coreCommit: String,
    val abi: String,
    val size: Long,
    val sha256: String,
)

data class VerifiedRootModule(val manifest: RootModuleManifest, val binary: File, val manifestBytes: ByteArray, val signatureBytes: ByteArray)

class RootModuleVerifier(
    private val trustedPublicKeyBase64: String,
    private val abi: String,
    private val androidApi: Int,
    private val clientVersionCode: Long,
) {
    fun verify(input: InputStream, staging: File, installedVersionCode: Int = 0): VerifiedRootModule {
        trustedKey()
        staging.mkdirs()
        val archive = File(staging, "module.zip")
        input.use { source -> archive.outputStream().use { copyBounded(source, it, MAX_ARCHIVE_BYTES) } }
        try {
            ZipFile(archive).use { zip ->
                val entries = mutableListOf<java.util.zip.ZipEntry>()
                val iterator = zip.entries()
                while (iterator.hasMoreElements()) {
                    if (entries.size == 3) throw RootModuleException("archive_entry_invalid")
                    entries.add(iterator.nextElement())
                }
                val allowed = setOf("manifest.json", "manifest.sig", "etonify-root")
                if (entries.size != 3 || entries.map { it.name }.toSet() != allowed || entries.any { it.isDirectory }) {
                    throw RootModuleException("archive_entry_invalid")
                }
                val manifestBytes = zip.getInputStream(zip.getEntry("manifest.json")).use { readBounded(it, MAX_MANIFEST_BYTES) }
                val signatureBytes = zip.getInputStream(zip.getEntry("manifest.sig")).use { readBounded(it, 1024) }
                val manifest = verifyManifest(manifestBytes, signatureBytes, installedVersionCode)
                val binary = File(staging, "etonify-root")
                val digest = MessageDigest.getInstance("SHA-256")
                var total = 0L
                zip.getInputStream(zip.getEntry("etonify-root")).use { source ->
                    binary.outputStream().use { target ->
                        val buffer = ByteArray(32768)
                        while (true) {
                            val count = source.read(buffer)
                            if (count < 0) break
                            total += count
                            if (total > manifest.size) throw RootModuleException("binary_size_mismatch")
                            digest.update(buffer, 0, count)
                            target.write(buffer, 0, count)
                        }
                    }
                }
                if (total != manifest.size) throw RootModuleException("binary_size_mismatch")
                if (digest.digest().toHex() != manifest.sha256) throw RootModuleException("binary_hash_mismatch")
                return VerifiedRootModule(manifest, binary, manifestBytes, signatureBytes)
            }
        } catch (error: RootModuleException) {
            throw error
        } catch (_: Exception) {
            throw RootModuleException("archive_invalid")
        } finally {
            archive.delete()
        }
    }

    fun verifyManifest(bytes: ByteArray, signature: ByteArray, installedVersionCode: Int = 0): RootModuleManifest {
        val key = trustedKey()
        if (bytes.size > MAX_MANIFEST_BYTES || signature.size != 384) throw RootModuleException("manifest_invalid")
        val valid = try {
            Signature.getInstance("SHA256withRSA").run { initVerify(key); update(bytes); verify(signature) }
        } catch (_: Exception) { false }
        if (!valid) throw RootModuleException("signature_invalid")
        return parseManifest(bytes, installedVersionCode)
    }

    private fun trustedKey(): RSAPublicKey {
        if (trustedPublicKeyBase64.isBlank()) throw RootModuleException("signing_not_configured")
        return try {
            val key = KeyFactory.getInstance("RSA").generatePublic(
                X509EncodedKeySpec(Base64.getDecoder().decode(trustedPublicKeyBase64)),
            ) as RSAPublicKey
            if (key.modulus.bitLength() != 3072) throw RootModuleException("signing_key_invalid")
            key
        } catch (_: Exception) { throw RootModuleException("signing_key_invalid") }
    }

    private fun parseManifest(bytes: ByteArray, installedVersionCode: Int): RootModuleManifest {
        try {
            val json = JSONObject(String(bytes, Charsets.UTF_8))
            if (integer(json, "protocol") != 1L) throw RootModuleException("protocol_unsupported")
            val moduleAbi = json.getString("abi")
            if (moduleAbi != "arm64-v8a" || moduleAbi != abi) throw RootModuleException("abi_unsupported")
            val minApi = integer(json, "minAndroidApi")
            val minClient = integer(json, "minClientVersionCode")
            val splitBuildNumber = clientVersionCode % 1000
            val clientBuildNumber = if (clientVersionCode >= 1000 && splitBuildNumber > 0) splitBuildNumber else clientVersionCode
            if (minApi > androidApi || minClient > clientBuildNumber) {
                throw RootModuleException("client_incompatible")
            }
            if (minApi < 26L || minClient < 1L) throw RootModuleException("manifest_invalid")
            val versionNumber = integer(json, "versionCode")
            if (versionNumber !in 1..Int.MAX_VALUE) throw RootModuleException("manifest_invalid")
            val versionCode = versionNumber.toInt()
            if (versionCode < installedVersionCode) throw RootModuleException("downgrade_rejected")
            val version = json.getString("moduleVersion")
            val commit = json.getString("coreCommit")
            val files = json.getJSONArray("files")
            if (!version.matches(Regex("[0-9]+\\.[0-9]+\\.[0-9]+")) || !commit.matches(Regex("[0-9a-f]{40}")) || files.length() != 1) {
                throw RootModuleException("manifest_invalid")
            }
            val binary = files.getJSONObject(0)
            val size = integer(binary, "size")
            val hash = binary.getString("sha256")
            if (binary.getString("path") != "etonify-root" || size !in 1..MAX_ARCHIVE_BYTES || !hash.matches(Regex("[0-9a-f]{64}"))) {
                throw RootModuleException("manifest_invalid")
            }
            return RootModuleManifest(version, versionCode, commit, moduleAbi, size, hash)
        } catch (error: RootModuleException) { throw error
        } catch (_: Exception) { throw RootModuleException("manifest_invalid") }
    }

    private fun integer(json: JSONObject, key: String): Long {
        val value = json.get(key)
        if (value !is Int && value !is Long) throw RootModuleException("manifest_invalid")
        return (value as Number).toLong()
    }

    companion object {
        const val MAX_ARCHIVE_BYTES = 128L * 1024 * 1024
        const val MAX_MANIFEST_BYTES = 64L * 1024

        fun readBounded(input: InputStream, limit: Long): ByteArray = java.io.ByteArrayOutputStream().also {
            copyBounded(input, it, limit)
        }.toByteArray()

        fun copyBounded(input: InputStream, target: java.io.OutputStream, limit: Long) {
            val buffer = ByteArray(32768)
            var total = 0L
            while (true) {
                val count = input.read(buffer)
                if (count < 0) return
                total += count
                if (total > limit) throw RootModuleException("download_size_exceeded")
                target.write(buffer, 0, count)
            }
        }

        fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }
    }
}
