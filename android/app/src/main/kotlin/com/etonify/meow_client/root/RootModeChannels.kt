package com.etonify.meow_client.root

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.etonify.meow_client.BuildConfig
import com.etonify.meow_client.singbox.MeowBoxService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** One manager shared by settings and runtime; no root query during ordinary startup. */
internal object RootModeBridge {
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor { task ->
        Thread(task, "EtonifyRootModule").apply { isDaemon = true }
    }
    private val listeners = CopyOnWriteArraySet<(Map<String, Any?>) -> Unit>()
    private val operationPending = AtomicBoolean()
    @Volatile private var worker: Thread? = null
    @Volatile private var instance: RootModuleManager? = null
    private var lastProgressAt = 0L

    @Synchronized fun manager(context: Context): RootModuleManager = instance ?: RootModuleManager(
        context.applicationContext,
        BuildConfig.ROOT_MODULE_PUBLIC_KEY,
        isRuntimeActive = { MeowBoxService.hasActiveRuntimeOwner() },
    ).also { instance = it }

    fun addListener(listener: (Map<String, Any?>) -> Unit) { listeners.add(listener) }
    fun removeListener(listener: (Map<String, Any?>) -> Unit) { listeners.remove(listener) }

    fun emit(value: Map<String, Any?>, progress: Boolean = false) {
        val now = android.os.SystemClock.elapsedRealtime()
        synchronized(this) {
            if (progress && now - lastProgressAt < 150L) return
            lastProgressAt = now
        }
        main.post { for (listener in listeners) listener(value) }
    }

    fun invoke(context: Context, method: String, enabled: Boolean?, result: MethodChannel.Result) {
        if (method == "cancel") {
            worker?.interrupt()
            // The active operation completes with operation_cancelled. Do not
            // cancel its Future: that would strand the original Dart caller.
            result.success(instance?.snapshot() ?: unavailable("operation_cancelled"))
            return
        }
        if (!operationPending.compareAndSet(false, true)) {
            result.success((instance?.snapshot() ?: unavailable("operation_busy")) + ("reason" to "operation_busy"))
            return
        }
        executor.execute {
            worker = Thread.currentThread()
            val snapshot = try {
                val manager = manager(context)
                when (method) {
                    "snapshot" -> manager.snapshot()
                    "requestAuthorization" -> manager.requestAuthorization()
                    "install" -> manager.install { emit(it, progress = true) }
                    "remove" -> manager.remove()
                    "checkUpdate" -> manager.checkUpdate()
                    "setEnabled" -> if (enabled != null) manager.setEnabled(enabled)
                        else manager.snapshot() + ("reason" to "invalid_arguments")
                    else -> manager.snapshot() + ("reason" to "unsupported_operation")
                }
            } catch (_: Exception) { unavailable("root_operation_failed")
            } finally {
                worker = null
                Thread.interrupted()
                operationPending.set(false)
            }
            emit(snapshot)
            main.post { result.success(snapshot) }
        }
    }

    private fun unavailable(reason: String): Map<String, Any?> = mapOf(
        "rootAvailability" to "unknown", "moduleState" to "notInstalled",
        "enabled" to false, "busy" to false, "reason" to reason,
    )
}

internal class RootModeChannels(context: Context, messenger: BinaryMessenger) : AutoCloseable {
    private val method = MethodChannel(messenger, "meow_client/root_mode")
    private val events = EventChannel(messenger, "meow_client/root_mode_events")
    private var sink: EventChannel.EventSink? = null
    private val listener: (Map<String, Any?>) -> Unit = { sink?.success(it) }

    init {
        method.setMethodCallHandler { call, result ->
            if (call.method !in setOf("snapshot", "requestAuthorization", "install", "remove", "checkUpdate", "setEnabled", "cancel")) {
                result.notImplemented()
            } else RootModeBridge.invoke(context.applicationContext, call.method, (call.arguments as? Map<*, *>)?.get("enabled") as? Boolean, result)
        }
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                sink = eventSink
                RootModeBridge.addListener(listener)
            }
            override fun onCancel(arguments: Any?) {
                sink = null
                RootModeBridge.removeListener(listener)
            }
        })
    }

    override fun close() {
        sink = null
        RootModeBridge.removeListener(listener)
        method.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}
