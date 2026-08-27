import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/app/active_proxy_ip_controller.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/app/app_bootstrap_controller.dart';
import 'package:meow_client/app/app_root_shell.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/deep_link_import.dart';
import 'package:meow_client/app/group_url_test_scheduler.dart';
import 'package:meow_client/app/latency_coordinator.dart';
import 'package:meow_client/app/network_recovery_controller.dart';
import 'package:meow_client/app/proxy_runtime_controller.dart';
import 'package:meow_client/app/proxy_selection_controller.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/app/providers/proxy_runtime_providers.dart';
import 'package:meow_client/app/providers/subscription_catalog_provider.dart';
import 'package:meow_client/app/providers/vpn_runtime_state_provider.dart';
import 'package:meow_client/app/providers/vpn_lifecycle_commands_provider.dart';
import 'package:meow_client/app/runtime_lifecycle_controller.dart';
import 'package:meow_client/app/runtime_connection_controller.dart';
import 'package:meow_client/app/runtime_command_coordinator.dart';
import 'package:meow_client/app/runtime_event_controller.dart';
import 'package:meow_client/app/runtime_intent_controller.dart';
import 'package:meow_client/app/runtime_operation_coordinator.dart';
import 'package:meow_client/app/runtime_recovery_controller.dart';
import 'package:meow_client/app/runtime_recovery_policy.dart';
import 'package:meow_client/app/runtime_session_coordinator.dart';
import 'package:meow_client/app/singbox_config_coordinator.dart';
import 'package:meow_client/app/subscription_coordinator.dart';
import 'package:meow_client/app/subscription_runtime_controller.dart';
import 'package:meow_client/app/traffic_status_reducer.dart';
import 'package:meow_client/app/subscription_profile_import_controller.dart';
import 'package:meow_client/app/subscription_profile_flow_controller.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/data/subscription/happ_crypto_link.dart';
import 'package:meow_client/data/subscription/subscription_fetcher.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/data/update/app_update_channel.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/features/home/home_presentation_builder.dart';
import 'package:meow_client/features/home/traffic_dashboard_page.dart';
import 'package:meow_client/features/legal/legal_consent_page.dart';
import 'package:meow_client/features/proxies/proxies_presentation_builder.dart';
import 'package:meow_client/features/proxies/proxy_panel_shell.dart';
import 'package:meow_client/features/settings/changelog_sheet.dart';
import 'package:meow_client/features/settings/settings_about_page.dart';
import 'package:meow_client/features/settings/settings_backup_actions.dart';
import 'package:meow_client/features/settings/settings_dns_page.dart';
import 'package:meow_client/features/settings/settings_experimental_page.dart';
import 'package:meow_client/features/settings/settings_general_page.dart';
import 'package:meow_client/features/settings/settings_inbound_page.dart';
import 'package:meow_client/features/settings/settings_logs_page.dart';
import 'package:meow_client/features/settings/settings_page.dart';
import 'package:meow_client/features/settings/settings_presentation_builder.dart';
import 'package:meow_client/features/settings/settings_routing_page.dart';
import 'package:meow_client/features/settings/settings_security_page.dart';
import 'package:meow_client/features/settings/settings_subscriptions_page.dart';
import 'package:meow_client/features/settings/settings_update_page.dart';
import 'package:meow_client/features/subscriptions/subscription_error_message.dart';
import 'package:meow_client/features/subscriptions/subscriptions_page.dart';
import 'package:meow_client/features/welcome/welcome_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';
import 'package:meow_client/models/core_integration_diagnostics.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/singbox/core_config_migration.dart';
import 'package:meow_client/singbox/singbox_config_builder.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';
import 'package:meow_client/theme/demo_app_theme.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

class MeowClient extends ConsumerStatefulWidget {
  const MeowClient({super.key, this.store});

  final AppSettingsStore? store;

  @override
  ConsumerState<MeowClient> createState() => _MeowClientState();
}

