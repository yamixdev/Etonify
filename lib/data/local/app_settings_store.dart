import 'dart:io' show InternetAddress, InternetAddressType, Platform;
import 'dart:math';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart';
import 'package:meow_client/data/local/hive_storage_diagnostics.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/data/update/app_update_channel.dart';
import 'package:meow_client/logging/app_log_store.dart';

import 'secure_hive_storage.dart';

enum AppThemePreference { system, light, dark, amoled }

enum TunImplementationPreference { mixed, system, gvisor }

enum InboundConnectionMode { vpn, proxy }

enum SplitRoutingMode { disabled, proxySelected, bypassSelected }

enum AppUpdateInstallMode { ask, manual, auto }

enum NotificationTrafficDisplayMode { speed, total, both }

enum TlsFragmentationMode { disabled, record, fragment }

const int maxSplitRoutingPackageCount = 128;
const String defaultUrlTestUrl = 'https://www.gstatic.com/generate_204';
const String defaultRussiaDnsDirectResolver = 'udp://77.88.8.8';
const String defaultProxyUsername = 'etonify';
const int proxyUsernameMaxLength = 64;
const int proxyPasswordLength = 24;

bool isValidProxyUsername(String value) {
  final normalized = value.trim();
  return normalized.isNotEmpty &&
      normalized.length <= proxyUsernameMaxLength &&
      !RegExp(r'[\s:\x00-\x1F\x7F]').hasMatch(normalized);
}

String normalizeProxyUsername(String value) {
  final normalized = value.trim();
  return isValidProxyUsername(normalized) ? normalized : defaultProxyUsername;
}

bool isValidProxyPassword(String value) {
  final normalized = value.trim();
  return normalized.length >= 16 &&
      normalized.length <= 128 &&
      !RegExp(r'\s').hasMatch(normalized);
}

String generateProxyPassword([Random? random]) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  final source = random ?? Random.secure();
  return List<String>.generate(
    proxyPasswordLength,
    (_) => alphabet[source.nextInt(alphabet.length)],
    growable: false,
  ).join();
}

String normalizeDnsResolverInput(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return normalized;
  }
  final lower = normalized.toLowerCase();
  if (lower.startsWith('udp://') ||
      lower.startsWith('tcp://') ||
      lower.startsWith('tls://') ||
      lower.startsWith('https://') ||
      lower == 'device://network') {
    return normalized;
  }
  if (RegExp(r'\s').hasMatch(normalized) ||
      normalized.contains('/') ||
      normalized.contains('?') ||
      normalized.contains('#') ||
      normalized.contains('@')) {
    return normalized;
  }

  final address = InternetAddress.tryParse(normalized);
  if (address?.type == InternetAddressType.IPv6) {
    return 'udp://[$normalized]';
  }

  final uri = Uri.tryParse('udp://$normalized');
  if (uri == null || uri.host.isEmpty || uri.path.isNotEmpty) {
    return normalized;
  }
  try {
    if (uri.hasPort) {
      uri.port;
    }
  } on FormatException {
    return normalized;
  }
  return 'udp://$normalized';
}

final RegExp _androidPackageNamePattern = RegExp(
  r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$',
);

bool isAndroidPackageName(String value) {
  final normalized = value.trim();
  return normalized.length <= 255 &&
      _androidPackageNamePattern.hasMatch(normalized);
}

List<String> normalizeSplitRoutingPackages(Iterable<String> values) {
  final normalized = <String>[];
  final seen = <String>{};
  for (final package in values) {
    final value = package.trim();
    if (value.isEmpty ||
        value == 'com.etonify.meow_client' ||
        !isAndroidPackageName(value) ||
        !seen.add(value)) {
      continue;
    }
    normalized.add(value);
    if (normalized.length >= maxSplitRoutingPackageCount) {
      break;
    }
  }
  return normalized;
}

class AppSettingsState {
  const AppSettingsState({
    this.coreConfigSchemaVersion = 0,
    required this.onboardingCompleted,
    this.acceptedLegalVersion = '',
    this.acceptedLegalAtMillis,
    required this.activeProfileId,
    required this.selectedProxyTag,
    this.proxySort = 'source',
    required this.localeCode,
    required this.themePreference,
    required this.accentColorHex,
    required this.hapticEnabled,
    this.statusNotificationEnabled = true,
    this.notificationTrafficDisplayMode = NotificationTrafficDisplayMode.speed,
    this.notificationTrafficRefreshSeconds = 2,
    required this.hideServerIp,
    required this.progressiveBlurEnabled,
    this.progressiveBlurConfigured = false,
    this.memoryLimitEnabled = true,
    this.memoryLimitWarningDismissed = false,
    this.updateInstallMode = AppUpdateInstallMode.ask,
    this.updateChannel = AppUpdateChannel.stable,
    this.tlsFragmentationMode = TlsFragmentationMode.disabled,
    this.allowUntrustedProxyCertificates = false,
    this.allowUntrustedSubscriptionCertificates = false,
    required this.vpnInboundEnabled,
    required this.vpnMtu,
    required this.vpnStrictRoute,
    required this.vpnTunImplementation,
    required this.proxyInboundEnabled,
    required this.proxyAllowLan,
    required this.proxyMixedListen,
    required this.proxyMixedPort,
    this.proxyUsername = defaultProxyUsername,
    this.proxyPassword = '',
    required this.dnsDirectPreset,
    required this.dnsDirectResolver,
    required this.dnsProxyPreset,
    required this.dnsProxyResolver,
    required this.dnsPreferIpv6,
    this.russiaDnsDirectResolver = defaultRussiaDnsDirectResolver,
    required this.urlTestUrl,
    required this.urlTestIntervalSeconds,
    required this.urlTestTimeoutSeconds,
    required this.urlTestConcurrency,
    required this.urlTestUnavailableCheckIntervalSeconds,
    required this.locationLookupLimit,
    required this.locationLookupTimeoutSeconds,
    required this.locationLookupConcurrency,
    required this.blockLeaks,
    required this.adBlockEnabled,
    required this.useRussiaRouteData,
    this.trafficRulePreset = TrafficRulePreset.none,
    required this.bypassLocalNetwork,
    required this.splitRoutingMode,
    required this.splitRoutingPackages,
    required this.singBoxLogLevel,
    required this.experimentalTcpFastOpen,
    required this.experimentalTcpMultiPath,
    required this.experimentalInterruptExistingConnections,
    required this.experimentalUrlTestStrictTolerance,
    this.experimentalFakeIpEnabled = false,
  });

