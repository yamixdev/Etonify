import 'package:flutter/material.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/data/update/app_update_channel.dart';

const int appSettingsDefaultUrlTestTimeoutSeconds = 15;
const int appSettingsDefaultLocationLookupTimeoutSeconds = 3;
const int appSettingsStandardUrlTestIntervalSeconds = 1800;
const int appSettingsStandardUrlTestConcurrency = 4;
const int appSettingsStandardUrlTestUnavailableCheckIntervalSeconds = 120;
const int appSettingsStandardLocationLookupLimit = 1;
const int appSettingsStandardLocationLookupConcurrency = 1;

enum SettingsRuntimeImpact {
  uiOnly,
  runtimeFlags,
  safeCoreRestart,
  fullServiceRestart,
}

class AppSettingsImpactRegistry {
  const AppSettingsImpactRegistry._();

  static const _fullServiceRestartReasons = <String>{
    'vpn inbound changed',
    'vpn mtu changed',
    'vpn strict route changed',
    'vpn tun implementation changed',
    'proxy inbound changed',
    'proxy allow lan changed',
    'proxy port changed',
    'inbound connection mode changed',
    'proxy credentials changed',
    'block leaks changed',
    'adblock changed',
    'traffic rule preset changed',
    'bypass local network changed',
    'split routing mode changed',
    'split routing packages changed',
    'experimental fakeip changed',
  };

  static SettingsRuntimeImpact resolve(AppSettingsChange change) {
    if (change.configReason case final reason?) {
      return _fullServiceRestartReasons.contains(reason)
          ? SettingsRuntimeImpact.fullServiceRestart
          : SettingsRuntimeImpact.safeCoreRestart;
    }
    if (change.syncRuntimeFlags) {
      return SettingsRuntimeImpact.runtimeFlags;
    }
    return SettingsRuntimeImpact.uiOnly;
  }
}

class AppSettingsChange {
  const AppSettingsChange({
    required this.changed,
    this.configReason,
    this.refreshTheme = false,
    this.publishTraffic = false,
    this.syncRuntimeFlags = false,
    this.scheduleLocationRefresh = false,
    this.pumpLocationLookupWaiters = false,
  });

  const AppSettingsChange.none() : this(changed: false);

  final bool changed;
  final String? configReason;
  final bool refreshTheme;
  final bool publishTraffic;
  final bool syncRuntimeFlags;
  final bool scheduleLocationRefresh;
  final bool pumpLocationLookupWaiters;

  SettingsRuntimeImpact get runtimeImpact =>
      AppSettingsImpactRegistry.resolve(this);
  bool get restartRuntime =>
      runtimeImpact == SettingsRuntimeImpact.safeCoreRestart ||
      runtimeImpact == SettingsRuntimeImpact.fullServiceRestart;
  bool get forceFullServiceRestart =>
      runtimeImpact == SettingsRuntimeImpact.fullServiceRestart;
}

class AppSettingsController {
  int coreConfigSchemaVersion = 0;
  String localeCode = 'system';
  AppThemePreference themePreference = AppThemePreference.system;
  String accentColorHex = 'default';
  bool memoryLimitEnabled = false;
  bool memoryLimitWarningDismissed = false;
  AppUpdateInstallMode updateInstallMode = AppUpdateInstallMode.ask;
  AppUpdateChannel updateChannel = AppUpdateChannel.stable;
  TlsFragmentationMode tlsFragmentationMode = TlsFragmentationMode.disabled;
  bool allowUntrustedProxyCertificates = false;
  bool allowUntrustedSubscriptionCertificates = false;
  bool hapticEnabled = true;
  bool statusNotificationEnabled = true;
  NotificationTrafficDisplayMode notificationTrafficDisplayMode =
      NotificationTrafficDisplayMode.speed;
  int notificationTrafficRefreshSeconds = 2;
  bool hideServerIp = false;
  String proxySort = 'source';
  bool progressiveBlurEnabled = false;
  bool vpnInboundEnabled = true;
  int vpnMtu = 1500;
  bool vpnStrictRoute = true;
  TunImplementationPreference vpnTunImplementation =
      TunImplementationPreference.mixed;
  bool proxyInboundEnabled = false;
  bool proxyAllowLan = false;
  String proxyMixedListen = '127.0.0.1';
  int proxyMixedPort = 1080;
  String proxyUsername = defaultProxyUsername;
  String proxyPassword = '';
  String dnsDirectPreset = 'cloudflare';
  String dnsDirectResolver = 'udp://1.1.1.1';
  String dnsProxyPreset = 'cloudflare';
  String dnsProxyResolver = 'https://dns.cloudflare.com/dns-query';
  bool dnsPreferIpv6 = false;
  bool dnsSecureOnly = false;
  bool dnsDirectThroughProxy = false;
  String russiaDnsDirectResolver = defaultRussiaDnsDirectResolver;
  String urlTestUrl = defaultUrlTestUrl;
  int urlTestIntervalSeconds = appSettingsStandardUrlTestIntervalSeconds;
  int urlTestTimeoutSeconds = appSettingsDefaultUrlTestTimeoutSeconds;
  int urlTestConcurrency = appSettingsStandardUrlTestConcurrency;
  int urlTestUnavailableCheckIntervalSeconds =
      appSettingsStandardUrlTestUnavailableCheckIntervalSeconds;
  int locationLookupLimit = appSettingsStandardLocationLookupLimit;
  int locationLookupTimeoutSeconds =
      appSettingsDefaultLocationLookupTimeoutSeconds;
  int locationLookupConcurrency = appSettingsStandardLocationLookupConcurrency;
  bool blockLeaks = false;
  bool adBlockEnabled = false;
  bool useRussiaRouteData = false;
  TrafficRulePreset trafficRulePreset = TrafficRulePreset.none;
  bool bypassLocalNetwork = true;
  SplitRoutingMode splitRoutingMode = SplitRoutingMode.disabled;
  List<String> splitRoutingPackages = const <String>[];
  String singBoxLogLevel = 'warning';
  bool experimentalTcpFastOpen = true;
  bool experimentalTcpMultiPath = false;
  bool experimentalInterruptExistingConnections = true;
  bool experimentalUrlTestStrictTolerance = true;
  bool experimentalFakeIpEnabled = false;

