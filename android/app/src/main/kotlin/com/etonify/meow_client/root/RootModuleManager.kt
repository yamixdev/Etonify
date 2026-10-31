package com.etonify.meow_client.root

import android.content.Context
import android.os.Build
import java.io.File
import java.net.URL
import java.util.Base64
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.HttpsURLConnection

class RootModuleManager(
    context: Context,
    private val trustedPublicKeyBase64: String,
    private val isRuntimeActive: () -> Boolean = { false },
    private val runner: RootProcessRunner = RootProcessRunner(),
    verifier: RootModuleVerifier? = null,
    private val releaseIndexSource: (() -> ByteArray)? = null,
) {
    private val context = context.applicationContext
    private val prefs = this.context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val busy = AtomicBoolean(false)
    private val verifier = verifier ?: RootModuleVerifier(
        trustedPublicKeyBase64,
        if (Build.SUPPORTED_ABIS.contains("arm64-v8a")) "arm64-v8a" else "unsupported",
        Build.VERSION.SDK_INT,
        @Suppress("DEPRECATION") this.context.packageManager.getPackageInfo(this.context.packageName, 0).let {
            if (Build.VERSION.SDK_INT >= 28) it.longVersionCode else it.versionCode.toLong()
        },
    )
    @Volatile private var cached: RootModuleManifest? = loadCached()
    @Volatile private var rootAvailability = "unknown"
    @Volatile private var moduleState = if (cached == null) "notInstalled" else "ready"
    @Volatile private var reason: String? = if (trustedPublicKeyBase64.isBlank()) "signing_not_configured" else null
    @Volatile private var progress = 0.0
    val isBusy: Boolean get() = busy.get()

    fun snapshot(): Map<String, Any?> = mapOf(
        "rootAvailability" to rootAvailability,
        "moduleState" to moduleState,
        "moduleVersion" to cached?.moduleVersion,
        "enabled" to (cached != null && prefs.getBoolean("enabled", false)),
        "busy" to busy.get(),
        "reason" to reason,
        "progress" to progress,
        "authorizationCached" to (rootAvailability == "granted"),
    )

    fun requestAuthorization(): Map<String, Any?> = operation {
        if (!authorize()) throw RootModuleException(if (rootAvailability == "noSu") "su_not_found" else "root_denied")
    }

    fun install(onProgress: (Map<String, Any?>) -> Unit = {}): Map<String, Any?> = operation {
        requireSigning()
        if (!authorize()) throw RootModuleException(if (rootAvailability == "noSu") "su_not_found" else "root_denied")
        val stage = createStage()
        try {
            moduleState = "downloading"
            onProgress(snapshot())
            val release = discoverRelease()
            val archive = download(stage, release, onProgress)
            moduleState = "verifying"
            onProgress(snapshot())
            val verified = archive.inputStream().use { verifier.verify(it, File(stage, "verified"), cached?.versionCode ?: 0) }
            if (verified.manifest.moduleVersion != release.moduleVersion) throw RootModuleException("release_version_mismatch")
            moduleState = "installing"
            progress = 0.95
            onProgress(snapshot())
            val manifest = verified.manifest
            RootModuleInstaller(runner).install(verified) {
                prefs.edit()
                    .putString("manifest", Base64.getEncoder().encodeToString(verified.manifestBytes))
                    .putString("signature", Base64.getEncoder().encodeToString(verified.signatureBytes))
                    .putBoolean("enabled", false).commit().also { if (!it) throw RootModuleException("module_metadata_failed") }
            }
            cached = manifest
            moduleState = "ready"
            progress = 1.0
            onProgress(snapshot())
        } finally {
            stage.deleteRecursively()
        }
    }

    fun remove(): Map<String, Any?> = operation {
        if (cached != null) {
            if (!authorizeRuntime()) throw RootModuleException(reason ?: "root_denied")
            requireCleanupSuccess(runner.execute("exec timeout -s KILL 15 $ROOT/current/etonify-root cleanup --work-dir $ROOT/runtime", timeoutMs = 20_000))
        } else {
            if (!authorize()) throw RootModuleException("root_denied")
            if (runner.execute("test ! -e $ROOT").exitCode != 0) throw RootModuleException("module_metadata_missing")
        }
        if (runner.execute("set -eu; test ! -L $ROOT; rm -rf $ROOT").exitCode != 0) throw RootModuleException("module_remove_failed")
        prefs.edit().clear().commit()
        cached = null
        moduleState = "notInstalled"
        progress = 0.0
    }

    fun checkUpdate(): Map<String, Any?> {
        var available = false
        var availableVersion: String? = null
        val result = operation(preserveInstalledState = true) {
            requireSigning()
            val stage = createStage()
            try {
                val release = discoverRelease()
                val file = download(stage, release) {}
                val module = file.inputStream().use { verifier.verify(it, File(stage, "verified"), cached?.versionCode ?: 0) }
                if (module.manifest.moduleVersion != release.moduleVersion) throw RootModuleException("release_version_mismatch")
                available = module.manifest.versionCode > (cached?.versionCode ?: 0)
                availableVersion = module.manifest.moduleVersion
            } finally { stage.deleteRecursively() }
        }
        return result + mapOf("updateAvailable" to available, "availableModuleVersion" to availableVersion)
    }

    fun setEnabled(enabled: Boolean): Map<String, Any?> {
        if (!enabled) {
            if (!prefs.edit().putBoolean("enabled", false).commit()) reason = "module_metadata_failed"
            return snapshot()
        }
        return operation {
            if (!authorizeRuntime()) throw RootModuleException(reason ?: "module_not_ready")
            if (!prefs.edit().putBoolean("enabled", true).commit()) throw RootModuleException("module_metadata_failed")
        }
    }

    fun authorizeRuntime(): Boolean {
        val module = cached ?: run { reason = "module_not_ready"; return false }
        if (!authorize()) { reason = "root_denied"; return false }
        val result = runner.execute(
            "set -eu; test ! -L $ROOT; test -L $ROOT/current; " +
                "p=\$(readlink -f $ROOT/current); case \"\$p\" in $ROOT/versions/v${module.versionCode}-${module.sha256}) ;; *) exit 1;; esac; " +
                "test \"\$(stat -c '%u:%g:%a' \"\$p\")\" = '0:0:700'; " +
                "test \"\$(stat -c '%u:%g:%a' \"\$p/etonify-root\")\" = '0:0:700'; " +
                "test \"\$(sha256sum \"\$p/etonify-root\" | cut -d ' ' -f 1)\" = '${module.sha256}'",
        )
        if (result.exitCode != 0) { reason = "module_integrity_failed"; moduleState = "failed"; return false }
        reason = null
        moduleState = "ready"
        return true
    }

    private fun authorize(): Boolean {
        rootAvailability = RootCapabilityProbe { runner.execute("id -u", timeoutMs = 30_000) }.requestAuthorization()
        return rootAvailability == "granted"
    }

    private fun operation(preserveInstalledState: Boolean = false, action: () -> Unit): Map<String, Any?> {
        if (!busy.compareAndSet(false, true)) return snapshot() + ("reason" to "operation_busy")
        val initialState = moduleState
        try {
            if (isRuntimeActive()) throw RootModuleException("runtime_busy")
            reason = null
            action()
        } catch (error: RootModuleException) {
            reason = error.code
            if (preserveInstalledState && cached != null) moduleState = initialState
            else if (error.code !in setOf("runtime_busy", "operation_busy", "root_denied", "su_not_found")) {
                moduleState = if (error.code in setOf("abi_unsupported", "client_incompatible", "protocol_unsupported")) "incompatible" else "failed"
            }
        } catch (_: Exception) { reason = "root_operation_failed"; moduleState = if (preserveInstalledState && cached != null) initialState else "failed"
        } finally { busy.set(false) }
        return snapshot()
    }

    private fun requireSigning() {
        if (trustedPublicKeyBase64.isBlank()) throw RootModuleException("signing_not_configured")
    }

    private fun loadCached(): RootModuleManifest? = try {
        val manifest = Base64.getDecoder().decode(prefs.getString("manifest", ""))
        val signature = Base64.getDecoder().decode(prefs.getString("signature", ""))
        verifier.verifyManifest(manifest, signature)
    } catch (_: Exception) { null }

    private fun createStage(): File = File(context.cacheDir, "root-module-${UUID.randomUUID()}").apply {
        if (!mkdir()) throw RootModuleException("staging_failed")
        setReadable(false, false); setWritable(false, false); setExecutable(false, false)
        setReadable(true, true); setWritable(true, true); setExecutable(true, true)
    }

    private fun discoverRelease(): RootModuleRelease {
        releaseIndexSource?.let { return RootModuleReleaseIndex.parse(it()) }
        val connection = URL(RootModuleReleaseIndex.API_URL).openConnection() as HttpsURLConnection
        connection.instanceFollowRedirects = false
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        connection.setRequestProperty("Accept", "application/vnd.github+json")
        connection.setRequestProperty("X-GitHub-Api-Version", "2022-11-28")
        connection.setRequestProperty("User-Agent", "Etonify-RootModule")
        try {
            when (connection.responseCode) {
                403, 429 -> throw RootModuleException("release_discovery_rate_limited")
                200 -> Unit
                else -> throw RootModuleException("release_discovery_failed")
            }
            if (connection.contentLengthLong > RootModuleReleaseIndex.MAX_BYTES) throw RootModuleException("release_index_size_exceeded")
            val started = System.nanoTime()
            val bytes = connection.inputStream.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    if (Thread.currentThread().isInterrupted) throw RootModuleException("operation_cancelled")
                    if (System.nanoTime() - started > 30_000_000_000L) throw RootModuleException("release_discovery_timeout")
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (output.size().toLong() + count > RootModuleReleaseIndex.MAX_BYTES) throw RootModuleException("release_index_size_exceeded")
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            return RootModuleReleaseIndex.parse(bytes)
        } catch (error: RootModuleException) { throw error
        } catch (_: Exception) { throw RootModuleException("release_discovery_failed")
        } finally { connection.disconnect() }
    }

    private fun download(stage: File, release: RootModuleRelease, onProgress: (Map<String, Any?>) -> Unit): File {
        var url = URL(release.downloadUrl)
        repeat(6) {
            if (url.protocol != "https" || url.host !in DOWNLOAD_HOSTS || url.userInfo != null || url.port !in setOf(-1, 443)) {
                throw RootModuleException("download_origin_rejected")
            }
            val connection = url.openConnection() as HttpsURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("Accept", "application/octet-stream")
            try {
                if (connection.responseCode in setOf(301, 302, 303, 307, 308)) {
                    val location = connection.getHeaderField("Location") ?: throw RootModuleException("download_redirect_invalid")
                    url = URL(url, location)
                } else {
                    if (connection.responseCode != 200) throw RootModuleException("module_release_unavailable")
                    val length = connection.contentLengthLong
                    if (length > RootModuleVerifier.MAX_ARCHIVE_BYTES) throw RootModuleException("download_size_exceeded")
                    val file = File(stage, "download.zip")
                    val started = System.nanoTime()
                    connection.inputStream.use { source ->
                        file.outputStream().use { target ->
                            val bytes = ByteArray(32768)
                            var total = 0L
                            while (true) {
                                if (Thread.currentThread().isInterrupted) throw RootModuleException("operation_cancelled")
                                if (System.nanoTime() - started > 90_000_000_000L) throw RootModuleException("download_timeout")
                                val count = source.read(bytes)
                                if (count < 0) break
                                total += count
                                if (total > RootModuleVerifier.MAX_ARCHIVE_BYTES) throw RootModuleException("download_size_exceeded")
                                target.write(bytes, 0, count)
                                progress = if (length > 0) (total.toDouble() / length * 0.9).coerceIn(0.0, 0.9) else 0.0
                                onProgress(snapshot())
                            }
                        }
                    }
                    return file
                }
            } finally { connection.disconnect() }
        }
        throw RootModuleException("download_redirect_limit")
    }

    companion object {
        private const val ROOT = RootProcessRunner.ROOT
        private const val PREFS = "etonify_root_module"
        private val DOWNLOAD_HOSTS = setOf("github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com")
        fun enabled(context: Context): Boolean = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("enabled", false)
    }
}
