import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/app/runtime_lifecycle_controller.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

enum SingboxConfigCoordinatorPhase {
  reconfiguring,
  stopping,
  connected,
  failed,
}

enum SingboxConfigApplyStatus {
  validated,
  applied,
  skipped,
  superseded,
  failed,
}

class SingboxConfigApplyResult {
  const SingboxConfigApplyResult({
    required this.status,
    required this.reason,
    this.generation = 0,
    this.error = '',
    this.runtimeGeneration = 0,
  });

  final SingboxConfigApplyStatus status;
  final String reason;
  final int generation;
  final String error;
  final int runtimeGeneration;

  bool get success =>
      status == SingboxConfigApplyStatus.validated ||
      status == SingboxConfigApplyStatus.applied ||
      status == SingboxConfigApplyStatus.skipped;

  bool get superseded => status == SingboxConfigApplyStatus.superseded;
}

class SingboxConfigCoordinatorSnapshot {
  const SingboxConfigCoordinatorSnapshot({
    required this.connected,
    required this.runtimeTransitionInProgress,
    required this.activeSubscription,
    required this.selectedProxyTag,
    required this.excludedOutboundTags,
    required this.vpnInboundEnabled,
    required this.vpnMtu,
    required this.vpnStrictRoute,
    required this.vpnTunImplementation,
    required this.proxyInboundEnabled,
    required this.proxyMixedListen,
    required this.proxyMixedPort,
    this.proxyUsername = defaultProxyUsername,
    this.proxyPassword = '',
    required this.dnsDirectResolver,
    required this.dnsProxyResolver,
    required this.dnsPreferIpv6,
    required this.russiaDnsDirectResolver,
    required this.urlTestUrl,
    required this.urlTestIntervalSeconds,
    required this.urlTestTimeoutSeconds,
    required this.urlTestConcurrency,
    required this.urlTestUnavailableCheckIntervalSeconds,
    required this.blockLeaks,
    required this.adBlockEnabled,
    required this.adBlockBlockRuleSetPath,
    required this.adBlockAllowRuleSetPath,
    required this.useRussiaRouteData,
    required this.routeDataAvailable,
    required this.routeDataSourceKind,
    required this.routeDataRelease,
    required this.russiaGeositeRuBlockedPath,
    required this.russiaGeositeRuAvailableOnlyInsidePath,
    required this.russiaGeositeCategoryRuPath,
    required this.russiaGeoipRuBlockedPath,
    required this.russiaGeoipRuWhitelistPath,
    required this.russiaGeoipRuPath,
    required this.russiaCuratedDirectServicesPath,
    required this.russiaAiServicesPath,
    this.russiaSocialServicesPath,
    this.trafficRulePreset = TrafficRulePreset.none,
    required this.bypassLocalNetwork,
    required this.splitRoutingMode,
    required this.splitRoutingPackages,
    required this.logLevel,
    required this.tcpFastOpenEnabled,
    required this.tcpMultiPathEnabled,
    required this.tlsFragmentationMode,
    this.allowUntrustedProxyCertificates = false,
    required this.interruptExistingConnections,
    required this.urlTestStrictTolerance,
    this.experimentalFakeIpEnabled = false,
    required this.markAllServersRussia,
    this.capabilities = LibboxCapabilities.bundledLegacy,
  });

