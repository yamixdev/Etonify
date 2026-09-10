package com.etonify.meow_client

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.net.ConnectivityManager
import android.os.Handler
import android.os.Looper
import android.util.AtomicFile
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import java.net.UnknownHostException
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import javax.net.ssl.SSLException

/** Download-only background work. Never opens Hive or starts/reloads the VPN.
 * The foreground client validates staged content before committing a profile.
 */
object SubscriptionRefreshJobs {
    private const val JOB_ID = 0x455452
    private const val PERIOD = 60 * 60 * 1000L
    private const val MAX_BODY = 16 * 1024 * 1024
    @Volatile var foreground = false
    private val io = Executors.newSingleThreadExecutor()
    private fun root(context: Context) = File(context.noBackupFilesDir, "subscription_refresh").apply { mkdirs() }
    private fun key(context: Context) = SecretKeySpec(
        Base64.decode(SecureHiveKeyProvider.getOrCreateDataKey(context), Base64.NO_WRAP), "AES")
    private fun file(context: Context, name: String) = File(root(context), name)
    private val subscriptionResponseHeaders = setOf(
        "profile-title",
        "content-disposition",
        "subscription-userinfo",
        "happ-crypto-link",
        "support-url",
        "profile-web-page-url",
        "new-url",
        "profile-update-interval",
        "per-app-proxy-mode",
        "per-app-proxy-list",
    )
    private fun resultName(id: String) = MessageDigest.getInstance("SHA-256")
        .digest(id.toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) } + ".result"

    // All control-plane operations are short and serialized with result commits.
    @Synchronized private fun read(context: Context, name: String): JSONObject? {
        val target = file(context, name)
        if (!target.exists()) return null
        val bytes = AtomicFile(target).readFully()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(context), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        return JSONObject(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
    }

    @Synchronized private fun write(context: Context, name: String, value: JSONObject) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(context))
        val bytes = cipher.iv + cipher.doFinal(value.toString().toByteArray(Charsets.UTF_8))
        val target = AtomicFile(file(context, name))
        val output = target.startWrite()
        try { output.write(bytes); target.finishWrite(output) }
        catch (e: Exception) { target.failWrite(output); throw e }
    }

    private fun plans(context: Context): List<JSONObject> {
        val array = read(context, "plan")?.optJSONArray("profiles") ?: JSONArray()
        return (0 until array.length()).map { array.getJSONObject(it) }
    }

    @Synchronized private fun configure(context: Context, value: JSONObject) {
        write(context, "plan", value)
        val profiles = plans(context)
        val keep = profiles.map { resultName(it.getString("id")) }.toSet()
        root(context).listFiles()?.filter { it.name.endsWith(".result") && it.name !in keep }
            ?.forEach { AtomicFile(it).delete() }
        val scheduler = context.getSystemService(JobScheduler::class.java)
        if (profiles.isEmpty()) { scheduler.cancel(JOB_ID); return }
        if (scheduler.getPendingJob(JOB_ID) == null) {
            val job = JobInfo.Builder(JOB_ID, ComponentName(context, SubscriptionRefreshJob::class.java))
                .setPeriodic(PERIOD)
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setRequiresBatteryNotLow(true)
                .setPersisted(true)
                .build()
            check(scheduler.schedule(job) == JobScheduler.RESULT_SUCCESS) { "Background scheduling failed" }
        }
    }

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "meow_client/subscription_refresh").setMethodCallHandler { call, result ->
            io.execute {
                runCatching {
                    when (call.method) {
                        "configure" -> { configure(context, JSONObject(call.arguments as String)); null }
                        "pending" -> JSONArray(plans(context).mapNotNull { p ->
                            read(context, resultName(p.getString("id")))?.let { r ->
                                JSONObject().put("id", r.getString("id")).put("token", r.getString("token"))
                            }
                        }).toString()
                        "read" -> read(context, resultName(call.arguments as String))?.toString()
                        "ack" -> {
                            val args = JSONObject(call.arguments as String)
                            synchronized(this) {
                                val name = resultName(args.getString("id"))
                                if (read(context, name)?.optString("token") == args.getString("token"))
                                    AtomicFile(file(context, name)).delete()
                            }
                            null
                        }
                        else -> throw IllegalArgumentException("Unknown refresh operation")
                    }
                }.onSuccess { value -> Handler(Looper.getMainLooper()).post { result.success(value) } }
                 .onFailure { Handler(Looper.getMainLooper()).post {
                     result.error("subscription_background_failed", "Background update storage or scheduling failed", null)
                 } }
            }
        }
    }

    fun run(context: Context, cancelled: AtomicBoolean, setConnection: (HttpURLConnection?) -> Unit) {
        val deadline = android.os.SystemClock.elapsedRealtime() + 120_000L
        for (profile in plans(context).sortedBy { it.optLong("dueAt") }) {
            if (foreground || cancelled.get() || android.os.SystemClock.elapsedRealtime() >= deadline) return
            val id = profile.getString("id")
            val token = profile.getString("token")
            if (System.currentTimeMillis() < profile.getLong("dueAt")) continue
            val previous = read(context, resultName(id))
            // One attempt per plan revision, including failures. No retry loop.
            // Opening the client acknowledges the result and creates a new plan.
            if (previous?.optString("token") == token) continue
            val result = JSONObject().put("id", id).put("token", token)
                .put("time", System.currentTimeMillis())
            try {
                val cm = context.getSystemService(ConnectivityManager::class.java)
                if (cm.activeNetwork == null) {
                    result.put("failure", "offline")
                } else {
                    fetch(profile, result, cancelled, deadline, setConnection)
                }
            } catch (e: Exception) {
                if (cancelled.get() || foreground) return
                result.put("failure", when (e) {
                    is SocketTimeoutException -> "timeout"
                    is UnknownHostException -> "dns"
                    is SSLException -> "tls"
                    is IllegalArgumentException -> "unsafeRedirect"
                    else -> "connection"
                })
            } finally { setConnection(null) }
            synchronized(this) {
                if (cancelled.get() || foreground) return
                // Bound encrypted staging on disk, even with many profiles.
                val used = root(context).listFiles()?.sumOf { it.length() } ?: 0L
                val resultBytes = result.toString().toByteArray(Charsets.UTF_8).size
                if (used + resultBytes > 64L * 1024 * 1024) return
                if (plans(context).any {
                        it.optString("id") == id && it.optString("token") == token
                    }
                ) {
                    write(context, resultName(id), result)
                }
            }
        }
    }

    private fun fetch(profile: JSONObject, result: JSONObject, cancelled: AtomicBoolean,
        deadline: Long, setConnection: (HttpURLConnection?) -> Unit) {
        var url = URL(profile.getString("url"))
        var headers = profile.getJSONObject("headers")
        for (redirect in 0..5) {
            require(url.protocol == "https") { "HTTPS required" }
            val connection = url.openConnection() as HttpURLConnection
            setConnection(connection)
            try {
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 15_000
                connection.readTimeout = 15_000
                connection.useCaches = false
                headers.keys().forEach { name ->
                    val value = headers.getString(name)
                    require(!name.contains('\r') && !name.contains('\n') && !value.contains('\r') && !value.contains('\n'))
                    connection.setRequestProperty(name, value)
                }
                val status = connection.responseCode
                if (status in listOf(301, 302, 303, 307, 308)) {
                    require(redirect < 5)
                    val next = URL(url, connection.getHeaderField("Location") ?: throw IllegalArgumentException("Missing redirect"))
                    if (next.host != url.host || next.port != url.port || next.protocol != url.protocol) {
                        headers = JSONObject().apply {
                            if (headers.has("User-Agent")) put("User-Agent", headers.getString("User-Agent"))
                        }
                    }
                    url = next
                    continue
                }
                if (status != 200) { result.put("failure", "httpStatus").put("httpStatus", status); return }
                if (connection.contentLengthLong > MAX_BODY) { result.put("failure", "responseTooLarge"); return }
                val bytes = java.io.ByteArrayOutputStream()
                connection.inputStream.use { stream ->
                    val buffer = ByteArray(8192)
                    while (true) {
                        if (cancelled.get() || foreground) return
                        if (android.os.SystemClock.elapsedRealtime() >= deadline) throw SocketTimeoutException()
                        val count = stream.read(buffer)
                        if (count < 0) break
                        if (bytes.size() + count > MAX_BODY) { result.put("failure", "responseTooLarge"); return }
                        bytes.write(buffer, 0, count)
                    }
                }
                val responseHeaders = JSONObject()
                connection.headerFields.forEach { (name, values) ->
                    val normalized = name?.lowercase()
                    if (normalized != null && normalized in subscriptionResponseHeaders) {
                        responseHeaders.put(normalized, values.joinToString(", "))
                    }
                }
                result.put("body", Base64.encodeToString(bytes.toByteArray(), Base64.NO_WRAP))
                    .put("headers", responseHeaders)
                return
            } finally { connection.disconnect(); setConnection(null) }
        }
    }
}

class SubscriptionRefreshJob : JobService() {
    private var cancelled = AtomicBoolean(false)
    @Volatile private var connection: HttpURLConnection? = null
    override fun onStartJob(params: JobParameters): Boolean {
        val cancellation = AtomicBoolean(false)
        cancelled = cancellation
        Thread({
            try { SubscriptionRefreshJobs.run(applicationContext, cancellation) { connection = it } }
            catch (error: Exception) { android.util.Log.w("SubscriptionRefresh", "Background update could not finish", error) }
            finally { Handler(Looper.getMainLooper()).post { if (!cancellation.get()) jobFinished(params, false) } }
        }, "subscription-refresh").start()
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean {
        cancelled.set(true)
        connection?.disconnect()
        return false
    }
}