class _MeowClientState extends ConsumerState<MeowClient>
    with WidgetsBindingObserver {
  static const _fallbackClientVersionLabel = '0.3.1';
  static const _requiredLegalVersion = '0.2.1';
  static final RegExp _quickTileCountryCodePattern = RegExp(r'^[A-Z]{2}$');
  static const _lowestProxyTag = lowestProxyTag;
  static const _derivedCacheBuildDebounce = Duration(milliseconds: 160);
  static const _networkHeartbeatIntervalSeconds = 240;
  static const _trafficUiUpdateInterval = Duration(seconds: 1);
  static const _runtimeRecoveryStatusLogInterval = Duration(seconds: 5);
  static const _subscriptionOperationSoftWarningDelay = Duration(seconds: 15);
  static const _subscriptionOperationTimeout = Duration(seconds: 30);
  static const _androidImageCacheMaximumBytes = 32 * 1024 * 1024;
  static const _androidImageCacheMaximumEntries = 64;
  static const _proxyChainTargetSourceCacheMaximumEntries = 2;
  static const _largeProxyListCacheReleaseThreshold = 500;
  static const _veryLargeProxyListCacheReleaseThreshold = 2000;
  static const _largeProxyListCacheReleaseDelay = Duration(seconds: 4);
  static const _veryLargeProxyListCacheReleaseDelay = Duration(seconds: 1);
  static const _splitRoutingTemporarilyDisabled = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late ThemeData _lightTheme;
  late ThemeData _darkTheme;
  late ThemeData _amoledTheme;
  StreamSubscription<DeepLinkImportRequest>? _deepLinkImportSubscription;
  AppSettingsStore? _store;
  Timer? _subscriptionAutoRefreshTimer;
  Timer? _locationLookupTimer;
  Timer? _derivedCacheBuildTimer;
  Timer? _proxyListCacheReleaseTimer;
  Timer? _trafficUiUpdateTimer;
  Timer? _vpnNotificationSyncTimer;
  Timer? _resumeForegroundSyncTimer;
  bool _autoRefreshInFlight = false;
  bool _ownsStore = false;
  bool _ready = false;
  bool _onboardingCompleted = false;
  String _acceptedLegalVersion = '';
  int? _acceptedLegalAtMillis;
  bool _runtimeErrorDialogVisible = false;
  bool _noValidOutboundsDialogVisible = false;
  bool _trafficAvailable = false;
  bool _deepLinkImportInFlight = false;
  bool _settingsBackupOperationInFlight = false;
  bool _locationLookupInFlight = false;
  bool _proxyPanelInteractionActive = false;
  bool _proxyPanelOpen = false;
  int _proxyPanelResetGeneration = 0;
  String _clientVersionLabel = _fallbackClientVersionLabel;
  int _clientVersionCode = 0;
  String _clientPackageName = '';
  String? _lastUpdateCleanupNoticeVersion;
  bool _updateCleanupInFlight = false;
  bool _notificationPermissionPromptAttempted = false;
  bool _notificationPermissionRequestInFlight = false;
  String _lastVpnNotificationPresentationSignature = '';
  late final SingboxRuntime _singboxRuntime;
  late final AppUpdateService _appUpdateService;
  late final RussiaRouteDataService _russiaRouteDataService;
  late final VpnLifecycleCommands _vpnLifecycleCommands;
  int _locationLookupActiveRequests = 0;
  int _locationLookupGeneration = 0;
  bool _locationLookupRefreshRequested = false;
  String _lastLocationLookupSignature = '';
  final Map<String, Future<Map<String, dynamic>>> _externalInfoLookups =
      <String, Future<Map<String, dynamic>>>{};
  final Queue<Completer<bool>> _locationLookupWaiters =
      Queue<Completer<bool>>();
  AdBlockRuleSetStatus _adBlockStatus =
      const AdBlockRuleSetStatus.unavailable();
  RussiaRouteDataStatus _russiaRouteDataStatus =
      const RussiaRouteDataStatus.unavailable();
  List<Map<String, dynamic>> _installedAppsCache =
      const <Map<String, dynamic>>[];
  Future<List<Map<String, dynamic>>>? _installedAppsWarmupFuture;
  int _installedAppsCacheGeneration = 0;
  int _downlinkBytesPerSecond = 0;
  int _uplinkBytesPerSecond = 0;
  int _uplinkTotalBytes = 0;
  int _downlinkTotalBytes = 0;
  DateTime? _connectedSince;
  List<TrafficSample> _trafficSamples = const <TrafficSample>[];
  bool _trafficDashboardOpen = false;
  final ValueNotifier<TrafficDashboardSnapshot> _trafficDashboardSnapshot =
      ValueNotifier<TrafficDashboardSnapshot>(TrafficDashboardSnapshot.empty);
  final ValueNotifier<TrafficUiSnapshot> _trafficUiSnapshot =
      ValueNotifier<TrafficUiSnapshot>(TrafficUiSnapshot.zero);
  Map<String, dynamic>? _pendingTrafficStatusEvent;
  DateTime _lastTrafficUiUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _networkInterfaceGeneration = 0;
  int _derivedCacheBuildGeneration = 0;
  final ProxyCacheBuildCoordinator _proxyCacheBuildCoordinator =
      ProxyCacheBuildCoordinator();
  String? _lastEmptyAfterDropInvalidWarningSubscriptionId;
  ActiveProxyIpSnapshot _activeProxyIp = const ActiveProxyIpSnapshot.idle();
  final ProxySelectionController _proxySelection = ProxySelectionController();
  final ActiveProxyIpController _activeProxyIpController =
      ActiveProxyIpController();
  static const TrafficStatusReducer _trafficStatusReducer =
      TrafficStatusReducer();
  late final AppBootstrapController _bootstrapController;
  final RuntimeLifecycleController _runtimeLifecycle =
      RuntimeLifecycleController();
  final RuntimeConnectionController _runtimeConnection =
      RuntimeConnectionController();
  final RuntimeIntentController _runtimeIntent = RuntimeIntentController();
  final RuntimeOperationCoordinator _runtimeOperations =
      RuntimeOperationCoordinator();
  final RuntimeRecoveryController _runtimeRecovery =
      RuntimeRecoveryController();
  final NetworkRecoveryController _networkRecovery =
      NetworkRecoveryController();
  final RuntimeSessionCoordinator _runtimeSession = RuntimeSessionCoordinator();
  late final RuntimeCommandCoordinator _runtimeCommands;
  late final SingboxConfigCoordinator _configCoordinator;
  late final RuntimeEventController _runtimeEvents;
  final ProxyRuntimeController _proxyRuntime = ProxyRuntimeController();
  late final LatencyCoordinator _latencyCoordinator;
  CoreConfigMigrationResult? _pendingCoreConfigMigration;
  final GroupUrlTestScheduler _groupUrlTestScheduler = GroupUrlTestScheduler();
  late final SubscriptionCoordinator _subscriptionCoordinator;
  static const SubscriptionProfileFlowController _subscriptionProfileFlow =
      SubscriptionProfileFlowController();
  AppProfileSummary? _activeProfileCache;
  AppProxySummary? _displayProxyCache;
  List<AppProxySummary> _activeProxiesCache = const [];
  late final ProxyRuntimeVisualStore _proxyRuntimeVisualStates;
  Map<String, AppProxySummary> _proxySummariesByTagCache =
      const <String, AppProxySummary>{};
  Map<String, List<AppProxySummary>> _activeGroupChildrenByTagCache =
      const <String, List<AppProxySummary>>{};
  int _activeTopLevelProxiesCount = 0;
  bool _fullProxyListCacheReady = false;
  bool _fullProxyListCacheRequested = false;
  Subscription? _activeLookupSubscription;
  List<Outbound> _activeVisibleOutboundsLookup = const [];
  Map<String, Outbound> _activeOutboundByTagLookup = const {};
  Map<String, SubscriptionGroup> _activeGroupByTagLookup = const {};
  final Map<String, List<AppProxySummary>> _proxyChainTargetSourceCache = {};
  DeepLinkImportRequest? _pendingDeepLinkImport;
  String? _lastQuickSettingsTileLabel;
  ColorScheme? _dynamicLightScheme;
  ColorScheme? _dynamicDarkScheme;
  int _groupsEventsSinceLastDiagnosticsLog = 0;
  DateTime? _lastGroupsDiagnosticsLogAt;
  Set<String> _preloadedProxyFlagCodes = const <String>{};
  static const _maximumPreloadedProxyFlags = 24;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  AppSettingsState? _lastAppliedSettingsState;
  Timer? _settingsConfigApplyTimer;
  int _settingsConfigApplyGeneration = 0;
  int _pendingSettingsConfigApplyGeneration = 0;

  VpnRuntimeState get _vpnRuntimeState => ref.read(vpnRuntimeStateProvider);
  AppConnectionPhase get _connectionPhase => _vpnRuntimeState.phase;
  bool get _connected => _vpnRuntimeState.connected;
  bool get _starting => _vpnRuntimeState.starting;
  bool get _runtimeTransitionInProgress =>
      _vpnRuntimeState.transitionInProgress;
  bool get _runtimeDesiredByUser => _runtimeIntent.desiredByUser;
  bool get _retryRuntimeOnResume => _runtimeIntent.retryOnResume;
  bool get _invalidOutboundRetryScheduled => _runtimeRecovery.retryScheduled;
  Set<String> get _excludedRuntimeOutboundTags =>
      _runtimeRecovery.excludedOutboundTags;

  bool get _legalAccepted => _acceptedLegalVersion == _requiredLegalVersion;

  AppSettingsController get _settings =>
      ref.read(appSettingsProvider).controller;

  SubscriptionCatalogState get _subscriptionCatalog =>
      ref.read(subscriptionCatalogProvider);

  List<Subscription> get _subscriptions => _subscriptionCatalog.subscriptions;
  set _subscriptions(List<Subscription> value) => ref
      .read(subscriptionCatalogProvider.notifier)
      .replaceSubscriptions(value);

  String get _activeProfileId => _subscriptionCatalog.activeProfileId;

  String get _selectedProxyTag => _subscriptionCatalog.selectedProxyTag;
  set _selectedProxyTag(String value) =>
      ref.read(subscriptionCatalogProvider.notifier).selectProxy(value);

  bool get _activeProfileRefreshInFlight =>
      _subscriptionCatalog.activeProfileRefreshing;
  set _activeProfileRefreshInFlight(bool value) => ref
      .read(subscriptionCatalogProvider.notifier)
      .setActiveProfileRefreshing(value);

  Subscription? get _activeSubscription =>
      _subscriptionCatalog.activeSubscription;

  AppProfileSummary? get _activeProfile {
    return _activeProfileCache;
  }

  Locale? get _locale =>
      _settings.localeCode == 'system' ? null : Locale(_settings.localeCode);
  ThemeMode get _themeMode => _settings.themeMode;
  AppThemePreference get _themePreference => _settings.themePreference;
  String get _accentColorHex => _settings.accentColorHex;
  bool get _memoryLimitEnabled => _settings.memoryLimitEnabled;
  bool get _memoryLimitWarningDismissed =>
      _settings.memoryLimitWarningDismissed;
  AppUpdateInstallMode get _updateInstallMode => _settings.updateInstallMode;
  AppUpdateChannel get _updateChannel => _settings.updateChannel;
  TlsFragmentationMode get _tlsFragmentationMode =>
      _settings.tlsFragmentationMode;
  bool get _allowUntrustedProxyCertificates =>
      _settings.allowUntrustedProxyCertificates;
  bool get _allowUntrustedSubscriptionCertificates =>
      _settings.allowUntrustedSubscriptionCertificates;
  bool get _hapticEnabled => _settings.hapticEnabled;
  bool get _statusNotificationEnabled => _settings.statusNotificationEnabled;
  NotificationTrafficDisplayMode get _notificationTrafficDisplayMode =>
      _settings.notificationTrafficDisplayMode;
  int get _notificationTrafficRefreshSeconds =>
      _settings.notificationTrafficRefreshSeconds;
  bool get _hideServerIp => _settings.hideServerIp;
  ProxySort get _proxySort => ProxySort.values.firstWhere(
    (value) => value.name == _settings.proxySort,
    orElse: () => ProxySort.source,
  );
  bool get _vpnInboundEnabled => _settings.vpnInboundEnabled;
  int get _vpnMtu => _settings.vpnMtu;
  bool get _vpnStrictRoute => _settings.vpnStrictRoute;
  TunImplementationPreference get _vpnTunImplementation =>
      _settings.vpnTunImplementation;
  bool get _proxyInboundEnabled => _settings.proxyInboundEnabled;
  bool get _proxyAllowLan => _settings.proxyAllowLan;
  String get _proxyMixedListen => _settings.proxyMixedListen;
  int get _proxyMixedPort => _settings.proxyMixedPort;
  String get _proxyUsername => _settings.proxyUsername;
  String get _proxyPassword => _settings.proxyPassword;
  String get _dnsDirectPreset => _settings.dnsDirectPreset;
  String get _dnsDirectResolver => _settings.dnsDirectResolver;
  String get _dnsProxyPreset => _settings.dnsProxyPreset;
  String get _dnsProxyResolver => _settings.dnsProxyResolver;
  bool get _dnsPreferIpv6 => _settings.dnsPreferIpv6;
  String get _russiaDnsDirectResolver => _settings.russiaDnsDirectResolver;
  String get _urlTestUrl => _settings.urlTestUrl;
  int get _urlTestIntervalSeconds => _settings.urlTestIntervalSeconds;
  int get _urlTestTimeoutSeconds => _settings.urlTestTimeoutSeconds;
  int get _urlTestConcurrency => _settings.urlTestConcurrency;
  int get _urlTestUnavailableCheckIntervalSeconds =>
      _settings.urlTestUnavailableCheckIntervalSeconds;
  int get _locationLookupLimit => _settings.locationLookupLimit;
  int get _locationLookupTimeoutSeconds =>
      _settings.locationLookupTimeoutSeconds;
  int get _locationLookupConcurrency => _settings.locationLookupConcurrency;
  bool get _blockLeaks => _settings.blockLeaks;
  bool get _adBlockEnabled => _settings.adBlockEnabled;
  set _adBlockEnabled(bool value) => _settings.adBlockEnabled = value;
  bool get _useRussiaRouteData => _settings.useRussiaRouteData;
  TrafficRulePreset get _trafficRulePreset => _settings.trafficRulePreset;
  bool get _bypassLocalNetwork => _settings.bypassLocalNetwork;
  SplitRoutingMode get _splitRoutingMode => _splitRoutingTemporarilyDisabled
      ? SplitRoutingMode.disabled
      : _settings.splitRoutingMode;
  List<String> get _splitRoutingPackages => _splitRoutingTemporarilyDisabled
      ? const <String>[]
      : _settings.splitRoutingPackages;
  String get _singBoxLogLevel => _settings.singBoxLogLevel;
  bool get _experimentalTcpFastOpen => _settings.experimentalTcpFastOpen;
  bool get _experimentalTcpMultiPath => _settings.experimentalTcpMultiPath;
  bool get _experimentalInterruptExistingConnections =>
      _settings.experimentalInterruptExistingConnections;
  bool get _experimentalUrlTestStrictTolerance =>
      _settings.experimentalUrlTestStrictTolerance;
  bool get _experimentalFakeIpEnabled => _settings.experimentalFakeIpEnabled;

  bool get _urlTestInFlight => ref.read(proxyLatencySessionProvider).running;

  int? get _lowestLatency => _proxyRuntime.lowestLatency;
  set _lowestLatency(int? value) => _proxyRuntime.lowestLatency = value;

  String? get _runtimeLowestOutboundTag =>
      _proxyRuntime.runtimeLowestOutboundTag;
  set _runtimeLowestOutboundTag(String? value) =>
      _proxyRuntime.runtimeLowestOutboundTag = value;

  Map<String, String> get _runtimeLowestSelections =>
      _proxyRuntime.runtimeLowestSelections;

  Map<String, int> get _runtimeLatencies => _proxyRuntime.runtimeLatencies;

  Set<String> get _unavailableLatencyTags =>
      _proxyRuntime.unavailableLatencyTags;

  Set<String> get _invalidatedLatencyTags =>
      _proxyRuntime.invalidatedLatencyTags;

  Map<String, String> get _latencyErrors => _proxyRuntime.latencyErrors;

  Map<String, int> get _latencyFailureCounts =>
      _proxyRuntime.latencyFailureCounts;

  Map<String, String> get _runtimeGroupSelections =>
      _proxyRuntime.runtimeGroupSelections;

  int? _effectiveOutboundLatency(Outbound outbound) {
    if (_proxyRuntime.isLatencyInvalidated(outbound.tag)) {
      return null;
    }
    return _runtimeLatencies[outbound.tag] ?? outbound.info.latestPing;
  }

  bool get _markAllServersRussia =>
      _activeSubscription?.markAllServersRussia ?? false;

  String? _runtimeLowestOutboundTagFor(String lowestTag) {
    return _proxyRuntime.runtimeLowestOutboundTagFor(lowestTag);
  }

  String? _activeRuntimeLowestOutboundTag() {
    if (!isLowestProxyTag(_selectedProxyTag)) {
      return null;
    }
    return _runtimeLowestOutboundTagFor(_selectedProxyTag);
  }

  Outbound? _lowestSelectedOutbound(
    String lowestTag,
    List<Outbound> visibleOutbounds,
  ) {
    final runtimeSelectedTag = _runtimeLowestOutboundTagFor(lowestTag);
    if (runtimeSelectedTag == null || runtimeSelectedTag.isEmpty) {
      return null;
    }
    final selectedGroup = _activeGroupByTagLookup[runtimeSelectedTag];
    final effectiveTag = selectedGroup == null
        ? runtimeSelectedTag
        : _runtimeGroupSelections[selectedGroup.tag]?.trim();
    if (effectiveTag == null ||
        effectiveTag.isEmpty ||
        _unavailableLatencyTags.contains(effectiveTag) ||
        _latencyErrors.containsKey(effectiveTag)) {
      return null;
    }
    final cached = _activeOutboundByTagLookup[effectiveTag];
    if (cached != null) {
      return cached;
    }
    for (final outbound in visibleOutbounds) {
      if (outbound.tag == effectiveTag) {
        return outbound;
      }
    }
    return null;
  }

  void _rebuildDerivedCaches() {
    ++_derivedCacheBuildGeneration;
    final subscription = _activeSubscription;
    if (subscription == null) {
      _derivedCacheBuildTimer?.cancel();
      _derivedCacheBuildTimer = null;
      _proxyCacheBuildCoordinator.cancelPending();
      _activeProfileCache = null;
      _displayProxyCache = null;
      _activeProxiesCache = const [];
      _activeGroupChildrenByTagCache = const <String, List<AppProxySummary>>{};
      _activeTopLevelProxiesCount = 0;
      _fullProxyListCacheReady = false;
      _fullProxyListCacheRequested = false;
      _publishProxyRuntimeVisualStates();
      _publishTrafficDashboardSnapshot();
      unawaited(_syncQuickSettingsTileLabel());
      return;
    }
    if (!_fullProxyListCacheRequested) {
      _refreshHomeProxyCache();
      return;
    }
    _derivedCacheBuildTimer?.cancel();
    _derivedCacheBuildTimer = Timer(
      _derivedCacheBuildDebounce,
      _runDerivedCacheBuild,
    );
  }

  void _runDerivedCacheBuild() {
    _derivedCacheBuildTimer?.cancel();
    _derivedCacheBuildTimer = null;
    final buildScope = _fullProxyListCacheRequested
        ? ProxyCacheBuildScope.full
        : ProxyCacheBuildScope.home;
    if (!_proxyCacheBuildCoordinator.beginOrQueue(buildScope)) {
      return;
    }
    final subscription = _activeSubscription;
    if (subscription == null) {
      _proxyCacheBuildCoordinator.complete();
      _activeProfileCache = null;
      _displayProxyCache = null;
      _activeProxiesCache = const [];
      _activeGroupChildrenByTagCache = const <String, List<AppProxySummary>>{};
      _activeTopLevelProxiesCount = 0;
      _fullProxyListCacheReady = false;
      _fullProxyListCacheRequested = false;
      _publishProxyRuntimeVisualStates();
      _publishTrafficDashboardSnapshot();
      unawaited(_syncQuickSettingsTileLabel());
      return;
    }

    final generation = _derivedCacheBuildGeneration;
    final buildFullProxyList = buildScope == ProxyCacheBuildScope.full;
    final input = _currentProxyCacheBuildInput(subscription);
    unawaited(() async {
      ProxyCacheBuildScope? pendingScope;
      try {
        final result = buildFullProxyList
            ? await buildProxyCacheInBackground(input)
            : await buildHomeProxyCacheInBackground(input);
        if (mounted && generation == _derivedCacheBuildGeneration) {
          setState(() {
            _activeProfileCache = result.activeProfile;
            _displayProxyCache = result.displayProxy;
            _activeProxiesCache = result.activeProxies;
            _activeGroupChildrenByTagCache = result.groupChildrenByTag;
            _activeTopLevelProxiesCount = result.totalTopLevelProxyCount;
            _fullProxyListCacheReady = result.includesFullProxyList;
            _fullProxyListCacheRequested = result.includesFullProxyList;
          });
          _publishProxyRuntimeVisualStates();
          _publishTrafficDashboardSnapshot();
          _preloadProxyFlags();
          unawaited(_syncQuickSettingsTileLabel());
          if (buildFullProxyList && !_proxyPanelOpen) {
            _scheduleProxyListCacheRelease();
          }
        }
      } catch (error, stackTrace) {
        AppLogStore.warning(
          'proxy cache',
          'build failed scope=${buildFullProxyList ? 'full' : 'home'} '
              'generation=$generation error=$error',
        );
        AppLogStore.debug('proxy cache', stackTrace.toString());
        if (mounted &&
            buildFullProxyList &&
            generation == _derivedCacheBuildGeneration) {
          _fullProxyListCacheRequested = false;
        }
      } finally {
        pendingScope = _proxyCacheBuildCoordinator.complete();
      }
      if (!mounted) {
        return;
      }
      if (pendingScope != null) {
        _derivedCacheBuildTimer?.cancel();
        _derivedCacheBuildTimer = Timer(
          _derivedCacheBuildDebounce,
          _runDerivedCacheBuild,
        );
      }
    }());
  }

  void _refreshHomeProxyCache() {
    if (_activeSubscription == null) {
      return;
    }
    _runDerivedCacheBuild();
  }

  void _ensureFullProxyListCache() {
    _cancelScheduledProxyListCacheRelease();
    if (_activeSubscription == null ||
        _fullProxyListCacheReady ||
        _fullProxyListCacheRequested) {
      return;
    }
    setState(() {
      _fullProxyListCacheRequested = true;
      _rebuildDerivedCaches();
    });
  }

  void _cancelScheduledProxyListCacheRelease() {
    _proxyListCacheReleaseTimer?.cancel();
    _proxyListCacheReleaseTimer = null;
  }

  void _scheduleProxyListCacheRelease() {
    _cancelScheduledProxyListCacheRelease();
    if (!_fullProxyListCacheReady || !_isLargeProxyListCache) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _proxyPanelOpen) {
        return;
      }
      _proxyRuntimeVisualStates.pruneUnobserved(
        additionalPinnedTags: [?_displayProxyCache?.tag],
      );
    });
    final releaseDelay =
        _fullProxyListCachedRowCount >= _veryLargeProxyListCacheReleaseThreshold
        ? _veryLargeProxyListCacheReleaseDelay
        : _largeProxyListCacheReleaseDelay;
    _proxyListCacheReleaseTimer = Timer(releaseDelay, () {
      _proxyListCacheReleaseTimer = null;
      if (!mounted || _proxyPanelOpen || _proxyPanelInteractionActive) {
        return;
      }
      _releaseFullProxyListCache(reason: 'panel_closed');
    });
  }

  bool get _isLargeProxyListCache {
    return _fullProxyListCachedRowCount >= _largeProxyListCacheReleaseThreshold;
  }

  int get _fullProxyListCachedRowCount {
    var childRows = 0;
    for (final children in _activeGroupChildrenByTagCache.values) {
      childRows += children.length;
    }
    return max(
      _activeTopLevelProxiesCount,
      max(_activeProxiesCache.length, childRows),
    );
  }

  bool _releaseFullProxyListCache({required String reason}) {
    if (!_isLargeProxyListCache ||
        (!_fullProxyListCacheReady && !_fullProxyListCacheRequested)) {
      return false;
    }
    _cancelScheduledProxyListCacheRelease();
    ++_derivedCacheBuildGeneration;
    _derivedCacheBuildTimer?.cancel();
    _derivedCacheBuildTimer = null;
    _proxyCacheBuildCoordinator.cancelPending();
    final proxyRows = _activeProxiesCache.length;
    final groupRows = _activeGroupChildrenByTagCache.values.fold<int>(
      0,
      (total, children) => total + children.length,
    );
    setState(() {
      _activeProxiesCache = const <AppProxySummary>[];
      _activeGroupChildrenByTagCache = const <String, List<AppProxySummary>>{};
      _fullProxyListCacheReady = false;
      _fullProxyListCacheRequested = false;
    });
    _publishProxyRuntimeVisualStates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _proxyRuntimeVisualStates.pruneUnobserved(
        additionalPinnedTags: [?_displayProxyCache?.tag],
      );
    });
    AppLogStore.info(
      'memory cleanup',
      'reason=$reason releasedProxyRows=$proxyRows '
          'releasedGroupRows=$groupRows',
    );
    return true;
  }

  ProxyCacheBuildInput _currentProxyCacheBuildInput(
    Subscription? subscription,
  ) {
    return ProxyCacheBuildInput(
      subscription: subscription == null
          ? null
          : compactSubscriptionForProxyCache(subscription),
      selectedProxyTag: _selectedProxyTag,
      lowestLatency: _lowestLatency,
      runtimeLowestOutboundTag: _runtimeLowestOutboundTag,
      runtimeLowestSelections: Map<String, String>.from(
        _runtimeLowestSelections,
      ),
      urlTestInFlight: _urlTestInFlight,
      runtimeLatencies: Map<String, int>.from(_runtimeLatencies),
      unavailableLatencyTags: Set<String>.from(_unavailableLatencyTags),
      latencyErrors: Map<String, String>.from(_latencyErrors),
      runtimeGroupSelections: Map<String, String>.from(_runtimeGroupSelections),
      markAllServersRussia: subscription?.markAllServersRussia ?? false,
    );
  }

  AppProxySummary? get _displayProxy {
    return _displayProxyCache;
  }

  List<AppProxySummary> get _activeProxies {
    return _activeProxiesCache;
  }

  Map<String, List<AppProxySummary>> get _activeGroupChildrenByTag {
    return _activeGroupChildrenByTagCache;
  }

  ProxyRuntimeVisualState _runtimeVisualStateFor(AppProxySummary proxy) {
    final selecting =
        _connected &&
        _proxySelection.pendingRuntimeSelectTag != null &&
        _proxySelection.pendingRuntimeSelectTag == proxy.tag;
    return ProxyRuntimeVisualState(
      latency: proxy.latency,
      latencyFresh: proxy.latencyFresh,
      latencyChecking: proxy.latencyChecking,
      latencyUnavailable: proxy.latencyUnavailable,
      latencyError: proxy.latencyError,
      networkUnavailable:
          _connected &&
          _runtimeOperations.networkStateKnown &&
          !_runtimeOperations.networkUsable,
      highlighted: proxy.highlighted,
      selecting: selecting,
    );
  }

  void _publishProxyRuntimeVisualStates() {
    _refreshProxySummariesByTagCache();
    final displayProxy = _displayProxyCache;
    _proxyRuntimeVisualStates.replaceResolver(
      _runtimeVisualStateForTag,
      pinnedTags: [if (displayProxy != null) displayProxy.tag],
    );
  }

  ProxyRuntimeVisualState? _runtimeVisualStateForTag(String tag) {
    final proxy =
        _proxySummariesByTagCache[tag] ?? _displayProxyForSelectedTag(tag);
    if (proxy == null) {
      return null;
    }
    return _runtimeVisualStateFor(
      _withRuntimeProxyState(proxy, _proxySummariesByTagCache),
    );
  }

  void _refreshProxySummariesByTagCache() {
    final summaries = <String, AppProxySummary>{
      for (final proxy in _activeProxiesCache) proxy.tag: proxy,
      for (final children in _activeGroupChildrenByTagCache.values)
        for (final proxy in children) proxy.tag: proxy,
    };
    final displayProxy = _displayProxyCache;
    if (displayProxy != null) {
      summaries[displayProxy.tag] = displayProxy;
    }
    _proxySummariesByTagCache = summaries;
  }

  void _publishProxyRuntimeVisualStatesForTags(
    Iterable<String> tags, {
    bool notifyRevision = false,
  }) {
    _proxyRuntimeVisualStates.refreshTags(tags, notifyRevision: notifyRevision);
  }

  void _publishProxyRuntimeVisualStatesForUrlTestTags(Iterable<String> tags) {
    final directTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    if (directTags.isEmpty) {
      return;
    }
    if (!_fullProxyListCacheReady) {
      final displayProxy = _displayProxyCache;
      if (displayProxy == null) {
        return;
      }
      final selectedChildTag = displayProxy.selectedChildTag;
      final affectsDisplay =
          directTags.contains(displayProxy.tag) ||
          (selectedChildTag != null && directTags.contains(selectedChildTag)) ||
          isLowestProxyTag(displayProxy.tag);
      if (affectsDisplay) {
        _publishProxyRuntimeVisualStatesForTags([
          displayProxy.tag,
        ], notifyRevision: true);
      }
      return;
    }
    final affectedTags = <String>{...directTags};
    for (final proxy in _activeProxiesCache) {
      if (isLowestProxyTag(proxy.tag)) {
        affectedTags.add(proxy.tag);
      }
    }
    for (final entry in _activeGroupChildrenByTagCache.entries) {
      if (entry.value.any((child) => directTags.contains(child.tag))) {
        affectedTags.add(entry.key);
      }
    }
    _publishProxyRuntimeVisualStatesForTags(affectedTags, notifyRevision: true);
  }

  Future<bool> _networkInterfaceUsable({String reason = 'dart_check'}) async {
    try {
      final state = await _singboxRuntime.getNetworkInterfaceState();
      final wasUsable = _runtimeOperations.networkUsable;
      _networkInterfaceGeneration = state.generation;
      _runtimeOperations.updateNetwork(
        generation: state.generation,
        usable: state.usable,
      );
      if (mounted) {
        ref
            .read(vpnRuntimeStateProvider.notifier)
            .updateNetwork(generation: state.generation, usable: state.usable);
      }
      if (wasUsable != state.usable) {
        _applyRuntimeStateToDerivedCaches();
      }
      return state.usable;
    } catch (error) {
      AppLogStore.warning(
        'network',
        'failed to query network interface reason=$reason error=$error',
      );
      return false;
    }
  }

  Future<void> _refreshRuntimeDiagnosticsNetworkState() async {
    final wasReady = _runtimeOperations.diagnosticsReady;
    final usable = await _networkInterfaceUsable(reason: 'runtime_readiness');
    if (!mounted || !usable || _runtimeTransitionInProgress || !_connected) {
      return;
    }
    if (!wasReady && _runtimeOperations.diagnosticsReady) {
      _onRuntimeDiagnosticsReady();
    }
  }

  void _handleRuntimeLogIssue(String reason, String message) {
    if (!mounted ||
        !_connected ||
        !_foregroundLifecycleActive ||
        _runtimeTransitionInProgress) {
      return;
    }
    final now = DateTime.now();
    final issue = _networkRecovery.registerInterfaceIssue(now);
    if (!issue.shouldScheduleRecovery) {
      return;
    }
    final shortMessage = message.length > 180
        ? message.substring(0, 180)
        : message;
    AppLogStore.warning(
      'network',
      'runtime_interface_issue_detected reason=$reason count=${issue.issueCount} '
          'selected=$_selectedProxyTag message=$shortMessage',
    );
    _scheduleNetworkRecovery(
      reason: reason,
      networkGeneration: _networkInterfaceGeneration,
      forceRestartOnDecision: true,
    );
  }

  void _scheduleNetworkRecovery({
    required String reason,
    required int networkGeneration,
    bool forceRestartOnDecision = false,
  }) {
    if (!mounted ||
        !_connected ||
        !_foregroundLifecycleActive ||
        _runtimeTransitionInProgress) {
      return;
    }
    _networkRecovery.scheduleDecision(
      forceRestartOnDecision: forceRestartOnDecision,
      onReady: (generation) {
        unawaited(
          _decideNetworkRecovery(
            reason: reason,
            generation: generation,
            networkGeneration: networkGeneration,
          ),
        );
      },
    );
    if (!forceRestartOnDecision) {
      AppLogStore.debug(
        'network',
        'network change observed without forced recovery reason=$reason '
            'networkGeneration=$networkGeneration',
      );
      return;
    }
  }

  Future<void> _decideNetworkRecovery({
    required String reason,
    required int generation,
    required int networkGeneration,
  }) async {
    if (!mounted ||
        !_networkRecovery.isCurrentDecision(generation) ||
        !_connected ||
        !_foregroundLifecycleActive ||
        _runtimeTransitionInProgress) {
      return;
    }
    if (!await _networkInterfaceUsable(reason: 'network_recovery_decision')) {
      AppLogStore.warning(
        'network',
        'recovery skipped reason=$reason networkGeneration=$networkGeneration '
            'selected=$_selectedProxyTag error=no_interface',
      );
      return;
    }
    if (!_networkRecovery.canRestart(DateTime.now())) {
      AppLogStore.warning(
        'network',
        'recovery restart suppressed reason=$reason '
            'networkGeneration=$networkGeneration selected=$_selectedProxyTag',
      );
      return;
    }
    _networkRecovery.recordRestart(DateTime.now());
    _groupUrlTestScheduler.cancel();
    _latencyCoordinator.cancel();
    AppLogStore.warning(
      'network',
      'recovery_restart reason=$reason '
          'networkGeneration=$networkGeneration selected=$_selectedProxyTag '
          'source=runtime_interface_errors',
    );
    await _configCoordinator.emitCurrentConfigLogAsync(
      'network recovery restart ($reason)',
      restartRuntime: true,
    );
  }

  void _preloadProxyFlags() {
    final codes = <String>{};
    var inspectedRows = 0;
    void addCode(String countryCode) {
      if (inspectedRows >= _maximumPreloadedProxyFlags) {
        return;
      }
      inspectedRows++;
      final code = CountryFlagBadge.circleFlagCodeFor(countryCode);
      if (code != null) {
        codes.add(code);
      }
    }

    // Favour the active card and the first visible proxy rows. The rest are
    // loaded by their own lazy widgets when the user scrolls, rather than
    // keeping every distinct flag in a very large subscription decoded.
    if (_displayProxyCache case final displayProxy?) {
      addCode(displayProxy.countryCode);
    }
    for (final proxy in _activeProxiesCache) {
      addCode(proxy.countryCode);
      if (inspectedRows >= _maximumPreloadedProxyFlags) {
        break;
      }
    }
    if (inspectedRows < _maximumPreloadedProxyFlags) {
      preloadChildren:
      for (final children in _activeGroupChildrenByTagCache.values) {
        for (final proxy in children) {
          addCode(proxy.countryCode);
          if (inspectedRows >= _maximumPreloadedProxyFlags) {
            break preloadChildren;
          }
        }
      }
    }
    if (codes.isEmpty || setEquals(codes, _preloadedProxyFlagCodes)) {
      return;
    }
    _preloadedProxyFlagCodes = codes;
    unawaited(CountryFlagBadge.preload(codes));
  }

  Outbound? _outboundForProxyTag(String tag) {
    final subscription = _activeSubscription;
    if (subscription == null) {
      return null;
    }
    for (final outbound in subscription.outbounds) {
      if (outbound.tag == tag && !outbound.info.deleted) {
        return outbound;
      }
    }
    return null;
  }

  Future<List<AppProfileSummary>> _loadProxyChainTargetSources() async {
    final activeId = _activeProfileId;
    final sources = _subscriptions
        .map(
          (subscription) => AppProfileSummary(
            id: subscription.id,
            name: subscription.name.trim().isEmpty
                ? 'Unnamed'
                : subscription.name.trim(),
            consumed: subscription.info?.consumed.toDouble() ?? 0,
            total: subscription.info?.total?.toDouble() ?? 0,
            remainingDays: subscription.info?.remainingDays,
            outboundsCount: subscription.outbounds.isEmpty
                ? max(0, subscription.cachedVisibleProxyCount)
                : subscription.outbounds
                      .where((outbound) => !outbound.info.deleted)
                      .where((outbound) => !_isGroupOnlyOutbound(outbound))
                      .length,
            sourceLabel: '',
          ),
        )
        .toList(growable: false);
    sources.sort((a, b) {
      if (a.id == activeId) return -1;
      if (b.id == activeId) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sources;
  }

  Future<List<AppProxySummary>> _loadProxyChainTargetsForSource(
    String subscriptionId,
  ) async {
    final normalizedId = subscriptionId.trim();
    if (normalizedId.isEmpty) {
      return const [];
    }
    final cached = _proxyChainTargetSourceCache.remove(normalizedId);
    if (cached != null) {
      _proxyChainTargetSourceCache[normalizedId] = cached;
      return cached;
    }
    Subscription? subscription;
    for (final metadata in _subscriptions) {
      if (metadata.id != normalizedId) {
        continue;
      }
      subscription = metadata.outbounds.isNotEmpty
          ? metadata
          : await SubscriptionStore.withPayloadInBackground(metadata);
      break;
    }
    if (subscription == null) {
      return const [];
    }
    final targets = subscription.outbounds
        .where((outbound) => !outbound.info.deleted)
        .where((outbound) => !_isGroupOnlyOutbound(outbound))
        .map(
          (outbound) => _proxyChainTargetSummary(
            subscription: subscription!,
            outbound: outbound,
          ),
        )
        .toList(growable: false);
    _cacheProxyChainTargetSource(normalizedId, targets);
    return targets;
  }

  void _cacheProxyChainTargetSource(
    String subscriptionId,
    List<AppProxySummary> targets,
  ) {
    _proxyChainTargetSourceCache.remove(subscriptionId);
    _proxyChainTargetSourceCache[subscriptionId] = targets;
    while (_proxyChainTargetSourceCache.length >
        _proxyChainTargetSourceCacheMaximumEntries) {
      _proxyChainTargetSourceCache.remove(
        _proxyChainTargetSourceCache.keys.first,
      );
    }
  }

  AppProxySummary _proxyChainTargetSummary({
    required Subscription subscription,
    required Outbound outbound,
  }) {
    final protocolLabel = _protocolLabel(outbound.config, outbound.type);
    final endpointLabel = _endpointLabel(outbound);
    final outboundName = outbound.name.trim().isEmpty
        ? outbound.tag
        : outbound.name.trim();
    final subscriptionName = subscription.name.trim();
    return AppProxySummary(
      tag: _proxyChainTargetRef(subscription.id, outbound.tag),
      displayName: subscriptionName.isEmpty
          ? outboundName
          : '$subscriptionName · $outboundName',
      countryCode: _normalizeCountryCode(outbound.info.country),
      type: outbound.type,
      server: outbound.server,
      port: outbound.port,
      detailText: '$protocolLabel · $endpointLabel',
      ip: outbound.info.externalIp?.trim() ?? '',
      latency: outbound.info.latestPing,
      latencyFresh: false,
      latencyChecking: false,
      latencyUnavailable: false,
      latencyError: null,
      protocolLabel: protocolLabel,
      endpointLabel: endpointLabel,
    );
  }

  String _proxyChainTargetRef(String subscriptionId, String outboundTag) =>
      '$subscriptionId\n$outboundTag';

  Future<({Subscription subscription, Outbound outbound})?>
  _resolveProxyChainTarget(String targetRef) async {
    final normalized = targetRef.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final parts = normalized.split('\n');
    if (parts.length >= 2) {
      final subscriptionId = parts.first.trim();
      final outboundTag = parts.sublist(1).join('\n').trim();
      for (final metadata in _subscriptions) {
        if (metadata.id != subscriptionId) {
          continue;
        }
        final subscription = metadata.outbounds.isNotEmpty
            ? metadata
            : await SubscriptionStore.getInBackground(metadata.id);
        if (subscription == null) {
          return null;
        }
        for (final outbound in subscription.outbounds) {
          if (outbound.tag == outboundTag && !outbound.info.deleted) {
            return (subscription: subscription, outbound: outbound);
          }
        }
      }
      return null;
    }
    _ensureActiveLookupCaches();
    final outbound = _activeOutboundByTagLookup[normalized];
    final subscription = _activeSubscription;
    if (subscription == null || outbound == null) {
      return null;
    }
    return (subscription: subscription, outbound: outbound);
  }

  SubscriptionProxyChain? _proxyChainForTag(String tag) {
    final subscription = _activeSubscription;
    if (subscription == null) {
      return null;
    }
    final normalizedTag = tag.trim();
    for (final chain in subscription.proxyChains) {
      if (chain.tag == normalizedTag) {
        return chain;
      }
    }
    return null;
  }

  bool _isProxyChainTag(String tag) => _proxyChainForTag(tag) != null;

  void _applyProxyCacheBuildResult(ProxyCacheBuildResult result) {
    ++_derivedCacheBuildGeneration;
    _derivedCacheBuildTimer?.cancel();
    _derivedCacheBuildTimer = null;
    _proxyCacheBuildCoordinator.cancelPending();
    _activeProfileCache = result.activeProfile;
    _displayProxyCache = result.displayProxy;
    _activeProxiesCache = result.activeProxies;
    _activeGroupChildrenByTagCache = result.groupChildrenByTag;
    _activeTopLevelProxiesCount = result.totalTopLevelProxyCount;
    _fullProxyListCacheReady = result.includesFullProxyList;
    _fullProxyListCacheRequested = result.includesFullProxyList;
    _publishProxyRuntimeVisualStates();
    _publishTrafficDashboardSnapshot();
    _preloadProxyFlags();
  }

  void _applyMetadataActiveProfile(
    List<Subscription> subscriptions,
    String activeSubscriptionId, {
    required bool clearProxyCache,
  }) {
    Subscription? activeSubscription;
    for (final subscription in subscriptions) {
      if (subscription.id == activeSubscriptionId) {
        activeSubscription = subscription;
        break;
      }
    }
    _activeProfileCache = activeSubscription == null
        ? null
        : _metadataProfileSummary(activeSubscription);
    _publishTrafficDashboardSnapshot();
    if (!clearProxyCache) {
      return;
    }
    ++_derivedCacheBuildGeneration;
    _derivedCacheBuildTimer?.cancel();
    _derivedCacheBuildTimer = null;
    _proxyCacheBuildCoordinator.cancelPending();
    _displayProxyCache = null;
    _activeProxiesCache = const [];
    _activeGroupChildrenByTagCache = const <String, List<AppProxySummary>>{};
    _activeTopLevelProxiesCount = 0;
    _fullProxyListCacheReady = false;
    _fullProxyListCacheRequested = false;
    _publishProxyRuntimeVisualStates();
    _publishTrafficDashboardSnapshot();
  }

  AppProfileSummary _metadataProfileSummary(Subscription subscription) {
    final info = subscription.info;
    return AppProfileSummary(
      id: subscription.id,
      name: subscription.name,
      consumed: info?.consumed.toDouble() ?? 0,
      total: info?.total?.toDouble() ?? 0,
      remainingDays: info?.remainingDays,
      outboundsCount: subscription.outbounds
          .where((outbound) => !outbound.info.deleted)
          .where((outbound) => outbound.config['_group_only'] != true)
          .length,
      sourceLabel: '',
    );
  }

  void _applyRuntimeStateToDerivedCaches() {
    if (_activeProxiesCache.isEmpty && _displayProxyCache == null) {
      return;
    }
    final previousSummariesByTag = <String, AppProxySummary>{
      for (final proxy in _activeProxiesCache) proxy.tag: proxy,
      for (final children in _activeGroupChildrenByTagCache.values)
        for (final proxy in children) proxy.tag: proxy,
    };
    final previousDisplayProxy = _displayProxyCache;
    if (previousDisplayProxy != null) {
      previousSummariesByTag[previousDisplayProxy.tag] = previousDisplayProxy;
    }
    _activeProxiesCache = _activeProxiesCache
        .map((proxy) => _withRuntimeProxyState(proxy, previousSummariesByTag))
        .toList(growable: false);
    _activeGroupChildrenByTagCache = {
      for (final entry in _activeGroupChildrenByTagCache.entries)
        entry.key: entry.value
            .map(
              (proxy) => _withRuntimeProxyState(proxy, previousSummariesByTag),
            )
            .toList(growable: false),
    };
    final summariesByTag = <String, AppProxySummary>{
      for (final proxy in _activeProxiesCache) proxy.tag: proxy,
      for (final children in _activeGroupChildrenByTagCache.values)
        for (final proxy in children) proxy.tag: proxy,
    };
    final currentDisplay = _displayProxyCache;
    if (currentDisplay != null) {
      summariesByTag[currentDisplay.tag] = currentDisplay;
    }
    _displayProxyCache = currentDisplay == null
        ? null
        : _withRuntimeProxyState(currentDisplay, summariesByTag);
    _publishProxyRuntimeVisualStates();
    _publishTrafficDashboardSnapshot();
    _scheduleVpnNotificationSync();
  }

  AppProxySummary? _displayProxyForSelectedTag(String tag) {
    final normalizedTag = tag.trim();
    if (normalizedTag.isEmpty) {
      return null;
    }
    final currentDisplay = _displayProxyCache;
    if (currentDisplay != null && currentDisplay.tag == normalizedTag) {
      return currentDisplay;
    }
    for (final proxy in _activeProxiesCache) {
      if (proxy.tag == normalizedTag) {
        return proxy;
      }
    }

    _ensureActiveLookupCaches();
    if (isLowestProxyTag(normalizedTag)) {
      if (_activeVisibleOutboundsLookup.isEmpty) {
        return null;
      }
      final selectedOutbound = _lowestSelectedOutbound(
        normalizedTag,
        _activeVisibleOutboundsLookup,
      );
      if (selectedOutbound == null) {
        final allUnavailable = _activeVisibleOutboundsLookup.every(
          (outbound) => _unavailableLatencyTags.contains(outbound.tag),
        );
        return AppProxySummary(
          tag: lowestProxyTag,
          displayName: lowestProxyBaseLabel(lowestProxyTag),
          countryCode: '',
          type: 'urltest',
          server: '',
          port: 0,
          detailText: 'URLTest · auto',
          ip: '',
          latency: null,
          latencyFresh: false,
          latencyChecking: _urlTestInFlight,
          latencyUnavailable: allUnavailable,
          latencyError: null,
          protocolLabel: 'URLTest · auto',
          endpointLabel: '',
          highlighted: true,
        );
      }
      final selectedSummary = _displaySummaryForOutbound(selectedOutbound);
      return selectedSummary.copyWith(
        tag: normalizedTag,
        displayName: lowestProxyDisplayName(
          normalizedTag,
          selectedSummary.displayName,
        ),
        detailText: 'URLTest · ${selectedSummary.displayName}',
        protocolLabel: 'URLTest · ${selectedSummary.protocolLabel}',
        selectedChildTag: selectedSummary.tag,
        selectedChildName: selectedSummary.displayName,
        highlighted: true,
      );
    }

    final group = _activeGroupByTagLookup[normalizedTag];
    if (group != null) {
      return _displaySummaryForGroup(group);
    }
    final chain = _proxyChainForTag(normalizedTag);
    if (chain != null) {
      return _displaySummaryForProxyChain(chain);
    }
    final outbound = _activeOutboundByTagLookup[normalizedTag];
    if (outbound != null) {
      return _displaySummaryForOutbound(outbound);
    }
    return null;
  }

  AppProxySummary? _displaySummaryForProxyChain(SubscriptionProxyChain chain) {
    final tag = chain.tag.trim();
    final target = _targetOutboundForProxyChain(chain);
    if (tag.isEmpty || target == null) {
      return null;
    }
    final targetSummary = _displaySummaryForOutbound(target);
    final detourName = _proxyDisplayNameForTag(chain.detourTag);
    final latencyInvalidated = _proxyRuntime.isLatencyInvalidated(tag);
    final runtimeLatency = latencyInvalidated ? null : _runtimeLatencies[tag];
    final latencyUnavailable =
        !latencyInvalidated && _unavailableLatencyTags.contains(tag);
    final latencyError = latencyInvalidated ? null : _latencyErrors[tag];
    return targetSummary.copyWith(
      tag: tag,
      displayName: chain.name.trim().isEmpty
          ? '$detourName -> ${targetSummary.displayName}'
          : chain.name.trim(),
      detailText: 'Chain · $detourName -> ${targetSummary.displayName}',
      protocolLabel: 'Chain · ${targetSummary.protocolLabel}',
      countryCode: _normalizeCountryCode(target.info.country).isNotEmpty
          ? _normalizeCountryCode(target.info.country)
          : _normalizeCountryCode(chain.targetCountry),
      latency: latencyInvalidated
          ? null
          : runtimeLatency ?? targetSummary.latency,
      clearLatency:
          latencyInvalidated ||
          (runtimeLatency == null &&
              targetSummary.latency == null &&
              latencyUnavailable),
      latencyFresh: runtimeLatency != null || targetSummary.latencyFresh,
      latencyChecking: _latencyCoordinator.isChecking(tag),
      latencyUnavailable: latencyUnavailable,
      latencyError: latencyError,
      clearLatencyError: latencyError == null,
      highlighted: _selectedProxyTag == tag,
    );
  }

  AppProxySummary _displaySummaryForOutbound(Outbound outbound) {
    final protocolLabel = _protocolLabel(outbound.config, outbound.type);
    final endpointLabel = _endpointLabel(outbound);
    final latencyInvalidated = _proxyRuntime.isLatencyInvalidated(outbound.tag);
    final runtimeLatency = latencyInvalidated
        ? null
        : _runtimeLatencies[outbound.tag];
    final latencyUnavailable =
        !latencyInvalidated && _unavailableLatencyTags.contains(outbound.tag);
    return AppProxySummary(
      tag: outbound.tag,
      displayName: outbound.name.trim().isEmpty ? outbound.tag : outbound.name,
      countryCode: _effectiveOutboundCountry(outbound),
      type: outbound.type,
      server: outbound.server,
      port: outbound.port,
      detailText: '$protocolLabel · $endpointLabel',
      ip: outbound.info.externalIp?.trim() ?? '',
      latency: latencyInvalidated
          ? null
          : runtimeLatency ?? outbound.info.latestPing,
      latencyFresh: runtimeLatency != null,
      latencyChecking: _latencyCoordinator.isChecking(outbound.tag),
      latencyUnavailable: latencyUnavailable,
      latencyError: latencyInvalidated ? null : _latencyErrors[outbound.tag],
      protocolLabel: protocolLabel,
      endpointLabel: endpointLabel,
      highlighted: _selectedProxyTag == outbound.tag,
    );
  }

  AppProxySummary _displaySummaryForGroup(SubscriptionGroup group) {
    final visibleChildTags = group.outboundTags
        .where((tag) => _activeOutboundByTagLookup.containsKey(tag))
        .toList(growable: false);
    final selectedChild = _selectedGroupOutbound(group);
    final selectedSummary = selectedChild == null
        ? null
        : _displaySummaryForOutbound(selectedChild);
    final selectedCountry = selectedSummary?.countryCode.trim() ?? '';
    final groupCountry = _markAllServersRussia
        ? 'RU'
        : _normalizeCountryCode(group.country);
    final selectedChildName =
        selectedSummary?.displayName ?? selectedChild?.name.trim();
    final hasSelectedChild =
        selectedChildName != null && selectedChildName.isNotEmpty;
    final childCount = visibleChildTags.isEmpty
        ? group.outboundTags.length
        : visibleChildTags.length;
    return AppProxySummary(
      tag: group.tag,
      displayName: group.name.trim().isEmpty ? group.tag : group.name,
      countryCode: selectedCountry.isNotEmpty ? selectedCountry : groupCountry,
      type: 'urltest',
      server: '',
      port: 0,
      detailText: hasSelectedChild
          ? 'URLTest · $selectedChildName'
          : 'URLTest · $childCount outbounds',
      ip: selectedSummary?.ip ?? '',
      latency: selectedSummary?.latency,
      latencyFresh: selectedSummary?.latencyFresh ?? false,
      latencyChecking:
          selectedSummary?.latencyChecking ??
          (_urlTestInFlight && selectedChild == null),
      latencyUnavailable: selectedSummary?.latencyUnavailable ?? false,
      latencyError: selectedSummary?.latencyError,
      protocolLabel: hasSelectedChild
          ? 'URLTest · $selectedChildName'
          : 'URLTest · $childCount outbounds',
      endpointLabel: selectedSummary?.endpointLabel ?? '',
      isGroup: true,
      childCount: childCount,
      selectedChildTag: selectedChild?.tag,
      selectedChildName: selectedChildName,
      highlighted: true,
    );
  }

  AppProxySummary _withRuntimeProxyState(
    AppProxySummary proxy,
    Map<String, AppProxySummary> summariesByTag,
  ) {
    if (isLowestProxyTag(proxy.tag)) {
      final selectedTag = _runtimeLowestOutboundTagFor(proxy.tag);
      final selectedGroupTag =
          selectedTag != null &&
              _activeGroupByTagLookup.containsKey(selectedTag)
          ? selectedTag
          : null;
      final selectedLeafTag = selectedGroupTag == null
          ? selectedTag
          : _runtimeGroupSelections[selectedGroupTag];
      final selected =
          selectedLeafTag == null ||
              _unavailableLatencyTags.contains(selectedLeafTag) ||
              _latencyErrors.containsKey(selectedLeafTag)
          ? null
          : summariesByTag[selectedLeafTag];
      if (selected == null) {
        return proxy.copyWith(
          displayName: lowestProxyBaseLabel(proxy.tag),
          countryCode: '',
          type: 'urltest',
          detailText: 'URLTest · auto',
          ip: '',
          ipChecking: false,
          clearLatency: true,
          latencyFresh: false,
          latencyChecking: _urlTestInFlight,
          latencyUnavailable:
              !_urlTestInFlight &&
              _activeVisibleOutboundsLookup.isNotEmpty &&
              _activeVisibleOutboundsLookup.every(
                (outbound) => _unavailableLatencyTags.contains(outbound.tag),
              ),
          clearLatencyError: true,
          protocolLabel: 'URLTest · auto',
          endpointLabel: '',
          clearSelectedChildTag: true,
          clearSelectedChildName: true,
          highlighted: proxy.tag == _selectedProxyTag,
        );
      }
      final selectedWithRuntime = _withDirectRuntimeProxyState(selected);
      return proxy.copyWith(
        displayName: lowestProxyDisplayName(
          proxy.tag,
          selectedWithRuntime.displayName,
        ),
        countryCode: selectedWithRuntime.countryCode,
        type: selectedWithRuntime.type,
        detailText: 'URLTest · ${selectedWithRuntime.displayName}',
        ip: selectedWithRuntime.ip,
        ipChecking: selectedWithRuntime.ipChecking,
        latency: selectedWithRuntime.latency,
        clearLatency: selectedWithRuntime.latency == null,
        latencyFresh: selectedWithRuntime.latencyFresh,
        latencyChecking: selectedWithRuntime.latencyChecking,
        latencyUnavailable: selectedWithRuntime.latencyUnavailable,
        latencyError: selectedWithRuntime.latencyError,
        clearLatencyError: selectedWithRuntime.latencyError == null,
        protocolLabel: 'URLTest · ${selectedWithRuntime.protocolLabel}',
        endpointLabel: selectedWithRuntime.endpointLabel,
        selectedChildTag: selectedWithRuntime.tag,
        selectedChildName: selectedWithRuntime.displayName,
        highlighted: proxy.tag == _selectedProxyTag,
      );
    }

    if (proxy.isGroup) {
      final fullChildTags = _fullChildTagsForProxy(proxy);
      final runtimeSelected = _runtimeGroupSelections[proxy.tag];
      final selectedChildTag =
          runtimeSelected != null && fullChildTags.contains(runtimeSelected)
          ? runtimeSelected
          : proxy.selectedChildTag;
      final selectedChild = selectedChildTag == null
          ? null
          : summariesByTag[selectedChildTag];
      final selectedChildWithRuntime = selectedChild == null
          ? null
          : _withDirectRuntimeProxyState(selectedChild);
      final selectedCountry =
          selectedChildWithRuntime?.countryCode.trim() ?? '';
      final selectedChildName =
          selectedChildWithRuntime?.displayName ?? proxy.selectedChildName;
      final hasSelectedChild =
          selectedChildName != null && selectedChildName.isNotEmpty;
      final childCount = proxy.childCount > 0
          ? proxy.childCount
          : proxy.childTags.length;
      final childSelectedByUser = _tagsContain(
        fullChildTags,
        _selectedProxyTag,
      );
      final childSelectedByLowest = _tagsContain(
        fullChildTags,
        _activeRuntimeLowestOutboundTag(),
      );
      final selectedByLowest =
          isLowestProxyTag(_selectedProxyTag) &&
          _activeRuntimeLowestOutboundTag() == proxy.tag;
      final unavailable =
          selectedChildWithRuntime?.latencyUnavailable ??
          proxy.latencyUnavailable;
      return proxy.copyWith(
        countryCode: selectedCountry.isNotEmpty
            ? selectedCountry
            : proxy.countryCode,
        detailText: hasSelectedChild
            ? 'URLTest · $selectedChildName'
            : 'URLTest · $childCount outbounds',
        ip: selectedChildWithRuntime?.ip ?? proxy.ip,
        ipChecking: selectedChildWithRuntime?.ipChecking ?? false,
        latency: selectedChildWithRuntime?.latency,
        clearLatency: selectedChildWithRuntime?.latency == null,
        latencyFresh: selectedChildWithRuntime?.latencyFresh ?? false,
        latencyChecking:
            selectedChildWithRuntime?.latencyChecking ??
            (_urlTestInFlight && selectedChildTag == null),
        latencyUnavailable: unavailable,
        latencyError: selectedChildWithRuntime?.latencyError,
        clearLatencyError: selectedChildWithRuntime?.latencyError == null,
        protocolLabel: hasSelectedChild
            ? 'URLTest · $selectedChildName'
            : 'URLTest · $childCount outbounds',
        endpointLabel:
            selectedChildWithRuntime?.endpointLabel ?? proxy.endpointLabel,
        selectedChildTag: selectedChildTag,
        clearSelectedChildTag: selectedChildTag == null,
        selectedChildName: selectedChildName,
        clearSelectedChildName: selectedChildName == null,
        highlighted:
            _selectedProxyTag == proxy.tag ||
            childSelectedByUser ||
            selectedByLowest ||
            (isLowestProxyTag(_selectedProxyTag) && childSelectedByLowest),
      );
    }

    return _withDirectRuntimeProxyState(proxy);
  }

  AppProxySummary _withDirectRuntimeProxyState(AppProxySummary proxy) {
    final latencyChecking = _latencyCoordinator.isChecking(proxy.tag);
    final latencyInvalidated = _proxyRuntime.isLatencyInvalidated(proxy.tag);
    final runtimeLatency = latencyInvalidated
        ? null
        : _runtimeLatencies[proxy.tag];
    final latencyUnavailable =
        ProxyRuntimeController.effectiveLatencyUnavailable(
          urlTestUnavailable:
              !latencyInvalidated &&
              _unavailableLatencyTags.contains(proxy.tag),
          endpointFallbackReachable: false,
        );
    final latencyError = ProxyRuntimeController.effectiveLatencyError(
      urlTestError: latencyInvalidated ? null : _latencyErrors[proxy.tag],
      endpointFallbackReachable: false,
    );
    final parentGroupTag = proxy.parentGroupTag;
    final highlightedByGroupUrlTest =
        parentGroupTag != null &&
        _runtimeGroupSelections[parentGroupTag] == proxy.tag;
    final highlightedByLowest =
        isLowestProxyTag(_selectedProxyTag) &&
        _activeRuntimeLowestOutboundTag() == proxy.tag;
    final shouldClearLatency =
        runtimeLatency == null && (latencyUnavailable || latencyInvalidated);
    final activeIpMatches =
        _connected && _activeProxyIp.outboundTag == proxy.tag;
    final activeIpOverride = activeIpMatches && _activeProxyIp.hasKnownIp
        ? _activeProxyIp.ip
        : null;
    final activeIpChecking =
        activeIpMatches && _activeProxyIp.state == ActiveProxyIpState.checking;
    return proxy.copyWith(
      ip: activeIpOverride,
      ipChecking: activeIpChecking,
      latency: runtimeLatency,
      clearLatency: shouldClearLatency,
      latencyFresh: runtimeLatency != null && latencyError == null,
      latencyChecking: latencyChecking,
      latencyUnavailable: latencyUnavailable,
      latencyError: latencyError,
      clearLatencyError: latencyError == null,
      highlighted:
          highlightedByGroupUrlTest ||
          highlightedByLowest ||
          _selectedProxyTag == proxy.tag,
    );
  }

  List<String> _fullChildTagsForProxy(AppProxySummary proxy) {
    _ensureActiveLookupCaches();
    final group = _activeGroupByTagLookup[proxy.tag];
    return group?.outboundTags ?? proxy.childTags;
  }

  bool _tagsContain(List<String> tags, String? tag) {
    final normalized = tag?.trim() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    return tags.contains(normalized);
  }

  bool _proxyCacheContainsTag(String? tag) {
    final normalized = tag?.trim() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    if (_displayProxyCache?.tag == normalized) {
      return true;
    }
    if (!_fullProxyListCacheReady) {
      _ensureActiveLookupCaches();
      return _activeOutboundByTagLookup.containsKey(normalized) ||
          _activeGroupByTagLookup.containsKey(normalized) ||
          _proxyChainForTag(normalized) != null ||
          isLowestProxyTag(normalized);
    }
    for (final proxy in _activeProxiesCache) {
      if (proxy.tag == normalized) {
        return true;
      }
    }
    for (final children in _activeGroupChildrenByTagCache.values) {
      for (final proxy in children) {
        if (proxy.tag == normalized) {
          return true;
        }
      }
    }
    return false;
  }

  bool _visibleGroupProxyCacheMissingChild(String groupTag, String childTag) {
    final normalizedGroupTag = groupTag.trim();
    final normalizedChildTag = childTag.trim();
    if (normalizedGroupTag.isEmpty || normalizedChildTag.isEmpty) {
      return false;
    }
    if (!_fullProxyListCacheReady) {
      return false;
    }
    for (final proxy in _activeProxiesCache) {
      if (!proxy.isGroup || proxy.tag != normalizedGroupTag) {
        continue;
      }
      final cachedChildren = _activeGroupChildrenByTagCache[normalizedGroupTag];
      if (cachedChildren == null) {
        return !proxy.childTags.contains(normalizedChildTag);
      }
      return !cachedChildren.any((child) => child.tag == normalizedChildTag);
    }
    return false;
  }

  void _ensureActiveLookupCaches() {
    final subscription = _activeSubscription;
    if (identical(subscription, _activeLookupSubscription)) {
      return;
    }
    _activeLookupSubscription = subscription;
    if (subscription == null) {
      _activeVisibleOutboundsLookup = const [];
      _activeOutboundByTagLookup = const {};
      _activeGroupByTagLookup = const {};
      return;
    }
    final visibleOutbounds = <Outbound>[];
    final outboundByTag = <String, Outbound>{};
    for (final outbound in subscription.outbounds) {
      if (outbound.info.deleted) {
        continue;
      }
      outboundByTag[outbound.tag] = outbound;
      if (_isGroupOnlyOutbound(outbound)) {
        continue;
      }
      visibleOutbounds.add(outbound);
    }
    _activeVisibleOutboundsLookup = visibleOutbounds;
    _activeOutboundByTagLookup = outboundByTag;
    _activeGroupByTagLookup = {
      for (final group in subscription.groups) group.tag: group,
    };
  }

  bool _isGroupOnlyOutbound(Outbound outbound) {
    return outbound.config['_group_only'] == true;
  }

  bool get _resolvingLowestProxy {
    if (!_connected || !isLowestProxyTag(_selectedProxyTag)) {
      return false;
    }
    final proxy = _displayProxy;
    final waitingForPing =
        proxy != null &&
        !proxy.latencyUnavailable &&
        (proxy.latencyChecking || !proxy.latencyFresh || proxy.latency == null);
    return _urlTestInFlight ||
        waitingForPing ||
        _currentResolvedActiveOutbound() == null;
  }

  String? _countryFlagEmoji(String? countryCode) {
    final normalizedCode = countryCode?.trim().toUpperCase() ?? '';
    if (!_quickTileCountryCodePattern.hasMatch(normalizedCode)) {
      return null;
    }
    final resolvedCode = switch (normalizedCode) {
      'UK' => 'GB',
      _ => normalizedCode,
    };
    final codeUnits = resolvedCode.codeUnits
        .map((unit) => 0x1F1A5 + unit)
        .toList(growable: false);
    return String.fromCharCodes(codeUnits);
  }

  String? _buildQuickSettingsTileLabel() {
    final proxyName = _displayProxy?.displayName.trim();
    if (proxyName != null && proxyName.isNotEmpty) {
      final flag = _countryFlagEmoji(_displayProxy?.countryCode);
      final normalizedName = isLowestProxyTag(_displayProxy?.tag ?? '')
          ? 'Авто'
          : proxyName;
      return flag == null ? normalizedName : '$flag $normalizedName';
    }
    final profileName = _activeProfile?.name.trim();
    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }
    return null;
  }

  Future<void> _syncQuickSettingsTileLabel() async {
    final nextLabel = _buildQuickSettingsTileLabel();
    if (_lastQuickSettingsTileLabel == nextLabel) {
      return;
    }
    _lastQuickSettingsTileLabel = nextLabel;
    await _singboxRuntime.setQuickSettingsTileLabel(nextLabel);
  }

  String _buildVpnNotificationTitle() {
    final proxy = _displayProxy;
    final name = proxy?.displayName.trim();
    if (name != null && name.isNotEmpty) {
      final flag = _countryFlagEmoji(proxy?.countryCode);
      return flag == null ? name : '$flag $name';
    }
    final profileName = _activeProfile?.name.trim();
    return profileName == null || profileName.isEmpty ? 'Etonify' : profileName;
  }

  void _scheduleVpnNotificationSync() {
    if (!Platform.isAndroid) {
      return;
    }
    _vpnNotificationSyncTimer?.cancel();
    _vpnNotificationSyncTimer = Timer(const Duration(milliseconds: 80), () {
      _vpnNotificationSyncTimer = null;
      unawaited(_syncVpnNotificationPresentation());
    });
  }

  Future<void> _syncVpnNotificationPresentation() async {
    if (!mounted || !_ready || !Platform.isAndroid) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final proxy = _displayProxy;
    final latency = proxy != null && !proxy.latencyUnavailable
        ? proxy.latency
        : null;
    final targetTag = _connected
        ? (_currentResolvedActiveOutboundTag()?.trim() ?? '')
        : '';
    final title = _buildVpnNotificationTitle();
    final timeoutMillis = _urlTestTimeoutSeconds * 1000;
    final signature = <Object?>[
      _statusNotificationEnabled,
      _notificationTrafficDisplayMode.name,
      _notificationTrafficRefreshSeconds,
      title,
      latency,
      targetTag,
      _urlTestUrl,
      timeoutMillis,
      _connected,
      _locale?.languageCode ?? 'system',
      l10n.notificationTrafficTotalLabel,
    ].join('|');
    if (signature == _lastVpnNotificationPresentationSignature) {
      return;
    }
    _lastVpnNotificationPresentationSignature = signature;
    try {
      await _singboxRuntime.updateVpnNotificationPresentation(
        detailed: _statusNotificationEnabled,
        trafficDisplayMode: _notificationTrafficDisplayMode.name,
        trafficRefreshSeconds: _notificationTrafficRefreshSeconds,
        title: title,
        latencyMillis: latency,
        groupTag: 'select',
        targetOutboundTag: targetTag,
        priorityOutboundTag: targetTag,
        excludeOutboundTag: '',
        url: _urlTestUrl,
        timeoutMillis: timeoutMillis,
        concurrency: 1,
        deadlineMillis: timeoutMillis + 5000,
        connectedText: l10n.notificationConnected,
        checkingText: l10n.notificationPingChecking,
        unavailableText: l10n.notificationPingUnavailable,
        totalLabel: l10n.notificationTrafficTotalLabel,
        refreshLabel: l10n.notificationRefreshPingAction,
        stopLabel: l10n.notificationStopAction,
      );
    } catch (error) {
      // A notification must never affect the VPN lifecycle. The Android
      // foreground service still supplies its minimal required notification.
      AppLogStore.warning('notification', 'failed to sync VPN status: $error');
    }
  }

  Future<void> _requestNotificationPermissionIfNeeded({
    bool force = false,
  }) async {
    if (!Platform.isAndroid ||
        !_statusNotificationEnabled ||
        !_connected ||
        _notificationPermissionRequestInFlight ||
        (_notificationPermissionPromptAttempted && !force)) {
      return;
    }
    _notificationPermissionPromptAttempted = true;
    _notificationPermissionRequestInFlight = true;
    try {
      await _singboxRuntime.ensureNotificationPermission();
    } catch (error) {
      AppLogStore.warning('notification', 'permission request failed: $error');
    } finally {
      _notificationPermissionRequestInFlight = false;
    }
  }

  @override
  void initState() {
    super.initState();
    ref.read(appSettingsProvider);
    _singboxRuntime = ref.read(singboxRuntimeProvider);
    _appUpdateService = ref.read(appUpdateServiceProvider);
    _russiaRouteDataService = ref.read(russiaRouteDataServiceProvider);
    _vpnLifecycleCommands = ref.read(vpnLifecycleCommandsProvider);
    _proxyRuntimeVisualStates = ref.read(proxyRuntimeVisualStoreProvider);
    _subscriptionCoordinator = SubscriptionCoordinator(
      runtime: ref.read(subscriptionRuntimeControllerProvider),
      refreshSubscription: (id) => SubscriptionStore.refresh(
        id,
        allowInsecureTls: _allowUntrustedSubscriptionCertificates,
      ),
    );
    _bootstrapController = AppBootstrapController(
      fallbackClientVersionLabel: _fallbackClientVersionLabel,
    );
    _runtimeCommands = RuntimeCommandCoordinator(
      selectOutbound: (groupTag, outboundTag) => _singboxRuntime.selectOutbound(
        groupTag: groupTag,
        outboundTag: outboundTag,
      ),
    );
    _latencyCoordinator = LatencyCoordinator(
      runTest: (request) => _singboxRuntime.urlTest(
        groupTag: request.groupTag,
        targetOutboundTag: request.targetOutboundTag,
        priorityOutboundTag: request.priorityOutboundTag,
        excludeOutboundTag: request.excludeOutboundTag,
        url: request.url,
        timeoutMillis: request.timeoutMillis,
        concurrency: request.concurrency,
        deadlineMillis: request.deadlineMillis,
        force: request.force,
      ),
      isConnected: () => _connected,
      isForeground: () => _foregroundLifecycleActive,
      activeOutboundTag: () => _currentResolvedActiveOutboundTag() ?? '',
      testUrl: () => _urlTestUrl,
      outboundCount: () {
        _ensureActiveLookupCaches();
        return _activeVisibleOutboundsLookup.length;
      },
      canRunDiagnostics: () => _runtimeOperations.diagnosticsReady,
      operationGeneration: () => _runtimeOperations.diagnosticGeneration,
      eventBaselineTimes: () => _proxyRuntime.runtimeLatencyTimes,
      expectedTags: () => _expectedLatencyTagsForSession(''),
      onSessionChanged: (running, kind, targetTag) {
        ref
            .read(proxyLatencySessionProvider.notifier)
            .update(running: running, kind: kind, targetTag: targetTag);
        if (!mounted) return;
        setState(_applyRuntimeStateToDerivedCaches);
        unawaited(_syncQuickSettingsTileLabel());
      },
    );
    _configCoordinator = SingboxConfigCoordinator(
      readSnapshot: _currentSingboxConfigSnapshot,
      isMounted: () => mounted,
      ensureActiveSubscriptionHydrated:
          _ensureActiveSubscriptionHydratedForRuntime,
      runtimeLifecycle: _runtimeLifecycle,
      applyStartupValidationResult: _applyStartupValidationResult,
      showNoValidOutboundsWarning: _showNoValidOutboundsWarning,
      setPhase: _setConfigCoordinatorPhase,
      showRuntimeFailure: _showRuntimeConfigFailure,
      logCall: _logLibboxCall,
      trimRuntimeStartMemory: _trimRuntimeStartMemory,
      onRuntimeLifecycleTimeout: _handleRuntimeLifecycleTimeout,
      cacheStartedBuild: _cacheLastStartedBuild,
      syncRuntimeState: _syncRuntimeState,
    );
    _runtimeEvents = RuntimeEventController(
      events: _singboxRuntime.events,
      onState: _handleRuntimeStateEvent,
      onStatus: _handleTrafficStatusEvent,
      onNetwork: _handleRuntimeNetworkEvent,
      onGroups: _applyGroupUpdates,
      shouldRecordLog: _shouldRecordSingBoxLog,
      onRuntimeLogIssue: _handleRuntimeLogIssue,
    );
    _vpnLifecycleCommands.bind(
      toggle: (source) => _toggleConnection(source: source),
      stop: (reason, allowQueuedRestart) =>
          _stopRuntime(reason: reason, allowQueuedRestart: allowQueuedRestart),
    );
    WidgetsBinding.instance.addObserver(this);
    _configureImageCacheForAndroid();
    _refreshThemeCache();
    _startDeepLinkHandling();
    unawaited(_bootstrap());
  }

  Future<AppVersionInfo> _readAppVersionInfo() =>
      _bootstrapController.readAppVersionInfo();

  Future<void> _refreshAppVersionInfo() async {
    final info = await _readAppVersionInfo();
    if (!mounted) return;
    final nextVersion = info.displayVersion;
    final nextBuildNumber = info.updateBuildNumber;
    if (_clientVersionLabel == nextVersion &&
        _clientVersionCode == nextBuildNumber &&
        _clientPackageName == info.packageName) {
      return;
    }
    setState(() {
      _clientVersionLabel = nextVersion;
      _clientVersionCode = nextBuildNumber;
      _clientPackageName = info.packageName;
    });
  }

  @override
  void dispose() {
    _vpnLifecycleCommands.unbind();
    WidgetsBinding.instance.removeObserver(this);
    _subscriptionAutoRefreshTimer?.cancel();
    _latencyCoordinator.dispose();
    _runtimeRecovery.dispose();
    _locationLookupTimer?.cancel();
    _resumeForegroundSyncTimer?.cancel();
    _groupUrlTestScheduler.dispose();
    _networkRecovery.dispose();
    _configCoordinator.dispose();
    _settingsConfigApplyTimer?.cancel();
    _runtimeLifecycle.dispose();
    _runtimeCommands.dispose();
    _activeProxyIpController.dispose();
    _proxySelection.dispose();
    _locationLookupRefreshRequested = false;
    for (final waiter in _locationLookupWaiters) {
      if (!waiter.isCompleted) {
        waiter.complete(false);
      }
    }
    _locationLookupWaiters.clear();
    _externalInfoLookups.clear();
    _derivedCacheBuildTimer?.cancel();
    _proxyListCacheReleaseTimer?.cancel();
    _trafficUiUpdateTimer?.cancel();
    _vpnNotificationSyncTimer?.cancel();
    unawaited(_runtimeEvents.dispose());
    _deepLinkImportSubscription?.cancel();
    final store = _store;
    if (_ownsStore && store != null) {
      unawaited(store.close());
    }
    _proxyRuntime.dispose();
    _trafficDashboardSnapshot.dispose();
    _trafficUiSnapshot.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_appLifecycleState == state) {
      return;
    }
    _appLifecycleState = state;
    if (_foregroundLifecycleActive) {
      _resumeForegroundWork();
    } else {
      _suspendForegroundWork();
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    _runMemoryPressureCleanup('system_memory_pressure');
  }

  void _configureImageCacheForAndroid() {
    if (!Platform.isAndroid) {
      return;
    }
    final cache = PaintingBinding.instance.imageCache;
    if (cache.maximumSizeBytes > _androidImageCacheMaximumBytes) {
      cache.maximumSizeBytes = _androidImageCacheMaximumBytes;
    }
    if (cache.maximumSize > _androidImageCacheMaximumEntries) {
      cache.maximumSize = _androidImageCacheMaximumEntries;
    }
  }

  void _runMemoryPressureCleanup(String reason) {
    final cache = PaintingBinding.instance.imageCache;
    final imageBytesBefore = cache.currentSizeBytes;
    final imageEntriesBefore = cache.currentSize;
    final proxyCacheBefore = _activeProxiesCache.length;
    final groupCacheBefore = _activeGroupChildrenByTagCache.length;
    final samplesBefore = _trafficSamples.length;
    final installedAppsBefore = _installedAppsCache.length;
    final proxyChainSourcesBefore = _proxyChainTargetSourceCache.length;

    cache.clear();
    cache.clearLiveImages();
    _configureImageCacheForAndroid();
    clearInstalledAppIconCache();
    _clearInstalledAppsCache();

    _proxyChainTargetSourceCache.clear();
    final fullProxyCacheReleased =
        !_proxyPanelOpen && _releaseFullProxyListCache(reason: reason);
    _proxyRuntimeVisualStates.pruneUnobserved(
      additionalPinnedTags: [?_displayProxyCache?.tag],
    );
    _preloadedProxyFlagCodes = const <String>{};
    var trafficDashboardChanged = false;
    if (!_connected) {
      _resetTrafficDashboardData();
      trafficDashboardChanged = true;
    } else if (_trafficSamples.length > 60) {
      _trafficSamples = List<TrafficSample>.unmodifiable(
        _trafficSamples.skip(_trafficSamples.length - 60),
      );
      trafficDashboardChanged = true;
    }
    if (trafficDashboardChanged) {
      _publishTrafficDashboardSnapshot(force: true);
    }

    AppLogStore.info(
      'memory cleanup',
      'reason=$reason imageBytesBefore=$imageBytesBefore '
          'imageEntriesBefore=$imageEntriesBefore '
          'proxyRowsBefore=$proxyCacheBefore groupCachesBefore=$groupCacheBefore '
          'proxyChainSourcesBefore=$proxyChainSourcesBefore '
          'trafficSamplesBefore=$samplesBefore '
          'installedAppsBefore=$installedAppsBefore '
          'proxyViewModelsRetained=${!fullProxyCacheReleased}',
    );
  }

  int _proxyPanelVisibleRows() {
    final total = _activeTopLevelProxiesCount;
    if (total <= 0) {
      return _activeProfileCache == null ? 0 : 1;
    }
    return total;
  }

  Future<void> _startDeepLinkHandling() async {
    _deepLinkImportSubscription = DeepLinkImportBridge.stream.listen(
      _enqueueDeepLinkImport,
    );

    final initialRequest = await DeepLinkImportBridge.getInitialRequest();
    if (!mounted || initialRequest == null) {
      return;
    }
    _enqueueDeepLinkImport(initialRequest);
  }

  void _enqueueDeepLinkImport(DeepLinkImportRequest request) {
    if (_ready && _onboardingCompleted && !_legalAccepted) {
      _showAppSnackBar(_legalImportBlockedMessage());
      return;
    }
    _pendingDeepLinkImport = request;
    if (!_ready ||
        !_onboardingCompleted ||
        !_legalAccepted ||
        _deepLinkImportInFlight) {
      return;
    }
    unawaited(_drainPendingDeepLinkImports());
  }

  Future<void> _drainPendingDeepLinkImports() async {
    if (_deepLinkImportInFlight) {
      return;
    }

    if (_pendingDeepLinkImport != null && !_legalAccepted) {
      _pendingDeepLinkImport = null;
      _showAppSnackBar(_legalImportBlockedMessage());
      return;
    }

    while (mounted && _ready && _onboardingCompleted && _legalAccepted) {
      final request = _pendingDeepLinkImport;
      if (request == null) {
        return;
      }

      final context = _navigatorKey.currentContext;
      if (context == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _ready && _onboardingCompleted && _legalAccepted) {
            unawaited(_drainPendingDeepLinkImports());
          }
        });
        return;
      }

      _pendingDeepLinkImport = null;
      _deepLinkImportInFlight = true;
      try {
        await _handleDeepLinkImport(request);
      } finally {
        _deepLinkImportInFlight = false;
      }
    }
  }

  Future<void> _handleDeepLinkImport(DeepLinkImportRequest request) async {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      _pendingDeepLinkImport = request;
      return;
    }
    final l10n = AppLocalizations.of(context);
    final copy = _deepLinkImportCopy(context);

    if (!HappCryptoLinkDecoder.isSupportedSubscriptionUrl(request.url)) {
      _showAppSnackBar(l10n.invalidUrl);
      return;
    }

    try {
      final preview = await _buildDeepLinkImportPreview(request);
      if (!context.mounted) {
        return;
      }
      final decision = await _showDeepLinkImportSheet(
        context,
        request,
        preview,
      );
      if (decision == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      final requestInfo = switch (decision) {
        _DeepLinkImportDecision.sendHwid => preview.requestInfo,
        _DeepLinkImportDecision.importWithoutHwid =>
          preview.requestInfo?.copyWith(requireHwid: false),
        _DeepLinkImportDecision.import => preview.requestInfo,
      };

      final createdResult = await _runSubscriptionOperationWithWarning(
        SubscriptionStore.addFromUrl(
          preview.resolvedUrl,
          customName: request.name,
          requestInfo: requestInfo,
          operationTimeout: _subscriptionOperationTimeout,
          allowInsecureTls: _allowUntrustedSubscriptionCertificates,
          onRouteAttempt: _handleSubscriptionRouteAttempt,
        ),
        slowMessage: l10n.subscriptionOperationSlowWarning,
        timeoutMessage: l10n.subscriptionOperationTimeout,
      );
      final created = createdResult.subscription;
      await _reloadSubscriptions();
      if (!mounted) {
        return;
      }
      _showAppSnackBar(
        createdResult.hasWarning
            ? subscriptionSavedWarningMessage(createdResult.warning, l10n)
            : copy.imported(created.name),
      );
      await _offerLikelyHwidFix(created);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppLogStore.warning(
        'subscription',
        'Deep-link subscription import failed: ${error.runtimeType}: $error',
      );
      _showAppSnackBar(_userFacingSubscriptionError(error, l10n));
    }
  }

  String _legalImportBlockedMessage() {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return 'Accept Terms and Privacy Policy before importing subscriptions.';
    }
    return AppLocalizations.of(context).legalImportBlockedMessage;
  }

  Future<_DeepLinkImportPreview> _buildDeepLinkImportPreview(
    DeepLinkImportRequest request,
  ) async {
    if (HappCryptoLinkDecoder.isSupportedLink(request.url)) {
      final prepared = await HappCryptoLinkDecoder.prepare(request.url);
      return _DeepLinkImportPreview(
        sourceUrl: request.url,
        resolvedUrl: prepared.resolvedUrl,
        requestInfo: prepared.requestInfo,
      );
    }

    final isHappDeepLink = request.isHapp;

    return _DeepLinkImportPreview(
      sourceUrl: request.url,
      resolvedUrl: request.url,
      requestInfo: isHappDeepLink
          ? HappCryptoLinkDecoder.happRequestInfo()
          : null,
    );
  }

  Future<_DeepLinkImportDecision?> _showDeepLinkImportSheet(
    BuildContext context,
    DeepLinkImportRequest request,
    _DeepLinkImportPreview preview,
  ) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<_DeepLinkImportDecision>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _DeepLinkImportSheet(
        request: request,
        preview: preview,
        copy: _deepLinkImportCopy(context),
        l10n: l10n,
      ),
    );
  }

  _DeepLinkImportCopy _deepLinkImportCopy(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _DeepLinkImportCopy(
      title: l10n.deepLinkImportTitle,
      message: l10n.deepLinkImportMessage,
      nameLabel: l10n.deepLinkImportNameLabel,
      importAction: l10n.deepLinkImportAction,
      importedTextBuilder: l10n.deepLinkImportSuccess,
    );
  }

  void _showAppSnackBar(
    String message, {
    AppNoticeTone tone = AppNoticeTone.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    AppNotice.show(
      context,
      message,
      tone: tone,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  void _handleSubscriptionRouteAttempt(
    SubscriptionFetchRoute route,
    bool isFallback,
  ) {
    if (!isFallback || route != SubscriptionFetchRoute.underlying) {
      return;
    }
    _showAppSnackBar(
      _currentLocalizations?.remoteDownloadRetryWithoutVpnHint ??
          'The VPN route did not respond. Retrying without VPN.',
    );
  }

  AppLocalizations? get _currentLocalizations {
    final context = _navigatorKey.currentContext;
    return context == null
        ? null
        : Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  String get _vpnStartFailedMessage =>
      _currentLocalizations?.vpnStartFailed ?? 'Failed to start VPN.';

  String get _vpnStartTimedOutMessage =>
      _currentLocalizations?.vpnStartTimedOut ??
      'VPN did not start within 15 seconds. Startup was stopped.';

  String get _vpnStopFailedMessage =>
      _currentLocalizations?.vpnStopFailed ?? 'Failed to stop VPN.';

  Future<void> _checkForClientUpdatesIfDue() async {
    await _refreshAppVersionInfo();
    await _cleanupInstalledUpdateArtifactsIfNeeded(showSnackBar: true);
    final result = await _appUpdateService.checkForUpdates(
      currentVersion: _clientVersionLabel,
      currentBuildNumber: _clientVersionCode,
      channel: _updateChannel,
    );
    if (!mounted ||
        (result.status != AppUpdateStatus.updateAvailable &&
            result.status != AppUpdateStatus.downloaded)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showUpdateAvailableSnackBar(result);
    });
  }

  Future<void> _cleanupInstalledUpdateArtifactsIfNeeded({
    bool showSnackBar = false,
  }) async {
    if (_updateCleanupInFlight || _clientVersionLabel.trim().isEmpty) {
      return;
    }
    _updateCleanupInFlight = true;
    try {
      final result = await _appUpdateService.cleanupInstalledUpdateArtifacts(
        currentVersion: _clientVersionLabel,
        currentBuildNumber: _clientVersionCode,
      );
      if (!result.changed) {
        return;
      }
      AppLogStore.info(
        'updates',
        'installed update cleanup files=${result.deletedFiles} '
            'metadataChanged=${result.metadataChanged} '
            'installedAtLeastLatest=${result.installedAtLeastLatest} '
            'current=$_clientVersionLabel+$_clientVersionCode',
      );
      if (!showSnackBar ||
          !result.installedAtLeastLatest ||
          result.deletedFiles <= 0) {
        return;
      }
      final versionKey = '$_clientVersionLabel+$_clientVersionCode';
      if (_lastUpdateCleanupNoticeVersion == versionKey) {
        return;
      }
      _lastUpdateCleanupNoticeVersion = versionKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _navigatorKey.currentContext;
        if (!mounted || context == null) return;
        AppNotice.show(
          context,
          AppLocalizations.of(
            context,
          ).updatesDeleteCachedApkDone(result.deletedFiles),
          tone: AppNoticeTone.success,
        );
      });
    } catch (error) {
      AppLogStore.warning('updates', 'installed update cleanup failed: $error');
    } finally {
      _updateCleanupInFlight = false;
    }
  }

  void _showUpdateAvailableSnackBar(AppUpdateCheckResult result) {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final version = result.info?.displayVersion;
    AppNotice.show(
      context,
      version == null
          ? l10n.updatesAvailableSnack
          : l10n.updatesAvailableSnackVersion(version),
      actionLabel: l10n.updatesOpenAction,
      onAction: () => unawaited(_showUpdateSettingsPage()),
    );
  }

  Future<T> _runSubscriptionOperationWithWarning<T>(
    Future<T> operation, {
    required String slowMessage,
    required String timeoutMessage,
  }) async {
    var completed = false;
    final slowTimer = Timer(_subscriptionOperationSoftWarningDelay, () {
      if (!completed && mounted) {
        _showAppSnackBar(slowMessage);
      }
    });
    try {
      return await operation;
    } on TimeoutException {
      throw _LocalizedSubscriptionError(timeoutMessage);
    } finally {
      completed = true;
      slowTimer.cancel();
    }
  }

  String _userFacingSubscriptionError(Object error, AppLocalizations l10n) {
    if (error is _LocalizedSubscriptionError) {
      return error.message;
    }
    return subscriptionErrorMessage(error, l10n);
  }

  Future<void> _refreshActiveSubscription() async {
    if (_activeProfileRefreshInFlight) {
      return;
    }
    final subscription = _activeSubscription;
    final context = _navigatorKey.currentContext;
    if (subscription == null || context == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (SubscriptionStore.isLocalFileImportUrl(subscription.url)) {
      _showAppSnackBar(l10n.refreshActiveSubscriptionUnavailable);
      return;
    }

    _haptic();
    final beforeFingerprint = _subscriptionCoordinator.runtimeFingerprint(
      subscription,
    );
    setState(() {
      _activeProfileRefreshInFlight = true;
    });
    try {
      final updated = await _runSubscriptionOperationWithWarning(
        SubscriptionStore.refresh(
          subscription.id,
          operationTimeout: _subscriptionOperationTimeout,
          allowInsecureTls: _allowUntrustedSubscriptionCertificates,
          onRouteAttempt: _handleSubscriptionRouteAttempt,
        ),
        slowMessage: l10n.subscriptionOperationSlowWarning,
        timeoutMessage: l10n.subscriptionOperationTimeout,
      );
      final afterFingerprint = _subscriptionCoordinator.runtimeFingerprint(
        updated,
      );
      final runtimeChanged = beforeFingerprint != afterFingerprint;
      final preferredTag = _validSelectedProxyTagForSubscription(
        updated,
        _selectedProxyTag,
      );
      await _reloadSubscriptions(
        preferredSubscriptionId: updated.id,
        preferredProxyTag: preferredTag,
        resetRuntimeState: runtimeChanged,
        restartRuntimeOnApply: _connected && runtimeChanged,
        urlTestAfterApply: _connected && runtimeChanged,
      );
      if (!mounted) {
        return;
      }
      _showAppSnackBar(l10n.activeSubscriptionRefreshComplete(updated.name));
      if (!SubscriptionStore.isLocalFileImportUrl(updated.url)) {
        await _offerLikelyHwidFix(updated);
      }
    } catch (error) {
      if (mounted) {
        _showAppSnackBar(_userFacingSubscriptionError(error, l10n));
      }
    } finally {
      if (mounted) {
        setState(() {
          _activeProfileRefreshInFlight = false;
        });
      }
    }
  }

  String _validSelectedProxyTagForSubscription(
    Subscription subscription,
    String preferredTag,
  ) {
    return _proxySelection.validSelectedProxyTagForSubscription(
      subscription,
      preferredTag,
    );
  }

  Future<void> _showTrafficDashboard() async {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    _trafficDashboardOpen = true;
    _publishTrafficDashboardSnapshot(force: true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        enableDrag: true,
        isDismissible: true,
        useSafeArea: false,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.32,
          maxChildSize: 0.94,
          builder: (context, scrollController) => TrafficDashboardPage(
            snapshotListenable: _trafficDashboardSnapshot,
            scrollController: scrollController,
          ),
        ),
      );
    } finally {
      _trafficDashboardOpen = false;
      _trafficSamples = const <TrafficSample>[];
      _trafficDashboardSnapshot.value = TrafficDashboardSnapshot.empty;
    }
  }

  Future<void> _offerLikelyHwidFix(Subscription subscription) async {
    if (!SubscriptionStore.likelyRequiresHwidEnable(subscription)) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.subscriptionLikelyRequiresHwidTitle),
        content: Text(l10n.subscriptionLikelyRequiresHwidMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(dialogContext).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.subscriptionLikelyRequiresHwidAction),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _enableHwidAndRefreshSubscription(subscription.id);
  }

  Future<void> _enableHwidAndRefreshSubscription(String subscriptionId) async {
    final current = await SubscriptionStore.getInBackground(subscriptionId);
    if (current == null) {
      return;
    }
    final wasActive = current.id == _activeProfileId;
    final beforeFingerprint = _subscriptionCoordinator.runtimeFingerprint(
      current,
    );
    final info = current.info ?? const SubscriptionInfo();
    await SubscriptionStore.saveMetadata(
      current.copyWith(info: info.copyWith(requireHwid: true)),
    );
    if (!mounted) {
      return;
    }
    final currentContext = _navigatorKey.currentContext;
    if (currentContext == null || !currentContext.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(currentContext);
    final updated = await _runSubscriptionOperationWithWarning(
      SubscriptionStore.refresh(
        subscriptionId,
        operationTimeout: _subscriptionOperationTimeout,
        allowInsecureTls: _allowUntrustedSubscriptionCertificates,
        onRouteAttempt: _handleSubscriptionRouteAttempt,
      ),
      slowMessage: l10n.subscriptionOperationSlowWarning,
      timeoutMessage: l10n.subscriptionOperationTimeout,
    );
    final runtimeChanged =
        wasActive &&
        beforeFingerprint !=
            _subscriptionCoordinator.runtimeFingerprint(updated);
    await _reloadSubscriptions(
      preferredSubscriptionId: updated.id,
      preferredProxyTag: wasActive
          ? _validSelectedProxyTagForSubscription(updated, _selectedProxyTag)
          : null,
      resetRuntimeState: runtimeChanged,
      restartRuntimeOnApply: _connected && runtimeChanged,
      urlTestAfterApply: _connected && runtimeChanged,
    );
    if (!mounted) {
      return;
    }
    _showAppSnackBar(l10n.subscriptionHwidEnabledAndUpdated);
    if (SubscriptionStore.likelyRequiresHwidEnable(updated)) {
      _offerLikelyHwidFix(updated);
    }
  }

  Future<void> _bootstrap() async {
    final bootstrapStopwatch = Stopwatch()..start();
    late final AppBootstrapResult bootstrap;
    try {
      bootstrap = await _bootstrapController.load(providedStore: widget.store);
    } catch (error, stackTrace) {
      AppLogStore.error(
        'bootstrap',
        'Fatal bootstrap failure: $error\n$stackTrace',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ready = true;
      });
      return;
    }
    final criticalBootstrapMs = bootstrapStopwatch.elapsedMilliseconds;
    final store = bootstrap.store;
    final ownsStore = bootstrap.ownsStore;
    final state = bootstrap.state;
    final adBlockStatus = bootstrap.adBlockStatus;
    final russiaRouteDataStatus = bootstrap.russiaRouteDataStatus;
    final appVersionInfo = bootstrap.appVersionInfo;
    final coreCapabilities = bootstrap.coreCapabilities;
    final pendingCoreConfigMigration = bootstrap.pendingCoreConfigMigration;
    final useInMemoryBootstrap = bootstrap.usesInMemoryStore;
    _latencyCoordinator.updateCapabilities(coreCapabilities);
    AppLogStore.info(
      'sing-box',
      'core capabilities api=${coreCapabilities.apiVersion} '
          'version=${coreCapabilities.coreVersion.isEmpty ? 'legacy' : coreCapabilities.coreVersion}',
    );

    const progressiveBlurEnabled = false;

    final resolvedSubscriptions = useInMemoryBootstrap
        ? const ResolvedSubscriptions(
            subscriptions: <Subscription>[],
            normalized: SubscriptionRuntimeSelection(
              activeSubscriptionId: '',
              selectedProxyTag: '',
            ),
          )
        : await _subscriptionCoordinator.resolveMetadata(
            activeSubscriptionId: state.activeProfileId,
            selectedProxyTag: state.selectedProxyTag,
            preferSelectedProxyTag: state.selectedProxyTag.trim().isNotEmpty,
          );
    final metadataResolveMs =
        bootstrapStopwatch.elapsedMilliseconds - criticalBootstrapMs;
    final subscriptions = resolvedSubscriptions.subscriptions;
    final normalized = resolvedSubscriptions.normalized;

    if (!mounted) {
      if (ownsStore) {
        await store.close();
      }
      return;
    }

    setState(() {
      _pendingCoreConfigMigration = pendingCoreConfigMigration;
      _store = store;
      _ownsStore = ownsStore;
      _clientVersionLabel = appVersionInfo.displayVersion;
      _clientVersionCode = appVersionInfo.updateBuildNumber;
      _clientPackageName = appVersionInfo.packageName;
      _ready = true;
      _onboardingCompleted = state.onboardingCompleted;
      _acceptedLegalVersion = state.acceptedLegalVersion;
      _acceptedLegalAtMillis = state.acceptedLegalAtMillis;
      ref
          .read(subscriptionCatalogProvider.notifier)
          .replace(
            subscriptions: subscriptions,
            activeProfileId: normalized.activeSubscriptionId,
            selectedProxyTag: normalized.selectedProxyTag,
          );
      ref
          .read(appSettingsProvider.notifier)
          .hydrate(
            state,
            progressiveBlurEnabledOverride: progressiveBlurEnabled,
          );
      _adBlockStatus = adBlockStatus;
      _russiaRouteDataStatus = russiaRouteDataStatus;
      _setConnectionPhase(AppConnectionPhase.idle);
      _refreshThemeCache();
      _applyMetadataActiveProfile(
        subscriptions,
        normalized.activeSubscriptionId,
        clearProxyCache: true,
      );
    });
    _lastAppliedSettingsState = _currentSettingsState();
    if (!useInMemoryBootstrap) {
      _scheduleDeferredBootstrapStatuses(
        includeAdBlock: state.adBlockEnabled,
        includeRussiaRouteData: state.useRussiaRouteData,
      );
    }
    if (!useInMemoryBootstrap && normalized.activeSubscriptionId.isNotEmpty) {
      // Keep the first frame metadata-only. Opening the encrypted payload box
      // and building thousands of proxy view models is intentionally delayed
      // until Flutter has presented the home screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(SubscriptionStore.ensurePayloadReady());
          unawaited(_ensureActiveSubscriptionHydratedForRuntime());
        }
      });
    }
    unawaited(_syncQuickSettingsTileLabel());
    AppLogStore.info('sing-box', 'startup');
    unawaited(_syncRuntimeFlags());
    _startSingboxEvents();
    if (_foregroundLifecycleActive) {
      _startSubscriptionAutoRefresh();
      if (!useInMemoryBootstrap) {
        unawaited(_checkForClientUpdatesIfDue());
      }
    }
    bootstrapStopwatch.stop();
    AppLogStore.info(
      'bootstrap performance',
      'readyMs=${bootstrapStopwatch.elapsedMilliseconds} '
          'criticalBootstrapMs=$criticalBootstrapMs '
          'metadataResolveMs=$metadataResolveMs '
          'metadataSubscriptions=${subscriptions.length} '
          'activePayloadDeferred=${!useInMemoryBootstrap && subscriptions.isNotEmpty}',
    );
    if (_pendingDeepLinkImport != null && _onboardingCompleted) {
      unawaited(_drainPendingDeepLinkImports());
    }

    final inboundSettingsMigrated =
        (!state.vpnInboundEnabled && !state.proxyInboundEnabled) ||
        state.proxyMixedListen !=
            (state.proxyAllowLan ? '0.0.0.0' : '127.0.0.1') ||
        !isValidProxyUsername(state.proxyUsername) ||
        !isValidProxyPassword(state.proxyPassword);
    if (normalized.activeSubscriptionId != state.activeProfileId ||
        normalized.selectedProxyTag != state.selectedProxyTag ||
        inboundSettingsMigrated) {
      _saveStateSoon();
    }
  }

  void _scheduleDeferredBootstrapStatuses({
    required bool includeAdBlock,
    required bool includeRussiaRouteData,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        _refreshDeferredBootstrapStatuses(
          includeAdBlock: includeAdBlock,
          includeRussiaRouteData: includeRussiaRouteData,
        ),
      );
    });
  }

  Future<void> _refreshDeferredBootstrapStatuses({
    required bool includeAdBlock,
    required bool includeRussiaRouteData,
  }) async {
    final statuses = await _bootstrapController.loadDeferredStatuses(
      includeAdBlock: includeAdBlock,
      includeRussiaRouteData: includeRussiaRouteData,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _adBlockStatus = statuses.adBlockStatus;
      _russiaRouteDataStatus = statuses.russiaRouteDataStatus;
    });
  }

  AppSettingsState _currentSettingsState() {
    return _settings.toState(
      onboardingCompleted: _onboardingCompleted,
      acceptedLegalVersion: _acceptedLegalVersion,
      acceptedLegalAtMillis: _acceptedLegalAtMillis,
      activeProfileId: _activeProfileId,
      selectedProxyTag: _selectedProxyTag,
    );
  }

  Future<void> _persistState() async {
    final store = _store;
    if (store == null) return;
    await store.saveState(_currentSettingsState());
  }

  Future<void> _applyImportedSettingsState(AppSettingsState state) async {
    await _applySettingsState(state, configReason: 'settings backup imported');
  }

  Future<void> _applySettingsState(
    AppSettingsState state, {
    required String configReason,
  }) async {
    final previousState = _lastAppliedSettingsState ?? _currentSettingsState();
    setState(() {
      ref
          .read(appSettingsProvider.notifier)
          .hydrate(state, progressiveBlurEnabledOverride: false);
      _refreshThemeCache();
    });
    final result = await _configCoordinator.emitCurrentConfigLogAsync(
      configReason,
      restartRuntime: true,
      applyWhenNativeRunning: true,
      forceFullServiceRestart: true,
    );
    if (!mounted) return;
    if (!result.success) {
      _restoreAppliedSettings(previousState, reason: result.error);
      return;
    }
    _lastAppliedSettingsState = _currentSettingsState();
    await _persistState();
    await _syncRuntimeFlags();
  }

  Future<void> _importBackupSubscriptions(
    List<Subscription> importedSubscriptions,
  ) async {
    final controller = SubscriptionProfileImportController(
      loadExisting: SubscriptionStore.getAllMetadataInBackground,
      save: SubscriptionStore.save,
      onApplied: () => _reloadSubscriptions(
        preferredSubscriptionId: _activeProfileId,
        preferredProxyTag: _selectedProxyTag,
        applyRuntime: false,
      ),
    );
    await controller.apply(importedSubscriptions);
  }

  void _haptic() {
    if (_hapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void _saveStateSoon() {
    unawaited(_persistState());
  }

  void _applySettingsChange(AppSettingsChange Function() mutate) {
    final previousState = _lastAppliedSettingsState ?? _currentSettingsState();
    late final AppSettingsChange change;
    setState(() {
      change = ref.read(appSettingsProvider.notifier).mutate((_) => mutate());
      if (change.refreshTheme) {
        _refreshThemeCache();
      }
      if (change.scheduleLocationRefresh) {
        _lastLocationLookupSignature = '';
      }
    });
    if (!change.changed) {
      return;
    }
    if (change.publishTraffic) {
      _publishTrafficDashboardSnapshot();
    }
    final configReason = change.configReason;
    if (configReason != null) {
      _scheduleSettingsConfigTransaction(
        change: change,
        previousState: previousState,
      );
    } else if (_pendingSettingsConfigApplyGeneration == 0) {
      _lastAppliedSettingsState = _currentSettingsState();
      _saveStateSoon();
    }
    if (change.pumpLocationLookupWaiters) {
      _pumpLocationLookupWaiters();
    }
    if (change.scheduleLocationRefresh) {
      _scheduleBestOutboundLocationRefresh();
    }
    if (change.syncRuntimeFlags) {
      unawaited(_syncRuntimeFlags());
    }
  }

  void _scheduleSettingsConfigTransaction({
    required AppSettingsChange change,
    required AppSettingsState previousState,
  }) {
    final generation = ++_settingsConfigApplyGeneration;
    _pendingSettingsConfigApplyGeneration = generation;
    _settingsConfigApplyTimer?.cancel();
    _configCoordinator.cancelPendingWork(reason: 'settings superseded');
    _settingsConfigApplyTimer = Timer(const Duration(milliseconds: 140), () {
      _settingsConfigApplyTimer = null;
      unawaited(
        _runSettingsConfigTransaction(
          change: change,
          previousState: previousState,
          generation: generation,
        ),
      );
    });
  }

  Future<void> _runSettingsConfigTransaction({
    required AppSettingsChange change,
    required AppSettingsState previousState,
    required int generation,
  }) async {
    final reason = change.configReason ?? 'settings changed';
    final result = await _configCoordinator.emitCurrentConfigLogAsync(
      reason,
      restartRuntime: change.restartRuntime,
      applyWhenNativeRunning: true,
      forceFullServiceRestart: change.forceFullServiceRestart,
    );
    if (!mounted || generation != _settingsConfigApplyGeneration) {
      return;
    }
    _pendingSettingsConfigApplyGeneration = 0;
    if (result.success) {
      _lastAppliedSettingsState = _currentSettingsState();
      await _persistState();
      AppLogStore.info(
        'settings transaction',
        'applied reason=$reason configGeneration=$generation '
            'runtimeGeneration=${result.runtimeGeneration}',
      );
      return;
    }
    if (result.superseded) return;
    _restoreAppliedSettings(
      _lastAppliedSettingsState ?? previousState,
      reason: result.error,
    );
    AppLogStore.warning(
      'settings transaction',
      'rolled back reason=$reason configGeneration=$generation '
          'error=${result.error}',
    );
  }

  void _restoreAppliedSettings(
    AppSettingsState state, {
    required String reason,
  }) {
    if (!mounted) return;
    setState(() {
      ref
          .read(appSettingsProvider.notifier)
          .hydrate(state, progressiveBlurEnabledOverride: false);
      _refreshThemeCache();
      _lastLocationLookupSignature = '';
    });
    _lastAppliedSettingsState = state;
    _publishTrafficDashboardSnapshot(force: true);
    unawaited(_syncRuntimeFlags());
    unawaited(_persistState());
    AppLogStore.warning(
      'settings transaction',
      'restored last applied settings error=$reason',
    );
  }

  bool get _foregroundLifecycleActive =>
      _appLifecycleState == AppLifecycleState.resumed;

  bool get _connectionBusy => switch (_connectionPhase) {
    AppConnectionPhase.preparing ||
    AppConnectionPhase.configuring ||
    AppConnectionPhase.reconfiguring ||
    AppConnectionPhase.starting ||
    AppConnectionPhase.stopping ||
    AppConnectionPhase.recovering => true,
    _ => false,
  };

  String _connectionButtonStatusLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_resolvingLowestProxy) {
      return l10n.connectionStageSelectingProxy;
    }
    return switch (_connectionPhase) {
      AppConnectionPhase.preparing => l10n.connectionStagePreparing,
      AppConnectionPhase.configuring => l10n.connectionStageConfiguring,
      AppConnectionPhase.reconfiguring => l10n.connectionStageConfiguring,
      AppConnectionPhase.starting => l10n.connectionStageStarting,
      AppConnectionPhase.stopping => l10n.connectionStageStopping,
      AppConnectionPhase.recovering => l10n.connectionStageRecovering,
      AppConnectionPhase.connected => l10n.connected,
      _ => l10n.tapToConnect,
    };
  }

  bool get _effectiveProgressiveBlurEnabled => false;

  RuntimeTrafficStatus _currentTrafficStatus() {
    return RuntimeTrafficStatus(
      uplinkBytesPerSecond: _uplinkBytesPerSecond,
      downlinkBytesPerSecond: _downlinkBytesPerSecond,
      uplinkTotalBytes: _uplinkTotalBytes,
      downlinkTotalBytes: _downlinkTotalBytes,
      available: _trafficAvailable,
    );
  }

  void _applyTrafficStatus(RuntimeTrafficStatus status) {
    _uplinkBytesPerSecond = status.uplinkBytesPerSecond;
    _downlinkBytesPerSecond = status.downlinkBytesPerSecond;
    _uplinkTotalBytes = status.uplinkTotalBytes;
    _downlinkTotalBytes = status.downlinkTotalBytes;
    _trafficAvailable = status.available;
  }

  void _recordTrafficSample(DateTime now) {
    if (!_trafficDashboardOpen || !_connected || !_trafficAvailable) {
      return;
    }
    final cutoff = now.subtract(const Duration(minutes: 5));
    final next = <TrafficSample>[
      for (final sample in _trafficSamples)
        if (!sample.timestamp.isBefore(cutoff)) sample,
      TrafficSample(
        timestamp: now,
        downlinkBps: _downlinkBytesPerSecond,
        uplinkBps: _uplinkBytesPerSecond,
        totalBytes: _uplinkTotalBytes + _downlinkTotalBytes,
      ),
    ];
    if (next.length > 180) {
      _trafficSamples = List<TrafficSample>.unmodifiable(
        next.skip(next.length - 180),
      );
    } else {
      _trafficSamples = List<TrafficSample>.unmodifiable(next);
    }
  }

  void _resetTrafficDashboardData() {
    _uplinkBytesPerSecond = 0;
    _downlinkBytesPerSecond = 0;
    _uplinkTotalBytes = 0;
    _downlinkTotalBytes = 0;
    _trafficAvailable = false;
    _trafficSamples = const <TrafficSample>[];
  }

  TrafficDashboardSnapshot _currentTrafficDashboardSnapshot() {
    return TrafficDashboardSnapshot(
      connected: _connected,
      connecting: _connectionBusy,
      trafficAvailable: _trafficAvailable,
      hideServerIp: _hideServerIp,
      downlinkBps: _connected && _trafficAvailable
          ? _downlinkBytesPerSecond
          : 0,
      uplinkBps: _connected && _trafficAvailable ? _uplinkBytesPerSecond : 0,
      uplinkTotalBytes: _connected && _trafficAvailable ? _uplinkTotalBytes : 0,
      downlinkTotalBytes: _connected && _trafficAvailable
          ? _downlinkTotalBytes
          : 0,
      connectedSince: _connected ? _connectedSince : null,
      activeProfile: _activeProfile,
      activeProxy: _displayProxy,
      samples: _trafficSamples,
    );
  }

  void _publishTrafficDashboardSnapshot({bool force = false}) {
    final trafficUiSnapshot = TrafficUiSnapshot(
      speedBytesPerSecond: _connected && _trafficAvailable
          ? _downlinkBytesPerSecond.toDouble()
          : 0,
      trafficBytes: _connected && _trafficAvailable
          ? (_uplinkTotalBytes + _downlinkTotalBytes).toDouble()
          : 0,
    );
    if (_trafficUiSnapshot.value != trafficUiSnapshot) {
      _trafficUiSnapshot.value = trafficUiSnapshot;
    }
    if (!_trafficDashboardOpen && !force) {
      return;
    }
    final snapshot = _currentTrafficDashboardSnapshot();
    if (_trafficDashboardSnapshot.value != snapshot) {
      _trafficDashboardSnapshot.value = snapshot;
    }
  }

  void _setConnectionPhase(
    AppConnectionPhase phase, {
    bool retryScheduled = false,
  }) {
    _runtimeOperations.synchronizeSelection(_selectedProxyTag);
    final transition = _runtimeConnection.transitionTo(phase);
    if (mounted) {
      ref
          .read(vpnRuntimeStateProvider.notifier)
          .transitionTo(phase, retryScheduled: retryScheduled);
    }
    if (transition.becameConnected) {
      _connectedSince = DateTime.now();
    } else if (!_connected &&
        (phase == AppConnectionPhase.idle ||
            phase == AppConnectionPhase.failed)) {
      _connectedSince = null;
      _resetActiveProxyIpState();
    }
    if (transition.transitionStarted) {
      _runtimeCommands.invalidate();
      _runtimeOperations.beginRuntimeTransition();
    } else if (transition.transitionFinished) {
      _runtimeOperations.finishRuntimeTransition(running: _connected);
    }
    if (!_connected) {
      _networkRecovery.clearInterfaceIssueWindow();
    }
    if (phase == AppConnectionPhase.connected ||
        phase == AppConnectionPhase.idle ||
        phase == AppConnectionPhase.failed ||
        phase == AppConnectionPhase.stopping) {
      _runtimeLifecycle.cancelStartWatchdog();
    }
    if (_runtimeTransitionInProgress) {
      _proxyRuntime.beginTransition();
    } else {
      _proxyRuntime.endTransition();
    }
    _runtimeRecovery.setRetryScheduled(retryScheduled);
  }

  void _applyActiveProxyIpSnapshot(ActiveProxyIpSnapshot snapshot) {
    _activeProxyIp = snapshot;
    _applyRuntimeStateToDerivedCaches();
  }

  void _publishActiveProxyIpSnapshot(ActiveProxyIpSnapshot snapshot) {
    if (!mounted) {
      _activeProxyIp = snapshot;
      return;
    }
    setState(() {
      _applyActiveProxyIpSnapshot(snapshot);
    });
  }

  void _resetActiveProxyIpState({bool rebuild = true}) {
    _activeProxyIpController.reset(
      onSnapshot: (snapshot) {
        _activeProxyIp = snapshot;
        if (rebuild) {
          _applyRuntimeStateToDerivedCaches();
        }
      },
    );
  }

  void _suspendForegroundWork() {
    unawaited(_syncRuntimeUiForeground(false));
    _proxyChainTargetSourceCache.clear();
    _resumeForegroundSyncTimer?.cancel();
    _subscriptionAutoRefreshTimer?.cancel();
    _activeProxyIpController.cancelPending();
    _locationLookupTimer?.cancel();
    _locationLookupGeneration++;
    _locationLookupInFlight = false;
    _locationLookupRefreshRequested = false;
    _cancelQueuedLocationLookups();
    _trafficUiUpdateTimer?.cancel();
    _trafficUiUpdateTimer = null;
    _pendingTrafficStatusEvent = null;
    _groupUrlTestScheduler.cancel();
    _latencyCoordinator.cancel();
    _networkRecovery.cancelDecision();
    if (_invalidOutboundRetryScheduled && _runtimeDesiredByUser) {
      _runtimeIntent.deferRetryUntilResume();
    }
    _runtimeRecovery.cancelRetry();
  }

  void _resumeForegroundWork() {
    unawaited(_syncRuntimeUiForeground(true));
    _scheduleVpnNotificationSync();
    if (!mounted || !_ready) {
      return;
    }
    _resumeForegroundSyncTimer?.cancel();
    _startSubscriptionAutoRefresh();
    _resumeForegroundSyncTimer = Timer(const Duration(milliseconds: 350), () {
      _resumeForegroundSyncTimer = null;
      if (!mounted || !_foregroundLifecycleActive) {
        return;
      }
      // Android installation starts a new process, and bootstrap already
      // refreshes version metadata plus stale update artifacts there. Repeating
      // package and file I/O on every foreground transition competes with the
      // first interactive frame after returning from recents.
      unawaited(_reconcileRuntimeAfterResume());
      if (_connected) {
        _scheduleActiveOutboundIpRefresh(
          delay: const Duration(milliseconds: 700),
        );
        if (_locationLookupLimit > 0) {
          _scheduleBestOutboundLocationRefresh(
            delay: const Duration(seconds: 1),
          );
        }
      }
      if (_runtimeIntent.consumeRetryOnResume(connected: _connected)) {
        _scheduleInvalidOutboundRetry('resume lifecycle retry');
      }
    });
  }

  Future<void> _syncRuntimeUiForeground(bool foreground) async {
    try {
      await _singboxRuntime.setRuntimeUiForeground(foreground);
    } catch (error) {
      AppLogStore.warning(
        'runtime',
        'failed to sync UI foreground=$foreground: $error',
      );
    }
  }

  Future<void> _reconcileRuntimeAfterResume() async {
    AppLogStore.info('runtime', 'resume reconcile start');
    await _syncRuntimeFlags();
    await _syncRuntimeState();
    if (!_connected || !_foregroundLifecycleActive) {
      return;
    }
    final networkReady = await _networkInterfaceUsable(
      reason: 'resume_reconcile',
    );
    if (!networkReady) {
      _runtimeIntent.deferRetryUntilResume();
      AppLogStore.warning(
        'runtime',
        'resume reconcile postponed: no usable network interface',
      );
      return;
    }
    AppLogStore.debug(
      'runtime',
      'resume reconcile completed without scheduling URLTest',
    );
  }

  void _setMemoryLimitEnabled(bool value, {bool warningDismissed = false}) {
    final previousEnabled = _memoryLimitEnabled;
    final previousDismissed = _memoryLimitWarningDismissed;
    _applySettingsChange(
      () => _settings.setMemoryLimitEnabled(
        value,
        warningDismissed: warningDismissed,
      ),
    );
    if (previousEnabled == _memoryLimitEnabled &&
        previousDismissed == _memoryLimitWarningDismissed) {
      return;
    }
    AppLogStore.info(
      'runtime',
      'memory limit setting changed enabled=$_memoryLimitEnabled '
          'warningDismissed=$_memoryLimitWarningDismissed',
    );
  }

  void _setUpdateInstallMode(AppUpdateInstallMode mode) {
    _applySettingsChange(() => _settings.setUpdateInstallMode(mode));
  }

  void _setUpdateChannel(AppUpdateChannel channel) {
    _applySettingsChange(() => _settings.setUpdateChannel(channel));
  }

  Future<void> _syncRuntimeFlags() {
    return _singboxRuntime.setRuntimeFlags(
      wakeLockEnabled: false,
      networkHeartbeatEnabled: true,
      networkHeartbeatIntervalSeconds: _networkHeartbeatIntervalSeconds,
      memoryLimitEnabled: _memoryLimitEnabled,
    );
  }

  void _startSubscriptionAutoRefresh() {
    _subscriptionAutoRefreshTimer?.cancel();
    _subscriptionAutoRefreshTimer = null;
    if (!mounted ||
        !_foregroundLifecycleActive ||
        !_ready ||
        _subscriptions.isEmpty) {
      return;
    }
    final delay = _subscriptionCoordinator.nextAutoRefreshDelay(_subscriptions);
    if (delay == null) {
      return;
    }
    _subscriptionAutoRefreshTimer = Timer(delay, () {
      _subscriptionAutoRefreshTimer = null;
      if (!mounted) {
        return;
      }
      unawaited(_runSubscriptionAutoRefresh());
    });
  }

  Future<void> _runSubscriptionAutoRefresh() async {
    if (_autoRefreshInFlight) {
      return;
    }
    if (!_ready || _subscriptions.isEmpty || !_foregroundLifecycleActive) {
      _startSubscriptionAutoRefresh();
      return;
    }
    _autoRefreshInFlight = true;
    try {
      final activeBefore = _activeSubscription;
      const refreshLimit = 1;
      final result = await _subscriptionCoordinator.refreshDue(
        subscriptions: _subscriptions,
        activeSubscription: activeBefore,
        concurrency: refreshLimit,
      );
      if (result.dueCount == 0) {
        return;
      }
      final refreshedActiveSubscription = result.refreshedActiveSubscription;
      final activeRuntimeChanged = result.activeRuntimeChanged;
      await _reloadSubscriptions(
        preferredSubscriptionId: refreshedActiveSubscription?.id,
        preferredProxyTag: refreshedActiveSubscription == null
            ? null
            : _validSelectedProxyTagForSubscription(
                refreshedActiveSubscription,
                _selectedProxyTag,
              ),
        applyRuntime: activeRuntimeChanged,
        resetRuntimeState: activeRuntimeChanged,
        restartRuntimeOnApply: _connected && activeRuntimeChanged,
        urlTestAfterApply: _connected && activeRuntimeChanged,
      );
      AppLogStore.info('subscription refresh', 'auto-refresh done');
    } finally {
      _autoRefreshInFlight = false;
      _startSubscriptionAutoRefresh();
    }
  }

  String _outboundDebugSnapshot({required String reason}) {
    final subscription = _activeSubscription;
    if (subscription == null) {
      return 'outbound snapshot reason=$reason activeSubscription=null';
    }
    final outbounds = subscription.outbounds;
    final sample = outbounds
        .take(14)
        .map((outbound) {
          final type = outbound.type;
          final deleted = outbound.info.deleted ? ' deleted' : '';
          final groupOnly = outbound.config['_group_only'] == true
              ? ' groupOnly'
              : '';
          final detour = outbound.config['detour']?.toString().trim() ?? '';
          final detourText = detour.isEmpty ? '' : ' detour=$detour';
          return '${outbound.tag}($type$deleted$groupOnly$detourText)';
        })
        .join(', ');
    return 'outbound snapshot reason=$reason '
        'sub=${subscription.id} selected=$_selectedProxyTag '
        'outbounds=${outbounds.length} groups=${subscription.groups.length} '
        'chains=${subscription.proxyChains.length}'
        '${sample.isEmpty ? '' : '\nsample: $sample'}';
  }

  void _logLibboxCall(String method, String detail) {
    AppLogStore.info(
      'libbox call',
      '$method $detail\n${_outboundDebugSnapshot(reason: method)}',
    );
  }

  void _completeOnboarding() {
    setState(() {
      _onboardingCompleted = true;
    });
    _saveStateSoon();
    if (_pendingDeepLinkImport != null && _legalAccepted) {
      unawaited(_drainPendingDeepLinkImports());
    }
  }

  void _acceptLegalDocuments() {
    setState(() {
      _acceptedLegalVersion = _requiredLegalVersion;
      _acceptedLegalAtMillis = DateTime.now().millisecondsSinceEpoch;
    });
    _saveStateSoon();
    if (_pendingDeepLinkImport != null) {
      unawaited(_drainPendingDeepLinkImports());
    }
  }

  void _resetOnboarding() {
    setState(() {
      _onboardingCompleted = false;
    });
    _saveStateSoon();
  }

  Future<void> _toggleConnection({String source = 'unknown'}) async {
    _haptic();
    if (_connectionPhase == AppConnectionPhase.stopping) {
      _runtimeIntent.queueStartAfterStop();
      AppLogStore.info(
        'runtime',
        'connection start queued while stopping source=$source',
      );
      return;
    }
    if (_runtimeActiveOrRequested) {
      await _stopRuntime(reason: 'toggle_connection');
      return;
    }

    await _startConnection(source: source);
  }

  bool get _runtimeActiveOrRequested =>
      _connected ||
      _runtimeDesiredByUser ||
      _connectionPhase == AppConnectionPhase.preparing ||
      _connectionPhase == AppConnectionPhase.configuring ||
      _connectionPhase == AppConnectionPhase.starting ||
      _connectionPhase == AppConnectionPhase.stopping ||
      _connectionPhase == AppConnectionPhase.recovering ||
      _connectionPhase == AppConnectionPhase.reconfiguring;

  Future<bool> _stopRuntime({
    required String reason,
    bool allowQueuedRestart = true,
  }) {
    return _runtimeSession.stop(
      activeOrRequested: _runtimeActiveOrRequested,
      allowQueuedRestart: allowQueuedRestart,
      suppressQueuedRestart: _runtimeIntent.suppressQueuedRestart,
      clearQueuedRestartSuppression:
          _runtimeIntent.clearQueuedRestartSuppression,
      performStop: () => _performRuntimeStop(reason: reason),
    );
  }

  Future<bool> _performRuntimeStop({required String reason}) async {
    _cancelAutomaticRuntimeRecovery('stop:$reason');
    _cancelManualRuntimeStart('stop:$reason');
    _runtimeIntent.beginExplicitStop();
    if (mounted) {
      setState(() {
        _setConnectionPhase(AppConnectionPhase.stopping);
      });
    } else {
      _setConnectionPhase(AppConnectionPhase.stopping);
    }

    final stopped = await _runtimeLifecycle.stopRuntime(reason: reason);
    if (!mounted) {
      return stopped;
    }
    if (!stopped) {
      _runtimeIntent.restoreAfterStopFailure();
      setState(() {
        _setConnectionPhase(AppConnectionPhase.connected);
      });
      _showAppSnackBar(_vpnStopFailedMessage);
      return false;
    }

    final startAfterStop = _runtimeIntent.completeSuccessfulStop();
    _latencyCoordinator.cancel();
    _groupUrlTestScheduler.cancel();
    setState(() {
      _setConnectionPhase(AppConnectionPhase.idle);
      _resetActiveProxyIpState();
      _locationLookupGeneration++;
      _locationLookupTimer?.cancel();
      _locationLookupInFlight = false;
      _locationLookupRefreshRequested = false;
      _cancelQueuedLocationLookups();
      _runtimeRecovery.clearExcludedOutbounds();
      _clearLastStartedBuildCache();
      _runtimeRecovery.cancelRetry();
      _lowestLatency = null;
      _runtimeLowestOutboundTag = null;
      _runtimeLowestSelections.clear();
      _runtimeLatencies.clear();
      _unavailableLatencyTags.clear();
      _invalidatedLatencyTags.clear();
      _latencyErrors.clear();
      _latencyFailureCounts.clear();
      _networkRecovery.cancelDecision();
      _applyRuntimeStateToDerivedCaches();
    });
    unawaited(_syncQuickSettingsTileLabel());
    if (startAfterStop && mounted) {
      AppLogStore.info(
        'runtime',
        'connection queued start after stop source=$reason',
      );
      await _startConnection(source: 'queued_after_stop:$reason');
    }
    return true;
  }

  Future<void> _startConnection({required String source}) async {
    if (_runtimeTransitionInProgress ||
        _starting ||
        _invalidOutboundRetryScheduled) {
      return;
    }
    // A foreground VPN can outlive Flutter. Reconcile with the native owner
    // before showing "Building config" or rebuilding an already running
    // runtime after the Activity has been recreated.
    await _syncRuntimeState();
    if (!mounted || _runtimeActiveOrRequested) {
      if (_connected) {
        AppLogStore.info(
          'runtime',
          'manual start reattached to existing runtime source=$source',
        );
      }
      return;
    }
    final startGeneration = _runtimeIntent.beginManualStart();
    AppLogStore.info(
      'sing-box',
      'manual start requested source=$source\n'
          '${_outboundDebugSnapshot(reason: 'manual start')}',
    );
    _trimRuntimeStartMemory('before_runtime_start');

    if (!_vpnInboundEnabled && !_proxyInboundEnabled) {
      _showAppSnackBar(AppLocalizations.of(context).inboundNoneEnabled);
      return;
    }

    if (_vpnInboundEnabled &&
        _splitRoutingMode != SplitRoutingMode.disabled &&
        normalizeSplitRoutingPackages(_splitRoutingPackages).isEmpty) {
      _showAppSnackBar(AppLocalizations.of(context).splitRoutingEmptyWhitelist);
      return;
    }

    SingboxConfigBuildResult? build;
    _runtimeIntent.markRuntimeDesired();
    try {
      setState(() {
        _setConnectionPhase(AppConnectionPhase.preparing);
      });

      final granted = await _singboxRuntime.prepareVpn(
        requiresVpn: _vpnInboundEnabled,
      );
      if (!_manualRuntimeStartCurrent(startGeneration)) {
        return;
      }
      if (!granted) {
        _runtimeIntent.clearRuntimeDesired();
        setState(() {
          _setConnectionPhase(AppConnectionPhase.idle);
        });
        return;
      }

      await _synchronizeSelectedProxyBeforeStart();
      if (!_manualRuntimeStartCurrent(startGeneration)) {
        return;
      }
      setState(() {
        _setConnectionPhase(AppConnectionPhase.configuring);
      });

      build = await _configCoordinator.buildCurrentSingboxConfigInBackground(
        returnConfig: true,
      );
      if (!_manualRuntimeStartCurrent(startGeneration)) {
        if (build != null) {
          _configCoordinator.discardPreparedConfigCandidate(build);
        }
        return;
      }
      if (build == null) {
        _runtimeIntent.clearRuntimeDesired();
        setState(() {
          _setConnectionPhase(AppConnectionPhase.idle);
        });
        return;
      }
      if (!_applyStartupValidationResult(build, 'manual start')) {
        _configCoordinator.discardPreparedConfigCandidate(build);
        _runtimeIntent.clearRuntimeDesired();
        setState(() {
          _setConnectionPhase(AppConnectionPhase.failed);
        });
        _showNoValidOutboundsWarning();
        return;
      }
      setState(() {
        _setConnectionPhase(AppConnectionPhase.starting);
      });
      final selectedTagForStart = _selectedProxyTag.trim();
      if (selectedTagForStart.isNotEmpty) {
        _proxySelection.guardCurrentSelectionForRuntime(
          tag: selectedTagForStart,
          previousTag: selectedTagForStart,
          onTimeout: _handleRuntimeProxySelectionTimeout,
          confirmationTimeout:
              _runtimeLifecycle.startTimeout +
              _runtimeCommands.selectionTimeout +
              const Duration(seconds: 2),
        );
      }
      await _startRuntimeWithBuild(
        build,
        useVpn: _vpnInboundEnabled,
        manualStartGeneration: startGeneration,
      );
    } catch (error, stackTrace) {
      if (build != null) {
        _configCoordinator.discardPreparedConfigCandidate(build);
      }
      if (!_manualRuntimeStartCurrent(startGeneration)) {
        AppLogStore.info(
          'runtime',
          'discarded cancelled manual start result source=$source error=$error',
        );
        return;
      }
      AppLogStore.error(
        'sing-box',
        'manual start failed source=$source error=$error\n$stackTrace',
      );
      await _handleRuntimeError(error.toString(), false);
    }
  }

  bool _manualRuntimeStartCurrent(int generation) {
    return mounted && _runtimeIntent.isManualStartCurrent(generation);
  }

  void _cancelManualRuntimeStart(String reason) {
    _runtimeIntent.invalidateManualStart();
    _configCoordinator.cancelPendingWork(reason: reason);
  }

  void _selectProxy(String tag) {
    final activeSubscription = _activeSubscription;
    if (activeSubscription == null || _selectedProxyTag == tag) {
      return;
    }

    final previousTag = _selectedProxyTag;
    final previousProxy = _displayProxyForSelectedTag(previousTag);
    final requestedProxy = _displayProxyForSelectedTag(tag);
    AppLogStore.info(
      'proxy',
      'user requested new outbound '
          'from=${previousTag.isEmpty ? '<none>' : previousTag}'
          '${previousProxy == null ? '' : ' (${previousProxy.displayName})'} '
          'to=$tag'
          '${requestedProxy == null ? '' : ' (${requestedProxy.displayName})'} '
          'subscription=${activeSubscription.id} '
          'connected=$_connected',
    );
    _haptic();
    final updatedSubscription = _withSelectedOutbound(activeSubscription, tag);
    _runtimeOperations.beginSelection(tag);
    _resetActiveProxyIpState(rebuild: false);
    final selectInRuntime = _proxySelection.runtimeSelectionUpdatesAllowed(
      connected: _connected,
      connectionStable: _connectionPhase == AppConnectionPhase.connected,
      transitionInProgress: _runtimeTransitionInProgress,
    );
    final selectionGeneration = selectInRuntime
        ? _beginRuntimeProxySelectionGuard(tag, previousTag)
        : _beginLocalProxySelection();
    setState(() {
      _subscriptions = _replaceSubscription(updatedSubscription);
      _activeLookupSubscription = null;
      _selectedProxyTag = tag;
      _displayProxyCache =
          _displayProxyForSelectedTag(tag) ?? _displayProxyCache;
    });
    // A selection changes at most the old and the new visible rows. Rebuilding
    // every proxy summary here turns a Wi-Fi/LTE handover plus one tap into a
    // multi-thousand-row synchronous allocation burst.
    final selectedActiveOutboundTag = _currentResolvedActiveOutboundTag();
    _publishProxyRuntimeVisualStatesForTags(<String>{
      previousTag,
      tag,
      ?selectedActiveOutboundTag,
    });
    _scheduleVpnNotificationSync();
    AppLogStore.info(
      'proxy',
      'local selected outbound updated tag=$tag '
          'display=${_displayProxyCache?.displayName ?? tag}',
    );
    unawaited(_syncQuickSettingsTileLabel());
    _saveStateSoon();
    unawaited(
      _proxySelection.enqueuePersistence(
        generation: selectionGeneration,
        action: () => _persistSelectedProxySelection(
          updatedSubscription,
          generation: selectionGeneration,
          prepareConfigSnapshot: !selectInRuntime,
        ),
      ),
    );
    if (selectInRuntime) {
      unawaited(() async {
        try {
          _logLibboxCall(
            'selectOutbound',
            'reason=user proxy select group=select outbound=$tag',
          );
          final result = await _runtimeCommands.selectOutbound(tag);
          if (!mounted ||
              !_proxySelection.isCurrentGeneration(selectionGeneration)) {
            return;
          }
          if (result.status == RuntimeSelectionStatus.stale) {
            return;
          }
          if (!result.applied) {
            throw result.error ?? StateError('selector command failed');
          }
          AppLogStore.info(
            'libbox call',
            'selectOutbound done group=select outbound=$tag '
                'elapsedMs=${result.elapsed.inMilliseconds}',
          );
          await _persistSelectedProxyConfigSnapshot(
            reason: 'proxy selection persisted',
            generation: selectionGeneration,
          );
          _clearRuntimeProxySelectionGuard(generation: selectionGeneration);
          _scheduleActiveOutboundIpRefresh();
        } catch (error) {
          if (!mounted ||
              !_proxySelection.isCurrentGeneration(selectionGeneration)) {
            return;
          }
          AppLogStore.error(
            'proxy',
            'Failed to select proxy "$tag" via command API: '
                '$error. Runtime restart was not requested.',
          );
          _clearRuntimeProxySelectionGuard(generation: selectionGeneration);
          _showAppSnackBar('Failed to select proxy: $error');
        }
      }());
    }
  }

  Future<void> _persistSelectedProxySelection(
    Subscription updatedSubscription, {
    required int generation,
    required bool prepareConfigSnapshot,
  }) async {
    try {
      await Future.wait<void>([
        SubscriptionStore.saveSelectedProxyMetadata(updatedSubscription),
        _persistState(),
      ]);
      if (prepareConfigSnapshot) {
        await _persistSelectedProxyConfigSnapshot(
          reason: 'pre-start proxy selection persisted',
          generation: generation,
        );
      }
    } catch (error) {
      AppLogStore.error(
        'proxy',
        'Failed to persist selected outbound '
            'tag=${updatedSubscription.selectedProxyTag}: $error',
      );
    }
  }

  Future<void> _synchronizeSelectedProxyBeforeStart() async {
    await _proxySelection.waitForPersistence();
    if (!mounted) {
      return;
    }
    final activeSubscription = _activeSubscription;
    if (activeSubscription == null) {
      return;
    }
    var tag = _selectedProxyTag.trim();
    if (tag.isEmpty && activeSubscription.selectedProxyTag.trim().isNotEmpty) {
      tag = activeSubscription.selectedProxyTag.trim();
      if (mounted) {
        setState(() {
          _selectedProxyTag = tag;
          _displayProxyCache =
              _displayProxyForSelectedTag(tag) ?? _displayProxyCache;
          _applyRuntimeStateToDerivedCaches();
        });
      } else {
        _selectedProxyTag = tag;
      }
    }
    if (tag.isEmpty) {
      await _persistState();
      return;
    }
    if (activeSubscription.selectedProxyTag == tag) {
      await Future.wait<void>([
        SubscriptionStore.saveSelectedProxyMetadata(activeSubscription),
        _persistState(),
      ]);
      return;
    }
    final updatedSubscription = _withSelectedOutbound(activeSubscription, tag);
    if (mounted) {
      setState(() {
        _subscriptions = _replaceSubscription(updatedSubscription);
        _activeLookupSubscription = null;
        _applyRuntimeStateToDerivedCaches();
      });
    } else {
      _subscriptions = _replaceSubscription(updatedSubscription);
      _activeLookupSubscription = null;
    }
    AppLogStore.info(
      'proxy',
      'start selection sync active=${updatedSubscription.id} '
          'selected=$tag previous=${activeSubscription.selectedProxyTag}',
    );
    await Future.wait<void>([
      SubscriptionStore.saveSelectedProxyMetadata(updatedSubscription),
      _persistState(),
    ]);
  }

  Set<String> _expectedLatencyTagsForSession(String targetTag) {
    final normalizedTarget = targetTag.trim();
    if (normalizedTarget.isNotEmpty) {
      return <String>{normalizedTarget};
    }
    _ensureActiveLookupCaches();
    final expectedTags = <String>{
      for (final tag in _activeOutboundByTagLookup.keys)
        if (!_excludedRuntimeOutboundTags.contains(tag)) tag,
    };
    final activeSubscription = _activeSubscription;
    if (activeSubscription != null) {
      for (final chain in activeSubscription.proxyChains) {
        final tag = chain.tag.trim();
        if (tag.isNotEmpty && !_excludedRuntimeOutboundTags.contains(tag)) {
          expectedTags.add(tag);
        }
      }
    }
    return expectedTags;
  }

  void _scheduleGroupUrlTest({
    required String reason,
    Duration delay = const Duration(milliseconds: 2500),
  }) {
    if (!mounted || !_foregroundLifecycleActive) {
      return;
    }
    AppLogStore.debug(
      'latency',
      'automatic group URLTest scheduled reason=$reason '
          'delayMs=${delay.inMilliseconds}',
    );
    _groupUrlTestScheduler.schedule(
      delay: delay,
      canRun: () {
        final ready =
            mounted &&
            _connected &&
            _foregroundLifecycleActive &&
            !_runtimeTransitionInProgress &&
            _runtimeOperations.diagnosticsReady &&
            !_urlTestInFlight;
        if (!ready) {
          AppLogStore.debug(
            'latency',
            'automatic group URLTest discarded reason=$reason',
          );
        }
        return ready;
      },
      run: () {
        AppLogStore.info(
          'latency',
          'automatic group URLTest start reason=$reason',
        );
        return _latencyCoordinator.runFull(reason: reason);
      },
    );
  }

  Future<void> _addProxyChain(String detourTag, String targetRef) async {
    final subscription = _activeSubscription;
    if (subscription == null) {
      return;
    }
    _ensureActiveLookupCaches();
    final resolvedTarget = await _resolveProxyChainTarget(targetRef);
    if (resolvedTarget == null) {
      return;
    }
    final target = resolvedTarget.outbound;
    final detour = detourTag.trim();
    if (detour.isEmpty) {
      return;
    }
    final tag = _newProxyChainTag(subscription);
    final targetName = target.name.trim().isEmpty
        ? target.tag
        : target.name.trim();
    final chain = SubscriptionProxyChain(
      tag: tag,
      name: 'chain · $targetName',
      targetTag: target.tag,
      detourTag: detour,
      targetSubscriptionId: resolvedTarget.subscription.id,
      targetName: targetName,
      targetCountry: _normalizeCountryCode(target.info.country),
      targetConfig: Map<String, dynamic>.from(target.config),
    );
    await _upsertProxyChain(subscription, chain, selectAfterApply: false);
  }

  Future<void> _changeProxyChainDetour(
    String chainTag,
    String detourTag,
  ) async {
    final subscription = _activeSubscription;
    final existing = _proxyChainForTag(chainTag);
    if (subscription == null || existing == null) {
      return;
    }
    final detour = detourTag.trim();
    if (detour.isEmpty) {
      return;
    }
    final updated = existing.copyWith(detourTag: detour);
    await _upsertProxyChain(subscription, updated, selectAfterApply: false);
  }

  Future<void> _renameProxyChain(String chainTag, String name) async {
    final subscription = _activeSubscription;
    final existing = _proxyChainForTag(chainTag);
    if (subscription == null || existing == null) {
      return;
    }
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName == existing.name) {
      return;
    }
    final updatedChain = existing.copyWith(name: normalizedName);
    final updated = subscription.copyWith(
      proxyChains: [
        for (final chain in subscription.proxyChains)
          chain.tag == existing.tag ? updatedChain : chain,
      ],
    );
    setState(() {
      _subscriptions = _replaceSubscription(updated);
      _activeLookupSubscription = null;
      _displayProxyCache =
          _displayProxyForSelectedTag(_selectedProxyTag) ?? _displayProxyCache;
      _applyRuntimeStateToDerivedCaches();
    });
    _saveStateSoon();
    unawaited(SubscriptionStore.saveMetadata(updated));
    _rebuildDerivedCaches();
  }

  Future<void> _removeProxyChain(String chainTag) async {
    final subscription = _activeSubscription;
    if (subscription == null) {
      return;
    }
    final normalizedTag = chainTag.trim();
    if (normalizedTag.isEmpty) {
      return;
    }
    final nextChains = subscription.proxyChains
        .where((chain) => chain.tag != normalizedTag)
        .toList(growable: false);
    var nextSelectedTag = _selectedProxyTag;
    if (nextSelectedTag == normalizedTag) {
      _ensureActiveLookupCaches();
      nextSelectedTag = '';
      for (final proxy in _activeVisibleOutboundsLookup) {
        if (proxy.tag != normalizedTag) {
          nextSelectedTag = proxy.tag;
          break;
        }
      }
    }
    final updated = subscription.copyWith(
      proxyChains: nextChains,
      selectedProxyTag: nextSelectedTag,
    );
    setState(() {
      _subscriptions = _replaceSubscription(updated);
      _activeLookupSubscription = null;
      _selectedProxyTag = nextSelectedTag;
      _displayProxyCache =
          _displayProxyForSelectedTag(nextSelectedTag) ?? _displayProxyCache;
      _applyRuntimeStateToDerivedCaches();
    });
    _saveStateSoon();
    unawaited(SubscriptionStore.saveMetadata(updated));
    _rebuildDerivedCaches();
    if (_connected) {
      AppLogStore.info(
        'proxy chain',
        'proxy chain removed; applying runtime config tag=$normalizedTag '
            'selected=$nextSelectedTag',
      );
      await _configCoordinator.emitCurrentConfigLogAsync(
        'proxy_chain_removed',
        restartRuntime: false,
      );
      if (mounted && _connected) {
        _scheduleGroupUrlTest(
          reason: 'proxy_chain_composition_changed',
          delay: const Duration(milliseconds: 2500),
        );
      }
    }
  }

  Future<void> _upsertProxyChain(
    Subscription subscription,
    SubscriptionProxyChain chain, {
    required bool selectAfterApply,
  }) async {
    _ensureActiveLookupCaches();
    final target = _targetOutboundForProxyChain(chain);
    if (target == null) {
      return;
    }
    final config = SingboxConfigBuilder.buildProxyChainOutboundConfig(
      chain: chain,
      target: target,
      vpnInboundEnabled: _vpnInboundEnabled,
      tcpFastOpenEnabled: _experimentalTcpFastOpen,
      tcpMultiPathEnabled: _experimentalTcpMultiPath,
      tlsFragmentationMode: _tlsFragmentationMode,
      allowUntrustedProxyCertificates: _allowUntrustedProxyCertificates,
      supportsRealitySpiderX:
          _latencyCoordinator.capabilities.isLegacyContract ||
          _latencyCoordinator.capabilities.supportsRealitySpiderX,
    );
    if (config == null) {
      return;
    }
    final chains = [
      for (final existing in subscription.proxyChains)
        if (existing.tag != chain.tag) existing,
      chain,
    ];
    final updated = subscription.copyWith(
      proxyChains: chains,
      selectedProxyTag: selectAfterApply
          ? chain.tag
          : subscription.selectedProxyTag,
    );
    setState(() {
      _subscriptions = _replaceSubscription(updated);
      _activeLookupSubscription = null;
      if (selectAfterApply) {
        _selectedProxyTag = chain.tag;
      }
      _displayProxyCache =
          _displayProxyForSelectedTag(_selectedProxyTag) ?? _displayProxyCache;
      _applyRuntimeStateToDerivedCaches();
    });
    _saveStateSoon();
    unawaited(SubscriptionStore.saveMetadata(updated));
    _rebuildDerivedCaches();
    if (_connected) {
      AppLogStore.info(
        'proxy chain',
        'proxy chain upserted; applying runtime config tag=${chain.tag} '
            'detour=${chain.detourTag} target=${chain.targetTag}',
      );
      await _configCoordinator.emitCurrentConfigLogAsync(
        'proxy_chain_upserted',
        restartRuntime: false,
      );
      if (mounted && _connected) {
        _scheduleGroupUrlTest(
          reason: 'proxy_chain_composition_changed',
          delay: const Duration(milliseconds: 2500),
        );
      }
    }
  }

  String _newProxyChainTag(Subscription subscription) {
    final usedTags = <String>{
      ...subscription.outbounds.map((outbound) => outbound.tag),
      ...subscription.groups.map((group) => group.tag),
      ...subscription.proxyChains.map((chain) => chain.tag),
      ...reservedProxyTags,
    };
    final base = 'chain-${DateTime.now().millisecondsSinceEpoch}';
    var tag = base;
    var index = 2;
    while (usedTags.contains(tag)) {
      tag = '$base-$index';
      index++;
    }
    return tag;
  }

  Outbound? _snapshotOutboundForProxyChain(SubscriptionProxyChain chain) {
    if (chain.targetConfig.isEmpty || chain.targetTag.trim().isEmpty) {
      return null;
    }
    final config = Map<String, dynamic>.from(chain.targetConfig);
    config['tag'] = chain.targetTag.trim();
    return Outbound(
      tag: chain.targetTag.trim(),
      name: chain.targetName.trim().isEmpty
          ? chain.targetTag.trim()
          : chain.targetName.trim(),
      config: config,
      info: OutboundInfo(country: chain.targetCountry),
    );
  }

  Outbound? _targetOutboundForProxyChain(SubscriptionProxyChain chain) {
    final activeId = _activeSubscription?.id ?? '';
    final targetSubscriptionId = chain.targetSubscriptionId.trim();
    if (targetSubscriptionId.isNotEmpty && targetSubscriptionId != activeId) {
      return _snapshotOutboundForProxyChain(chain);
    }
    return _activeOutboundByTagLookup[chain.targetTag] ??
        _snapshotOutboundForProxyChain(chain);
  }

  String _proxyDisplayNameForTag(String tag) {
    final normalized = normalizeProxySelectionTag(tag);
    if (normalized.isEmpty) {
      return '';
    }
    return _displayProxyForSelectedTag(normalized)?.displayName ??
        (isLowestProxyTag(normalized)
            ? lowestProxyBaseLabel(normalized)
            : normalized);
  }

  void _setLocale(String localeCode) {
    _applySettingsChange(() => _settings.setLocale(localeCode));
  }

  void _setThemePreference(AppThemePreference preference) {
    _applySettingsChange(() => _settings.setThemePreference(preference));
  }

  void _setHapticEnabled(bool value) {
    _applySettingsChange(() => _settings.setHapticEnabled(value));
  }

  void _setStatusNotificationEnabled(bool value) {
    _applySettingsChange(() => _settings.setStatusNotificationEnabled(value));
    _lastVpnNotificationPresentationSignature = '';
    _scheduleVpnNotificationSync();
    if (value) {
      unawaited(_requestNotificationPermissionIfNeeded(force: true));
    }
  }

  void _setNotificationTrafficDisplayMode(
    NotificationTrafficDisplayMode value,
  ) {
    _applySettingsChange(
      () => _settings.setNotificationTrafficDisplayMode(value),
    );
    _lastVpnNotificationPresentationSignature = '';
    _scheduleVpnNotificationSync();
  }

  void _setNotificationTrafficRefreshSeconds(int value) {
    _applySettingsChange(
      () => _settings.setNotificationTrafficRefreshSeconds(value),
    );
    _lastVpnNotificationPresentationSignature = '';
    _scheduleVpnNotificationSync();
  }

  void _setHideServerIp(bool value) {
    _applySettingsChange(() => _settings.setHideServerIp(value));
  }

  void _setAllowUntrustedProxyCertificates(bool value) {
    _applySettingsChange(
      () => _settings.setAllowUntrustedProxyCertificates(value),
    );
  }

  void _setAllowUntrustedSubscriptionCertificates(bool value) {
    _applySettingsChange(
      () => _settings.setAllowUntrustedSubscriptionCertificates(value),
    );
  }

  void _setProxySort(ProxySort value) {
    _applySettingsChange(() => _settings.setProxySort(value.name));
  }

  void _setAccentColor(String hex) {
    _applySettingsChange(() => _settings.setAccentColor(hex));
  }

  void _setVpnMtu(int value) {
    _applySettingsChange(() => _settings.setVpnMtu(value));
  }

  void _setVpnStrictRoute(bool value) {
    _applySettingsChange(() => _settings.setVpnStrictRoute(value));
  }

  void _setVpnTunImplementation(TunImplementationPreference value) {
    _applySettingsChange(() => _settings.setVpnTunImplementation(value));
  }

  void _setProxyInboundEnabled(bool value) {
    _applySettingsChange(() => _settings.setProxyInboundEnabled(value));
  }

  void _setProxyAllowLan(bool value) {
    _applySettingsChange(() => _settings.setProxyAllowLan(value));
  }

  void _setProxyMixedPort(int value) {
    _applySettingsChange(() => _settings.setProxyMixedPort(value));
  }

  void _setInboundConnectionMode(InboundConnectionMode value) {
    _applySettingsChange(() => _settings.setInboundConnectionMode(value));
  }

  void _setProxyPassword(String value) {
    _applySettingsChange(() => _settings.setProxyPassword(value));
  }

  void _setProxyUsername(String value) {
    _applySettingsChange(() => _settings.setProxyUsername(value));
  }

  void _setDnsDirectPreset(String value) {
    _applySettingsChange(() => _settings.setDnsDirectPreset(value));
  }

  void _setDnsDirectResolver(String value) {
    _applySettingsChange(() => _settings.setDnsDirectResolver(value));
  }

  void _setDnsProxyPreset(String value) {
    _applySettingsChange(() => _settings.setDnsProxyPreset(value));
  }

  void _setDnsProxyResolver(String value) {
    _applySettingsChange(() => _settings.setDnsProxyResolver(value));
  }

  void _setDnsPreferIpv6(bool value) {
    _applySettingsChange(() => _settings.setDnsPreferIpv6(value));
  }

  void _setRussiaDnsDirectResolver(String value) {
    _applySettingsChange(() => _settings.setRussiaDnsDirectResolver(value));
  }

  void _setUrlTestUrl(String value) {
    _applySettingsChange(() => _settings.setUrlTestUrl(value));
  }

  void _setUrlTestIntervalSeconds(int value) {
    _applySettingsChange(() => _settings.setUrlTestIntervalSeconds(value));
  }

  void _setUrlTestTimeoutSeconds(int value) {
    _applySettingsChange(() => _settings.setUrlTestTimeoutSeconds(value));
  }

  void _setUrlTestConcurrency(int value) {
    _applySettingsChange(() => _settings.setUrlTestConcurrency(value));
  }

  void _setUrlTestUnavailableCheckIntervalSeconds(int value) {
    _applySettingsChange(
      () => _settings.setUrlTestUnavailableCheckIntervalSeconds(value),
    );
  }

  void _setLocationLookupLimit(int value) {
    _applySettingsChange(() => _settings.setLocationLookupLimit(value));
  }

  void _setLocationLookupTimeoutSeconds(int value) {
    _applySettingsChange(
      () => _settings.setLocationLookupTimeoutSeconds(value),
    );
  }

  void _setLocationLookupConcurrency(int value) {
    _applySettingsChange(() => _settings.setLocationLookupConcurrency(value));
  }

  Color? get _seedColor {
    if (_accentColorHex == 'default') return _dynamicLightScheme?.primary;
    final parsed = int.tryParse(_accentColorHex, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }

  void _refreshThemeCache() {
    final useDynamicScheme =
        _accentColorHex == 'default' && _dynamicLightScheme != null;
    final seedColor = _seedColor;

    if (useDynamicScheme) {
      _lightTheme = buildDemoTheme(
        Brightness.light,
        dynamicLightScheme: _dynamicLightScheme,
        dynamicDarkScheme: _dynamicDarkScheme,
      );
      _darkTheme = buildDemoTheme(
        Brightness.dark,
        dynamicLightScheme: _dynamicLightScheme,
        dynamicDarkScheme: _dynamicDarkScheme,
      );
      _amoledTheme = buildAmoledTheme(
        dynamicLightScheme: _dynamicLightScheme,
        dynamicDarkScheme: _dynamicDarkScheme,
      );
    } else {
      _lightTheme = buildDemoTheme(Brightness.light, seedColor: seedColor);
      _darkTheme = buildDemoTheme(Brightness.dark, seedColor: seedColor);
      _amoledTheme = buildAmoledTheme(seedColor: seedColor);
    }
  }

  Future<void> _reloadSubscriptions({
    String? preferredSubscriptionId,
    String? preferredProxyTag,
    bool applyRuntime = true,
    bool resetRuntimeState = false,
    bool restartRuntimeOnApply = false,
    bool urlTestAfterApply = false,
  }) async {
    final resolved = await _subscriptionCoordinator.resolveMetadata(
      activeSubscriptionId: preferredSubscriptionId ?? _activeProfileId,
      selectedProxyTag: preferredProxyTag ?? _selectedProxyTag,
      preferSelectedProxyTag: preferredProxyTag?.trim().isNotEmpty == true,
    );
    final subscriptions = resolved.subscriptions;
    final normalized = resolved.normalized;

    if (!mounted) {
      return;
    }

    final nextActiveId = normalized.activeSubscriptionId;
    final activeChanged = nextActiveId != _activeProfileId;
    final shouldResetRuntimeState = activeChanged || resetRuntimeState;
    final preserveLatencyDuringReload =
        resetRuntimeState && !activeChanged && _connected;
    final previousSelectedTag = _selectedProxyTag;
    if (shouldResetRuntimeState) {
      _latencyCoordinator.cancel();
    }

    setState(() {
      ref
          .read(subscriptionCatalogProvider.notifier)
          .replace(
            subscriptions: subscriptions,
            activeProfileId: nextActiveId,
            selectedProxyTag: normalized.selectedProxyTag,
          );
      _lastEmptyAfterDropInvalidWarningSubscriptionId = null;
      if (shouldResetRuntimeState) {
        if (!preserveLatencyDuringReload) {
          _runtimeLatencies.clear();
          _unavailableLatencyTags.clear();
          _invalidatedLatencyTags.clear();
          _latencyErrors.clear();
          _latencyFailureCounts.clear();
        }
        _runtimeGroupSelections.clear();
        _lowestLatency = null;
        _runtimeLowestOutboundTag = null;
        _runtimeLowestSelections.clear();
        _clearLastStartedBuildCache();
      }
      _applyMetadataActiveProfile(
        subscriptions,
        normalized.activeSubscriptionId,
        clearProxyCache:
            (shouldResetRuntimeState && !preserveLatencyDuringReload) ||
            _activeProfileCache == null,
      );
    });
    unawaited(_syncQuickSettingsTileLabel());
    if (_connected) {
      _scheduleActiveOutboundIpRefresh();
    }
    if (subscriptions.isNotEmpty) {
      _scheduleActiveSubscriptionHydration(
        activeSubscriptionId: normalized.activeSubscriptionId,
        selectedProxyTag: normalized.selectedProxyTag,
        preserveRuntimeState:
            !shouldResetRuntimeState || preserveLatencyDuringReload,
        applyRuntime: applyRuntime,
        restartRuntimeOnApply: restartRuntimeOnApply,
        urlTestAfterApply: urlTestAfterApply,
      );
    } else if (applyRuntime) {
      _configCoordinator.emitCurrentConfigLog(
        'subscriptions reloaded',
        restartRuntime: restartRuntimeOnApply,
      );
    } else {
      unawaited(
        _configCoordinator.logCurrentSingboxConfig(
          'subscriptions reloaded (runtime skipped)',
        ),
      );
    }
    if (activeChanged || previousSelectedTag != normalized.selectedProxyTag) {
      _saveStateSoon();
    }
  }

  void _scheduleActiveSubscriptionHydration({
    required String activeSubscriptionId,
    required String selectedProxyTag,
    required bool preserveRuntimeState,
    required bool applyRuntime,
    bool restartRuntimeOnApply = false,
    bool urlTestAfterApply = false,
  }) {
    final generation = _subscriptionCoordinator.beginHydration();
    unawaited(() async {
      final resolved = await _subscriptionCoordinator.resolveSubscriptions(
        activeSubscriptionId: activeSubscriptionId,
        selectedProxyTag: selectedProxyTag,
        preserveRuntimeState: preserveRuntimeState,
        runtimeSnapshot: _currentSubscriptionRuntimeSnapshot(
          preserveRuntimeState: preserveRuntimeState,
        ),
        buildFullProxyList: _fullProxyListCacheRequested,
      );
      if (!mounted ||
          !_subscriptionCoordinator.isHydrationCurrent(generation)) {
        return;
      }
      final normalized = resolved.normalized;
      final activeStillExpected =
          _activeProfileId == activeSubscriptionId ||
          _activeProfileId == normalized.activeSubscriptionId;
      if (!activeStillExpected) {
        return;
      }

      final previousActiveId = _activeProfileId;
      final previousSelectedTag = _selectedProxyTag;
      final activeChanged = normalized.activeSubscriptionId != previousActiveId;
      final shouldResetRuntimeState = activeChanged || !preserveRuntimeState;
      final preserveLatencyDuringReload =
          !preserveRuntimeState && !activeChanged && _connected;
      if (shouldResetRuntimeState) {
        _latencyCoordinator.cancel();
      }
      setState(() {
        ref
            .read(subscriptionCatalogProvider.notifier)
            .replace(
              subscriptions: resolved.subscriptions,
              activeProfileId: normalized.activeSubscriptionId,
              selectedProxyTag: normalized.selectedProxyTag,
            );
        if (shouldResetRuntimeState) {
          if (!preserveLatencyDuringReload) {
            _runtimeLatencies.clear();
            _unavailableLatencyTags.clear();
            _invalidatedLatencyTags.clear();
            _latencyErrors.clear();
            _latencyFailureCounts.clear();
          }
          _runtimeGroupSelections.clear();
          _lowestLatency = null;
          _runtimeLowestOutboundTag = null;
          _runtimeLowestSelections.clear();
        }
        final proxyCache = resolved.proxyCache;
        if (proxyCache != null) {
          _applyProxyCacheBuildResult(proxyCache);
        } else {
          _applyMetadataActiveProfile(
            resolved.subscriptions,
            normalized.activeSubscriptionId,
            clearProxyCache:
                shouldResetRuntimeState && !preserveLatencyDuringReload,
          );
        }
      });
      unawaited(_syncQuickSettingsTileLabel());
      if (_connected) {
        _scheduleActiveOutboundIpRefresh();
      }
      if (applyRuntime) {
        await _configCoordinator.emitCurrentConfigLogAsync(
          'subscriptions reloaded',
          restartRuntime: restartRuntimeOnApply,
        );
        if (urlTestAfterApply && mounted && _connected) {
          _scheduleGroupUrlTest(
            reason: 'subscription_composition_changed',
            delay: const Duration(milliseconds: 2500),
          );
        }
      } else {
        unawaited(
          _configCoordinator.logCurrentSingboxConfig(
            'subscriptions reloaded (runtime skipped)',
          ),
        );
      }
      if (activeChanged || previousSelectedTag != normalized.selectedProxyTag) {
        _saveStateSoon();
      }
    }());
  }

  SubscriptionRuntimeSnapshot _currentSubscriptionRuntimeSnapshot({
    required bool preserveRuntimeState,
  }) {
    if (!preserveRuntimeState) {
      return const SubscriptionRuntimeSnapshot();
    }
    return SubscriptionRuntimeSnapshot(
      lowestLatency: _lowestLatency,
      runtimeLowestOutboundTag: _runtimeLowestOutboundTag,
      runtimeLowestSelections: Map<String, String>.from(
        _runtimeLowestSelections,
      ),
      urlTestInFlight: _urlTestInFlight,
      runtimeLatencies: Map<String, int>.from(_runtimeLatencies),
      unavailableLatencyTags: Set<String>.from(_unavailableLatencyTags),
      latencyErrors: Map<String, String>.from(_latencyErrors),
      runtimeGroupSelections: Map<String, String>.from(_runtimeGroupSelections),
    );
  }

  Future<bool> _ensureActiveSubscriptionHydratedForRuntime() {
    return _subscriptionCoordinator.ensureActiveHydrated(
      _hydrateActiveSubscriptionForUse,
    );
  }

  Future<bool> _hydrateActiveSubscriptionForUse(int generation) async {
    final activeSubscription = _activeSubscription;
    if (activeSubscription == null || activeSubscription.outbounds.isNotEmpty) {
      return true;
    }
    final hydrated = await _subscriptionCoordinator.hydrateActiveSubscription(
      metadata: activeSubscription,
      selectedProxyTag: _selectedProxyTag,
      preferSelectedProxyTag: _selectedProxyTag.trim().isNotEmpty,
      preserveRuntimeState: true,
      runtimeSnapshot: _currentSubscriptionRuntimeSnapshot(
        preserveRuntimeState: true,
      ),
      buildFullProxyList: _fullProxyListCacheRequested,
    );
    if (!mounted || !_subscriptionCoordinator.isHydrationCurrent(generation)) {
      return false;
    }
    if (_activeProfileId != activeSubscription.id) {
      return false;
    }
    setState(() {
      _subscriptions = _replaceSubscription(hydrated.subscription);
      _selectedProxyTag = hydrated.normalized.selectedProxyTag;
      _applyProxyCacheBuildResult(hydrated.proxyCache);
    });
    unawaited(_syncQuickSettingsTileLabel());
    return true;
  }

  Future<void> _showSubscriptionsPage({bool openAddOnStart = false}) async {
    if (_navigatorKey.currentContext == null) return;

    final session = SubscriptionProfilePageSession(
      activeProfileId: _activeProfileId,
      selectedProxyTag: _selectedProxyTag,
      metadataFingerprint: await _subscriptionCoordinator.metadataFingerprint(),
      activeRuntimeFingerprint: await _subscriptionCoordinator
          .runtimeFingerprintFromStore(_activeProfileId),
    );
    final context = _navigatorKey.currentContext;
    if (!mounted || context == null || !context.mounted) return;
    final subscriptionPageResult = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubscriptionsPage(
        activeSubscriptionId: _activeProfileId,
        openAddOnStart: openAddOnStart,
        hapticEnabled: _hapticEnabled,
        allowUntrustedSubscriptionCertificates:
            _allowUntrustedSubscriptionCertificates,
      ),
    );
    final selectedProfileId = subscriptionPageResult is String
        ? subscriptionPageResult
        : null;

    if (mounted) {
      setState(() {});
    }

    final decision = _subscriptionProfileFlow.decide(
      session: session,
      selectedProfileId: selectedProfileId,
      afterMetadataFingerprint: await _subscriptionCoordinator
          .metadataFingerprint(),
      afterActiveRuntimeFingerprint: await _subscriptionCoordinator
          .runtimeFingerprintFromStore(_activeProfileId),
      runtimeActiveOrRequested: _runtimeActiveOrRequested,
      connected: _connected,
    );
    if (!decision.shouldReload) {
      AppLogStore.info(
        'subscription',
        'subscriptions page closed without changes; runtime reload skipped',
      );
      return;
    }

    if (decision.isProfileSwitch) {
      _haptic();
      await _proxySelection.waitForPersistence();
      if (!mounted) {
        return;
      }
      AppLogStore.info(
        'subscription',
        'profile switch requested from=$_activeProfileId '
            'to=${decision.reloadPlan!.preferredSubscriptionId} '
            'running=$_runtimeActiveOrRequested',
      );
      if (decision.shouldStopRuntime) {
        final stopped = await _stopRuntime(
          reason: 'profile_switch',
          allowQueuedRestart: false,
        );
        if (!mounted || !stopped) {
          return;
        }
      }
    }

    final reloadPlan = decision.reloadPlan!;
    await _reloadSubscriptions(
      preferredSubscriptionId: reloadPlan.preferredSubscriptionId,
      preferredProxyTag: reloadPlan.preferredProxyTag,
      applyRuntime: reloadPlan.applyRuntime,
      resetRuntimeState: reloadPlan.resetRuntimeState,
      restartRuntimeOnApply: reloadPlan.restartRuntimeOnApply,
      urlTestAfterApply: reloadPlan.urlTestAfterApply,
    );
  }

  Future<void> _showSettingsPage() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute<void>(builder: _buildSettingsPresentation),
    );
  }

  SettingsPage _buildSettingsPresentation(BuildContext context) {
    return SettingsPresentationBuilder(
      data: SettingsPresentationData(
        localeCode: _locale?.languageCode ?? 'system',
        themePreference: _themePreference,
      ),
      callbacks: SettingsPresentationCallbacks(
        openGeneral: _showGeneralSettingsPage,
        openDns: _showDnsSettingsPage,
        openSubscriptions: _showSubscriptionsSettingsPage,
        openInbound: _showInboundSettingsPage,
        openRouting: _showRoutingSettingsPage,
        openSecurity: _showSecuritySettingsPage,
        importBackup: () => unawaited(
          _runSettingsBackupAction(SettingsBackupAction.importFile),
        ),
        exportSettings: () => unawaited(
          _runSettingsBackupAction(SettingsBackupAction.exportSettings),
        ),
        exportEncryptedProfile: () => unawaited(
          _runSettingsBackupAction(SettingsBackupAction.exportEncryptedProfile),
        ),
        exportPlainProfile: () => unawaited(
          _runSettingsBackupAction(SettingsBackupAction.exportPlainProfile),
        ),
        resetSettings: () => unawaited(_resetSettingsToDefaults()),
        openExperimental: _showExperimentalSettingsPage,
        openLogs: _showLogsPage,
        openAbout: _showAboutSettingsPage,
      ),
    ).build(context);
  }

  Future<List<Map<String, dynamic>>> _warmInstalledApps() {
    final inFlight = _installedAppsWarmupFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final generation = _installedAppsCacheGeneration;
    final future = _singboxRuntime
        .getInstalledApps()
        .then((items) {
          if (generation == _installedAppsCacheGeneration) {
            _installedAppsCache = items;
          }
          _installedAppsWarmupFuture = null;
          return items;
        })
        .catchError((error) {
          _installedAppsWarmupFuture = null;
          throw error;
        });
    _installedAppsWarmupFuture = future;
    return future;
  }

  void _clearInstalledAppsCache() {
    _installedAppsCacheGeneration++;
    _installedAppsWarmupFuture = null;
    _installedAppsCache = const <Map<String, dynamic>>[];
    clearInstalledAppIconCache();
  }

  void _trimRuntimeStartMemory(String reason) {
    final cache = PaintingBinding.instance.imageCache;
    final imageBytesBefore = cache.currentSizeBytes;
    final imageEntriesBefore = cache.currentSize;

    // Installed-app metadata and the bounded icon cache are reused by split
    // routing. Clearing them every time a VPN runtime starts made every visit
    // to routing re-query PackageManager and re-decode icons on the UI path.
    // Keep that small bounded cache; actual Android memory pressure still
    // clears it through _runMemoryPressureCleanup.
    cache.clear();
    cache.clearLiveImages();
    _configureImageCacheForAndroid();

    if (imageBytesBefore > 0 || imageEntriesBefore > 0) {
      AppLogStore.info(
        'memory cleanup',
        'reason=$reason imageBytesBefore=$imageBytesBefore '
            'imageEntriesBefore=$imageEntriesBefore '
            'installedAppsRetained=${_installedAppsCache.length}',
      );
    }
  }

  Future<void> _showGeneralSettingsPage() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsGeneralPage(
          currentLocaleCode: _locale?.languageCode ?? 'system',
          currentThemePreference: _themePreference,
          currentAccentColorHex: _accentColorHex,
          dynamicLightScheme: _dynamicLightScheme,
          onLocaleChanged: _setLocale,
          onThemePreferenceChanged: _setThemePreference,
          currentHapticEnabled: _hapticEnabled,
          currentStatusNotificationEnabled: _statusNotificationEnabled,
          currentNotificationTrafficDisplayMode:
              _notificationTrafficDisplayMode,
          currentNotificationTrafficRefreshSeconds:
              _notificationTrafficRefreshSeconds,
          currentHideServerIp: _hideServerIp,
          onAccentColorChanged: _setAccentColor,
          onHapticChanged: _setHapticEnabled,
          onStatusNotificationChanged: _setStatusNotificationEnabled,
          onNotificationTrafficDisplayModeChanged:
              _setNotificationTrafficDisplayMode,
          onNotificationTrafficRefreshSecondsChanged:
              _setNotificationTrafficRefreshSeconds,
          onHideServerIpChanged: _setHideServerIp,
        ),
      ),
    );
  }

  Future<void> _showInboundSettingsPage() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsInboundPage(
          currentVpnInboundEnabled: _vpnInboundEnabled,
          currentVpnMtu: _vpnMtu,
          currentVpnStrictRoute: _vpnStrictRoute,
          currentVpnTunImplementation: _vpnTunImplementation,
          currentProxyInboundEnabled: _proxyInboundEnabled,
          currentProxyAllowLan: _proxyAllowLan,
          currentProxyMixedListen: _proxyMixedListen,
          currentProxyMixedPort: _proxyMixedPort,
          currentProxyUsername: _proxyUsername,
          currentProxyPassword: _proxyPassword,
          onVpnMtuChanged: _setVpnMtu,
          onVpnStrictRouteChanged: _setVpnStrictRoute,
          onVpnTunImplementationChanged: _setVpnTunImplementation,
          onProxyInboundEnabledChanged: _setProxyInboundEnabled,
          onProxyAllowLanChanged: _setProxyAllowLan,
          onProxyMixedPortChanged: _setProxyMixedPort,
          onConnectionModeChanged: _setInboundConnectionMode,
          onProxyUsernameChanged: _setProxyUsername,
          onProxyPasswordChanged: _setProxyPassword,
        ),
      ),
    );
  }

  Future<void> _showDnsSettingsPage() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsDnsPage(
          currentDirectPreset: _dnsDirectPreset,
          currentDirectResolver: _dnsDirectResolver,
          currentProxyPreset: _dnsProxyPreset,
          currentProxyResolver: _dnsProxyResolver,
          currentPreferIpv6: _dnsPreferIpv6,
          onDirectPresetChanged: _setDnsDirectPreset,
          onDirectResolverChanged: _setDnsDirectResolver,
          onProxyPresetChanged: _setDnsProxyPreset,
          onProxyResolverChanged: _setDnsProxyResolver,
          onPreferIpv6Changed: _setDnsPreferIpv6,
        ),
      ),
    );
  }

  Future<void> _runSettingsBackupAction(SettingsBackupAction action) async {
    if (_settingsBackupOperationInFlight) return;
    final navigator = _navigatorKey.currentState;
    final store = _store;
    if (navigator == null || store == null) return;
    _settingsBackupOperationInFlight = true;
    try {
      await _refreshAppVersionInfo();
      if (!mounted) return;
      final actions = SettingsBackupActions(
        store: store,
        settingsState: _currentSettingsState(),
        clientVersion: _clientVersionLabel,
        loadSubscriptions: SubscriptionStore.getAllInBackground,
        onImportSettings: _applyImportedSettingsState,
        onImportSubscriptions: _importBackupSubscriptions,
      );
      await actions.run(navigator.context, action);
    } finally {
      _settingsBackupOperationInFlight = false;
    }
  }

  Future<void> _resetSettingsToDefaults() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final defaults = AppSettingsController().toState(
      onboardingCompleted: _onboardingCompleted,
      acceptedLegalVersion: _acceptedLegalVersion,
      acceptedLegalAtMillis: _acceptedLegalAtMillis,
      activeProfileId: _activeProfileId,
      selectedProxyTag: _selectedProxyTag,
    );
    await _applySettingsState(
      defaults,
      configReason: 'settings reset to defaults',
    );
    if (!mounted) return;
    AppNotice.show(
      navigator.context,
      AppLocalizations.of(navigator.context).settingsResetSuccess,
      tone: AppNoticeTone.success,
    );
  }

  Future<void> _showUpdateSettingsPage() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await _refreshAppVersionInfo();
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsUpdatePage(
          currentVersion: _clientVersionLabel,
          installMode: _updateInstallMode,
          updateChannel: _updateChannel,
          onInstallModeChanged: _setUpdateInstallMode,
          onUpdateChannelChanged: _setUpdateChannel,
        ),
      ),
    );
  }

  Future<void> _showChangelogSheet() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await showModalBottomSheet<void>(
      context: navigator.context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChangelogSheet(
        currentVersion: _clientVersionLabel,
        currentBuildNumber: _clientVersionCode,
        updateChannel: _updateChannel,
      ),
    );
  }

  Future<void> _showSubscriptionsSettingsPage() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsSubscriptionsPage(
          currentConfig: UrlTestConfig(
            url: _urlTestUrl,
            intervalSeconds: _urlTestIntervalSeconds,
            timeoutSeconds: _urlTestTimeoutSeconds,
            concurrency: _urlTestConcurrency,
            unavailableCheckIntervalSeconds:
                _urlTestUnavailableCheckIntervalSeconds,
          ),
          currentLocationLookupLimit: _locationLookupLimit,
          currentLocationLookupTimeoutSeconds: _locationLookupTimeoutSeconds,
          currentLocationLookupConcurrency: _locationLookupConcurrency,
          onChanged: (value) async {
            _setUrlTestUrl(value.url ?? '');
            _setUrlTestIntervalSeconds(value.intervalSeconds ?? 180);
            _setUrlTestTimeoutSeconds(value.timeoutSeconds ?? 15);
            _setUrlTestConcurrency(value.concurrency ?? 30);
            _setUrlTestUnavailableCheckIntervalSeconds(
              value.unavailableCheckIntervalSeconds ?? 5,
            );
          },
          onLocationLookupLimitChanged: _setLocationLookupLimit,
          onLocationLookupTimeoutSecondsChanged:
              _setLocationLookupTimeoutSeconds,
          onLocationLookupConcurrencyChanged: _setLocationLookupConcurrency,
        ),
      ),
    );
  }

  Future<void> _showAboutSettingsPage() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await _refreshAppVersionInfo();
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsAboutPage(
          versionLabel: _clientVersionLabel,
          onShowOnboarding: _resetOnboarding,
          updateInstallMode: _updateInstallMode,
          updateChannel: _updateChannel,
          onUpdateInstallModeChanged: _setUpdateInstallMode,
          onUpdateChannelChanged: _setUpdateChannel,
          readCoreIntegrationDiagnostics: _readCoreIntegrationDiagnostics,
        ),
      ),
    );
  }

  CoreIntegrationDiagnosticsSnapshot _readCoreIntegrationDiagnostics() {
    final result = _configCoordinator.lastApplyResult;
    return CoreIntegrationDiagnosticsSnapshot(
      applyStatus: result.status.name,
      applyReason: result.reason,
      applyError: result.error,
      configGeneration: result.generation,
      configRuntimeGeneration: result.runtimeGeneration,
      configSchemaVersion: currentCoreConfigSchemaVersion,
      settingsApplyPending:
          _pendingSettingsConfigApplyGeneration != 0 ||
          (_settingsConfigApplyTimer?.isActive ?? false),
      lastApplyAtMillis: _configCoordinator.lastApplyAtMillis,
    );
  }

  void _setBlockLeaks(bool value) {
    _applySettingsChange(() => _settings.setBlockLeaks(value));
  }

  void _setAdBlockEnabled(bool value) {
    _applySettingsChange(() => _settings.setAdBlockEnabled(value));
  }

  Future<AdBlockRuleSetStatus> _downloadAdBlockRuleSet() async {
    final affectsActiveRuntime = _adBlockEnabled;
    final status = await AdBlockRuleSetService.instance.downloadLatest();
    if (!mounted) {
      return status;
    }
    setState(() {
      _adBlockStatus = status;
    });
    if (affectsActiveRuntime) {
      await _configCoordinator.emitCurrentConfigLogAsync(
        'adblock rule-set updated',
        restartRuntime: true,
        applyWhenNativeRunning: true,
        forceFullServiceRestart: true,
      );
    }
    return status;
  }

  Future<AdBlockRuleSetStatus> _deleteAdBlockRuleSet() async {
    final affectsActiveRuntime = _adBlockEnabled;
    final status = await AdBlockRuleSetService.instance.deleteRuleSet();
    if (!mounted) {
      return status;
    }
    setState(() {
      _adBlockStatus = status;
      if (!status.available) {
        _adBlockEnabled = false;
      }
    });
    if (affectsActiveRuntime) {
      await _configCoordinator.emitCurrentConfigLogAsync(
        'adblock rule-set deleted',
        restartRuntime: true,
        applyWhenNativeRunning: true,
        forceFullServiceRestart: true,
      );
    }
    _saveStateSoon();
    return status;
  }

  void _setTrafficRulePreset(TrafficRulePreset value) {
    _applySettingsChange(() => _settings.setTrafficRulePreset(value));
  }

  Future<RussiaRouteDataStatus> _installRussiaRouteData() async {
    final affectsActiveRuntime = _trafficRulePreset != TrafficRulePreset.none;
    final hadInstalledData = _russiaRouteDataStatus.available;
    final status = hadInstalledData
        ? await _russiaRouteDataService.ensureUpdated(force: true)
        : await _russiaRouteDataService.ensureBundledInstalled();
    if (!mounted) {
      return status;
    }
    setState(() {
      _russiaRouteDataStatus = status;
    });
    if (affectsActiveRuntime) {
      await _configCoordinator.emitCurrentConfigLogAsync(
        'russia route data prepared',
        restartRuntime: true,
        applyWhenNativeRunning: true,
        forceFullServiceRestart: true,
      );
    }
    return status;
  }

  Future<RussiaRouteDataStatus> _prepareTrafficRuleData(
    TrafficRulePreset preset,
  ) async {
    final affectsActiveRuntime =
        _trafficRulePreset != TrafficRulePreset.none &&
        (preset == TrafficRulePreset.none || preset == _trafficRulePreset);
    var status = _russiaRouteDataStatus;
    final hadPreparedData = status.available;
    if (!status.available) {
      status = await _russiaRouteDataService.ensureBundledInstalled();
    }
    if (preset == TrafficRulePreset.aiViaVpn ||
        preset == TrafficRulePreset.socialViaVpn ||
        hadPreparedData) {
      status = await _russiaRouteDataService.ensureUpdated(force: true);
    }
    if (!mounted) {
      return status;
    }
    setState(() => _russiaRouteDataStatus = status);
    if (affectsActiveRuntime) {
      await _configCoordinator.emitCurrentConfigLogAsync(
        'traffic rule data prepared',
        restartRuntime: true,
        applyWhenNativeRunning: true,
        forceFullServiceRestart: true,
      );
    }
    return status;
  }

  void _setBypassLocalNetwork(bool value) {
    _applySettingsChange(() => _settings.setBypassLocalNetwork(value));
  }

  void _setSplitRoutingMode(SplitRoutingMode value) {
    if (_splitRoutingTemporarilyDisabled) {
      _applySettingsChange(
        () => _settings.setSplitRoutingMode(SplitRoutingMode.disabled),
      );
      return;
    }
    _applySettingsChange(() => _settings.setSplitRoutingMode(value));
  }

  void _setSplitRoutingPackages(List<String> value) {
    if (_splitRoutingTemporarilyDisabled) {
      _applySettingsChange(
        () => _settings.setSplitRoutingPackages(const <String>[]),
      );
      return;
    }
    _applySettingsChange(() => _settings.setSplitRoutingPackages(value));
  }

  void _setSingBoxLogLevel(String value) {
    var changed = false;
    _applySettingsChange(() {
      final change = _settings.setSingBoxLogLevel(value);
      changed = change.changed;
      return change;
    });
    if (changed) {
      unawaited(_applySingBoxLogLevelChange());
    }
  }

  bool _shouldRecordSingBoxLog(String level) {
    final normalized = level.trim().toLowerCase();
    const priorities = <String, int>{
      'trace': 0,
      'debug': 1,
      'info': 2,
      'warn': 3,
      'warning': 3,
      'error': 4,
    };
    final current = priorities[_singBoxLogLevel] ?? 2;
    final incoming = priorities[normalized] ?? 2;
    return incoming >= current;
  }

  Future<void> _applySingBoxLogLevelChange() async {
    await _persistState();
    await _configCoordinator.emitCurrentConfigLogAsync(
      'sing-box log level changed',
      restartRuntime: true,
      applyWhenNativeRunning: true,
    );
  }

  void _setExperimentalTcpFastOpen(bool value) {
    _applySettingsChange(() => _settings.setExperimentalTcpFastOpen(value));
  }

  void _setExperimentalTcpMultiPath(bool value) {
    _applySettingsChange(() => _settings.setExperimentalTcpMultiPath(value));
  }

  void _setExperimentalInterruptExistingConnections(bool value) {
    _applySettingsChange(
      () => _settings.setExperimentalInterruptExistingConnections(value),
    );
  }

  void _setExperimentalUrlTestStrictTolerance(bool value) {
    _applySettingsChange(
      () => _settings.setExperimentalUrlTestStrictTolerance(value),
    );
  }

  void _setExperimentalFakeIpEnabled(bool value) {
    _applySettingsChange(() => _settings.setExperimentalFakeIpEnabled(value));
  }

  void _setTlsFragmentationMode(TlsFragmentationMode value) {
    _applySettingsChange(() => _settings.setTlsFragmentationMode(value));
  }

  Future<void> _showRoutingSettingsPage() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    unawaited(() async {
      try {
        await _warmInstalledApps();
      } catch (error) {
        AppLogStore.warning('split routing', 'app list preload failed: $error');
      }
    }());
    try {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (context) => SettingsRoutingPage(
            currentBlockLeaks: _blockLeaks,
            currentAdBlockEnabled: _adBlockEnabled,
            currentAdBlockStatus: _adBlockStatus,
            currentRussiaRouteDataStatus: _russiaRouteDataStatus,
            currentTrafficRulePreset: _trafficRulePreset,
            currentRussiaDnsDirectResolver: _russiaDnsDirectResolver,
            currentBypassLocalNetwork: _bypassLocalNetwork,
            currentVpnInboundEnabled: _vpnInboundEnabled,
            currentSplitRoutingMode: _splitRoutingMode,
            currentSplitRoutingPackages: _splitRoutingPackages,
            initialInstalledApps: _installedAppsCache,
            preloadInstalledApps: _warmInstalledApps,
            onBlockLeaksChanged: _setBlockLeaks,
            onAdBlockEnabledChanged: _setAdBlockEnabled,
            onDownloadAdBlockRuleSet: _downloadAdBlockRuleSet,
            onDeleteAdBlockRuleSet: _deleteAdBlockRuleSet,
            onRefreshRoutingRuleData: _installRussiaRouteData,
            onTrafficRulePresetChanged: _setTrafficRulePreset,
            onRussiaDnsDirectResolverChanged: _setRussiaDnsDirectResolver,
            onPrepareTrafficRuleData: _prepareTrafficRuleData,
            onBypassLocalNetworkChanged: _setBypassLocalNetwork,
            onSplitRoutingModeChanged: _setSplitRoutingMode,
            onSplitRoutingPackagesChanged: _setSplitRoutingPackages,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _proxyPanelResetGeneration++);
      }
    }
  }

  Future<void> _showExperimentalSettingsPage() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsExperimentalPage(
          currentTcpFastOpen: _experimentalTcpFastOpen,
          currentTcpMultiPath: _experimentalTcpMultiPath,
          currentInterruptExistingConnections:
              _experimentalInterruptExistingConnections,
          currentUrlTestStrictTolerance: _experimentalUrlTestStrictTolerance,
          currentFakeIpEnabled: _experimentalFakeIpEnabled,
          fakeIpAvailable:
              _vpnInboundEnabled &&
              _splitRoutingMode == SplitRoutingMode.disabled,
          currentTlsFragmentationMode: _tlsFragmentationMode,
          currentMemoryLimitEnabled: _memoryLimitEnabled,
          currentMemoryLimitWarningDismissed: _memoryLimitWarningDismissed,
          onTcpFastOpenChanged: _setExperimentalTcpFastOpen,
          onTcpMultiPathChanged: _setExperimentalTcpMultiPath,
          onInterruptExistingConnectionsChanged:
              _setExperimentalInterruptExistingConnections,
          onUrlTestStrictToleranceChanged:
              _setExperimentalUrlTestStrictTolerance,
          onFakeIpEnabledChanged: _setExperimentalFakeIpEnabled,
          onTlsFragmentationModeChanged: _setTlsFragmentationMode,
          onMemoryLimitChanged: _setMemoryLimitEnabled,
        ),
      ),
    );
  }

  Future<void> _showSecuritySettingsPage() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsSecurityPage(
          allowUntrustedProxyCertificates: _allowUntrustedProxyCertificates,
          allowUntrustedSubscriptionCertificates:
              _allowUntrustedSubscriptionCertificates,
          onAllowUntrustedProxyCertificatesChanged:
              _setAllowUntrustedProxyCertificates,
          onAllowUntrustedSubscriptionCertificatesChanged:
              _setAllowUntrustedSubscriptionCertificates,
        ),
      ),
    );
  }

  Future<void> _showLogsPage() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsLogsPage(
          currentSingBoxLogLevel: _singBoxLogLevel,
          onSingBoxLogLevelChanged: _setSingBoxLogLevel,
        ),
      ),
    );
  }

  Future<void> _runUrlTest({bool haptic = true}) async {
    if (!_connected || !_foregroundLifecycleActive) {
      return;
    }
    if (_urlTestInFlight) {
      AppLogStore.debug(
        'latency',
        'full URLTest skipped: native session is still producing results',
      );
      return;
    }
    if (haptic) {
      _haptic();
    }
    await _latencyCoordinator.runFull(reason: 'manual');
  }

  Future<void> _runActiveProxyUrlTest({bool haptic = true}) async {
    if (!_connected || !_foregroundLifecycleActive) {
      return;
    }
    if (_urlTestInFlight) {
      AppLogStore.debug(
        'latency',
        'targeted URLTest skipped: native session is still producing results',
      );
      return;
    }
    final targetTag = _currentResolvedActiveOutboundTag()?.trim() ?? '';
    if (targetTag.isEmpty) {
      AppLogStore.warning(
        'latency',
        'targeted URLTest skipped: active outbound is unresolved',
      );
      return;
    }
    if (haptic) {
      _haptic();
    }
    if (!_latencyCoordinator.capabilities.supportsTargetedUrlTest) {
      await _latencyCoordinator.runFull(reason: 'manual_active_fallback');
      return;
    }
    await _latencyCoordinator.runTarget(
      targetOutboundTag: targetTag,
      reason: 'manual_active',
    );
  }

  Future<void> _handleRuntimeLifecycleTimeout(
    RuntimeLifecycleResult result,
  ) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _setConnectionPhase(AppConnectionPhase.failed);
    });
    _showAppSnackBar(_vpnStartTimedOutMessage);
  }

  Future<void> _startRuntimeWithBuild(
    SingboxConfigBuildResult build, {
    required bool useVpn,
    int? manualStartGeneration,
    int? automaticRecoveryGeneration,
  }) async {
    final result = await _configCoordinator.startRuntimeWithBuild(
      build,
      useVpn: useVpn,
    );
    if (!mounted) {
      return;
    }
    final manualStartCancelled =
        manualStartGeneration != null &&
        !_manualRuntimeStartCurrent(manualStartGeneration);
    final automaticRecoveryCancelled =
        automaticRecoveryGeneration != null &&
        !_automaticRuntimeRecoveryCurrent(automaticRecoveryGeneration);
    final disposition = _runtimeSession.classifyStartResult(
      result: result,
      manualStartCancelled: manualStartCancelled,
      automaticRecoveryCancelled: automaticRecoveryCancelled,
      runtimeDesiredByUser: _runtimeDesiredByUser,
    );
    if (disposition == RuntimeStartDisposition.cancelledNeedsCleanup) {
      try {
        await _singboxRuntime
            .stop(reason: 'cancelled_runtime_start_completed')
            .timeout(const Duration(seconds: 7));
      } catch (error, stackTrace) {
        AppLogStore.error(
          'sing-box',
          'late cancelled start cleanup failed: $error\n$stackTrace',
        );
      }
      return;
    }
    if (disposition == RuntimeStartDisposition.cancelled) {
      return;
    }
    if (disposition == RuntimeStartDisposition.success) {
      await _reassertPendingRuntimeProxySelectionAfterStart();
      return;
    }
    if (disposition == RuntimeStartDisposition.failed) {
      _clearRuntimeProxySelectionGuard();
      _runtimeIntent.clearRuntimeDesired();
      setState(() {
        _setConnectionPhase(AppConnectionPhase.failed);
      });
      _showAppSnackBar(
        result.timedOut ? _vpnStartTimedOutMessage : _vpnStartFailedMessage,
      );
    }
  }

  void _setConfigCoordinatorPhase(SingboxConfigCoordinatorPhase phase) {
    if (!mounted) {
      return;
    }
    if (phase == SingboxConfigCoordinatorPhase.reconfiguring ||
        phase == SingboxConfigCoordinatorPhase.stopping) {
      _latencyCoordinator.cancel();
      _activeProxyIpController.cancelPending();
      _groupUrlTestScheduler.cancel();
    }
    setState(() {
      _setConnectionPhase(switch (phase) {
        SingboxConfigCoordinatorPhase.reconfiguring =>
          AppConnectionPhase.reconfiguring,
        SingboxConfigCoordinatorPhase.stopping => AppConnectionPhase.stopping,
        SingboxConfigCoordinatorPhase.connected => AppConnectionPhase.connected,
        SingboxConfigCoordinatorPhase.failed => AppConnectionPhase.failed,
      });
    });
  }

  void _showRuntimeConfigFailure({required bool timedOut}) {
    _showAppSnackBar(
      timedOut ? _vpnStartTimedOutMessage : _vpnStartFailedMessage,
    );
  }

  int _beginLocalProxySelection() {
    final hadPending = _proxySelection.hasPendingRuntimeSelection;
    final generation = _proxySelection.beginLocalSelection();
    if (hadPending) {
      _publishProxyRuntimeVisualStates();
    }
    return generation;
  }

  int _beginRuntimeProxySelectionGuard(String tag, String previousTag) {
    final generation = _proxySelection.beginRuntimeSelection(
      tag: tag,
      previousTag: previousTag,
      onTimeout: _handleRuntimeProxySelectionTimeout,
    );
    _publishProxyRuntimeVisualStates();
    return generation;
  }

  void _handleRuntimeProxySelectionTimeout(ProxySelectionTimeout timeout) {
    if (!mounted || !_proxySelection.isCurrentGeneration(timeout.generation)) {
      return;
    }
    AppLogStore.warning(
      'proxy',
      'runtime did not confirm selected outbound tag=${timeout.tag} '
          'previous=${timeout.previousTag ?? '<none>'}; restart suppressed',
    );
    _clearRuntimeProxySelectionGuard(generation: timeout.generation);
    // A start guard uses the same value for tag and previousTag. Its job is to
    // ignore a stale selector snapshot while the core starts; it is not a user
    // switch and therefore must not surface a misleading failure snackbar.
    if (timeout.previousTag != timeout.tag) {
      _showAppSnackBar('Proxy switch was not confirmed. Try again.');
    }
  }

  Future<void> _reassertPendingRuntimeProxySelectionAfterStart() async {
    final tag = _proxySelection.pendingRuntimeSelectTag?.trim() ?? '';
    if (tag.isEmpty) {
      return;
    }
    final generation = _proxySelection.generation;
    AppLogStore.info(
      'proxy',
      'reasserting selected outbound after runtime start tag=$tag',
    );
    final result = await _runtimeCommands.selectOutbound(tag);
    if (!mounted ||
        !_proxySelection.isCurrentGeneration(generation) ||
        _proxySelection.pendingRuntimeSelectTag != tag ||
        result.status == RuntimeSelectionStatus.stale) {
      return;
    }
    if (!result.applied) {
      AppLogStore.warning(
        'proxy',
        'failed to reassert selected outbound after runtime start tag=$tag '
            'error=${result.error}',
      );
      return;
    }
    AppLogStore.info(
      'libbox call',
      'post-start selectOutbound done group=select outbound=$tag '
          'elapsedMs=${result.elapsed.inMilliseconds}',
    );
    _clearRuntimeProxySelectionGuard(generation: generation);
  }

  void _clearRuntimeProxySelectionGuard({int? generation}) {
    if (_proxySelection.clearRuntimeSelection(generation: generation)) {
      _publishProxyRuntimeVisualStates();
    }
  }

  Future<void> _persistSelectedProxyConfigSnapshot({
    required String reason,
    required int generation,
  }) async {
    if (!mounted || !_proxySelection.isCurrentGeneration(generation)) {
      return;
    }
    try {
      final build = await _configCoordinator
          .buildCurrentSingboxConfigInBackground(returnConfig: false);
      if (build == null ||
          !mounted ||
          !_proxySelection.isCurrentGeneration(generation)) {
        if (build != null) {
          _configCoordinator.discardPreparedConfigCandidate(build);
        }
        return;
      }
      await _configCoordinator.promotePreparedConfigBuild(build);
      _cacheLastStartedBuild(build);
      _configCoordinator.recordBuiltConfigLog(reason, build);
    } catch (error) {
      AppLogStore.warning(
        'proxy',
        'Failed to persist selected proxy config snapshot: $error',
      );
    }
  }

  void _cacheLastStartedBuild(SingboxConfigBuildResult build) {
    _runtimeRecovery.cacheStartedBuild(build);
    final migration = _pendingCoreConfigMigration;
    if (migration != null) {
      _settings.coreConfigSchemaVersion =
          migration.state.coreConfigSchemaVersion;
      _pendingCoreConfigMigration = null;
      _saveStateSoon();
      AppLogStore.info(
        'sing-box',
        'core config migration committed '
            'schema=${migration.state.coreConfigSchemaVersion}',
      );
    }
  }

  void _clearLastStartedBuildCache() {
    _runtimeRecovery.clearBuildCache();
  }

  SingboxConfigCoordinatorSnapshot _currentSingboxConfigSnapshot() {
    final routeData = _russiaRouteDataStatus;
    return SingboxConfigCoordinatorSnapshot(
      connected: _connected,
      runtimeTransitionInProgress: _runtimeTransitionInProgress,
      activeSubscription: _activeSubscription,
      selectedProxyTag: _selectedProxyTag,
      excludedOutboundTags: _excludedRuntimeOutboundTags,
      vpnInboundEnabled: _vpnInboundEnabled,
      vpnMtu: _vpnMtu,
      vpnStrictRoute: _vpnStrictRoute,
      vpnTunImplementation: _vpnTunImplementation,
      proxyInboundEnabled: _proxyInboundEnabled,
      proxyMixedListen: _proxyMixedListen,
      proxyMixedPort: _proxyMixedPort,
      proxyUsername: _proxyUsername,
      proxyPassword: _proxyPassword,
      dnsDirectResolver: _dnsDirectResolver,
      dnsProxyResolver: _dnsProxyResolver,
      dnsPreferIpv6: _dnsPreferIpv6,
      russiaDnsDirectResolver: _russiaDnsDirectResolver,
      urlTestUrl: _urlTestUrl,
      urlTestIntervalSeconds: _urlTestIntervalSeconds,
      urlTestTimeoutSeconds: _urlTestTimeoutSeconds,
      urlTestConcurrency: _urlTestConcurrency,
      urlTestUnavailableCheckIntervalSeconds:
          _urlTestUnavailableCheckIntervalSeconds,
      blockLeaks: _blockLeaks,
      adBlockEnabled: _adBlockEnabled,
      adBlockBlockRuleSetPath: _adBlockStatus.blockRuleSetPath,
      adBlockAllowRuleSetPath: _adBlockStatus.allowRuleSetPath,
      useRussiaRouteData: _useRussiaRouteData,
      routeDataAvailable: routeData.available,
      routeDataSourceKind: routeData.sourceKind,
      routeDataRelease: routeData.releaseTag ?? routeData.versionTag,
      russiaGeositeRuBlockedPath: routeData.geositeRuBlockedPath,
      russiaGeositeRuAvailableOnlyInsidePath:
          routeData.geositeRuAvailableOnlyInsidePath,
      russiaGeositeCategoryRuPath: routeData.geositeCategoryRuPath,
      russiaGeoipRuBlockedPath: routeData.geoipRuBlockedPath,
      russiaGeoipRuWhitelistPath: routeData.geoipRuWhitelistPath,
      russiaGeoipRuPath: routeData.geoipRuPath,
      russiaCuratedDirectServicesPath: routeData.curatedDirectServicesPath,
      russiaAiServicesPath: routeData.aiServicesPath,
      russiaSocialServicesPath: routeData.socialServicesPath,
      trafficRulePreset: _trafficRulePreset,
      bypassLocalNetwork: _bypassLocalNetwork,
      splitRoutingMode: _splitRoutingMode,
      splitRoutingPackages: _splitRoutingPackages,
      logLevel: _singBoxLogLevel,
      tcpFastOpenEnabled: _experimentalTcpFastOpen,
      tcpMultiPathEnabled: _experimentalTcpMultiPath,
      tlsFragmentationMode: _tlsFragmentationMode,
      allowUntrustedProxyCertificates: _allowUntrustedProxyCertificates,
      interruptExistingConnections: _experimentalInterruptExistingConnections,
      urlTestStrictTolerance: _experimentalUrlTestStrictTolerance,
      experimentalFakeIpEnabled: _experimentalFakeIpEnabled,
      markAllServersRussia: _activeSubscription?.markAllServersRussia ?? false,
      capabilities: _latencyCoordinator.capabilities,
    );
  }

  void _startSingboxEvents() {
    _runtimeEvents.start();
    if (_foregroundLifecycleActive) {
      // A foreground VPN service can outlive the Flutter engine after the task
      // is swiped away. Explicitly reattach the new engine even though its
      // initial lifecycle state is already `resumed` and therefore produces no
      // didChangeAppLifecycleState callback.
      unawaited(_syncRuntimeUiForeground(true));
      _scheduleVpnNotificationSync();
    }
    unawaited(_syncRuntimeState());
  }

  void _handleRuntimeStateEvent(RuntimeStateEvent event) {
    final running = event.running;
    final nativeRuntimeGeneration =
        (event.raw['runtimeGeneration'] as num?)?.toInt() ?? 0;
    _runtimeOperations.updateRuntimeState(
      running: running,
      nativeRuntimeGeneration: nativeRuntimeGeneration,
    );
    final error = event.error;
    final hasError = event.hasError;
    final wasRetryScheduled = _invalidOutboundRetryScheduled;
    final decision = _runtimeSession.decideStateEvent(
      running: running,
      hasError: hasError,
      transitionInProgress: _runtimeTransitionInProgress,
      retryScheduled: _invalidOutboundRetryScheduled,
      starting: _starting,
      stopping:
          _runtimeIntent.explicitStopInProgress ||
          _connectionPhase == AppConnectionPhase.stopping,
    );
    if (!mounted) return;
    var shouldSyncQuickSettingsTile = false;
    var shouldCancelLatency = false;
    setState(() {
      if (running) {
        _runtimeIntent.restoreDesiredFromObservedRuntime();
        _lastLocationLookupSignature = '';
      }
      _setConnectionPhase(
        decision.phase,
        retryScheduled: decision.retryScheduled,
      );
      if (decision.clearDisconnectedState) {
        shouldCancelLatency = true;
        shouldSyncQuickSettingsTile = true;
        _resetActiveProxyIpState();
        _locationLookupGeneration++;
        _locationLookupTimer?.cancel();
        _locationLookupInFlight = false;
        _locationLookupRefreshRequested = false;
        _cancelQueuedLocationLookups();
        _resetTrafficDashboardData();
        _lowestLatency = null;
        _runtimeLowestOutboundTag = null;
        _runtimeLowestSelections.clear();
        _runtimeLatencies.clear();
        _unavailableLatencyTags.clear();
        _invalidatedLatencyTags.clear();
        _latencyErrors.clear();
        _latencyFailureCounts.clear();
        _groupUrlTestScheduler.cancel();
        _networkRecovery.cancelDecision();
        _applyRuntimeStateToDerivedCaches();
      }
    });
    if (shouldCancelLatency) {
      _latencyCoordinator.cancel();
    }
    _publishTrafficDashboardSnapshot();
    if (shouldSyncQuickSettingsTile) {
      unawaited(_syncQuickSettingsTileLabel());
    }
    _scheduleVpnNotificationSync();
    if (hasError) {
      unawaited(_handleRuntimeError(error ?? '', wasRetryScheduled));
    } else if (running) {
      unawaited(_requestNotificationPermissionIfNeeded());
      unawaited(_refreshRuntimeDiagnosticsNetworkState());
      _scheduleActiveOutboundIpRefresh();
    }
  }

  void _handleTrafficStatusEvent(Map<String, dynamic> event) {
    if (!mounted || !_foregroundLifecycleActive) {
      return;
    }
    _pendingTrafficStatusEvent = event;
    final now = DateTime.now();
    final interval = _trafficUiUpdateInterval;
    final elapsed = now.difference(_lastTrafficUiUpdateAt);
    if (elapsed >= interval) {
      _flushPendingTrafficStatusEvent();
      return;
    }
    _trafficUiUpdateTimer ??= Timer(interval - elapsed, () {
      _trafficUiUpdateTimer = null;
      _flushPendingTrafficStatusEvent();
    });
  }

  void _flushPendingTrafficStatusEvent() {
    final event = _pendingTrafficStatusEvent;
    if (event == null) {
      return;
    }
    _pendingTrafficStatusEvent = null;
    _applyTrafficStatusEvent(event);
  }

  void _applyTrafficStatusEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final now = DateTime.now();
    final current = _currentTrafficStatus();
    final next = _trafficStatusReducer
        .reduce(current: current, event: RuntimeTrafficEvent.fromMap(event))
        .status;
    if (current == next) {
      // The graph needs a time sample even while traffic is idle; otherwise a
      // flat connection leaves its last point frozen until another packet is
      // transferred. The dashboard is the only consumer, so this stays idle
      // when it is closed.
      _recordTrafficSample(now);
      _publishTrafficDashboardSnapshot();
      return;
    }
    _lastTrafficUiUpdateAt = now;
    _applyTrafficStatus(next);
    _recordTrafficSample(now);
    _publishTrafficDashboardSnapshot();
  }

  void _handleRuntimeNetworkEvent(Map<String, dynamic> event) {
    final reason = event['reason']?.toString() ?? 'network';
    final interfaceName = event['interfaceName']?.toString();
    final interfaceIndex = (event['interfaceIndex'] as num?)?.toInt() ?? 0;
    final networkGeneration =
        (event['networkGeneration'] as num?)?.toInt() ??
        ++_networkInterfaceGeneration;
    AppLogStore.info(
      'network',
      'default network changed: $reason'
          '${interfaceName == null || interfaceName.isEmpty ? '' : ' ($interfaceName)'} '
          'networkGeneration=$networkGeneration selected=$_selectedProxyTag',
    );
    _networkInterfaceGeneration = networkGeneration;
    final usable =
        reason == 'default_interface' &&
        interfaceName != null &&
        interfaceName.isNotEmpty &&
        interfaceIndex > 0;
    final diagnosticsWereReady = _runtimeOperations.diagnosticsReady;
    _runtimeOperations.updateNetwork(
      generation: networkGeneration,
      usable: usable,
    );
    if (mounted) {
      ref
          .read(vpnRuntimeStateProvider.notifier)
          .updateNetwork(generation: networkGeneration, usable: usable);
    }
    _runtimeCommands.invalidate();
    _latencyCoordinator.cancel();
    _activeProxyIpController.cancelPending();
    _groupUrlTestScheduler.cancel();
    if (!usable) {
      AppLogStore.warning(
        'network',
        'default interface unavailable reason=$reason '
            'networkGeneration=$networkGeneration selected=$_selectedProxyTag',
      );
    }
    if (!_connected || _runtimeTransitionInProgress) {
      return;
    }

    // Keep historic results for unrelated servers. Invalidating every proxy
    // makes the sorted list rebuild and resort thousands of rows exactly when
    // Android is already handling a network handover. Only the active route
    // must be revalidated before it can be presented as current again.
    final activeOutboundTag = _currentResolvedActiveOutboundTag();
    final invalidatedTags = <String>{
      ?activeOutboundTag,
      if (!isLowestProxyTag(_selectedProxyTag) &&
          !_activeGroupByTagLookup.containsKey(_selectedProxyTag))
        _selectedProxyTag,
    };
    final measurementsChanged = _proxyRuntime.invalidateNetworkMeasurements(
      invalidatedTags,
      preserveUnrelatedMeasurements: true,
    );
    _resetActiveProxyIpState(rebuild: false);
    _locationLookupGeneration++;
    _locationLookupTimer?.cancel();
    _locationLookupInFlight = false;
    _locationLookupRefreshRequested = false;
    _lastLocationLookupSignature = '';
    _cancelQueuedLocationLookups();
    if (measurementsChanged) {
      _publishProxyRuntimeVisualStatesForTags(invalidatedTags);
    }
    _scheduleVpnNotificationSync();
    if (!diagnosticsWereReady && _runtimeOperations.diagnosticsReady) {
      _onRuntimeDiagnosticsReady();
    }
    if (!_foregroundLifecycleActive) {
      _runtimeIntent.deferRetryUntilResume();
      return;
    }
    if (usable) {
      // Give the new transport a moment to settle, then refresh only the
      // selected endpoint metadata. A full URLTest here can flood a freshly
      // attached cellular resolver and compete with real application traffic.
      _scheduleActiveOutboundIpRefresh(
        delay: const Duration(seconds: 2),
        forceRefresh: true,
      );
      _scheduleNetworkRecovery(
        reason: 'default_interface_changed',
        networkGeneration: networkGeneration,
      );
      return;
    }
    _networkRecovery.cancelDecision();
  }

  Future<void> _syncRuntimeState() async {
    try {
      final status = await _singboxRuntime.status();
      if (!mounted || !_foregroundLifecycleActive) return;
      final running = status['running'] == true;
      _runtimeOperations.updateRuntimeState(
        running: running,
        nativeRuntimeGeneration:
            (status['runtimeGeneration'] as num?)?.toInt() ?? 0,
      );
      final recordedServiceAlive = status['recordedServiceAlive'] == true;
      final runtimeIntentFresh = status['runtimeIntentFresh'] == true;
      final activeRuntimeOwner = status['activeRuntimeOwner'] == true;
      final nativeRecoveryPending = nativeRuntimeRecoveryPending(
        running: running,
        recordedServiceAlive: recordedServiceAlive,
        activeRuntimeOwner: activeRuntimeOwner,
        runtimeIntentFresh: runtimeIntentFresh,
      );
      final localTransitionPending =
          _starting ||
          _invalidOutboundRetryScheduled ||
          _runtimeLifecycle.startWatchdogActive;
      final decision = _runtimeSession.decideStatus(
        running: running,
        nativeRecoveryPending: nativeRecoveryPending,
        localTransitionPending: localTransitionPending,
        retryScheduled: _invalidOutboundRetryScheduled,
        stopping:
            _runtimeIntent.explicitStopInProgress ||
            _connectionPhase == AppConnectionPhase.stopping,
      );
      if (nativeRecoveryPending) {
        _logRuntimeRecoveryStatus(status);
      }
      final now = DateTime.now();
      final syncedTraffic = _trafficStatusReducer
          .reduce(
            current: _currentTrafficStatus(),
            event: RuntimeTrafficEvent.fromMap(status),
          )
          .status;
      setState(() {
        if (running) {
          _runtimeIntent.restoreDesiredFromObservedRuntime();
        }
        _setConnectionPhase(
          decision.phase,
          retryScheduled: decision.retryScheduled,
        );
        _applyTrafficStatus(syncedTraffic);
        if (running) {
          _recordTrafficSample(now);
        } else if (!nativeRecoveryPending) {
          _resetTrafficDashboardData();
          _groupUrlTestScheduler.cancel();
        }
      });
      _publishTrafficDashboardSnapshot();
      if (running &&
          await _networkInterfaceUsable(reason: 'runtime_sync_running')) {
        _scheduleActiveOutboundIpRefresh();
      } else if (running) {
        AppLogStore.warning(
          'runtime',
          'runtime sync running but interface is not usable yet',
        );
      }
    } catch (_) {
      // Ignore transient sync failures: live EventChannel events still drive state.
    }
  }

  void _logRuntimeRecoveryStatus(Map<String, dynamic> status) {
    final now = DateTime.now();
    if (!_runtimeSession.shouldLogRecoveryStatus(
      now: now,
      interval: _runtimeRecoveryStatusLogInterval,
    )) {
      return;
    }
    AppLogStore.warning(
      'runtime',
      'runtime sync pending native recovery '
          'running=${status['running']} '
          'recordedAlive=${status['recordedServiceAlive']} '
          'recordedMode=${status['recordedServiceMode'] ?? ''} '
          'intentFresh=${status['runtimeIntentFresh']} '
          'intentMode=${status['runtimeIntentMode'] ?? ''} '
          'intentReason=${status['runtimeIntentReason'] ?? ''} '
          'intent=${status['runtimeIntentState'] ?? ''} '
          'service=${status['recordedServiceState'] ?? ''}',
    );
  }

  Future<void> _handleRuntimeError(String error, bool wasRetryScheduled) async {
    AppLogStore.error('sing-box', error);
    if (!_runtimeDesiredByUser) {
      AppLogStore.info(
        'runtime',
        'ignored runtime error after explicit stop: $error',
      );
      if (mounted && _connectionPhase != AppConnectionPhase.stopping) {
        setState(() {
          _setConnectionPhase(AppConnectionPhase.idle);
        });
      }
      return;
    }
    if (wasRetryScheduled &&
        _runtimeRecovery.isTransientConfigRetryError(error)) {
      AppLogStore.warning(
        'sing-box',
        'Retrying after transient config decode failure: $error',
      );
      _runtimeRecovery.cancelRetry();
      _scheduleInvalidOutboundRetry(
        'retry after transient config decode failure',
      );
      return;
    }
    if (wasRetryScheduled) {
      _runtimeRecovery.cancelRetry();
    }
    if (await _tryRecoverFromInvalidOutbound(error)) {
      if (mounted) {
        setState(() {
          _setConnectionPhase(
            AppConnectionPhase.recovering,
            retryScheduled: true,
          );
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _runtimeIntent.clearRuntimeDesired();
        _setConnectionPhase(AppConnectionPhase.failed);
      });
    } else {
      _runtimeIntent.clearRuntimeDesired();
      _setConnectionPhase(AppConnectionPhase.failed);
    }
    if (_runtimeRecovery.shouldPresentRuntimeError(error)) {
      unawaited(_showCoreStartFailedDialog(error));
    }
  }

  Future<bool> _tryRecoverFromInvalidOutbound(String error) async {
    final recovery = await _runtimeRecovery.registerInvalidOutboundError(
      error,
      loadFallbackTagsByIndex: () async {
        // Cache miss: fall back to a one-off build to map index→tag.
        final build = await _configCoordinator
            .buildCurrentSingboxConfigInBackground(
              dropStale: false,
              prepareConfig: false,
              validateConfig: false,
            );
        return build?.plan.proxyOutboundTagsByIndex;
      },
    );
    if (recovery == null) {
      return false;
    }
    AppLogStore.warning(
      'sing-box',
      'Skipping invalid outbound "${recovery.tag}": ${recovery.reason}',
    );
    _warnIfNoOutboundsRemainAfterDropInvalid();
    _scheduleInvalidOutboundRetry(
      'retry without invalid outbound ${recovery.tag}',
    );
    return true;
  }

  void _warnIfNoOutboundsRemainAfterDropInvalid() {
    final subscription = _activeSubscription;
    if (subscription == null) {
      return;
    }
    final hasRemainingOutbounds = _runtimeRecovery.hasRemainingOutbounds(
      subscription.outbounds
          .where((outbound) => !outbound.info.deleted)
          .map((outbound) => outbound.tag),
    );
    if (hasRemainingOutbounds) {
      if (_lastEmptyAfterDropInvalidWarningSubscriptionId == subscription.id) {
        _lastEmptyAfterDropInvalidWarningSubscriptionId = null;
      }
      return;
    }
    if (_lastEmptyAfterDropInvalidWarningSubscriptionId == subscription.id) {
      return;
    }
    _lastEmptyAfterDropInvalidWarningSubscriptionId = subscription.id;
    final context = _navigatorKey.currentContext;
    final message = context == null
        ? 'No valid outbounds remain after drop invalid.'
        : AppLocalizations.of(context).noValidOutboundsAfterDropInvalidWarning;
    AppLogStore.warning('subscription', message);
    if (context != null) {
      unawaited(
        _showNoValidOutboundsDialog(
          title: AppLocalizations.of(context).noValidOutboundsTitle,
          message: AppLocalizations.of(
            context,
          ).noValidOutboundsAfterDropInvalidMessage,
        ),
      );
    }
  }

  bool _applyStartupValidationResult(
    SingboxConfigBuildResult build,
    String reason,
  ) {
    final validation = _runtimeRecovery.validateStartupBuild(build, reason);
    final warning = validation.warning;
    if (warning != null) {
      AppLogStore.warning('sing-box', warning);
      if (validation.selectedProxyInvalid) {
        _selectedProxyTag = _lowestProxyTag;
      }
    }
    return validation.canStart;
  }

  void _scheduleInvalidOutboundRetry(String reason) {
    if (!mounted || _invalidOutboundRetryScheduled || !_runtimeDesiredByUser) {
      return;
    }
    if (!_foregroundLifecycleActive) {
      _runtimeIntent.deferRetryUntilResume();
      return;
    }
    _runtimeIntent.clearRetryOnResume();
    if (mounted) {
      setState(() {
        _setConnectionPhase(
          AppConnectionPhase.recovering,
          retryScheduled: true,
        );
      });
    } else {
      _setConnectionPhase(AppConnectionPhase.recovering, retryScheduled: true);
    }
    _runtimeRecovery.scheduleRetry((retryGeneration) {
      unawaited(_runInvalidOutboundRetry(reason, retryGeneration));
    });
  }

  Future<void> _runInvalidOutboundRetry(
    String reason,
    int retryGeneration,
  ) async {
    if (!_automaticRuntimeRecoveryCurrent(retryGeneration)) {
      return;
    }
    AppLogStore.info('sing-box', reason);
    try {
      try {
        await _singboxRuntime.stop(reason: 'invalid_outbound_retry');
      } catch (_) {}
      if (!_automaticRuntimeRecoveryCurrent(retryGeneration)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!_automaticRuntimeRecoveryCurrent(retryGeneration)) {
        return;
      }
      if (await _tryFastRetryViaMutation(reason, retryGeneration)) {
        return;
      }
      if (!_automaticRuntimeRecoveryCurrent(retryGeneration)) {
        return;
      }
      final build = await _configCoordinator
          .buildCurrentSingboxConfigInBackground(
            dropStale: false,
            returnConfig: true,
          );
      if (build == null) {
        if (mounted) {
          setState(() {
            _setConnectionPhase(AppConnectionPhase.failed);
          });
        } else {
          _setConnectionPhase(AppConnectionPhase.failed);
        }
        return;
      }
      if (!_automaticRuntimeRecoveryCurrent(retryGeneration)) {
        _configCoordinator.discardPreparedConfigCandidate(build);
        return;
      }
      if (!_applyStartupValidationResult(build, reason)) {
        _configCoordinator.discardPreparedConfigCandidate(build);
        if (mounted) {
          setState(() {
            _setConnectionPhase(AppConnectionPhase.failed);
          });
        } else {
          _setConnectionPhase(AppConnectionPhase.failed);
        }
        _showNoValidOutboundsWarning();
        return;
      }
      await _startRuntimeWithBuild(
        build,
        useVpn: _vpnInboundEnabled,
        automaticRecoveryGeneration: retryGeneration,
      );
    } catch (error, stackTrace) {
      if (!_automaticRuntimeRecoveryCurrent(retryGeneration)) {
        return;
      }
      AppLogStore.error(
        'sing-box',
        'automatic outbound recovery failed: $error\n$stackTrace',
      );
      await _handleRuntimeError(error.toString(), true);
    }
  }

  bool _automaticRuntimeRecoveryCurrent(int generation) {
    return _runtimeRecovery.isCurrent(
      generation,
      ownerActive: mounted && _runtimeDesiredByUser,
    );
  }

  void _cancelAutomaticRuntimeRecovery(String reason) {
    final hadPendingRecovery =
        _invalidOutboundRetryScheduled || _retryRuntimeOnResume;
    _runtimeIntent.clearRetryOnResume();
    _runtimeRecovery.cancelRetry();
    if (hadPendingRecovery) {
      AppLogStore.info('runtime', 'automatic recovery cancelled: $reason');
    }
  }

  Future<bool> _tryFastRetryViaMutation(
    String reason,
    int retryGeneration,
  ) async {
    if (!_automaticRuntimeRecoveryCurrent(retryGeneration)) {
      return true;
    }
    final configPath = await _configCoordinator.ensureSingboxConfigPath();
    if (!_automaticRuntimeRecoveryCurrent(retryGeneration)) {
      return true;
    }
    if (configPath == null || configPath.trim().isEmpty) {
      return false;
    }
    final mutationInput = _runtimeRecovery.createMutationInput(configPath);
    if (mutationInput == null) {
      return false;
    }
    final ConfigMutationResult mutation;
    try {
      mutation = await mutateSingboxConfigInBackground(mutationInput);
    } catch (error) {
      AppLogStore.warning(
        'sing-box',
        'Fast retry mutation failed for "${mutationInput.tagToRemove}", '
            'falling back to rebuild: $error',
      );
      return false;
    }
    if (!_automaticRuntimeRecoveryCurrent(retryGeneration)) {
      return true;
    }
    _runtimeRecovery.applyMutation(mutation);
    if (mutation.startableProxyCount == 0) {
      if (mounted) {
        setState(() {
          _setConnectionPhase(AppConnectionPhase.failed);
        });
      } else {
        _setConnectionPhase(AppConnectionPhase.failed);
      }
      _showNoValidOutboundsWarning();
      return true;
    }
    final route = mutation.config['route'] as Map<String, dynamic>?;
    final routeRules = (route?['rules'] as List?) ?? const [];
    final inbounds = (mutation.config['inbounds'] as List?) ?? const [];
    final build = SingboxConfigBuildResult(
      plan: SingboxBuildPlan(
        config: mutation.config,
        proxyOutboundTagsByIndex: mutation.proxyOutboundTagsByIndex,
        visibleProxyOutboundCount: mutation.startableProxyCount,
      ),
      configJson: '',
      configPath: mutation.configPath,
      configLength: 0,
      configOutboundCount: mutation.outboundCount,
      configInboundCount: inbounds.length,
      configRouteRuleCount: routeRules.length,
      invalidOutbounds: const <InvalidStartupOutbound>[],
      invalidOutboundCount: 0,
      selectedProxyInvalid: false,
      startableOutboundCount: mutation.startableProxyCount,
    );
    AppLogStore.info(
      'sing-box',
      'Fast retry: applied in-memory mutation excluding '
          '"${mutationInput.tagToRemove}" '
          '(${mutation.outboundCount} outbounds remain)',
    );
    if (!_automaticRuntimeRecoveryCurrent(retryGeneration)) {
      return true;
    }
    await _startRuntimeWithBuild(
      build,
      useVpn: _vpnInboundEnabled,
      automaticRecoveryGeneration: retryGeneration,
    );
    return true;
  }

  void _showNoValidOutboundsWarning() {
    final context = _navigatorKey.currentContext;
    final message = context == null
        ? 'No valid outbounds remain in the selected subscription.'
        : AppLocalizations.of(context).noValidOutboundsWarning;
    AppLogStore.warning('subscription', message);
    if (context != null) {
      unawaited(
        _showNoValidOutboundsDialog(
          title: AppLocalizations.of(context).noValidOutboundsTitle,
          message: AppLocalizations.of(context).noValidOutboundsMessage,
        ),
      );
    }
  }

  Future<void> _showNoValidOutboundsDialog({
    required String title,
    required String message,
  }) async {
    if (_noValidOutboundsDialogVisible) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null || !mounted) {
      return;
    }
    _noValidOutboundsDialogVisible = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(dialogContext).close),
            ),
          ],
        ),
      );
    } finally {
      _noValidOutboundsDialogVisible = false;
    }
  }

  Future<void> _showCoreStartFailedDialog(String message) async {
    if (_runtimeErrorDialogVisible) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null || !mounted) {
      return;
    }
    _runtimeErrorDialogVisible = true;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.coreStartFailedTitle),
        content: Text(l10n.coreStartFailedMessage(message)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_showLogsPage());
            },
            child: Text(l10n.logsTitle),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
    _runtimeErrorDialogVisible = false;
  }

  void _applyGroupUpdates(RuntimeGroupsEvent event) {
    if (kDebugMode) {
      developer.Timeline.timeSync(
        'MeowClient._applyGroupUpdates',
        () => _applyGroupUpdatesImpl(event),
        arguments: <String, Object?>{'groups': event.groups.length},
      );
      return;
    }
    _applyGroupUpdatesImpl(event);
  }

  void _applyGroupUpdatesImpl(RuntimeGroupsEvent event) {
    final rawGroups = event.groups;
    _recordGroupsDiagnostics(rawGroups.length);
    final activeSubscription = _activeSubscription;
    if (activeSubscription == null || rawGroups.isEmpty || !mounted) {
      return;
    }
    var canonicalSelectedTag = '';
    for (final rawGroup in rawGroups) {
      if (rawGroup is Map && rawGroup['tag']?.toString() == 'select') {
        canonicalSelectedTag = rawGroup['selected']?.toString() ?? '';
        break;
      }
    }
    final diagnosticsWereReady = _runtimeOperations.diagnosticsReady;
    final accepted = _runtimeOperations.acceptGroupsSnapshot(
      nativeRuntimeGeneration: event.runtimeGeneration,
      selectedTag: canonicalSelectedTag,
    );
    if (!accepted) {
      AppLogStore.debug(
        'proxy',
        'discarded stale groups snapshot nativeGeneration='
            '${event.runtimeGeneration} currentGeneration='
            '${_runtimeOperations.nativeRuntimeGeneration}',
      );
      return;
    }
    final diagnosticsBecameReady =
        !diagnosticsWereReady && _runtimeOperations.diagnosticsReady;
    final previousActiveOutboundTag = _connected
        ? _currentResolvedActiveOutboundTag()
        : null;
    _ensureActiveLookupCaches();

    final result = _proxyRuntime.applyGroupUpdates(
      ProxyRuntimeGroupUpdateInput(
        rawGroups: rawGroups,
        activeSubscription: activeSubscription,
        selectedProxyTag: _selectedProxyTag,
        pendingRuntimeSelectTag: _proxySelection.pendingRuntimeSelectTag,
        currentResolvedActiveOutboundTag: previousActiveOutboundTag,
        activeOutboundTags: _activeOutboundByTagLookup.keys.toSet(),
        latencySessionRunning: _latencyCoordinator.isRunning,
        shouldIgnoreLatencyResult: _latencyCoordinator.shouldIgnoreGroupResult,
        proxyCacheContainsTag: _proxyCacheContainsTag,
        visibleGroupProxyCacheMissingChild: _visibleGroupProxyCacheMissingChild,
      ),
    );
    _forwardLatencyGroupEvents(rawGroups);
    if (!result.changed) {
      if (diagnosticsBecameReady) {
        _onRuntimeDiagnosticsReady();
      }
      return;
    }

    void applyRuntimeUpdates() {
      if (result.shouldClearRuntimeProxySelectionGuard) {
        _clearRuntimeProxySelectionGuard();
      }
      if (result.requiresRootRebuild) {
        _applyRuntimeStateToDerivedCaches();
      } else {
        _publishProxyRuntimeVisualStatesForUrlTestTags(
          result.affectedProxyTags,
        );
      }
    }

    if (result.requiresRootRebuild) {
      setState(applyRuntimeUpdates);
    } else {
      applyRuntimeUpdates();
    }
    if (result.shouldRebuildProxyCache) {
      _rebuildDerivedCaches();
    }
    unawaited(_syncQuickSettingsTileLabel());
    if (_connected) {
      final nextActiveOutboundTag = _currentResolvedActiveOutboundTag();
      if (nextActiveOutboundTag != null &&
          nextActiveOutboundTag != previousActiveOutboundTag) {
        _scheduleActiveOutboundIpRefresh();
      }
      if (result.realOutboundRuntimeStateChanged) {
        _scheduleBestOutboundLocationRefresh();
      }
    }
    if (diagnosticsBecameReady) {
      _onRuntimeDiagnosticsReady();
    }
  }

  void _forwardLatencyGroupEvents(List<dynamic> rawGroups) {
    if (!_latencyCoordinator.isRunning) {
      return;
    }
    for (final rawGroup in rawGroups) {
      if (rawGroup is! Map) continue;
      final items = rawGroup['items'];
      if (items is! List) continue;
      for (final rawItem in items) {
        if (rawItem is! Map) continue;
        final tag = rawItem['tag']?.toString().trim() ?? '';
        final time = (rawItem['time'] as num?)?.toInt() ?? 0;
        final delay = (rawItem['delay'] as num?)?.toInt() ?? 0;
        final status = rawItem['status']?.toString().trim().toLowerCase() ?? '';
        final error = rawItem['error']?.toString().trim() ?? '';
        final terminalResult =
            delay > 0 ||
            status == ProxyRuntimeController.urlTestStatusUnavailable ||
            error.isNotEmpty;
        if (terminalResult) {
          _latencyCoordinator.handleGroupEvent(tag: tag, timeSeconds: time);
        }
      }
    }
  }

  void _onRuntimeDiagnosticsReady() {
    AppLogStore.info(
      'runtime',
      'runtime diagnostics ready nativeGeneration='
          '${_runtimeOperations.nativeRuntimeGeneration} '
          'networkGeneration=$_networkInterfaceGeneration '
          'selected=$_selectedProxyTag',
    );
    // Diagnostics are not a startup requirement. Let real application traffic
    // use the newly established TUN before opening probe/provider connections.
    _scheduleActiveOutboundIpRefresh(delay: const Duration(seconds: 5));
  }

  void _recordGroupsDiagnostics(int groupCount) {
    if (!kDebugMode) {
      return;
    }
    _groupsEventsSinceLastDiagnosticsLog++;
    final now = DateTime.now();
    final previous = _lastGroupsDiagnosticsLogAt;
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 5)) {
      return;
    }
    _lastGroupsDiagnosticsLogAt = now;
    debugPrint(
      'Meow diagnostics: groupsEvents=$_groupsEventsSinceLastDiagnosticsLog '
      'groups=$groupCount activeProxies=${_activeProxiesCache.length}',
    );
    _groupsEventsSinceLastDiagnosticsLog = 0;
  }

  Outbound? _currentResolvedActiveOutbound() {
    _ensureActiveLookupCaches();
    final visibleOutbounds = _activeVisibleOutboundsLookup;
    if (visibleOutbounds.isEmpty) {
      return null;
    }
    if (isLowestProxyTag(_selectedProxyTag)) {
      return _lowestSelectedOutbound(lowestProxyTag, visibleOutbounds);
    }
    final selectedGroup = _subscriptionGroupForTag(_selectedProxyTag);
    if (selectedGroup != null) {
      return _selectedGroupOutbound(selectedGroup);
    }
    final selectedChain = _proxyChainForTag(_selectedProxyTag);
    if (selectedChain != null) {
      final target = _targetOutboundForProxyChain(selectedChain);
      if (target != null) {
        return target.copyWith(tag: selectedChain.tag);
      }
    }
    return _activeOutboundByTagLookup[_selectedProxyTag];
  }

  SubscriptionGroup? _subscriptionGroupForTag(String tag) {
    _ensureActiveLookupCaches();
    return _activeGroupByTagLookup[tag];
  }

  Outbound? _selectedGroupOutbound(SubscriptionGroup group) {
    final runtimeSelectedTag = _runtimeGroupSelections[group.tag];
    if (runtimeSelectedTag != null &&
        group.outboundTags.contains(runtimeSelectedTag)) {
      final outbound = _activeOutboundByTagLookup[runtimeSelectedTag];
      if (outbound != null) {
        return outbound;
      }
    }

    Outbound? firstChild;
    Outbound? bestChild;
    int? bestLatency;
    for (final tag in group.outboundTags) {
      final outbound = _activeOutboundByTagLookup[tag];
      if (outbound == null) {
        continue;
      }
      firstChild ??= outbound;
      if (_unavailableLatencyTags.contains(tag)) {
        continue;
      }
      final latency = _effectiveOutboundLatency(outbound);
      if (latency == null) {
        continue;
      }
      if (bestLatency == null || latency < bestLatency) {
        bestLatency = latency;
        bestChild = outbound;
      }
    }
    return bestChild ?? firstChild;
  }

  String? _currentResolvedActiveOutboundTag() {
    return _currentResolvedActiveOutbound()?.tag;
  }

  void _scheduleActiveOutboundIpRefresh({
    Duration delay = const Duration(milliseconds: 120),
    bool forceRefresh = false,
  }) {
    final externalLookupReady = _runtimeOperations.diagnosticsReady;
    if (!externalLookupReady) {
      AppLogStore.debug(
        'proxy',
        'external IP lookup deferred; resolving endpoint IP first',
      );
    }
    _activeProxyIpController.schedule(
      delay: delay,
      forceRefresh: forceRefresh,
      externalLookupReady: externalLookupReady,
      isConnected: () => _connected,
      isForegroundActive: () => _foregroundLifecycleActive,
      currentTarget: _currentActiveProxyIpTarget,
      networkUsable: (reason) => _networkInterfaceUsable(reason: reason),
      resolveEndpointIp: _resolveProxyEndpointIp,
      resolveExternalIp: _resolveActiveProxyIp,
      persistResult: _persistActiveProxyIpResult,
      onSnapshot: _publishActiveProxyIpSnapshot,
    );
  }

  void _refreshActiveProxyIp() {
    if (!_connected) {
      return;
    }
    _scheduleActiveOutboundIpRefresh(delay: Duration.zero, forceRefresh: true);
  }

  ActiveProxyIpTarget? _currentActiveProxyIpTarget() {
    final activeSubscription = _activeSubscription;
    _ensureActiveLookupCaches();
    final selectedTag = _selectedProxyTag.trim();
    final activeOutbound =
        isLowestProxyTag(selectedTag) ||
            _subscriptionGroupForTag(selectedTag) != null ||
            _proxyChainForTag(selectedTag) != null
        ? _currentResolvedActiveOutbound()
        : _activeOutboundByTagLookup[selectedTag];
    if (activeSubscription == null || activeOutbound == null) {
      return null;
    }
    final endpointHost = _normalizedProxyEndpointHost(activeOutbound.server);
    final literalEndpointIp = InternetAddress.tryParse(endpointHost)?.address;
    return ActiveProxyIpTarget(
      subscriptionId: activeSubscription.id,
      outboundTag: activeOutbound.tag,
      cachedIp: activeOutbound.info.externalIp?.trim(),
      cachedCountryCode: _normalizeCountryCode(
        activeOutbound.info.exitCountry ?? activeOutbound.info.country,
      ),
      endpointHost: endpointHost,
      endpointIp: literalEndpointIp,
      endpointCountryCode: _normalizeCountryCode(activeOutbound.info.country),
      hasCachedLocation: _hasResolvedExternalLocation(activeOutbound),
      operationGeneration: _runtimeOperations.diagnosticGeneration,
      networkGeneration: _networkInterfaceGeneration,
    );
  }

  String _normalizedProxyEndpointHost(String rawHost) {
    final host = rawHost.trim();
    if (host.length >= 2 && host.startsWith('[') && host.endsWith(']')) {
      return host.substring(1, host.length - 1);
    }
    return host;
  }

  Future<String?> _resolveProxyEndpointIp(String host) async {
    final normalizedHost = _normalizedProxyEndpointHost(host);
    if (normalizedHost.isEmpty) {
      return null;
    }
    final literal = InternetAddress.tryParse(normalizedHost);
    if (literal != null) {
      return literal.address;
    }
    try {
      final addresses = await _singboxRuntime.resolveHostOnUnderlyingNetwork(
        host: normalizedHost,
        timeout: const Duration(seconds: 3),
      );
      return addresses.firstOrNull;
    } catch (error) {
      AppLogStore.debug('proxy', 'endpoint DNS lookup failed: $error');
      return null;
    }
  }

  Future<ActiveProxyIpResolveResult?> _resolveActiveProxyIp(
    String outboundTag,
  ) async {
    final resolved = await _fetchExternalIpInfo(
      outboundTag: outboundTag,
      highPriority: true,
    );
    if (resolved == null) {
      return null;
    }
    return ActiveProxyIpResolveResult(
      ip: resolved.ip,
      countryCode: resolved.countryCode,
    );
  }

  Future<void> _persistActiveProxyIpResult(
    ActiveProxyIpTarget target,
    ActiveProxyIpResolveResult result,
  ) async {
    final latestSubscription = _activeSubscription;
    final latestActiveOutbound = _currentResolvedActiveOutbound();
    if (latestSubscription == null ||
        latestSubscription.id != target.subscriptionId ||
        latestActiveOutbound == null ||
        latestActiveOutbound.tag != target.outboundTag) {
      return;
    }
    await _applyResolvedExternalIpInfos(
      subscriptionId: target.subscriptionId,
      resolvedByTag: {
        target.outboundTag: _ResolvedExternalIpInfo(
          ip: result.ip,
          countryCode: result.countryCode,
        ),
      },
    );
  }

  Future<_ResolvedExternalIpInfo?> _fetchExternalIpInfo({
    required String outboundTag,
    bool highPriority = false,
  }) async {
    _LocationLookupSlot? slot;
    if (!highPriority) {
      slot = await _acquireLocationLookupSlot();
      if (slot == null) {
        return null;
      }
    }
    final lookup = _sharedExternalInfoLookup(outboundTag);
    if (slot != null) {
      unawaited(
        lookup.whenComplete(slot.release).then<void>((_) {}, onError: (_) {}),
      );
    }
    try {
      final response = await lookup.timeout(
        Duration(seconds: _locationLookupTimeoutSeconds),
      );
      return _ResolvedExternalIpInfo.fromResponse(
        response,
        normalizeCountryCode: _normalizeCountryCode,
      );
    } on TimeoutException {
      AppLogStore.debug(
        'proxy',
        'outbound_ip_rpc tag=$outboundTag error=timeout',
      );
      return null;
    } catch (error) {
      AppLogStore.debug(
        'proxy',
        'outbound_ip_rpc tag=$outboundTag error=core_error '
            'detail=$error',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>> _sharedExternalInfoLookup(String outboundTag) {
    final normalizedTag = outboundTag.trim();
    final key = '${_runtimeOperations.diagnosticGeneration}\n$normalizedTag';
    final existing = _externalInfoLookups[key];
    if (existing != null) {
      return existing;
    }
    final lookup = _singboxRuntime.lookupOutboundExternalInfo(
      outboundTag: normalizedTag,
    );
    _externalInfoLookups[key] = lookup;
    unawaited(
      lookup
          .whenComplete(() {
            if (identical(_externalInfoLookups[key], lookup)) {
              _externalInfoLookups.remove(key);
            }
          })
          .then<void>((_) {}, onError: (_) {}),
    );
    return lookup;
  }

  Future<_LocationLookupSlot?> _acquireLocationLookupSlot() async {
    if (_locationLookupActiveRequests >= _locationLookupConcurrency) {
      final waiter = Completer<bool>();
      _locationLookupWaiters.add(waiter);
      final acquired = await waiter.future;
      if (!acquired || !mounted) {
        return null;
      }
    } else {
      _locationLookupActiveRequests++;
    }
    return _LocationLookupSlot(_releaseLocationLookupSlot);
  }

  void _releaseLocationLookupSlot() {
    _locationLookupActiveRequests = max(0, _locationLookupActiveRequests - 1);
    _pumpLocationLookupWaiters();
  }

  void _pumpLocationLookupWaiters() {
    while (_locationLookupWaiters.isNotEmpty &&
        _locationLookupActiveRequests < _locationLookupConcurrency) {
      final waiter = _locationLookupWaiters.removeFirst();
      if (waiter.isCompleted) {
        continue;
      }
      _locationLookupActiveRequests++;
      waiter.complete(true);
    }
  }

  void _cancelQueuedLocationLookups() {
    while (_locationLookupWaiters.isNotEmpty) {
      final waiter = _locationLookupWaiters.removeFirst();
      if (!waiter.isCompleted) {
        waiter.complete(false);
      }
    }
  }

  Future<void> _applyResolvedExternalIpInfos({
    required String subscriptionId,
    required Map<String, _ResolvedExternalIpInfo> resolvedByTag,
  }) async {
    if (resolvedByTag.isEmpty ||
        !_connected ||
        !mounted ||
        _markAllServersRussia) {
      return;
    }
    final latestSubscription = _activeSubscription;
    if (latestSubscription == null || latestSubscription.id != subscriptionId) {
      return;
    }
    var subscriptionChanged = false;
    final updatedSubscription = latestSubscription.copyWith(
      outbounds: latestSubscription.outbounds
          .map((outbound) {
            final resolved = resolvedByTag[outbound.tag];
            if (resolved == null) {
              return outbound;
            }
            final legacyLocationStoredInCountry =
                outbound.info.exitCountry == null &&
                (outbound.info.externalIp?.trim().isNotEmpty ?? false);
            final inferredSourceCountry = legacyLocationStoredInCountry
                ? SubscriptionStore.inferCountryCodeFromName(outbound.name)
                : null;
            final sourceCountry =
                inferredSourceCountry ?? outbound.info.country;
            final nextExitCountry =
                resolved.countryCode ?? outbound.info.exitCountry;
            final nextInfo = outbound.info.copyWith(
              externalIp: resolved.ip,
              country: sourceCountry,
              exitCountry: nextExitCountry,
            );
            if (nextInfo.externalIp == outbound.info.externalIp &&
                nextInfo.country == outbound.info.country &&
                nextInfo.exitCountry == outbound.info.exitCountry) {
              return outbound;
            }
            subscriptionChanged = true;
            return outbound.copyWith(info: nextInfo);
          })
          .toList(growable: false),
    );
    if (!subscriptionChanged || !mounted) {
      return;
    }
    setState(() {
      _subscriptions = _replaceSubscription(updatedSubscription);
      _rebuildDerivedCaches();
    });
    final sourceCountriesByTag = <String, String?>{
      for (final outbound in updatedSubscription.outbounds)
        outbound.tag: outbound.info.country,
    };
    await SubscriptionStore.saveOutboundRuntimeInfoInBackground(
      updatedSubscription.id,
      externalInfos: {
        for (final entry in resolvedByTag.entries)
          entry.key: {
            'external_ip': entry.value.ip,
            'source_country': sourceCountriesByTag[entry.key],
            'exit_country': entry.value.countryCode,
          },
      },
    );
  }

  void _scheduleBestOutboundLocationRefresh({
    Duration delay = const Duration(seconds: 1),
  }) {
    if (!mounted || !_foregroundLifecycleActive) {
      _locationLookupTimer?.cancel();
      _locationLookupRefreshRequested = false;
      return;
    }
    if (_locationLookupInFlight) {
      _locationLookupRefreshRequested = true;
      return;
    }
    _locationLookupTimer?.cancel();
    final generation = ++_locationLookupGeneration;
    if (!_connected || _locationLookupLimit <= 0 || _markAllServersRussia) {
      _locationLookupRefreshRequested = false;
      return;
    }
    final effectiveDelay = _proxyPanelInteractionActive
        ? delay + const Duration(seconds: 3)
        : delay;
    _locationLookupTimer = Timer(effectiveDelay, () {
      unawaited(_refreshBestOutboundLocations(generation: generation));
    });
  }

  Future<void> _refreshBestOutboundLocations({required int generation}) async {
    if (_locationLookupInFlight ||
        !_connected ||
        !_foregroundLifecycleActive ||
        !mounted ||
        generation != _locationLookupGeneration ||
        _locationLookupLimit <= 0 ||
        _markAllServersRussia) {
      return;
    }
    if (_proxyPanelInteractionActive) {
      _scheduleBestOutboundLocationRefresh(delay: const Duration(seconds: 3));
      return;
    }
    final activeSubscription = _activeSubscription;
    if (activeSubscription == null) {
      return;
    }
    final targets = _bestOutboundsForLocationLookup();
    if (targets.isEmpty) {
      return;
    }
    final targetTags = targets
        .take(_locationLookupLimit)
        .where((outbound) => !_hasResolvedExternalLocation(outbound))
        .map((outbound) => outbound.tag)
        .toList(growable: false);
    if (targetTags.isEmpty) {
      return;
    }
    final signature =
        '${activeSubscription.id}|$_locationLookupLimit|'
        '${targetTags.map((tag) {
          final outbound = _activeOutboundByTagLookup[tag];
          return '$tag:${outbound == null ? '' : _effectiveOutboundLatency(outbound) ?? ''}';
        }).join('|')}';
    if (signature == _lastLocationLookupSignature) {
      return;
    }
    _lastLocationLookupSignature = signature;
    _locationLookupInFlight = true;
    try {
      final resolvedByTag = await _fetchExternalIpInfoBatch(
        targetTags,
        subscriptionId: activeSubscription.id,
        generation: generation,
      );
      if (resolvedByTag.isEmpty ||
          !_connected ||
          !mounted ||
          generation != _locationLookupGeneration) {
        return;
      }
      await _applyResolvedExternalIpInfos(
        subscriptionId: activeSubscription.id,
        resolvedByTag: resolvedByTag,
      );
    } finally {
      final refreshRequested = _locationLookupRefreshRequested;
      _locationLookupRefreshRequested = false;
      _locationLookupInFlight = false;
      if (mounted &&
          _connected &&
          (refreshRequested || generation != _locationLookupGeneration) &&
          _locationLookupLimit > 0) {
        _scheduleBestOutboundLocationRefresh(
          delay: _proxyPanelInteractionActive
              ? const Duration(seconds: 3)
              : Duration.zero,
        );
      }
    }
  }

  Future<Map<String, _ResolvedExternalIpInfo>> _fetchExternalIpInfoBatch(
    List<String> outboundTags, {
    required String subscriptionId,
    required int generation,
  }) async {
    final resolvedByTag = <String, _ResolvedExternalIpInfo>{};
    var nextIndex = 0;
    final workerCount = min(outboundTags.length, _locationLookupConcurrency);
    Future<void> worker() async {
      while (mounted &&
          _connected &&
          generation == _locationLookupGeneration &&
          _activeSubscription?.id == subscriptionId) {
        final index = nextIndex;
        nextIndex++;
        if (index >= outboundTags.length) {
          return;
        }
        final tag = outboundTags[index];
        final resolved = await _fetchExternalIpInfo(outboundTag: tag);
        if (resolved != null) {
          resolvedByTag[tag] = resolved;
        }
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));
    return resolvedByTag;
  }

  List<Outbound> _bestOutboundsForLocationLookup() {
    _ensureActiveLookupCaches();
    final outbounds = _activeVisibleOutboundsLookup
        .where(
          (outbound) =>
              !_unavailableLatencyTags.contains(outbound.tag) &&
              !_proxyRuntime.isLatencyInvalidated(outbound.tag) &&
              _effectiveOutboundLatency(outbound) != null,
        )
        .toList(growable: false);
    outbounds.sort((left, right) {
      final leftLatency = _effectiveOutboundLatency(left) ?? (1 << 30);
      final rightLatency = _effectiveOutboundLatency(right) ?? (1 << 30);
      if (leftLatency != rightLatency) {
        return leftLatency.compareTo(rightLatency);
      }
      return left.name.compareTo(right.name);
    });
    return outbounds;
  }

  bool _hasResolvedExternalLocation(Outbound outbound) {
    if (_markAllServersRussia) {
      return true;
    }
    final externalIp = outbound.info.externalIp?.trim() ?? '';
    if (externalIp.isEmpty) {
      return false;
    }
    return _normalizeCountryCode(
      outbound.info.exitCountry ?? outbound.info.country,
    ).isNotEmpty;
  }

  String _normalizeCountryCode(String? countryCode) {
    final normalized = countryCode?.trim().toUpperCase() ?? '';
    return RegExp(r'^[A-Z]{2}$').hasMatch(normalized) ? normalized : '';
  }

  String _effectiveOutboundCountry(Outbound outbound) {
    if (_markAllServersRussia) {
      return 'RU';
    }
    final sourceCountry = _normalizeCountryCode(outbound.info.country);
    return sourceCountry.isNotEmpty
        ? sourceCountry
        : _normalizeCountryCode(outbound.info.exitCountry);
  }

  String _protocolLabel(Map<String, dynamic> config, String fallbackType) {
    final parts = <String>[
      fallbackType.toUpperCase(),
      ...[_securityLabel(config), _transportLabel(config)].whereType<String>(),
    ];
    return parts.join(' · ');
  }

  String? _securityLabel(Map<String, dynamic> config) {
    final tls = config['tls'];
    if (tls is Map) {
      final reality = tls['reality'];
      if (reality is Map && reality['enabled'] == true) {
        return 'REALITY';
      }
      if (tls['enabled'] == true) {
        return 'TLS';
      }
    }

    final security = (config['security'] as String?)?.trim();
    if (security == null ||
        security.isEmpty ||
        security.toLowerCase() == 'none') {
      return null;
    }
    return security.toUpperCase();
  }

  String? _transportLabel(Map<String, dynamic> config) {
    final transport = config['transport'];
    if (transport is Map) {
      final type = (transport['type'] as String?)?.trim();
      if (type != null && type.isNotEmpty) {
        return type.toUpperCase();
      }
    }
    return null;
  }

  String _endpointLabel(Outbound outbound) {
    if (outbound.server.isEmpty) {
      return outbound.tag;
    }
    if (outbound.port <= 0) {
      return outbound.server;
    }
    return '${outbound.server}:${outbound.port}';
  }

  Subscription _withSelectedOutbound(Subscription subscription, String tag) {
    return _proxySelection.withSelectedOutbound(subscription, tag);
  }

  List<Subscription> _replaceSubscription(Subscription updated) {
    return _proxySelection.replaceSubscription(_subscriptions, updated);
  }

  Widget _buildHomePresentation(
    BuildContext context, {
    required ProxyPanelMetrics panelMetrics,
    required ProxyPanelGestures panelGestures,
  }) {
    final activeSubscription = _activeSubscription;
    final canRefreshActiveSubscription =
        activeSubscription != null &&
        !SubscriptionStore.isLocalFileImportUrl(activeSubscription.url);
    return HomePresentationBuilder(
      data: HomePresentationData(
        connected: _connected,
        connecting: _connectionBusy,
        resolvingProxy: _resolvingLowestProxy,
        connectionStatusLabel: _connectionButtonStatusLabel(context),
        activeProfile: _activeProfile,
        activeProxy: _displayProxy,
        runtimeStates: _proxyRuntimeVisualStates,
        hideServerIp: _hideServerIp,
        hapticEnabled: _hapticEnabled,
        trafficAvailable: _trafficAvailable,
        downlinkBytesPerSecond: _downlinkBytesPerSecond,
        uplinkTotalBytes: _uplinkTotalBytes,
        downlinkTotalBytes: _downlinkTotalBytes,
        trafficListenable: _trafficUiSnapshot,
        activeProfileRefreshing: _activeProfileRefreshInFlight,
        showActiveProfileRefreshAction: activeSubscription != null,
        brandName: 'Etonify',
        versionLabel: _clientVersionLabel,
        prereleaseVersion: AppUpdateService.isPrereleaseVersion(
          _clientVersionLabel,
        ),
      ),
      callbacks: HomePresentationCallbacks(
        toggleConnection: () => unawaited(
          _vpnLifecycleCommands.toggle(source: 'home.connection_button'),
        ),
        refreshLatency: () => unawaited(_runActiveProxyUrlTest()),
        refreshActiveProxyIp: _refreshActiveProxyIp,
        openSubscriptions: _showSubscriptionsPage,
        addSubscription: () => _showSubscriptionsPage(openAddOnStart: true),
        openSettings: _showSettingsPage,
        openChangelog: () => unawaited(_showChangelogSheet()),
        openTrafficDashboard: () => unawaited(_showTrafficDashboard()),
        refreshActiveSubscription: canRefreshActiveSubscription
            ? _refreshActiveSubscription
            : null,
      ),
    ).build(panelMetrics: panelMetrics, panelGestures: panelGestures);
  }

  Widget _buildProxiesPresentation(
    BuildContext context, {
    required ProxyPanelMetrics panelMetrics,
    required ValueListenable<ProxyPanelMetrics> panelMetricsListenable,
    required ScrollController scrollController,
    required ProxyPanelGestures panelGestures,
  }) {
    return ProxiesPresentationBuilder(
      data: ProxiesPresentationData(
        proxies: _activeProxies,
        groupChildrenByTag: _activeGroupChildrenByTag,
        selectedTag: _selectedProxyTag,
        activeProxy: _displayProxy,
        hideActiveProxyIp: _hideServerIp,
        connected: _connected,
        hapticEnabled: _hapticEnabled,
        trafficAvailable: _trafficAvailable,
        downlinkBytesPerSecond: _downlinkBytesPerSecond,
        uplinkTotalBytes: _uplinkTotalBytes,
        downlinkTotalBytes: _downlinkTotalBytes,
        trafficListenable: _trafficUiSnapshot,
        initialSort: _proxySort,
        progressiveBlurEnabled: _effectiveProgressiveBlurEnabled,
        runtimeStates: _proxyRuntimeVisualStates,
        proxyListLoading:
            _fullProxyListCacheRequested && !_fullProxyListCacheReady,
      ),
      callbacks: ProxiesPresentationCallbacks(
        changeSort: _setProxySort,
        selectProxy: _selectProxy,
        runUrlTest: _runUrlTest,
        refreshActiveProxyIp: _refreshActiveProxyIp,
        outboundForTag: _outboundForProxyTag,
        loadProxyChainTargetSources: _loadProxyChainTargetSources,
        loadProxyChainTargetsForSource: _loadProxyChainTargetsForSource,
        addProxyChain: _addProxyChain,
        changeProxyChainDetour: _changeProxyChainDetour,
        renameProxyChain: _renameProxyChain,
        removeProxyChain: _removeProxyChain,
        isProxyChainTag: _isProxyChainTag,
        changeHideActiveProxyIp: _setHideServerIp,
      ),
    ).build(
      panelMetrics: panelMetrics,
      panelMetricsListenable: panelMetricsListenable,
      scrollController: scrollController,
      panelGestures: panelGestures,
    );
  }

  void _updateDynamicColorSchemes(
    ColorScheme? lightDynamic,
    ColorScheme? darkDynamic,
  ) {
    if (lightDynamic == _dynamicLightScheme &&
        darkDynamic == _dynamicDarkScheme) {
      return;
    }
    _dynamicLightScheme = lightDynamic;
    _dynamicDarkScheme = darkDynamic;
    if (_accentColorHex == 'default') {
      _refreshThemeCache();
    }
  }

  Widget _buildAppHome() {
    return ProxyPanelShell(
      ready: _ready,
      onboardingCompleted: _onboardingCompleted && _legalAccepted,
      loading: const Scaffold(
        key: ValueKey('loading'),
        body: Center(child: CircularProgressIndicator()),
      ),
      welcome: _onboardingCompleted
          ? LegalConsentPage(
              key: const ValueKey('legal-consent'),
              requiredVersion: _requiredLegalVersion,
              onAccept: _acceptLegalDocuments,
            )
          : WelcomePage(
              key: const ValueKey('welcome'),
              onContinue: _completeOnboarding,
              brandName: 'Etonify',
              versionLabel: _clientVersionLabel,
            ),
      visibleRows: _proxyPanelVisibleRows(),
      hasActiveProfile: _activeProfileCache != null,
      resetListKey: '$_activeProfileId:$_proxyPanelResetGeneration',
      onInteractionActiveChanged: (active) {
        if (_proxyPanelInteractionActive == active) {
          return;
        }
        setState(() {
          _proxyPanelInteractionActive = active;
        });
      },
      onOpenRequested: () {
        _proxyPanelOpen = true;
        _cancelScheduledProxyListCacheRelease();
      },
      onOpened: () {
        if (!_proxyPanelOpen) {
          return;
        }
        unawaited(() async {
          final hydrated = await _ensureActiveSubscriptionHydratedForRuntime();
          if (mounted && hydrated && _proxyPanelOpen) {
            _ensureFullProxyListCache();
          }
        }());
      },
      onClosed: () {
        _proxyPanelOpen = false;
        _scheduleProxyListCacheRelease();
      },
      homeBuilder: (context, metrics, gestures) => _buildHomePresentation(
        context,
        panelMetrics: metrics,
        panelGestures: gestures,
      ),
      sheetBuilder:
          (context, metrics, metricsListenable, scrollController, gestures) =>
              _buildProxiesPresentation(
                context,
                panelMetrics: metrics,
                panelMetricsListenable: metricsListenable,
                scrollController: scrollController,
                panelGestures: gestures,
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the root subscription surface deliberately narrow. High-frequency
    // traffic and proxy visual updates are handled by ValueNotifier-based
    // stores below, so the whole app shell should only rebuild for values that
    // actually affect its configuration or the currently selected runtime.
    ref.watch(
      appSettingsProvider.select(
        (snapshot) => snapshot.controller.themePreference,
      ),
    );
    ref.watch(
      appSettingsProvider.select((snapshot) => snapshot.controller.localeCode),
    );
    ref.watch(
      appSettingsProvider.select(
        (snapshot) => snapshot.controller.hapticEnabled,
      ),
    );
    ref.watch(
      subscriptionCatalogProvider.select((state) => state.subscriptions),
    );
    ref.watch(
      subscriptionCatalogProvider.select((state) => state.activeProfileId),
    );
    ref.watch(
      subscriptionCatalogProvider.select((state) => state.selectedProxyTag),
    );
    ref.watch(
      subscriptionCatalogProvider.select(
        (state) => state.activeProfileRefreshing,
      ),
    );
    ref.watch(
      vpnRuntimeStateProvider.select(
        (state) => (
          state.phase,
          state.retryScheduled,
          state.networkUsable,
          state.networkGeneration,
        ),
      ),
    );
    return AppRootShell(
      navigatorKey: _navigatorKey,
      lightTheme: _lightTheme,
      darkTheme: _themePreference == AppThemePreference.amoled
          ? _amoledTheme
          : _darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      progressiveBlurEnabled: _effectiveProgressiveBlurEnabled,
      hapticEnabled: _hapticEnabled,
      home: _buildAppHome(),
      onDynamicColorSchemesChanged: _updateDynamicColorSchemes,
    );
  }
}

class _DeepLinkImportCopy {
  const _DeepLinkImportCopy({
    required this.title,
    required this.message,
    required this.nameLabel,
    required this.importAction,
    required this.importedTextBuilder,
  });

  final String title;
  final String message;
  final String nameLabel;
  final String importAction;
  final String Function(String name) importedTextBuilder;

  String imported(String name) {
    return importedTextBuilder(name);
  }
}

class _ResolvedExternalIpInfo {
  const _ResolvedExternalIpInfo({required this.ip, this.countryCode});

  final String ip;
  final String? countryCode;

  static _ResolvedExternalIpInfo? fromResponse(
    Map<String, dynamic> response, {
    required String Function(String? value) normalizeCountryCode,
  }) {
    final ip =
        (response['ip']?.toString() ?? response['query']?.toString() ?? '')
            .trim();
    if (ip.isEmpty) {
      return null;
    }
    final normalizedCountry = normalizeCountryCode(
      response['countryCode']?.toString() ??
          response['country_code']?.toString() ??
          response['cc']?.toString(),
    );
    return _ResolvedExternalIpInfo(
      ip: ip,
      countryCode: normalizedCountry.isEmpty ? null : normalizedCountry,
    );
  }
}

class _LocationLookupSlot {
  _LocationLookupSlot(this._onRelease);

  final VoidCallback _onRelease;
  bool _released = false;

  void release() {
    if (_released) {
      return;
    }
    _released = true;
    _onRelease();
  }
}

class _LocalizedSubscriptionError implements Exception {
  const _LocalizedSubscriptionError(this.message);

  final String message;

  @override
  String toString() => message;
}

class _DeepLinkImportPreview {
  const _DeepLinkImportPreview({
    required this.sourceUrl,
    required this.resolvedUrl,
    required this.requestInfo,
  });

  final String sourceUrl;
  final String resolvedUrl;
  final SubscriptionInfo? requestInfo;

  bool get isHapp =>
      requestInfo?.happCryptoLink != null ||
      requestInfo?.requireHwid == true ||
      requestInfo?.customUserAgent?.trim().isNotEmpty == true;
}

class _DeepLinkImportSheet extends StatelessWidget {
  const _DeepLinkImportSheet({
    required this.request,
    required this.preview,
    required this.copy,
    required this.l10n,
  });

  final DeepLinkImportRequest request;
  final _DeepLinkImportPreview preview;
  final _DeepLinkImportCopy copy;
  final AppLocalizations l10n;

  String _summarizeSourceUrl(String value) {
    if (value.length <= 72) {
      return value;
    }
    return '${value.substring(0, 72)}...';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = request.name;
    final isHapp = preview.isHapp;
    final happInfo = preview.requestInfo;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy.title, style: theme.textTheme.titleLarge),
                      const Gap(12),
                      Text(copy.message, style: theme.textTheme.bodyLarge),
                      if (isHapp) ...[
                        const Gap(12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: .10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.deepLinkImportHappBadge,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const Gap(16),
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (name != null && name.isNotEmpty) ...[
                                  Text(
                                    copy.nameLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  Text(name, style: theme.textTheme.titleSmall),
                                  const Gap(12),
                                ],
                                if (isHapp) ...[
                                  Text(
                                    l10n.deepLinkImportResolvedUrlLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  SelectableText(
                                    preview.resolvedUrl,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const Gap(16),
                                  Text(
                                    l10n.deepLinkImportSourceLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  Text(
                                    _summarizeSourceUrl(preview.sourceUrl),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    l10n.subscriptionUrl,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  SelectableText(
                                    preview.sourceUrl,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isHapp) ...[
                        const Gap(12),
                        SizedBox(
                          width: double.infinity,
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                l10n.deepLinkImportHappNotice,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                        const Gap(12),
                        SizedBox(
                          width: double.infinity,
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.deepLinkImportHwidLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  Text(
                                    l10n.deepLinkImportHwidValue,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const Gap(12),
                                  Text(
                                    l10n.deepLinkImportUserAgentLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  SelectableText(
                                    happInfo?.customUserAgent ??
                                        happLatestUserAgent,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Gap(16),
              if (isHapp)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_DeepLinkImportDecision.sendHwid),
                      child: Text(l10n.deepLinkImportHappSendHwidAction),
                    ),
                    const Gap(8),
                    FilledButton.tonal(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_DeepLinkImportDecision.importWithoutHwid),
                      child: Text(l10n.deepLinkImportHappWithoutHwidAction),
                    ),
                    const Gap(8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(_DeepLinkImportDecision.import),
                        child: Text(copy.importAction),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DeepLinkImportDecision { import, sendHwid, importWithoutHwid }
