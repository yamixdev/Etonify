package com.etonify.meow_client.root

import android.content.Context
import android.os.Build
import android.os.Process
import android.system.Os
import android.system.OsConstants
import java.io.File
import java.util.Base64
import java.util.concurrent.atomic.AtomicBoolean

/** Migration only: never downloads, installs, enables or launches a runtime. */
class RootModuleManager(
    context: Context,
    trustedPublicKeyBase64: String,
    private val isRuntimeActive: () -> Boolean = { false },
    private val runner: RootProcessRunner = RootProcessRunner(),
    verifier: RootModuleVerifier? = null,
) {
    private val context = context.applicationContext
    private val prefs = this.context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val verifier = verifier ?: RootModuleVerifier(
        trustedPublicKeyBase64,
        if (Build.SUPPORTED_ABIS.contains("arm64-v8a")) "arm64-v8a" else "unsupported",
        Build.VERSION.SDK_INT,
        @Suppress("DEPRECATION") this.context.packageManager.getPackageInfo(this.context.packageName, 0).let {
            if (Build.VERSION.SDK_INT >= 28) it.longVersionCode else it.versionCode.toLong()
        },
    )
    private val busy = cleanupBusy
    private var rootAvailability = "unknown"
    private var reason: String? = null
    private var cached: RootModuleManifest? = null

    init {
        // Disable the obsolete preference without probing or requesting su.
        if (!prefs.edit().putBoolean("enabled", false).commit()) reason = "module_metadata_failed"
        val manifest = prefs.getString("manifest", null)
        val signature = prefs.getString("signature", null)
        if (manifest != null || signature != null) {
            try {
                if (manifest == null || signature == null) throw RootModuleException("module_metadata_missing")
                if (manifest.length > 90_000 || signature.length > 2048) throw RootModuleException("manifest_invalid")
                cached = this.verifier.verifyManifest(Base64.getDecoder().decode(manifest), Base64.getDecoder().decode(signature))
            } catch (error: RootModuleException) { reason = error.code
            } catch (_: Exception) { reason = "manifest_invalid" }
        }
    }

    fun snapshot(): Map<String, Any?> = mapOf(
        "rootAvailability" to rootAvailability,
        "moduleState" to if (reason != null) "failed" else if (cached != null) "ready" else "notInstalled",
        "moduleVersion" to cached?.moduleVersion,
        "enabled" to false, "busy" to busy.get(), "reason" to reason,
    )

    /** Only invoked after a UI confirmation. Any failure preserves module files and metadata. */
    fun remove(): Map<String, Any?> {
        if (!busy.compareAndSet(false, true)) return snapshot() + ("reason" to "operation_busy")
        try {
            // Orphan app-private downloads do not require root or a surviving
            // installation manifest. Never strand them behind a failed su step.
            cleanStaging()
            if (isRuntimeActive()) throw RootModuleException("runtime_busy")
            val module = cached ?: throw RootModuleException(reason ?: "module_metadata_missing")
            reason = null
            rootAvailability = RootCapabilityProbe { runner.execute("id -u") }.requestAuthorization()
            if (rootAvailability != "granted") throw RootModuleException(if (rootAvailability == "noSu") "su_not_found" else "root_denied")
            val version = "$ROOT/versions/v${module.versionCode}-${module.sha256}"
            val integrity = "set -eu; " +
                "test ! -L /data/adb; test \"\$(stat -c '%u' /data/adb)\" = 0; " +
                "case \"\$(stat -c '%a' /data/adb)\" in 700|711|755) ;; *) exit 1;; esac; " +
                "test ! -L $ROOT; test \"\$(stat -c '%u:%g:%a' $ROOT)\" = '0:0:700'; " +
                "test ! -L $ROOT/versions; test \"\$(stat -c '%u:%g:%a' $ROOT/versions)\" = '0:0:700'; " +
                "test ! -L $version; test \"\$(stat -c '%u:%g:%a' $version)\" = '0:0:700'; " +
                "test -L $ROOT/current; test \"\$(readlink -f $ROOT/current)\" = '$version'; " +
                "test ! -L $version/etonify-root; test -f $version/etonify-root; " +
                "test \"\$(stat -c '%u:%g:%a' $version/etonify-root)\" = '0:0:700'; " +
                "test \"\$(stat -c '%s' $version/etonify-root)\" = '${module.size}'; " +
                "test \"\$(sha256sum $version/etonify-root | cut -d ' ' -f 1)\" = '${module.sha256}'; " +
                "test -z \"\$(find $ROOT -xdev ! -uid 0 -print -quit)\"; " +
                "test -z \"\$(find $ROOT -xdev -type l ! -path $ROOT/current -print -quit)\"; " +
                "if test -e $ROOT/runtime; then test ! -L $ROOT/runtime; test \"\$(stat -c '%u:%g:%a' $ROOT/runtime)\" = '0:0:700'; fi"
            if (runner.execute(integrity).exitCode != 0) throw RootModuleException("module_integrity_failed")
            // A failed journal/network cleanup must never be followed by rm.
            requireCleanupSuccess(runner.execute(
                "exec timeout -s KILL 15 $version/etonify-root cleanup --work-dir $ROOT/runtime", timeoutMs = 20_000))
            if (runner.execute("$integrity; rm -rf -- $ROOT").exitCode != 0) throw RootModuleException("module_remove_failed")
            if (!prefs.edit().clear().putBoolean("enabled", false).commit()) throw RootModuleException("module_metadata_failed")
            cached = null
        } catch (error: RootModuleException) { reason = error.code
        } catch (_: Exception) { reason = "root_operation_failed"
        } finally { busy.set(false) }
        return snapshot()
    }

    private fun cleanStaging() {
        val cache = context.cacheDir.canonicalFile
        val ownedName = Regex("root-module-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
        val deadline = System.nanoTime() + java.util.concurrent.TimeUnit.SECONDS.toNanos(2)
        var entries = 0
        fun budget() {
            if (++entries > 256 || System.nanoTime() > deadline) throw RootModuleException("module_cache_cleanup_failed")
        }
        java.nio.file.Files.newDirectoryStream(cache.toPath(), "root-module-*").use { stages ->
        for (stage in stages) {
            budget()
            val directory = stage.toFile()
            if (!ownedName.matches(directory.name)) continue
            val paths = mutableListOf<File>()
            val pending = java.util.ArrayDeque<Pair<File, Int>>()
            pending.add(directory to 0)
            while (pending.isNotEmpty()) {
                budget()
                val (file, depth) = pending.removeLast()
                if (depth > 6) throw RootModuleException("module_cache_cleanup_failed")
                val stat = Os.lstat(file.absolutePath)
                if (stat.st_uid != Process.myUid() || OsConstants.S_ISLNK(stat.st_mode)) throw RootModuleException("module_cache_cleanup_failed")
                if (OsConstants.S_ISDIR(stat.st_mode)) {
                    java.nio.file.Files.newDirectoryStream(file.toPath()).use { children ->
                        for (child in children) {
                            budget()
                            pending.add(child.toFile() to depth + 1)
                        }
                    }
                }
                paths.add(file)
            }
            if (directory.parentFile?.canonicalFile != cache || directory.canonicalFile != directory.absoluteFile)
                throw RootModuleException("module_cache_cleanup_failed")
            // Validate the bounded tree before deleting anything. Reverse parent
            // visitation order removes children first without recursive calls.
            for (file in paths.asReversed()) {
                val stat = Os.lstat(file.absolutePath)
                if (stat.st_uid != Process.myUid() || OsConstants.S_ISLNK(stat.st_mode) || !file.delete())
                    throw RootModuleException("module_cache_cleanup_failed")
            }
        }
        }
    }

    companion object {
        private val cleanupBusy = AtomicBoolean(false)
        private const val ROOT = RootProcessRunner.ROOT
        private const val PREFS = "etonify_root_module"
    }
}

internal fun requireCleanupSuccess(result: RootCommandResult) {
    if (result.exitCode == 0) return
    val reason = runCatching {
        val response = org.json.JSONObject(result.stdout)
        if (response.opt("protocol") == 1 && response.opt("ready") == false) response.optString("reason") else null
    }.getOrNull()
    throw RootModuleException(when (reason) {
        "already_running" -> "runtime_busy"
        "work_dir_denied", "lock_denied", "journal_denied", "cleanup_failed", "root_required" -> "module_cleanup_$reason"
        else -> "module_cleanup_failed"
    })
}
