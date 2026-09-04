import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';

void main() {
  group('AppSettingsCommands', () {
    test('forwards calls to bound routing handlers', () async {
      final commands = AppSettingsCommands();
      var blockLeaks = false;
      var adBlockEnabled = false;
      var downloaded = false;
      var deleted = false;
      var refreshed = false;
      var trafficPreset = TrafficRulePreset.none;
      var preparedPreset = TrafficRulePreset.none;
      var directResolver = '';
      var bypassLocal = false;
      var splitMode = SplitRoutingMode.disabled;
      List<String>? splitPackages;
      var preloadedApps = false;

      commands.bindRoutingHandlers(
        setBlockLeaks: (value) => blockLeaks = value,
        setAdBlockEnabled: (value) => adBlockEnabled = value,
        downloadAdBlockRuleSet: () async {
          downloaded = true;
          return const AdBlockRuleSetStatus.unavailable();
        },
        deleteAdBlockRuleSet: () async {
          deleted = true;
          return const AdBlockRuleSetStatus.unavailable();
        },
        refreshRoutingRuleData: () async {
          refreshed = true;
          return const RussiaRouteDataStatus.unavailable();
        },
        setTrafficRulePreset: (TrafficRulePreset value) => trafficPreset = value,
        prepareTrafficRuleData: (TrafficRulePreset preset) async {
          preparedPreset = preset;
          return const RussiaRouteDataStatus.unavailable();
        },
        setRussiaDnsDirectResolver: (String value) => directResolver = value,
        setBypassLocalNetwork: (bool value) => bypassLocal = value,
        setSplitRoutingMode: (SplitRoutingMode value) => splitMode = value,
        setSplitRoutingPackages: (List<String> value) => splitPackages = value,
        preloadInstalledApps: () async {
          preloadedApps = true;
          return const [
            {'packageName': 'com.test.app'},
          ];
        },
      );

      commands.setBlockLeaks(true);
      expect(blockLeaks, isTrue);

      commands.setAdBlockEnabled(true);
      expect(adBlockEnabled, isTrue);

      await commands.downloadAdBlockRuleSet();
      expect(downloaded, isTrue);

      await commands.deleteAdBlockRuleSet();
      expect(deleted, isTrue);

      await commands.refreshRoutingRuleData();
      expect(refreshed, isTrue);

      commands.setTrafficRulePreset(TrafficRulePreset.aiViaVpn);
      expect(trafficPreset, TrafficRulePreset.aiViaVpn);

      await commands.prepareTrafficRuleData(TrafficRulePreset.socialViaVpn);
      expect(preparedPreset, TrafficRulePreset.socialViaVpn);

      commands.setRussiaDnsDirectResolver('udp://1.1.1.1');
      expect(directResolver, 'udp://1.1.1.1');

      commands.setBypassLocalNetwork(true);
      expect(bypassLocal, isTrue);

      commands.setSplitRoutingMode(SplitRoutingMode.bypassSelected);
      expect(splitMode, SplitRoutingMode.bypassSelected);

      commands.setSplitRoutingPackages(['com.test.app']);
      expect(splitPackages, ['com.test.app']);

      final apps = await commands.preloadInstalledApps();
      expect(preloadedApps, isTrue);
      expect(apps, hasLength(1));

      // Test unbind
      commands.unbindRoutingHandlers();
      commands.setBlockLeaks(false);
      // blockLeaks should still be true since handler is unbound (noop)
      expect(blockLeaks, isTrue);
    });

    test('forwards calls to bound dns handlers and unbinds cleanly', () {
      final commands = AppSettingsCommands();
      var directPreset = '';
      var directResolver = '';
      var proxyPreset = '';
      var proxyResolver = '';
      var preferIpv6 = false;
      var secureOnly = false;
      var directThroughProxy = false;

      commands.bindDnsHandlers(
        setDnsDirectPreset: (v) => directPreset = v,
        setDnsDirectResolver: (v) => directResolver = v,
        setDnsProxyPreset: (v) => proxyPreset = v,
        setDnsProxyResolver: (v) => proxyResolver = v,
        setDnsPreferIpv6: (v) => preferIpv6 = v,
        setDnsSecureOnly: (v) => secureOnly = v,
        setDnsDirectThroughProxy: (v) => directThroughProxy = v,
      );

      expect(commands.isDnsBound, isTrue);

      commands.setDnsDirectPreset('cloudflare');
      expect(directPreset, 'cloudflare');

      commands.setDnsDirectResolver('udp://1.1.1.1');
      expect(directResolver, 'udp://1.1.1.1');

      commands.setDnsProxyPreset('device');
      expect(proxyPreset, 'device');

      commands.setDnsProxyResolver('device://network');
      expect(proxyResolver, 'device://network');

      commands.setDnsPreferIpv6(true);
      expect(preferIpv6, isTrue);

      commands.setDnsSecureOnly(true);
      expect(secureOnly, isTrue);

      commands.setDnsDirectThroughProxy(true);
      expect(directThroughProxy, isTrue);

      commands.unbindDnsHandlers();
      expect(commands.isDnsBound, isFalse);

      commands.setDnsDirectPreset('custom');
      expect(directPreset, 'cloudflare');
    });

    test('forwards calls to bound experimental handlers and unbinds cleanly', () {
      final commands = AppSettingsCommands();
      var tcpFastOpen = false;
      var tcpMultiPath = false;
      var interruptConns = false;
      var urlTolerance = false;
      var fakeIp = false;
      var tlsMode = TlsFragmentationMode.disabled;
      var memoryLimit = false;
      var observedWarningDismissed = false;

      commands.bindExperimentalHandlers(
        setExperimentalTcpFastOpen: (v) => tcpFastOpen = v,
        setExperimentalTcpMultiPath: (v) => tcpMultiPath = v,
        setExperimentalInterruptExistingConnections: (v) => interruptConns = v,
        setExperimentalUrlTestStrictTolerance: (v) => urlTolerance = v,
        setExperimentalFakeIpEnabled: (v) => fakeIp = v,
        setTlsFragmentationMode: (v) => tlsMode = v,
        setMemoryLimitEnabled: (v, {bool warningDismissed = false}) {
          memoryLimit = v;
          observedWarningDismissed = warningDismissed;
        },
      );

      expect(commands.isExperimentalBound, isTrue);

      commands.setExperimentalTcpFastOpen(true);
      expect(tcpFastOpen, isTrue);

      commands.setExperimentalTcpMultiPath(true);
      expect(tcpMultiPath, isTrue);

      commands.setExperimentalInterruptExistingConnections(true);
      expect(interruptConns, isTrue);

      commands.setExperimentalUrlTestStrictTolerance(true);
      expect(urlTolerance, isTrue);

      commands.setExperimentalFakeIpEnabled(true);
      expect(fakeIp, isTrue);

      commands.setTlsFragmentationMode(TlsFragmentationMode.fragment);
      expect(tlsMode, TlsFragmentationMode.fragment);

      commands.setMemoryLimitEnabled(true, warningDismissed: true);
      expect(memoryLimit, isTrue);
      expect(observedWarningDismissed, isTrue);

      commands.unbindExperimentalHandlers();
      expect(commands.isExperimentalBound, isFalse);

      commands.setExperimentalTcpFastOpen(false);
      expect(tcpFastOpen, isTrue);
    });
  });
}