  final int coreConfigSchemaVersion;
  final bool onboardingCompleted;
  final String acceptedLegalVersion;
  final int? acceptedLegalAtMillis;
  final String activeProfileId;
  final String selectedProxyTag;
  final String proxySort;
  final String localeCode;
  final AppThemePreference themePreference;
  final String accentColorHex; // e.g. "2D5BFF" or "default"
  final bool hapticEnabled;
  final bool statusNotificationEnabled;
  final NotificationTrafficDisplayMode notificationTrafficDisplayMode;
  final int notificationTrafficRefreshSeconds;
  final bool hideServerIp;
  final bool progressiveBlurEnabled;
  final bool progressiveBlurConfigured;
  final bool memoryLimitEnabled;
  final bool memoryLimitWarningDismissed;
  final AppUpdateInstallMode updateInstallMode;
  final AppUpdateChannel updateChannel;
  final TlsFragmentationMode tlsFragmentationMode;
  final bool allowUntrustedProxyCertificates;
  final bool allowUntrustedSubscriptionCertificates;
  final bool vpnInboundEnabled;
  final int vpnMtu;
  final bool vpnStrictRoute;
  final TunImplementationPreference vpnTunImplementation;
  final bool proxyInboundEnabled;
  final bool proxyAllowLan;
  final String proxyMixedListen;
  final int proxyMixedPort;
  final String proxyUsername;
  final String proxyPassword;
  final String dnsDirectPreset;
  final String dnsDirectResolver;
  final String dnsProxyPreset;
  final String dnsProxyResolver;
  final bool dnsPreferIpv6;
  final String russiaDnsDirectResolver;
  final String urlTestUrl;
  final int urlTestIntervalSeconds;
  final int urlTestTimeoutSeconds;
  final int urlTestConcurrency;
  final int urlTestUnavailableCheckIntervalSeconds;
  final int locationLookupLimit;
  final int locationLookupTimeoutSeconds;
  final int locationLookupConcurrency;
  final bool blockLeaks;
  final bool adBlockEnabled;
  final bool useRussiaRouteData;
  final TrafficRulePreset trafficRulePreset;
  final bool bypassLocalNetwork;
  final SplitRoutingMode splitRoutingMode;
  final List<String> splitRoutingPackages;
  final String singBoxLogLevel;
  final bool experimentalTcpFastOpen;
  final bool experimentalTcpMultiPath;
  final bool experimentalInterruptExistingConnections;
  final bool experimentalUrlTestStrictTolerance;
  final bool experimentalFakeIpEnabled;

