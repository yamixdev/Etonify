import 'package:pigeon/pigeon.dart';

// Values shared by the native runtime event stream and its Dart consumer.
// Keeping them in the Pigeon contract prevents the two sides from silently
// drifting when a new event type is added or renamed.
const String runtimeEventClearLogs = 'clearLogs';
const String runtimeEventClient = 'client';
const String runtimeEventGroups = 'groups';
const String runtimeEventLogLevel = 'logLevel';
const String runtimeEventLogs = 'logs';
const String runtimeEventNativeLog = 'nativeLog';
const String runtimeEventNetwork = 'network';
const String runtimeEventState = 'state';
const String runtimeEventStatus = 'status';

// Wire values used by Flutter settings and the Android foreground service.
const String notificationTrafficModeSpeed = 'speed';
const String notificationTrafficModeTotal = 'total';
const String notificationTrafficModeBoth = 'both';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/singbox/singbox_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/com/etonify/meow_client/generated/SingboxApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.etonify.meow_client.generated'),
  ),
)
class RuntimeFlagsMessage {
  RuntimeFlagsMessage({
    this.wakeLockEnabled,
    this.networkHeartbeatEnabled,
    this.networkHeartbeatIntervalSeconds,
    this.memoryLimitEnabled,
  });

  bool? wakeLockEnabled;
  bool? networkHeartbeatEnabled;
  int? networkHeartbeatIntervalSeconds;
  bool? memoryLimitEnabled;
}

class NetworkInterfaceStateMessage {
  NetworkInterfaceStateMessage({
    required this.available,
    this.interfaceName,
    required this.interfaceIndex,
    required this.generation,
    this.reason,
    required this.updatedAtMillis,
  });

  bool available;
  String? interfaceName;
  int interfaceIndex;
  int generation;
  String? reason;
  int updatedAtMillis;
}

class UrlTestRequestMessage {
  UrlTestRequestMessage({
    required this.groupTag,
    required this.targetOutboundTag,
    required this.priorityOutboundTag,
    required this.excludeOutboundTag,
    required this.url,
    required this.timeoutMillis,
    required this.concurrency,
    required this.deadlineMillis,
    required this.force,
  });

  String groupTag;
  String targetOutboundTag;
  String priorityOutboundTag;
  String excludeOutboundTag;
  String url;
  int timeoutMillis;
  int concurrency;
  int deadlineMillis;
  bool force;
}

class VpnNotificationPresentationMessage {
  VpnNotificationPresentationMessage({
    required this.detailed,
    required this.trafficDisplayMode,
    required this.trafficRefreshSeconds,
    required this.title,
    this.latencyMillis,
    required this.groupTag,
    required this.targetOutboundTag,
    required this.priorityOutboundTag,
    required this.excludeOutboundTag,
    required this.url,
    required this.timeoutMillis,
    required this.concurrency,
    required this.deadlineMillis,
    required this.connectedText,
    required this.checkingText,
    required this.unavailableText,
    required this.totalLabel,
    required this.refreshLabel,
    required this.stopLabel,
  });

  bool detailed;
  String trafficDisplayMode;
  int trafficRefreshSeconds;
  String title;
  int? latencyMillis;
  String groupTag;
  String targetOutboundTag;
  String priorityOutboundTag;
  String excludeOutboundTag;
  String url;
  int timeoutMillis;
  int concurrency;
  int deadlineMillis;
  String connectedText;
  String checkingText;
  String unavailableText;
  String totalLabel;
  String refreshLabel;
  String stopLabel;
}

class HttpHeaderMessage {
  HttpHeaderMessage({required this.name, required this.value});

  String name;
  String value;
}

class UnderlyingNetworkFetchRequestMessage {
  UnderlyingNetworkFetchRequestMessage({
    required this.url,
    required this.headers,
    required this.maxBytes,
    required this.timeoutMillis,
  });

  String url;
  List<HttpHeaderMessage?> headers;
  int maxBytes;
  int timeoutMillis;
}

class UnderlyingNetworkFetchResponseMessage {
  UnderlyingNetworkFetchResponseMessage({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.finalUrl,
    required this.network,
  });

  int statusCode;
  String body;
  List<HttpHeaderMessage?> headers;
  String finalUrl;
  String network;
}

class OutboundFetchRequestMessage {
  OutboundFetchRequestMessage({
    required this.outboundTag,
    required this.url,
    required this.headers,
    required this.maxBytes,
    required this.timeoutMillis,
  });

  String outboundTag;
  String url;
  List<HttpHeaderMessage?> headers;
  int maxBytes;
  int timeoutMillis;
}

