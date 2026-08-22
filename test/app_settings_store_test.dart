import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';

void main() {
  test('defaults to stable runtime values', () {
    final state = _TestSettingsStore().mapState(const <String, dynamic>{});

    expect(state.urlTestIntervalSeconds, 1800);
    expect(state.urlTestTimeoutSeconds, 15);
    expect(state.urlTestConcurrency, 8);
    expect(state.urlTestUnavailableCheckIntervalSeconds, 120);
    expect(state.urlTestUrl, defaultUrlTestUrl);
    expect(state.locationLookupLimit, 1);
    expect(state.locationLookupTimeoutSeconds, 3);
    expect(state.locationLookupConcurrency, 1);
    expect(state.russiaDnsDirectResolver, defaultRussiaDnsDirectResolver);
    expect(state.memoryLimitEnabled, isTrue);
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
    expect(state.urlTestConcurrency, 8);
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
    expect(standard.urlTestConcurrency, 8);
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
    expect(economy.urlTestConcurrency, 8);
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
}

final class _TestSettingsStore extends AppSettingsStore {
  @override
  Future<void> close() async {}

  @override
  Future<AppSettingsState> loadState() async => mapState(const {});

  @override
  Future<void> saveState(AppSettingsState state) async {}
}