  AppSettingsState copyWith({
    int? coreConfigSchemaVersion,
    bool? onboardingCompleted,
    String? acceptedLegalVersion,
    int? acceptedLegalAtMillis,
    String? activeProfileId,
    String? selectedProxyTag,
    String? proxySort,
    String? localeCode,
    AppThemePreference? themePreference,
    String? accentColorHex,
    bool? hapticEnabled,
    bool? statusNotificationEnabled,
    NotificationTrafficDisplayMode? notificationTrafficDisplayMode,
    int? notificationTrafficRefreshSeconds,
    bool? hideServerIp,
    bool? progressiveBlurEnabled,
    bool? progressiveBlurConfigured,
    bool? memoryLimitEnabled,
    bool? memoryLimitWarningDismissed,
    AppUpdateInstallMode? updateInstallMode,
    AppUpdateChannel? updateChannel,
    TlsFragmentationMode? tlsFragmentationMode,
    bool? allowUntrustedProxyCertificates,
    bool? allowUntrustedSubscriptionCertificates,
    bool? vpnInboundEnabled,
    int? vpnMtu,
    bool? vpnStrictRoute,
    TunImplementationPreference? vpnTunImplementation,
    bool? proxyInboundEnabled,
    bool? proxyAllowLan,
    String? proxyMixedListen,
    int? proxyMixedPort,
    String? proxyUsername,
    String? proxyPassword,
    String? dnsDirectPreset,
    String? dnsDirectResolver,
    String? dnsProxyPreset,
    String? dnsProxyResolver,
    bool? dnsPreferIpv6,
    String? russiaDnsDirectResolver,
    String? urlTestUrl,
    int? urlTestIntervalSeconds,
    int? urlTestTimeoutSeconds,
    int? urlTestConcurrency,
    int? urlTestUnavailableCheckIntervalSeconds,
    int? locationLookupLimit,
    int? locationLookupTimeoutSeconds,
    int? locationLookupConcurrency,
    bool? blockLeaks,
    bool? adBlockEnabled,
    bool? useRussiaRouteData,
    TrafficRulePreset? trafficRulePreset,
    bool? bypassLocalNetwork,
    SplitRoutingMode? splitRoutingMode,
    List<String>? splitRoutingPackages,
    String? singBoxLogLevel,
    bool? experimentalTcpFastOpen,
    bool? experimentalTcpMultiPath,
    bool? experimentalInterruptExistingConnections,
    bool? experimentalUrlTestStrictTolerance,
    bool? experimentalFakeIpEnabled,
  }) {
    return AppSettingsState(
      coreConfigSchemaVersion:
          coreConfigSchemaVersion ?? this.coreConfigSchemaVersion,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      acceptedLegalVersion: acceptedLegalVersion ?? this.acceptedLegalVersion,
      acceptedLegalAtMillis:
          acceptedLegalAtMillis ?? this.acceptedLegalAtMillis,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      selectedProxyTag: selectedProxyTag ?? this.selectedProxyTag,
      proxySort: proxySort ?? this.proxySort,
      localeCode: localeCode ?? this.localeCode,
      themePreference: themePreference ?? this.themePreference,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      statusNotificationEnabled:
          statusNotificationEnabled ?? this.statusNotificationEnabled,
      notificationTrafficDisplayMode:
          notificationTrafficDisplayMode ?? this.notificationTrafficDisplayMode,
      notificationTrafficRefreshSeconds:
          notificationTrafficRefreshSeconds ??
          this.notificationTrafficRefreshSeconds,
      hideServerIp: hideServerIp ?? this.hideServerIp,
      progressiveBlurEnabled:
          progressiveBlurEnabled ?? this.progressiveBlurEnabled,
      progressiveBlurConfigured:
          progressiveBlurConfigured ?? this.progressiveBlurConfigured,
      memoryLimitEnabled: memoryLimitEnabled ?? this.memoryLimitEnabled,
      memoryLimitWarningDismissed:
          memoryLimitWarningDismissed ?? this.memoryLimitWarningDismissed,
      updateInstallMode: updateInstallMode ?? this.updateInstallMode,
      updateChannel: updateChannel ?? this.updateChannel,
      tlsFragmentationMode: tlsFragmentationMode ?? this.tlsFragmentationMode,
      allowUntrustedProxyCertificates:
          allowUntrustedProxyCertificates ??
          this.allowUntrustedProxyCertificates,
      allowUntrustedSubscriptionCertificates:
          allowUntrustedSubscriptionCertificates ??
          this.allowUntrustedSubscriptionCertificates,
      vpnInboundEnabled: vpnInboundEnabled ?? this.vpnInboundEnabled,
      vpnMtu: vpnMtu ?? this.vpnMtu,
      vpnStrictRoute: vpnStrictRoute ?? this.vpnStrictRoute,
      vpnTunImplementation: vpnTunImplementation ?? this.vpnTunImplementation,
      proxyInboundEnabled: proxyInboundEnabled ?? this.proxyInboundEnabled,
      proxyAllowLan: proxyAllowLan ?? this.proxyAllowLan,
      proxyMixedListen: proxyMixedListen ?? this.proxyMixedListen,
      proxyMixedPort: proxyMixedPort ?? this.proxyMixedPort,
      proxyUsername: proxyUsername ?? this.proxyUsername,
      proxyPassword: proxyPassword ?? this.proxyPassword,
      dnsDirectPreset: dnsDirectPreset ?? this.dnsDirectPreset,
      dnsDirectResolver: dnsDirectResolver ?? this.dnsDirectResolver,
      dnsProxyPreset: dnsProxyPreset ?? this.dnsProxyPreset,
      dnsProxyResolver: dnsProxyResolver ?? this.dnsProxyResolver,
      dnsPreferIpv6: dnsPreferIpv6 ?? this.dnsPreferIpv6,
      russiaDnsDirectResolver:
          russiaDnsDirectResolver ?? this.russiaDnsDirectResolver,
      urlTestUrl: urlTestUrl ?? this.urlTestUrl,
      urlTestIntervalSeconds:
          urlTestIntervalSeconds ?? this.urlTestIntervalSeconds,
      urlTestTimeoutSeconds:
          urlTestTimeoutSeconds ?? this.urlTestTimeoutSeconds,
      urlTestConcurrency: urlTestConcurrency ?? this.urlTestConcurrency,
      urlTestUnavailableCheckIntervalSeconds:
          urlTestUnavailableCheckIntervalSeconds ??
          this.urlTestUnavailableCheckIntervalSeconds,
      locationLookupLimit: locationLookupLimit ?? this.locationLookupLimit,
      locationLookupTimeoutSeconds:
          locationLookupTimeoutSeconds ?? this.locationLookupTimeoutSeconds,
      locationLookupConcurrency:
          locationLookupConcurrency ?? this.locationLookupConcurrency,
      blockLeaks: blockLeaks ?? this.blockLeaks,
      adBlockEnabled: adBlockEnabled ?? this.adBlockEnabled,
      useRussiaRouteData: useRussiaRouteData ?? this.useRussiaRouteData,
      trafficRulePreset: trafficRulePreset ?? this.trafficRulePreset,
      bypassLocalNetwork: bypassLocalNetwork ?? this.bypassLocalNetwork,
      splitRoutingMode: splitRoutingMode ?? this.splitRoutingMode,
      splitRoutingPackages: splitRoutingPackages ?? this.splitRoutingPackages,
      singBoxLogLevel: singBoxLogLevel ?? this.singBoxLogLevel,
      experimentalTcpFastOpen:
          experimentalTcpFastOpen ?? this.experimentalTcpFastOpen,
      experimentalTcpMultiPath:
          experimentalTcpMultiPath ?? this.experimentalTcpMultiPath,
      experimentalInterruptExistingConnections:
          experimentalInterruptExistingConnections ??
          this.experimentalInterruptExistingConnections,
      experimentalUrlTestStrictTolerance:
          experimentalUrlTestStrictTolerance ??
          this.experimentalUrlTestStrictTolerance,
      experimentalFakeIpEnabled:
          experimentalFakeIpEnabled ?? this.experimentalFakeIpEnabled,
    );
  }
}