  final bool connected;
  final bool runtimeTransitionInProgress;
  final Subscription? activeSubscription;
  final String selectedProxyTag;
  final Set<String> excludedOutboundTags;
  final bool vpnInboundEnabled;
  final int vpnMtu;
  final bool vpnStrictRoute;
  final TunImplementationPreference vpnTunImplementation;
  final bool proxyInboundEnabled;
  final String proxyMixedListen;
  final int proxyMixedPort;
  final String proxyUsername;
  final String proxyPassword;
  final String dnsDirectResolver;
  final String dnsProxyResolver;
  final bool dnsPreferIpv6;
  final String russiaDnsDirectResolver;
  final String urlTestUrl;
  final int urlTestIntervalSeconds;
  final int urlTestTimeoutSeconds;
  final int urlTestConcurrency;
  final int urlTestUnavailableCheckIntervalSeconds;
  final bool blockLeaks;
  final bool adBlockEnabled;
  final String? adBlockBlockRuleSetPath;
  final String? adBlockAllowRuleSetPath;
  final bool useRussiaRouteData;
  final bool routeDataAvailable;
  final String routeDataSourceKind;
  final String? routeDataRelease;
  final String? russiaGeositeRuBlockedPath;
  final String? russiaGeositeRuAvailableOnlyInsidePath;
  final String? russiaGeositeCategoryRuPath;
  final String? russiaGeoipRuBlockedPath;
  final String? russiaGeoipRuWhitelistPath;
  final String? russiaGeoipRuPath;
  final String? russiaCuratedDirectServicesPath;
  final String? russiaAiServicesPath;
  final String? russiaSocialServicesPath;
  final TrafficRulePreset trafficRulePreset;
  final bool bypassLocalNetwork;
  final SplitRoutingMode splitRoutingMode;
  final List<String> splitRoutingPackages;
  final String logLevel;
  final bool tcpFastOpenEnabled;
  final bool tcpMultiPathEnabled;
  final TlsFragmentationMode tlsFragmentationMode;
  final bool allowUntrustedProxyCertificates;
  final bool interruptExistingConnections;
  final bool urlTestStrictTolerance;
  final bool experimentalFakeIpEnabled;
  final bool markAllServersRussia;
  final LibboxCapabilities capabilities;

  bool get routeDataPathsValid =>
      russiaGeositeRuBlockedPath?.isNotEmpty == true &&
      russiaGeositeRuAvailableOnlyInsidePath?.isNotEmpty == true &&
      russiaGeositeCategoryRuPath?.isNotEmpty == true &&
      russiaGeoipRuBlockedPath?.isNotEmpty == true &&
      russiaGeoipRuWhitelistPath?.isNotEmpty == true &&
      russiaGeoipRuPath?.isNotEmpty == true;
}

typedef SingboxConfigCoordinatorSnapshotReader =
    SingboxConfigCoordinatorSnapshot Function();
typedef SingboxConfigHydrationHook = Future<bool> Function();
typedef SingboxConfigStartupValidation =
    bool Function(SingboxConfigBuildResult build, String reason);
typedef SingboxConfigPhaseSetter =
    void Function(SingboxConfigCoordinatorPhase phase);
typedef SingboxConfigRuntimeFailureNotifier =
    void Function({required bool timedOut});
typedef SingboxRuntimeStatusReader = Future<Map<String, dynamic>> Function();
typedef SingboxConfigPathReader = Future<String?> Function();

class SingboxConfigCoordinator {
  SingboxConfigCoordinator({
    required SingboxConfigCoordinatorSnapshotReader readSnapshot,
    required bool Function() isMounted,
    required SingboxConfigHydrationHook ensureActiveSubscriptionHydrated,
    required RuntimeLifecycleController runtimeLifecycle,
    required SingboxConfigStartupValidation applyStartupValidationResult,
    required void Function() showNoValidOutboundsWarning,
    required SingboxConfigPhaseSetter setPhase,
    required SingboxConfigRuntimeFailureNotifier showRuntimeFailure,
    required RuntimeLogHook logCall,
    required void Function(String reason) trimRuntimeStartMemory,
    required RuntimeTimeoutHook onRuntimeLifecycleTimeout,
    required RuntimeVoidHook cacheStartedBuild,
    required Future<void> Function() syncRuntimeState,
    SingboxRuntimeStatusReader? readRuntimeStatus,
    SingboxConfigPathReader? readConfigPath,
    this.fullServiceRestartDebounce = const Duration(milliseconds: 450),
  }) : _readSnapshot = readSnapshot,
       _isMounted = isMounted,
       _ensureActiveSubscriptionHydrated = ensureActiveSubscriptionHydrated,
       _runtimeLifecycle = runtimeLifecycle,
       _applyStartupValidationResult = applyStartupValidationResult,
       _showNoValidOutboundsWarning = showNoValidOutboundsWarning,
       _setPhase = setPhase,
       _showRuntimeFailure = showRuntimeFailure,
       _logCall = logCall,
       _trimRuntimeStartMemory = trimRuntimeStartMemory,
       _onRuntimeLifecycleTimeout = onRuntimeLifecycleTimeout,
       _cacheStartedBuild = cacheStartedBuild,
       _syncRuntimeState = syncRuntimeState,
       _readRuntimeStatus = readRuntimeStatus ?? SingboxRuntime.instance.status,
       _readConfigPath =
           readConfigPath ?? SingboxRuntime.instance.getConfigPath;

  final Duration fullServiceRestartDebounce;

