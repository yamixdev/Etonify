import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/vm/storage_backend_vm.dart';
import 'package:hive_ce/src/box/box_base_impl.dart';
import 'package:meow_client/models/core_settings.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/data/update/app_update_channel.dart';
import 'package:meow_client/platform/windows/desktop_preferences.dart';
import 'package:flutter/services.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'package:meow_client/data/local/secure_hive_storage.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _SettingsTestPaths extends PathProviderPlatform {
  _SettingsTestPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

// Observe real Hive disk writes/fsync through its existing backend testing hook.
// Encoding, box state, saveState and flushing remain the production code paths.
class _CountingSettingsFile extends Fake implements RandomAccessFile {
  _CountingSettingsFile(this.delegate);
  final RandomAccessFile delegate;
  int flushCalls = 0;
  @override
  Future<RandomAccessFile> flush() async {
    flushCalls++;
    return delegate.flush();
  }

  @override
  Future<RandomAccessFile> writeFrom(
    List<int> buffer, [
    int start = 0,
    int? end,
  ]) => delegate.writeFrom(buffer, start, end);
  @override
  Future<RandomAccessFile> setPosition(int position) =>
      delegate.setPosition(position);
  @override
  Future<RandomAccessFile> truncate(int length) => delegate.truncate(length);
  @override
  Future<int> length() => delegate.length();
  @override
  Future<void> close() => delegate.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'unchanged Hive settings do not write or flush Windows namespace',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'etonify-settings-noop-',
      );
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _SettingsTestPaths(directory.path);
      HiveAppSettingsStore? store;
      StorageBackendVm? backend;
      RandomAccessFile? originalFile;
      try {
        if (Platform.isWindows) {
          const channel = MethodChannel('etonify/windows_storage');
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async => null);
          final paths = await AppDataPaths.resolve(
            DesktopLaunchContext(
              installationId: 'fixture',
              distribution: DesktopDistribution.portable,
              dataRoot: directory.path,
              startedAtLogin: false,
              minimized: false,
              ownerPid: 1,
            ),
          );
          await SecureHiveStorage.initWindows(paths, portable: true);
        }
        store = await HiveAppSettingsStore.open();
        final state = (await store.loadState()).copyWith(
          windowsUnknown: {
            'future': {
              'items': ['one', 'two'],
              'empty': null,
            },
          },
        );
        await store.saveState(state);
        final box =
            Hive.box<dynamic>(AppSettingsStore.boxName) as BoxBaseImpl<dynamic>;
        // ignore: invalid_use_of_protected_member
        backend = box.backend as StorageBackendVm;
        originalFile = backend.writeRaf;
        final observed = _CountingSettingsFile(originalFile);
        backend.writeRaf = observed;
        final fileLength = await observed.length();
        await store.saveState(await store.loadState());
        expect(
          observed.flushCalls,
          0,
          reason:
              'content-identical Windows maps must not schedule putAll/flush',
        );
        expect(await observed.length(), fileLength);

        final current = await store.loadState();
        await store.saveState(
          current.copyWith(
            windowsModes: current.windowsModes.copyWith(tunEnabled: true),
          ),
        );
        expect(observed.flushCalls, 1);
        expect((await store.loadState()).windowsModes.tunEnabled, true);
        expect(await observed.length(), greaterThan(fileLength));
        await store.saveState(await store.loadState());
        expect(observed.flushCalls, 1);

        await store.saveState(
          current.copyWith(
            windowsModes: current.windowsModes.copyWith(tunEnabled: true),
            windowsUnknown: {
              'future': {
                'items': ['one', 'changed'],
                'empty': null,
              },
            },
          ),
        );
        expect(observed.flushCalls, 2);
        expect((await store.loadState()).windowsUnknown, {
          'future': {
            'items': ['one', 'changed'],
            'empty': null,
          },
        });
      } finally {
        if (backend != null && originalFile != null) {
          backend.writeRaf = originalFile;
        }
        await store?.close();
        await Hive.close();
        PathProviderPlatform.instance = originalPaths;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('etonify/windows_storage'),
              null,
            );
        await directory.delete(recursive: true);
      }
    },
  );
  test('Windows namespace survives settings and backup round trips', () {
    final store = _TestSettingsStore();
    final original = store.mapState({
      'windows': {
        'modes': {'tunEnabled': true, 'futureMode': 7},
        'presentation': {'proxyListStyle': 'comfortable', 'futureStyle': 9},
        'futureNamespace': {'value': 11},
      },
    });
    final restored = store.mapState(store.stateToMap(original));
    final imported = store.mergeSafeImportMap(
      store.mapState({}),
      store.stateToSafeExportMap(restored),
    );
    expect(store.stateToMap(imported)['windows'], isA<Map<String, dynamic>>());
    final block = store.stateToMap(imported)['windows'] as Map<String, dynamic>;
    expect((block['modes'] as Map)['tunEnabled'], true);
    expect((block['modes'] as Map)['futureMode'], 7);
    expect((block['presentation'] as Map)['proxyListStyle'], 'comfortable');
    expect(block['futureNamespace'], {'value': 11});
    expect(imported.vpnInboundEnabled, original.vpnInboundEnabled);
    final controller = AppSettingsController()..applyState(imported);
    controller.hapticEnabled = false;
    final saved = controller.toState(
      onboardingCompleted: false,
      acceptedLegalVersion: '',
      acceptedLegalAtMillis: null,
      activeProfileId: '',
      selectedProxyTag: '',
    );
    expect(store.stateToMap(saved)['windows'], block);
    expect(saved.hapticEnabled, false);
    expect(saved.copyWith(localeCode: 'ru').windowsModes.tunEnabled, true);
    expect(saved.copyWith(localeCode: 'ru').windowsUnknown, {
      'futureNamespace': {'value': 11},
    });
  });
  test('Android fixture retains defaults without Windows namespace', () async {
    final store = _TestSettingsStore();
    final android = store.mapState({
      'vpn_inbound_enabled': '1',
      'proxy_inbound_enabled': '0',
      'vpn_mtu': '1500',
    });
    expect(android.vpnInboundEnabled, true);
    expect(android.proxyInboundEnabled, false);
    expect(android.vpnMtu, 1500);
    expect(android.windowsModes.tunEnabled, false);
    expect(android.windowsModes.launchMinimized, true);
    expect(android.windowsPresentation.proxyListStyle, ProxyListStyle.compact);
    final memory = MemoryAppSettingsStore(android);
    final changed = android.copyWith(
      windowsModes: android.windowsModes.copyWith(tunEnabled: true),
      windowsPresentation: android.windowsPresentation.copyWith(
        proxyListStyle: ProxyListStyle.comfortable,
      ),
    );
    await memory.saveState(changed);
    final restored = await memory.loadState();
    expect(restored.windowsModes.tunEnabled, true);
    expect(
      restored.windowsPresentation.proxyListStyle,
      ProxyListStyle.comfortable,
    );
    expect(restored.vpnInboundEnabled, true);
    await memory.close();
  });
  test(
    'legacy split import replaces active bank and preserves migration metadata',
    () {
      final store = _TestSettingsStore();
      final current = store
          .mapState({})
          .copyWith(
            splitRoutingSchemaVersion: 1,
            splitRoutingResetPending: true,
            splitRoutingIncludedPackages: ['com.old.app'],
            splitRoutingExcludedPackages: ['com.other.app'],
          );
      final restored = store.mergeSafeImportMap(current, {
        'split_routing_mode': 'proxy_selected',
        'split_routing_packages': 'com.new.app',
        'split_routing_schema': '0',
        'split_routing_reset_pending': '0',
      });
      expect(restored.splitRoutingIncludedPackages, ['com.new.app']);
      expect(restored.splitRoutingExcludedPackages, ['com.other.app']);
      expect(restored.splitRoutingPackages, ['com.new.app']);
      expect(restored.splitRoutingSchemaVersion, 1);
      expect(restored.splitRoutingResetPending, isTrue);
    },
  );
  test(
    'core settings round trip and scoped reset retains entry acknowledgement',
    () {
      final store = _TestSettingsStore();
      final state = store
          .mapState({})
          .copyWith(
            coreSettings: const CoreSettings(
              connectTimeoutSeconds: 12,
              udpNatMax: 8192,
            ),
            coreSettingsNoticeAcknowledged: true,
          );
      final restored = store.mapState(store.stateToMap(state));
      expect(restored.coreSettings, state.coreSettings);
      expect(restored.coreSettingsNoticeAcknowledged, isTrue);
      final exported = store.stateToSafeExportMap(restored);
      expect(
        exported.containsKey('core_settings_notice_acknowledged'),
        isFalse,
      );
      expect(
        store.mergeSafeImportMap(store.mapState({}), exported).coreSettings,
        restored.coreSettings,
      );
      final controller = AppSettingsController()..applyState(restored);
      final change = controller.setCoreSettings(const CoreSettings());
      expect(change.forceFullServiceRestart, isTrue);
      expect(controller.coreSettings, const CoreSettings());
      expect(controller.coreSettingsNoticeAcknowledged, isTrue);
      expect(controller.dnsDirectResolver, state.dnsDirectResolver);
    },
  );
  test('HWID sharing consent persists locally but cannot be imported', () {
    final store = _TestSettingsStore();
    final off = store.mapState(const {
      'hwid_default_notice_shown': '1',
      'send_hwid_to_providers': '0',
    });
    expect(off.sendHwidToProviders, isFalse);
    final on = off.copyWith(sendHwidToProviders: true);
    expect(store.mapState(store.stateToMap(on)).sendHwidToProviders, isTrue);
    expect(
      store.stateToSafeExportMap(on).containsKey('send_hwid_to_providers'),
      isFalse,
    );
    expect(
      store.mergeSafeImportMap(off, {
        'send_hwid_to_providers': '1',
      }).sendHwidToProviders,
      isFalse,
    );
    expect(
      store.mergeSafeImportMap(on, {
        'send_hwid_to_providers': '0',
      }).sendHwidToProviders,
      isTrue,
    );
  });
  test('HWID defaults on but preserves an existing disabled value', () {
    final store = _TestSettingsStore();
    final empty = store.mapState(const {});
    expect(empty.sendHwidToProviders, isTrue);
    expect(empty.hwidDefaultNoticeShown, isFalse);

    final legacyOff = store.mapState(const {'send_hwid_to_providers': '0'});
    expect(legacyOff.sendHwidToProviders, isFalse);
    expect(legacyOff.hwidDefaultNoticeShown, isFalse);

    final explicitlyDisabled = store.mapState(const {
      'send_hwid_to_providers': '0',
      'hwid_default_notice_shown': '1',
    });
    expect(explicitlyDisabled.sendHwidToProviders, isFalse);
    expect(explicitlyDisabled.hwidDefaultNoticeShown, isTrue);
  });
  test('HWID disabled before notice acknowledgement survives a round trip', () {
    final store = _TestSettingsStore();
    final disabled = store
        .mapState(const {})
        .copyWith(sendHwidToProviders: false, hwidDefaultNoticeShown: false);
    final restored = store.mapState(store.stateToMap(disabled));
    expect(restored.sendHwidToProviders, isFalse);
    expect(restored.hwidDefaultNoticeShown, isFalse);
  });
  test('defaults to stable runtime values', () {
    final state = _TestSettingsStore().mapState(const <String, dynamic>{});

    expect(state.urlTestIntervalSeconds, 1800);
    expect(state.urlTestTimeoutSeconds, 15);
    expect(state.urlTestConcurrency, 10);
    expect(state.urlTestUnavailableCheckIntervalSeconds, 120);
    expect(state.urlTestUrl, defaultUrlTestUrl);
    expect(state.locationLookupLimit, 1);
    expect(state.locationLookupTimeoutSeconds, 3);
    expect(state.locationLookupConcurrency, 1);
    expect(state.russiaDnsDirectResolver, defaultRussiaDnsDirectResolver);
    expect(state.memoryLimitEnabled, isFalse);
    expect(state.memoryLimitWarningDismissed, isFalse);
    expect(state.statusNotificationEnabled, isTrue);
    expect(
      state.notificationTrafficDisplayMode,
      NotificationTrafficDisplayMode.speed,
    );
    expect(state.notificationTrafficRefreshSeconds, 2);
    expect(state.allowUntrustedProxyCertificates, isFalse);
    expect(state.allowUntrustedSubscriptionCertificates, isFalse);
  });

  test('persists TLS exceptions but never includes them in safe exports', () {
    final store = _TestSettingsStore();
    final state = store.mapState(const <String, dynamic>{
      'allow_untrusted_proxy_certificates': '1',
      'allow_untrusted_subscription_certificates': '1',
    });
    final persisted = store.stateToMap(state);
    final exported = store.stateToSafeExportMap(state);

    expect(state.allowUntrustedProxyCertificates, isTrue);
    expect(state.allowUntrustedSubscriptionCertificates, isTrue);
    expect(persisted['allow_untrusted_proxy_certificates'], '1');
    expect(persisted['allow_untrusted_subscription_certificates'], '1');
    expect(exported, isNot(contains('allow_untrusted_proxy_certificates')));
    expect(
      exported,
      isNot(contains('allow_untrusted_subscription_certificates')),
    );
  });

  test('persists the selected notification traffic display mode', () {
    final store = _TestSettingsStore();
    final state = store.mapState(const <String, dynamic>{
      'notification_traffic_display_mode': 'both',
    });
    final map = store.stateToMap(state);

    expect(
      state.notificationTrafficDisplayMode,
      NotificationTrafficDisplayMode.both,
    );
    expect(map['notification_traffic_display_mode'], 'both');
  });

  test('persists the selected update channel', () {
    final store = _TestSettingsStore();
    final state = store.mapState(const <String, dynamic>{
      'update_channel': 'beta',
    });
    final persisted = store.stateToMap(state);
    final exported = store.stateToSafeExportMap(state);

    expect(state.updateChannel, AppUpdateChannel.beta);
    expect(persisted['update_channel'], 'beta');
    expect(exported['update_channel'], 'beta');
    expect(
      store.mapState(const <String, dynamic>{
        'update_channel': 'unknown',
      }).updateChannel,
      AppUpdateChannel.stable,
    );
  });

  test('persists the single selected traffic rule preset', () {
    final store = _TestSettingsStore();
    final state = store.mapState(const <String, dynamic>{
      'traffic_rule_preset': 'social_via_vpn',
    });
    final map = store.stateToMap(state);

    expect(state.trafficRulePreset, TrafficRulePreset.socialViaVpn);
    expect(map['traffic_rule_preset'], 'social_via_vpn');
    expect(
      store.mapState(const <String, dynamic>{
        'traffic_rule_preset': 'unknown',
      }).trafficRulePreset,
      TrafficRulePreset.none,
    );
  });

  test('persists and bounds notification traffic refresh seconds', () {
    final store = _TestSettingsStore();
    final state = store.mapState(const <String, dynamic>{
      'notification_traffic_refresh_seconds': '20',
    });
    final map = store.stateToMap(state);

    expect(state.notificationTrafficRefreshSeconds, 10);
    expect(map['notification_traffic_refresh_seconds'], '10');
    expect(
      store.mapState(const <String, dynamic>{
        'notification_traffic_refresh_seconds': '0',
      }).notificationTrafficRefreshSeconds,
      1,
    );
    expect(
      store.stateToSafeExportMap(state)['notification_traffic_refresh_seconds'],
      '10',
    );
  });

  test(
    'drops removed performance mode from persisted and exported settings',
    () {
      final store = _TestSettingsStore();
      final state = store.mapState(const <String, dynamic>{
        'performance_mode': 'performance',
      });
      final map = store.stateToMap(state);
      final exported = store.stateToSafeExportMap(state);

      expect(map, isNot(contains('performance_mode')));
      expect(exported, isNot(contains('performance_mode')));
    },
  );

  test('migrates the removed economy preset to stable runtime values', () {
    final state = _TestSettingsStore().mapState(const <String, dynamic>{
      'performance_mode': 'economy',
      'urltest_interval_seconds': '3600',
      'urltest_concurrency': '4',
      'urltest_unavailable_check_interval_seconds': '300',
      'location_lookup_limit': '0',
    });

    expect(state.urlTestIntervalSeconds, 1800);
    expect(state.urlTestTimeoutSeconds, 15);
    expect(state.urlTestConcurrency, 10);
    expect(state.urlTestUnavailableCheckIntervalSeconds, 120);
    expect(state.locationLookupLimit, 1);
    expect(state.locationLookupTimeoutSeconds, 3);
    expect(state.locationLookupConcurrency, 1);
  });

  test('migrates old standard and economy URLTest defaults', () {
    final store = _TestSettingsStore();

    final standard = store.mapState(const <String, dynamic>{
      'performance_mode': 'standard',
      'url_test_interval_seconds': '900',
      'url_test_timeout_seconds': '10',
      'url_test_concurrency': '4',
      'urltest_unavailable_check_interval_seconds': '60',
      'location_lookup_concurrency': '1',
    });
    expect(standard.urlTestIntervalSeconds, 1800);
    expect(standard.urlTestTimeoutSeconds, 15);
    expect(standard.urlTestConcurrency, 10);
    expect(standard.urlTestUnavailableCheckIntervalSeconds, 120);
    expect(standard.locationLookupConcurrency, 1);

    final previousStandard = store.mapState(const <String, dynamic>{
      'performance_mode': 'standard',
      'urltest_interval_seconds': '120',
      'urltest_concurrency': '8',
      'urltest_unavailable_check_interval_seconds': '120',
    });
    expect(previousStandard.urlTestIntervalSeconds, 1800);
    expect(previousStandard.urlTestConcurrency, 8);
    expect(previousStandard.urlTestUnavailableCheckIntervalSeconds, 120);

    final economy = store.mapState(const <String, dynamic>{
      'performance_mode': 'economy',
      'url_test_interval_seconds': '1800',
      'url_test_timeout_seconds': '10',
      'url_test_concurrency': '2',
      'urltest_unavailable_check_interval_seconds': '120',
    });
    expect(economy.urlTestIntervalSeconds, 1800);
    expect(economy.urlTestTimeoutSeconds, 15);
    expect(economy.urlTestConcurrency, 10);
    expect(economy.urlTestUnavailableCheckIntervalSeconds, 120);
  });

  test('normalizes Russia route DNS resolver', () {
    final store = _TestSettingsStore();

    expect(
      store.mapState(const {
        'russia_dns_direct_resolver': 'udp://77.88.8.1',
      }).russiaDnsDirectResolver,
      'udp://77.88.8.1',
    );
    expect(
      store.mapState(const {
        'russia_dns_direct_resolver': '77.88.8.1',
      }).russiaDnsDirectResolver,
      'udp://77.88.8.1',
    );
    expect(
      store.mapState(const {
        'russia_dns_direct_resolver': 'bad resolver',
      }).russiaDnsDirectResolver,
      defaultRussiaDnsDirectResolver,
    );
  });

  test('normalizes plain custom DNS resolvers as UDP', () {
    final store = _TestSettingsStore();

    final state = store.mapState(const {
      'dns_direct_resolver': '1.1.1.1',
      'dns_proxy_resolver': 'dns.google:5353',
    });

    expect(state.dnsDirectResolver, 'udp://1.1.1.1');
    expect(state.dnsProxyResolver, 'udp://dns.google:5353');
  });

  test(
    'normalizes split routing packages to a bounded Android package list',
    () {
      final packages = normalizeSplitRoutingPackages([
        'Telegram',
        'com.example.app',
        'com.example.app',
        'com.etonify.meow_client',
        'bad package',
        '',
        ...List.generate(140, (index) => 'com.example.app$index'),
      ]);

      expect(packages.first, 'com.example.app');
      expect(packages, isNot(contains('com.etonify.meow_client')));
      expect(packages.length, maxSplitRoutingPackageCount);
    },
  );

  test('persists accepted legal document metadata', () {
    final store = _TestSettingsStore();
    final state = store.mapState(const <String, dynamic>{
      'accepted_legal_version': '0.2.0',
      'accepted_legal_at_millis': '1780000000000',
    });
    final map = store.stateToMap(state);

    expect(state.acceptedLegalVersion, '0.2.0');
    expect(state.acceptedLegalAtMillis, 1780000000000);
    expect(map['accepted_legal_version'], '0.2.0');
    expect(map['accepted_legal_at_millis'], '1780000000000');
  });

  test('persists memory limit runtime setting and warning state', () {
    final store = _TestSettingsStore();
    final state = store.mapState(const <String, dynamic>{
      'memory_limit_enabled': '0',
      'memory_limit_warning_dismissed': '1',
    });
    final map = store.stateToMap(state);

    expect(state.memoryLimitEnabled, isFalse);
    expect(state.memoryLimitWarningDismissed, isTrue);
    expect(map['memory_limit_enabled'], '0');
    expect(map['memory_limit_warning_dismissed'], '1');
  });

  test('persists notification status setting and keeps it in safe exports', () {
    final store = _TestSettingsStore();
    final state = store.mapState(const <String, dynamic>{
      'status_notification_enabled': '0',
    });

    expect(state.statusNotificationEnabled, isFalse);
    expect(store.stateToMap(state)['status_notification_enabled'], '0');
    expect(
      store.stateToSafeExportMap(state)['status_notification_enabled'],
      '0',
    );
  });

  test('persists TLS fragmentation mode', () {
    final store = _TestSettingsStore();
    final state = store.mapState(const <String, dynamic>{
      'tls_fragmentation_mode': 'record',
    });
    final map = store.stateToMap(state);

    expect(state.tlsFragmentationMode, TlsFragmentationMode.record);
    expect(map['tls_fragmentation_mode'], 'record');
    expect(
      store.mapState(const <String, dynamic>{
        'tls_fragmentation_mode': 'fragment',
      }).tlsFragmentationMode,
      TlsFragmentationMode.fragment,
    );
    expect(
      store.mapState(const <String, dynamic>{
        'tls_fragmentation_mode': 'unknown',
      }).tlsFragmentationMode,
      TlsFragmentationMode.disabled,
    );
  });

  test('stores proxy credentials and exports only the username', () {
    final store = _TestSettingsStore();
    final state = store.mapState(const <String, dynamic>{
      'proxy_username': 'sergey',
      'proxy_password': 'LocalOnlyPassword123456',
    });

    expect(state.proxyUsername, 'sergey');
    expect(state.proxyPassword, 'LocalOnlyPassword123456');
    expect(store.stateToMap(state)['proxy_username'], state.proxyUsername);
    expect(store.stateToMap(state)['proxy_password'], state.proxyPassword);
    expect(store.stateToSafeExportMap(state)['proxy_username'], 'sergey');
    expect(
      store.stateToSafeExportMap(state),
      isNot(contains('proxy_password')),
    );
    expect(
      store.mapState(const <String, dynamic>{
        'proxy_username': 'bad username',
      }).proxyUsername,
      defaultProxyUsername,
    );
  });

  test('persists proxy sorting preference and normalizes unknown values', () {
    final store = _TestSettingsStore();
    final working = store.mapState(const <String, dynamic>{
      'proxy_sort': 'working',
    });

    expect(working.proxySort, 'working');
    expect(store.stateToMap(working)['proxy_sort'], 'working');
    expect(store.stateToSafeExportMap(working)['proxy_sort'], 'working');
    expect(
      store.mapState(const <String, dynamic>{'proxy_sort': 'broken'}).proxySort,
      'source',
    );
  });

  test('persists and exports DNS protection parameters', () {
    final store = _TestSettingsStore();
    final state = store.mapState(const <String, dynamic>{
      'dns_secure_only': '1',
      'dns_direct_through_proxy': '1',
    });

    expect(state.dnsSecureOnly, isTrue);
    expect(state.dnsDirectThroughProxy, isTrue);
    expect(store.stateToMap(state)['dns_secure_only'], '1');
    expect(store.stateToMap(state)['dns_direct_through_proxy'], '1');
    expect(store.stateToSafeExportMap(state)['dns_secure_only'], '1');
    expect(store.stateToSafeExportMap(state)['dns_direct_through_proxy'], '1');
  });

  test('persists autoCheckServers and local notice acknowledgment', () {
    final store = _TestSettingsStore();
    final defaultState = store.mapState(const <String, dynamic>{});
    expect(defaultState.autoCheckServers, isFalse);
    expect(defaultState.autoCheckNoticeAcknowledged, isFalse);

    final enabled = defaultState.copyWith(
      autoCheckServers: true,
      autoCheckNoticeAcknowledged: true,
    );
    final mapped = store.stateToMap(enabled);
    expect(mapped['auto_check_servers'], '1');
    expect(mapped['auto_check_notice_acknowledged'], '1');

    final restored = store.mapState(mapped);
    expect(restored.autoCheckServers, isTrue);
    expect(restored.autoCheckNoticeAcknowledged, isTrue);

    final exported = store.stateToSafeExportMap(restored);
    expect(exported['auto_check_servers'], '1');
    expect(exported.containsKey('auto_check_notice_acknowledged'), isFalse);
  });

  test('auto-connect stays off by default and round-trips in settings', () {
    final store = _TestSettingsStore();
    final defaults = store.mapState(const <String, dynamic>{});
    expect(defaults.autoConnectOnLaunch, isFalse);

    final encoded = store.stateToMap(
      defaults.copyWith(autoConnectOnLaunch: true),
    );
    expect(encoded['auto_connect_on_launch'], '1');
    expect(store.mapState(encoded).autoConnectOnLaunch, isTrue);
    expect(
      store.stateToSafeExportMap(
        store.mapState(encoded),
      )['auto_connect_on_launch'],
      '1',
    );
  });

  test('stale pre-0.3.7 probe concurrency is rewritten exactly once', () {
    expect(
      AppSettingsStore.migratedUrlTestConcurrency(
        stored: '4',
        alreadyMigrated: false,
      ),
      AppSettingsStore.defaultUrlTestConcurrency,
    );
    expect(
      AppSettingsStore.migratedUrlTestConcurrency(
        stored: ' 4 ',
        alreadyMigrated: false,
      ),
      AppSettingsStore.defaultUrlTestConcurrency,
    );
    // Anything else is the user's own number, including a deliberate 4 chosen
    // after the rewrite and an absent value that already maps to the default.
    expect(
      AppSettingsStore.migratedUrlTestConcurrency(
        stored: null,
        alreadyMigrated: false,
      ),
      isNull,
    );
    expect(
      AppSettingsStore.migratedUrlTestConcurrency(
        stored: '8',
        alreadyMigrated: false,
      ),
      isNull,
    );
    expect(
      AppSettingsStore.migratedUrlTestConcurrency(
        stored: '4',
        alreadyMigrated: true,
      ),
      isNull,
    );
    // The marker is device state, so it must never leave through an export.
    expect(
      AppSettingsStore.safeExportKeys,
      isNot(contains('urltest_concurrency_default_migrated')),
    );
  });

  test('shouldCompactAppSettingsBox triggers when threshold is reached', () {
    expect(shouldCompactAppSettingsBox(50, 24), isFalse);
    expect(shouldCompactAppSettingsBox(50, 25), isFalse);
    expect(shouldCompactAppSettingsBox(25, 25), isTrue);
    expect(shouldCompactAppSettingsBox(20, 25), isTrue);
    expect(shouldCompactAppSettingsBox(50, 50), isTrue);
  });
}

final class _TestSettingsStore extends AppSettingsStore {
  @override
  Future<void> close() async {}

  @override
  Future<AppSettingsState> loadState() async => mapState(const {});

  @override
  Future<void> saveState(AppSettingsState state) async {}
}