  ThemeMode get themeMode => switch (themePreference) {
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.amoled => ThemeMode.dark,
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
  };

  InboundConnectionMode get inboundConnectionMode => vpnInboundEnabled
      ? InboundConnectionMode.vpn
      : InboundConnectionMode.proxy;

  AppSettingsState toState({
    required bool onboardingCompleted,
    required String acceptedLegalVersion,
    required int? acceptedLegalAtMillis,
    required String activeProfileId,
    required String selectedProxyTag,
  }) {
    return AppSettingsState(
      coreConfigSchemaVersion: coreConfigSchemaVersion,
      onboardingCompleted: onboardingCompleted,
      acceptedLegalVersion: acceptedLegalVersion,
      acceptedLegalAtMillis: acceptedLegalAtMillis,
      activeProfileId: activeProfileId,
      selectedProxyTag: selectedProxyTag,
      proxySort: proxySort,
      localeCode: localeCode,
      themePreference: themePreference,
      accentColorHex: accentColorHex,
      hapticEnabled: hapticEnabled,
      statusNotificationEnabled: statusNotificationEnabled,
      notificationTrafficDisplayMode: notificationTrafficDisplayMode,
      notificationTrafficRefreshSeconds: notificationTrafficRefreshSeconds,
      hideServerIp: hideServerIp,
      progressiveBlurEnabled: progressiveBlurEnabled,
      progressiveBlurConfigured: true,
      memoryLimitEnabled: memoryLimitEnabled,
      memoryLimitWarningDismissed: memoryLimitWarningDismissed,
      updateInstallMode: updateInstallMode,
      updateChannel: updateChannel,
      tlsFragmentationMode: tlsFragmentationMode,
      allowUntrustedProxyCertificates: allowUntrustedProxyCertificates,
      allowUntrustedSubscriptionCertificates:
          allowUntrustedSubscriptionCertificates,
      vpnInboundEnabled: vpnInboundEnabled,
      vpnMtu: vpnMtu,
      vpnStrictRoute: vpnStrictRoute,
      vpnTunImplementation: vpnTunImplementation,
      proxyInboundEnabled: proxyInboundEnabled,
      proxyAllowLan: proxyAllowLan,
      proxyMixedListen: proxyMixedListen,
      proxyMixedPort: proxyMixedPort,
      proxyUsername: proxyUsername,
      proxyPassword: proxyPassword,
      dnsDirectPreset: dnsDirectPreset,
      dnsDirectResolver: dnsDirectResolver,
      dnsProxyPreset: dnsProxyPreset,
      dnsProxyResolver: dnsProxyResolver,
      dnsPreferIpv6: dnsPreferIpv6,
      dnsSecureOnly: dnsSecureOnly,
      dnsDirectThroughProxy: dnsDirectThroughProxy,
      russiaDnsDirectResolver: russiaDnsDirectResolver,
      urlTestUrl: urlTestUrl,
      urlTestIntervalSeconds: urlTestIntervalSeconds,
      urlTestTimeoutSeconds: urlTestTimeoutSeconds,
      urlTestConcurrency: urlTestConcurrency,
      urlTestUnavailableCheckIntervalSeconds:
          urlTestUnavailableCheckIntervalSeconds,
      locationLookupLimit: locationLookupLimit,
      locationLookupTimeoutSeconds: locationLookupTimeoutSeconds,
      locationLookupConcurrency: locationLookupConcurrency,
      blockLeaks: blockLeaks,
      adBlockEnabled: adBlockEnabled,
      useRussiaRouteData: useRussiaRouteData,
      trafficRulePreset: trafficRulePreset,
      bypassLocalNetwork: bypassLocalNetwork,
      splitRoutingMode: splitRoutingMode,
      splitRoutingPackages: splitRoutingPackages,
      singBoxLogLevel: singBoxLogLevel,
      experimentalTcpFastOpen: experimentalTcpFastOpen,
      experimentalTcpMultiPath: experimentalTcpMultiPath,
      experimentalInterruptExistingConnections:
          experimentalInterruptExistingConnections,
      experimentalUrlTestStrictTolerance: experimentalUrlTestStrictTolerance,
      experimentalFakeIpEnabled: experimentalFakeIpEnabled,
    );
  }