  final SingboxConfigCoordinatorSnapshotReader _readSnapshot;
  final bool Function() _isMounted;
  final SingboxConfigHydrationHook _ensureActiveSubscriptionHydrated;
  final RuntimeLifecycleController _runtimeLifecycle;
  final SingboxConfigStartupValidation _applyStartupValidationResult;
  final void Function() _showNoValidOutboundsWarning;
  final SingboxConfigPhaseSetter _setPhase;
  final SingboxConfigRuntimeFailureNotifier _showRuntimeFailure;
  final RuntimeLogHook _logCall;
  final void Function(String reason) _trimRuntimeStartMemory;
  final RuntimeTimeoutHook _onRuntimeLifecycleTimeout;
  final RuntimeVoidHook _cacheStartedBuild;
  final Future<void> Function() _syncRuntimeState;
  final SingboxRuntimeStatusReader _readRuntimeStatus;
  final SingboxConfigPathReader _readConfigPath;

  int _runtimeConfigApplyGeneration = 0;
  int _singboxConfigBuildGeneration = 0;
  Future<String?>? _singboxConfigPathFuture;
  Future<void> _runtimeConfigApplyQueue = Future<void>.value();
  Timer? _fullServiceRestartDebounceTimer;
  SingboxConfigApplyResult _lastApplyResult = const SingboxConfigApplyResult(
    status: SingboxConfigApplyStatus.skipped,
    reason: 'not_applied_yet',
  );
  int _lastApplyAtMillis = 0;

  SingboxConfigApplyResult get lastApplyResult => _lastApplyResult;
  int get lastApplyAtMillis => _lastApplyAtMillis;

  void dispose() {
    _runtimeConfigApplyGeneration++;
    _singboxConfigBuildGeneration++;
    _fullServiceRestartDebounceTimer?.cancel();
    _fullServiceRestartDebounceTimer = null;
  }

  /// Invalidates config work that has not reached the native runtime yet.
  ///
  /// The worker isolate itself cannot be interrupted, but its result is
  /// discarded as soon as it returns. Runtime apply jobs use a separate
  /// generation so a queued settings update cannot restart a VPN after the
  /// user explicitly pressed stop.
  void cancelPendingWork({required String reason}) {
    _singboxConfigBuildGeneration++;
    _runtimeConfigApplyGeneration++;
    _fullServiceRestartDebounceTimer?.cancel();
    _fullServiceRestartDebounceTimer = null;
    AppLogStore.info('runtime', 'pending config work cancelled: $reason');
  }

  void emitCurrentConfigLog(
    String reason, {
    bool restartRuntime = true,
    bool forceFullServiceRestart = false,
  }) {
    if (forceFullServiceRestart && fullServiceRestartDebounce > Duration.zero) {
      _fullServiceRestartDebounceTimer?.cancel();
      _fullServiceRestartDebounceTimer = Timer(fullServiceRestartDebounce, () {
        _fullServiceRestartDebounceTimer = null;
        unawaited(
          emitCurrentConfigLogAsync(
            reason,
            restartRuntime: restartRuntime,
            forceFullServiceRestart: true,
          ).then<void>((_) {}),
        );
      });
      return;
    }
    unawaited(
      emitCurrentConfigLogAsync(
        reason,
        restartRuntime: restartRuntime,
        forceFullServiceRestart: forceFullServiceRestart,
      ).then<void>((_) {}),
    );
  }

