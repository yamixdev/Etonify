import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/singbox/singbox_api.g.dart' as pigeon;

@visibleForTesting
List<Map<String, dynamic>> normalizePigeonMapListForTest(Object? value) {
  return SingboxRuntime.instance._normalizeMapList(value);
}

class RuntimeFlags {
  const RuntimeFlags({
    this.wakeLockEnabled = false,
    this.networkHeartbeatEnabled = true,
    this.networkHeartbeatIntervalSeconds = 180,
    this.memoryLimitEnabled = false,
    this.goMemoryLimitBytes = 0,
  });

  final bool wakeLockEnabled;
  final bool networkHeartbeatEnabled;
  final int networkHeartbeatIntervalSeconds;
  final bool memoryLimitEnabled;
  final int goMemoryLimitBytes;
}

class AppVersionInfo {
  const AppVersionInfo({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
  });

  final String packageName;
  final String versionName;
  final int versionCode;

  String get displayVersion {
    final normalized = versionName.trim();
    return normalized.isEmpty ? '0.3.3' : normalized;
  }

  int get updateBuildNumber => normalizeSplitApkVersionCode(versionCode);

  static int normalizeSplitApkVersionCode(int value) {
    if (value <= 0) return 0;
    final abiSplitBuildNumber = value % 1000;
    if (value >= 1000 && abiSplitBuildNumber > 0) {
      return abiSplitBuildNumber;
    }
    return value;
  }
}

class NetworkInterfaceSnapshot {
  const NetworkInterfaceSnapshot({
    required this.available,
    required this.interfaceName,
    required this.interfaceIndex,
    required this.generation,
    required this.reason,
    required this.updatedAtMillis,
  });

  static const unavailable = NetworkInterfaceSnapshot(
    available: false,
    interfaceName: '',
    interfaceIndex: -1,
    generation: 0,
    reason: 'unavailable',
    updatedAtMillis: 0,
  );

  final bool available;
  final String interfaceName;
  final int interfaceIndex;
  final int generation;
  final String reason;
  final int updatedAtMillis;

  bool get usable =>
      available && interfaceName.trim().isNotEmpty && interfaceIndex >= 0;
}

class SingboxRuntime {
  SingboxRuntime._();

  static final SingboxRuntime instance = SingboxRuntime._();

  static final pigeon.SingboxHostApi _hostApi = pigeon.SingboxHostApi();
  static const EventChannel _events = EventChannel(
    'meow_client/singbox_events',
  );

