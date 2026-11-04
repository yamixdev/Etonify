package com.etonify.meow_client.root

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.etonify.meow_client.BuildConfig
import com.etonify.meow_client.singbox.MeowBoxService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Temporary legacy cleanup channel. No install, update, authorize or enable API. */
internal class RootModeChannels(context: Context, messenger: BinaryMessenger) : AutoCloseable {
    private val method = MethodChannel(messenger, "meow_client/root_mode")
    private val events = EventChannel(messenger, "meow_client/root_mode_events")
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor { r -> Thread(r, "LegacyModuleCleanup").apply { isDaemon = true } }
    private val pending = AtomicBoolean()
    private val manager = RootModuleManager(context, BuildConfig.ROOT_MODULE_PUBLIC_KEY,
        isRuntimeActive = { MeowBoxService.hasActiveRuntimeOwner() })
    @Volatile private var closed = false
    private var sink: EventChannel.EventSink? = null
    init {
        method.setMethodCallHandler { call, result ->
            if (call.method !in setOf("snapshot", "remove")) result.notImplemented()
            else if (!pending.compareAndSet(false, true)) result.success(manager.snapshot() + ("reason" to "operation_busy"))
            else executor.execute {
                val snapshot = try {
                    if (call.method == "snapshot") manager.snapshot() else manager.remove()
                } finally { pending.set(false) }
                main.post { result.success(snapshot); if (!closed) sink?.success(snapshot) }
            }
        }
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) { sink = eventSink }
            override fun onCancel(arguments: Any?) { sink = null }
        })
    }
    override fun close() {
        closed = true
        sink = null
        method.setMethodCallHandler(null)
        events.setStreamHandler(null)
        // Do not interrupt an already-confirmed network cleanup midway through.
        executor.shutdown()
    }
}
