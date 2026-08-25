import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_bootstrap_controller.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

void main() {
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