  Stream<Map<String, dynamic>> get events => _events
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));

  Map<String, dynamic> _normalizeMap(Object? value) {
    if (value is! Map) {
      return const {};
    }
    return <String, dynamic>{
      for (final entry in value.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }

  List<Map<String, dynamic>> _normalizeMapList(Object? value) {
    if (value is! Iterable) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map<dynamic, dynamic>>()
        .map(_normalizeMap)
        .toList(growable: false);
  }

  Future<bool> prepareVpn({required bool requiresVpn}) async {
    if (!Platform.isAndroid) {
      return !requiresVpn;
    }
    return _hostApi.prepareVpn(requiresVpn);
  }

  Future<bool> vpnPermissionGranted() async {
    if (!Platform.isAndroid) {
      return true;
    }
    final value = _normalizeMap(await _hostApi.vpnPermissionStatus());
    return value['granted'] == true;
  }

  Future<void> start({required String config, required bool useVpn}) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _hostApi.start(config, useVpn);
  }

  Future<void> startPrepared({required bool useVpn}) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _hostApi.startPrepared(useVpn);
  }

  Future<void> applyConfig({
    required String config,
    required bool useVpn,
    bool restartCore = false,
  }) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _hostApi.applyConfig(config, useVpn, restartCore);
  }

  Future<void> applyPreparedConfig({
    required bool useVpn,
    bool restartCore = false,
  }) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _hostApi.applyPreparedConfig(useVpn, restartCore);
  }

  Future<String?> getConfigPath() async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      final value = await _hostApi.getConfigPath();
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    } on MissingPluginException {
      return null;
    }
  }

  Future<RuntimeFlags> getRuntimeFlags() async {
    if (!Platform.isAndroid) {
      return const RuntimeFlags();
    }
    try {
      final value = _normalizeMap(await _hostApi.getRuntimeFlags());
      return RuntimeFlags(
        wakeLockEnabled: value['wakeLockEnabled'] == true,
        networkHeartbeatEnabled: value['networkHeartbeatEnabled'] != false,
        networkHeartbeatIntervalSeconds:
            (value['networkHeartbeatIntervalSeconds'] as num?)?.toInt() ?? 180,
        memoryLimitEnabled: value['memoryLimitEnabled'] == true,
        goMemoryLimitBytes:
            (value['goMemoryLimitBytes'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      return const RuntimeFlags();
    }
  }

  Future<void> setRuntimeFlags({
    bool? wakeLockEnabled,
    bool? networkHeartbeatEnabled,
    int? networkHeartbeatIntervalSeconds,
    bool? memoryLimitEnabled,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _hostApi.setRuntimeFlags(
        pigeon.RuntimeFlagsMessage(
          wakeLockEnabled: wakeLockEnabled,
          networkHeartbeatEnabled: networkHeartbeatEnabled,
          networkHeartbeatIntervalSeconds: networkHeartbeatIntervalSeconds,
          memoryLimitEnabled: memoryLimitEnabled,
        ),
      );
    } on MissingPluginException {
      // Ignore on builds without the Android platform bridge.
    }
  }

  Future<void> reload() {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _hostApi.reload();
  }

  Future<void> setRuntimeUiForeground(bool foreground) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _hostApi.setRuntimeUiForeground(foreground);
    } on MissingPluginException {
      // Keep non-Android and incomplete development hosts non-fatal.
    }
  }

  Future<bool> ensureNotificationPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      return await _hostApi.ensureNotificationPermission();
    } on MissingPluginException {
      return true;
    }
  }

  Future<void> updateVpnNotificationPresentation({
    required bool detailed,
    required String trafficDisplayMode,
    required int trafficRefreshSeconds,
    required String title,
    int? latencyMillis,
    required String groupTag,
    required String targetOutboundTag,
    required String priorityOutboundTag,
    required String excludeOutboundTag,
    required String url,
    required int timeoutMillis,
    required int concurrency,
    required int deadlineMillis,
    required String connectedText,
    required String checkingText,
    required String unavailableText,
    required String totalLabel,
    required String refreshLabel,
    required String stopLabel,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    final normalizedTrafficDisplayMode = switch (trafficDisplayMode) {
      pigeon.notificationTrafficModeTotal =>
        pigeon.notificationTrafficModeTotal,
      pigeon.notificationTrafficModeBoth => pigeon.notificationTrafficModeBoth,
      _ => pigeon.notificationTrafficModeSpeed,
    };
    try {
      await _hostApi.updateVpnNotificationPresentation(
        pigeon.VpnNotificationPresentationMessage(
          detailed: detailed,
          trafficDisplayMode: normalizedTrafficDisplayMode,
          trafficRefreshSeconds: trafficRefreshSeconds,
          title: title,
          latencyMillis: latencyMillis,
          groupTag: groupTag,
          targetOutboundTag: targetOutboundTag,
          priorityOutboundTag: priorityOutboundTag,
          excludeOutboundTag: excludeOutboundTag,
          url: url,
          timeoutMillis: timeoutMillis,
          concurrency: concurrency,
          deadlineMillis: deadlineMillis,
          connectedText: connectedText,
          checkingText: checkingText,
          unavailableText: unavailableText,
          totalLabel: totalLabel,
          refreshLabel: refreshLabel,
          stopLabel: stopLabel,
        ),
      );
    } on MissingPluginException {
      // Keep non-Android and incomplete development hosts non-fatal.
    }
  }

  Future<void> stop({String reason = 'unspecified'}) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _hostApi.stop(reason);
  }

  Future<void> selectOutbound({
    required String groupTag,
    required String outboundTag,
  }) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _hostApi.selectOutbound(groupTag, outboundTag);
  }

  Future<void> urlTest({
    required String groupTag,
    String targetOutboundTag = '',
    String priorityOutboundTag = '',
    String excludeOutboundTag = '',
    String url = '',
    int timeoutMillis = 3000,
    int concurrency = 0,
    int deadlineMillis = 10000,
    bool force = true,
  }) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _hostApi.urlTest(
      pigeon.UrlTestRequestMessage(
        groupTag: groupTag,
        targetOutboundTag: targetOutboundTag,
        priorityOutboundTag: priorityOutboundTag,
        excludeOutboundTag: excludeOutboundTag,
        url: url,
        timeoutMillis: timeoutMillis,
        concurrency: concurrency,
        deadlineMillis: deadlineMillis,
        force: force,
      ),
    );
  }

  Future<Map<String, dynamic>> status() async {
    if (!Platform.isAndroid) {
      return const {};
    }
    try {
      return _normalizeMap(await _hostApi.status());
    } on MissingPluginException {
      return const {};
    }
  }

  Future<Map<String, dynamic>> lookupOutboundExternalInfo({
    required String outboundTag,
  }) async {
    if (!Platform.isAndroid) {
      return const {};
    }
    final normalizedTag = outboundTag.trim();
    if (normalizedTag.isEmpty) {
      return const {};
    }
    try {
      return _normalizeMap(
        await _hostApi.lookupOutboundExternalInfo(normalizedTag),
      );
    } on MissingPluginException {
      return const {};
    }
  }

  Future<Map<String, dynamic>> fetchUrlViaOutbound({
    required String outboundTag,
    required Uri uri,
    required Map<String, String> headers,
    required int maxBytes,
    required Duration timeout,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Outbound HTTP fetch is only available on Android.',
      );
    }
    final normalizedTag = outboundTag.trim();
    final url = uri.toString().trim();
    if (normalizedTag.isEmpty || url.isEmpty) {
      return const <String, dynamic>{};
    }
    final raw = await _hostApi.fetchUrlViaOutbound(
      pigeon.OutboundFetchRequestMessage(
        outboundTag: normalizedTag,
        url: url,
        headers: headers.entries
            .map(
              (entry) =>
                  pigeon.HttpHeaderMessage(name: entry.key, value: entry.value),
            )
            .toList(growable: false),
        maxBytes: maxBytes,
        timeoutMillis: timeout.inMilliseconds,
      ),
    );
    return _normalizeMap(raw);
  }

  Future<NetworkInterfaceSnapshot> getNetworkInterfaceState() async {
    if (!Platform.isAndroid) {
      return NetworkInterfaceSnapshot.unavailable;
    }
    try {
      final state = await _hostApi.getNetworkInterfaceState();
      return NetworkInterfaceSnapshot(
        available: state.available,
        interfaceName: state.interfaceName?.trim() ?? '',
        interfaceIndex: state.interfaceIndex,
        generation: state.generation,
        reason: state.reason?.trim() ?? 'host_api',
        updatedAtMillis: state.updatedAtMillis,
      );
    } on MissingPluginException {
      return NetworkInterfaceSnapshot.unavailable;
    }
  }

  Future<String?> exportLogs({
    required String content,
    required String suggestedName,
  }) {
    if (!Platform.isAndroid) {
      return Future<String?>.value(null);
    }
    return _hostApi.exportLogs(content, suggestedName);
  }

  Future<bool> canInstallApks() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _hostApi.canInstallApks();
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openApkInstallSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _hostApi.openApkInstallSettings();
    } on MissingPluginException {
      // Ignore on non-Android bridge builds.
    }
  }

  Future<void> installDownloadedApk() async {
    if (!Platform.isAndroid) {
      return;
    }
    // Native code deliberately selects the sole APK from private files/updates.
    // The package installer never receives a path controlled by Flutter.
    await _hostApi.installDownloadedApk();
  }

  Future<Map<String, dynamic>> inspectDownloadedApk(String path) async {
    if (!Platform.isAndroid) {
      return const <String, dynamic>{'valid': true};
    }
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', 'APK path is empty');
    }
    final inspection = await _hostApi.inspectDownloadedApk(normalizedPath);
    return <String, dynamic>{
      'valid': inspection.valid,
      'packageName': inspection.packageName,
      'installedPackageName': inspection.installedPackageName,
      'versionName': inspection.versionName,
      'versionCode': inspection.versionCode,
      'minSdk': inspection.minSdk,
      'targetSdk': inspection.targetSdk,
      'deviceSdk': inspection.deviceSdk,
      'signingCertificateSha256': inspection.signingCertificateSha256,
      'installedCertificateSha256': inspection.installedCertificateSha256,
    };
  }

  Future<Map<String, dynamic>> fetchUrlOnUnderlyingNetwork({
    required Uri uri,
    required Map<String, String> headers,
    required int maxBytes,
    required Duration timeout,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Underlying-network HTTP is only available on Android.',
      );
    }
    final response = await _hostApi.fetchUrlOnUnderlyingNetwork(
      pigeon.UnderlyingNetworkFetchRequestMessage(
        url: uri.toString(),
        headers: headers.entries
            .map(
              (entry) =>
                  pigeon.HttpHeaderMessage(name: entry.key, value: entry.value),
            )
            .toList(growable: false),
        maxBytes: maxBytes,
        timeoutMillis: timeout.inMilliseconds,
      ),
    );
    return <String, dynamic>{
      'statusCode': response.statusCode,
      'body': response.body,
      'headers': <String, String>{
        for (final header in response.headers)
          if (header != null && header.name.trim().isNotEmpty)
            header.name.toLowerCase(): header.value,
      },
      'finalUrl': response.finalUrl,
      'network': response.network,
    };
  }

  Future<Map<String, dynamic>> downloadUrlOnUnderlyingNetwork({
    required Uri uri,
    required Map<String, String> headers,
    required String destinationPath,
    required int maxBytes,
    required Duration responseStartTimeout,
    required Duration idleTimeout,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Underlying-network downloads are only available on Android.',
      );
    }
    final normalizedDestination = destinationPath.trim();
    if (normalizedDestination.isEmpty) {
      throw ArgumentError.value(
        destinationPath,
        'destinationPath',
        'Destination path is empty',
      );
    }
    final response = await _hostApi.downloadUrlOnUnderlyingNetwork(
      pigeon.UnderlyingNetworkDownloadRequestMessage(
        url: uri.toString(),
        headers: headers.entries
            .map(
              (entry) =>
                  pigeon.HttpHeaderMessage(name: entry.key, value: entry.value),
            )
            .toList(growable: false),
        destinationPath: normalizedDestination,
        maxBytes: maxBytes,
        responseStartTimeoutMillis: responseStartTimeout.inMilliseconds,
        idleTimeoutMillis: idleTimeout.inMilliseconds,
      ),
    );
    return <String, dynamic>{
      'statusCode': response.statusCode,
      'downloadedBytes': response.downloadedBytes,
      'headers': <String, String>{
        for (final header in response.headers)
          if (header != null && header.name.trim().isNotEmpty)
            header.name.toLowerCase(): header.value,
      },
      'finalUrl': response.finalUrl,
      'network': response.network,
    };
  }

  Future<List<String>> resolveHostOnUnderlyingNetwork({
    required String host,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Underlying-network DNS is only available on Android.',
      );
    }
    final normalizedHost = host.trim();
    if (normalizedHost.isEmpty) {
      throw ArgumentError.value(host, 'host', 'Host is empty');
    }
    final addresses = await _hostApi
        .resolveHostOnUnderlyingNetwork(normalizedHost)
        .timeout(timeout);
    return addresses
        .whereType<String>()
        .map((address) => address.trim())
        .where((address) => address.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<String> getAndroidId() async {
    if (!Platform.isAndroid) {
      return '';
    }
    try {
      return await _hostApi.getAndroidId();
    } on MissingPluginException {
      return '';
    }
  }

  Future<Map<String, dynamic>> getSubscriptionRequestDeviceInfo() async {
    if (!Platform.isAndroid) {
      return const {};
    }
    try {
      return _normalizeMap(await _hostApi.getSubscriptionRequestDeviceInfo());
    } on MissingPluginException {
      return const {};
    }
  }

  Future<Map<String, dynamic>> getPlatformDeviceInfo() async {
    if (!Platform.isAndroid) {
      return const {};
    }
    try {
      return _normalizeMap(await _hostApi.getPlatformDeviceInfo());
    } on MissingPluginException {
      return const {};
    }
  }

  Future<AppVersionInfo> getAppVersionInfo() async {
    if (!Platform.isAndroid) {
      return const AppVersionInfo(
        packageName: '',
        versionName: '0.2.3',
        versionCode: 0,
      );
    }
    try {
      final value = _normalizeMap(await _hostApi.getAppVersionInfo());
      return AppVersionInfo(
        packageName: value['packageName']?.toString().trim() ?? '',
        versionName: value['versionName']?.toString().trim() ?? '',
        versionCode: int.tryParse(value['versionCode']?.toString() ?? '') ?? 0,
      );
    } on MissingPluginException {
      return const AppVersionInfo(
        packageName: '',
        versionName: '0.2.3',
        versionCode: 0,
      );
    }
  }

  Future<String?> getCoreVersion() async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      final value = await _hostApi.getCoreVersion();
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    } on MissingPluginException {
      return null;
    }
  }

  Future<LibboxCapabilities> getCoreCapabilities() async {
    if (!Platform.isAndroid) {
      return LibboxCapabilities.bundledLegacy;
    }
    try {
      final value = await _hostApi
          .getCoreCapabilities()
          .timeout(const Duration(seconds: 5));
      return LibboxCapabilities.parseStrict(value);
    } on TimeoutException {
      return LibboxCapabilities.incompatible;
    } on MissingPluginException {
      return LibboxCapabilities.incompatible;
    } on PlatformException {
      return LibboxCapabilities.incompatible;
    }
  }

  Future<void> checkConfig(String config) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _hostApi.checkConfig(config);
  }

  Future<Map<String, dynamic>> getPerformanceSnapshot() async {
    if (!Platform.isAndroid) {
      return const {};
    }
    try {
      return _normalizeMap(await _hostApi.getPerformanceSnapshot());
    } on MissingPluginException {
      return const {};
    }
  }

  Future<void> startRuntimeMeasurement({required int durationSeconds}) async {
    if (!Platform.isAndroid) return;
    final normalizedDuration = durationSeconds.clamp(15, 3600).toInt();
    try {
      await _hostApi.startRuntimeMeasurement(normalizedDuration);
    } on MissingPluginException {
      // The diagnostics panel is unavailable on older Android bridges.
    }
  }

  Future<void> stopRuntimeMeasurement() async {
    if (!Platform.isAndroid) return;
    try {
      await _hostApi.stopRuntimeMeasurement();
    } on MissingPluginException {
      // The diagnostics panel is unavailable on older Android bridges.
    }
  }

  Future<Map<String, dynamic>> getRuntimeMeasurement() async {
    if (!Platform.isAndroid) return const {};
    try {
      return _normalizeMap(await _hostApi.getRuntimeMeasurement());
    } on MissingPluginException {
      return const {};
    }
  }

  Future<String> getRuntimeMeasurementReport() async {
    if (!Platform.isAndroid) return '';
    try {
      final value = await _hostApi.getRuntimeMeasurementReport();
      return value.trim();
    } on MissingPluginException {
      return '';
    }
  }

  Future<Map<String, dynamic>> getHappCrypt5Support() async {
    if (!Platform.isAndroid) {
      return const {
        'supported': false,
        'detail': 'This platform is not supported.',
      };
    }
    try {
      return _normalizeMap(await _hostApi.getHappCrypt5Support());
    } on MissingPluginException {
      return const {
        'supported': false,
        'detail': 'Android bridge is unavailable.',
      };
    }
  }

  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    if (!Platform.isAndroid) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final apps = await _hostApi.getInstalledApps();
      return apps
          .whereType<pigeon.InstalledAppMessage>()
          .map(
            (app) => <String, dynamic>{
              'packageName': app.packageName,
              'label': app.label,
              'system': app.system,
              'launchable': app.launchable,
            },
          )
          .toList(growable: false);
    } on MissingPluginException {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Uint8List?> getInstalledAppIcon(
    String packageName, {
    int sizePx = 48,
  }) async {
    if (!Platform.isAndroid || packageName.trim().isEmpty) {
      return null;
    }
    try {
      return await _hostApi.getInstalledAppIcon(
        packageName.trim(),
        sizePx.clamp(24, 96).toInt(),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> setQuickSettingsTileLabel(String? label) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      final normalizedLabel = label?.trim() ?? '';
      await _hostApi.setQuickSettingsTileLabel(normalizedLabel);
    } on MissingPluginException {
      // Ignore on builds without the Android platform bridge.
    }
  }
}
