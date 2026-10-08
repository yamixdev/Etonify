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
const String runtimeEventUrlTest = 'urlTest';

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
    required this.mode,
    required this.includeOutboundTags,
    required this.logicalSessionId,
    required this.physicalNetworkEpoch,
    this.startupLeaseToken = 0,
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
  String mode;
  List<String> includeOutboundTags;
  String logicalSessionId;
  int physicalNetworkEpoch;
  int startupLeaseToken;
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
  @asyncCallback
  bool prepareVpn(bool requiresVpn);

  @asyncCallback
  Map<String?, Object?> vpnPermissionStatus();

  @asyncCallback
  void start(String config, bool useVpn);

  @asyncCallback
  void startPrepared(bool useVpn);

  @asyncCallback
  void startProbe(String config);

  @asyncCallback
  void stopProbe();

  @asyncCallback
  void applyConfig(String config, bool useVpn, bool restartCore);

  @asyncCallback
  void applyPreparedConfig(bool useVpn, bool restartCore);

  @asyncCallback
  String getConfigPath();

  @asyncCallback
  Map<String?, Object?> getRuntimeFlags();

  @asyncCallback
  void setRuntimeFlags(RuntimeFlagsMessage flags);

  @asyncCallback
  void setRuntimeUiForeground(bool foreground);

  @asyncCallback
  bool ensureNotificationPermission();

  @asyncCallback
  void updateVpnNotificationPresentation(
    VpnNotificationPresentationMessage presentation,
  );

  @asyncCallback
  void reload();

  @asyncCallback
  void stop(String reason);

  @asyncCallback
  void selectOutbound(String groupTag, String outboundTag);

  @asyncCallback
  void urlTest(UrlTestRequestMessage request);

  /// Shares the tile's one startup leaf measurement with the client sweep.
  @asyncCallback
  Map<String?, Object?> prepareStartupUrlTest(
    int runtimeGeneration,
    List<String> coveredTags,
  );

  @asyncCallback
  void cancelUrlTest(String groupTag, String targetOutboundTag);

  @asyncCallback
  Map<String?, Object?> status();

  @asyncCallback
  Map<String?, Object?> lookupOutboundExternalInfo(String outboundTag);

  @asyncCallback
  NetworkInterfaceStateMessage getNetworkInterfaceState();

  @asyncCallback
  String? exportLogs(String content, String suggestedName);

  @asyncCallback
  bool canInstallApks();

  @asyncCallback
  bool openApkInstallSettings();

  @asyncCallback
  void installDownloadedApk();

  @asyncCallback
  ApkInspectionMessage inspectDownloadedApk(String path);

  @asyncCallback
  Map<String?, Object?> fetchUrlViaOutbound(
    OutboundFetchRequestMessage request,
  );

  @asyncCallback
  UnderlyingNetworkFetchResponseMessage fetchUrlOnUnderlyingNetwork(
    UnderlyingNetworkFetchRequestMessage request,
  );

  @asyncCallback
  UnderlyingNetworkDownloadResponseMessage downloadUrlOnUnderlyingNetwork(
    UnderlyingNetworkDownloadRequestMessage request,
  );

  @asyncCallback
  List<String?> resolveHostOnUnderlyingNetwork(String host);

  @asyncCallback
  String getAndroidId();

  @asyncCallback
  Map<String?, Object?> getSubscriptionRequestDeviceInfo();

  @asyncCallback
  Map<String?, Object?> getPlatformDeviceInfo();

  @asyncCallback
  Map<String?, Object?> getAppVersionInfo();

  @asyncCallback
  String getCoreVersion();

  @asyncCallback
  String getCoreCapabilities();

  @asyncCallback
  void checkConfig(String config);

  @asyncCallback
  Map<String?, Object?> getPerformanceSnapshot();

  @asyncCallback
  void startRuntimeMeasurement(int durationSeconds);

  @asyncCallback
  void stopRuntimeMeasurement();

  @asyncCallback
  Map<String?, Object?> getRuntimeMeasurement();

  @asyncCallback
  String getRuntimeMeasurementReport();

  @asyncCallback
  Map<String?, Object?> getHappCrypt5Support();

  @asyncCallback
  List<InstalledAppMessage?> getInstalledApps();

  @asyncCallback
  Uint8List? getInstalledAppIcon(String packageName, int sizePx);

  @asyncCallback
  void setQuickSettingsTileLabel(String label);
}