abstract class AppSettingsStore {
  static const boxName = 'app_state_secure_v1';
  static const legacyBoxName = 'app_state';
  static const storageSchemaVersionKey = '__etonify_storage_schema_version__';
  static const storageSchemaVersion = 1;
  static const exportFormatVersion = 1;
  static const exportMinClientVersion = '0.2.0';

  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _coreConfigSchemaVersionKey = 'core_config_schema_version';
  static const _acceptedLegalVersionKey = 'accepted_legal_version';
  static const _acceptedLegalAtMillisKey = 'accepted_legal_at_millis';
  static const _activeProfileIdKey = 'active_profile_id';
  static const _selectedProxyTagKey = 'selected_proxy_tag';
  static const _proxySortKey = 'proxy_sort';
  static const _localeCodeKey = 'locale_code';
  static const _themePreferenceKey = 'theme_preference';
  static const _accentColorHexKey = 'accent_color_hex';
  static const _hapticEnabledKey = 'haptic_enabled';
  static const _statusNotificationEnabledKey = 'status_notification_enabled';
  static const _notificationTrafficDisplayModeKey =
      'notification_traffic_display_mode';
  static const _notificationTrafficRefreshSecondsKey =
      'notification_traffic_refresh_seconds';
  static const _hideServerIpKey = 'hide_server_ip';
  static const _progressiveBlurEnabledKey = 'progressive_blur_enabled';
  static const _performanceModeKey = 'performance_mode';
  static const _memoryLimitEnabledKey = 'memory_limit_enabled';
  static const _memoryLimitWarningDismissedKey =
      'memory_limit_warning_dismissed';
  static const _updateInstallModeKey = 'update_install_mode';
  static const _updateChannelKey = 'update_channel';
  static const _tlsFragmentationModeKey = 'tls_fragmentation_mode';
  static const _allowUntrustedProxyCertificatesKey =
      'allow_untrusted_proxy_certificates';
  static const _allowUntrustedSubscriptionCertificatesKey =
      'allow_untrusted_subscription_certificates';
  static const _vpnInboundEnabledKey = 'vpn_inbound_enabled';
  static const _vpnMtuKey = 'vpn_mtu';
  static const _vpnStrictRouteKey = 'vpn_strict_route';
  static const _vpnTunImplementationKey = 'vpn_tun_implementation';
  static const _proxyInboundEnabledKey = 'proxy_inbound_enabled';
  static const _proxyAllowLanKey = 'proxy_allow_lan';
  static const _proxyMixedListenKey = 'proxy_mixed_listen';
  static const _proxyMixedPortKey = 'proxy_mixed_port';
  static const _proxyUsernameKey = 'proxy_username';
  static const _proxyPasswordKey = 'proxy_password';
  static const _dnsDirectPresetKey = 'dns_direct_preset';
  static const _dnsDirectResolverKey = 'dns_direct_resolver';
  static const _dnsProxyPresetKey = 'dns_proxy_preset';
  static const _dnsProxyResolverKey = 'dns_proxy_resolver';
  static const _dnsPreferIpv6Key = 'dns_prefer_ipv6';
  static const _russiaDnsDirectResolverKey = 'russia_dns_direct_resolver';
  static const _urlTestUrlKey = 'urltest_url';
  static const _urlTestIntervalSecondsKey = 'urltest_interval_seconds';
  static const _urlTestTimeoutSecondsKey = 'urltest_timeout_seconds';
  static const _urlTestConcurrencyKey = 'urltest_concurrency';
  static const _urlTestUnavailableCheckIntervalSecondsKey =
      'urltest_unavailable_check_interval_seconds';
  static const _locationLookupLimitKey = 'location_lookup_limit';
  static const _locationLookupTimeoutSecondsKey =
      'location_lookup_timeout_seconds';
  static const _locationLookupConcurrencyKey = 'location_lookup_concurrency';
  static const _blockLeaksKey = 'block_leaks';
  static const _adBlockEnabledKey = 'ad_block_enabled';
  static const _useRussiaRouteDataKey = 'use_russia_route_data';
  static const _trafficRulePresetKey = 'traffic_rule_preset';
  static const _bypassLocalNetworkKey = 'bypass_local_network';
  static const _splitRoutingModeKey = 'split_routing_mode';
  static const _splitRoutingPackagesKey = 'split_routing_packages';
  static const _singBoxLogLevelKey = 'singbox_log_level';
  static const _experimentalTcpFastOpenKey = 'experimental_tcp_fast_open';
  static const _experimentalTcpMultiPathKey = 'experimental_tcp_multi_path';
  static const _experimentalInterruptExistingConnectionsKey =
      'experimental_interrupt_existing_connections';
  static const _experimentalUrlTestStrictToleranceKey =
      'experimental_urltest_strict_tolerance';
  static const _experimentalFakeIpEnabledKey = 'experimental_fake_ip_enabled';

  Future<AppSettingsState> loadState();

  Future<void> saveState(AppSettingsState state);

  Future<void> close();

  static const Set<String> safeExportKeys = {
    _localeCodeKey,
    _themePreferenceKey,
    _accentColorHexKey,
    _hapticEnabledKey,
    _statusNotificationEnabledKey,
    _notificationTrafficDisplayModeKey,
    _notificationTrafficRefreshSecondsKey,
    _hideServerIpKey,
    _proxySortKey,
    _memoryLimitEnabledKey,
    _memoryLimitWarningDismissedKey,
    _updateInstallModeKey,
    _updateChannelKey,
    _tlsFragmentationModeKey,
    _vpnInboundEnabledKey,
    _vpnMtuKey,
    _vpnStrictRouteKey,
    _vpnTunImplementationKey,
    _proxyInboundEnabledKey,
    _proxyAllowLanKey,
    _proxyMixedListenKey,
    _proxyMixedPortKey,
    _proxyUsernameKey,
    _dnsDirectPresetKey,
    _dnsDirectResolverKey,
    _dnsProxyPresetKey,
    _dnsProxyResolverKey,
    _dnsPreferIpv6Key,
    _russiaDnsDirectResolverKey,
    _urlTestUrlKey,
    _urlTestIntervalSecondsKey,
    _urlTestTimeoutSecondsKey,
    _urlTestConcurrencyKey,
    _urlTestUnavailableCheckIntervalSecondsKey,
    _locationLookupLimitKey,
    _locationLookupTimeoutSecondsKey,
    _locationLookupConcurrencyKey,
    _blockLeaksKey,
    _adBlockEnabledKey,
    _useRussiaRouteDataKey,
    _trafficRulePresetKey,
    _bypassLocalNetworkKey,
    _splitRoutingModeKey,
    _splitRoutingPackagesKey,
    _singBoxLogLevelKey,
    _experimentalTcpFastOpenKey,
    _experimentalTcpMultiPathKey,
    _experimentalInterruptExistingConnectionsKey,
    _experimentalUrlTestStrictToleranceKey,
    _experimentalFakeIpEnabledKey,
  };

  Map<String, dynamic> stateToSafeExportMap(AppSettingsState state) {
    final map = stateToMap(state);
    return <String, dynamic>{
      for (final key in safeExportKeys)
        if (map.containsKey(key)) key: map[key],
    };
  }

  AppSettingsState mergeSafeImportMap(
    AppSettingsState current,
    Map<String, dynamic> imported,
  ) {
    final currentMap = stateToMap(current);
    final sanitized = <String, dynamic>{
      for (final entry in imported.entries)
        if (safeExportKeys.contains(entry.key)) entry.key: entry.value,
    };
    return mapState({...currentMap, ...sanitized});
  }

