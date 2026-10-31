package com.etonify.meow_client.root

import java.util.UUID
import org.json.JSONObject

internal class RootModuleInstaller(private val runner: RootProcessRunner) {
    fun install(module: VerifiedRootModule, commitMetadata: () -> Unit) {
        val manifest = module.manifest
        val token = UUID.randomUUID().toString().replace("-", "")
        val stage = "$ROOT/staging-$token"
        val versionDirectory = "v${manifest.versionCode}-${manifest.sha256}"
        val target = "$ROOT/versions/$versionDirectory"
        var activationAttempted = false
        var committed = false
        try {
            val prepare = "set -eu; umask 077; test ! -L $ROOT; mkdir -p $ROOT/versions; " +
                "chown 0:0 $ROOT $ROOT/versions; chmod 700 $ROOT $ROOT/versions; " +
                downgradeGuard(manifest.versionCode) +
                "mkdir $stage; chown 0:0 $stage; chmod 700 $stage; cat > $stage/etonify-root; " +
                "chown 0:0 $stage/etonify-root; chmod 600 $stage/etonify-root; " +
                hashGuard("$stage/etonify-root", manifest.sha256) +
                "chmod 700 $stage/etonify-root; exec timeout -s KILL 10 $stage/etonify-root version"
            val health = module.binary.inputStream().use { runner.executeStreaming(prepare, it, 30_000) }
            if (health.exitCode != 0) throw RootModuleException("module_healthcheck_failed")
            validateHealth(health.stdout, manifest)
            val cleanup = runner.execute(
                "set -eu; " + hashGuard("$stage/etonify-root", manifest.sha256) +
                    "exec timeout -s KILL 15 $stage/etonify-root cleanup --work-dir $ROOT/runtime",
                timeoutMs = 20_000,
            )
            requireCleanupSuccess(cleanup)
            val activate = "set -eu; umask 077; " + downgradeGuard(manifest.versionCode) +
                hashGuard("$stage/etonify-root", manifest.sha256) +
                "if test -e $target; then test ! -L $target; " + hashGuard("$target/etonify-root", manifest.sha256) +
                "rm -rf $stage; else mv $stage $target; fi; " +
                "old=\$(readlink $ROOT/current 2>/dev/null || true); printf '%s' \"\$old\" > $ROOT/rollback-$token; " +
                "if test -f $ROOT/version-code; then cat $ROOT/version-code > $ROOT/rollback-version-$token; else echo 0 > $ROOT/rollback-version-$token; fi; " +
                "printf '%s' \"\$old\" > $ROOT/previous; " +
                "ln -s versions/$versionDirectory $ROOT/current-$token; " +
                "echo ${manifest.versionCode} > $ROOT/version-code-$token; " +
                "mv -f $ROOT/version-code-$token $ROOT/version-code; " +
                "mv -Tf $ROOT/current-$token $ROOT/current"
            activationAttempted = true
            if (runner.execute(activate).exitCode != 0) throw RootModuleException("module_activation_failed")
            commitMetadata()
            committed = true
        } finally {
            val restoreInterrupt = Thread.interrupted()
            try {
                if (activationAttempted && !committed) {
                    val rollback = "set -eu; " +
                        "if test -f $ROOT/rollback-$token; then " +
                        "old=\$(cat $ROOT/rollback-$token); " +
                        "if test -n \"\$old\"; then " +
                        "case \"\$old\" in versions/v*) ;; *) exit 1;; esac; " +
                        "ln -s \"\$old\" $ROOT/rollback-link-$token; mv -Tf $ROOT/rollback-link-$token $ROOT/current; " +
                        "else rm -f $ROOT/current; fi; " +
                        "mv -f $ROOT/rollback-version-$token $ROOT/version-code; fi"
                    val result = runCatching { runner.execute(rollback, timeoutMs = 5_000) }.getOrNull()
                    if (result?.exitCode != 0) throw RootModuleException("module_rollback_failed")
                }
            } finally {
                runner.runCatching {
                    execute("test ! -L $stage && rm -rf $stage; rm -f $ROOT/rollback-$token $ROOT/rollback-version-$token $ROOT/current-$token $ROOT/version-code-$token", timeoutMs = 5_000)
                }
                if (restoreInterrupt) Thread.currentThread().interrupt()
            }
        }
    }

    private fun downgradeGuard(versionCode: Int): String =
        "if test -f $ROOT/version-code; then old=\$(cat $ROOT/version-code); " +
            "case \"\$old\" in ''|*[!0-9]*) exit 1;; esac; test \"\$old\" -le $versionCode; fi; "

    private fun hashGuard(path: String, hash: String): String =
        "test \"\$(sha256sum $path | cut -d ' ' -f 1)\" = '$hash'; "

    private fun validateHealth(output: String, manifest: RootModuleManifest) {
        try {
            val json = JSONObject(output)
            if (json.getInt("protocol") != 1 || json.getString("coreCommit") != manifest.coreCommit ||
                json.getString("abi") != manifest.abi || json.getString("moduleVersion") != manifest.moduleVersion) {
                throw RootModuleException("module_healthcheck_failed")
            }
        } catch (_: Exception) { throw RootModuleException("module_healthcheck_failed") }
    }

    companion object { private const val ROOT = RootProcessRunner.ROOT }
}

internal fun requireCleanupSuccess(result: RootCommandResult) {
    if (result.exitCode == 0) return
    val reason = runCatching { JSONObject(result.stdout).optString("reason") }.getOrNull()
    throw RootModuleException(if (reason == "already_running") "runtime_busy" else "module_cleanup_failed")
}