  void applyState(
    AppSettingsState state, {
    bool progressiveBlurEnabledOverride = false,
  }) {
    coreConfigSchemaVersion = state.coreConfigSchemaVersion;
    localeCode = state.localeCode;
    themePreference = state.themePreference;
    accentColorHex = normalizeAccentColorHex(state.accentColorHex);
    hapticEnabled = state.hapticEnabled;
    statusNotificationEnabled = state.statusNotificationEnabled;
    notificationTrafficDisplayMode = state.notificationTrafficDisplayMode;
    notificationTrafficRefreshSeconds = state.notificationTrafficRefreshSeconds;
    hideServerIp = state.hideServerIp;
    proxySort =
        const {'source', 'latency', 'name', 'country'}.contains(state.proxySort)
        ? state.proxySort
        : 'source';
    progressiveBlurEnabled = progressiveBlurEnabledOverride;
    memoryLimitEnabled = state.memoryLimitEnabled;
    memoryLimitWarningDismissed = state.memoryLimitWarningDismissed;
    updateInstallMode = state.updateInstallMode;
    updateChannel = state.updateChannel;
    tlsFragmentationMode = state.tlsFragmentationMode;
    allowUntrustedProxyCertificates = state.allowUntrustedProxyCertificates;
    allowUntrustedSubscriptionCertificates =
        state.allowUntrustedSubscriptionCertificates;
    vpnInboundEnabled = state.vpnInboundEnabled;
    vpnMtu = state.vpnMtu;
    vpnStrictRoute = state.vpnStrictRoute;
    vpnTunImplementation = state.vpnTunImplementation;
    proxyInboundEnabled = state.proxyInboundEnabled;
    if (!vpnInboundEnabled && !proxyInboundEnabled) {
      vpnInboundEnabled = true;
    }
    proxyAllowLan = state.proxyAllowLan;
    proxyMixedListen = proxyAllowLan ? '0.0.0.0' : '127.0.0.1';
    proxyMixedPort = state.proxyMixedPort;
    proxyUsername = normalizeProxyUsername(state.proxyUsername);
    proxyPassword = state.proxyPassword.trim();
    if (!isValidProxyPassword(proxyPassword)) {
      proxyPassword = generateProxyPassword();
    }
    dnsDirectPreset = state.dnsDirectPreset;
    dnsDirectResolver = state.dnsDirectResolver;
    dnsProxyPreset = state.dnsProxyPreset;
    dnsProxyResolver = state.dnsProxyResolver;
    dnsPreferIpv6 = state.dnsPreferIpv6;
    dnsSecureOnly = state.dnsSecureOnly;
    dnsDirectThroughProxy = state.dnsDirectThroughProxy;
    russiaDnsDirectResolver = normalizedRussiaDnsDirectResolver(
      state.russiaDnsDirectResolver,
    );
    _enforceSecureDnsResolvers();
    urlTestUrl = normalizedUrlTestUrl(state.urlTestUrl);
    urlTestIntervalSeconds = state.urlTestIntervalSeconds;
    urlTestTimeoutSeconds = state.urlTestTimeoutSeconds;
    urlTestConcurrency = state.urlTestConcurrency;
    urlTestUnavailableCheckIntervalSeconds =
        state.urlTestUnavailableCheckIntervalSeconds;
    locationLookupLimit = state.locationLookupLimit.clamp(0, 50).toInt();
    locationLookupTimeoutSeconds = state.locationLookupTimeoutSeconds
        .clamp(2, 30)
        .toInt();
    locationLookupConcurrency = state.locationLookupConcurrency
        .clamp(1, 60)
        .toInt();
    blockLeaks = state.blockLeaks;
    adBlockEnabled = state.adBlockEnabled;
    trafficRulePreset =
        state.trafficRulePreset == TrafficRulePreset.none &&
            state.useRussiaRouteData
        ? TrafficRulePreset.russianServicesDirect
        : state.trafficRulePreset;
    // Kept only for the legacy config builder call while profiles migrate.
    // The persisted source of truth is now trafficRulePreset.
    useRussiaRouteData =
        trafficRulePreset == TrafficRulePreset.russianServicesDirect;
    bypassLocalNetwork = state.bypassLocalNetwork;
    splitRoutingMode = state.splitRoutingMode;
    splitRoutingPackages = List<String>.from(state.splitRoutingPackages);
    singBoxLogLevel = state.singBoxLogLevel;
    experimentalTcpFastOpen = state.experimentalTcpFastOpen;
    experimentalTcpMultiPath = state.experimentalTcpMultiPath;
    experimentalInterruptExistingConnections =
        state.experimentalInterruptExistingConnections;
    experimentalUrlTestStrictTolerance =
        state.experimentalUrlTestStrictTolerance;
    experimentalFakeIpEnabled =
        state.experimentalFakeIpEnabled &&
        vpnInboundEnabled &&
        splitRoutingMode == SplitRoutingMode.disabled;
  }