class UnderlyingNetworkDownloadRequestMessage {
  UnderlyingNetworkDownloadRequestMessage({
    required this.url,
    required this.headers,
    required this.destinationPath,
    required this.maxBytes,
    required this.responseStartTimeoutMillis,
    required this.idleTimeoutMillis,
  });

  String url;
  List<HttpHeaderMessage?> headers;
  String destinationPath;
  int maxBytes;
  int responseStartTimeoutMillis;
  int idleTimeoutMillis;
}

class UnderlyingNetworkDownloadResponseMessage {
  UnderlyingNetworkDownloadResponseMessage({
    required this.statusCode,
    required this.downloadedBytes,
    required this.headers,
    required this.finalUrl,
    required this.network,
  });

  int statusCode;
  int downloadedBytes;
  List<HttpHeaderMessage?> headers;
  String finalUrl;
  String network;
}

class ApkInspectionMessage {
  ApkInspectionMessage({
    required this.valid,
    required this.packageName,
    required this.installedPackageName,
    required this.versionName,
    required this.versionCode,
    required this.minSdk,
    required this.targetSdk,
    required this.deviceSdk,
    required this.signingCertificateSha256,
    required this.installedCertificateSha256,
  });

  bool valid;
  String packageName;
  String installedPackageName;
  String versionName;
  int versionCode;
  int minSdk;
  int targetSdk;
  int deviceSdk;
  List<String?> signingCertificateSha256;
  List<String?> installedCertificateSha256;
}

class InstalledAppMessage {
  InstalledAppMessage({
    required this.packageName,
    required this.label,
    required this.system,
    required this.launchable,
  });

  String packageName;
  String label;
  bool system;
  bool launchable;
}

@HostApi()
abstract class SingboxHostApi {
  @async
  bool prepareVpn(bool requiresVpn);

  @async
  Map<String?, Object?> vpnPermissionStatus();

  @async
  void start(String config, bool useVpn);

  @async
  void startPrepared(bool useVpn);

  @async
  void applyConfig(String config, bool useVpn, bool restartCore);

  @async
  void applyPreparedConfig(bool useVpn, bool restartCore);

  @async
  String getConfigPath();

  @async
  Map<String?, Object?> getRuntimeFlags();

  @async
  void setRuntimeFlags(RuntimeFlagsMessage flags);

  @async
  void setRuntimeUiForeground(bool foreground);

  @async
  bool ensureNotificationPermission();

  @async
  void updateVpnNotificationPresentation(
    VpnNotificationPresentationMessage presentation,
  );

  @async
  void reload();

  @async
  void stop(String reason);

  @async
  void selectOutbound(String groupTag, String outboundTag);

  @async
  void urlTest(UrlTestRequestMessage request);

  @async
  Map<String?, Object?> status();

  @async
  Map<String?, Object?> lookupOutboundExternalInfo(String outboundTag);

  @async
  NetworkInterfaceStateMessage getNetworkInterfaceState();

  @async
  String? exportLogs(String content, String suggestedName);

  @async
  bool canInstallApks();

  @async
  bool openApkInstallSettings();

  @async
  void installDownloadedApk();

  @async
  ApkInspectionMessage inspectDownloadedApk(String path);

  @async
  Map<String?, Object?> fetchUrlViaOutbound(
    OutboundFetchRequestMessage request,
  );

  @async
  UnderlyingNetworkFetchResponseMessage fetchUrlOnUnderlyingNetwork(
    UnderlyingNetworkFetchRequestMessage request,
  );

  @async
  UnderlyingNetworkDownloadResponseMessage downloadUrlOnUnderlyingNetwork(
    UnderlyingNetworkDownloadRequestMessage request,
  );

  @async
  List<String?> resolveHostOnUnderlyingNetwork(String host);

  @async
  String getAndroidId();

  @async
  Map<String?, Object?> getSubscriptionRequestDeviceInfo();

  @async
  Map<String?, Object?> getPlatformDeviceInfo();

  @async
  Map<String?, Object?> getAppVersionInfo();

  @async
  String getCoreVersion();

  @async
  String getCoreCapabilities();

  @async
  void checkConfig(String config);

  @async
  Map<String?, Object?> getPerformanceSnapshot();

  @async
  void startRuntimeMeasurement(int durationSeconds);

  @async
  void stopRuntimeMeasurement();

  @async
  Map<String?, Object?> getRuntimeMeasurement();

  @async
  String getRuntimeMeasurementReport();

  @async
  Map<String?, Object?> getHappCrypt5Support();

  @async
  List<InstalledAppMessage?> getInstalledApps();

  @async
  Uint8List? getInstalledAppIcon(String packageName, int sizePx);

  @async
  void setQuickSettingsTileLabel(String label);
}
