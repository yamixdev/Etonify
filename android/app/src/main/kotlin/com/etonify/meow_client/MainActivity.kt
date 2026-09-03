package com.etonify.meow_client

import android.app.ActivityManager
import android.Manifest
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.AtomicFile
import android.util.Log
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
// Legacy Happ native crypt5 path is intentionally disabled. Crypt5/5.1 is now
// decrypted in Dart from extracted selector/key tables.
// import com.etonify.meow_client.happcrypto.Crypto5IsolatedService
import com.etonify.meow_client.singbox.MeowBoxService
import com.etonify.meow_client.singbox.MeowDefaultNetworkMonitor
import com.etonify.meow_client.singbox.MeowDiagnostics
import com.etonify.meow_client.singbox.MeowLogSanitizer
import com.etonify.meow_client.singbox.MeowProxyService
import com.etonify.meow_client.singbox.MeowVpnPlatformInterface
import com.etonify.meow_client.singbox.MeowVpnService
import com.etonify.meow_client.singbox.OwnProcessMemory
import com.etonify.meow_client.singbox.PersistentDnsCache
import com.etonify.meow_client.singbox.RuntimeMeasurement
import com.etonify.meow_client.singbox.SingboxController
import com.etonify.meow_client.generated.ApkInspectionMessage
import com.etonify.meow_client.generated.FlutterError as PigeonFlutterError
import com.etonify.meow_client.generated.HttpHeaderMessage
import com.etonify.meow_client.generated.InstalledAppMessage
import com.etonify.meow_client.generated.NetworkInterfaceStateMessage
import com.etonify.meow_client.generated.RuntimeFlagsMessage
import com.etonify.meow_client.generated.SingboxHostApi
import com.etonify.meow_client.generated.UnderlyingNetworkDownloadRequestMessage
import com.etonify.meow_client.generated.UnderlyingNetworkDownloadResponseMessage
import com.etonify.meow_client.generated.UnderlyingNetworkFetchRequestMessage
import com.etonify.meow_client.generated.UnderlyingNetworkFetchResponseMessage
import com.etonify.meow_client.generated.UrlTestRequestMessage
import com.etonify.meow_client.generated.VpnNotificationPresentationMessage
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.libbox.Libbox
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val TAG = "MeowMainActivity"
        private const val QUICK_TILE_LABEL_FILE = "quick_tile_label.txt"
        private const val MAX_SUBSCRIPTION_REDIRECTS = 5
        private val SUBSCRIPTION_REDIRECT_CODES = setOf(301, 302, 303, 307, 308)
    }
    private val methodChannelName = "meow_client/singbox"
    private val eventChannelName = "meow_client/singbox_events"
    private val deepLinkMethodChannelName = "meow_client/deep_links"
    private val deepLinkEventChannelName = "meow_client/deep_link_events"
    private val secureStorageMethodChannelName = "meow_client/secure_storage"
    // private val happCryptoMethodChannelName = "meow_client/happ_crypto"
    private var pendingPrepareResult: MethodChannel.Result? = null
    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingExportContent: String? = null
    private var pendingInstallSettingsResult: MethodChannel.Result? = null
    private var pendingApkInstallResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null
    private var deepLinkEventSink: EventChannel.EventSink? = null
    @Volatile
    private var singboxEventSinkRegistration = 0L
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val subscriptionNetworkExecutor = Executors.newFixedThreadPool(2)
    private val endpointDnsExecutor = Executors.newFixedThreadPool(2)
    private val appIconExecutor = Executors.newFixedThreadPool(3)
    private var lastPerformanceSnapshotUptimeMs = 0L
    private var lastPerformanceSnapshotCpuMs = 0L

    private val vpnPermissionLauncher: ActivityResultLauncher<Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
            val result = pendingPrepareResult
            pendingPrepareResult = null
            result?.success(VpnService.prepare(this) == null)
        }

    private val exportDocumentLauncher: ActivityResultLauncher<String> =
        registerForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri ->
            completeLogExport(uri)
        }

    private val installSettingsLauncher: ActivityResultLauncher<Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
            val result = pendingInstallSettingsResult
            pendingInstallSettingsResult = null
            result?.success(canRequestApkInstalls())
        }

    private val apkInstallLauncher: ActivityResultLauncher<Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
            val result = pendingApkInstallResult
            pendingApkInstallResult = null
            result?.success(true)
        }

    private val notificationPermissionLauncher: ActivityResultLauncher<String> =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            val result = pendingNotificationPermissionResult
            pendingNotificationPermissionResult = null
            result?.success(granted)
        }

    private class PigeonMethodResult<T>(
        private val callback: (Result<T>) -> Unit,
        private val transform: (Any?) -> T,
    ) : MethodChannel.Result {
        override fun success(result: Any?) {
            runCatching { transform(result) }
                .onSuccess { callback(Result.success(it)) }
                .onFailure { callback(Result.failure(it)) }
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            callback(Result.failure(PigeonFlutterError(errorCode, errorMessage, errorDetails)))
        }

        override fun notImplemented() {
            callback(
                Result.failure(
                    PigeonFlutterError(
                        "not_implemented",
                        "Android host method is not implemented.",
                        null,
                    ),
                ),
            )
        }
    }

    private fun unitResult(callback: (Result<Unit>) -> Unit): MethodChannel.Result =
        PigeonMethodResult(callback) { Unit }

    private fun boolResult(callback: (Result<Boolean>) -> Unit): MethodChannel.Result =
        PigeonMethodResult(callback) { result -> result == true }

    private fun nullableStringResult(callback: (Result<String?>) -> Unit): MethodChannel.Result =
        PigeonMethodResult(callback) { result -> result as String? }

    private fun errorResult(
        code: String,
        message: String?,
        details: Any? = null,
    ): Result<Nothing> = Result.failure(PigeonFlutterError(code, message, details))

    private fun pigeonMap(source: Map<*, *>): Map<String?, Any?> =
        source.entries.associate { entry -> entry.key?.toString() to entry.value }

    private fun notificationPresentationArguments(
        presentation: VpnNotificationPresentationMessage,
    ): Map<String, Any?> = linkedMapOf(
        "detailed" to presentation.detailed,
        "trafficDisplayMode" to presentation.trafficDisplayMode,
        "trafficRefreshSeconds" to presentation.trafficRefreshSeconds,
        "title" to presentation.title,
        "latencyMillis" to presentation.latencyMillis,
        "groupTag" to presentation.groupTag,
        "targetOutboundTag" to presentation.targetOutboundTag,
        "priorityOutboundTag" to presentation.priorityOutboundTag,
        "excludeOutboundTag" to presentation.excludeOutboundTag,
        "url" to presentation.url,
        "timeoutMillis" to presentation.timeoutMillis,
        "concurrency" to presentation.concurrency,
        "deadlineMillis" to presentation.deadlineMillis,
        "connectedText" to presentation.connectedText,
        "checkingText" to presentation.checkingText,
        "unavailableText" to presentation.unavailableText,
        "totalLabel" to presentation.totalLabel,
        "refreshLabel" to presentation.refreshLabel,
        "stopLabel" to presentation.stopLabel,
    )

    private fun underlyingNetworkFetchResponse(
        response: Map<String, Any>,
    ): UnderlyingNetworkFetchResponseMessage {
        val headers = (response["headers"] as? Map<*, *>)
            .orEmpty()
            .mapNotNull { (name, value) ->
                val normalizedName = name?.toString()?.trim().orEmpty()
                if (normalizedName.isEmpty()) {
                    null
                } else {
                    HttpHeaderMessage(normalizedName, value?.toString().orEmpty())
                }
            }
        return UnderlyingNetworkFetchResponseMessage(
            statusCode = (response["statusCode"] as? Number)?.toLong() ?: 0L,
            body = response["body"]?.toString().orEmpty(),
            headers = headers,
            finalUrl = response["finalUrl"]?.toString().orEmpty(),
            network = response["network"]?.toString().orEmpty(),
        )
    }

    private fun underlyingNetworkDownloadResponse(
        response: Map<String, Any>,
    ): UnderlyingNetworkDownloadResponseMessage {
        val headers = (response["headers"] as? Map<*, *>)
            .orEmpty()
            .mapNotNull { (name, value) ->
                val normalizedName = name?.toString()?.trim().orEmpty()
                if (normalizedName.isEmpty()) {
                    null
                } else {
                    HttpHeaderMessage(normalizedName, value?.toString().orEmpty())
                }
            }
        return UnderlyingNetworkDownloadResponseMessage(
            statusCode = (response["statusCode"] as? Number)?.toLong() ?: 0L,
            downloadedBytes = (response["downloadedBytes"] as? Number)?.toLong() ?: 0L,
            headers = headers,
            finalUrl = response["finalUrl"]?.toString().orEmpty(),
            network = response["network"]?.toString().orEmpty(),
        )
    }

    private fun apkInspectionMessage(inspection: Map<String, Any>): ApkInspectionMessage =
        ApkInspectionMessage(
            valid = inspection["valid"] == true,
            packageName = inspection["packageName"]?.toString().orEmpty(),
            installedPackageName = inspection["installedPackageName"]?.toString().orEmpty(),
            versionName = inspection["versionName"]?.toString().orEmpty(),
            versionCode = (inspection["versionCode"] as? Number)?.toLong() ?: 0L,
            minSdk = (inspection["minSdk"] as? Number)?.toLong() ?: 0L,
            targetSdk = (inspection["targetSdk"] as? Number)?.toLong() ?: 0L,
            deviceSdk = (inspection["deviceSdk"] as? Number)?.toLong() ?: 0L,
            signingCertificateSha256 = (inspection["signingCertificateSha256"] as? Iterable<*>)
                ?.mapNotNull { value -> value?.toString() }
                ?: emptyList(),
            installedCertificateSha256 = (inspection["installedCertificateSha256"] as? Iterable<*>)
                ?.mapNotNull { value -> value?.toString() }
                ?: emptyList(),
        )

    private fun installedAppMessages(): List<InstalledAppMessage> =
        getInstalledApps().map { app ->
            InstalledAppMessage(
                packageName = app["packageName"]?.toString().orEmpty(),
                label = app["label"]?.toString().orEmpty(),
                system = app["system"] == true,
                launchable = app["launchable"] == true,
            )
        }

    private fun getOwnPackageInfoCompat(): PackageInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0)
        }

    private fun getAppVersionInfo(): Map<String, Any> {
        val info = getOwnPackageInfoCompat()
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return linkedMapOf(
            "packageName" to packageName,
            "versionName" to (info.versionName ?: ""),
            "versionCode" to versionCode,
        )
    }

    private fun getEtonifyCoreCapabilities(): String =
        runCatching {
            val capabilityMethod = Libbox::class.java.methods.firstOrNull { method ->
                method.parameterCount == 0 &&
                    method.name.equals("etonifyCapabilities", ignoreCase = true)
            }
            capabilityMethod?.invoke(null) as? String ?: ""
        }.onFailure { error ->
            Log.w(TAG, "Core capability handshake is unavailable", error)
        }.getOrDefault("")

    private fun canRequestApkInstalls(): Boolean = packageManager.canRequestPackageInstalls()

    private fun notificationsGranted(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED

    private fun ensureNotificationPermission(result: MethodChannel.Result) {
        if (notificationsGranted()) {
            result.success(true)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            result.error(
                "notification_permission_in_progress",
                "A notification permission request is already active.",
                null,
            )
            return
        }
        pendingNotificationPermissionResult = result
        runCatching {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }.onFailure { error ->
            pendingNotificationPermissionResult = null
            result.error("notification_permission_launch_failed", error.message, null)
        }
    }

    private fun launchVpnPermission(intent: Intent, result: MethodChannel.Result) {
        if (pendingPrepareResult != null) {
            result.error(
                "vpn_permission_in_progress",
                "A VPN permission request is already active.",
                null,
            )
            return
        }
        pendingPrepareResult = result
        runCatching { vpnPermissionLauncher.launch(intent) }
            .onFailure { error ->
                pendingPrepareResult = null
                result.error("vpn_permission_launch_failed", error.message, null)
            }
    }

    private fun openApkInstallSettings(result: MethodChannel.Result) {
        if (pendingInstallSettingsResult != null) {
            result.error(
                "install_settings_in_progress",
                "APK install settings are already open.",
                null,
            )
            return
        }
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        )
        pendingInstallSettingsResult = result
        runCatching { installSettingsLauncher.launch(intent) }
            .onFailure { error ->
                pendingInstallSettingsResult = null
                result.error("open_install_settings_failed", error.message, null)
            }
    }

    private fun installDownloadedApk(result: MethodChannel.Result) {
        val file = UpdateApkLocator.resolveSingleExisting(filesDir)
        requireTrustedUpdateIdentity(file)
        if (!canRequestApkInstalls()) {
            throw IllegalStateException("APK install permission is not granted.")
        }
        check(pendingApkInstallResult == null) { "An APK installation is already active." }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
        }
        pendingApkInstallResult = result
        runCatching { apkInstallLauncher.launch(intent) }
            .onFailure { error ->
                pendingApkInstallResult = null
                throw error
            }
    }

    private fun requireTrustedUpdateIdentity(file: File) {
        val inspection = inspectDownloadedApk(file.absolutePath)
        require(inspection["valid"] == true) { "Android could not read the update APK." }
        require(inspection["packageName"] == packageName) {
            "Update APK package does not match Etonify."
        }
        val archiveCertificates = digestSet(inspection["signingCertificateSha256"])
        val installedCertificates = digestSet(inspection["installedCertificateSha256"])
        require(
            archiveCertificates.isNotEmpty() &&
                installedCertificates.isNotEmpty() &&
                archiveCertificates.any(installedCertificates::contains),
        ) { "Update APK signature does not match installed Etonify." }
    }

    private fun digestSet(value: Any?): Set<String> =
        (value as? Iterable<*>)
            ?.mapNotNull { digest ->
                digest?.toString()?.trim()?.lowercase()?.takeIf(String::isNotEmpty)
            }
            ?.toSet()
            .orEmpty()

    private fun launchLogExport(
        content: String,
        suggestedName: String,
        result: MethodChannel.Result,
    ) {
        if (pendingExportResult != null) {
            result.error("export_in_progress", "A log export is already active.", null)
            return
        }
        pendingExportResult = result
        pendingExportContent = logsWithNativeDiagnostics(content)
        runCatching {
            exportDocumentLauncher.launch(
                suggestedName.ifBlank { "meow-logs-${System.currentTimeMillis()}.txt" },
            )
        }.onFailure { error ->
            pendingExportResult = null
            pendingExportContent = null
            result.error("export_logs_failed", error.message, null)
        }
    }

    private fun completeLogExport(uri: Uri?) {
        val result = pendingExportResult
        val content = pendingExportContent
        pendingExportResult = null
        pendingExportContent = null
        if (uri == null || content == null) {
            result?.success(null)
            return
        }
        runCatching {
            contentResolver.openOutputStream(uri)?.use { stream ->
                stream.write(content.toByteArray(Charsets.UTF_8))
                stream.flush()
            } ?: error("Failed to open output stream")
        }.onSuccess {
            result?.success(uri.toString())
        }.onFailure {
            result?.error("export_logs_failed", it.message, null)
        }
    }

    private fun inspectDownloadedApk(path: String): Map<String, Any> {
        val file = File(path)
        require(file.exists() && file.isFile) { "APK file does not exist." }
        require(file.name.lowercase().endsWith(".apk")) { "File is not an APK." }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
        val archiveInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageArchiveInfo(
                file.absolutePath,
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageArchiveInfo(file.absolutePath, flags)
        } ?: return linkedMapOf("valid" to false)
        archiveInfo.applicationInfo?.apply {
            sourceDir = file.absolutePath
            publicSourceDir = file.absolutePath
        }
        val installedInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, flags)
        }
        val archiveVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            archiveInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            archiveInfo.versionCode.toLong()
        }
        return linkedMapOf(
            "valid" to true,
            "packageName" to archiveInfo.packageName,
            "installedPackageName" to packageName,
            "versionName" to (archiveInfo.versionName ?: ""),
            "versionCode" to archiveVersionCode,
            "minSdk" to (archiveInfo.applicationInfo?.minSdkVersion ?: 0),
            "targetSdk" to (archiveInfo.applicationInfo?.targetSdkVersion ?: 0),
            "deviceSdk" to Build.VERSION.SDK_INT,
            "signingCertificateSha256" to signingCertificateDigests(archiveInfo),
            "installedCertificateSha256" to signingCertificateDigests(installedInfo),
        )
    }

    private fun signingCertificateDigests(info: PackageInfo): List<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo ?: return emptyList()
            if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
        } else {
            @Suppress("DEPRECATION")
            info.signatures
        }
        return signatures
            .orEmpty()
            .map { signature ->
                MessageDigest.getInstance("SHA-256")
                    .digest(signature.toByteArray())
                    .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
            }
            .distinct()
    }

    private fun resolveHostOnUnderlyingNetwork(rawHost: String): List<String> {
        val host = rawHost.trim().removePrefix("[").removeSuffix("]")
        require(host.isNotEmpty()) { "Host is empty." }
        require(host.length <= 253) { "Host is too long." }
        val network = MeowDefaultNetworkMonitor.requirePhysicalNetwork()
        val addresses = network.getAllByName(host)
            .mapNotNull { address -> address.hostAddress?.trim() }
            .filter { address -> address.isNotEmpty() }
            .distinct()
        require(addresses.isNotEmpty()) { "Host did not resolve to an IP address." }
        return addresses
    }

    private fun fetchUrlOnUnderlyingNetwork(
        rawUrl: String,
        headers: Map<String, String>,
        maxBytes: Int,
        timeoutMs: Int,
    ): Map<String, Any> {
        val network = MeowDefaultNetworkMonitor.requirePhysicalNetwork()
        val boundedTimeout = timeoutMs.coerceIn(3_000, 60_000)
        val deadline = SystemClock.elapsedRealtime() + boundedTimeout
        var url = URL(rawUrl)
        var requestHeaders = headers.toMap()
        var redirectCount = 0
        while (true) {
            validateSubscriptionRequest(url)
            val remaining = deadline - SystemClock.elapsedRealtime()
            require(remaining > 0L) { "Subscription request timed out." }
            val connection = network.openConnection(url) as HttpURLConnection
            val requestTimeout = remaining.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
            val abortOnDeadline = Runnable { connection.disconnect() }
            mainHandler.postDelayed(abortOnDeadline, remaining)
            try {
                connection.requestMethod = "GET"
                connection.instanceFollowRedirects = false
                connection.connectTimeout = requestTimeout
                connection.readTimeout = requestTimeout
                connection.useCaches = false
                for ((name, value) in requestHeaders) {
                    if (name.isBlank() || name.any { it == '\r' || it == '\n' }) continue
                    if (value.any { it == '\r' || it == '\n' }) continue
                    connection.setRequestProperty(name, value)
                }
                val statusCode = connection.responseCode
                if (statusCode in SUBSCRIPTION_REDIRECT_CODES) {
                    require(redirectCount < MAX_SUBSCRIPTION_REDIRECTS) {
                        "Too many subscription redirects."
                    }
                    val location = connection.getHeaderField("Location")?.trim().orEmpty()
                    require(location.isNotEmpty()) { "Subscription redirect has no Location header." }
                    val redirectedUrl = URL(url, location)
                    require(!(url.protocol == "https" && redirectedUrl.protocol == "http")) {
                        "HTTPS to HTTP subscription redirect is not allowed."
                    }
                    if (!sameOrigin(url, redirectedUrl)) {
                        requestHeaders = requestHeaders.filterKeys(::isSafeCrossOriginHeader)
                    }
                    url = redirectedUrl
                    redirectCount++
                    continue
                }
                val declaredLength = connection.contentLengthLong
                require(declaredLength <= maxBytes || declaredLength < 0) {
                    "Response is larger than $maxBytes bytes."
                }
                val stream = if (statusCode in 200..299) {
                    connection.inputStream
                } else {
                    connection.errorStream
                }
                val output = ByteArrayOutputStream(
                    declaredLength.coerceIn(0, maxBytes.toLong()).toInt(),
                )
                stream?.use { input ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var total = 0
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        total += read
                        require(total <= maxBytes) { "Response is larger than $maxBytes bytes." }
                        output.write(buffer, 0, read)
                    }
                }
                val responseHeaders = linkedMapOf<String, String>()
                for ((name, values) in connection.headerFields) {
                    if (name == null || values.isNullOrEmpty()) continue
                    responseHeaders[name.lowercase()] = values.joinToString(", ")
                }
                return linkedMapOf(
                    "statusCode" to statusCode,
                    "body" to decodeSubscriptionUtf8(output.toByteArray()),
                    "headers" to responseHeaders,
                    "finalUrl" to url.toString(),
                    "network" to MeowDefaultNetworkMonitor.describeNetwork(network),
                )
            } finally {
                mainHandler.removeCallbacks(abortOnDeadline)
                connection.disconnect()
            }
        }
    }

    private fun downloadUrlOnUnderlyingNetwork(
        rawUrl: String,
        headers: Map<String, String>,
        destinationPath: String,
        maxBytes: Long,
        responseStartTimeoutMs: Int,
        idleTimeoutMs: Int,
    ): Map<String, Any> {
        val network = MeowDefaultNetworkMonitor.requirePhysicalNetwork()
        val destination = requirePrivateDownloadTarget(destinationPath)
        val boundedResponseTimeout = responseStartTimeoutMs.coerceIn(1_000, 30_000)
        val boundedIdleTimeout = idleTimeoutMs.coerceIn(1_000, 60_000)
        var url = URL(rawUrl)
        var requestHeaders = headers.toMap()
        var redirectCount = 0
        try {
            while (true) {
                validateSubscriptionRequest(url)
                val connection = network.openConnection(url) as HttpURLConnection
                val abortBeforeResponse = Runnable { connection.disconnect() }
                try {
                    connection.requestMethod = "GET"
                    connection.instanceFollowRedirects = false
                    connection.connectTimeout = boundedResponseTimeout
                    // Before responseCode this timeout limits time to the first
                    // response bytes. Once headers arrive, use the longer
                    // per-read idle timeout for the actual file stream.
                    connection.readTimeout = boundedResponseTimeout
                    connection.useCaches = false
                    for ((name, value) in requestHeaders) {
                        if (name.isBlank() || name.any { it == '\r' || it == '\n' }) continue
                        if (value.any { it == '\r' || it == '\n' }) continue
                        connection.setRequestProperty(name, value)
                    }
                    mainHandler.postDelayed(
                        abortBeforeResponse,
                        boundedResponseTimeout.toLong(),
                    )
                    val statusCode = connection.responseCode
                    mainHandler.removeCallbacks(abortBeforeResponse)
                    if (statusCode in SUBSCRIPTION_REDIRECT_CODES) {
                        require(redirectCount < MAX_SUBSCRIPTION_REDIRECTS) {
                            "Too many remote download redirects."
                        }
                        val location = connection.getHeaderField("Location")?.trim().orEmpty()
                        require(location.isNotEmpty()) { "Remote redirect has no Location header." }
                        val redirectedUrl = URL(url, location)
                        require(!(url.protocol == "https" && redirectedUrl.protocol == "http")) {
                            "HTTPS to HTTP remote redirect is not allowed."
                        }
                        if (!sameOrigin(url, redirectedUrl)) {
                            requestHeaders = requestHeaders.filterKeys(::isSafeCrossOriginHeader)
                        }
                        url = redirectedUrl
                        redirectCount++
                        continue
                    }

                    val declaredLength = connection.contentLengthLong
                    require(declaredLength <= maxBytes || declaredLength < 0L) {
                        "Response is larger than $maxBytes bytes."
                    }
                    var downloadedBytes = 0L
                    if (statusCode in 200..299) {
                        connection.readTimeout = boundedIdleTimeout
                        destination.parentFile?.mkdirs()
                        connection.inputStream.use { input ->
                            FileOutputStream(destination, false).use { output ->
                                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                                while (true) {
                                    val read = input.read(buffer)
                                    if (read < 0) break
                                    downloadedBytes += read
                                    require(downloadedBytes <= maxBytes) {
                                        "Response is larger than $maxBytes bytes."
                                    }
                                    output.write(buffer, 0, read)
                                }
                                output.fd.sync()
                            }
                        }
                    }
                    val responseHeaders = linkedMapOf<String, String>()
                    for ((name, values) in connection.headerFields) {
                        if (name == null || values.isNullOrEmpty()) continue
                        responseHeaders[name.lowercase()] = values.joinToString(", ")
                    }
                    return linkedMapOf(
                        "statusCode" to statusCode,
                        "downloadedBytes" to downloadedBytes,
                        "headers" to responseHeaders,
                        "finalUrl" to url.toString(),
                        "network" to MeowDefaultNetworkMonitor.describeNetwork(network),
                    )
                } finally {
                    mainHandler.removeCallbacks(abortBeforeResponse)
                    connection.disconnect()
                }
            }
        } catch (error: Throwable) {
            runCatching { if (destination.exists()) destination.delete() }
            throw error
        }
    }

    private fun requirePrivateDownloadTarget(rawPath: String): File {
        return PrivateDownloadPathPolicy.requireTarget(
            rawPath = rawPath,
            privateDataDirectory = File(applicationInfo.dataDir),
        )
    }

    private fun validateSubscriptionRequest(url: URL) {
        SubscriptionTransportPolicy.validate(url)
    }

    private fun decodeSubscriptionUtf8(bytes: ByteArray): String = try {
        Charsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes))
            .toString()
    } catch (error: CharacterCodingException) {
        throw IllegalArgumentException("Subscription response is not valid UTF-8.", error)
    }

    private fun isSafeCrossOriginHeader(name: String): Boolean =
        name.equals("User-Agent", ignoreCase = true) ||
            name.equals("Accept", ignoreCase = true)

    private fun sameOrigin(first: URL, second: URL): Boolean =
        first.protocol.equals(second.protocol, ignoreCase = true) &&
            first.host.equals(second.host, ignoreCase = true) &&
            effectivePort(first) == effectivePort(second)

    private fun effectivePort(url: URL): Int = when {
        url.port >= 0 -> url.port
        url.protocol == "https" -> 443
        else -> 80
    }

    private fun buildImportDeepLinkPayload(uri: Uri?): Map<String, Any?>? {
        if (uri == null) {
            return null
        }
        val scheme = uri.scheme?.lowercase() ?: return null
        fun importPayload(sourceType: String, url: String, name: String = ""): Map<String, Any?> =
            linkedMapOf(
                "scheme" to scheme,
                "sourceType" to sourceType,
                "url" to url,
                "name" to name,
            )

        if (scheme == "happ") {
            val host = uri.host?.lowercase().orEmpty()
            val path = uri.path.orEmpty().trim('/').lowercase()
            if (
                host == "routing" ||
                path == "routing" ||
                path.startsWith("routing/")
            ) {
                return null
            }
            val importUrl = uri.getQueryParameter("url")?.trim().orEmpty()
            val name = uri.getQueryParameter("name")?.trim().orEmpty()
            val sourceType = when {
                host == "add" || path == "add" || path.startsWith("add/") -> "happAdd"
                host == "crypt" || host == "crypt2" || host == "crypt3" ||
                    host == "crypt4" || host == "crypt5" ||
                    path == "crypt" || path == "crypt2" || path == "crypt3" ||
                    path == "crypt4" || path == "crypt5" ||
                    path.startsWith("crypt/") || path.startsWith("crypt2/") ||
                    path.startsWith("crypt3/") || path.startsWith("crypt4/") ||
                    path.startsWith("crypt5/") -> "happCrypto"
                else -> "happAdd"
            }
            return importPayload(
                sourceType,
                if (importUrl.isNotBlank()) importUrl else uri.toString(),
                name,
            )
        }
        if (scheme == "sing-box") {
            val host = uri.host?.lowercase().orEmpty()
            val path = uri.path.orEmpty().trim('/').lowercase()
            if (host != "import-remote-profile" && path != "import-remote-profile") {
                return null
            }
            val url = uri.getQueryParameter("url")?.trim().orEmpty()
            if (url.isBlank()) {
                return null
            }
            val name = uri.getQueryParameter("name")?.trim().orEmpty()
            return importPayload("singBoxRemoteProfile", url, name)
        }
        if (scheme != "etonify" && scheme != "meowvpn") {
            return null
        }
        val host = uri.host?.lowercase().orEmpty()
        val path = uri.path.orEmpty().trim('/').lowercase()
        if (host != "import" && path != "import") {
            return null
        }
        val url = uri.getQueryParameter("url")?.trim().orEmpty()
        if (url.isBlank()) {
            return null
        }
        val name = uri.getQueryParameter("name")?.trim().orEmpty()
        return importPayload("etonifyImport", url, name)
    }

    private fun dispatchImportDeepLink(intent: Intent?) {
        val payload = buildImportDeepLinkPayload(intent?.data) ?: return
        mainHandler.post {
            deepLinkEventSink?.success(payload)
        }
    }

    private fun writeConfigAtomically(config: String) {
        val target = MeowApplication.configFile
        val directory = target.parentFile ?: throw IllegalStateException("Config directory missing")
        directory.mkdirs()
        val previousConfig = target.takeIf { it.isFile }?.readText(Charsets.UTF_8)
        val dnsChanged = dnsConfigurationChanged(previousConfig, config)
        val atomicFile = AtomicFile(target)
        var output: FileOutputStream? = null
        try {
            output = atomicFile.startWrite()
            output.write(config.toByteArray(Charsets.UTF_8))
            atomicFile.finishWrite(output)
        } catch (error: Throwable) {
            output?.let(atomicFile::failWrite)
            throw error
        }
        if (dnsChanged) {
            PersistentDnsCache.requestClear(
                MeowApplication.singboxWorkingDirectory,
                "config_dns_changed",
            )
            MeowDiagnostics.log(TAG, "persistent DNS cache clear requested after config change")
        }
    }

    private fun dnsConfigurationChanged(previousConfig: String?, nextConfig: String): Boolean {
        if (previousConfig == null) {
            return File(MeowApplication.singboxWorkingDirectory, "cache.db").exists()
        }
        val previousDns = runCatching { JSONObject(previousConfig).opt("dns")?.toString() }.getOrNull()
        val nextDns = runCatching { JSONObject(nextConfig).opt("dns")?.toString() }.getOrNull()
        return previousDns == null || nextDns == null || previousDns != nextDns
    }

    private fun writeConfigAndDispatch(
        config: String,
        result: MethodChannel.Result,
        onSuccess: () -> Unit,
    ) {
        ioExecutor.execute {
            val error = runCatching {
                writeConfigAtomically(config)
            }.exceptionOrNull()
            mainHandler.post {
                if (error != null) {
                    result.error("write_config_failed", error.message, null)
                    return@post
                }
                onSuccess()
            }
        }
    }

    private fun withPreparedConfig(
        result: MethodChannel.Result,
        onSuccess: () -> Unit,
    ) {
        ioExecutor.execute {
            val error = runCatching {
                val target = MeowApplication.configFile
                if (!target.exists() || target.length() <= 0L) {
                    error("Config is empty")
                }
            }.exceptionOrNull()
            mainHandler.post {
                if (error != null) {
                    result.error("empty_config", error.message, null)
                    return@post
                }
                onSuccess()
            }
        }
    }

    private fun currentRuntimeModeForStop(): String {
        val controllerMode = SingboxController.serviceMode.trim().lowercase()
        if (controllerMode == "vpn" || controllerMode == "proxy") {
            return controllerMode
        }
        val recordedMode = MeowApplication.readServiceState()?.mode?.trim()?.lowercase().orEmpty()
        return if (recordedMode == "proxy") "proxy" else "vpn"
    }

    private fun runtimeStopTargetForMode(mode: String): Class<out android.app.Service> {
        return when (mode) {
            "proxy" -> MeowProxyService::class.java
            else -> MeowVpnService::class.java
        }
    }

    private fun runtimeCleanupTargets(
        primary: Class<out android.app.Service>,
    ): List<Class<out android.app.Service>> {
        val secondary = if (primary == MeowVpnService::class.java) {
            MeowProxyService::class.java
        } else {
            MeowVpnService::class.java
        }
        return listOf(primary, secondary)
    }

    private fun cleanupStoppedRuntimeState(
        reason: String,
        source: String,
        stopRequestedAtMillis: Long,
        targets: List<Class<out android.app.Service>>,
        force: Boolean,
    ): Boolean {
        val runtimeIntent = MeowApplication.readRuntimeIntent()
        val freshStartAfterStop =
            runtimeIntent != null &&
                runtimeIntent.updatedAtMillis > stopRequestedAtMillis &&
                MeowApplication.isRuntimeIntentFresh(runtimeIntent.mode)
        if (freshStartAfterStop) {
            MeowDiagnostics.log(
                TAG,
                "cleanupStoppedRuntimeState skipped fresh start reason=$reason source=$source " +
                    "intent=${MeowApplication.describeRuntimeIntent()}",
            )
            return false
        }
        if (force) {
            SingboxController.log(
                "warning",
                "force runtime cleanup reason=$reason source=$source " +
                    "running=${SingboxController.running} mode=${SingboxController.serviceMode} " +
                    "activeOwner=${MeowBoxService.hasActiveRuntimeOwner(SingboxController.serviceMode)}",
            )
            MeowBoxService.requestStopAll("force_cleanup:$reason:$source")
            MeowBoxService.requestTerminalForceStopAll("force_cleanup:$reason:$source")
            MeowDefaultNetworkMonitor.stop()
        }
        for (serviceClass in targets) {
            runCatching {
                stopService(Intent(this, serviceClass))
            }.onFailure {
                MeowDiagnostics.log(TAG, "stopService failed target=${serviceClass.simpleName}", it)
            }
        }
        MeowApplication.clearServiceState()
        MeowApplication.clearRuntimeIntent()
        MeowQuickSettingsTileService.requestRefresh(this)
        val stopped =
            !SingboxController.running &&
                !MeowBoxService.hasActiveRuntimeOwner()
        MeowDiagnostics.log(
            TAG,
            "cleanupStoppedRuntimeState completed reason=$reason source=$source force=$force " +
                "stopped=$stopped targets=${targets.joinToString { it.simpleName }}",
        )
        return stopped
    }

    private fun dispatchStopRuntime(reason: String, onComplete: (Boolean) -> Unit) {
        val modeAtRequest = currentRuntimeModeForStop()
        val primaryTarget = runtimeStopTargetForMode(modeAtRequest)
        val cleanupTargets = runtimeCleanupTargets(primaryTarget)
        val stopRequestedAtMillis = System.currentTimeMillis()
        MeowDiagnostics.log(
            TAG,
            "dispatchStopRuntime reason=$reason running=${SingboxController.running} " +
                "mode=${SingboxController.serviceMode} requestedMode=$modeAtRequest " +
                "primary=${primaryTarget.simpleName} cleanup=${cleanupTargets.joinToString { it.simpleName }}",
        )
        SingboxController.log(
            "warning",
            "android stop requested reason=$reason running=${SingboxController.running} " +
                "mode=${SingboxController.serviceMode}",
        )
        // Persist the user's stop intent before native cleanup. If Android
        // kills the process during cleanup, START_STICKY must not resurrect a
        // VPN the user has just stopped.
        MeowApplication.clearRuntimeIntent()

        val stopRequestedDirectly = MeowBoxService.requestStopForMode(
            modeAtRequest,
            "main_activity_stop:$reason",
        )

        if (!stopRequestedDirectly) {
            runCatching {
                startService(
                    Intent(this, primaryTarget)
                        .setAction(MeowBoxService.ACTION_STOP)
                        .putExtra(MeowBoxService.EXTRA_STOP_REASON, reason),
                )
            }.onFailure {
                MeowDiagnostics.log(
                    TAG,
                    "ACTION_STOP failed target=${primaryTarget.simpleName}",
                    it,
                )
            }
        }
        mainHandler.postDelayed({
            if (!SingboxController.running) {
                cleanupStoppedRuntimeState(
                    reason = reason,
                    source = "safety_delay",
                    stopRequestedAtMillis = stopRequestedAtMillis,
                    targets = cleanupTargets,
                    force = false,
                )
            } else {
                MeowDiagnostics.log(
                    TAG,
                    "dispatchStopRuntime safety stopService skipped reason=$reason " +
                        "running=${SingboxController.running} " +
                        "activeOwner=${MeowBoxService.hasActiveRuntimeOwner(modeAtRequest)} " +
                        "intent=${MeowApplication.describeRuntimeIntent()}",
                )
            }
        }, 1_200L)
        if (!SingboxController.running) {
            cleanupStoppedRuntimeState(
                reason = reason,
                source = "already_stopped",
                stopRequestedAtMillis = stopRequestedAtMillis,
                targets = cleanupTargets,
                force = false,
            )
            onComplete(true)
            return
        }
        SingboxController.awaitStopped { stopped ->
            if (!stopped) {
                cleanupStoppedRuntimeState(
                    reason = reason,
                    source = "await_timeout",
                    stopRequestedAtMillis = stopRequestedAtMillis,
                    targets = cleanupTargets,
                    force = true,
                )
                // Give Service.onDestroy() and the native cleanup worker a short
                // final window, but never turn a timeout into a fake success.
                mainHandler.postDelayed({
                    val verifiedStopped =
                        !SingboxController.running &&
                            !MeowBoxService.hasActiveRuntimeOwner()
                    MeowDiagnostics.log(
                        TAG,
                        "dispatchStopRuntime timeout verification reason=$reason " +
                            "stopped=$verifiedStopped running=${SingboxController.running} " +
                            "activeOwner=${MeowBoxService.hasActiveRuntimeOwner()}",
                    )
                    onComplete(verifiedStopped)
                }, 750L)
                return@awaitStopped
            }
            cleanupStoppedRuntimeState(
                reason = reason,
                source = "await_stopped",
                stopRequestedAtMillis = stopRequestedAtMillis,
                targets = cleanupTargets,
                force = false,
            )
            onComplete(true)
        }
    }

    private fun dispatchStartAfterConfigWrite(useVpn: Boolean, result: MethodChannel.Result) {
        Log.i(TAG, "start requested useVpn=$useVpn running=${SingboxController.running} mode=${SingboxController.serviceMode}")
        SingboxController.log(
            "info",
            "android start requested useVpn=$useVpn running=${SingboxController.running} mode=${SingboxController.serviceMode}",
        )
        MeowDiagnostics.log(
            TAG,
            "start requested useVpn=$useVpn running=${SingboxController.running} mode=${SingboxController.serviceMode}",
        )
        val targetMode = if (useVpn) "vpn" else "proxy"
        val targetService = if (useVpn) {
            MeowVpnService::class.java
        } else {
            MeowProxyService::class.java
        }
        if (SingboxController.running && SingboxController.serviceMode == targetMode) {
            val serviceIntent = Intent(this, targetService).setAction(MeowBoxService.ACTION_START)
            Log.i(TAG, "start forwarding idempotent ACTION_START mode=$targetMode")
            MeowDiagnostics.log(TAG, "start forwarding idempotent ACTION_START mode=$targetMode")
            startForegroundService(serviceIntent)
            result.success(true)
            return
        }
        if (SingboxController.running && SingboxController.serviceMode != targetMode) {
            val currentService = if (SingboxController.serviceMode == "proxy") {
                MeowProxyService::class.java
            } else {
                MeowVpnService::class.java
            }
            val stopRequestedAtMillis = System.currentTimeMillis()
            val cleanupTargets = runtimeCleanupTargets(currentService)
            MeowDiagnostics.log(
                TAG,
                "issuing ACTION_STOP for mode switch currentMode=${SingboxController.serviceMode} targetMode=$targetMode currentService=${currentService.simpleName}",
            )
            MeowBoxService.requestStopForMode(
                SingboxController.serviceMode,
                "mode_switch_to_$targetMode",
            )
            startService(
                Intent(this, currentService)
                    .setAction(MeowBoxService.ACTION_STOP)
                    .putExtra(MeowBoxService.EXTRA_STOP_REASON, "mode_switch_to_$targetMode"),
            )
            SingboxController.awaitStopped { stopped ->
                if (!stopped) {
                    val cleaned = cleanupStoppedRuntimeState(
                        reason = "mode_switch_to_$targetMode",
                        source = "await_timeout",
                        stopRequestedAtMillis = stopRequestedAtMillis,
                        targets = cleanupTargets,
                        force = true,
                    )
                    if (!cleaned) {
                        SingboxController.log(
                            "error",
                            "mode switch aborted: previous VPN stop was not confirmed target=$targetMode",
                        )
                        MeowDiagnostics.log(
                            TAG,
                            "mode switch start blocked target=$targetMode running=${SingboxController.running} " +
                                "activeOwner=${MeowBoxService.hasActiveRuntimeOwner()}",
                        )
                        return@awaitStopped
                    }
                }
                val serviceIntent = Intent(this, targetService).setAction(MeowBoxService.ACTION_START)
                Log.i(TAG, "starting target service after mode switch target=${targetService.simpleName} stopped=$stopped")
                MeowDiagnostics.log(
                    TAG,
                    "starting target service after mode switch target=${targetService.simpleName} stopped=$stopped",
                )
                startForegroundService(serviceIntent)
            }
        } else {
            val serviceIntent = Intent(this, targetService).setAction(MeowBoxService.ACTION_START)
            Log.i(TAG, "starting target service target=${targetService.simpleName}")
            MeowDiagnostics.log(TAG, "starting target service target=${targetService.simpleName}")
            startForegroundService(serviceIntent)
        }
        result.success(true)
    }

    private fun dispatchApplyConfigAfterConfigWrite(
        useVpn: Boolean,
        restartCore: Boolean,
        result: MethodChannel.Result,
    ) {
        val dnsCacheClearPending = PersistentDnsCache.isClearPending(
            MeowApplication.singboxWorkingDirectory,
        )
        val effectiveRestartCore = restartCore || dnsCacheClearPending
        val targetMode = if (useVpn) "vpn" else "proxy"
        val serviceClass = if (useVpn) MeowVpnService::class.java else MeowProxyService::class.java
        Log.i(
            TAG,
            "applyConfig useVpn=$useVpn restartCore=$effectiveRestartCore dnsCacheClearPending=$dnsCacheClearPending running=${SingboxController.running} mode=${SingboxController.serviceMode} target=${serviceClass.simpleName}",
        )
        SingboxController.log(
            "info",
            "android applyConfig requested useVpn=$useVpn restartCore=$effectiveRestartCore " +
                "dnsCacheClearPending=$dnsCacheClearPending " +
                "running=${SingboxController.running} mode=${SingboxController.serviceMode}",
        )
        MeowDiagnostics.log(
            TAG,
            "applyConfig useVpn=$useVpn restartCore=$effectiveRestartCore dnsCacheClearPending=$dnsCacheClearPending running=${SingboxController.running} mode=${SingboxController.serviceMode} target=${serviceClass.simpleName}",
        )
        if (SingboxController.running && SingboxController.serviceMode == targetMode) {
            if (effectiveRestartCore) {
                startService(Intent(this, serviceClass).setAction(MeowBoxService.ACTION_RESTART_CORE))
                result.success(true)
            } else {
                SingboxController.reloadService { reloadResult ->
                    reloadResult.onSuccess {
                        result.success(true)
                    }.onFailure {
                        result.error("reload_failed", it.message, null)
                    }
                }
            }
        } else {
            val serviceIntent = Intent(this, serviceClass).setAction(MeowBoxService.ACTION_START)
            startForegroundService(serviceIntent)
            result.success(true)
        }
    }

    private fun writeQuickSettingsTileLabel(label: String?) {
        val normalized = label?.trim().orEmpty()
        val target = File(filesDir, QUICK_TILE_LABEL_FILE)
        runCatching {
            if (normalized.isEmpty()) {
                if (target.exists() && !target.delete()) {
                    Log.w(TAG, "failed to clear quick tile label ${target.absolutePath}")
                }
            } else {
                target.writeText(normalized, Charsets.UTF_8)
            }
            MeowQuickSettingsTileService.requestRefresh(this)
        }.onFailure { error ->
            Log.w(TAG, "failed to write quick tile label", error)
        }
    }

    private fun getHappCrypt5Support(): Map<String, Any> {
        val requiredAssets = listOf(
            "assets/happ_crypto/selectors.json",
            "assets/happ_crypto/expanded_rsa_keys.json",
            "assets/happ_crypto/crypt51_rsa_keys.json",
            "assets/happ_crypto/native_rsa_keys.json",
        )
        val missingAssets = requiredAssets.filterNot { assetPath ->
            runCatching {
                assets.open("flutter_assets/$assetPath").use { input ->
                    input.read() != -1
                }
            }.getOrDefault(false)
        }
        val supported = missingAssets.isEmpty()
        return linkedMapOf(
            "supported" to supported,
            "detail" to if (supported) {
                "Happ crypt5 compatibility assets are bundled."
            } else {
                "Happ crypt5 compatibility assets are unavailable in this build."
            },
            "abi" to Build.SUPPORTED_ABIS.firstOrNull().orEmpty(),
            "abis" to Build.SUPPORTED_ABIS.toList(),
            "missingAssets" to missingAssets,
        )
    }

    private fun buildPerformanceSnapshot(): Map<String, Any?> {
        val memoryInfo = ActivityManager.MemoryInfo()
        val activityManager = getSystemService(ActivityManager::class.java)
        activityManager.getMemoryInfo(memoryInfo)
        val processMemory = OwnProcessMemory.capture()
        val runtime = Runtime.getRuntime()
        val snapshotUptimeMs = SystemClock.elapsedRealtime()
        val processCpuMs = android.os.Process.getElapsedCpuTime()
        val processCpuPercent = if (lastPerformanceSnapshotUptimeMs > 0L) {
            val wallDeltaMs = snapshotUptimeMs - lastPerformanceSnapshotUptimeMs
            val cpuDeltaMs = processCpuMs - lastPerformanceSnapshotCpuMs
            if (wallDeltaMs > 0L && cpuDeltaMs >= 0L) {
                cpuDeltaMs.toDouble() * 100.0 / wallDeltaMs.toDouble()
            } else {
                null
            }
        } else {
            null
        }
        lastPerformanceSnapshotUptimeMs = snapshotUptimeMs
        lastPerformanceSnapshotCpuMs = processCpuMs
        val batteryIntent = registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED),
        )
        val batteryTemperatureTenths = batteryIntent
            ?.getIntExtra("temperature", Int.MIN_VALUE)
            ?: Int.MIN_VALUE
        return linkedMapOf(
            "pid" to android.os.Process.myPid(),
            "wakeLockEnabled" to MeowApplication.wakeLockEnabled,
            "networkHeartbeatEnabled" to MeowApplication.networkHeartbeatEnabled,
            "networkHeartbeatIntervalSeconds" to MeowApplication.networkHeartbeatIntervalSeconds,
            "memoryLimitEnabled" to MeowApplication.memoryLimitEnabled,
            "goMemoryLimitBytes" to MeowApplication.appliedGoMemoryLimitBytes,
            "serviceState" to MeowApplication.describeRecordedServiceState(),
            "runtimeIntent" to MeowApplication.describeRuntimeIntent(),
            "totalPssKb" to processMemory.totalPssKb,
            "totalRssKb" to processMemory.totalRssKb,
            "totalSwapPssKb" to processMemory.totalSwapPssKb,
            "totalSwapKb" to processMemory.totalSwapKb,
            "totalPrivateDirtyKb" to processMemory.totalPrivateDirtyKb,
            "dalvikPssKb" to processMemory.dalvikPssKb,
            "nativePssKb" to processMemory.nativePssKb,
            "otherPssKb" to processMemory.otherPssKb,
            "graphicsPssKb" to processMemory.graphicsPssKb,
            "codePssKb" to processMemory.codePssKb,
            "stackPssKb" to processMemory.stackPssKb,
            "privateOtherPssKb" to processMemory.privateOtherPssKb,
            "systemPssKb" to processMemory.systemPssKb,
            "nativeHeapAllocatedKb" to processMemory.nativeHeapAllocatedKb,
            "nativeHeapSizeKb" to processMemory.nativeHeapSizeKb,
            "javaHeapUsedKb" to ((runtime.totalMemory() - runtime.freeMemory()) / 1024L),
            "javaHeapMaxKb" to (runtime.maxMemory() / 1024L),
            "coreMemoryBytes" to SingboxController.coreMemoryBytes,
            "coreGoroutines" to SingboxController.coreGoroutines,
            "connectionsIn" to SingboxController.connectionsIn,
            "connectionsOut" to SingboxController.connectionsOut,
            "processCpuPercent" to processCpuPercent,
            "systemAvailMemKb" to (memoryInfo.availMem / 1024L),
            "systemLowMemory" to memoryInfo.lowMemory,
            "batteryTemperatureC" to if (batteryTemperatureTenths == Int.MIN_VALUE) {
                null
            } else {
                batteryTemperatureTenths / 10.0
            },
        )
    }

    private fun runtimeStatusMap(): Map<String?, Any?> {
        val recordedState = MeowApplication.readServiceState()
        val runtimeIntent = MeowApplication.readRuntimeIntent()
        val recordedServiceAlive = MeowApplication.isRecordedServiceAlive()
        val activeRuntimeOwner = MeowBoxService.hasActiveRuntimeOwner(
            SingboxController.serviceMode.takeIf { it.isNotBlank() },
        )
        val nativeRecoveryPending =
            !SingboxController.running && (recordedServiceAlive || activeRuntimeOwner)
        return mapOf(
            "running" to SingboxController.running,
            "mode" to SingboxController.serviceMode,
            "runtimeGeneration" to SingboxController.activeRuntimeGeneration,
            "uplink" to SingboxController.uplink,
            "downlink" to SingboxController.downlink,
            "uplinkTotal" to SingboxController.uplinkTotal,
            "downlinkTotal" to SingboxController.downlinkTotal,
            "coreMemoryBytes" to SingboxController.coreMemoryBytes,
            "coreGoroutines" to SingboxController.coreGoroutines,
            "connectionsIn" to SingboxController.connectionsIn,
            "connectionsOut" to SingboxController.connectionsOut,
            "recordedServiceAlive" to recordedServiceAlive,
            "recordedServiceMode" to recordedState?.mode,
            "recordedServicePid" to recordedState?.pid,
            "recordedServiceUpdatedAtMillis" to recordedState?.updatedAtMillis,
            "recordedServiceState" to MeowApplication.describeRecordedServiceState(),
            "activeRuntimeOwner" to activeRuntimeOwner,
            "nativeRecoveryPending" to nativeRecoveryPending,
            // Status is intentionally read-only. Recovery belongs to explicit
            // stop/timeout paths so polling cannot interrupt a normal restart.
            "staleRuntimeStateCleaned" to false,
            "runtimeIntentFresh" to MeowApplication.isRuntimeIntentFresh(),
            "runtimeIntentMode" to runtimeIntent?.mode,
            "runtimeIntentReason" to runtimeIntent?.reason,
            "runtimeIntentPid" to runtimeIntent?.pid,
            "runtimeIntentUpdatedAtMillis" to runtimeIntent?.updatedAtMillis,
            "runtimeIntentState" to MeowApplication.describeRuntimeIntent(),
        )
    }

    private fun logsWithNativeDiagnostics(content: String): String {
        val nativeDiagnostics = MeowDiagnostics.readTail()
        val crashReport = MeowDiagnostics.readCrashReportTail()
        val oomReport = MeowDiagnostics.readLatestOomReportMetadata()
        val runtimeSnapshot = runCatching { runtimeStatusMap().toString() }.getOrDefault("unavailable")
        val splitSnapshot = MeowVpnPlatformInterface.describeLastTunPackages()
        return MeowLogSanitizer.redact(buildString {
            append(content)
            if (content.isNotBlank()) {
                append("\n\n")
            }
            append("# Runtime snapshot\n")
            append(runtimeSnapshot)
            append("\n# Split tunnel snapshot\n")
            append(splitSnapshot)
            if (nativeDiagnostics.isNotBlank()) {
                append("\n# Native diagnostics\n")
                append(nativeDiagnostics)
            }
            if (crashReport.isNotBlank()) {
                append("\n# Native crash report\n")
                append(crashReport)
            }
            if (oomReport.isNotBlank()) {
                append("\n# Latest OOM report\n")
                append(oomReport)
            }
        })
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val packageManager = packageManager
        val installedApps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getInstalledApplications(
                android.content.pm.PackageManager.ApplicationInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getInstalledApplications(0)
        }
        val launchIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val launcherApps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                launchIntent,
                android.content.pm.PackageManager.ResolveInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(launchIntent, 0)
        }
        val launchablePackages = launcherApps
            .mapNotNull { it.activityInfo?.packageName }
            .toMutableSet()
        val appsByPackage = linkedMapOf<String, ApplicationInfo>()
        for (appInfo in installedApps) {
            appsByPackage[appInfo.packageName] = appInfo
        }
        for (packageName in launchablePackages) {
            if (appsByPackage.containsKey(packageName)) {
                continue
            }
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    packageManager.getApplicationInfo(
                        packageName,
                        android.content.pm.PackageManager.ApplicationInfoFlags.of(0),
                    )
                } else {
                    @Suppress("DEPRECATION")
                    packageManager.getApplicationInfo(packageName, 0)
                }
            }.onSuccess { appInfo ->
                appsByPackage[appInfo.packageName] = appInfo
            }
        }
        return appsByPackage.values
            .asSequence()
            .filterNot { it.packageName == packageName }
            .map { appInfo ->
                val label = runCatching {
                    packageManager.getApplicationLabel(appInfo).toString().trim()
                }.getOrDefault(appInfo.packageName)
                val isSystem =
                    (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0 ||
                        (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
                linkedMapOf(
                    "packageName" to appInfo.packageName,
                    "label" to if (label.isNotEmpty()) label else appInfo.packageName,
                    "system" to isSystem,
                    "launchable" to (appInfo.packageName in launchablePackages),
                )
            }
            .sortedWith(
                compareByDescending<Map<String, Any>> { it["launchable"] == true }
                    .thenBy<Map<String, Any>> { it["system"] == true }
                    .thenBy(String.CASE_INSENSITIVE_ORDER) { it["label"]?.toString().orEmpty() }
                    .thenBy(String.CASE_INSENSITIVE_ORDER) { it["packageName"]?.toString().orEmpty() },
            )
            .toList()
    }

    private fun getInstalledAppIcon(packageName: String?, sizePx: Int?): ByteArray? {
        val normalizedPackage = packageName?.trim().orEmpty()
        if (!isAndroidPackageName(normalizedPackage) || normalizedPackage == this.packageName) {
            return null
        }
        val size = (sizePx ?: 48).coerceIn(24, 96)
        val icon = runCatching {
            packageManager.getApplicationIcon(normalizedPackage)
        }.getOrNull() ?: return null
        return renderDrawableToPng(icon, size)
    }

    private fun renderDrawableToPng(drawable: Drawable, size: Int): ByteArray? {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        return try {
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
            stream.toByteArray()
        } catch (error: Throwable) {
            MeowDiagnostics.log(TAG, "failed to render installed app icon", error)
            null
        } finally {
            bitmap.recycle()
        }
    }

    private fun isAndroidPackageName(value: String): Boolean =
        value.length <= 255 &&
            Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$").matches(value)

    /*
    private fun decodeHappCrypt5(link: String?, result: MethodChannel.Result) {
        val input = link?.trim().orEmpty()
        if (input.isBlank()) {
            result.error("empty_input", "Happ crypt5 link is empty", null)
            return
        }

        val serviceIntent = Intent(this, Crypto5IsolatedService::class.java).apply {
            putExtra(Crypto5IsolatedService.EXTRA_INPUT, input)
            putExtra(
                Crypto5IsolatedService.EXTRA_RECEIVER,
                object : ResultReceiver(mainHandler) {
                    override fun onReceiveResult(resultCode: Int, resultData: Bundle) {
                        if (resultCode == Crypto5IsolatedService.RESULT_SUCCESS) {
                            result.success(
                                resultData.getString(Crypto5IsolatedService.EXTRA_DECODED).orEmpty(),
                            )
                            return
                        }
                        result.error(
                            "decode_failed",
                            resultData.getString(Crypto5IsolatedService.EXTRA_ERROR)
                                ?: "Failed to decode Happ crypt5 link",
                            null,
                        )
                    }
                },
            )
        }

        try {
            val started = startService(serviceIntent)
            if (started == null) {
                result.error(
                    "service_unavailable",
                    "Happ crypt5 isolated service is unavailable",
                    null,
                )
            }
        } catch (error: Throwable) {
            result.error(
                "service_start_failed",
                error.message ?: error.toString(),
                null,
            )
        }
    }
    */

    private fun setupSingboxHostApi(binaryMessenger: BinaryMessenger) {
        SingboxHostApi.setUp(
            binaryMessenger,
            object : SingboxHostApi {
                override fun prepareVpn(
                    requiresVpn: Boolean,
                    callback: (Result<Boolean>) -> Unit,
                ) {
                    if (!requiresVpn) {
                        callback(Result.success(true))
                        return
                    }
                    val intent = VpnService.prepare(this@MainActivity)
                    Log.i(TAG, "prepareVpn requiresVpn=$requiresVpn granted=${intent == null}")
                    if (intent == null) {
                        callback(Result.success(true))
                    } else {
                        launchVpnPermission(intent, boolResult(callback))
                    }
                }

                override fun vpnPermissionStatus(callback: (Result<Map<String?, Any?>>) -> Unit) {
                    callback(Result.success(mapOf("granted" to (VpnService.prepare(this@MainActivity) == null))))
                }

                override fun start(config: String, useVpn: Boolean, callback: (Result<Unit>) -> Unit) {
                    if (config.isBlank()) {
                        callback(errorResult("empty_config", "Config is empty"))
                        return
                    }
                    val result = unitResult(callback)
                    writeConfigAndDispatch(config, result) {
                        dispatchStartAfterConfigWrite(useVpn, result)
                    }
                }

                override fun startPrepared(useVpn: Boolean, callback: (Result<Unit>) -> Unit) {
                    val result = unitResult(callback)
                    withPreparedConfig(result) {
                        dispatchStartAfterConfigWrite(useVpn, result)
                    }
                }

                override fun applyConfig(
                    config: String,
                    useVpn: Boolean,
                    restartCore: Boolean,
                    callback: (Result<Unit>) -> Unit,
                ) {
                    if (config.isBlank()) {
                        callback(errorResult("empty_config", "Config is empty"))
                        return
                    }
                    val result = unitResult(callback)
                    writeConfigAndDispatch(config, result) {
                        dispatchApplyConfigAfterConfigWrite(useVpn, restartCore, result)
                    }
                }

                override fun applyPreparedConfig(
                    useVpn: Boolean,
                    restartCore: Boolean,
                    callback: (Result<Unit>) -> Unit,
                ) {
                    val result = unitResult(callback)
                    withPreparedConfig(result) {
                        dispatchApplyConfigAfterConfigWrite(useVpn, restartCore, result)
                    }
                }

                override fun getConfigPath(callback: (Result<String>) -> Unit) {
                    callback(Result.success(MeowApplication.configFile.absolutePath))
                }

                override fun getRuntimeFlags(callback: (Result<Map<String?, Any?>>) -> Unit) {
                    callback(
                        Result.success(
                            mapOf(
                                "wakeLockEnabled" to MeowApplication.wakeLockEnabled,
                                "networkHeartbeatEnabled" to MeowApplication.networkHeartbeatEnabled,
                                "networkHeartbeatIntervalSeconds" to MeowApplication.networkHeartbeatIntervalSeconds,
                                "memoryLimitEnabled" to MeowApplication.memoryLimitEnabled,
                                "goMemoryLimitBytes" to MeowApplication.appliedGoMemoryLimitBytes,
                            ),
                        ),
                    )
                }

                override fun setRuntimeFlags(
                    flags: RuntimeFlagsMessage,
                    callback: (Result<Unit>) -> Unit,
                ) {
                    var heartbeatChanged = false
                    flags.wakeLockEnabled?.let { MeowApplication.wakeLockEnabled = it }
                    flags.networkHeartbeatEnabled?.let {
                        MeowApplication.networkHeartbeatEnabled = it
                        heartbeatChanged = true
                    }
                    flags.networkHeartbeatIntervalSeconds?.let {
                        MeowApplication.networkHeartbeatIntervalSeconds = it
                        heartbeatChanged = true
                    }
                    val memoryPolicyApplied = flags.memoryLimitEnabled?.let {
                        MeowApplication.updateMemoryLimitEnabled(it)
                    } ?: true
                    if (!memoryPolicyApplied) {
                        callback(Result.failure(IllegalStateException("Unable to apply Go memory limit")))
                        return
                    }
                    if (heartbeatChanged) {
                        MeowDefaultNetworkMonitor.refreshHeartbeat()
                    }
                    callback(Result.success(Unit))
                }

                override fun setRuntimeUiForeground(
                    foreground: Boolean,
                    callback: (Result<Unit>) -> Unit,
                ) {
                    SingboxController.setUiForeground(
                        foreground,
                        singboxEventSinkRegistration,
                    )
                    callback(Result.success(Unit))
                }

                override fun ensureNotificationPermission(
                    callback: (Result<Boolean>) -> Unit,
                ) {
                    ensureNotificationPermission(boolResult(callback))
                }

                override fun updateVpnNotificationPresentation(
                    presentation: VpnNotificationPresentationMessage,
                    callback: (Result<Unit>) -> Unit,
                ) {
                    MeowBoxService.updateNotificationPresentation(
                        notificationPresentationArguments(presentation),
                    )
                    callback(Result.success(Unit))
                }

                override fun reload(callback: (Result<Unit>) -> Unit) {
                    val serviceClass = when (SingboxController.serviceMode) {
                        "proxy" -> MeowProxyService::class.java
                        else -> MeowVpnService::class.java
                    }
                    startService(Intent(this@MainActivity, serviceClass).setAction(MeowBoxService.ACTION_RELOAD))
                    callback(Result.success(Unit))
                }

                override fun stop(reason: String, callback: (Result<Unit>) -> Unit) {
                    dispatchStopRuntime(reason) { stopped ->
                        if (stopped) {
                            callback(Result.success(Unit))
                        } else {
                            callback(errorResult("stop_timeout", "Native service stop timed out"))
                        }
                    }
                }

                override fun selectOutbound(
                    groupTag: String,
                    outboundTag: String,
                    callback: (Result<Unit>) -> Unit,
                ) {
                    val normalizedTag = outboundTag.trim()
                    if (normalizedTag.isEmpty()) {
                        callback(errorResult("missing_outbound", "Outbound tag is empty"))
                        return
                    }
                    SingboxController.selectOutbound(groupTag.ifBlank { "select" }, normalizedTag) { selectionResult ->
                        selectionResult
                            .onSuccess { callback(Result.success(Unit)) }
                            .onFailure { callback(errorResult("select_failed", it.message)) }
                    }
                }

                override fun urlTest(request: UrlTestRequestMessage, callback: (Result<Unit>) -> Unit) {
                    SingboxController.urlTest(
                        groupTag = request.groupTag.ifBlank { "select" },
                        targetOutboundTag = request.targetOutboundTag,
                        priorityOutboundTag = request.priorityOutboundTag,
                        excludeOutboundTag = request.excludeOutboundTag,
                        url = request.url,
                        timeoutMillis = request.timeoutMillis.toInt(),
                        concurrency = request.concurrency.toInt(),
                        deadlineMillis = request.deadlineMillis.toInt(),
                        force = request.force,
                    ) { urlTestResult ->
                        urlTestResult
                            .onSuccess { callback(Result.success(Unit)) }
                            .onFailure { callback(errorResult("urltest_failed", it.message)) }
                    }
                }

                override fun status(callback: (Result<Map<String?, Any?>>) -> Unit) {
                    callback(Result.success(runtimeStatusMap()))
                }

                override fun lookupOutboundExternalInfo(
                    outboundTag: String,
                    callback: (Result<Map<String?, Any?>>) -> Unit,
                ) {
                    val normalizedTag = outboundTag.trim()
                    if (normalizedTag.isEmpty()) {
                        callback(errorResult("lookup_outbound_external_info_failed", "Outbound tag is empty"))
                        return
                    }
                    SingboxController.lookupOutboundExternalInfo(normalizedTag) { lookupResult ->
                        lookupResult
                            .onSuccess { callback(Result.success(pigeonMap(it))) }
                            .onFailure { callback(errorResult("lookup_outbound_external_info_failed", it.message)) }
                    }
                }

                override fun getNetworkInterfaceState(
                    callback: (Result<NetworkInterfaceStateMessage>) -> Unit,
                ) {
                    val state = MeowDefaultNetworkMonitor.currentInterfaceState("host_api")
                    callback(
                        Result.success(
                            NetworkInterfaceStateMessage(
                                available = state.available,
                                interfaceName = state.interfaceName.ifBlank { null },
                                interfaceIndex = state.interfaceIndex.toLong(),
                                generation = state.generation,
                                reason = state.reason,
                                updatedAtMillis = state.updatedAtMillis,
                            ),
                        ),
                    )
                }

                override fun exportLogs(
                    content: String,
                    suggestedName: String,
                    callback: (Result<String?>) -> Unit,
                ) {
                    launchLogExport(
                        content,
                        suggestedName,
                        nullableStringResult(callback),
                    )
                }

                override fun canInstallApks(callback: (Result<Boolean>) -> Unit) {
                    callback(Result.success(canRequestApkInstalls()))
                }

                override fun openApkInstallSettings(callback: (Result<Boolean>) -> Unit) {
                    openApkInstallSettings(boolResult(callback))
                }

                override fun installDownloadedApk(callback: (Result<Unit>) -> Unit) {
                    runCatching { installDownloadedApk(unitResult(callback)) }
                        .onFailure {
                            callback(errorResult("install_apk_failed", it.message ?: it.toString()))
                        }
                }

                override fun inspectDownloadedApk(
                    path: String,
                    callback: (Result<ApkInspectionMessage>) -> Unit,
                ) {
                    val normalizedPath = path.trim()
                    if (normalizedPath.isEmpty()) {
                        callback(errorResult("missing_apk_path", "APK path is empty"))
                        return
                    }
                    ioExecutor.execute {
                        runCatching { apkInspectionMessage(inspectDownloadedApk(normalizedPath)) }
                            .onSuccess { inspection ->
                                mainHandler.post { callback(Result.success(inspection)) }
                            }
                            .onFailure { error ->
                                mainHandler.post {
                                    callback(errorResult("inspect_apk_failed", error.message ?: error.toString()))
                                }
                            }
                    }
                }

                override fun fetchUrlOnUnderlyingNetwork(
                    request: UnderlyingNetworkFetchRequestMessage,
                    callback: (Result<UnderlyingNetworkFetchResponseMessage>) -> Unit,
                ) {
                    val url = request.url.trim()
                    if (url.isEmpty()) {
                        callback(errorResult("missing_url", "URL is empty"))
                        return
                    }
                    val headers = request.headers
                        .mapNotNull { header ->
                            val name = header?.name?.trim().orEmpty()
                            if (name.isEmpty()) null else name to header?.value.orEmpty()
                        }
                        .toMap()
                    val maxBytes = request.maxBytes.coerceIn(1L, 32L * 1024L * 1024L).toInt()
                    val timeoutMs = request.timeoutMillis.coerceIn(3_000L, 60_000L).toInt()
                    subscriptionNetworkExecutor.execute {
                        runCatching {
                            underlyingNetworkFetchResponse(
                                fetchUrlOnUnderlyingNetwork(url, headers, maxBytes, timeoutMs),
                            )
                        }.onSuccess { response ->
                            mainHandler.post { callback(Result.success(response)) }
                        }.onFailure { error ->
                            mainHandler.post {
                                callback(errorResult("underlying_http_failed", error.message ?: error.toString()))
                            }
                        }
                    }
                }

                override fun downloadUrlOnUnderlyingNetwork(
                    request: UnderlyingNetworkDownloadRequestMessage,
                    callback: (Result<UnderlyingNetworkDownloadResponseMessage>) -> Unit,
                ) {
                    val url = request.url.trim()
                    val destinationPath = request.destinationPath.trim()
                    if (url.isEmpty()) {
                        callback(errorResult("missing_url", "URL is empty"))
                        return
                    }
                    if (destinationPath.isEmpty()) {
                        callback(errorResult("missing_destination", "Destination path is empty"))
                        return
                    }
                    val headers = request.headers
                        .mapNotNull { header ->
                            val name = header?.name?.trim().orEmpty()
                            if (name.isEmpty()) null else name to header?.value.orEmpty()
                        }
                        .toMap()
                    val maxBytes = request.maxBytes.coerceIn(1L, 512L * 1024L * 1024L)
                    val responseStartTimeoutMs = request.responseStartTimeoutMillis
                        .coerceIn(1_000L, 30_000L)
                        .toInt()
                    val idleTimeoutMs = request.idleTimeoutMillis
                        .coerceIn(1_000L, 60_000L)
                        .toInt()
                    subscriptionNetworkExecutor.execute {
                        runCatching {
                            underlyingNetworkDownloadResponse(
                                downloadUrlOnUnderlyingNetwork(
                                    url,
                                    headers,
                                    destinationPath,
                                    maxBytes,
                                    responseStartTimeoutMs,
                                    idleTimeoutMs,
                                ),
                            )
                        }.onSuccess { response ->
                            mainHandler.post { callback(Result.success(response)) }
                        }.onFailure { error ->
                            mainHandler.post {
                                callback(
                                    errorResult(
                                        "underlying_download_failed",
                                        error.message ?: error.toString(),
                                    ),
                                )
                            }
                        }
                    }
                }

                override fun resolveHostOnUnderlyingNetwork(
                    host: String,
                    callback: (Result<List<String?>>) -> Unit,
                ) {
                    val normalizedHost = host.trim()
                    if (normalizedHost.isEmpty()) {
                        callback(errorResult("missing_host", "Host is empty"))
                        return
                    }
                    endpointDnsExecutor.execute {
                        runCatching { resolveHostOnUnderlyingNetwork(normalizedHost) }
                            .onSuccess { addresses ->
                                mainHandler.post { callback(Result.success(addresses)) }
                            }
                            .onFailure { error ->
                                mainHandler.post {
                                    callback(
                                        errorResult(
                                            "underlying_dns_failed",
                                            error.message ?: error.toString(),
                                        ),
                                    )
                                }
                            }
                    }
                }

                override fun getAndroidId(callback: (Result<String>) -> Unit) {
                    callback(
                        Result.success(
                            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "",
                        ),
                    )
                }

                override fun getSubscriptionRequestDeviceInfo(callback: (Result<Map<String?, Any?>>) -> Unit) {
                    val locale = resources.configuration.locales?.get(0)?.language
                        ?: java.util.Locale.getDefault().language
                    callback(
                        Result.success(
                            mapOf(
                                "locale" to locale,
                                "os" to "Android",
                                "osVersion" to Build.VERSION.RELEASE,
                                "model" to Build.MODEL,
                                "androidId" to (Settings.Secure.getString(
                                    contentResolver,
                                    Settings.Secure.ANDROID_ID,
                                ) ?: ""),
                            ),
                        ),
                    )
                }

                override fun getPlatformDeviceInfo(callback: (Result<Map<String?, Any?>>) -> Unit) {
                    callback(
                        Result.success(
                            mapOf(
                                "manufacturer" to Build.MANUFACTURER,
                                "brand" to Build.BRAND,
                                "model" to Build.MODEL,
                                "sdkInt" to Build.VERSION.SDK_INT,
                                "release" to Build.VERSION.RELEASE,
                                "abi" to Build.SUPPORTED_ABIS.firstOrNull().orEmpty(),
                                "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
                            ),
                        ),
                    )
                }

                override fun getAppVersionInfo(callback: (Result<Map<String?, Any?>>) -> Unit) {
                    callback(Result.success(pigeonMap(getAppVersionInfo())))
                }

                override fun getCoreVersion(callback: (Result<String>) -> Unit) {
                    callback(Result.success(Libbox.version()))
                }

                override fun getCoreCapabilities(callback: (Result<String>) -> Unit) {
                    callback(Result.success(getEtonifyCoreCapabilities()))
                }

                override fun checkConfig(config: String, callback: (Result<Unit>) -> Unit) {
                    ioExecutor.execute {
                        runCatching { Libbox.checkConfig(config) }
                            .onSuccess {
                                mainHandler.post { callback(Result.success(Unit)) }
                            }
                            .onFailure { error ->
                                mainHandler.post {
                                    callback(errorResult("config_check_failed", error.message ?: error.toString()))
                                }
                            }
                    }
                }

                override fun getPerformanceSnapshot(callback: (Result<Map<String?, Any?>>) -> Unit) {
                    callback(Result.success(pigeonMap(buildPerformanceSnapshot())))
                }

                override fun startRuntimeMeasurement(
                    durationSeconds: Long,
                    callback: (Result<Unit>) -> Unit,
                ) {
                    RuntimeMeasurement.start(applicationContext, durationSeconds)
                    callback(Result.success(Unit))
                }

                override fun stopRuntimeMeasurement(callback: (Result<Unit>) -> Unit) {
                    RuntimeMeasurement.stop()
                    callback(Result.success(Unit))
                }

                override fun getRuntimeMeasurement(
                    callback: (Result<Map<String?, Any?>>) -> Unit,
                ) {
                    callback(Result.success(pigeonMap(RuntimeMeasurement.snapshot())))
                }

                override fun getRuntimeMeasurementReport(callback: (Result<String>) -> Unit) {
                    callback(Result.success(RuntimeMeasurement.report()))
                }

                override fun getHappCrypt5Support(callback: (Result<Map<String?, Any?>>) -> Unit) {
                    callback(Result.success(pigeonMap(getHappCrypt5Support())))
                }

                override fun getInstalledApps(callback: (Result<List<InstalledAppMessage?>>) -> Unit) {
                    Thread {
                        runCatching { installedAppMessages() }
                            .onSuccess { apps ->
                                mainHandler.post {
                                    callback(Result.success(apps))
                                }
                            }
                            .onFailure { error ->
                                mainHandler.post {
                                    callback(errorResult("get_installed_apps_failed", error.message ?: error.toString()))
                                }
                            }
                    }.start()
                }

                override fun getInstalledAppIcon(
                    packageName: String,
                    sizePx: Long,
                    callback: (Result<ByteArray?>) -> Unit,
                ) {
                    appIconExecutor.execute {
                        val iconBytes = getInstalledAppIcon(packageName, sizePx.toInt())
                        mainHandler.post { callback(Result.success(iconBytes)) }
                    }
                }

                override fun setQuickSettingsTileLabel(label: String, callback: (Result<Unit>) -> Unit) {
                    writeQuickSettingsTileLabel(label)
                    callback(Result.success(Unit))
                }
            },
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupSingboxHostApi(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            secureStorageMethodChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getOrCreateHiveDataKey" -> runCatching {
                    SecureHiveKeyProvider.getOrCreateDataKey(applicationContext)
                }.onSuccess(result::success).onFailure { error ->
                    result.error(
                        "secure_storage_key_failed",
                        error.message ?: error.toString(),
                        null,
                    )
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events == null) {
                        return
                    }
                    singboxEventSinkRegistration = SingboxController.registerEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    val registration = singboxEventSinkRegistration
                    singboxEventSinkRegistration = 0L
                    SingboxController.clearEventSink(registration)
                }
            },
        )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deepLinkEventChannelName,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    deepLinkEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    deepLinkEventSink = null
                }
            },
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deepLinkMethodChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialImportRequest" -> {
                    result.success(buildImportDeepLinkPayload(intent?.data))
                }
                else -> result.notImplemented()
            }
        }

        /*
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            happCryptoMethodChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "decodeCrypt5" -> decodeHappCrypt5(call.argument("link"), result)
                else -> result.notImplemented()
            }
        }
        */

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareVpn" -> {
                    val requiresVpn = call.argument<Boolean>("requiresVpn") ?: true
                    if (!requiresVpn) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    val intent = VpnService.prepare(this)
                    Log.i(TAG, "prepareVpn requiresVpn=$requiresVpn granted=${intent == null}")
                    if (intent == null) {
                        result.success(true)
                    } else {
                        launchVpnPermission(intent, result)
                    }
                }

                "vpnPermissionStatus" -> {
                    result.success(
                        mapOf(
                            "granted" to (VpnService.prepare(this) == null),
                        ),
                    )
                }

                "getPlatformDeviceInfo" -> {
                    result.success(
                        mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "brand" to Build.BRAND,
                            "model" to Build.MODEL,
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "release" to Build.VERSION.RELEASE,
                            "abi" to Build.SUPPORTED_ABIS.firstOrNull().orEmpty(),
                            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
                        ),
                    )
                }

                "getAppVersionInfo" -> {
                    result.success(getAppVersionInfo())
                }

                "getCoreVersion" -> {
                    result.success(Libbox.version())
                }

                "getCoreCapabilities" -> {
                    result.success(getEtonifyCoreCapabilities())
                }

                "checkConfig" -> {
                    val config = call.argument<String>("config").orEmpty()
                    ioExecutor.execute {
                        runCatching { Libbox.checkConfig(config) }
                            .onSuccess { mainHandler.post { result.success(null) } }
                            .onFailure { error ->
                                mainHandler.post {
                                    result.error("config_check_failed", error.message, null)
                                }
                            }
                    }
                }

                "getConfigPath" -> {
                    result.success(MeowApplication.configFile.absolutePath)
                }

                "getRuntimeFlags" -> {
                    result.success(
                        mapOf(
                            "wakeLockEnabled" to MeowApplication.wakeLockEnabled,
                            "networkHeartbeatEnabled" to MeowApplication.networkHeartbeatEnabled,
                            "networkHeartbeatIntervalSeconds" to MeowApplication.networkHeartbeatIntervalSeconds,
                            "memoryLimitEnabled" to MeowApplication.memoryLimitEnabled,
                            "goMemoryLimitBytes" to MeowApplication.appliedGoMemoryLimitBytes,
                        ),
                    )
                }

                "setRuntimeFlags" -> {
                    val wakeLock = call.argument<Boolean>("wakeLockEnabled")
                    val heartbeat = call.argument<Boolean>("networkHeartbeatEnabled")
                    val heartbeatInterval = call.argument<Int>("networkHeartbeatIntervalSeconds")
                    val memoryLimitEnabled = call.argument<Boolean>("memoryLimitEnabled")
                    var heartbeatChanged = false
                    if (wakeLock != null) {
                        MeowApplication.wakeLockEnabled = wakeLock
                    }
                    if (heartbeat != null) {
                        MeowApplication.networkHeartbeatEnabled = heartbeat
                        heartbeatChanged = true
                    }
                    if (heartbeatInterval != null) {
                        MeowApplication.networkHeartbeatIntervalSeconds = heartbeatInterval.toLong()
                        heartbeatChanged = true
                    }
                    if (memoryLimitEnabled != null) {
                        if (!MeowApplication.updateMemoryLimitEnabled(memoryLimitEnabled)) {
                            result.error(
                                "memory_limit_apply_failed",
                                "Unable to apply Go memory limit",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                    }
                    if (heartbeatChanged) {
                        MeowDefaultNetworkMonitor.refreshHeartbeat()
                    }
                    result.success(true)
                }

                "getPerformanceSnapshot" -> {
                    result.success(buildPerformanceSnapshot())
                }

                "startRuntimeMeasurement" -> {
                    val durationSeconds = call.argument<Number>("durationSeconds")?.toLong() ?: 60L
                    RuntimeMeasurement.start(applicationContext, durationSeconds)
                    result.success(null)
                }

                "stopRuntimeMeasurement" -> {
                    RuntimeMeasurement.stop()
                    result.success(null)
                }

                "getRuntimeMeasurement" -> {
                    result.success(RuntimeMeasurement.snapshot())
                }

                "getRuntimeMeasurementReport" -> {
                    result.success(RuntimeMeasurement.report())
                }

                "start" -> {
                    val config = call.argument<String>("config")
                    val useVpn = call.argument<Boolean>("useVpn") ?: true
                    if (config.isNullOrBlank()) {
                        result.error("empty_config", "Config is empty", null)
                        return@setMethodCallHandler
                    }
                    writeConfigAndDispatch(config, result) {
                        dispatchStartAfterConfigWrite(useVpn, result)
                    }
                }

                "startPrepared" -> {
                    val useVpn = call.argument<Boolean>("useVpn") ?: true
                    withPreparedConfig(result) {
                        dispatchStartAfterConfigWrite(useVpn, result)
                    }
                }

                "applyConfig" -> {
                    val config = call.argument<String>("config")
                    val useVpn = call.argument<Boolean>("useVpn") ?: true
                    val restartCore = call.argument<Boolean>("restartCore") ?: false
                    if (config.isNullOrBlank()) {
                        result.error("empty_config", "Config is empty", null)
                        return@setMethodCallHandler
                    }
                    writeConfigAndDispatch(config, result) {
                        dispatchApplyConfigAfterConfigWrite(useVpn, restartCore, result)
                    }
                }

                "applyPreparedConfig" -> {
                    val useVpn = call.argument<Boolean>("useVpn") ?: true
                    val restartCore = call.argument<Boolean>("restartCore") ?: false
                    withPreparedConfig(result) {
                        dispatchApplyConfigAfterConfigWrite(useVpn, restartCore, result)
                    }
                }

                "setQuickSettingsTileLabel" -> {
                    writeQuickSettingsTileLabel(call.argument("label"))
                    result.success(true)
                }

                "stop" -> {
                    val reason = call.argument<String>("reason") ?: "unspecified"
                    dispatchStopRuntime(reason) { stopped ->
                        if (stopped) {
                            result.success(true)
                        } else {
                            result.error("stop_timeout", "Native service stop timed out", null)
                        }
                    }
                }

                "reload" -> {
                    val serviceClass = when (SingboxController.serviceMode) {
                        "proxy" -> MeowProxyService::class.java
                        else -> MeowVpnService::class.java
                    }
                    startService(Intent(this, serviceClass).setAction(MeowBoxService.ACTION_RELOAD))
                    result.success(true)
                }

                "selectOutbound" -> {
                    val groupTag = call.argument<String>("groupTag") ?: "select"
                    val outboundTag = call.argument<String>("outboundTag")
                    if (outboundTag.isNullOrBlank()) {
                        result.error("missing_outbound", "Outbound tag is empty", null)
                        return@setMethodCallHandler
                    }
                    SingboxController.selectOutbound(groupTag, outboundTag) { selectionResult ->
                        selectionResult.onSuccess {
                            result.success(true)
                        }.onFailure {
                            result.error("select_failed", it.message, null)
                        }
                    }
                }

                "urlTest" -> {
                    val groupTag = call.argument<String>("groupTag") ?: "select"
                    SingboxController.urlTest(
                        groupTag = groupTag,
                        targetOutboundTag = call.argument<String>("targetOutboundTag").orEmpty(),
                        priorityOutboundTag = call.argument<String>("priorityOutboundTag").orEmpty(),
                        excludeOutboundTag = call.argument<String>("excludeOutboundTag").orEmpty(),
                        url = call.argument<String>("url").orEmpty(),
                        timeoutMillis = call.argument<Number>("timeoutMillis")?.toInt() ?: 3_000,
                        concurrency = call.argument<Number>("concurrency")?.toInt() ?: 0,
                        deadlineMillis = call.argument<Number>("deadlineMillis")?.toInt() ?: 10_000,
                        force = call.argument<Boolean>("force") ?: true,
                    ) { urlTestResult ->
                        urlTestResult.onSuccess {
                            result.success(true)
                        }.onFailure {
                            result.error("urltest_failed", it.message, null)
                        }
                    }
                }

                "status" -> {
                    result.success(runtimeStatusMap())
                }

                "lookupOutboundExternalInfo" -> {
                    val outboundTag = call.argument<String>("outboundTag")?.trim().orEmpty()
                    if (outboundTag.isEmpty()) {
                        result.error("lookup_outbound_external_info_failed", "Outbound tag is empty", null)
                        return@setMethodCallHandler
                    }
                    SingboxController.lookupOutboundExternalInfo(outboundTag) { lookupResult ->
                        lookupResult.onSuccess {
                            result.success(it)
                        }.onFailure {
                            result.error("lookup_outbound_external_info_failed", it.message, null)
                        }
                    }
                }

                "fetchUrlViaOutbound" -> {
                    val outboundTag = call.argument<String>("outboundTag")?.trim().orEmpty()
                    val url = call.argument<String>("url")?.trim().orEmpty()
                    val headers = (call.argument<Map<*, *>>("headers") ?: emptyMap<Any?, Any?>())
                        .entries
                        .mapNotNull { entry ->
                            val name = entry.key?.toString()?.trim().orEmpty()
                            if (name.isEmpty()) null else name to entry.value?.toString().orEmpty()
                        }
                        .toMap()
                    val maxBytes = (call.argument<Number>("maxBytes")?.toInt() ?: 0)
                        .coerceIn(1, 3 * 1024 * 1024)
                    val timeoutMillis = (call.argument<Number>("timeoutMillis")?.toInt() ?: 10_000)
                        .coerceIn(1_000, 60_000)
                    if (outboundTag.isEmpty() || url.isEmpty()) {
                        result.error("outbound_http_invalid", "Outbound tag or URL is empty", null)
                        return@setMethodCallHandler
                    }
                    SingboxController.fetchUrlViaOutbound(
                        outboundTag = outboundTag,
                        url = url,
                        headers = headers,
                        maxBytes = maxBytes,
                        timeoutMillis = timeoutMillis,
                    ) { fetchResult ->
                        fetchResult.onSuccess(result::success).onFailure { error ->
                            result.error("outbound_http_failed", error.message ?: error.toString(), null)
                        }
                    }
                }

                "getNetworkInterfaceState" -> {
                    val state = MeowDefaultNetworkMonitor.currentInterfaceState("method_channel")
                    result.success(
                        mapOf(
                            "available" to state.available,
                            "interfaceName" to state.interfaceName,
                            "interfaceIndex" to state.interfaceIndex,
                            "generation" to state.generation,
                            "reason" to state.reason,
                            "updatedAtMillis" to state.updatedAtMillis,
                        ),
                    )
                }

                "exportLogs" -> {
                    val content = call.argument<String>("content") ?: ""
                    val suggestedName = call.argument<String>("suggestedName")
                        ?: "meow-logs-${System.currentTimeMillis()}.txt"
                    launchLogExport(content, suggestedName, result)
                }

                "getAndroidId" -> {
                    result.success(
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "",
                    )
                }

                "getSubscriptionRequestDeviceInfo" -> {
                    val locale = resources.configuration.locales?.get(0)?.language
                        ?: java.util.Locale.getDefault().language
                    result.success(
                        mapOf(
                            "locale" to locale,
                            "os" to "Android",
                            "osVersion" to Build.VERSION.RELEASE,
                            "model" to Build.MODEL,
                            "androidId" to (Settings.Secure.getString(
                                contentResolver,
                                Settings.Secure.ANDROID_ID,
                            ) ?: ""),
                        ),
                    )
                }

                "getHappCrypt5Support" -> {
                    result.success(getHappCrypt5Support())
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchImportDeepLink(intent)
    }

    override fun onDestroy() {
        val registration = singboxEventSinkRegistration
        singboxEventSinkRegistration = 0L
        if (registration != 0L) {
            SingboxController.clearEventSink(registration)
        }
        deepLinkEventSink = null
        super.onDestroy()
    }
}