  AppSettingsState mapState(Map<String, dynamic> map) {
    bool boolValue(String key, {required bool defaultValue}) {
      final raw = map[key]?.toString();
      if (raw == null) {
        return defaultValue;
      }
      return raw == '1';
    }

    List<String> packageListValue(String key) {
      final raw = map[key]?.toString() ?? '';
      return normalizeSplitRoutingPackages(raw.split(RegExp(r'[\n,;]')));
    }

    // Performance modes were removed in 0.3.0 because they only changed a
    // handful of timers and made runtime behaviour harder to predict. Detect
    // the old Economy preset once so its generated values can be migrated to
    // the normal defaults instead of surviving as an invisible mode.
    final legacyEconomy = map[_performanceModeKey] == 'economy';
    final urlTestInterval = int.tryParse(
      map[_urlTestIntervalSecondsKey]?.toString() ?? '',
    );
    final urlTestTimeout = int.tryParse(
      map[_urlTestTimeoutSecondsKey]?.toString() ?? '',
    );
    final urlTestConcurrency = int.tryParse(
      map[_urlTestConcurrencyKey]?.toString() ?? '',
    );
    final unavailableCheckInterval = int.tryParse(
      map[_urlTestUnavailableCheckIntervalSecondsKey]?.toString() ?? '',
    );
    final notificationTrafficRefreshSeconds =
        (int.tryParse(
                  map[_notificationTrafficRefreshSecondsKey]?.toString() ?? '',
                ) ??
                2)
            .clamp(1, 10)
            .toInt();
    const defaultUrlTestConcurrency = 8;
    final normalizedUrlTestConcurrency =
        ((legacyEconomy && urlTestConcurrency == 4)
                ? defaultUrlTestConcurrency
                : urlTestConcurrency ?? defaultUrlTestConcurrency)
            .clamp(1, defaultUrlTestConcurrency);
    const defaultUnavailableCheckInterval = 120;
    final locationLookupConcurrency = int.tryParse(
      map[_locationLookupConcurrencyKey]?.toString() ?? '',
    );
    final locationLookupTimeout = int.tryParse(
      map[_locationLookupTimeoutSecondsKey]?.toString() ?? '',
    );

    return AppSettingsState(
      coreConfigSchemaVersion:
          int.tryParse(map[_coreConfigSchemaVersionKey]?.toString() ?? '') ?? 0,
      onboardingCompleted: boolValue(
        _onboardingCompletedKey,
        defaultValue: false,
      ),
      acceptedLegalVersion:
          map[_acceptedLegalVersionKey]?.toString().trim() ?? '',
      acceptedLegalAtMillis: int.tryParse(
        map[_acceptedLegalAtMillisKey]?.toString() ?? '',
      ),
      activeProfileId: map[_activeProfileIdKey] ?? '',
      selectedProxyTag: map[_selectedProxyTagKey] ?? '',
      proxySort: switch (map[_proxySortKey]?.toString()) {
        'latency' => 'latency',
        'working' => 'working',
        'name' => 'name',
        'country' => 'country',
        _ => 'source',
      },
      localeCode: map[_localeCodeKey] ?? 'system',
      themePreference: switch (map[_themePreferenceKey]) {
        'system' => AppThemePreference.system,
        'dark' => AppThemePreference.dark,
        'light' => AppThemePreference.light,
        'amoled' => AppThemePreference.amoled,
        _ => AppThemePreference.system,
      },
      accentColorHex: map[_accentColorHexKey] ?? 'default',
      hapticEnabled: boolValue(_hapticEnabledKey, defaultValue: true),
      statusNotificationEnabled: boolValue(
        _statusNotificationEnabledKey,
        defaultValue: true,
      ),
      notificationTrafficDisplayMode:
          switch (map[_notificationTrafficDisplayModeKey]) {
            'total' => NotificationTrafficDisplayMode.total,
            'both' => NotificationTrafficDisplayMode.both,
            _ => NotificationTrafficDisplayMode.speed,
          },
      notificationTrafficRefreshSeconds: notificationTrafficRefreshSeconds,
      hideServerIp: boolValue(_hideServerIpKey, defaultValue: false),
      progressiveBlurEnabled: boolValue(
        _progressiveBlurEnabledKey,
        defaultValue: false,
      ),
      progressiveBlurConfigured: map.containsKey(_progressiveBlurEnabledKey),
      memoryLimitEnabled: boolValue(_memoryLimitEnabledKey, defaultValue: true),
      memoryLimitWarningDismissed: boolValue(
        _memoryLimitWarningDismissedKey,
        defaultValue: false,
      ),
      updateInstallMode: switch (map[_updateInstallModeKey]) {
        'manual' => AppUpdateInstallMode.manual,
        'auto' => AppUpdateInstallMode.auto,
        'ask' => AppUpdateInstallMode.ask,
        _ => AppUpdateInstallMode.ask,
      },
      updateChannel: switch (map[_updateChannelKey]) {
        'beta' => AppUpdateChannel.beta,
        _ => AppUpdateChannel.stable,
      },
      tlsFragmentationMode: switch (map[_tlsFragmentationModeKey]) {
        'record' => TlsFragmentationMode.record,
        'fragment' => TlsFragmentationMode.fragment,
        'disabled' => TlsFragmentationMode.disabled,
        _ => TlsFragmentationMode.disabled,
      },
      allowUntrustedProxyCertificates: boolValue(
        _allowUntrustedProxyCertificatesKey,
        defaultValue: false,
      ),
      allowUntrustedSubscriptionCertificates: boolValue(
        _allowUntrustedSubscriptionCertificatesKey,
        defaultValue: false,
      ),
      vpnInboundEnabled: boolValue(_vpnInboundEnabledKey, defaultValue: true),
      vpnMtu: _vpnMtuValue(map[_vpnMtuKey]),
      vpnStrictRoute: boolValue(_vpnStrictRouteKey, defaultValue: true),
      vpnTunImplementation: switch (map[_vpnTunImplementationKey]) {
        'system' => TunImplementationPreference.system,
        'gvisor' => TunImplementationPreference.gvisor,
        'mixed' => TunImplementationPreference.mixed,
        _ => TunImplementationPreference.mixed,
      },
      proxyInboundEnabled: boolValue(
        _proxyInboundEnabledKey,
        defaultValue: false,
      ),
      proxyAllowLan: boolValue(_proxyAllowLanKey, defaultValue: false),
      proxyMixedListen:
          map[_proxyMixedListenKey]?.toString() ??
          (boolValue(_proxyAllowLanKey, defaultValue: false)
              ? '0.0.0.0'
              : '127.0.0.1'),
      proxyMixedPort:
          int.tryParse(map[_proxyMixedPortKey]?.toString() ?? '') ?? 1080,
      proxyUsername: normalizeProxyUsername(
        map[_proxyUsernameKey]?.toString() ?? '',
      ),
      proxyPassword: map[_proxyPasswordKey]?.toString() ?? '',
      dnsDirectPreset: map[_dnsDirectPresetKey]?.toString() ?? 'cloudflare',
      dnsDirectResolver:
          _resolverValue(
            map[_dnsDirectResolverKey]?.toString(),
            'udp://1.1.1.1',
          ) ??
          'udp://1.1.1.1',
      dnsProxyPreset: map[_dnsProxyPresetKey]?.toString() ?? 'cloudflare',
      dnsProxyResolver:
          _resolverValue(
            map[_dnsProxyResolverKey]?.toString(),
            'https://dns.cloudflare.com/dns-query',
          ) ??
          'https://dns.cloudflare.com/dns-query',
      dnsPreferIpv6: map[_dnsPreferIpv6Key] == '1',
      russiaDnsDirectResolver:
          _resolverValue(
            map[_russiaDnsDirectResolverKey]?.toString(),
            defaultRussiaDnsDirectResolver,
          ) ??
          defaultRussiaDnsDirectResolver,
      urlTestUrl: _migrateUrlTestUrl(map[_urlTestUrlKey]?.toString()),
      urlTestIntervalSeconds:
          urlTestInterval == null ||
              const <int>{120, 180, 300, 900}.contains(urlTestInterval) ||
              (legacyEconomy && urlTestInterval == 3600)
          ? 1800
          : urlTestInterval,
      urlTestTimeoutSeconds:
          urlTestTimeout == null ||
              const <int>{4, 5, 10, 15}.contains(urlTestTimeout)
          ? 15
          : urlTestTimeout,
      urlTestConcurrency: normalizedUrlTestConcurrency,
      urlTestUnavailableCheckIntervalSeconds:
          unavailableCheckInterval == null ||
              (legacyEconomy && unavailableCheckInterval == 10) ||
              const <int>{
                5,
                15,
                60,
                120,
                300,
              }.contains(unavailableCheckInterval)
          ? defaultUnavailableCheckInterval
          : unavailableCheckInterval.clamp(
              defaultUnavailableCheckInterval,
              3600,
            ),
      locationLookupLimit: switch (int.tryParse(
        map[_locationLookupLimitKey]?.toString() ?? '',
      )) {
        null => 1,
        0 when legacyEconomy => 1,
        2 => 1,
        final value => value,
      },
      locationLookupTimeoutSeconds:
          locationLookupTimeout == null || locationLookupTimeout == 5
          ? 3
          : locationLookupTimeout,
      locationLookupConcurrency:
          locationLookupConcurrency == null ||
              locationLookupConcurrency == 2 ||
              locationLookupConcurrency == 3
          ? 1
          : locationLookupConcurrency,
      blockLeaks: boolValue(_blockLeaksKey, defaultValue: false),
      adBlockEnabled: boolValue(_adBlockEnabledKey, defaultValue: false),
      useRussiaRouteData: boolValue(
        _useRussiaRouteDataKey,
        defaultValue: false,
      ),
      trafficRulePreset: TrafficRulePreset.fromStorage(
        map[_trafficRulePresetKey],
      ),
      bypassLocalNetwork: boolValue(_bypassLocalNetworkKey, defaultValue: true),
      splitRoutingMode: switch (map[_splitRoutingModeKey]) {
        'proxy_selected' => SplitRoutingMode.proxySelected,
        'bypass_selected' => SplitRoutingMode.bypassSelected,
        'disabled' => SplitRoutingMode.disabled,
        _ => SplitRoutingMode.disabled,
      },
      splitRoutingPackages: packageListValue(_splitRoutingPackagesKey),
      singBoxLogLevel: map[_singBoxLogLevelKey]?.toString() ?? 'warning',
      experimentalTcpFastOpen: boolValue(
        _experimentalTcpFastOpenKey,
        defaultValue: true,
      ),
      experimentalTcpMultiPath: boolValue(
        _experimentalTcpMultiPathKey,
        defaultValue: false,
      ),
      experimentalInterruptExistingConnections: boolValue(
        _experimentalInterruptExistingConnectionsKey,
        defaultValue: true,
      ),
      experimentalUrlTestStrictTolerance: boolValue(
        _experimentalUrlTestStrictToleranceKey,
        defaultValue: true,
      ),
      experimentalFakeIpEnabled: boolValue(
        _experimentalFakeIpEnabledKey,
        defaultValue: false,
      ),
    );
  }

