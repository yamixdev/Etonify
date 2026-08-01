enum TrafficRulePreset {
  none,
  russianServicesDirect,
  aiViaVpn,
  socialViaVpn;

  String get storageValue => switch (this) {
    TrafficRulePreset.none => 'none',
    TrafficRulePreset.russianServicesDirect => 'russian_services_direct',
    TrafficRulePreset.aiViaVpn => 'ai_via_vpn',
    TrafficRulePreset.socialViaVpn => 'social_via_vpn',
  };

  static TrafficRulePreset fromStorage(Object? value) =>
      switch (value?.toString().trim()) {
        'russian_services_direct' => TrafficRulePreset.russianServicesDirect,
        'ai_via_vpn' => TrafficRulePreset.aiViaVpn,
        'social_via_vpn' => TrafficRulePreset.socialViaVpn,
        _ => TrafficRulePreset.none,
      };
}

enum TrafficRuleDefaultRoute { proxy, direct }

class TrafficRulePresetDefinition {
  const TrafficRulePresetDefinition({
    required this.preset,
    required this.defaultRoute,
    required this.routeDataKind,
    required this.proxyCategoryCount,
    required this.directCategoryCount,
    required this.blockedCategoryCount,
  });

  final TrafficRulePreset preset;
  final TrafficRuleDefaultRoute defaultRoute;
  final TrafficRuleDataKind routeDataKind;
  final int proxyCategoryCount;
  final int directCategoryCount;
  final int blockedCategoryCount;

  bool get isVerified => preset != TrafficRulePreset.none;
}

enum TrafficRuleDataKind { none, runet, ai, social }

const trafficRulePresetDefinitions =
    <TrafficRulePreset, TrafficRulePresetDefinition>{
      TrafficRulePreset.russianServicesDirect: TrafficRulePresetDefinition(
        preset: TrafficRulePreset.russianServicesDirect,
        defaultRoute: TrafficRuleDefaultRoute.proxy,
        routeDataKind: TrafficRuleDataKind.runet,
        proxyCategoryCount: 2,
        directCategoryCount: 5,
        blockedCategoryCount: 0,
      ),
      TrafficRulePreset.aiViaVpn: TrafficRulePresetDefinition(
        preset: TrafficRulePreset.aiViaVpn,
        defaultRoute: TrafficRuleDefaultRoute.direct,
        routeDataKind: TrafficRuleDataKind.ai,
        proxyCategoryCount: 1,
        directCategoryCount: 0,
        blockedCategoryCount: 0,
      ),
      TrafficRulePreset.socialViaVpn: TrafficRulePresetDefinition(
        preset: TrafficRulePreset.socialViaVpn,
        defaultRoute: TrafficRuleDefaultRoute.direct,
        routeDataKind: TrafficRuleDataKind.social,
        proxyCategoryCount: 10,
        directCategoryCount: 0,
        blockedCategoryCount: 0,
      ),
    };

TrafficRulePresetDefinition? trafficRulePresetDefinitionFor(
  TrafficRulePreset preset,
) => trafficRulePresetDefinitions[preset];
