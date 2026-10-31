package com.etonify.meow_client.root

import org.json.JSONObject

internal data class RootRuntimeReady(val ready: Boolean, val failureCode: String?)

internal object RootRuntimeHandshake {
    private val safeReasons = setOf(
        "dns_bootstrap_unsupported", "dns_local_unsupported", "config_invalid", "config_too_large",
        "config_frame_incomplete", "config_read_failed", "package_split_unsupported", "tun_required",
        "outbound_unsupported", "environment_expansion_denied", "file_access_denied", "rule_file_denied",
        "rule_file_unsupported", "app_directory_denied", "work_dir_denied", "lock_denied", "already_running",
        "journal_denied", "cleanup_failed", "iptables_unavailable", "resource_check_failed", "resource_conflict",
        "arguments_denied", "root_required", "build_identity_missing", "android_required", "process_group_failed",
        "rpc_denied", "runtime_start_failed", "socket_directory_denied", "socket_permissions_failed", "ready_write_failed",
    )
    fun parse(line: String): RootRuntimeReady {
        if (line.toByteArray(Charsets.UTF_8).size > 4096) return RootRuntimeReady(false, "runtime_start_failed")
        return try {
            val json = JSONObject(line)
            if (json.opt("protocol") != 1) return RootRuntimeReady(false, "runtime_start_failed")
            if (json.opt("ready") == true) return RootRuntimeReady(true, null)
            val reason = json.opt("reason") as? String
            RootRuntimeReady(false, when {
                reason == "config_unsupported" -> "root_config_unsupported"
                reason != null && reason in safeReasons -> reason
                else -> "runtime_start_failed"
            })
        } catch (_: Exception) { RootRuntimeReady(false, "runtime_start_failed") }
    }
}