  int _vpnMtuValue(Object? rawValue) {
    final value = int.tryParse(rawValue?.toString() ?? '');
    if (value == null || value == 3400) {
      return 1500;
    }
    return value;
  }

  Map<String, dynamic> stateToMap(AppSettingsState state) {
    return {
      _coreConfigSchemaVersionKey: state.coreConfigSchemaVersion.toString(),
      _onboardingCompletedKey: state.onboardingCompleted ? '1' : '0',
      _acceptedLegalVersionKey: state.acceptedLegalVersion,
      _acceptedLegalAtMillisKey: state.acceptedLegalAtMillis?.toString() ?? '',
      _activeProfileIdKey: state.activeProfileId,
      _selectedProxyTagKey: state.selectedProxyTag,
      _proxySortKey: state.proxySort,
      _localeCodeKey: state.localeCode,
      _themePreferenceKey: state.themePreference.name,
      _accentColorHexKey: state.accentColorHex,
      _hapticEnabledKey: state.hapticEnabled ? '1' : '0',
      _statusNotificationEnabledKey: state.statusNotificationEnabled
          ? '1'
          : '0',
      _notificationTrafficDisplayModeKey:
          state.notificationTrafficDisplayMode.name,
      _notificationTrafficRefreshSecondsKey: state
          .notificationTrafficRefreshSeconds
          .toString(),
      _hideServerIpKey: state.hideServerIp ? '1' : '0',
      _progressiveBlurEnabledKey: state.progressiveBlurEnabled ? '1' : '0',
      _memoryLimitEnabledKey: state.memoryLimitEnabled ? '1' : '0',
      _memoryLimitWarningDismissedKey: state.memoryLimitWarningDismissed
          ? '1'
          : '0',
      _updateInstallModeKey: state.updateInstallMode.name,
      _updateChannelKey: state.updateChannel.name,
      _tlsFragmentationModeKey: state.tlsFragmentationMode.name,
      _allowUntrustedProxyCertificatesKey: state.allowUntrustedProxyCertificates
          ? '1'
          : '0',
      _allowUntrustedSubscriptionCertificatesKey:
          state.allowUntrustedSubscriptionCertificates ? '1' : '0',
      _vpnInboundEnabledKey: state.vpnInboundEnabled ? '1' : '0',
      _vpnMtuKey: state.vpnMtu.toString(),
      _vpnStrictRouteKey: state.vpnStrictRoute ? '1' : '0',
      _vpnTunImplementationKey: state.vpnTunImplementation.name,
      _proxyInboundEnabledKey: state.proxyInboundEnabled ? '1' : '0',
      _proxyAllowLanKey: state.proxyAllowLan ? '1' : '0',
      _proxyMixedListenKey: state.proxyMixedListen,
      _proxyMixedPortKey: state.proxyMixedPort.toString(),
      _proxyUsernameKey: normalizeProxyUsername(state.proxyUsername),
      _proxyPasswordKey: state.proxyPassword,
      _dnsDirectPresetKey: state.dnsDirectPreset,
      _dnsDirectResolverKey: state.dnsDirectResolver,
      _dnsProxyPresetKey: state.dnsProxyPreset,
      _dnsProxyResolverKey: state.dnsProxyResolver,
      _dnsPreferIpv6Key: state.dnsPreferIpv6 ? '1' : '0',
      _russiaDnsDirectResolverKey: state.russiaDnsDirectResolver,
      _urlTestUrlKey: state.urlTestUrl,
      _urlTestIntervalSecondsKey: state.urlTestIntervalSeconds.toString(),
      _urlTestTimeoutSecondsKey: state.urlTestTimeoutSeconds.toString(),
      _urlTestConcurrencyKey: state.urlTestConcurrency.toString(),
      _urlTestUnavailableCheckIntervalSecondsKey: state
          .urlTestUnavailableCheckIntervalSeconds
          .toString(),
      _locationLookupLimitKey: state.locationLookupLimit.toString(),
      _locationLookupTimeoutSecondsKey: state.locationLookupTimeoutSeconds
          .toString(),
      _locationLookupConcurrencyKey: state.locationLookupConcurrency.toString(),
      _blockLeaksKey: state.blockLeaks ? '1' : '0',
      _adBlockEnabledKey: state.adBlockEnabled ? '1' : '0',
      _useRussiaRouteDataKey: state.useRussiaRouteData ? '1' : '0',
      _trafficRulePresetKey: state.trafficRulePreset.storageValue,
      _bypassLocalNetworkKey: state.bypassLocalNetwork ? '1' : '0',
      _splitRoutingModeKey: switch (state.splitRoutingMode) {
        SplitRoutingMode.disabled => 'disabled',
        SplitRoutingMode.proxySelected => 'proxy_selected',
        SplitRoutingMode.bypassSelected => 'bypass_selected',
      },
      _splitRoutingPackagesKey: normalizeSplitRoutingPackages(
        state.splitRoutingPackages,
      ).join('\n'),
      _singBoxLogLevelKey: state.singBoxLogLevel,
      _experimentalTcpFastOpenKey: state.experimentalTcpFastOpen ? '1' : '0',
      _experimentalTcpMultiPathKey: state.experimentalTcpMultiPath ? '1' : '0',
      _experimentalInterruptExistingConnectionsKey:
          state.experimentalInterruptExistingConnections ? '1' : '0',
      _experimentalUrlTestStrictToleranceKey:
          state.experimentalUrlTestStrictTolerance ? '1' : '0',
      _experimentalFakeIpEnabledKey: state.experimentalFakeIpEnabled
          ? '1'
          : '0',
    };
  }
}

