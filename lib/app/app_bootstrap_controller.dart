import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/data/subscription/subscription_fetcher.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/singbox/core_config_migration.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

typedef BootstrapAction = Future<void> Function();
typedef SettingsStoreLoader = Future<AppSettingsStore> Function();
typedef AppVersionInfoLoader = Future<AppVersionInfo> Function();
typedef CoreCapabilitiesLoader = Future<LibboxCapabilities> Function();
typedef AdBlockStatusLoader = Future<AdBlockRuleSetStatus> Function();
typedef RussiaRouteStatusLoader = Future<RussiaRouteDataStatus> Function();

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.store,
    required this.ownsStore,
    required this.state,
    required this.adBlockStatus,
    required this.russiaRouteDataStatus,
    required this.appVersionInfo,
    required this.coreCapabilities,
    required this.pendingCoreConfigMigration,
    required this.usesInMemoryStore,
  });

  final AppSettingsStore store;
  final bool ownsStore;
  final AppSettingsState state;
  final AdBlockRuleSetStatus adBlockStatus;
  final RussiaRouteDataStatus russiaRouteDataStatus;
  final AppVersionInfo appVersionInfo;
  final LibboxCapabilities coreCapabilities;
  final CoreConfigMigrationResult? pendingCoreConfigMigration;
  final bool usesInMemoryStore;
}

/// Optional rule-set status loaded after the first application frame.
///
/// The underlying files are only required to build a runtime configuration
/// when the corresponding feature is enabled. Keeping a disabled feature out
/// of the critical startup path makes the home screen available sooner while
/// preserving the safe path for an enabled feature.
class BootstrapDeferredStatuses {
  const BootstrapDeferredStatuses({
    required this.adBlockStatus,
    required this.russiaRouteDataStatus,
  });

  final AdBlockRuleSetStatus adBlockStatus;
  final RussiaRouteDataStatus russiaRouteDataStatus;
}

/// Loads the durable application state without owning any Flutter UI state.
///
/// Keeping storage, native metadata and core compatibility checks here makes
/// bootstrap independently testable and prevents the root widget from becoming
/// the owner of every startup dependency.
class AppBootstrapController {
  AppBootstrapController({
    required this.fallbackClientVersionLabel,
    BootstrapAction? initializeHive,
    BootstrapAction? initializeSubscriptions,
    SettingsStoreLoader? openSettingsStore,
    AppVersionInfoLoader? loadAppVersionInfo,
    CoreCapabilitiesLoader? loadCoreCapabilities,
    AdBlockStatusLoader? loadAdBlockStatus,
    RussiaRouteStatusLoader? loadRussiaRouteStatus,
  }) : _initializeHive = initializeHive ?? HiveAppSettingsStore.initHive,
       _initializeSubscriptions =
           initializeSubscriptions ?? SubscriptionStore.initForBootstrap,
       _openSettingsStore = openSettingsStore ?? HiveAppSettingsStore.open,
       _loadAppVersionInfo =
           loadAppVersionInfo ??
           (() => SingboxRuntime.instance.getAppVersionInfo()),
       _loadCoreCapabilities =
           loadCoreCapabilities ??
           (() => SingboxRuntime.instance.getCoreCapabilities()),
       _loadAdBlockStatus =
           loadAdBlockStatus ?? AdBlockRuleSetService.instance.loadStatus,
       _loadRussiaRouteStatus =
           loadRussiaRouteStatus ?? RussiaRouteDataService.instance.loadStatus;

  final String fallbackClientVersionLabel;
  final BootstrapAction _initializeHive;
  final BootstrapAction _initializeSubscriptions;
  final SettingsStoreLoader _openSettingsStore;
  final AppVersionInfoLoader _loadAppVersionInfo;
  final CoreCapabilitiesLoader _loadCoreCapabilities;
  final AdBlockStatusLoader _loadAdBlockStatus;
  final RussiaRouteStatusLoader _loadRussiaRouteStatus;

