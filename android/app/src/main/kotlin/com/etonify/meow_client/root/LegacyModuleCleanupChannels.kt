package com.etonify.meow_client.root

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.etonify.meow_client.BuildConfig
import com.etonify.meow_client.singbox.MeowBoxService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Temporary legacy cleanup channel. No install, update, authorize or enable API. */
internal class LegacyModuleCleanupChannels(context: Context, messenger: BinaryMessenger) : AutoCloseable {
    private val method = MethodChannel(messenger, "meow_client/legacy_module_cleanup")
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor { r -> Thread(r, "LegacyModuleCleanup").apply { isDaemon = true } }
    private val pending = AtomicBoolean()
    private val manager by lazy {
        RootModuleManager(context, BuildConfig.ROOT_MODULE_PUBLIC_KEY,
            isRuntimeActive = { MeowBoxService.hasActiveRuntimeOwner() })
    }
    @Volatile private var closed = false
    init {
        // Run bounded app-private cleanup even if Flutter never asks for a
        // migration snapshot. No su probe is performed by initialization.
        executor.execute { manager.snapshot() }
        method.setMethodCallHandler { call, result ->
            if (call.method !in setOf("snapshot", "acknowledgePrompt", "remove")) result.notImplemented()
            else if (!pending.compareAndSet(false, true)) result.success(mapOf("enabled" to false, "busy" to true, "reason" to "operation_busy"))
            else executor.execute {
                val snapshot = try {
                    when (call.method) {
                        "snapshot" -> manager.snapshot()
                        "acknowledgePrompt" -> manager.acknowledgePrompt()
                        else -> manager.remove()
                    }
                } finally { pending.set(false) }
                main.post { if (!closed) result.success(snapshot) }
            }
        }
    }
    override fun close() {
        closed = true
        method.setMethodCallHandler(null)
        // Do not interrupt an already-confirmed network cleanup midway through.
        executor.shutdown()
    }
}