  AppSettingsChange setLocale(String value) {
    final normalized = value == 'system' ? 'system' : value;
    if (localeCode == normalized) {
      return const AppSettingsChange.none();
    }
    localeCode = normalized;
    return const AppSettingsChange(changed: true);
  }

  AppSettingsChange setThemePreference(AppThemePreference value) {
    if (themePreference == value) {
      return const AppSettingsChange.none();
    }
    themePreference = value;
    return const AppSettingsChange(changed: true);
  }

  AppSettingsChange setHapticEnabled(bool value) {
    if (hapticEnabled == value) {
      return const AppSettingsChange.none();
    }
    hapticEnabled = value;
    return const AppSettingsChange(changed: true);
  }

  AppSettingsChange setStatusNotificationEnabled(bool value) {
    if (statusNotificationEnabled == value) {
      return const AppSettingsChange.none();
    }
    statusNotificationEnabled = value;
    return const AppSettingsChange(changed: true);
  }

  AppSettingsChange setNotificationTrafficDisplayMode(
    NotificationTrafficDisplayMode value,
  ) {
    if (notificationTrafficDisplayMode == value) {
      return const AppSettingsChange.none();
    }
    notificationTrafficDisplayMode = value;
    return const AppSettingsChange(changed: true);
  }

  AppSettingsChange setNotificationTrafficRefreshSeconds(int value) {
    final normalized = value.clamp(1, 10).toInt();
    if (notificationTrafficRefreshSeconds == normalized) {
      return const AppSettingsChange.none();
    }
    notificationTrafficRefreshSeconds = normalized;
    return const AppSettingsChange(changed: true);
  }

  AppSettingsChange setHideServerIp(bool value) {
    if (hideServerIp == value) {
      return const AppSettingsChange.none();
    }
    hideServerIp = value;
    return const AppSettingsChange(changed: true, publishTraffic: true);
  }

  AppSettingsChange setProxySort(String value) {
    final normalized =
        const {
          'source',
          'latency',
          'working',
          'name',
          'country',
        }.contains(value)
        ? value
        : 'source';
    if (proxySort == normalized) {
      return const AppSettingsChange.none();
    }
    proxySort = normalized;
    return const AppSettingsChange(changed: true);
  }

  AppSettingsChange setAccentColor(String value) {
    final normalized = normalizeAccentColorHex(value);
    if (accentColorHex == normalized) {
      return const AppSettingsChange.none();
    }
    accentColorHex = normalized;
    return const AppSettingsChange(changed: true, refreshTheme: true);
  }

  AppSettingsChange setMemoryLimitEnabled(
    bool value, {
    bool warningDismissed = false,
  }) {
    if (memoryLimitEnabled == value &&
        (!warningDismissed || memoryLimitWarningDismissed)) {
      return const AppSettingsChange.none();
    }
    memoryLimitEnabled = value;
    if (warningDismissed) {
      memoryLimitWarningDismissed = true;
    }
    return const AppSettingsChange(changed: true, syncRuntimeFlags: true);
  }

  AppSettingsChange setUpdateInstallMode(AppUpdateInstallMode value) {
    if (updateInstallMode == value) {
      return const AppSettingsChange.none();
    }
    updateInstallMode = value;
    return const AppSettingsChange(changed: true);
  }

