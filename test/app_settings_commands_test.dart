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
  });
}
