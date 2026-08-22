import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/features/settings/settings_dns_page.dart';

void main() {
  test('URLTest fallbacks use the stable runtime defaults', () {
    final controller = AppSettingsController();

    final intervalChange = controller.setUrlTestIntervalSeconds(0);
    final concurrencyChange = controller.setUrlTestConcurrency(0);
    final unavailableChange = controller
        .setUrlTestUnavailableCheckIntervalSeconds(0);

    expect(intervalChange.changed, isFalse);
    expect(concurrencyChange.changed, isFalse);
    expect(unavailableChange.changed, isFalse);
    expect(
      controller.urlTestIntervalSeconds,
      appSettingsStandardUrlTestIntervalSeconds,
    );
    expect(
      controller.urlTestConcurrency,
      appSettingsStandardUrlTestConcurrency,
    );
    expect(
      controller.urlTestUnavailableCheckIntervalSeconds,
      appSettingsStandardUrlTestUnavailableCheckIntervalSeconds,
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

  test('dataplane routing changes require a full VPN service restart', () {
    final controller = AppSettingsController();

    final blockLeaks = controller.setBlockLeaks(!controller.blockLeaks);
    final adBlock = controller.setAdBlockEnabled(true);
    final bypassLan = controller.setBypassLocalNetwork(
      !controller.bypassLocalNetwork,
    );

    expect(blockLeaks.forceFullServiceRestart, isTrue);
    expect(adBlock.forceFullServiceRestart, isTrue);
    expect(bypassLan.forceFullServiceRestart, isTrue);
  });

  test('FakeIP is limited to full VPN TUN and restarts the service', () {
    final controller = AppSettingsController();

    final enabled = controller.setExperimentalFakeIpEnabled(true);
    expect(enabled.changed, isTrue);
    expect(enabled.forceFullServiceRestart, isTrue);
    expect(controller.experimentalFakeIpEnabled, isTrue);

    controller.setSplitRoutingMode(SplitRoutingMode.proxySelected);
    expect(controller.experimentalFakeIpEnabled, isFalse);
    expect(controller.setExperimentalFakeIpEnabled(true).changed, isFalse);

    controller.setSplitRoutingMode(SplitRoutingMode.disabled);
    controller.setExperimentalFakeIpEnabled(true);
    controller.setVpnInboundEnabled(false);
    expect(controller.experimentalFakeIpEnabled, isFalse);
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
    expect(state.experimentalFakeIpEnabled, isFalse);
  });

  test('TLS security overrides have separate runtime effects', () {
    final controller = AppSettingsController();

    final proxy = controller.setAllowUntrustedProxyCertificates(true);
    final subscription = controller.setAllowUntrustedSubscriptionCertificates(
      true,
    );

    expect(proxy.changed, isTrue);
    expect(proxy.configReason, isNotNull);
    expect(proxy.restartRuntime, isTrue);
    expect(subscription.changed, isTrue);
    expect(subscription.configReason, isNull);
    expect(controller.allowUntrustedProxyCertificates, isTrue);
    expect(controller.allowUntrustedSubscriptionCertificates, isTrue);
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
