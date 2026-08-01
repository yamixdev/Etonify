import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/features/settings/settings_dns_page.dart';

void main() {
  test('performance preset updates URLTest and lookup defaults', () {
    final controller = AppSettingsController();

    final change = controller.setPerformanceMode(AppPerformanceMode.economy);

    expect(change.changed, isTrue);
    expect(change.configReason, 'performance mode changed');
    expect(change.syncRuntimePerformanceFlags, isTrue);
    expect(controller.urlTestConcurrency, appSettingsEconomyUrlTestConcurrency);
    expect(
      controller.locationLookupLimit,
      appSettingsEconomyLocationLookupLimit,
    );
  });

  test('notification status can be changed without a config rebuild', () {
    final controller = AppSettingsController();

    final change = controller.setStatusNotificationEnabled(false);

    expect(change.changed, isTrue);
    expect(change.configReason, isNull);
    expect(controller.statusNotificationEnabled, isFalse);
  });

  test('notification traffic display can change without a config rebuild', () {
    final controller = AppSettingsController();

    final change = controller.setNotificationTrafficDisplayMode(
      NotificationTrafficDisplayMode.both,
    );

    expect(change.changed, isTrue);
    expect(change.configReason, isNull);
    expect(
      controller.notificationTrafficDisplayMode,
      NotificationTrafficDisplayMode.both,
    );
  });

  test(
    'notification traffic refresh is bounded and needs no config rebuild',
    () {
      final controller = AppSettingsController();

      final change = controller.setNotificationTrafficRefreshSeconds(99);

      expect(change.changed, isTrue);
      expect(change.configReason, isNull);
      expect(controller.notificationTrafficRefreshSeconds, 10);
      expect(
        controller.setNotificationTrafficRefreshSeconds(-1).changed,
        isTrue,
      );
      expect(controller.notificationTrafficRefreshSeconds, 1);
    },
  );

  test('DNS preset updates resolver together with preset', () {
    final controller = AppSettingsController();

    final change = controller.setDnsDirectPreset('cloudflare_doh');

    expect(change.changed, isTrue);
    expect(change.configReason, 'dns direct preset changed');
    expect(controller.dnsDirectPreset, 'cloudflare_doh');
    expect(
      controller.dnsDirectResolver,
      'https://dns.cloudflare.com/dns-query',
    );
  });

  test('plain DNS address defaults to UDP', () {
    final controller = AppSettingsController();

    final directChange = controller.setDnsDirectResolver(' 1.1.1.1 ');
    final proxyChange = controller.setDnsProxyResolver('dns.google:5353');

    expect(directChange.changed, isFalse);
    expect(controller.dnsDirectResolver, 'udp://1.1.1.1');
    expect(proxyChange.changed, isTrue);
    expect(controller.dnsProxyResolver, 'udp://dns.google:5353');
    expect(
      AppSettingsController.normalizedRussiaDnsDirectResolver('77.88.8.1'),
      'udp://77.88.8.1',
    );
    expect(normalizeDnsResolverInput('8.8.8.8:5353'), 'udp://8.8.8.8:5353');
    expect(
      normalizeDnsResolverInput('2606:4700:4700::1111'),
      'udp://[2606:4700:4700::1111]',
    );
    expect(
      normalizeDnsResolverInput('[2606:4700:4700::1111]:5353'),
      'udp://[2606:4700:4700::1111]:5353',
    );
    expect(normalizeDnsResolverInput('tcp://8.8.8.8'), 'tcp://8.8.8.8');
  });

  test('DNS settings keep implicit UDP out of the editable field', () {
    expect(dnsResolverFieldText('udp://1.1.1.1'), '1.1.1.1');
    expect(dnsResolverFieldText('tcp://1.1.1.1'), 'tcp://1.1.1.1');
    expect(dnsResolverProtocolLabel('1.1.1.1'), 'UDP');
    expect(dnsResolverProtocolLabel('tcp://1.1.1.1'), 'TCP');
    expect(dnsResolverProtocolLabel('tls://1.1.1.1'), 'TLS');
    expect(dnsResolverProtocolLabel('https://dns.example/dns-query'), 'HTTPS');
  });

  test('split routing changes require a full VPN service restart', () {
    final controller = AppSettingsController();

    final modeChange = controller.setSplitRoutingMode(
      SplitRoutingMode.bypassSelected,
    );
    final packagesChange = controller.setSplitRoutingPackages(const [
      'com.example.app',
    ]);

    expect(modeChange.changed, isTrue);
    expect(modeChange.forceFullServiceRestart, isTrue);
    expect(packagesChange.changed, isTrue);
    expect(packagesChange.forceFullServiceRestart, isTrue);
  });

  test('toState keeps external runtime selection fields supplied by app', () {
    final controller = AppSettingsController()
      ..setLocale('ru')
      ..setTlsFragmentationMode(TlsFragmentationMode.record);

    final state = controller.toState(
      onboardingCompleted: true,
      acceptedLegalVersion: '0.2.0',
      acceptedLegalAtMillis: 42,
      activeProfileId: 'sub-1',
      selectedProxyTag: 'vless-1',
    );

    expect(state.onboardingCompleted, isTrue);
    expect(state.acceptedLegalVersion, '0.2.0');
    expect(state.acceptedLegalAtMillis, 42);
    expect(state.activeProfileId, 'sub-1');
    expect(state.selectedProxyTag, 'vless-1');
    expect(state.localeCode, 'ru');
    expect(state.tlsFragmentationMode, TlsFragmentationMode.record);
  });

  test('connection mode never leaves the runtime without an inbound', () {
    final controller = AppSettingsController();

    final proxyChange = controller.setInboundConnectionMode(
      InboundConnectionMode.proxy,
    );
    expect(proxyChange.forceFullServiceRestart, isTrue);
    expect(controller.vpnInboundEnabled, isFalse);
    expect(controller.proxyInboundEnabled, isTrue);

    controller.setProxyInboundEnabled(false);
    expect(controller.vpnInboundEnabled, isTrue);
    expect(controller.proxyInboundEnabled, isFalse);
  });

  test('enabling any local proxy creates a strong per-install password', () {
    final controller = AppSettingsController();

    controller.setProxyInboundEnabled(true);

    expect(controller.proxyMixedListen, '127.0.0.1');
    expect(controller.proxyUsername, defaultProxyUsername);
    expect(isValidProxyPassword(controller.proxyPassword), isTrue);
    expect(controller.proxyPassword.length, proxyPasswordLength);

    final usernameChange = controller.setProxyUsername('sergey');
    expect(usernameChange.changed, isTrue);
    expect(usernameChange.restartRuntime, isTrue);
    expect(controller.proxyUsername, 'sergey');
    expect(controller.setProxyUsername('bad username').changed, isFalse);
  });

  test('proxy sorting changes persist without restarting runtime', () {
    final controller = AppSettingsController();

    final change = controller.setProxySort('working');

    expect(change.changed, isTrue);
    expect(change.restartRuntime, isFalse);
    expect(controller.proxySort, 'working');
  });

  test('traffic rules keep exactly one active preset and restart VPN', () {
    final controller = AppSettingsController();

    final aiChange = controller.setTrafficRulePreset(
      TrafficRulePreset.aiViaVpn,
    );
    expect(aiChange.changed, isTrue);
    expect(aiChange.forceFullServiceRestart, isTrue);
    expect(controller.trafficRulePreset, TrafficRulePreset.aiViaVpn);
    expect(controller.useRussiaRouteData, isFalse);

    final russianChange = controller.setRussiaRouteDataEnabled(true);
    expect(russianChange.changed, isTrue);
    expect(
      controller.trafficRulePreset,
      TrafficRulePreset.russianServicesDirect,
    );
    expect(controller.useRussiaRouteData, isTrue);
  });
}
