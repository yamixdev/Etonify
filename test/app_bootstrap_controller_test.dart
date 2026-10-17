import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_bootstrap_controller.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

void main() {
  test('deferred core handshake does not hold durable UI state', () async {
    final core = Completer<LibboxCapabilities>();
    final controller = AppBootstrapController(
      fallbackClientVersionLabel: '0.3.9',
      loadAppVersionInfo: () async => const AppVersionInfo(
        packageName: '',
        versionName: '0.3.9',
        versionCode: 39,
      ),
      loadCoreCapabilities: () => core.future,
    );
    final result = await controller
        .load(
          providedStore: MemoryAppSettingsStore(),
          deferCoreCapabilities: true,
        )
        .timeout(const Duration(seconds: 1));
    expect(result.coreCapabilities.isCompatible, isFalse);
    expect(result.pendingCoreConfigMigration, isNull);
    expect(result.state.localeCode, 'system');
    core.complete(LibboxCapabilities.bundledLegacy);
    expect(
      await result.deferredCoreCapabilities,
      same(LibboxCapabilities.bundledLegacy),
    );
  });
  test('unanswered version request has a bounded startup wait', () async {
    final pending = Completer<AppVersionInfo>();
    final controller = AppBootstrapController(
      fallbackClientVersionLabel: '0.3.9',
      loadAppVersionInfo: () => pending.future,
      loadCoreCapabilities: () async => LibboxCapabilities.bundledLegacy,
    );
    final result = await controller
        .load(providedStore: MemoryAppSettingsStore())
        .timeout(const Duration(seconds: 2));
    expect(result.appVersionInfo.versionName, '0.3.9');
    expect(result.appVersionInfo.versionCode, 0);
    pending.complete(
      const AppVersionInfo(
        packageName: 'stale',
        versionName: '0.1.0',
        versionCode: 1,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(result.appVersionInfo.versionCode, 0);
  });

  test('failed version refresh retains previously verified metadata', () async {
    var fail = false;
    final controller = AppBootstrapController(
      fallbackClientVersionLabel: '0.3.9',
      loadAppVersionInfo: () async {
        if (fail) throw StateError('bridge detached');
        return const AppVersionInfo(
          packageName: 'com.etonify.meow_client',
          versionName: '0.3.9',
          versionCode: 39,
        );
      },
    );
    await controller.readAppVersionInfo();
    fail = true;
    final result = await controller.readAppVersionInfo();
    expect(result.versionCode, 39);
    expect(result.packageName, 'com.etonify.meow_client');
  });

  test(
    'deferred handshake errors stay incompatible without losing settings',
    () async {
      final core = Completer<LibboxCapabilities>();
      final controller = AppBootstrapController(
        fallbackClientVersionLabel: '0.3.9',
        loadAppVersionInfo: () async => const AppVersionInfo(
          packageName: '',
          versionName: '0.3.9',
          versionCode: 39,
        ),
        loadCoreCapabilities: () => core.future,
      );
      final store = MemoryAppSettingsStore();
      final result = await controller.load(
        providedStore: store,
        deferCoreCapabilities: true,
      );
      core.completeError(StateError('engine detached'));
      expect((await result.deferredCoreCapabilities)!.isCompatible, isFalse);
      expect(result.store, same(store));
      expect(
        (await store.loadState()).coreConfigSchemaVersion,
        result.state.coreConfigSchemaVersion,
      );
    },
  );
  test(
    'legacy split routing is reset once without disabling auto-connect',
    () async {
      final store = MemoryAppSettingsStore();
      final initial = await store.loadState();
      await store.saveState(
        initial.copyWith(
          splitRoutingMode: SplitRoutingMode.proxySelected,
          splitRoutingPackages: ['com.google.android.youtube'],
          autoConnectOnLaunch: true,
        ),
      );
      final controller = AppBootstrapController(
        fallbackClientVersionLabel: '0.3.7',
        loadCoreCapabilities: () async => LibboxCapabilities.bundledLegacy,
      );
      final result = await controller.load(providedStore: store);
      expect(result.state.splitRoutingMode, SplitRoutingMode.disabled);
      expect(result.state.splitRoutingPackages, isEmpty);
      expect(result.state.autoConnectOnLaunch, isTrue);
      expect(
        (await store.loadState()).splitRoutingMode,
        SplitRoutingMode.disabled,
      );

      await store.saveState(
        result.state.copyWith(
          splitRoutingMode: SplitRoutingMode.proxySelected,
          splitRoutingPackages: ['org.mozilla.firefox'],
        ),
      );
      final next = await controller.load(providedStore: store);
      expect(next.state.splitRoutingMode, SplitRoutingMode.proxySelected);
      expect(next.state.splitRoutingPackages, ['org.mozilla.firefox']);
    },
  );
  test('memory bootstrap skips durable storage initialization', () async {
    var hiveInitialized = false;
    var subscriptionsInitialized = false;
    var durableStoreOpened = false;
    final controller = AppBootstrapController(
      fallbackClientVersionLabel: '0.3.0',
      initializeHive: () async => hiveInitialized = true,
      initializeSubscriptions: () async => subscriptionsInitialized = true,
      openSettingsStore: () async {
        durableStoreOpened = true;
        return MemoryAppSettingsStore();
      },
      loadAppVersionInfo: () async => const AppVersionInfo(
        packageName: 'com.etonify.meow_client',
        versionName: '0.3.0',
        versionCode: 12,
      ),
      loadCoreCapabilities: () async => LibboxCapabilities.bundledLegacy,
    );

    final result = await controller.load(
      providedStore: MemoryAppSettingsStore(),
    );

    expect(result.usesInMemoryStore, isTrue);
    expect(result.ownsStore, isFalse);
    expect(result.appVersionInfo.versionName, '0.3.0');
    expect(result.state.localeCode, 'system');
    expect(hiveInitialized, isFalse);
    expect(subscriptionsInitialized, isFalse);
    expect(durableStoreOpened, isFalse);
  });

  test('failed owned store is closed before fallback is used', () async {
    final failingStore = _FailingSettingsStore();
    final controller = AppBootstrapController(
      fallbackClientVersionLabel: '0.3.0',
      initializeHive: () async {},
      initializeSubscriptions: () async {},
      openSettingsStore: () async => failingStore,
      loadAppVersionInfo: () async => const AppVersionInfo(
        packageName: '',
        versionName: '0.3.0',
        versionCode: 0,
      ),
      loadCoreCapabilities: () async => LibboxCapabilities.bundledLegacy,
    );

    if (Platform.isWindows) {
      await expectLater(controller.load(), throwsA(isA<StateError>()));
      expect(failingStore.closed, isTrue);
      return;
    }
    final result = await controller.load();

    expect(failingStore.closed, isTrue);
    expect(result.store, isA<MemoryAppSettingsStore>());
    expect(result.ownsStore, isTrue);
    expect(result.state.vpnInboundEnabled, isTrue);
  });

  test('native metadata failures fall back without blocking startup', () async {
    final controller = AppBootstrapController(
      fallbackClientVersionLabel: '0.3.0',
      loadAppVersionInfo: () async => throw StateError('version unavailable'),
      loadCoreCapabilities: () async => throw StateError('core unavailable'),
    );

    final result = await controller.load(
      providedStore: MemoryAppSettingsStore(),
    );

    expect(result.appVersionInfo.versionName, '0.3.0');
    expect(result.appVersionInfo.versionCode, 0);
    expect(result.coreCapabilities, same(LibboxCapabilities.incompatible));
  });
  test(
    'late owned settings store is closed after subscription startup fails',
    () async {
      final settings = Completer<AppSettingsStore>();
      final failedStore = _FailingSettingsStore();
      final failure = StateError('subscription storage unavailable');
      final controller = AppBootstrapController(
        fallbackClientVersionLabel: '0.3.0',
        initializeHive: () async {},
        initializeSubscriptions: () async => throw failure,
        openSettingsStore: () => settings.future,
      );
      final result = expectLater(controller.load(), throwsA(same(failure)));
      await Future<void>.delayed(Duration.zero);
      settings.complete(failedStore);
      await result;
      expect(failedStore.closed, isTrue);
    },
    skip: !Platform.isWindows,
  );

  test('opens encrypted storage before the core capability bridge', () async {
    final order = <String>[];
    final storageReady = Completer<void>();
    final controller = AppBootstrapController(
      fallbackClientVersionLabel: '0.3.0',
      initializeHive: () async => order.add('hive'),
      initializeSubscriptions: () async {
        order.add('subscriptions');
        await storageReady.future;
      },
      openSettingsStore: () async {
        order.add('settings');
        return MemoryAppSettingsStore();
      },
      loadAppVersionInfo: () async => const AppVersionInfo(
        packageName: '',
        versionName: '0.3.0',
        versionCode: 0,
      ),
      loadCoreCapabilities: () async {
        order.add('capabilities');
        return LibboxCapabilities.bundledLegacy;
      },
    );

    final load = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(order, ['hive', 'subscriptions', 'settings']);

    storageReady.complete();
    await load;
    expect(order.last, 'capabilities');
  });

  test('disabled rule-set status is deferred until after bootstrap', () async {
    var adBlockRequests = 0;
    var russiaRouteRequests = 0;
    final controller = AppBootstrapController(
      fallbackClientVersionLabel: '0.3.0',
      loadAppVersionInfo: () async => const AppVersionInfo(
        packageName: '',
        versionName: '0.3.0',
        versionCode: 0,
      ),
      loadCoreCapabilities: () async => LibboxCapabilities.bundledLegacy,
      loadAdBlockStatus: () async {
        adBlockRequests++;
        throw StateError('ad block status unavailable');
      },
      loadRussiaRouteStatus: () async {
        russiaRouteRequests++;
        throw StateError('russia route status unavailable');
      },
    );

    final result = await controller.load(
      providedStore: MemoryAppSettingsStore(),
    );

    expect(result.adBlockStatus.available, isFalse);
    expect(result.russiaRouteDataStatus.available, isFalse);
    expect(adBlockRequests, 0);
    expect(russiaRouteRequests, 0);

    await controller.loadDeferredStatuses();

    expect(adBlockRequests, 1);
    expect(russiaRouteRequests, 1);
  });

  test('enabled rule-set status is deferred until after bootstrap', () async {
    var adBlockRequests = 0;
    var russiaRouteRequests = 0;
    final store = MemoryAppSettingsStore();
    await store.saveState(
      (await store.loadState()).copyWith(
        adBlockEnabled: true,
        useRussiaRouteData: true,
      ),
    );
    final controller = AppBootstrapController(
      fallbackClientVersionLabel: '0.3.0',
      loadAppVersionInfo: () async => const AppVersionInfo(
        packageName: '',
        versionName: '0.3.0',
        versionCode: 0,
      ),
      loadCoreCapabilities: () async => LibboxCapabilities.bundledLegacy,
      loadAdBlockStatus: () async {
        adBlockRequests++;
        throw StateError('ad block status unavailable');
      },
      loadRussiaRouteStatus: () async {
        russiaRouteRequests++;
        throw StateError('russia route status unavailable');
      },
    );

    final result = await controller.load(providedStore: store);

    expect(result.adBlockStatus.available, isFalse);
    expect(result.russiaRouteDataStatus.available, isFalse);
    expect(adBlockRequests, 0);
    expect(russiaRouteRequests, 0);

    await controller.loadDeferredStatuses(
      includeAdBlock: true,
      includeRussiaRouteData: true,
    );

    expect(adBlockRequests, 1);
    expect(russiaRouteRequests, 1);
  });
}

class _FailingSettingsStore extends AppSettingsStore {
  bool closed = false;

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<AppSettingsState> loadState() async {
    throw StateError('settings unavailable');
  }

  @override
  Future<void> saveState(AppSettingsState state) async {}
}
