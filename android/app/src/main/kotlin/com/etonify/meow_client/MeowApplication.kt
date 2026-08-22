package com.etonify.meow_client

import android.app.Application
import android.content.Context
import android.content.pm.ApplicationInfo
import android.net.ConnectivityManager
import android.os.Build
import com.etonify.meow_client.singbox.MeowDiagnostics
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.SetupOptions
import java.io.File
import kotlin.system.exitProcess

class MeowApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        application = this
        runtimeFlagsPrefs.edit().remove(LEGACY_FLAG_PERFORMANCE_MODE).apply()
        installUncaughtExceptionLogger()
        val processName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Application.getProcessName()
        } else {
            applicationInfo.processName
        }.orEmpty()
        // Legacy native Happ crypt5 used an isolated process:
        // if (!processName.endsWith(":happ_crypto5_isolated")) {
        //     MeowDiagnostics.pruneLegacyRuntimeFiles()
        // }
        // That bridge is excluded from build; the pure Dart crypt5 path has no extra process.
        MeowDiagnostics.pruneLegacyRuntimeFiles()
        MeowDiagnostics.log(
            "Application",
            "onCreate pid=${android.os.Process.myPid()} process=$processName",
        )
    }

    companion object {
        data class ServiceState(
            val pid: Int,
            val mode: String,
            val updatedAtMillis: Long,
        )

        data class RuntimeIntentState(
            val pid: Int,
            val mode: String,
            val reason: String,
            val updatedAtMillis: Long,
        )

        private const val RUNTIME_FLAGS_PREF = "meow_runtime_flags"
        private const val FLAG_WAKE_LOCK = "wake_lock_enabled"
        private const val FLAG_HEARTBEAT = "network_heartbeat_enabled"
        private const val FLAG_HEARTBEAT_INTERVAL_SECONDS = "network_heartbeat_interval_seconds"
        private const val LEGACY_FLAG_PERFORMANCE_MODE = "performance_mode"
        private const val FLAG_MEMORY_LIMIT_ENABLED = "memory_limit_enabled"
        @Volatile
        private var uncaughtExceptionLoggerInstalled = false

        lateinit var application: MeowApplication
        @Volatile
        private var libboxReady: Boolean = false
        val connectivity: ConnectivityManager
            get() = application.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val configFile: File
            get() = File(application.filesDir, "singbox-config.json")
        val serviceStateFile: File
            get() = File(application.filesDir, "singbox-service-state.txt")
        val runtimeIntentFile: File
            get() = File(application.filesDir, "singbox-runtime-intent.txt")

        private val runtimeFlagsPrefs
            get() = application.getSharedPreferences(
                RUNTIME_FLAGS_PREF,
                Context.MODE_PRIVATE,
            )

        var wakeLockEnabled: Boolean
            get() = runtimeFlagsPrefs.getBoolean(FLAG_WAKE_LOCK, false)
            set(value) {
                runtimeFlagsPrefs.edit().putBoolean(FLAG_WAKE_LOCK, value).apply()
            }

        var networkHeartbeatEnabled: Boolean
            get() = runtimeFlagsPrefs.getBoolean(FLAG_HEARTBEAT, true)
            set(value) {
                runtimeFlagsPrefs.edit().putBoolean(FLAG_HEARTBEAT, value).apply()
            }

        var networkHeartbeatIntervalSeconds: Long
            get() = runtimeFlagsPrefs
                .getLong(FLAG_HEARTBEAT_INTERVAL_SECONDS, 180L)
                .coerceIn(15L, 300L)
            set(value) {
                runtimeFlagsPrefs.edit()
                    .putLong(FLAG_HEARTBEAT_INTERVAL_SECONDS, value.coerceIn(15L, 300L))
                    .apply()
            }

        var memoryLimitEnabled: Boolean
            get() = runtimeFlagsPrefs.getBoolean(FLAG_MEMORY_LIMIT_ENABLED, true)
            set(value) {
                runtimeFlagsPrefs.edit()
                    .putBoolean(FLAG_MEMORY_LIMIT_ENABLED, value)
                    .apply()
            }

        private fun installUncaughtExceptionLogger() {
            if (uncaughtExceptionLoggerInstalled) return
            synchronized(this) {
                if (uncaughtExceptionLoggerInstalled) return
                val previous = Thread.getDefaultUncaughtExceptionHandler()
                Thread.setDefaultUncaughtExceptionHandler { thread, error ->
                    runCatching {
                        MeowDiagnostics.log(
                            "UncaughtException",
                            "thread=${thread.name} pid=${android.os.Process.myPid()}",
                            error,
                        )
                    }
                    if (previous != null) {
                        previous.uncaughtException(thread, error)
                    } else {
                        android.os.Process.killProcess(android.os.Process.myPid())
                        exitProcess(10)
                    }
                }
                uncaughtExceptionLoggerInstalled = true
            }
        }

        fun ensureLibboxSetup() {
            if (libboxReady) {
                return
            }
            synchronized(this) {
                if (libboxReady) {
                    return
                }
                val app = application
                MeowDiagnostics.log("Application", "ensureLibboxSetup begin pid=${android.os.Process.myPid()}")
                MeowDiagnostics.log("Application", "ensureLibboxSetup skip Libbox.setLocale")
                val baseDir = File(app.filesDir, "singbox-base").apply { mkdirs() }
                val workingDir = File(app.getExternalFilesDir(null) ?: app.filesDir, "singbox-work").apply { mkdirs() }
                val tempDir = File(app.cacheDir, "singbox-tmp").apply { mkdirs() }
                val memoryLimitFlag = memoryLimitEnabled
                val setupOptions = SetupOptions().apply {
                    basePath = baseDir.absolutePath
                    workingPath = workingDir.absolutePath
                    tempPath = tempDir.absolutePath
                    logMaxLines = 800
                    debug = (app.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
                }
                Libbox.setup(setupOptions)
                Libbox.setMemoryLimit(memoryLimitFlag)
                libboxReady = true
                MeowDiagnostics.log(
                    "Application",
                    "ensureLibboxSetup done pid=${android.os.Process.myPid()} memoryLimit=${if (memoryLimitFlag) "enabled" else "disabled"}",
                )
            }
        }

        fun writeServiceState(mode: String) {
            val pid = android.os.Process.myPid()
            val updatedAtMillis = System.currentTimeMillis()
            serviceStateFile.parentFile?.mkdirs()
            serviceStateFile.writeText(
                buildString {
                    append("pid=")
                    append(pid)
                    append('\n')
                    append("mode=")
                    append(mode)
                    append('\n')
                    append("updatedAtMillis=")
                    append(updatedAtMillis)
                    append('\n')
                },
            )
            MeowDiagnostics.log(
                "Application",
                "writeServiceState pid=$pid mode=$mode updatedAtMillis=$updatedAtMillis",
            )
        }

        fun writeRuntimeIntent(mode: String, reason: String) {
            val pid = android.os.Process.myPid()
            val updatedAtMillis = System.currentTimeMillis()
            runtimeIntentFile.parentFile?.mkdirs()
            runtimeIntentFile.writeText(
                buildString {
                    append("pid=")
                    append(pid)
                    append('\n')
                    append("mode=")
                    append(mode)
                    append('\n')
                    append("reason=")
                    append(reason)
                    append('\n')
                    append("updatedAtMillis=")
                    append(updatedAtMillis)
                    append('\n')
                },
            )
            MeowDiagnostics.log(
                "Application",
                "writeRuntimeIntent pid=$pid mode=$mode reason=$reason updatedAtMillis=$updatedAtMillis",
            )
        }

        fun clearServiceState() {
            val deleted = runCatching {
                !serviceStateFile.exists() || serviceStateFile.delete()
            }.getOrDefault(false)
            MeowDiagnostics.log("Application", "clearServiceState deleted=$deleted")
        }

        fun clearRuntimeIntent() {
            val deleted = runCatching {
                !runtimeIntentFile.exists() || runtimeIntentFile.delete()
            }.getOrDefault(false)
            MeowDiagnostics.log("Application", "clearRuntimeIntent deleted=$deleted")
        }

        fun readServiceState(): ServiceState? {
            return runCatching {
                if (!serviceStateFile.exists()) {
                    return null
                }
                var pid = -1
                var mode = ""
                var updatedAtMillis = 0L
                for (line in serviceStateFile.readLines()) {
                    val index = line.indexOf('=')
                    if (index <= 0) continue
                    val key = line.substring(0, index)
                    val value = line.substring(index + 1)
                    when (key) {
                        "pid" -> pid = value.toIntOrNull() ?: -1
                        "mode" -> mode = value
                        "updatedAtMillis" -> updatedAtMillis = value.toLongOrNull() ?: 0L
                    }
                }
                if (pid <= 0 || mode.isBlank()) {
                    null
                } else {
                    ServiceState(pid = pid, mode = mode, updatedAtMillis = updatedAtMillis)
                }
            }.getOrNull()
        }

        fun readRuntimeIntent(): RuntimeIntentState? {
            return runCatching {
                if (!runtimeIntentFile.exists()) {
                    return null
                }
                var pid = -1
                var mode = ""
                var reason = ""
                var updatedAtMillis = 0L
                for (line in runtimeIntentFile.readLines()) {
                    val index = line.indexOf('=')
                    if (index <= 0) continue
                    val key = line.substring(0, index)
                    val value = line.substring(index + 1)
                    when (key) {
                        "pid" -> pid = value.toIntOrNull() ?: -1
                        "mode" -> mode = value
                        "reason" -> reason = value
                        "updatedAtMillis" -> updatedAtMillis = value.toLongOrNull() ?: 0L
                    }
                }
                if (pid <= 0 || mode.isBlank()) {
                    null
                } else {
                    RuntimeIntentState(
                        pid = pid,
                        mode = mode,
                        reason = reason,
                        updatedAtMillis = updatedAtMillis,
                    )
                }
            }.getOrNull()
        }

        fun describeRecordedServiceState(): String {
            val state = readServiceState()
            if (state == null) {
                return "state=missing"
            }
            val cmdline = runCatching {
                File("/proc/${state.pid}/cmdline")
                    .readText()
                    .replace('\u0000', ' ')
                    .trim()
            }.getOrDefault("")
            val alive = cmdline.contains(application.packageName)
            return buildString {
                append("statePid=")
                append(state.pid)
                append(" mode=")
                append(state.mode)
                append(" updatedAtMillis=")
                append(state.updatedAtMillis)
                append(" alive=")
                append(alive)
                if (cmdline.isNotEmpty()) {
                    append(" cmdline=")
                    append(cmdline)
                }
            }
        }

        fun describeRuntimeIntent(): String {
            val state = readRuntimeIntent()
            if (state == null) {
                return "intent=missing"
            }
            val ageMs = System.currentTimeMillis() - state.updatedAtMillis
            return buildString {
                append("intentPid=")
                append(state.pid)
                append(" mode=")
                append(state.mode)
                append(" reason=")
                append(state.reason)
                append(" updatedAtMillis=")
                append(state.updatedAtMillis)
                append(" ageMs=")
                append(ageMs)
                append(" fresh=")
                append(ageMs >= 0L)
            }
        }

        fun isRecordedServiceAlive(mode: String? = null): Boolean {
            val state = readServiceState() ?: return false
            if (mode != null && state.mode != mode) {
                return false
            }
            val cmdline = runCatching {
                File("/proc/${state.pid}/cmdline")
                    .readText()
                    .replace('\u0000', ' ')
                    .trim()
            }.getOrDefault("")
            return cmdline.contains(application.packageName)
        }

        fun isRuntimeIntentFresh(mode: String? = null): Boolean {
            val state = readRuntimeIntent() ?: return false
            if (mode != null && state.mode != mode) {
                return false
            }
            // The file represents the user's desired runtime state, not a
            // short retry token. It remains valid until an explicit stop
            // clears it, allowing START_STICKY to recover after an overnight
            // low-memory or OEM process kill.
            return System.currentTimeMillis() >= state.updatedAtMillis
        }
    }
}