  Future<AppBootstrapResult> load({AppSettingsStore? providedStore}) async {
    AppSettingsStore? store;
    var ownsStore = false;
    late AppSettingsState state;
    const adBlockStatus = AdBlockRuleSetStatus.unavailable();
    const russiaRouteDataStatus = RussiaRouteDataStatus.unavailable();
    final appVersionInfoFuture = readAppVersionInfo();
    final usesInMemoryStore = providedStore is MemoryAppSettingsStore;

    try {
      if (usesInMemoryStore) {
        store = providedStore;
      } else {
        await _initializeHive();
        final subscriptionInitFuture = _initializeSubscriptions();
        final storeFuture = providedStore == null
            ? _openSettingsStore()
            : Future<AppSettingsStore>.value(providedStore);
        await subscriptionInitFuture;
        store = await storeFuture;
        ownsStore = providedStore == null;
      }
      state = await store.loadState();
    } catch (error, stackTrace) {
      AppLogStore.error(
        'bootstrap',
        'Failed to bootstrap app, using in-memory defaults: '
            '$error\n$stackTrace',
      );
      if (providedStore == null && store != null) {
        try {
          await store.close();
        } catch (_) {}
      }
      store = MemoryAppSettingsStore();
      ownsStore = providedStore == null;
      state = _fallbackSettingsState();
    }

    final appVersionInfo = await appVersionInfoFuture;
    // The native capability bridge is needed for migration planning, but it
    // must not compete with encrypted Hive I/O during cold start. On slower
    // devices that contention was visible as a blank 1–3 second launch.
    final coreCapabilities = await _readCoreCapabilities();
    final migration = CoreConfigMigration.plan(
      state: state,
      capabilities: coreCapabilities,
    );
    CoreConfigMigrationResult? pendingCoreConfigMigration;
    if (migration.requiresValidation) {
      pendingCoreConfigMigration = migration;
      final persistedSchemaVersion = state.coreConfigSchemaVersion;
      state = migration.state.copyWith(
        coreConfigSchemaVersion: persistedSchemaVersion,
      );
      AppLogStore.info(
        'sing-box',
        'core config migration prepared '
            'from=$persistedSchemaVersion '
            'to=${migration.state.coreConfigSchemaVersion} '
            'changes=${migration.changes.join(',')}',
      );
    } else if (migration.status == CoreConfigMigrationStatus.blocked) {
      AppLogStore.warning(
        'sing-box',
        'core config migration blocked: ${migration.blockReason}',
      );
    }

    return AppBootstrapResult(
      store: store,
      ownsStore: ownsStore,
      state: state,
      adBlockStatus: adBlockStatus,
      russiaRouteDataStatus: russiaRouteDataStatus,
      appVersionInfo: appVersionInfo,
      coreCapabilities: coreCapabilities,
      pendingCoreConfigMigration: pendingCoreConfigMigration,
      usesInMemoryStore: usesInMemoryStore,
    );
  }

  /// Reads status data for the routing settings UI.
  ///
  /// These file-system checks are intentionally kept out of the critical
  /// bootstrap path even when the corresponding feature is enabled. The
  /// config builder reads the persisted settings and rule-set services
  /// directly; a status only changes what the UI displays.
  Future<BootstrapDeferredStatuses> loadDeferredStatuses({
    bool includeAdBlock = true,
    bool includeRussiaRouteData = true,
  }) async {
    final adBlockStatusFuture = includeAdBlock
        ? _loadAdBlockStatusSafely()
        : Future<AdBlockRuleSetStatus>.value(
            const AdBlockRuleSetStatus.unavailable(),
          );
    final russiaRouteStatusFuture = includeRussiaRouteData
        ? _loadRussiaRouteStatusSafely()
        : Future<RussiaRouteDataStatus>.value(
            const RussiaRouteDataStatus.unavailable(),
          );
    return BootstrapDeferredStatuses(
      adBlockStatus: await adBlockStatusFuture,
      russiaRouteDataStatus: await russiaRouteStatusFuture,
    );
  }

  Future<AdBlockRuleSetStatus> _loadAdBlockStatusSafely() async {
    try {
      return await _loadAdBlockStatus();
    } catch (_) {
      return const AdBlockRuleSetStatus.unavailable();
    }
  }

  Future<RussiaRouteDataStatus> _loadRussiaRouteStatusSafely() async {
    try {
      return await _loadRussiaRouteStatus();
    } catch (_) {
      return const RussiaRouteDataStatus.unavailable();
    }
  }

  Future<AppVersionInfo> readAppVersionInfo() async {
    try {
      final info = await _loadAppVersionInfo();
      if (info.versionName.trim().isNotEmpty) {
        SubscriptionFetcher.configureAppVersion(info.versionName);
        return info;
      }
    } catch (error) {
      AppLogStore.warning('app version', 'Failed to read app version: $error');
    }
    SubscriptionFetcher.configureAppVersion(fallbackClientVersionLabel);
    return AppVersionInfo(
      packageName: '',
      versionName: fallbackClientVersionLabel,
      versionCode: 0,
    );
  }

  Future<LibboxCapabilities> _readCoreCapabilities() async {
    try {
      return await _loadCoreCapabilities();
    } catch (error) {
      AppLogStore.warning(
        'sing-box',
        'Failed to read core capabilities; runtime start is disabled: $error',
      );
      return LibboxCapabilities.incompatible;
    }
  }

  AppSettingsState _fallbackSettingsState() {
    return const AppSettingsState(
      onboardingCompleted: false,
      activeProfileId: '',
      selectedProxyTag: '',
      localeCode: 'system',
      themePreference: AppThemePreference.system,
      accentColorHex: 'default',
      hapticEnabled: true,
      hideServerIp: false,
      progressiveBlurEnabled: false,
      tlsFragmentationMode: TlsFragmentationMode.disabled,
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
      urlTestConcurrency: 4,
      urlTestUnavailableCheckIntervalSeconds: 120,
      locationLookupLimit: 2,
      locationLookupTimeoutSeconds: 5,
      locationLookupConcurrency: 2,
      blockLeaks: false,
      adBlockEnabled: false,
      useRussiaRouteData: false,
      bypassLocalNetwork: true,
      splitRoutingMode: SplitRoutingMode.disabled,
      splitRoutingPackages: <String>[],
      singBoxLogLevel: 'warning',
      experimentalTcpFastOpen: true,
      experimentalTcpMultiPath: false,
      experimentalInterruptExistingConnections: true,
      experimentalUrlTestStrictTolerance: true,
    );
  }
}
