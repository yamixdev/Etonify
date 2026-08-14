import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/data/local/app_settings_store.dart';

void main() {
  test('publishes a new revision only for an effective mutation', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(appSettingsProvider.notifier);
    expect(container.read(appSettingsProvider).revision, 0);

    final changed = notifier.mutate(
      (settings) => settings.setNotificationTrafficRefreshSeconds(7),
    );
    expect(changed.changed, isTrue);
    expect(container.read(appSettingsProvider).revision, 1);
    expect(
      container
          .read(appSettingsProvider)
          .controller
          .notificationTrafficRefreshSeconds,
      7,
    );

    final unchanged = notifier.mutate(
      (settings) => settings.setNotificationTrafficRefreshSeconds(7),
    );
    expect(unchanged.changed, isFalse);
    expect(container.read(appSettingsProvider).revision, 1);
  });

  test('hydrates and normalizes persisted settings once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(appSettingsProvider.notifier);
    notifier.hydrate(_persistedSettings(proxySort: 'unsupported'));

    final snapshot = container.read(appSettingsProvider);
    expect(snapshot.revision, 1);
    expect(snapshot.controller.localeCode, 'ru');
    expect(snapshot.controller.proxySort, 'source');
  });
}

AppSettingsState _persistedSettings({required String proxySort}) {
  return AppSettingsState(
    onboardingCompleted: true,
    activeProfileId: '',
    selectedProxyTag: '',
    proxySort: proxySort,
    localeCode: 'ru',
    themePreference: AppThemePreference.dark,
    accentColorHex: 'default',
    hapticEnabled: true,
    hideServerIp: false,
    progressiveBlurEnabled: false,
    vpnInboundEnabled: true,
    vpnMtu: 1500,
    vpnStrictRoute: true,
    vpnTunImplementation: TunImplementationPreference.mixed,
    proxyInboundEnabled: false,
    proxyAllowLan: false,
    proxyMixedListen: '127.0.0.1',
    proxyMixedPort: 1080,
    dnsDirectPreset: 'cloudflare',
    dnsDirectResolver: 'udp://1.1.1.1',
    dnsProxyPreset: 'cloudflare',
    dnsProxyResolver: 'https://dns.cloudflare.com/dns-query',
    dnsPreferIpv6: false,
    urlTestUrl: 'https://www.gstatic.com/generate_204',
    urlTestIntervalSeconds: 180,
    urlTestTimeoutSeconds: 15,
    urlTestConcurrency: 30,
    urlTestUnavailableCheckIntervalSeconds: 2,
    locationLookupLimit: 12,
    locationLookupTimeoutSeconds: 6,
    locationLookupConcurrency: 16,
    blockLeaks: false,
    adBlockEnabled: false,
    useRussiaRouteData: false,
    bypassLocalNetwork: true,
    splitRoutingMode: SplitRoutingMode.disabled,
    splitRoutingPackages: const <String>[],
    singBoxLogLevel: 'warning',
    experimentalTcpFastOpen: true,
    experimentalTcpMultiPath: false,
    experimentalInterruptExistingConnections: true,
    experimentalUrlTestStrictTolerance: true,
  );
}