  Future<SingboxConfigApplyResult> emitCurrentConfigLogAsync(
    String reason, {
    required bool restartRuntime,
    bool applyWhenNativeRunning = false,
    bool forceFullServiceRestart = false,
  }) async {
    var snapshot = _readSnapshot();
    var applyToRuntime =
        snapshot.connected || snapshot.runtimeTransitionInProgress;
    if (!applyToRuntime &&
        (applyWhenNativeRunning || forceFullServiceRestart)) {
      final status = await _runtimeStatusSnapshot(
        reason: 'config_emit_native_running',
      );
      applyToRuntime = status['running'] == true;
    }
    final generation = applyToRuntime ? ++_runtimeConfigApplyGeneration : 0;
    if (applyToRuntime && _isMounted()) {
      _setPhase(SingboxConfigCoordinatorPhase.reconfiguring);
    }
    final SingboxConfigBuildResult? build;
    try {
      build = await buildCurrentSingboxConfigInBackground(
        prepareConfig: applyToRuntime,
        returnConfig: applyToRuntime,
      );
    } catch (error, stackTrace) {
      AppLogStore.error(
        'sing-box config',
        'Failed to build or validate config reason=$reason: $error\n'
            '$stackTrace',
      );
      if (applyToRuntime && _isMounted() && _isCurrentApply(generation)) {
        // The old native runtime is still alive because configuration is
        // validated before it is promoted. Keep the UI attached to it.
        final status = await _runtimeStatusSnapshot(
          reason: 'config_emit_failed',
        );
        _setPhase(
          status['running'] == true
              ? SingboxConfigCoordinatorPhase.connected
              : SingboxConfigCoordinatorPhase.failed,
        );
      }
      return _recordApplyResult(
        SingboxConfigApplyResult(
          status: SingboxConfigApplyStatus.failed,
          reason: reason,
          generation: generation,
          error: error.toString(),
        ),
      );
    }
    if (build == null) {
      if (applyToRuntime && _isMounted() && _isCurrentApply(generation)) {
        _setPhase(SingboxConfigCoordinatorPhase.connected);
      }
      return _recordApplyResult(
        SingboxConfigApplyResult(
          status: applyToRuntime
              ? SingboxConfigApplyStatus.superseded
              : SingboxConfigApplyStatus.skipped,
          reason: reason,
          generation: generation,
        ),
      );
    }
    if (applyToRuntime && !_applyStartupValidationResult(build, reason)) {
      discardPreparedConfigCandidate(build);
      if (_isMounted() && _isCurrentApply(generation)) {
        _setPhase(SingboxConfigCoordinatorPhase.failed);
      }
      _showNoValidOutboundsWarning();
      return _recordApplyResult(
        SingboxConfigApplyResult(
          status: SingboxConfigApplyStatus.failed,
          reason: reason,
          generation: generation,
          error: 'no_valid_outbounds',
        ),
      );
    }
    recordBuiltConfigLog(reason, build);
    if (!applyToRuntime) {
      return _recordApplyResult(
        SingboxConfigApplyResult(
          status: SingboxConfigApplyStatus.validated,
          reason: reason,
          generation: generation,
        ),
      );
    }
    snapshot = _readSnapshot();
    return applyRuntimeConfig(
      build: build,
      useVpn: snapshot.vpnInboundEnabled,
      restartRuntime: restartRuntime,
      forceFullServiceRestart: forceFullServiceRestart,
      generation: generation,
    );
  }