class HiveAppSettingsStore extends AppSettingsStore {
  HiveAppSettingsStore._(this._box);

  final Box<dynamic> _box;
  static bool _hiveInitialized = false;

  static String _androidFilesDirPath() {
    final context = androidApplicationContext;
    final contextClass = context.jClass;
    final getFilesDir = contextClass.instanceMethodId(
      'getFilesDir',
      '()Ljava/io/File;',
    );
    final filesDir = getFilesDir.call(context, JObject.type, []);
    final fileClass = filesDir.jClass;
    final getAbsolutePath = fileClass.instanceMethodId(
      'getAbsolutePath',
      '()Ljava/lang/String;',
    );
    final path = getAbsolutePath
        .call(filesDir, JString.type, [])
        .toDartString(releaseOriginal: true);

    fileClass.release();
    filesDir.release();
    contextClass.release();
    context.release();

    return path;
  }

  /// Call once before [open], ideally in main() before runApp.
  static Future<void> initHive() async {
    if (_hiveInitialized) return;
    if (Platform.isAndroid) {
      final filesDir = _androidFilesDirPath();
      Hive.init('$filesDir/meow_hive');
    } else {
      await Hive.initFlutter('meow_hive');
    }
    await SecureHiveStorage.init();
    _hiveInitialized = true;
  }

