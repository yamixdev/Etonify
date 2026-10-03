import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/app/runtime_lifecycle_controller.dart';
import 'package:meow_client/app/singbox_config_coordinator.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/singbox/singbox_config_builder.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

void main() {
  test('confirmed ordinary startup records the applied config', () async {
    final runtime = _BlockingRuntime();
    final lifecycle = RuntimeLifecycleController(runtime: runtime);
    addTearDown(lifecycle.dispose);
    final coordinator = _coordinator(runtimeLifecycle: lifecycle);

    final starting = coordinator.startRuntimeWithBuild(
      _build('first'),
      useVpn: true,
    );
    await runtime.firstApplyStarted.future;
    expect(coordinator.lastApplyResult.reason, 'not_applied_yet');
    runtime.releaseFirstApply.complete();
    expect((await starting).success, isTrue);
    expect(
      coordinator.lastApplyResult.status,
      SingboxConfigApplyStatus.applied,
    );
    expect(coordinator.lastApplyResult.reason, 'runtime_start');
    expect(coordinator.lastApplyAtMillis, greaterThan(0));
  });

  test('failed ordinary startup records failure rather than applied', () async {
    final runtime = _FailingStartRuntime();
    final lifecycle = RuntimeLifecycleController(runtime: runtime);
    addTearDown(lifecycle.dispose);
    final coordinator = _coordinator(runtimeLifecycle: lifecycle);
    final result = await coordinator.startRuntimeWithBuild(
      _build('failed config'),
      useVpn: true,
    );
    expect(result.success, isFalse);
    expect(coordinator.lastApplyResult.status, SingboxConfigApplyStatus.failed);
    expect(
      coordinator.lastApplyResult.error,
      contains('ordinary start failed'),
    );
  });

  test(
    'prepared promotion error replaces the previous applied result',
    () async {
      final runtime = _BlockingRuntime();
      final lifecycle = RuntimeLifecycleController(runtime: runtime);
      addTearDown(lifecycle.dispose);
      final coordinator = _coordinator(runtimeLifecycle: lifecycle);
      expect(
        (await coordinator.startRuntimeWithBuild(
          _build('success'),
          useVpn: true,
        )).success,
        isTrue,
      );
      expect(
        coordinator.lastApplyResult.status,
        SingboxConfigApplyStatus.applied,
      );
      await expectLater(
        coordinator.startRuntimeWithBuild(
          _build('', configPath: 'candidate-without-target.json'),
          useVpn: true,
        ),
        throwsStateError,
      );
      expect(
        coordinator.lastApplyResult.status,
        SingboxConfigApplyStatus.failed,
      );
      expect(
        coordinator.lastApplyResult.error,
        contains('target path is unavailable'),
      );
      expect(runtime.startCalls, 1);
    },
  );

  test(
    'cache refresh restarts a service started while the build was pending',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'config-native-start-race-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/config.json');
      await target.writeAsString('old');
      final runtime = _BlockingRuntime();
      final lifecycle = RuntimeLifecycleController(runtime: runtime);
      addTearDown(lifecycle.dispose);
      var statusReads = 0;
      final coordinator = _coordinator(
        runtimeLifecycle: lifecycle,
        connected: false,
        readConfigPath: () async => target.path,
        readRuntimeStatus: () async => {
          'running': ++statusReads > 1,
          'mode': 'vpn',
          'recordedServiceAlive': statusReads > 1,
        },
      );
      final result = await coordinator.emitCurrentConfigLogAsync(
        'split routing settings changed',
        restartRuntime: true,
        applyWhenNativeRunning: true,
        forceFullServiceRestart: true,
        refreshCachedConfig: true,
      );
      expect(result.status, SingboxConfigApplyStatus.applied);
      expect(runtime.stopCalls, 1);
      expect(runtime.startCalls, 1);
      expect(statusReads, greaterThanOrEqualTo(3));
    },
  );
  test('migration interlock rejects native apply and direct start', () async {
    final runtime = _BlockingRuntime();
    final lifecycle = RuntimeLifecycleController(runtime: runtime);
    addTearDown(lifecycle.dispose);
    final coordinator = _coordinator(
      runtimeLifecycle: lifecycle,
      allowRuntimeApply: () => false,
    );
    final emitted = await coordinator.emitCurrentConfigLogAsync(
      'migration',
      restartRuntime: true,
    );
    expect(emitted.superseded, isTrue);
    final applied = await coordinator.applyRuntimeConfig(
      build: _build('must not apply'),
      useVpn: true,
      restartRuntime: true,
    );
    expect(applied.superseded, isTrue);
    final started = await coordinator.startRuntimeWithBuild(
      _build('must not start'),
      useVpn: true,
    );
    expect(started.success, isFalse);
    expect(runtime.appliedConfigs, isEmpty);
  });
  test(
    'migration invalidates native cached config without starting VPN',
    () async {
      final dir = await Directory.systemTemp.createTemp('config-reset-test-');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/config.json');
      await target.writeAsString('old split routing');
      final lifecycle = RuntimeLifecycleController(
        runtime: _FailingPreparedRuntime(),
      );
      addTearDown(lifecycle.dispose);
      final coordinator = _coordinator(
        runtimeLifecycle: lifecycle,
        readConfigPath: () async => target.path,
      );
      await coordinator.invalidateCachedRuntimeConfig();
      expect(await target.exists(), isFalse);
      await coordinator.invalidateCachedRuntimeConfig();
    },
  );
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

  test(
    'superseded apply that already reached the core keeps its config file',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'etonify-config-supersede-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final target = File('${temp.path}/config.json')..writeAsStringSync('old');
      final candidate = File('${temp.path}/candidate.json')
        ..writeAsStringSync('new');
      final runtime = _SupersedingPreparedRuntime();
      final lifecycle = RuntimeLifecycleController(
        runtime: runtime,
        healthCheckTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(lifecycle.dispose);
      final coordinator = _coordinator(
        runtimeLifecycle: lifecycle,
        readConfigPath: () async => target.path,
      );
      addTearDown(coordinator.dispose);
      runtime.onApply = () async => coordinator.cancelPendingWork(
        reason: 'newer settings change requested',
      );

      final result = await coordinator.applyRuntimeConfig(
        build: _build('', configPath: candidate.path),
        useVpn: true,
        restartRuntime: true,
      );

      expect(result.status, SingboxConfigApplyStatus.superseded);
      expect(target.readAsStringSync(), 'new');
      expect(
        temp.listSync().whereType<File>().map((file) => file.path),
        everyElement(isNot(contains('.rollback.'))),
      );
    },
  );

  test('transient config path failure is not memoised', () async {
    var remainingFailures = 1;
    final lifecycle = RuntimeLifecycleController(runtime: _BlockingRuntime());
    addTearDown(lifecycle.dispose);
    final coordinator = _coordinator(
      runtimeLifecycle: lifecycle,
      readConfigPath: () async {
        if (remainingFailures > 0) {
          remainingFailures--;
          throw PlatformException(code: 'channel-error');
        }
        return '/data/user/0/com.example/config.json';
      },
    );
    addTearDown(coordinator.dispose);

    await expectLater(
      coordinator.ensureSingboxConfigPath(),
      throwsA(isA<PlatformException>()),
    );
    expect(
      await coordinator.ensureSingboxConfigPath(),
      '/data/user/0/com.example/config.json',
    );
  });

  test(
    'buildCurrentSingboxConfigInBackground retries capabilities if incompatible',
    () async {
      final runtime = _BlockingRuntime();
      final lifecycle = RuntimeLifecycleController(
        runtime: runtime,
        healthCheckTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(lifecycle.dispose);

      var refreshCalled = false;
      final coordinator = SingboxConfigCoordinator(
        readSnapshot: () =>
            _snapshot(capabilities: LibboxCapabilities.incompatible),
        isMounted: () => true,
        ensureActiveSubscriptionHydrated: () async => true,
        runtimeLifecycle: lifecycle,
        applyStartupValidationResult: (_, _) => true,
        showNoValidOutboundsWarning: () {},
        setPhase: (_) {},
        showRuntimeFailure: ({required bool timedOut}) {},
        logCall: (_, _) {},
        trimRuntimeStartMemory: (_) {},
        onRuntimeLifecycleTimeout: (_) {},
        cacheStartedBuild: (_) {},
        syncRuntimeState: () async {},
        refreshCapabilities: () async {
          refreshCalled = true;
          return LibboxCapabilities.bundledLegacy;
        },
        readConfigPath: () async => null,
      );

      final build = await coordinator.buildCurrentSingboxConfigInBackground(
        prepareConfig: false,
        validateConfig: false,
      );

      expect(refreshCalled, isTrue);
      expect(build, isNotNull);
    },
  );
  test(
    'cached coordinator build rejects settings changed before promotion',
    () async {
      final dir = Directory.systemTemp.createTempSync('config-state-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final target = File('${dir.path}/config.json')
        ..writeAsStringSync('previous');
      final lifecycle = RuntimeLifecycleController(runtime: _BlockingRuntime());
      addTearDown(lifecycle.dispose);
      var mtu = 1500;
      final coordinator = _coordinator(
        runtimeLifecycle: lifecycle,
        readConfigPath: () async => target.path,
        snapshot: () => _snapshot(mtu: mtu),
      );
      addTearDown(coordinator.dispose);
      final build = (await coordinator.buildCurrentSingboxConfigInBackground(
        validateConfig: false,
      ))!;
      mtu = 1400;
      await expectLater(
        coordinator.promotePreparedConfigBuild(build),
        throwsStateError,
      );
      expect(target.readAsStringSync(), 'previous');
      expect(File(build.configPath!).existsSync(), isFalse);
      final updated = (await coordinator.buildCurrentSingboxConfigInBackground(
        validateConfig: false,
      ))!;
      expect(updated.reusedConfig, isFalse);
      await coordinator.promotePreparedConfigBuild(updated);
      final cached = (await coordinator.buildCurrentSingboxConfigInBackground(
        validateConfig: false,
      ))!;
      expect(cached.reusedConfig, isTrue);
      await coordinator.promotePreparedConfigBuild(cached);
    },
  );

  test('cancelling prepared build preserves the active config', () async {
    final dir = Directory.systemTemp.createTempSync('config-cancel-test-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final target = File('${dir.path}/config.json')
      ..writeAsStringSync('previous');
    final lifecycle = RuntimeLifecycleController(runtime: _BlockingRuntime());
    addTearDown(lifecycle.dispose);
    final coordinator = _coordinator(
      runtimeLifecycle: lifecycle,
      readConfigPath: () async => target.path,
    );
    addTearDown(coordinator.dispose);
    final build = (await coordinator.buildCurrentSingboxConfigInBackground(
      validateConfig: false,
    ))!;
    coordinator.cancelPendingWork(reason: 'test');
    await expectLater(
      coordinator.promotePreparedConfigBuild(build),
      throwsStateError,
    );
    expect(target.readAsStringSync(), 'previous');
    expect(File(build.configPath!).existsSync(), isFalse);
  });

  test('probe build has no inbound and keeps a stable fingerprint', () async {
    final lifecycle = RuntimeLifecycleController(runtime: _BlockingRuntime());
    addTearDown(lifecycle.dispose);
    final coordinator = _coordinator(runtimeLifecycle: lifecycle);
    addTearDown(coordinator.dispose);

    final probe = await coordinator.buildProbeConfig(validateConfig: false);
    expect(probe, isNotNull);
    expect(probe!.build.plan.config['inbounds'], isEmpty);
    expect(probe.build.configJson, isNot(contains('tun-in')));
    expect(probe.probeFingerprint, isNotEmpty);
  });

  test('real VPN and probe builds share a handoff fingerprint', () async {
    final lifecycle = RuntimeLifecycleController(runtime: _BlockingRuntime());
    addTearDown(lifecycle.dispose);
    final coordinator = _coordinator(runtimeLifecycle: lifecycle);
    addTearDown(coordinator.dispose);

    final vpn = await coordinator.buildCurrentSingboxConfigInBackground(
      prepareConfig: false,
      returnConfig: true,
      validateConfig: false,
    );
    final probe = await coordinator.buildProbeConfig(validateConfig: false);
    expect(vpn, isNotNull);
    expect(probe, isNotNull);
    expect(
      probeFingerprintForConfig(vpn!.plan.config),
      probe!.probeFingerprint,
    );
  });

  test('probe fingerprint ignores selector and TUN-only differences', () {
    final probe = <String, dynamic>{
      'inbounds': <Object>[],
      'outbounds': [
        {'type': 'selector', 'tag': 'select', 'default': 'a'},
        {'type': 'vless', 'tag': 'a', 'server': 'example.com'},
      ],
      'dns': {'servers': <Object>[]},
      'route': {'rules': <Object>[]},
    };
    final vpn = <String, dynamic>{
      ...probe,
      'inbounds': [
        {'type': 'tun', 'tag': 'tun-in', 'mtu': 9000},
      ],
      'outbounds': [
        {'type': 'selector', 'tag': 'select', 'default': 'b'},
        {'type': 'vless', 'tag': 'a', 'server': 'example.com'},
      ],
      'dns': {'servers': <Object>[], 'strategy': 'ipv4_only'},
      'route': {
        'rules': [
          {'inbound': 'tun-in', 'action': 'reject'},
        ],
      },
    };
    expect(probeFingerprintForConfig(probe), probeFingerprintForConfig(vpn));
  });
}

SingboxConfigCoordinator _coordinator({
  required RuntimeLifecycleController runtimeLifecycle,
  bool connected = true,
  Duration fullServiceRestartDebounce = const Duration(milliseconds: 450),
  SingboxConfigPathReader? readConfigPath,
  bool Function()? allowRuntimeApply,
  SingboxRuntimeStatusReader? readRuntimeStatus,
  SingboxConfigCoordinatorSnapshot Function()? snapshot,
}) {
  return SingboxConfigCoordinator(
    readSnapshot: snapshot ?? () => _snapshot(connected: connected),
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
    readRuntimeStatus:
        readRuntimeStatus ??
        () async => const <String, dynamic>{
          'running': true,
          'mode': 'vpn',
          'recordedServiceAlive': true,
          'runtimeIntentFresh': true,
        },
    readConfigPath: readConfigPath,
    allowRuntimeApply: allowRuntimeApply,
    fullServiceRestartDebounce: fullServiceRestartDebounce,
  );
}

SingboxConfigCoordinatorSnapshot _snapshot({
  bool connected = true,
  int mtu = 9000,
  LibboxCapabilities capabilities = LibboxCapabilities.bundledLegacy,
}) {
  return SingboxConfigCoordinatorSnapshot(
    connected: connected,
    capabilities: capabilities,
    runtimeTransitionInProgress: false,
    activeSubscription: null,
    selectedProxyTag: '',
    excludedOutboundTags: <String>{},
    vpnInboundEnabled: true,
    vpnMtu: mtu,
    vpnStrictRoute: false,
    vpnEnableIpv6: false,
    vpnTunImplementation: TunImplementationPreference.native,
    proxyInboundEnabled: false,
    proxyMixedListen: '127.0.0.1',
    proxyMixedPort: 2080,
    dnsDirectResolver: 'local',
    dnsProxyResolver: 'https://dns.google/dns-query',
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

class _FailingStartRuntime extends _BlockingRuntime {
  @override
  Future<void> start({required String config, required bool useVpn}) async {
    throw StateError('ordinary start failed');
  }
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

/// Applies the prepared config successfully, but lets the test supersede the
/// running generation while the native call is still in flight.
class _SupersedingPreparedRuntime extends _BlockingRuntime {
  Future<void> Function()? onApply;

  @override
  Future<void> applyPreparedConfig({
    required bool useVpn,
    required bool restartCore,
  }) async {
    await onApply?.call();
    _confirmCoreRestart(useVpn: useVpn);
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
  Stream<Map<String, dynamic>> get events => const Stream.empty();

  @override
  Future<void> applyConfig({
    required String config,
    required bool useVpn,
    required bool restartCore,
  }) async {
    await _trackConfigApply(config);
    if (restartCore) {
      _confirmCoreRestart(useVpn: useVpn);
    }
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
  }) async {
    if (restartCore) {
      _confirmCoreRestart(useVpn: useVpn);
    }
  }

  void _confirmCoreRestart({required bool useVpn}) {
    running = true;
    mode = useVpn ? 'vpn' : 'proxy';
    recordedServiceAlive = true;
    activeRuntimeOwner = true;
    runtimeGeneration++;
  }

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