  AppSettingsChange setUpdateChannel(AppUpdateChannel value) {
    if (updateChannel == value) {
      return const AppSettingsChange.none();
    }
    updateChannel = value;
    return const AppSettingsChange(changed: true);
  }

  AppSettingsChange setVpnInboundEnabled(bool value) {
    final disableFakeIp = !value && experimentalFakeIpEnabled;
    if (vpnInboundEnabled == value && !disableFakeIp) {
      return const AppSettingsChange.none();
    }
    vpnInboundEnabled = value;
    if (disableFakeIp) {
      experimentalFakeIpEnabled = false;
    }
    if (!vpnInboundEnabled && !proxyInboundEnabled) {
      proxyInboundEnabled = true;
    }
    return const AppSettingsChange(
      changed: true,
      configReason: 'vpn inbound changed',
    );
  }

  AppSettingsChange setVpnMtu(int value) {
    if (vpnMtu == value) {
      return const AppSettingsChange.none();
    }
    vpnMtu = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'vpn mtu changed',
    );
  }

  AppSettingsChange setVpnStrictRoute(bool value) {
    if (vpnStrictRoute == value) {
      return const AppSettingsChange.none();
    }
    vpnStrictRoute = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'vpn strict route changed',
    );
  }

  AppSettingsChange setVpnTunImplementation(TunImplementationPreference value) {
    if (vpnTunImplementation == value) {
      return const AppSettingsChange.none();
    }
    vpnTunImplementation = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'vpn tun implementation changed',
    );
  }

  AppSettingsChange setProxyInboundEnabled(bool value) {
    if (proxyInboundEnabled == value) {
      return const AppSettingsChange.none();
    }
    proxyInboundEnabled = value;
    if (proxyInboundEnabled && !isValidProxyUsername(proxyUsername)) {
      proxyUsername = defaultProxyUsername;
    }
    if (proxyInboundEnabled && !isValidProxyPassword(proxyPassword)) {
      proxyPassword = generateProxyPassword();
    }
    if (!proxyInboundEnabled && !vpnInboundEnabled) {
      vpnInboundEnabled = true;
    }
    return const AppSettingsChange(
      changed: true,
      configReason: 'proxy inbound changed',
    );
  }

  AppSettingsChange setProxyAllowLan(bool value) {
    if (proxyAllowLan == value) {
      return const AppSettingsChange.none();
    }
    proxyAllowLan = value;
    proxyMixedListen = value ? '0.0.0.0' : '127.0.0.1';
    if (value && !isValidProxyUsername(proxyUsername)) {
      proxyUsername = defaultProxyUsername;
    }
    if (value && !isValidProxyPassword(proxyPassword)) {
      proxyPassword = generateProxyPassword();
    }
    return const AppSettingsChange(
      changed: true,
      configReason: 'proxy allow lan changed',
    );
  }

  AppSettingsChange setProxyMixedPort(int value) {
    if (proxyMixedPort == value) {
      return const AppSettingsChange.none();
    }
    proxyMixedPort = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'proxy port changed',
    );
  }

  AppSettingsChange setInboundConnectionMode(InboundConnectionMode value) {
    final nextVpnEnabled = value == InboundConnectionMode.vpn;
    final nextProxyEnabled = value == InboundConnectionMode.proxy;
    if (vpnInboundEnabled == nextVpnEnabled &&
        proxyInboundEnabled == nextProxyEnabled) {
      return const AppSettingsChange.none();
    }
    vpnInboundEnabled = nextVpnEnabled;
    proxyInboundEnabled = nextProxyEnabled;
    if (proxyInboundEnabled && !isValidProxyUsername(proxyUsername)) {
      proxyUsername = defaultProxyUsername;
    }
    if (proxyInboundEnabled && !isValidProxyPassword(proxyPassword)) {
      proxyPassword = generateProxyPassword();
    }
    return const AppSettingsChange(
      changed: true,
      configReason: 'inbound connection mode changed',
    );
  }

  AppSettingsChange regenerateProxyPassword() {
    proxyPassword = generateProxyPassword();
    return AppSettingsChange(
      changed: true,
      configReason: proxyInboundEnabled ? 'proxy credentials changed' : null,
    );
  }

  AppSettingsChange setProxyUsername(String value) {
    final normalized = value.trim();
    if (!isValidProxyUsername(normalized) || proxyUsername == normalized) {
      return const AppSettingsChange.none();
    }
    proxyUsername = normalized;
    return AppSettingsChange(
      changed: true,
      configReason: proxyInboundEnabled ? 'proxy credentials changed' : null,
    );
  }

  AppSettingsChange setProxyPassword(String value) {
    final normalized = value.trim();
    if (!isValidProxyPassword(normalized) || proxyPassword == normalized) {
      return const AppSettingsChange.none();
    }
    proxyPassword = normalized;
    return AppSettingsChange(
      changed: true,
      configReason: proxyInboundEnabled ? 'proxy credentials changed' : null,
    );
  }

  AppSettingsChange setDnsDirectPreset(String value) {
    if (dnsDirectPreset == value) {
      return const AppSettingsChange.none();
    }
    dnsDirectPreset = value;
    syncDnsPresetValue(isDirect: true);
    _enforceSecureDnsResolvers();
    return const AppSettingsChange(
      changed: true,
      configReason: 'dns direct preset changed',
    );
  }

  AppSettingsChange setDnsDirectResolver(String value) {
    final requested = normalizeDnsResolverInput(value);
    final normalized = dnsSecureOnly && !isEncryptedDnsResolver(requested)
        ? defaultSecureDnsDirectResolver
        : requested;
    if (dnsDirectResolver == normalized) {
      return const AppSettingsChange.none();
    }
    dnsDirectResolver = normalized;
    return const AppSettingsChange(
      changed: true,
      configReason: 'dns direct resolver changed',
    );
  }

  AppSettingsChange setDnsProxyPreset(String value) {
    if (dnsProxyPreset == value) {
      return const AppSettingsChange.none();
    }
    dnsProxyPreset = value;
    syncDnsPresetValue(isDirect: false);
    _enforceSecureDnsResolvers();
    return const AppSettingsChange(
      changed: true,
      configReason: 'dns proxy preset changed',
    );
  }

  AppSettingsChange setDnsProxyResolver(String value) {
    final requested = normalizeDnsResolverInput(value);
    final normalized = dnsSecureOnly && !isEncryptedDnsResolver(requested)
        ? defaultSecureDnsProxyResolver
        : requested;
    if (dnsProxyResolver == normalized) {
      return const AppSettingsChange.none();
    }
    dnsProxyResolver = normalized;
    return const AppSettingsChange(
      changed: true,
      configReason: 'dns proxy resolver changed',
    );
  }

  AppSettingsChange setDnsPreferIpv6(bool value) {
    if (dnsPreferIpv6 == value) {
      return const AppSettingsChange.none();
    }
    dnsPreferIpv6 = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'dns ip preference changed',
    );
  }

  AppSettingsChange setDnsSecureOnly(bool value) {
    if (dnsSecureOnly == value) {
      return const AppSettingsChange.none();
    }
    dnsSecureOnly = value;
    _enforceSecureDnsResolvers();
    return const AppSettingsChange(
      changed: true,
      configReason: 'secure DNS policy changed',
    );
  }

  AppSettingsChange setDnsDirectThroughProxy(bool value) {
    if (dnsDirectThroughProxy == value) {
      return const AppSettingsChange.none();
    }
    dnsDirectThroughProxy = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'direct DNS detour changed',
    );
  }

  AppSettingsChange setRussiaDnsDirectResolver(String value) {
    final normalized = normalizedRussiaDnsDirectResolver(value);
    if (russiaDnsDirectResolver == normalized) {
      return const AppSettingsChange.none();
    }
    russiaDnsDirectResolver = normalized;
    return const AppSettingsChange(
      changed: true,
      configReason: 'russia dns direct resolver changed',
    );
  }

  AppSettingsChange setUrlTestUrl(String value) {
    final normalized = normalizedUrlTestUrl(value);
    if (urlTestUrl == normalized) {
      return const AppSettingsChange.none();
    }
    urlTestUrl = normalized;
    return const AppSettingsChange(
      changed: true,
      configReason: 'urltest url changed',
    );
  }

  AppSettingsChange setUrlTestIntervalSeconds(int value) {
    final normalized = value <= 0
        ? appSettingsStandardUrlTestIntervalSeconds
        : value;
    if (urlTestIntervalSeconds == normalized) {
      return const AppSettingsChange.none();
    }
    urlTestIntervalSeconds = normalized;
    return const AppSettingsChange(
      changed: true,
      configReason: 'urltest interval changed',
    );
  }

  AppSettingsChange setUrlTestTimeoutSeconds(int value) {
    final normalized = value <= 0
        ? appSettingsDefaultUrlTestTimeoutSeconds
        : value;
    if (urlTestTimeoutSeconds == normalized) {
      return const AppSettingsChange.none();
    }
    urlTestTimeoutSeconds = normalized;
    return const AppSettingsChange(
      changed: true,
      configReason: 'urltest timeout changed',
    );
  }

  AppSettingsChange setUrlTestConcurrency(int value) {
    const fallback = appSettingsStandardUrlTestConcurrency;
    final normalized = (value <= 0 ? fallback : value).clamp(1, 8);
    if (urlTestConcurrency == normalized) {
      return const AppSettingsChange.none();
    }
    urlTestConcurrency = normalized;
    return const AppSettingsChange(
      changed: true,
      configReason: 'urltest concurrency changed',
    );
  }

  AppSettingsChange setUrlTestUnavailableCheckIntervalSeconds(int value) {
    const fallback = appSettingsStandardUrlTestUnavailableCheckIntervalSeconds;
    final normalized = (value <= 0 ? fallback : value).clamp(120, 3600);
    if (urlTestUnavailableCheckIntervalSeconds == normalized) {
      return const AppSettingsChange.none();
    }
    urlTestUnavailableCheckIntervalSeconds = normalized;
    return const AppSettingsChange(
      changed: true,
      configReason: 'urltest unavailable check interval changed',
    );
  }

  AppSettingsChange setLocationLookupLimit(int value) {
    final normalized = value.clamp(0, 50).toInt();
    if (locationLookupLimit == normalized) {
      return const AppSettingsChange.none();
    }
    locationLookupLimit = normalized;
    return const AppSettingsChange(
      changed: true,
      scheduleLocationRefresh: true,
    );
  }

  AppSettingsChange setLocationLookupTimeoutSeconds(int value) {
    final normalized = value.clamp(2, 30).toInt();
    if (locationLookupTimeoutSeconds == normalized) {
      return const AppSettingsChange.none();
    }
    locationLookupTimeoutSeconds = normalized;
    return const AppSettingsChange(
      changed: true,
      scheduleLocationRefresh: true,
    );
  }

  AppSettingsChange setLocationLookupConcurrency(int value) {
    final normalized = value.clamp(1, 60).toInt();
    if (locationLookupConcurrency == normalized) {
      return const AppSettingsChange.none();
    }
    locationLookupConcurrency = normalized;
    return const AppSettingsChange(
      changed: true,
      pumpLocationLookupWaiters: true,
      scheduleLocationRefresh: true,
    );
  }

  AppSettingsChange setBlockLeaks(bool value) {
    if (blockLeaks == value) {
      return const AppSettingsChange.none();
    }
    blockLeaks = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'block leaks changed',
    );
  }

  AppSettingsChange setAdBlockEnabled(bool value) {
    if (adBlockEnabled == value) {
      return const AppSettingsChange.none();
    }
    adBlockEnabled = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'adblock changed',
    );
  }

  AppSettingsChange setRussiaRouteDataEnabled(bool value) {
    return setTrafficRulePreset(
      value ? TrafficRulePreset.russianServicesDirect : TrafficRulePreset.none,
    );
  }

  AppSettingsChange setTrafficRulePreset(TrafficRulePreset value) {
    if (trafficRulePreset == value) {
      return const AppSettingsChange.none();
    }
    trafficRulePreset = value;
    useRussiaRouteData = value == TrafficRulePreset.russianServicesDirect;
    return const AppSettingsChange(
      changed: true,
      configReason: 'traffic rule preset changed',
    );
  }

  AppSettingsChange setBypassLocalNetwork(bool value) {
    if (bypassLocalNetwork == value) {
      return const AppSettingsChange.none();
    }
    bypassLocalNetwork = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'bypass local network changed',
    );
  }

  AppSettingsChange setSplitRoutingMode(SplitRoutingMode value) {
    final disableFakeIp =
        value != SplitRoutingMode.disabled && experimentalFakeIpEnabled;
    if (splitRoutingMode == value && !disableFakeIp) {
      return const AppSettingsChange.none();
    }
    splitRoutingMode = value;
    if (disableFakeIp) {
      experimentalFakeIpEnabled = false;
    }
    return const AppSettingsChange(
      changed: true,
      configReason: 'split routing mode changed',
    );
  }

  AppSettingsChange setSplitRoutingPackages(List<String> value) {
    final normalized = normalizeSplitRoutingPackages(value);
    if (splitRoutingPackages.join('\n') == normalized.join('\n')) {
      return const AppSettingsChange.none();
    }
    splitRoutingPackages = normalized;
    return const AppSettingsChange(
      changed: true,
      configReason: 'split routing packages changed',
    );
  }

  AppSettingsChange setSingBoxLogLevel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || singBoxLogLevel == normalized) {
      return const AppSettingsChange.none();
    }
    singBoxLogLevel = normalized;
    return const AppSettingsChange(changed: true);
  }

  AppSettingsChange setExperimentalTcpFastOpen(bool value) {
    if (experimentalTcpFastOpen == value) {
      return const AppSettingsChange.none();
    }
    experimentalTcpFastOpen = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'experimental tcp fast open changed',
    );
  }

  AppSettingsChange setExperimentalTcpMultiPath(bool value) {
    if (experimentalTcpMultiPath == value) {
      return const AppSettingsChange.none();
    }
    experimentalTcpMultiPath = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'experimental tcp multipath changed',
    );
  }

  AppSettingsChange setExperimentalInterruptExistingConnections(bool value) {
    if (experimentalInterruptExistingConnections == value) {
      return const AppSettingsChange.none();
    }
    experimentalInterruptExistingConnections = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'experimental interrupt existing connections changed',
    );
  }

  AppSettingsChange setExperimentalUrlTestStrictTolerance(bool value) {
    if (experimentalUrlTestStrictTolerance == value) {
      return const AppSettingsChange.none();
    }
    experimentalUrlTestStrictTolerance = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'experimental urltest strict tolerance changed',
    );
  }

  AppSettingsChange setExperimentalFakeIpEnabled(bool value) {
    final normalized =
        value &&
        vpnInboundEnabled &&
        splitRoutingMode == SplitRoutingMode.disabled;
    if (experimentalFakeIpEnabled == normalized) {
      return const AppSettingsChange.none();
    }
    experimentalFakeIpEnabled = normalized;
    return const AppSettingsChange(
      changed: true,
      configReason: 'experimental fakeip changed',
    );
  }

  AppSettingsChange setTlsFragmentationMode(TlsFragmentationMode value) {
    if (tlsFragmentationMode == value) {
      return const AppSettingsChange.none();
    }
    tlsFragmentationMode = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'tls fragmentation mode changed',
    );
  }

  AppSettingsChange setAllowUntrustedProxyCertificates(bool value) {
    if (allowUntrustedProxyCertificates == value) {
      return const AppSettingsChange.none();
    }
    allowUntrustedProxyCertificates = value;
    return const AppSettingsChange(
      changed: true,
      configReason: 'proxy TLS certificate verification changed',
    );
  }

  AppSettingsChange setAllowUntrustedSubscriptionCertificates(bool value) {
    if (allowUntrustedSubscriptionCertificates == value) {
      return const AppSettingsChange.none();
    }
    allowUntrustedSubscriptionCertificates = value;
    return const AppSettingsChange(changed: true);
  }

  void syncDnsPresetValue({required bool isDirect}) {
    const directPresets = {
      'device': 'device://network',
      'cloudflare': 'udp://1.1.1.1',
      'cloudflare_dot': defaultSecureDnsDirectResolver,
      'cloudflare_doh': 'https://dns.cloudflare.com/dns-query',
    };
    const proxyPresets = {
      'device': 'device://network',
      'cloudflare': 'udp://1.1.1.1',
      'cloudflare_dot': defaultSecureDnsDirectResolver,
      'cloudflare_doh': 'https://dns.cloudflare.com/dns-query',
    };
    final preset = isDirect ? dnsDirectPreset : dnsProxyPreset;
    if (preset == 'custom') {
      return;
    }
    final value = isDirect ? directPresets[preset] : proxyPresets[preset];
    if (value == null) {
      return;
    }
    if (isDirect) {
      dnsDirectResolver = value;
    } else {
      dnsProxyResolver = value;
    }
  }

  void _enforceSecureDnsResolvers() {
    if (!dnsSecureOnly) {
      return;
    }
    if (!isEncryptedDnsResolver(dnsDirectResolver) ||
        dnsDirectPreset == 'device' ||
        dnsDirectPreset == 'cloudflare') {
      dnsDirectPreset = 'cloudflare_dot';
      dnsDirectResolver = defaultSecureDnsDirectResolver;
    }
    if (!isEncryptedDnsResolver(dnsProxyResolver) ||
        dnsProxyPreset == 'device' ||
        dnsProxyPreset == 'cloudflare') {
      dnsProxyPreset = 'cloudflare_doh';
      dnsProxyResolver = defaultSecureDnsProxyResolver;
    }
    if (!isEncryptedDnsResolver(russiaDnsDirectResolver)) {
      russiaDnsDirectResolver = defaultSecureDnsDirectResolver;
    }
  }

  static String normalizeAccentColorHex(String value) => switch (value) {
    'dynamic-2' || 'dynamic-3' => 'default',
    _ => value,
  };

  static String normalizedUrlTestUrl(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? defaultUrlTestUrl : normalized;
  }

  static String normalizedRussiaDnsDirectResolver(String value) {
    final normalized = normalizeDnsResolverInput(value);
    return normalized.isEmpty ? defaultRussiaDnsDirectResolver : normalized;
  }
}
