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
    this.performanceMode = 'cool',
    this.memoryLimitEnabled = true,
  });

  final bool wakeLockEnabled;
  final bool networkHeartbeatEnabled;
  final int networkHeartbeatIntervalSeconds;
  final String performanceMode;
  final bool memoryLimitEnabled;
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
    return normalized.isEmpty ? '0.3.0-beta.4' : normalized;
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

  static const MethodChannel _methods = MethodChannel('meow_client/singbox');
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
    return value.whereType<Map>().map(_normalizeMap).toList(growable: false);
  }

  Future<T> _withMethodChannelFallback<T>(
    Future<T> Function() hostCall,
    Future<T> Function() fallback,
  ) async {
    if (!Platform.isAndroid) {
      return fallback();
    }
    try {
      return await hostCall();
    } on MissingPluginException {
      return fallback();
    } on PlatformException catch (error) {
      if (error.code == 'channel-error') {
        return fallback();
      }
      rethrow;
    }
  }

  Future<bool> prepareVpn({required bool requiresVpn}) async {
    return _withMethodChannelFallback(
      () => _hostApi.prepareVpn(requiresVpn),
      () async {
        if (!Platform.isAndroid) {
          return !requiresVpn;
        }
        final granted = await _methods.invokeMethod<bool>('prepareVpn', {
          'requiresVpn': requiresVpn,
        });
        return granted ?? false;
      },
    );
  }

  Future<bool> vpnPermissionGranted() async {
    final value = await _withMethodChannelFallback<Map<String, dynamic>>(
      () async => _normalizeMap(await _hostApi.vpnPermissionStatus()),
      () async =>
          await _methods.invokeMapMethod<String, dynamic>(
            'vpnPermissionStatus',
          ) ??
          const {},
    );
    return value['granted'] == true;
  }

  Future<void> start({required String config, required bool useVpn}) {
    return _withMethodChannelFallback(
      () => _hostApi.start(config, useVpn),
      () => _methods.invokeMethod<void>('start', {
        'config': config,
        'useVpn': useVpn,
      }),
    );
  }

  Future<void> startPrepared({required bool useVpn}) {
    return _withMethodChannelFallback(
      () => _hostApi.startPrepared(useVpn),
      () => _methods.invokeMethod<void>('startPrepared', {'useVpn': useVpn}),
    );
  }

  Future<void> applyConfig({
    required String config,
    required bool useVpn,
    bool restartCore = false,
  }) {
    return _withMethodChannelFallback(
      () => _hostApi.applyConfig(config, useVpn, restartCore),
      () => _methods.invokeMethod<void>('applyConfig', {
        'config': config,
        'useVpn': useVpn,
        'restartCore': restartCore,
      }),
    );
  }

  Future<void> applyPreparedConfig({
    required bool useVpn,
    bool restartCore = false,
  }) {
    return _withMethodChannelFallback(
      () => _hostApi.applyPreparedConfig(useVpn, restartCore),
      () => _methods.invokeMethod<void>('applyPreparedConfig', {
        'useVpn': useVpn,
        'restartCore': restartCore,
      }),
    );
  }

  Future<String?> getConfigPath() async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      final value = await _withMethodChannelFallback<String?>(
        () => _hostApi.getConfigPath(),
        () => _methods.invokeMethod<String>('getConfigPath'),
      );
      final normalized = value?.trim() ?? '';
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
      final value = await _withMethodChannelFallback<Map<String, dynamic>>(
        () async => _normalizeMap(await _hostApi.getRuntimeFlags()),
        () async =>
            await _methods.invokeMapMethod<String, dynamic>(
              'getRuntimeFlags',
            ) ??
            const {},
      );
      return RuntimeFlags(
        wakeLockEnabled: value['wakeLockEnabled'] == true,
        networkHeartbeatEnabled: value['networkHeartbeatEnabled'] != false,
        networkHeartbeatIntervalSeconds:
            (value['networkHeartbeatIntervalSeconds'] as num?)?.toInt() ?? 180,
        performanceMode:
            value['performanceMode']?.toString().trim().isNotEmpty == true
            ? value['performanceMode'].toString()
            : 'cool',
        memoryLimitEnabled: value['memoryLimitEnabled'] != false,
      );
    } on MissingPluginException {
      return const RuntimeFlags();
    }
  }

  Future<void> setRuntimeFlags({
    bool? wakeLockEnabled,
    bool? networkHeartbeatEnabled,
    int? networkHeartbeatIntervalSeconds,
    String? performanceMode,
    bool? memoryLimitEnabled,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _withMethodChannelFallback(
        () => _hostApi.setRuntimeFlags(
          pigeon.RuntimeFlagsMessage(
            wakeLockEnabled: wakeLockEnabled,
            networkHeartbeatEnabled: networkHeartbeatEnabled,
            networkHeartbeatIntervalSeconds: networkHeartbeatIntervalSeconds,
            performanceMode: performanceMode,
            memoryLimitEnabled: memoryLimitEnabled,
          ),
        ),
        () {
          final args = <String, dynamic>{};
          if (wakeLockEnabled != null) {
            args['wakeLockEnabled'] = wakeLockEnabled;
          }
          if (networkHeartbeatEnabled != null) {
            args['networkHeartbeatEnabled'] = networkHeartbeatEnabled;
          }
          if (networkHeartbeatIntervalSeconds != null) {
            args['networkHeartbeatIntervalSeconds'] =
                networkHeartbeatIntervalSeconds;
          }
          if (performanceMode != null) {
            args['performanceMode'] = performanceMode;
          }
          if (memoryLimitEnabled != null) {
            args['memoryLimitEnabled'] = memoryLimitEnabled;
          }
          return _methods.invokeMethod<void>('setRuntimeFlags', args);
        },
      );
    } on MissingPluginException {
      // Ignore on builds without the Android platform bridge.
    }
  }

  Future<void> reload() => _withMethodChannelFallback(
    () => _hostApi.reload(),
    () => _methods.invokeMethod<void>('reload'),
  );

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
          refreshLabel: refreshLabel,
          stopLabel: stopLabel,
        ),
      );
    } on MissingPluginException {
      // Keep non-Android and incomplete development hosts non-fatal.
    }
  }

  Future<void> stop({String reason = 'unspecified'}) {
    return _withMethodChannelFallback(
      () => _hostApi.stop(reason),
      () => _methods.invokeMethod<void>('stop', {'reason': reason}),
    );
  }

  Future<void> selectOutbound({
    required String groupTag,
    required String outboundTag,
  }) {
    return _withMethodChannelFallback(
      () => _hostApi.selectOutbound(groupTag, outboundTag),
      () => _methods.invokeMethod<void>('selectOutbound', {
        'groupTag': groupTag,
        'outboundTag': outboundTag,
      }),
    );
  }

  Future<void> addOutbound({
    required String selectorTag,
    required String outboundJson,
  }) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _withMethodChannelFallback(
      () => _hostApi.addOutbound(selectorTag, outboundJson),
      () => _methods.invokeMethod<void>('addOutbound', {
        'selectorTag': selectorTag,
        'outboundJson': outboundJson,
      }),
    );
  }

  Future<void> removeOutbound({
    required String selectorTag,
    required String outboundTag,
  }) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _withMethodChannelFallback(
      () => _hostApi.removeOutbound(selectorTag, outboundTag),
      () => _methods.invokeMethod<void>('removeOutbound', {
        'selectorTag': selectorTag,
        'outboundTag': outboundTag,
      }),
    );
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
    return _withMethodChannelFallback(
      () async {
        await _hostApi.urlTest(
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
      },
      () async {
        await _methods.invokeMethod<void>('urlTest', {
          'groupTag': groupTag,
          'targetOutboundTag': targetOutboundTag,
          'priorityOutboundTag': priorityOutboundTag,
          'excludeOutboundTag': excludeOutboundTag,
          'url': url,
          'timeoutMillis': timeoutMillis,
          'concurrency': concurrency,
          'deadlineMillis': deadlineMillis,
          'force': force,
        });
      },
    );
  }

  Future<void> removeUrlTestOutbounds({
    required String groupTag,
    required Iterable<String> outboundTags,
  }) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    final normalizedGroupTag = groupTag.trim();
    final normalizedTags = outboundTags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    if (normalizedGroupTag.isEmpty || normalizedTags.isEmpty) {
      return Future<void>.value();
    }
    return _withMethodChannelFallback(
      () => _hostApi.removeUrlTestOutbounds(normalizedGroupTag, normalizedTags),
      () => _methods.invokeMethod<void>('removeUrlTestOutbounds', {
        'groupTag': normalizedGroupTag,
        'outboundTags': normalizedTags,
      }),
    );
  }

  Future<Map<String, dynamic>> status() async {
    return _withMethodChannelFallback(
      () async => _normalizeMap(await _hostApi.status()),
      () async =>
          await _methods.invokeMapMethod<String, dynamic>('status') ?? const {},
    );
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
      final value = await _withMethodChannelFallback<Map<String, dynamic>>(
        () async => _normalizeMap(
          await _hostApi.lookupOutboundExternalInfo(normalizedTag),
        ),
        () async =>
            await _methods.invokeMapMethod<String, dynamic>(
              'lookupOutboundExternalInfo',
              {'outboundTag': normalizedTag},
            ) ??
            const {},
      );
      return value;
    } on MissingPluginException {
      return const {};
    }
  }

  Future<NetworkInterfaceSnapshot> getNetworkInterfaceState() async {
    if (!Platform.isAndroid) {
      return NetworkInterfaceSnapshot.unavailable;
    }
    try {
      final value = await _withMethodChannelFallback<NetworkInterfaceSnapshot>(
        () async {
          final state = await _hostApi.getNetworkInterfaceState();
          return NetworkInterfaceSnapshot(
            available: state.available,
            interfaceName: state.interfaceName?.trim() ?? '',
            interfaceIndex: state.interfaceIndex,
            generation: state.generation,
            reason: state.reason?.trim() ?? 'host_api',
            updatedAtMillis: state.updatedAtMillis,
          );
        },
        () async {
          final raw =
              await _methods.invokeMapMethod<String, dynamic>(
                'getNetworkInterfaceState',
              ) ??
              const {};
          return NetworkInterfaceSnapshot(
            available: raw['available'] == true,
            interfaceName: raw['interfaceName']?.toString().trim() ?? '',
            interfaceIndex: (raw['interfaceIndex'] as num?)?.toInt() ?? -1,
            generation: (raw['generation'] as num?)?.toInt() ?? 0,
            reason: raw['reason']?.toString().trim() ?? 'method_channel',
            updatedAtMillis: (raw['updatedAtMillis'] as num?)?.toInt() ?? 0,
          );
        },
      );
      return value;
    } on MissingPluginException {
      return NetworkInterfaceSnapshot.unavailable;
    }
  }

  Future<String?> exportLogs({
    required String content,
    required String suggestedName,
  }) {
    return _withMethodChannelFallback(
      () => _hostApi.exportLogs(content, suggestedName),
      () => _methods.invokeMethod<String>('exportLogs', {
        'content': content,
        'suggestedName': suggestedName,
      }),
    );
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
    final value = await _withMethodChannelFallback<String?>(
      () => _hostApi.getAndroidId(),
      () => _methods.invokeMethod<String>('getAndroidId'),
    );
    return value ?? '';
  }

  Future<Map<String, dynamic>> getSubscriptionRequestDeviceInfo() async {
    final value = await _withMethodChannelFallback<Map<String, dynamic>>(
      () async =>
          _normalizeMap(await _hostApi.getSubscriptionRequestDeviceInfo()),
      () async =>
          await _methods.invokeMapMethod<String, dynamic>(
            'getSubscriptionRequestDeviceInfo',
          ) ??
          const {},
    );
    return value;
  }

  Future<Map<String, dynamic>> getPlatformDeviceInfo() async {
    if (!Platform.isAndroid) {
      return const {};
    }
    try {
      final value = await _withMethodChannelFallback<Map<String, dynamic>>(
        () async => _normalizeMap(await _hostApi.getPlatformDeviceInfo()),
        () async =>
            await _methods.invokeMapMethod<String, dynamic>(
              'getPlatformDeviceInfo',
            ) ??
            const {},
      );
      return value;
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
      final value = await _withMethodChannelFallback<Map<String, dynamic>>(
        () async => _normalizeMap(await _hostApi.getAppVersionInfo()),
        () async =>
            await _methods.invokeMapMethod<String, dynamic>(
              'getAppVersionInfo',
            ) ??
            const {},
      );
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
      final value = await _withMethodChannelFallback<String?>(
        () => _hostApi.getCoreVersion(),
        () => _methods.invokeMethod<String>('getCoreVersion'),
      );
      final normalized = value?.trim() ?? '';
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
      final value = await _withMethodChannelFallback<String?>(
        () => _hostApi.getCoreCapabilities(),
        () => _methods.invokeMethod<String>('getCoreCapabilities'),
      ).timeout(const Duration(seconds: 2));
      return LibboxCapabilities.parseOrLegacy(value);
    } on TimeoutException {
      return LibboxCapabilities.bundledLegacy;
    } on MissingPluginException {
      return LibboxCapabilities.bundledLegacy;
    } on PlatformException {
      return LibboxCapabilities.bundledLegacy;
    }
  }

  Future<void> checkConfig(String config) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    return _withMethodChannelFallback(
      () => _hostApi.checkConfig(config),
      () => _methods.invokeMethod<void>('checkConfig', {'config': config}),
    );
  }

  Future<Map<String, dynamic>> getPerformanceSnapshot() async {
    if (!Platform.isAndroid) {
      return const {};
    }
    try {
      final value = await _withMethodChannelFallback<Map<String, dynamic>>(
        () async => _normalizeMap(await _hostApi.getPerformanceSnapshot()),
        () async =>
            await _methods.invokeMapMethod<String, dynamic>(
              'getPerformanceSnapshot',
            ) ??
            const {},
      );
      return value;
    } on MissingPluginException {
      return const {};
    }
  }

  Future<void> startRuntimeMeasurement({required int durationSeconds}) async {
    if (!Platform.isAndroid) return;
    final normalizedDuration = durationSeconds.clamp(15, 3600).toInt();
    try {
      await _withMethodChannelFallback(
        () => _hostApi.startRuntimeMeasurement(normalizedDuration),
        () => _methods.invokeMethod<void>('startRuntimeMeasurement', {
          'durationSeconds': normalizedDuration,
        }),
      );
    } on MissingPluginException {
      // The diagnostics panel is unavailable on older Android bridges.
    }
  }

  Future<void> stopRuntimeMeasurement() async {
    if (!Platform.isAndroid) return;
    try {
      await _withMethodChannelFallback(
        _hostApi.stopRuntimeMeasurement,
        () => _methods.invokeMethod<void>('stopRuntimeMeasurement'),
      );
    } on MissingPluginException {
      // The diagnostics panel is unavailable on older Android bridges.
    }
  }

  Future<Map<String, dynamic>> getRuntimeMeasurement() async {
    if (!Platform.isAndroid) return const {};
    try {
      return await _withMethodChannelFallback<Map<String, dynamic>>(
        () async => _normalizeMap(await _hostApi.getRuntimeMeasurement()),
        () async =>
            await _methods.invokeMapMethod<String, dynamic>(
              'getRuntimeMeasurement',
            ) ??
            const {},
      );
    } on MissingPluginException {
      return const {};
    }
  }

  Future<String> getRuntimeMeasurementReport() async {
    if (!Platform.isAndroid) return '';
    try {
      return await _withMethodChannelFallback<String>(
        _hostApi.getRuntimeMeasurementReport,
        () => _methods
            .invokeMethod<String>('getRuntimeMeasurementReport')
            .then((value) => value ?? ''),
      );
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
      final value = await _withMethodChannelFallback<Map<String, dynamic>>(
        () async => _normalizeMap(await _hostApi.getHappCrypt5Support()),
        () async =>
            await _methods.invokeMapMethod<String, dynamic>(
              'getHappCrypt5Support',
            ) ??
            const {},
      );
      return value;
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
      await _withMethodChannelFallback(
        () => _hostApi.setQuickSettingsTileLabel(normalizedLabel),
        () => _methods.invokeMethod<void>('setQuickSettingsTileLabel', {
          'label': normalizedLabel,
        }),
      );
    } on MissingPluginException {
      // Ignore on builds without the Android platform bridge.
    }
  }
}