  Future<SingboxConfigApplyResult> applyRuntimeConfig({
    required SingboxConfigBuildResult build,
    required bool useVpn,
    required bool restartRuntime,
    bool forceFullServiceRestart = false,
    int? generation,
  }) {
    final applyGeneration = generation ?? ++_runtimeConfigApplyGeneration;
    final operation = _runtimeConfigApplyQueue.then(
      (_) => _applyRuntimeConfigSerially(
        build: build,
        useVpn: useVpn,
        restartRuntime: restartRuntime,
        forceFullServiceRestart: forceFullServiceRestart,
        generation: applyGeneration,
      ),
    );
    _runtimeConfigApplyQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<SingboxConfigApplyResult> _applyRuntimeConfigSerially({
    required SingboxConfigBuildResult build,
    required bool useVpn,
    required bool restartRuntime,
    required bool forceFullServiceRestart,
    required int generation,
  }) async {
    var preparedBuildPromoted = false;
    _PreparedConfigTransaction? preparedConfigTransaction;
    var runtimeApplySucceeded = false;
    try {
      if (!_isMounted() || !_isCurrentApply(generation)) {
        return _recordApplyResult(
          SingboxConfigApplyResult(
            status: SingboxConfigApplyStatus.superseded,
            reason: 'runtime_apply',
            generation: generation,
          ),
        );
      }
      final policy = await _resolveRuntimeApplyPolicy(
        useVpn: useVpn,
        restartRuntime: restartRuntime,
        forceFullServiceRestart: forceFullServiceRestart,
      );
      if (!_isMounted() || !_isCurrentApply(generation)) {
        return _recordApplyResult(
          SingboxConfigApplyResult(
            status: SingboxConfigApplyStatus.superseded,
            reason: 'runtime_apply',
            generation: generation,
          ),
        );
      }
      if (policy == RuntimeApplyPolicy.logOnly) {
        AppLogStore.info(
          'runtime',
          'config apply skipped because runtime is not running useVpn=$useVpn',
        );
        return _recordApplyResult(
          SingboxConfigApplyResult(
            status: SingboxConfigApplyStatus.validated,
            reason: 'runtime_not_running',
            generation: generation,
          ),
        );
      }
      _setPhase(
        policy == RuntimeApplyPolicy.fullServiceRestart
            ? SingboxConfigCoordinatorPhase.stopping
            : SingboxConfigCoordinatorPhase.reconfiguring,
      );
      final result = await _runtimeLifecycle.applyRuntimeBuild(
        build: build,
        useVpn: useVpn,
        policy: policy,
        promotePreparedConfig: (candidate) async {
          preparedConfigTransaction = await _beginPreparedConfigTransaction(
            candidate,
            generation: generation,
          );
          preparedBuildPromoted = candidate.hasPreparedConfig;
        },
        cacheStartedBuild: _cacheStartedBuild,
        logCall: _logCall,
        trimMemory: _trimRuntimeStartMemory,
        onWatchdogTimeout: _onRuntimeLifecycleTimeout,
      );
      if (!_isMounted() || !_isCurrentApply(generation)) {
        return _recordApplyResult(
          SingboxConfigApplyResult(
            status: SingboxConfigApplyStatus.superseded,
            reason: 'runtime_apply',
            generation: generation,
          ),
        );
      }
      if (!result.success) {
        await preparedConfigTransaction?.rollback();
        preparedConfigTransaction = null;
        _setPhase(SingboxConfigCoordinatorPhase.failed);
        _showRuntimeFailure(timedOut: result.timedOut);
        return _recordApplyResult(
          SingboxConfigApplyResult(
            status: SingboxConfigApplyStatus.failed,
            reason: 'runtime_apply',
            generation: generation,
            error: result.error?.toString() ?? 'runtime_apply_failed',
          ),
        );
      }
      runtimeApplySucceeded = true;
      await preparedConfigTransaction?.commit();
      preparedConfigTransaction = null;
      if (result.policy == RuntimeApplyPolicy.safeCoreRestart) {
        _setPhase(SingboxConfigCoordinatorPhase.connected);
        if (result.recovered) {
          AppLogStore.info(
            'runtime',
            'safe core restart recovered with one full service restart',
          );
        }
      }
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 500),
          _syncRuntimeState,
        ),
      );
      return _recordApplyResult(
        SingboxConfigApplyResult(
          status: SingboxConfigApplyStatus.applied,
          reason: 'runtime_apply',
          generation: generation,
        ),
      );
    } catch (error, stackTrace) {
      await preparedConfigTransaction?.rollback();
      preparedConfigTransaction = null;
      AppLogStore.error(
        'sing-box',
        'Failed to apply config: $error\n$stackTrace',
      );
      if (_isMounted()) {
        _setPhase(SingboxConfigCoordinatorPhase.failed);
        _showRuntimeFailure(timedOut: false);
      }
      return _recordApplyResult(
        SingboxConfigApplyResult(
          status: SingboxConfigApplyStatus.failed,
          reason: 'runtime_apply',
          generation: generation,
          error: error.toString(),
        ),
      );
    } finally {
      // Applying a prepared build consumes its staged file. If the operation
      // became stale or failed before promotion, remove the orphan candidate.
      if (!preparedBuildPromoted) {
        discardPreparedConfigCandidate(build);
      }
      if (!runtimeApplySucceeded) {
        await preparedConfigTransaction?.rollback();
      }
    }
  }

  SingboxConfigApplyResult _recordApplyResult(SingboxConfigApplyResult result) {
    if (!result.superseded) {
      _lastApplyResult = result;
      _lastApplyAtMillis = DateTime.now().millisecondsSinceEpoch;
    }
    return result;
  }

  Future<RuntimeLifecycleResult> startRuntimeWithBuild(
    SingboxConfigBuildResult build, {
    required bool useVpn,
  }) {
    return _runtimeLifecycle.startRuntimeWithBuild(
      build: build,
      useVpn: useVpn,
      promotePreparedConfig: promotePreparedConfigBuild,
      cacheStartedBuild: _cacheStartedBuild,
      logCall: _logCall,
      trimMemory: _trimRuntimeStartMemory,
      onWatchdogTimeout: _onRuntimeLifecycleTimeout,
    );
  }

  Future<SingboxConfigBuildResult?> buildCurrentSingboxConfigInBackground({
    bool dropStale = true,
    bool prepareConfig = true,
    bool returnConfig = false,
    bool validateConfig = true,
  }) async {
    final capabilities = _readSnapshot().capabilities;
    if (!capabilities.isCompatible) {
      throw StateError(
        'Incompatible libbox contract: ${capabilities.contractError}',
      );
    }
    if (!await _ensureActiveSubscriptionHydrated()) {
      return null;
    }
    final generation = ++_singboxConfigBuildGeneration;
    final configPath = prepareConfig ? await ensureSingboxConfigPath() : null;
    if (!_isMounted()) {
      return null;
    }
    if (dropStale && generation != _singboxConfigBuildGeneration) {
      return null;
    }
    final stagedConfigPath = configPath == null
        ? null
        : '$configPath.pending.$generation';
    final input = _currentSingboxConfigBuildInput(
      outputConfigPath: stagedConfigPath,
      // A validation-only build has no file to read back. Always return JSON
      // in that mode so checkConfig/logging cannot fail with an artificial
      // "Generated config is unavailable" error.
      returnConfig: returnConfig || stagedConfigPath == null,
    );
    late final SingboxConfigBuildResult result;
    try {
      result = await buildSingboxConfigInBackground(input);
      if (validateConfig && input.capabilities.supportsConfigCheck) {
        await SingboxRuntime.instance.checkConfig(
          await _configContentForValidation(result),
        );
      }
    } catch (_) {
      _deletePreparedConfigCandidate(stagedConfigPath);
      rethrow;
    }
    if (!_isMounted()) {
      _deletePreparedConfigCandidate(stagedConfigPath);
      return null;
    }
    if (dropStale && generation != _singboxConfigBuildGeneration) {
      _deletePreparedConfigCandidate(stagedConfigPath);
      return null;
    }
    return result;
  }

  Future<String> _configContentForValidation(
    SingboxConfigBuildResult result,
  ) async {
    if (result.configJson.isNotEmpty) {
      return result.configJson;
    }
    final path = result.configPath?.trim() ?? '';
    if (path.isEmpty) {
      throw StateError('Generated config is unavailable for validation.');
    }
    return File(path).readAsString();
  }

  Future<void> promotePreparedConfigBuild(
    SingboxConfigBuildResult build,
  ) async {
    if (!build.hasPreparedConfig) {
      return;
    }
    final targetPath = await ensureSingboxConfigPath();
    if (targetPath == null || targetPath.trim().isEmpty) {
      throw StateError('Prepared config target path is unavailable.');
    }
    _promotePreparedConfigCandidate(
      sourcePath: build.configPath!,
      targetPath: targetPath,
    );
  }

  Future<_PreparedConfigTransaction?> _beginPreparedConfigTransaction(
    SingboxConfigBuildResult build, {
    required int generation,
  }) async {
    if (!build.hasPreparedConfig) return null;
    final targetPath = await ensureSingboxConfigPath();
    if (targetPath == null || targetPath.trim().isEmpty) {
      throw StateError('Prepared config target path is unavailable.');
    }
    final source = File(build.configPath!);
    final target = File(targetPath);
    final backup = File('$targetPath.rollback.$generation');
    target.parent.createSync(recursive: true);
    if (backup.existsSync()) backup.deleteSync();
    var hadTarget = false;
    try {
      if (target.existsSync()) {
        target.renameSync(backup.path);
        hadTarget = true;
      }
      source.renameSync(target.path);
      return _PreparedConfigTransaction(
        target: target,
        backup: backup,
        hadTarget: hadTarget,
      );
    } catch (_) {
      if (!target.existsSync() && hadTarget && backup.existsSync()) {
        backup.renameSync(target.path);
      }
      rethrow;
    }
  }

  void discardPreparedConfigCandidate(SingboxConfigBuildResult build) {
    if (!build.hasPreparedConfig) {
      return;
    }
    _deletePreparedConfigCandidate(build.configPath);
  }

  Future<void> logCurrentSingboxConfig(String reason) async {
    final build = await buildCurrentSingboxConfigInBackground(
      prepareConfig: false,
      returnConfig: true,
    );
    if (build == null) {
      return;
    }
    recordBuiltConfigLog(reason, build);
  }

  void recordBuiltConfigLog(String reason, SingboxConfigBuildResult build) {
    final snapshot = _readSnapshot();
    AppLogStore.info(
      'sing-box config diagnostics',
      'reason=$reason '
          'useRussiaRouteData=${snapshot.useRussiaRouteData} '
          'trafficRulePreset=${snapshot.trafficRulePreset.storageValue} '
          'routeDataAvailable=${snapshot.routeDataAvailable} '
          'routeDataPathsValid=${snapshot.routeDataPathsValid} '
          'routeDataSource=${snapshot.routeDataSourceKind} '
          'routeDataRelease=${snapshot.routeDataRelease ?? ''} '
          'activeSubscription=${snapshot.activeSubscription?.id ?? ''} '
          'selectedProxy=${snapshot.selectedProxyTag} '
          'outbounds=${build.configOutboundCount} '
          'inbounds=${build.configInboundCount} '
          'routeRules=${build.configRouteRuleCount}',
    );
    if (build.configJson.isNotEmpty) {
      final decoded = jsonDecode(build.configJson);
      if (decoded is Map<String, dynamic>) {
        AppLogStore.config(reason, decoded);
        return;
      }
    }
    if (build.hasReturnedConfig) {
      AppLogStore.config(reason, build.plan.config);
      return;
    }
    AppLogStore.info(
      'sing-box config ($reason)',
      'config omitted: ${build.configOutboundCount} outbounds, '
          '${build.configInboundCount} inbounds, '
          '${build.configRouteRuleCount} route rules, '
          '${build.configLength} chars',
    );
  }

  Future<String?> ensureSingboxConfigPath() {
    return _singboxConfigPathFuture ??= _readConfigPath();
  }

  Future<RuntimeApplyPolicy> _resolveRuntimeApplyPolicy({
    required bool useVpn,
    required bool restartRuntime,
    required bool forceFullServiceRestart,
  }) async {
    final status = await _runtimeStatusSnapshot(reason: 'config_apply_policy');
    final running = status['running'] == true;
    final currentMode = status['mode']?.toString().toLowerCase();
    final targetMode = useVpn ? 'vpn' : 'proxy';
    final recordedServiceAlive = status['recordedServiceAlive'] == true;
    final runtimeIntentFresh = status['runtimeIntentFresh'] == true;
    final transitionInProgress = _readSnapshot().runtimeTransitionInProgress;
    final serviceMayBeAlive =
        running ||
        recordedServiceAlive ||
        runtimeIntentFresh ||
        transitionInProgress;
    final policy = forceFullServiceRestart && serviceMayBeAlive
        ? RuntimeApplyPolicy.fullServiceRestart
        : running && currentMode == targetMode
        ? RuntimeApplyPolicy.safeCoreRestart
        : (serviceMayBeAlive || restartRuntime
              ? RuntimeApplyPolicy.fullServiceRestart
              : RuntimeApplyPolicy.logOnly);
    AppLogStore.info(
      'runtime',
      'config apply policy resolved policy=${policy.name} '
          'requestedRestart=$restartRuntime running=$running '
          'forceFullServiceRestart=$forceFullServiceRestart '
          'mode=${currentMode ?? ''} target=$targetMode '
          'recordedServiceAlive=$recordedServiceAlive '
          'runtimeIntentFresh=$runtimeIntentFresh',
    );
    return policy;
  }

  Future<Map<String, dynamic>> _runtimeStatusSnapshot({
    required String reason,
  }) async {
    try {
      return await _readRuntimeStatus().timeout(const Duration(seconds: 2));
    } catch (error) {
      AppLogStore.warning(
        'runtime',
        'status snapshot failed reason=$reason error=$error',
      );
      return const <String, dynamic>{'running': false};
    }
  }

  bool _isCurrentApply(int generation) {
    return generation == _runtimeConfigApplyGeneration;
  }

  SingboxConfigBuildInput _currentSingboxConfigBuildInput({
    String? outputConfigPath,
    required bool returnConfig,
  }) {
    final snapshot = _readSnapshot();
    return SingboxConfigBuildInput(
      activeSubscription: snapshot.activeSubscription,
      selectedProxyTag: snapshot.selectedProxyTag,
      excludedOutboundTags: Set<String>.from(snapshot.excludedOutboundTags),
      vpnInboundEnabled: snapshot.vpnInboundEnabled,
      vpnMtu: snapshot.vpnMtu,
      vpnStrictRoute: snapshot.vpnStrictRoute,
      vpnTunImplementation: snapshot.vpnTunImplementation,
      proxyInboundEnabled: snapshot.proxyInboundEnabled,
      proxyMixedListen: snapshot.proxyMixedListen,
      proxyMixedPort: snapshot.proxyMixedPort,
      proxyUsername: snapshot.proxyUsername,
      proxyPassword: snapshot.proxyPassword,
      dnsDirectResolver: snapshot.dnsDirectResolver,
      dnsProxyResolver: snapshot.dnsProxyResolver,
      dnsPreferIpv6: snapshot.dnsPreferIpv6,
      russiaDnsDirectResolver: snapshot.russiaDnsDirectResolver,
      urlTestUrl: snapshot.urlTestUrl,
      urlTestIntervalSeconds: snapshot.urlTestIntervalSeconds,
      urlTestTimeoutSeconds: snapshot.urlTestTimeoutSeconds,
      urlTestConcurrency: snapshot.urlTestConcurrency,
      urlTestUnavailableCheckIntervalSeconds:
          snapshot.urlTestUnavailableCheckIntervalSeconds,
      blockLeaks: snapshot.blockLeaks,
      adBlockEnabled: snapshot.adBlockEnabled,
      adBlockBlockRuleSetPath: snapshot.adBlockBlockRuleSetPath,
      adBlockAllowRuleSetPath: snapshot.adBlockAllowRuleSetPath,
      useRussiaRouteData: snapshot.useRussiaRouteData,
      russiaGeositeRuBlockedPath: snapshot.russiaGeositeRuBlockedPath,
      russiaGeositeRuAvailableOnlyInsidePath:
          snapshot.russiaGeositeRuAvailableOnlyInsidePath,
      russiaGeositeCategoryRuPath: snapshot.russiaGeositeCategoryRuPath,
      russiaGeoipRuBlockedPath: snapshot.russiaGeoipRuBlockedPath,
      russiaGeoipRuWhitelistPath: snapshot.russiaGeoipRuWhitelistPath,
      russiaGeoipRuPath: snapshot.russiaGeoipRuPath,
      russiaCuratedDirectServicesPath: snapshot.russiaCuratedDirectServicesPath,
      russiaAiServicesPath: snapshot.russiaAiServicesPath,
      russiaSocialServicesPath: snapshot.russiaSocialServicesPath,
      trafficRulePreset: snapshot.trafficRulePreset,
      bypassLocalNetwork: snapshot.bypassLocalNetwork,
      splitRoutingMode: snapshot.splitRoutingMode,
      splitRoutingPackages: snapshot.splitRoutingPackages,
      logLevel: snapshot.logLevel,
      tcpFastOpenEnabled: snapshot.tcpFastOpenEnabled,
      tcpMultiPathEnabled: snapshot.tcpMultiPathEnabled,
      tlsFragmentationMode: snapshot.tlsFragmentationMode,
      allowUntrustedProxyCertificates: snapshot.allowUntrustedProxyCertificates,
      interruptExistingConnections: snapshot.interruptExistingConnections,
      urlTestStrictTolerance: snapshot.urlTestStrictTolerance,
      experimentalFakeIpEnabled: snapshot.experimentalFakeIpEnabled,
      markAllServersRussia: snapshot.markAllServersRussia,
      capabilities: snapshot.capabilities,
      outputConfigPath: outputConfigPath,
      returnConfig: returnConfig,
    );
  }

  void _promotePreparedConfigCandidate({
    required String sourcePath,
    required String targetPath,
  }) {
    if (sourcePath == targetPath) {
      return;
    }
    final source = File(sourcePath);
    final target = File(targetPath);
    target.parent.createSync(recursive: true);
    try {
      source.renameSync(target.path);
      return;
    } on FileSystemException {
      if (target.existsSync()) {
        target.deleteSync();
      }
    }
    source.renameSync(target.path);
  }

  void _deletePreparedConfigCandidate(String? path) {
    if (path == null || path.trim().isEmpty) {
      return;
    }
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }
}

class _PreparedConfigTransaction {
  _PreparedConfigTransaction({
    required this.target,
    required this.backup,
    required this.hadTarget,
  });

  final File target;
  final File backup;
  final bool hadTarget;
  bool _finished = false;

  Future<void> commit() async {
    if (_finished) return;
    _finished = true;
    if (backup.existsSync()) backup.deleteSync();
  }

  Future<void> rollback() async {
    if (_finished) return;
    _finished = true;
    if (target.existsSync()) target.deleteSync();
    if (hadTarget && backup.existsSync()) {
      backup.renameSync(target.path);
    } else if (backup.existsSync()) {
      backup.deleteSync();
    }
  }
}
