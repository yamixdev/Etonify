import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/app/runtime_lifecycle_controller.dart';
import 'package:meow_client/app/singbox_config_coordinator.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/singbox/singbox_config_builder.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

void main() {
  test('serializes config applies and drops queued stale builds', () async {
    final runtime = _BlockingRuntime();
    final lifecycle = RuntimeLifecycleController(
      runtime: runtime,
      healthCheckTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(lifecycle.dispose);
    final coordinator = _coordinator(runtimeLifecycle: lifecycle);

    final first = coordinator.applyRuntimeConfig(
      build: _build('first'),
      useVpn: true,
      restartRuntime: true,
    );
    unawaited(
      first.then<void>(
        (_) {
          if (!runtime.firstApplyStarted.isCompleted) {
            runtime.firstApplyStarted.completeError(
              StateError('first apply completed without reaching runtime'),
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!runtime.firstApplyStarted.isCompleted) {
            runtime.firstApplyStarted.completeError(error, stackTrace);
          }
        },
      ),
    );
    await runtime.firstApplyStarted.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('first apply did not start'),
    );

    final stale = coordinator.applyRuntimeConfig(
      build: _build('stale'),
      useVpn: true,
      restartRuntime: true,
    );
    final latest = coordinator.applyRuntimeConfig(
      build: _build('latest'),
      useVpn: true,
      restartRuntime: true,
    );

    expect(runtime.appliedConfigs, ['first']);
    expect(runtime.maxConcurrentApplies, 1);

    runtime.releaseFirstApply.complete();
    await Future.wait([first, stale, latest]).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('queued applies did not finish'),
    );

    expect(runtime.appliedConfigs, ['first', 'latest']);
    expect(runtime.maxConcurrentApplies, 1);
  });

  test('explicit stop invalidates a queued config apply', () async {
    final runtime = _BlockingRuntime();
    final lifecycle = RuntimeLifecycleController(
      runtime: runtime,
      healthCheckTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(lifecycle.dispose);
    final coordinator = _coordinator(runtimeLifecycle: lifecycle);

    final first = coordinator.applyRuntimeConfig(
      build: _build('first'),
      useVpn: true,
      restartRuntime: true,
    );
    await runtime.firstApplyStarted.future.timeout(const Duration(seconds: 5));

    final queued = coordinator.applyRuntimeConfig(
      build: _build('must-not-start'),
      useVpn: true,
      restartRuntime: true,
    );
    coordinator.cancelPendingWork(reason: 'test explicit stop');
    runtime.releaseFirstApply.complete();

    await Future.wait([first, queued]).timeout(const Duration(seconds: 5));
    expect(runtime.appliedConfigs, ['first']);
  });

  test('split routing apply forces a full VPN service restart', () async {
    final runtime = _BlockingRuntime();
    final lifecycle = RuntimeLifecycleController(
      runtime: runtime,
      healthCheckTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(lifecycle.dispose);
    final coordinator = _coordinator(runtimeLifecycle: lifecycle);

    await coordinator.applyRuntimeConfig(
      build: _build('split-routing'),
      useVpn: true,
      restartRuntime: true,
      forceFullServiceRestart: true,
    );

    expect(runtime.stopCalls, 1);
    expect(runtime.startCalls, 1);
    expect(runtime.appliedConfigs, ['split-routing']);
  });

  test(
    'rapid split routing changes collapse into one full service restart',
    () async {
      final runtime = _BlockingRuntime();
      final lifecycle = RuntimeLifecycleController(
        runtime: runtime,
        healthCheckTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(lifecycle.dispose);
      final coordinator = _coordinator(
        runtimeLifecycle: lifecycle,
        fullServiceRestartDebounce: const Duration(milliseconds: 30),
      );
      addTearDown(coordinator.dispose);

      coordinator.emitCurrentConfigLog(
        'split routing mode changed',
        forceFullServiceRestart: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      coordinator.emitCurrentConfigLog(
        'split routing packages changed',
        forceFullServiceRestart: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      coordinator.emitCurrentConfigLog(
        'split routing mode changed again',
        forceFullServiceRestart: true,
      );

      await runtime.firstStart.future.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(runtime.stopCalls, 1);
      expect(runtime.startCalls, 1);
      expect(runtime.maxConcurrentApplies, 1);
    },
  );

  test(
    'forced dataplane change detects a native runtime behind stale UI',
    () async {
      final runtime = _BlockingRuntime();
      final lifecycle = RuntimeLifecycleController(
        runtime: runtime,
        healthCheckTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(lifecycle.dispose);
      final coordinator = _coordinator(
        runtimeLifecycle: lifecycle,
        connected: false,
        fullServiceRestartDebounce: Duration.zero,
      );

      await coordinator.emitCurrentConfigLogAsync(
        'adblock rule-set updated',
        restartRuntime: true,
        forceFullServiceRestart: true,
      );

      expect(runtime.stopCalls, 1);
      expect(runtime.startCalls, 1);
    },
  );

  test('failed runtime apply restores the previous promoted config', () async {
    final temp = await Directory.systemTemp.createTemp('etonify-config-tx-');
    addTearDown(() => temp.delete(recursive: true));
    final target = File('${temp.path}/config.json')..writeAsStringSync('old');
    final candidate = File('${temp.path}/candidate.json')
      ..writeAsStringSync('new');
    final runtime = _FailingPreparedRuntime();
    final lifecycle = RuntimeLifecycleController(
      runtime: runtime,
      healthCheckTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(lifecycle.dispose);
    final coordinator = _coordinator(
      runtimeLifecycle: lifecycle,
      readConfigPath: () async => target.path,
    );

    final result = await coordinator.applyRuntimeConfig(
      build: _build('', configPath: candidate.path),
      useVpn: true,
      restartRuntime: true,
    );

    expect(result.status, SingboxConfigApplyStatus.failed);
    expect(target.readAsStringSync(), 'old');
    expect(candidate.existsSync(), isFalse);
    expect(
      temp.listSync().whereType<File>().map((file) => file.path),
      everyElement(isNot(contains('.rollback.'))),
    );
  });
}

SingboxConfigCoordinator _coordinator({
  required RuntimeLifecycleController runtimeLifecycle,
  bool connected = true,
  Duration fullServiceRestartDebounce = const Duration(milliseconds: 450),
  SingboxConfigPathReader? readConfigPath,
}) {
  return SingboxConfigCoordinator(
    readSnapshot: () => _snapshot(connected: connected),
    isMounted: () => true,
    ensureActiveSubscriptionHydrated: () async => true,
    runtimeLifecycle: runtimeLifecycle,
    applyStartupValidationResult: (_, _) => true,
    showNoValidOutboundsWarning: () {},
    setPhase: (_) {},
    showRuntimeFailure: ({required bool timedOut}) {},
    logCall: (_, _) {},
    trimRuntimeStartMemory: (_) {},
    onRuntimeLifecycleTimeout: (_) {},
    cacheStartedBuild: (_) {},
    syncRuntimeState: () async {},
    readRuntimeStatus: () async => const <String, dynamic>{
      'running': true,
      'mode': 'vpn',
      'recordedServiceAlive': true,
      'runtimeIntentFresh': true,
    },
    readConfigPath: readConfigPath,
    fullServiceRestartDebounce: fullServiceRestartDebounce,
  );
}

SingboxConfigCoordinatorSnapshot _snapshot({bool connected = true}) {
  return SingboxConfigCoordinatorSnapshot(
    connected: connected,
    runtimeTransitionInProgress: false,
    activeSubscription: null,
    selectedProxyTag: '',
    excludedOutboundTags: <String>{},
    vpnInboundEnabled: true,
    vpnMtu: 9000,
    vpnStrictRoute: false,
    vpnTunImplementation: TunImplementationPreference.mixed,
    proxyInboundEnabled: false,
    proxyMixedListen: '127.0.0.1',
    proxyMixedPort: 2080,
    dnsDirectResolver: 'local',
    dnsProxyResolver: 'https://dns.google/dns-query',
    dnsPreferIpv6: false,
    russiaDnsDirectResolver: defaultRussiaDnsDirectResolver,
    urlTestUrl: defaultUrlTestUrl,
    urlTestIntervalSeconds: 300,
    urlTestTimeoutSeconds: 5,
    urlTestConcurrency: 4,
    urlTestUnavailableCheckIntervalSeconds: 60,
    blockLeaks: true,
    adBlockEnabled: false,
    adBlockBlockRuleSetPath: null,
    adBlockAllowRuleSetPath: null,
    useRussiaRouteData: false,
    routeDataAvailable: false,
    routeDataSourceKind: 'test',
    routeDataRelease: null,
    russiaGeositeRuBlockedPath: null,
    russiaGeositeRuAvailableOnlyInsidePath: null,
    russiaGeositeCategoryRuPath: null,
    russiaGeoipRuBlockedPath: null,
    russiaGeoipRuWhitelistPath: null,
    russiaGeoipRuPath: null,
    russiaCuratedDirectServicesPath: null,
    russiaAiServicesPath: null,
    bypassLocalNetwork: true,
    splitRoutingMode: SplitRoutingMode.disabled,
    splitRoutingPackages: <String>[],
    logLevel: 'info',
    tcpFastOpenEnabled: false,
    tcpMultiPathEnabled: false,
    tlsFragmentationMode: TlsFragmentationMode.disabled,
    interruptExistingConnections: false,
    urlTestStrictTolerance: false,
    markAllServersRussia: false,
  );
}

SingboxConfigBuildResult _build(String config, {String? configPath}) {
  return SingboxConfigBuildResult(
    plan: const SingboxBuildPlan(
      config: <String, dynamic>{},
      proxyOutboundTagsByIndex: <int, String>{0: 'vless-1'},
      visibleProxyOutboundCount: 1,
    ),
    configJson: config,
    configPath: configPath,
    configLength: config.length,
    configOutboundCount: 1,
    configInboundCount: 1,
    configRouteRuleCount: 1,
    invalidOutbounds: const <InvalidStartupOutbound>[],
    invalidOutboundCount: 0,
    selectedProxyInvalid: false,
    startableOutboundCount: 1,
  );
}

class _FailingPreparedRuntime extends _BlockingRuntime {
  @override
  Future<void> applyPreparedConfig({
    required bool useVpn,
    required bool restartCore,
  }) async {
    throw StateError('prepared apply failed');
  }

  @override
  Future<void> startPrepared({required bool useVpn}) async {
    throw StateError('prepared restart failed');
  }
}

class _BlockingRuntime implements RuntimeLifecycleRuntime {
  final Completer<void> firstApplyStarted = Completer<void>();
  final Completer<void> releaseFirstApply = Completer<void>();
  final Completer<void> firstStart = Completer<void>();
  final List<String> appliedConfigs = <String>[];
  int _concurrentApplies = 0;
  int maxConcurrentApplies = 0;
  int startCalls = 0;
  int stopCalls = 0;
  bool running = true;
  String mode = 'vpn';
  bool recordedServiceAlive = true;
  bool activeRuntimeOwner = true;
  int runtimeGeneration = 1;

  @override
  Future<void> applyConfig({
    required String config,
    required bool useVpn,
    required bool restartCore,
  }) async {
    await _trackConfigApply(config);
  }

  Future<void> _trackConfigApply(String config) async {
    appliedConfigs.add(config);
    _concurrentApplies++;
    if (_concurrentApplies > maxConcurrentApplies) {
      maxConcurrentApplies = _concurrentApplies;
    }
    try {
      if (config == 'first') {
        firstApplyStarted.complete();
        await releaseFirstApply.future;
      }
    } finally {
      _concurrentApplies--;
    }
  }

  @override
  Future<void> applyPreparedConfig({
    required bool useVpn,
    required bool restartCore,
  }) async {}

  @override
  Future<NetworkInterfaceSnapshot> getNetworkInterfaceState() async {
    return const NetworkInterfaceSnapshot(
      available: true,
      interfaceName: 'wlan0',
      interfaceIndex: 1,
      generation: 1,
      reason: 'test',
      updatedAtMillis: 1,
    );
  }

  @override
  Future<bool> prepareVpn({required bool requiresVpn}) async => true;

  @override
  Future<void> start({required String config, required bool useVpn}) {
    startCalls++;
    running = true;
    mode = useVpn ? 'vpn' : 'proxy';
    recordedServiceAlive = true;
    activeRuntimeOwner = true;
    runtimeGeneration++;
    if (!firstStart.isCompleted) {
      firstStart.complete();
    }
    return _trackConfigApply(config);
  }

  @override
  Future<void> startPrepared({required bool useVpn}) async {
    startCalls++;
    running = true;
    mode = useVpn ? 'vpn' : 'proxy';
    recordedServiceAlive = true;
    activeRuntimeOwner = true;
    runtimeGeneration++;
    if (!firstStart.isCompleted) {
      firstStart.complete();
    }
  }

  @override
  Future<Map<String, dynamic>> status() async {
    return <String, dynamic>{
      'running': running,
      'mode': mode,
      'runtimeGeneration': runtimeGeneration,
      'recordedServiceAlive': recordedServiceAlive,
      'activeRuntimeOwner': activeRuntimeOwner,
    };
  }

  @override
  Future<void> stop({required String reason}) async {
    stopCalls++;
    running = false;
    recordedServiceAlive = false;
    activeRuntimeOwner = false;
    runtimeGeneration = 0;
  }
}