  static Future<HiveAppSettingsStore> open() async {
    // Safety: ensure Hive is initialized even if caller forgot.
    await initHive();

    // If the box is already open, just reuse it.
    if (Hive.isBoxOpen(AppSettingsStore.boxName)) {
      final box = Hive.box<dynamic>(AppSettingsStore.boxName);
      await HiveStorageDiagnostics.logBoxOnce(
        label: AppSettingsStore.boxName,
        box: box,
        openElapsed: Duration.zero,
      );
      return HiveAppSettingsStore._(box);
    }

    try {
      final stopwatch = Stopwatch()..start();
      final box = await Hive.openBox<dynamic>(
        AppSettingsStore.boxName,
        encryptionCipher: SecureHiveStorage.cipher,
      );
      await _migrateLegacyBox(box);
      stopwatch.stop();
      await HiveStorageDiagnostics.logBoxOnce(
        label: AppSettingsStore.boxName,
        box: box,
        openElapsed: stopwatch.elapsed,
      );
      return HiveAppSettingsStore._(box);
    } catch (error, stackTrace) {
      AppLogStore.error(
        'settings storage',
        'Failed to open Hive settings box: $error\n$stackTrace',
      );
      rethrow;
    }
  }

  static Future<void> _migrateLegacyBox(Box<dynamic> secureBox) async {
    final storedVersion =
        (secureBox.get(AppSettingsStore.storageSchemaVersionKey) as num?)
            ?.toInt() ??
        0;
    if (storedVersion >= AppSettingsStore.storageSchemaVersion) {
      return;
    }

    if (!await Hive.boxExists(AppSettingsStore.legacyBoxName)) {
      await secureBox.put(
        AppSettingsStore.storageSchemaVersionKey,
        AppSettingsStore.storageSchemaVersion,
      );
      await secureBox.flush();
      return;
    }

    final legacyBox = Hive.isBoxOpen(AppSettingsStore.legacyBoxName)
        ? Hive.box<dynamic>(AppSettingsStore.legacyBoxName)
        : await Hive.openBox<dynamic>(AppSettingsStore.legacyBoxName);
    try {
      if (legacyBox.isNotEmpty) {
        final legacyValues = Map<dynamic, dynamic>.from(legacyBox.toMap());
        final missingValues = <dynamic, dynamic>{
          for (final entry in legacyValues.entries)
            if (!secureBox.containsKey(entry.key)) entry.key: entry.value,
        };
        if (missingValues.isNotEmpty) {
          await secureBox.putAll(missingValues);
          await secureBox.flush();
        }
        if (legacyValues.keys.any((key) => !secureBox.containsKey(key))) {
          throw StateError('Encrypted settings migration was incomplete.');
        }
      }
    } finally {
      await legacyBox.close();
    }

    // Removal happens only after the encrypted copy was flushed and verified.
    await Hive.deleteBoxFromDisk(AppSettingsStore.legacyBoxName);
    await secureBox.put(
      AppSettingsStore.storageSchemaVersionKey,
      AppSettingsStore.storageSchemaVersion,
    );
    await secureBox.flush();
  }

  @override
  Future<AppSettingsState> loadState() async {
    final raw = _box.toMap().map(
      (key, value) => MapEntry(key.toString(), value),
    );
    return mapState(raw);
  }

  @override
  Future<void> saveState(AppSettingsState state) async {
    final map = stateToMap(state);
    await _box.delete(AppSettingsStore._performanceModeKey);
    await _box.putAll(map);
    await _box.flush();
  }

  @override
  Future<void> close() => _box.close();
}

class MemoryAppSettingsStore extends AppSettingsStore {
  MemoryAppSettingsStore([AppSettingsState? initialState])
    : _state =
          initialState ??
          const AppSettingsState(
            onboardingCompleted: false,
            activeProfileId: '',
            selectedProxyTag: '',
            localeCode: 'system',
            themePreference: AppThemePreference.system,
            accentColorHex: 'default',
            hapticEnabled: true,
            hideServerIp: false,
            progressiveBlurEnabled: false,
            progressiveBlurConfigured: false,
            memoryLimitEnabled: true,
            memoryLimitWarningDismissed: false,
            updateInstallMode: AppUpdateInstallMode.ask,
            vpnInboundEnabled: true,
            vpnMtu: 1500,
            vpnStrictRoute: true,
            vpnTunImplementation: TunImplementationPreference.mixed,
            proxyInboundEnabled: false,
            proxyAllowLan: false,
            proxyMixedListen: '127.0.0.1',
            proxyMixedPort: 1080,
            dnsDirectPreset: 'cloudflare',
            dnsDirectResolver: 'udp://1.1.1.1',
            dnsProxyPreset: 'cloudflare',
            dnsProxyResolver: 'https://dns.cloudflare.com/dns-query',
            dnsPreferIpv6: false,
            russiaDnsDirectResolver: defaultRussiaDnsDirectResolver,
            urlTestUrl: defaultUrlTestUrl,
            urlTestIntervalSeconds: 1800,
            urlTestTimeoutSeconds: 15,
            urlTestConcurrency: 8,
            urlTestUnavailableCheckIntervalSeconds: 120,
            locationLookupLimit: 2,
            locationLookupTimeoutSeconds: 3,
            locationLookupConcurrency: 2,
            blockLeaks: false,
            adBlockEnabled: false,
            useRussiaRouteData: false,
            trafficRulePreset: TrafficRulePreset.none,
            bypassLocalNetwork: true,
            splitRoutingMode: SplitRoutingMode.disabled,
            splitRoutingPackages: <String>[],
            singBoxLogLevel: 'warning',
            experimentalTcpFastOpen: true,
            experimentalTcpMultiPath: false,
            experimentalInterruptExistingConnections: true,
            experimentalUrlTestStrictTolerance: true,
          );

  AppSettingsState _state;

  @override
  Future<AppSettingsState> loadState() async => _state;

  @override
  Future<void> saveState(AppSettingsState state) async {
    _state = state;
  }

  @override
  Future<void> close() async {}
}

String _migrateUrlTestUrl(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty ||
      normalized == 'http://connectivitycheck.gstatic.com/generate_204') {
    return defaultUrlTestUrl;
  }
  return normalized;
}

String? _resolverValue(String? value, String fallback) {
  final normalized = normalizeDnsResolverInput(value ?? '');
  if (normalized.isEmpty) {
    return fallback;
  }
  final lower = normalized.toLowerCase();
  if (lower.startsWith('udp://') ||
      lower.startsWith('tcp://') ||
      lower.startsWith('tls://') ||
      lower.startsWith('https://') ||
      lower == 'device://network') {
    return normalized;
  }
  return fallback;
}
