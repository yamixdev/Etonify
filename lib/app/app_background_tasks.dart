import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/core/outbound_location.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/data/subscription/outbound_schema.dart';
import 'package:meow_client/data/subscription/outbound_support.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/singbox/singbox_config_builder.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';

class ProxyCacheBuildInput {
  const ProxyCacheBuildInput({
    required this.subscription,
    required this.selectedProxyTag,
    required this.lowestLatency,
    required this.runtimeLowestOutboundTag,
    required this.runtimeLowestSelections,
    required this.urlTestInFlight,
    required this.runtimeLatencies,
    required this.unavailableLatencyTags,
    required this.latencyErrors,
    required this.runtimeGroupSelections,
    required this.markAllServersRussia,
  });

  final Subscription? subscription;
  final String selectedProxyTag;
  final int? lowestLatency;
  final String? runtimeLowestOutboundTag;
  final Map<String, String> runtimeLowestSelections;
  final bool urlTestInFlight;
  final Map<String, int> runtimeLatencies;
  final Set<String> unavailableLatencyTags;
  final Map<String, String> latencyErrors;
  final Map<String, String> runtimeGroupSelections;
  final bool markAllServersRussia;
}

enum ProxyCacheBuildScope { home, full }

/// Serializes proxy presentation builds and retains at most one pending build.
///
/// Multiple runtime events often arrive together after URLTest or a network
/// change. Running an isolate for every intermediate event duplicates a large
/// subscription several times. The pending scope is coalesced and a full-list
/// request always wins over a home-only refresh.
class ProxyCacheBuildCoordinator {
  bool _inFlight = false;
  ProxyCacheBuildScope? _pendingScope;

  bool get inFlight => _inFlight;
  ProxyCacheBuildScope? get pendingScope => _pendingScope;

  bool beginOrQueue(ProxyCacheBuildScope scope) {
    if (_inFlight) {
      _pendingScope =
          _pendingScope == ProxyCacheBuildScope.full ||
              scope == ProxyCacheBuildScope.full
          ? ProxyCacheBuildScope.full
          : ProxyCacheBuildScope.home;
      return false;
    }
    _inFlight = true;
    return true;
  }

  ProxyCacheBuildScope? complete() {
    _inFlight = false;
    final next = _pendingScope;
    _pendingScope = null;
    return next;
  }

  void cancelPending() {
    _pendingScope = null;
  }
}

/// Creates the smallest subscription snapshot required by the proxy
/// presentation builders.
///
/// A complete outbound config may contain certificates, transport headers and
/// other deeply nested values. Sending thousands of those maps to an isolate
/// temporarily duplicates them in the Dart heap even though the proxy list
/// only needs protocol, endpoint, TLS and transport labels.
Subscription compactSubscriptionForProxyCache(Subscription subscription) {
  return subscription.copyWith(
    rawContent: '',
    outbounds: subscription.outbounds
        .map(
          (outbound) => outbound.copyWith(
            config: _compactOutboundPresentationConfig(outbound.config),
          ),
        )
        .toList(growable: false),
    proxyChains: subscription.proxyChains
        .map(
          (chain) => chain.targetConfig.isEmpty
              ? chain
              : chain.copyWith(
                  targetConfig: _compactOutboundPresentationConfig(
                    chain.targetConfig,
                  ),
                ),
        )
        .toList(growable: false),
  );
}

Map<String, dynamic> _compactOutboundPresentationConfig(
  Map<String, dynamic> config,
) {
  final compact = <String, dynamic>{};
  for (final key in const <String>[
    'type',
    'server',
    'server_port',
    'security',
    '_group_only',
  ]) {
    if (config.containsKey(key)) {
      compact[key] = config[key];
    }
  }

  final tls = config['tls'];
  if (tls is Map) {
    final compactTls = <String, dynamic>{};
    if (tls.containsKey('enabled')) {
      compactTls['enabled'] = tls['enabled'];
    }
    final reality = tls['reality'];
    if (reality is Map && reality.containsKey('enabled')) {
      compactTls['reality'] = <String, dynamic>{'enabled': reality['enabled']};
    }
    if (compactTls.isNotEmpty) {
      compact['tls'] = compactTls;
    }
  }

  final transport = config['transport'];
  if (transport is Map && transport.containsKey('type')) {
    compact['transport'] = <String, dynamic>{'type': transport['type']};
  }
  return compact;
}

class ProxyCacheBuildResult {
  const ProxyCacheBuildResult({
    required this.activeProfile,
    required this.displayProxy,
    required this.activeProxies,
    this.groupChildrenByTag = const <String, List<AppProxySummary>>{},
    required this.totalTopLevelProxyCount,
    this.includesFullProxyList = true,
    this.unsupportedWireGuardCount = 0,
  });

  final AppProfileSummary? activeProfile;
  final AppProxySummary? displayProxy;
  final List<AppProxySummary> activeProxies;
  final Map<String, List<AppProxySummary>> groupChildrenByTag;
  final int totalTopLevelProxyCount;
  final bool includesFullProxyList;
  final int unsupportedWireGuardCount;
}

class SingboxConfigBuildInput {
  const SingboxConfigBuildInput({
    required this.activeSubscription,
    required this.selectedProxyTag,
    required this.excludedOutboundTags,
    required this.vpnInboundEnabled,
    required this.vpnMtu,
    required this.vpnStrictRoute,
    required this.vpnTunImplementation,
    required this.proxyInboundEnabled,
    required this.proxyMixedListen,
    required this.proxyMixedPort,
    this.proxyUsername = defaultProxyUsername,
    this.proxyPassword = '',
    required this.dnsDirectResolver,
    required this.dnsProxyResolver,
    required this.dnsPreferIpv6,
    this.dnsSecureOnly = false,
    this.dnsDirectThroughProxy = false,
    this.russiaDnsDirectResolver = defaultRussiaDnsDirectResolver,
    required this.urlTestUrl,
    required this.urlTestIntervalSeconds,
    required this.urlTestTimeoutSeconds,
    required this.urlTestConcurrency,
    required this.urlTestUnavailableCheckIntervalSeconds,
    required this.blockLeaks,
    required this.adBlockEnabled,
    required this.adBlockBlockRuleSetPath,
    required this.adBlockAllowRuleSetPath,
    required this.useRussiaRouteData,
    required this.russiaGeositeRuBlockedPath,
    required this.russiaGeositeRuAvailableOnlyInsidePath,
    required this.russiaGeositeCategoryRuPath,
    required this.russiaGeoipRuBlockedPath,
    required this.russiaGeoipRuWhitelistPath,
    required this.russiaGeoipRuPath,
    required this.russiaCuratedDirectServicesPath,
    required this.russiaAiServicesPath,
    required this.russiaSocialServicesPath,
    this.trafficRulePreset = TrafficRulePreset.none,
    required this.bypassLocalNetwork,
    required this.splitRoutingMode,
    required this.splitRoutingPackages,
    required this.logLevel,
    required this.tcpFastOpenEnabled,
    required this.tcpMultiPathEnabled,
    required this.tlsFragmentationMode,
    this.allowUntrustedProxyCertificates = false,
    required this.interruptExistingConnections,
    required this.urlTestStrictTolerance,
    this.experimentalFakeIpEnabled = false,
    required this.markAllServersRussia,
    this.capabilities = LibboxCapabilities.bundledLegacy,
    this.outputConfigPath,
    this.returnConfig = true,
  });

  final Subscription? activeSubscription;
  final String selectedProxyTag;
  final Set<String> excludedOutboundTags;
  final bool vpnInboundEnabled;
  final int vpnMtu;
  final bool vpnStrictRoute;
  final TunImplementationPreference vpnTunImplementation;
  final bool proxyInboundEnabled;
  final String proxyMixedListen;
  final int proxyMixedPort;
  final String proxyUsername;
  final String proxyPassword;
  final String dnsDirectResolver;
  final String dnsProxyResolver;
  final bool dnsPreferIpv6;
  final bool dnsSecureOnly;
  final bool dnsDirectThroughProxy;
  final String russiaDnsDirectResolver;
  final String urlTestUrl;
  final int urlTestIntervalSeconds;
  final int urlTestTimeoutSeconds;
  final int urlTestConcurrency;
  final int urlTestUnavailableCheckIntervalSeconds;
  final bool blockLeaks;
  final bool adBlockEnabled;
  final String? adBlockBlockRuleSetPath;
  final String? adBlockAllowRuleSetPath;
  final bool useRussiaRouteData;
  final String? russiaGeositeRuBlockedPath;
  final String? russiaGeositeRuAvailableOnlyInsidePath;
  final String? russiaGeositeCategoryRuPath;
  final String? russiaGeoipRuBlockedPath;
  final String? russiaGeoipRuWhitelistPath;
  final String? russiaGeoipRuPath;
  final String? russiaCuratedDirectServicesPath;
  final String? russiaAiServicesPath;
  final String? russiaSocialServicesPath;
  final TrafficRulePreset trafficRulePreset;
  final bool bypassLocalNetwork;
  final SplitRoutingMode splitRoutingMode;
  final List<String> splitRoutingPackages;
  final String logLevel;
  final bool tcpFastOpenEnabled;
  final bool tcpMultiPathEnabled;
  final TlsFragmentationMode tlsFragmentationMode;
  final bool allowUntrustedProxyCertificates;
  final bool interruptExistingConnections;
  final bool urlTestStrictTolerance;
  final bool experimentalFakeIpEnabled;
  final bool markAllServersRussia;
  final LibboxCapabilities capabilities;
  final String? outputConfigPath;
  final bool returnConfig;
}

class SingboxConfigBuildResult {
  const SingboxConfigBuildResult({
    required this.plan,
    required this.configJson,
    required this.configPath,
    required this.configLength,
    required this.configOutboundCount,
    required this.configInboundCount,
    required this.configRouteRuleCount,
    required this.invalidOutbounds,
    required this.invalidOutboundCount,
    required this.selectedProxyInvalid,
    required this.startableOutboundCount,
  });

  final SingboxBuildPlan plan;
  final String configJson;
  final String? configPath;
  final int configLength;
  final int configOutboundCount;
  final int configInboundCount;
  final int configRouteRuleCount;
  final List<InvalidStartupOutbound> invalidOutbounds;
  final int invalidOutboundCount;
  final bool selectedProxyInvalid;
  final int startableOutboundCount;

  bool get hasReturnedConfig => plan.config.isNotEmpty;
  bool get hasPreparedConfig =>
      configPath != null && configPath!.trim().isNotEmpty;
}

class StartupValidationInput {
  const StartupValidationInput({
    required this.subscription,
    required this.excludedOutboundTags,
  });

  final Subscription? subscription;
  final Set<String> excludedOutboundTags;
}

class InvalidStartupOutbound {
  const InvalidStartupOutbound({
    required this.tag,
    required this.name,
    required this.reason,
  });

  final String tag;
  final String name;
  final String reason;
}

class StartupValidationResult {
  const StartupValidationResult({
    required this.invalidOutbounds,
    required this.startableCount,
  });

  final List<InvalidStartupOutbound> invalidOutbounds;
  final int startableCount;
}

Future<ProxyCacheBuildResult> buildProxyCacheInBackground(
  ProxyCacheBuildInput input,
) {
  return Isolate.run(
    () => buildProxyCache(input),
    debugName: 'meow-proxy-cache',
  );
}

/// Builds the compact state required by the home screen.
///
/// The full proxy list deliberately has a separate builder: a subscription
/// with thousands of nodes should not allocate a second complete set of
/// presentation objects just to show the selected server on the home page.
Future<ProxyCacheBuildResult> buildHomeProxyCacheInBackground(
  ProxyCacheBuildInput input,
) {
  return Isolate.run(
    () => buildHomeProxyCache(input),
    debugName: 'meow-home-proxy-cache',
  );
}

ProxyCacheBuildResult buildHomeProxyCache(ProxyCacheBuildInput input) {
  final subscription = input.subscription;
  if (subscription == null) {
    return const ProxyCacheBuildResult(
      activeProfile: null,
      displayProxy: null,
      activeProxies: <AppProxySummary>[],
      groupChildrenByTag: <String, List<AppProxySummary>>{},
      totalTopLevelProxyCount: 0,
      includesFullProxyList: false,
    );
  }

  final unsupportedWireGuardCount = subscription.outbounds
      .where((outbound) => !outbound.info.deleted)
      .where((outbound) => isWireGuardOutboundConfig(outbound.config))
      .length;
  final visibleOutbounds = subscription.outbounds
      .where((outbound) => !outbound.info.deleted)
      .where((outbound) => isSupportedOutboundConfig(outbound.config))
      .toList(growable: false);
  final selectableOutbounds = visibleOutbounds
      .where((outbound) => !_isGroupOnlyOutbound(outbound))
      .toList(growable: false);
  final activeProfile = _buildProfileSummary(subscription);
  final displayProxy = _buildHomeDisplayProxy(
    input,
    subscription,
    visibleOutbounds,
    selectableOutbounds,
  );
  return ProxyCacheBuildResult(
    activeProfile: activeProfile,
    displayProxy: displayProxy,
    activeProxies: const <AppProxySummary>[],
    totalTopLevelProxyCount: selectableOutbounds.length,
    includesFullProxyList: false,
    unsupportedWireGuardCount: unsupportedWireGuardCount,
  );
}

AppProxySummary _buildHomeDisplayProxy(
  ProxyCacheBuildInput input,
  Subscription subscription,
  List<Outbound> visibleOutbounds,
  List<Outbound> selectableOutbounds,
) {
  final selectedTag = input.selectedProxyTag.trim();
  final outboundByTag = <String, Outbound>{
    for (final outbound in visibleOutbounds) outbound.tag: outbound,
  };
  final groupByTag = <String, SubscriptionGroup>{
    for (final group in subscription.groups) group.tag: group,
  };
  final chainByTag = <String, SubscriptionProxyChain>{
    for (final chain in subscription.proxyChains) chain.tag: chain,
  };

  AppProxySummary summaryForOutbound(Outbound outbound) =>
      _buildProxySummary(input, outbound);

  AppProxySummary? selectedGroupChild(SubscriptionGroup group) {
    final runtimeSelected = input.runtimeGroupSelections[group.tag]?.trim();
    if (runtimeSelected != null && runtimeSelected.isNotEmpty) {
      final selected = outboundByTag[runtimeSelected];
      if (selected != null && !selected.info.deleted) {
        return summaryForOutbound(selected);
      }
    }
    AppProxySummary? first;
    AppProxySummary? best;
    int? bestLatency;
    for (final tag in group.outboundTags) {
      final outbound = outboundByTag[tag];
      if (outbound == null || outbound.info.deleted) {
        continue;
      }
      final summary = summaryForOutbound(outbound);
      first ??= summary;
      if (summary.latencyUnavailable || summary.latency == null) {
        continue;
      }
      if (bestLatency == null || summary.latency! < bestLatency) {
        bestLatency = summary.latency;
        best = summary;
      }
    }
    return best ?? first;
  }

  AppProxySummary groupSummary(SubscriptionGroup group) {
    final child = selectedGroupChild(group);
    final childName = child?.displayName;
    final childCountry = child?.countryCode ?? '';
    final childCount = group.outboundTags
        .where(outboundByTag.containsKey)
        .length;
    final count = childCount == 0 ? group.outboundTags.length : childCount;
    final groupCountry = input.markAllServersRussia
        ? 'RU'
        : _normalizeCountryCode(group.country);
    return AppProxySummary(
      tag: group.tag,
      displayName: group.name.trim().isEmpty ? group.tag : group.name,
      countryCode: childCountry.isNotEmpty ? childCountry : groupCountry,
      type: 'urltest',
      server: '',
      port: 0,
      detailText: childName == null || childName.isEmpty
          ? 'URLTest · $count outbounds'
          : 'URLTest · $childName',
      ip: child?.ip ?? '',
      latency: child?.latency,
      latencyFresh: child?.latencyFresh ?? false,
      latencyChecking:
          child?.latencyChecking ?? (input.urlTestInFlight && child == null),
      latencyUnavailable: child?.latencyUnavailable ?? false,
      latencyError: child?.latencyError,
      protocolLabel: childName == null || childName.isEmpty
          ? 'URLTest · $count outbounds'
          : 'URLTest · $childName',
      endpointLabel: child?.endpointLabel ?? '',
      isGroup: true,
      childCount: count,
      selectedChildTag: child?.tag,
      selectedChildName: childName,
      highlighted: selectedTag == group.tag,
    );
  }

  if (isLowestProxyTag(selectedTag)) {
    final selectedTagForLowest =
        input.runtimeLowestSelections[selectedTag] ??
        (selectedTag == lowestProxyTag ? input.runtimeLowestOutboundTag : null);
    AppProxySummary? selected;
    if (selectedTagForLowest != null && selectedTagForLowest.isNotEmpty) {
      final group = groupByTag[selectedTagForLowest];
      if (group != null) {
        selected = selectedGroupChild(group);
      } else {
        final outbound = outboundByTag[selectedTagForLowest];
        if (outbound != null) {
          selected = summaryForOutbound(outbound);
        }
      }
    }
    final invalidSelection =
        selected == null ||
        input.unavailableLatencyTags.contains(selected.tag) ||
        input.latencyErrors.containsKey(selected.tag);
    if (invalidSelection) {
      final allUnavailable =
          selectableOutbounds.isNotEmpty &&
          selectableOutbounds.every(
            (outbound) => input.unavailableLatencyTags.contains(outbound.tag),
          );
      return AppProxySummary(
        tag: selectedTag.isEmpty ? lowestProxyTag : selectedTag,
        displayName: lowestProxyBaseLabel(selectedTag),
        countryCode: '',
        type: 'urltest',
        server: '',
        port: 0,
        detailText: 'URLTest · auto',
        ip: '',
        latency: null,
        latencyFresh: false,
        latencyChecking: input.urlTestInFlight,
        latencyUnavailable: allUnavailable,
        latencyError: null,
        protocolLabel: 'URLTest · auto',
        endpointLabel: '',
        highlighted: true,
      );
    }
    return selected.copyWith(
      tag: selectedTag,
      displayName: lowestProxyDisplayName(selectedTag, selected.displayName),
      detailText: 'URLTest · ${selected.displayName}',
      protocolLabel: 'URLTest · ${selected.protocolLabel}',
      selectedChildTag: selected.tag,
      selectedChildName: selected.displayName,
      highlighted: true,
    );
  }

  final group = groupByTag[selectedTag];
  if (group != null) {
    return groupSummary(group);
  }
  final chain = chainByTag[selectedTag];
  if (chain != null) {
    final target = outboundByTag[chain.targetTag];
    if (target != null) {
      final targetSummary = summaryForOutbound(target);
      final runtimeLatency = input.runtimeLatencies[chain.tag];
      final unavailable = input.unavailableLatencyTags.contains(chain.tag);
      final error = input.latencyErrors[chain.tag];
      return targetSummary.copyWith(
        tag: chain.tag,
        displayName: chain.name.trim().isEmpty
            ? '${chain.detourTag} -> ${targetSummary.displayName}'
            : chain.name.trim(),
        detailText:
            'Chain · ${chain.detourTag} -> ${targetSummary.displayName}',
        protocolLabel: 'Chain · ${targetSummary.protocolLabel}',
        latency: runtimeLatency ?? targetSummary.latency,
        clearLatency:
            runtimeLatency == null &&
            targetSummary.latency == null &&
            unavailable,
        latencyFresh: runtimeLatency != null || targetSummary.latencyFresh,
        latencyChecking: input.urlTestInFlight,
        latencyUnavailable: unavailable,
        latencyError: error,
        clearLatencyError: error == null,
        highlighted: true,
      );
    }
  }
  final selectedOutbound = outboundByTag[selectedTag];
  if (selectedOutbound != null) {
    return summaryForOutbound(selectedOutbound);
  }
  return _fallbackDisplayProxy(subscription, selectableOutbounds);
}

ProxyCacheBuildResult buildProxyCache(ProxyCacheBuildInput input) {
  final subscription = input.subscription;
  if (subscription == null) {
    return const ProxyCacheBuildResult(
      activeProfile: null,
      displayProxy: null,
      activeProxies: <AppProxySummary>[],
      groupChildrenByTag: <String, List<AppProxySummary>>{},
      totalTopLevelProxyCount: 0,
    );
  }

  final activeProfile = _buildProfileSummary(subscription);
  final unsupportedWireGuardCount = subscription.outbounds
      .where((outbound) => !outbound.info.deleted)
      .where((outbound) => isWireGuardOutboundConfig(outbound.config))
      .length;
  final visibleOutbounds = subscription.outbounds
      .where((outbound) => !outbound.info.deleted)
      .where((outbound) => isSupportedOutboundConfig(outbound.config))
      .toList(growable: false);
  final selectableOutbounds = visibleOutbounds
      .where((outbound) => !_isGroupOnlyOutbound(outbound))
      .toList(growable: false);
  final proxySummaries = visibleOutbounds
      .map((outbound) => _buildProxySummary(input, outbound))
      .toList(growable: false);
  final proxySummariesByTag = {
    for (final summary in proxySummaries) summary.tag: summary,
  };
  final visibleOutboundByTag = {
    for (final outbound in visibleOutbounds) outbound.tag: outbound,
  };
  final chainSummaries = _buildProxyChainSummaries(
    input,
    subscription.proxyChains,
    proxySummariesByTag,
    visibleOutboundByTag,
  );
  for (final summary in chainSummaries) {
    proxySummariesByTag[summary.tag] = summary;
  }
  final groupedOutboundTags = <String>{};
  final groupTagByChildTag = <String, String>{};
  final groupSummaries = <AppProxySummary>[];
  final lowestCandidateGroupSummaries = <AppProxySummary>[];
  final lowestCandidateGroupChildTags = <String>{};
  for (final group in subscription.groups) {
    final visibleChildTags = group.outboundTags
        .where(proxySummariesByTag.containsKey)
        .toList(growable: false);
    if (visibleChildTags.length < 2) {
      continue;
    }
    groupedOutboundTags.addAll(visibleChildTags);
    for (final tag in visibleChildTags) {
      groupTagByChildTag[tag] = group.tag;
    }
    final groupSummary = _buildGroupProxySummary(
      input,
      group,
      visibleChildTags,
      proxySummariesByTag,
    );
    groupSummaries.add(groupSummary);
    proxySummariesByTag[groupSummary.tag] = groupSummary;
    if (_isSetbackUrlTestGroup(group)) {
      lowestCandidateGroupSummaries.add(groupSummary);
      lowestCandidateGroupChildTags.addAll(visibleChildTags);
    }
  }

  final lowestProxies = <AppProxySummary>[];
  if (selectableOutbounds.length + lowestCandidateGroupSummaries.length > 1) {
    final lowestCandidates = _lowestEligibleProxySummaries(
      input,
      lowestProxyTag,
      selectableOutbounds,
      lowestCandidateGroupSummaries,
      lowestCandidateGroupChildTags,
      proxySummariesByTag,
    );
    lowestProxies.add(
      _buildLowestProxySummary(input, lowestProxyTag, lowestCandidates),
    );
  }
  final lowestProxyByTag = {
    for (final proxy in lowestProxies) proxy.tag: proxy,
  };
  final chainSummariesByTag = {
    for (final proxy in chainSummaries) proxy.tag: proxy,
  };

  final activeProxy =
      selectableOutbounds.length == 1 &&
          isLowestProxyTag(input.selectedProxyTag)
      ? proxySummariesByTag[selectableOutbounds.single.tag]
      : isLowestProxyTag(input.selectedProxyTag)
      ? lowestProxyByTag[input.selectedProxyTag]
      : chainSummariesByTag[input.selectedProxyTag] ??
            _groupSummaryByTag(groupSummaries, input.selectedProxyTag) ??
            proxySummariesByTag[input.selectedProxyTag];

  final displayProxy =
      activeProxy ??
      (selectableOutbounds.isEmpty
          ? null
          : proxySummariesByTag[selectableOutbounds.first.tag]) ??
      _fallbackDisplayProxy(subscription, selectableOutbounds);

  final standaloneProxySummaries = proxySummaries
      .where(
        (summary) =>
            !groupedOutboundTags.contains(summary.tag) &&
            !_isGroupOnlySummary(summary, visibleOutboundByTag),
      )
      .toList(growable: false);
  final topLevelSummaries = <AppProxySummary>[
    ...lowestProxies,
    ...groupSummaries,
    ...chainSummaries,
    ...standaloneProxySummaries,
  ];
  final groupChildrenByTag = <String, List<AppProxySummary>>{
    for (final group in groupSummaries)
      group.tag: [
        for (final tag in group.childTags)
          if (groupedOutboundTags.contains(tag) &&
              groupTagByChildTag[tag] == group.tag &&
              proxySummariesByTag[tag] != null)
            _withParentGroup(input, proxySummariesByTag[tag]!, group.tag),
      ],
  };

  return ProxyCacheBuildResult(
    activeProfile: activeProfile,
    displayProxy: displayProxy,
    activeProxies: topLevelSummaries,
    groupChildrenByTag: groupChildrenByTag,
    totalTopLevelProxyCount: topLevelSummaries.length,
    unsupportedWireGuardCount: unsupportedWireGuardCount,
  );
}

Future<SingboxConfigBuildResult> buildSingboxConfigInBackground(
  SingboxConfigBuildInput input,
) {
  return Isolate.run(
    () => buildSingboxConfig(input),
    debugName: 'meow-singbox-config',
  );
}

SingboxConfigBuildResult buildSingboxConfig(SingboxConfigBuildInput input) {
  final validation = validateStartupOutbounds(
    StartupValidationInput(
      subscription: input.activeSubscription,
      excludedOutboundTags: input.excludedOutboundTags,
    ),
  );
  final invalidOutboundTags = validation.invalidOutbounds
      .map((outbound) => outbound.tag)
      .toSet();
  final excludedOutboundTags = <String>{
    ...input.excludedOutboundTags,
    ...invalidOutboundTags,
  };
  final plan = SingboxConfigBuilder(
    activeSubscription: input.activeSubscription,
    selectedProxyTag: input.selectedProxyTag,
    excludedOutboundTags: excludedOutboundTags,
    vpnInboundEnabled: input.vpnInboundEnabled,
    vpnMtu: input.vpnMtu,
    vpnStrictRoute: input.vpnStrictRoute,
    vpnTunImplementation: input.vpnTunImplementation,
    proxyInboundEnabled: input.proxyInboundEnabled,
    proxyMixedListen: input.proxyMixedListen,
    proxyMixedPort: input.proxyMixedPort,
    proxyUsername: input.proxyUsername,
    proxyPassword: input.proxyPassword,
    dnsDirectResolver: input.dnsDirectResolver,
    dnsProxyResolver: input.dnsProxyResolver,
    dnsPreferIpv6: input.dnsPreferIpv6,
    dnsSecureOnly: input.dnsSecureOnly,
    dnsDirectThroughProxy: input.dnsDirectThroughProxy,
    russiaDnsDirectResolver: input.russiaDnsDirectResolver,
    urlTestUrl: input.urlTestUrl,
    urlTestIntervalSeconds: input.urlTestIntervalSeconds,
    urlTestTimeoutSeconds: input.urlTestTimeoutSeconds,
    urlTestConcurrency: input.urlTestConcurrency,
    urlTestUnavailableCheckIntervalSeconds:
        input.urlTestUnavailableCheckIntervalSeconds,
    blockLeaks: input.blockLeaks,
    adBlockEnabled: input.adBlockEnabled,
    adBlockBlockRuleSetPath: input.adBlockBlockRuleSetPath,
    adBlockAllowRuleSetPath: input.adBlockAllowRuleSetPath,
    useRussiaRouteData: input.useRussiaRouteData,
    russiaGeositeRuBlockedPath: input.russiaGeositeRuBlockedPath,
    russiaGeositeRuAvailableOnlyInsidePath:
        input.russiaGeositeRuAvailableOnlyInsidePath,
    russiaGeositeCategoryRuPath: input.russiaGeositeCategoryRuPath,
    russiaGeoipRuBlockedPath: input.russiaGeoipRuBlockedPath,
    russiaGeoipRuWhitelistPath: input.russiaGeoipRuWhitelistPath,
    russiaGeoipRuPath: input.russiaGeoipRuPath,
    russiaCuratedDirectServicesPath: input.russiaCuratedDirectServicesPath,
    russiaAiServicesPath: input.russiaAiServicesPath,
    russiaSocialServicesPath: input.russiaSocialServicesPath,
    trafficRulePreset: input.trafficRulePreset,
    bypassLocalNetwork: input.bypassLocalNetwork,
    splitRoutingMode: input.splitRoutingMode,
    splitRoutingPackages: input.splitRoutingPackages,
    logLevel: input.logLevel,
    tcpFastOpenEnabled: input.tcpFastOpenEnabled,
    tcpMultiPathEnabled: input.tcpMultiPathEnabled,
    tlsFragmentationMode: input.tlsFragmentationMode,
    allowUntrustedProxyCertificates: input.allowUntrustedProxyCertificates,
    interruptExistingConnections: input.interruptExistingConnections,
    urlTestStrictTolerance: input.urlTestStrictTolerance,
    experimentalFakeIpEnabled: input.experimentalFakeIpEnabled,
    markAllServersRussia: input.markAllServersRussia,
    capabilities: input.capabilities,
  ).buildPlan();
  final config = plan.config;
  final configJson = jsonEncode(config);
  final outputConfigPath = input.outputConfigPath?.trim();
  final writtenConfigPath = outputConfigPath == null || outputConfigPath.isEmpty
      ? null
      : _writeConfigJsonAtomically(outputConfigPath, configJson);
  final configOutboundCount =
      ((config['outbounds'] as List?) ?? const []).length;
  final shouldReturnConfig = input.returnConfig || configOutboundCount < 100;
  final resultPlan = shouldReturnConfig
      ? plan
      : SingboxBuildPlan(
          config: const <String, dynamic>{},
          proxyOutboundTagsByIndex: plan.proxyOutboundTagsByIndex,
          visibleProxyOutboundCount: plan.visibleProxyOutboundCount,
        );
  return SingboxConfigBuildResult(
    plan: resultPlan,
    configJson: shouldReturnConfig ? configJson : '',
    configPath: writtenConfigPath,
    configLength: configJson.length,
    configOutboundCount: configOutboundCount,
    configInboundCount: ((config['inbounds'] as List?) ?? const []).length,
    configRouteRuleCount:
        (((config['route'] as Map?)?['rules'] as List?) ?? const []).length,
    invalidOutbounds: validation.invalidOutbounds
        .take(5)
        .toList(growable: false),
    invalidOutboundCount: validation.invalidOutbounds.length,
    selectedProxyInvalid:
        input.selectedProxyTag.isNotEmpty &&
        invalidOutboundTags.contains(input.selectedProxyTag),
    startableOutboundCount: validation.startableCount,
  );
}

String _writeConfigJsonAtomically(String path, String configJson) {
  final target = File(path);
  target.parent.createSync(recursive: true);
  final temp = File(
    '${target.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
  );
  try {
    temp.writeAsStringSync(configJson, flush: true);
    if (target.existsSync()) {
      target.deleteSync();
    }
    temp.renameSync(target.path);
    return target.path;
  } catch (_) {
    try {
      if (temp.existsSync()) {
        temp.deleteSync();
      }
    } catch (_) {}
    rethrow;
  }
}

Future<StartupValidationResult> validateStartupOutboundsInBackground(
  StartupValidationInput input,
) {
  return Isolate.run(
    () => validateStartupOutbounds(input),
    debugName: 'meow-startup-validation',
  );
}

class ConfigMutationInput {
  const ConfigMutationInput({
    required this.config,
    required this.proxyOutboundTagsByIndex,
    required this.tagToRemove,
    required this.outputPath,
  });

  final Map<String, dynamic> config;
  final Map<int, String> proxyOutboundTagsByIndex;
  final String tagToRemove;
  final String outputPath;
}

class ConfigMutationResult {
  const ConfigMutationResult({
    required this.config,
    required this.proxyOutboundTagsByIndex,
    required this.configPath,
    required this.outboundCount,
    required this.startableProxyCount,
  });

  final Map<String, dynamic> config;
  final Map<int, String> proxyOutboundTagsByIndex;
  final String configPath;
  final int outboundCount;
  final int startableProxyCount;
}

Future<ConfigMutationResult> mutateSingboxConfigInBackground(
  ConfigMutationInput input,
) {
  return Isolate.run(
    () => mutateSingboxConfig(input),
    debugName: 'meow-singbox-config-mutation',
  );
}

ConfigMutationResult mutateSingboxConfig(ConfigMutationInput input) {
  final outbounds = ((input.config['outbounds'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  if (!outbounds.any((outbound) => outbound['tag'] == input.tagToRemove)) {
    throw StateError(
      'Cached config does not contain outbound tag "${input.tagToRemove}"',
    );
  }

  final removedTags = <String>{input.tagToRemove};
  var filteredOutbounds = outbounds
      .where((outbound) => outbound['tag'] != input.tagToRemove)
      .toList(growable: false);

  var changed = true;
  while (changed) {
    changed = false;
    final nextOutbounds = <Map<String, dynamic>>[];
    for (final outbound in filteredOutbounds) {
      final references = outbound['outbounds'];
      if (references is! List) {
        nextOutbounds.add(outbound);
        continue;
      }
      final cleaned = references
          .whereType<String>()
          .where((ref) => !removedTags.contains(ref))
          .toList(growable: false);
      final tag = outbound['tag']?.toString() ?? '';
      if (cleaned.isEmpty) {
        if (tag.isNotEmpty && removedTags.add(tag)) {
          changed = true;
        }
        continue;
      }
      final defaultTag = outbound['default']?.toString() ?? '';
      nextOutbounds.add({
        ...outbound,
        'outbounds': cleaned,
        if (defaultTag.isNotEmpty && !cleaned.contains(defaultTag))
          'default': cleaned.first,
      });
    }
    filteredOutbounds = nextOutbounds;
  }

  final mutatedConfig = {...input.config, 'outbounds': filteredOutbounds};
  final proxyTags = input.proxyOutboundTagsByIndex.values.toSet();
  final newIndexMap = <int, String>{};
  for (var i = 0; i < filteredOutbounds.length; i++) {
    final tag = filteredOutbounds[i]['tag']?.toString() ?? '';
    if (proxyTags.contains(tag)) {
      newIndexMap[i] = tag;
    }
  }
  final configJson = jsonEncode(mutatedConfig);
  final writtenPath = _writeConfigJsonAtomically(input.outputPath, configJson);
  return ConfigMutationResult(
    config: mutatedConfig,
    proxyOutboundTagsByIndex: newIndexMap,
    configPath: writtenPath,
    outboundCount: filteredOutbounds.length,
    startableProxyCount: newIndexMap.length,
  );
}

StartupValidationResult validateStartupOutbounds(StartupValidationInput input) {
  final subscription = input.subscription;
  if (subscription == null) {
    return const StartupValidationResult(
      invalidOutbounds: <InvalidStartupOutbound>[],
      startableCount: 0,
    );
  }

  var startableCount = 0;
  final invalidOutbounds = <InvalidStartupOutbound>[];
  for (final outbound in subscription.outbounds) {
    if (outbound.info.deleted ||
        input.excludedOutboundTags.contains(outbound.tag)) {
      continue;
    }
    final validationError = ParsedOutboundSchema.validate(outbound.config);
    if (validationError == null) {
      startableCount++;
      continue;
    }
    invalidOutbounds.add(
      InvalidStartupOutbound(
        tag: outbound.tag,
        name: outbound.name,
        reason: validationError,
      ),
    );
  }

  return StartupValidationResult(
    invalidOutbounds: invalidOutbounds,
    startableCount: startableCount,
  );
}

AppProfileSummary _buildProfileSummary(Subscription subscription) {
  final info = subscription.info;
  return AppProfileSummary(
    id: subscription.id,
    name: subscription.name,
    consumed: info?.consumed.toDouble() ?? 0,
    total: info?.total?.toDouble() ?? 0,
    remainingDays: info?.remainingDays,
    outboundsCount: subscription.outbounds
        .where((outbound) => !outbound.info.deleted)
        .where((outbound) => !_isGroupOnlyOutbound(outbound))
        .length,
    sourceLabel: '',
  );
}

AppProxySummary _buildLowestProxySummary(
  ProxyCacheBuildInput input,
  String lowestTag,
  List<AppProxySummary> candidates,
) {
  final selectedSummary = _lowestSelectedSummary(input, lowestTag, candidates);
  final selectedName = selectedSummary?.displayName;
  final protocolLabel = (selectedSummary == null
      ? 'URLTest · auto'
      : 'URLTest · ${selectedSummary.protocolLabel}');
  final detailText = (selectedSummary == null
      ? 'URLTest · auto'
      : 'URLTest · ${selectedSummary.displayName}');
  final allCandidatesUnavailable =
      candidates.isNotEmpty &&
      candidates.every(
        (candidate) =>
            input.unavailableLatencyTags.contains(candidate.tag) ||
            candidate.latencyUnavailable,
      );
  return AppProxySummary(
    tag: lowestTag,
    displayName: lowestProxyDisplayName(lowestTag, selectedName),
    countryCode: selectedSummary?.countryCode ?? '',
    type: selectedSummary?.type ?? 'urltest',
    server: '',
    port: 0,
    detailText: detailText,
    ip: selectedSummary?.ip ?? '',
    // A lowest group must display the measurement of the child actually
    // selected by sing-box. A global minimum may belong to another child and
    // must never be presented as this selection's latency.
    latency: selectedSummary?.latency,
    latencyFresh: selectedSummary?.latencyFresh ?? false,
    latencyChecking: input.urlTestInFlight,
    latencyUnavailable:
        selectedSummary?.latencyUnavailable ?? allCandidatesUnavailable,
    latencyError: selectedSummary?.latencyError,
    protocolLabel: protocolLabel,
    endpointLabel: selectedSummary?.endpointLabel ?? '',
    selectedChildTag: selectedSummary?.tag,
    selectedChildName: selectedName,
    highlighted: input.selectedProxyTag == lowestTag,
  );
}

bool _isGroupOnlyOutbound(Outbound outbound) {
  return outbound.config['_group_only'] == true;
}

bool _isGroupOnlySummary(
  AppProxySummary summary,
  Map<String, Outbound> outboundByTag,
) {
  final outbound = outboundByTag[summary.tag];
  return outbound != null && _isGroupOnlyOutbound(outbound);
}

List<AppProxySummary> _lowestEligibleProxySummaries(
  ProxyCacheBuildInput input,
  String lowestTag,
  List<Outbound> visibleOutbounds,
  List<AppProxySummary> groupCandidates,
  Set<String> groupCandidateChildTags,
  Map<String, AppProxySummary> summariesByTag,
) {
  final result = <AppProxySummary>[];
  for (final group in groupCandidates) {
    if (lowestProxyAllowsCountry(lowestTag, group.countryCode)) {
      result.add(group);
    }
  }
  for (final outbound in visibleOutbounds) {
    if (groupCandidateChildTags.contains(outbound.tag)) {
      continue;
    }
    if (!lowestProxyAllowsCountry(
      lowestTag,
      _sourceOutboundCountry(input, outbound),
    )) {
      continue;
    }
    result.add(
      summariesByTag[outbound.tag] ?? _buildProxySummary(input, outbound),
    );
  }
  return result;
}

String? _runtimeLowestOutboundTagFor(
  ProxyCacheBuildInput input,
  String lowestTag,
) {
  final selected = input.runtimeLowestSelections[lowestTag];
  if (selected != null && selected.isNotEmpty) {
    return selected;
  }
  if (lowestTag == lowestProxyTag) {
    return input.runtimeLowestOutboundTag;
  }
  return null;
}

String? _activeRuntimeLowestOutboundTag(ProxyCacheBuildInput input) {
  if (!isLowestProxyTag(input.selectedProxyTag)) {
    return null;
  }
  return _runtimeLowestOutboundTagFor(input, input.selectedProxyTag);
}

AppProxySummary? _lowestSelectedSummary(
  ProxyCacheBuildInput input,
  String lowestTag,
  List<AppProxySummary> candidates,
) {
  final runtimeSelectedTag = _runtimeLowestOutboundTagFor(input, lowestTag);
  if (runtimeSelectedTag != null && runtimeSelectedTag.isNotEmpty) {
    for (final candidate in candidates) {
      if (candidate.tag == runtimeSelectedTag) {
        final selectedLeafTag = candidate.isGroup
            ? input.runtimeGroupSelections[candidate.tag]?.trim()
            : candidate.tag;
        if (selectedLeafTag == null ||
            selectedLeafTag.isEmpty ||
            input.unavailableLatencyTags.contains(selectedLeafTag) ||
            input.latencyErrors.containsKey(selectedLeafTag) ||
            candidate.latencyUnavailable ||
            candidate.latencyError != null) {
          return null;
        }
        return candidate;
      }
    }
  }
  return null;
}

bool _isSetbackUrlTestGroup(SubscriptionGroup group) {
  final type = group.type.trim();
  if (type.isNotEmpty && type != 'urltest') {
    return false;
  }
  return group.urlTestConfig.method?.trim().toLowerCase() == 'setback';
}

AppProxySummary _buildProxySummary(
  ProxyCacheBuildInput input,
  Outbound outbound,
) {
  final securityLabel = _securityLabel(outbound.config);
  final transportLabel = _transportLabel(outbound.config);
  final protocolParts = <String>[
    outbound.type.toUpperCase(),
    ...[securityLabel, transportLabel].whereType<String>(),
  ];
  final protocolLabel = protocolParts.join(' · ');
  final endpointLabel = _endpointLabel(outbound);
  final runtimeLatency = input.runtimeLatencies[outbound.tag];
  final latencyUnavailable = input.unavailableLatencyTags.contains(
    outbound.tag,
  );
  final runtimeLowestTag = _activeRuntimeLowestOutboundTag(input);
  final highlightedByLowest =
      isLowestProxyTag(input.selectedProxyTag) &&
      runtimeLowestTag == outbound.tag;
  return AppProxySummary(
    tag: outbound.tag,
    displayName: outbound.name.trim().isEmpty ? outbound.tag : outbound.name,
    countryCode: _displayOutboundCountry(input, outbound),
    type: outbound.type,
    server: outbound.server,
    port: outbound.port,
    detailText: '$protocolLabel · $endpointLabel',
    ip: outbound.info.externalIp?.trim() ?? '',
    latency: runtimeLatency ?? outbound.info.latestPing,
    // Persisted subscription pings are useful history, not a measurement from
    // the current runtime session.
    latencyFresh: runtimeLatency != null,
    latencyChecking: input.urlTestInFlight,
    latencyUnavailable: latencyUnavailable,
    latencyError: input.latencyErrors[outbound.tag],
    protocolLabel: protocolLabel,
    endpointLabel: endpointLabel,
    highlighted: highlightedByLowest,
  );
}

List<AppProxySummary> _buildProxyChainSummaries(
  ProxyCacheBuildInput input,
  List<SubscriptionProxyChain> chains,
  Map<String, AppProxySummary> proxySummariesByTag,
  Map<String, Outbound> visibleOutboundByTag,
) {
  if (chains.isEmpty) {
    return const [];
  }
  final result = <AppProxySummary>[];
  final seen = <String>{};
  for (final chain in chains) {
    final tag = chain.tag.trim();
    final target = _proxyChainTargetSummaryFor(
      input,
      chain,
      proxySummariesByTag,
    );
    if (tag.isEmpty || target == null || !seen.add(tag)) {
      continue;
    }
    final detourName = _detourDisplayName(chain.detourTag, proxySummariesByTag);
    final runtimeLatency = input.runtimeLatencies[tag];
    final latencyUnavailable = input.unavailableLatencyTags.contains(tag);
    final latencyError = input.latencyErrors[tag];
    final targetCountry = _proxyChainTargetCountry(chain, visibleOutboundByTag);
    result.add(
      target.copyWith(
        tag: tag,
        displayName: chain.name.trim().isEmpty
            ? '$detourName -> ${target.displayName}'
            : chain.name.trim(),
        detailText: 'Chain · $detourName -> ${target.displayName}',
        protocolLabel: 'Chain · ${target.protocolLabel}',
        countryCode: targetCountry,
        latency: runtimeLatency ?? target.latency,
        clearLatency:
            runtimeLatency == null &&
            target.latency == null &&
            latencyUnavailable,
        latencyFresh: runtimeLatency != null || target.latencyFresh,
        latencyChecking: input.urlTestInFlight,
        latencyUnavailable: latencyUnavailable,
        latencyError: latencyError,
        clearLatencyError: latencyError == null,
        highlighted: input.selectedProxyTag == tag,
      ),
    );
  }
  return result;
}

String _proxyChainTargetCountry(
  SubscriptionProxyChain chain,
  Map<String, Outbound> visibleOutboundByTag,
) {
  final target = visibleOutboundByTag[chain.targetTag.trim()];
  if (target != null) {
    return outboundDisplayCountryCode(target, markAllServersRussia: false);
  }
  return _normalizeCountryCode(chain.targetCountry);
}

AppProxySummary? _proxyChainTargetSummaryFor(
  ProxyCacheBuildInput input,
  SubscriptionProxyChain chain,
  Map<String, AppProxySummary> proxySummariesByTag,
) {
  final targetSubscriptionId = chain.targetSubscriptionId.trim();
  final activeSubscriptionId = input.subscription?.id ?? '';
  if (targetSubscriptionId.isNotEmpty &&
      targetSubscriptionId != activeSubscriptionId) {
    return _buildProxyChainSnapshotTargetSummary(input, chain);
  }
  return proxySummariesByTag[chain.targetTag.trim()] ??
      _buildProxyChainSnapshotTargetSummary(input, chain);
}

AppProxySummary? _buildProxyChainSnapshotTargetSummary(
  ProxyCacheBuildInput input,
  SubscriptionProxyChain chain,
) {
  if (chain.targetConfig.isEmpty || chain.targetTag.trim().isEmpty) {
    return null;
  }
  final config = Map<String, dynamic>.from(chain.targetConfig);
  if (!isSupportedOutboundConfig(config)) {
    return null;
  }
  config['tag'] = chain.targetTag.trim();
  final outbound = Outbound(
    tag: chain.targetTag.trim(),
    name: chain.targetName.trim().isEmpty
        ? chain.targetTag.trim()
        : chain.targetName.trim(),
    config: config,
    info: OutboundInfo(country: chain.targetCountry),
  );
  return _buildProxySummary(input, outbound);
}

String _detourDisplayName(
  String detourTag,
  Map<String, AppProxySummary> proxySummariesByTag,
) {
  final normalized = detourTag.trim();
  if (isLegacySyntheticProxyTag(normalized)) return 'lowest';
  if (isLowestProxyTag(normalized)) {
    return lowestProxyBaseLabel(normalized);
  }
  return proxySummariesByTag[normalized]?.displayName ?? normalized;
}

AppProxySummary _buildGroupProxySummary(
  ProxyCacheBuildInput input,
  SubscriptionGroup group,
  List<String> visibleChildTags,
  Map<String, AppProxySummary> childSummariesByTag,
) {
  final runtimeSelectedTag = input.runtimeGroupSelections[group.tag];
  final selectedChildTag =
      runtimeSelectedTag != null &&
          visibleChildTags.contains(runtimeSelectedTag)
      ? runtimeSelectedTag
      : _bestChildTag(input, visibleChildTags, childSummariesByTag);
  final selectedChild = selectedChildTag == null
      ? null
      : childSummariesByTag[selectedChildTag];
  final selectedCountry = selectedChild?.countryCode.trim() ?? '';
  final groupCountry = input.markAllServersRussia
      ? 'RU'
      : _normalizeCountryCode(group.country);
  final selectedChildName = selectedChild?.displayName ?? selectedChildTag;
  final hasSelectedChild =
      selectedChildName != null && selectedChildName.isNotEmpty;
  final unavailable = visibleChildTags.every(
    (tag) => input.unavailableLatencyTags.contains(tag),
  );
  final runtimeLowestTag = _activeRuntimeLowestOutboundTag(input);
  return AppProxySummary(
    tag: group.tag,
    displayName: group.name.trim().isEmpty ? group.tag : group.name,
    countryCode: selectedCountry.isNotEmpty ? selectedCountry : groupCountry,
    type: 'urltest',
    server: '',
    port: 0,
    detailText: hasSelectedChild
        ? 'URLTest · $selectedChildName'
        : 'URLTest · ${visibleChildTags.length} outbounds',
    ip: selectedChild?.ip ?? '',
    latency: selectedChild?.latency,
    latencyFresh: selectedChild?.latencyFresh ?? false,
    latencyChecking:
        input.urlTestInFlight || (selectedChild?.latencyChecking ?? false),
    latencyUnavailable: unavailable,
    latencyError: selectedChild?.latencyError,
    protocolLabel: hasSelectedChild
        ? 'URLTest · $selectedChildName'
        : 'URLTest · ${visibleChildTags.length} outbounds',
    endpointLabel: selectedChild?.endpointLabel ?? '',
    isGroup: true,
    childTags: visibleChildTags,
    childCount: visibleChildTags.length,
    selectedChildTag: selectedChildTag,
    selectedChildName: selectedChildName,
    highlighted:
        input.selectedProxyTag == group.tag ||
        visibleChildTags.contains(input.selectedProxyTag) ||
        (runtimeLowestTag != null &&
            visibleChildTags.contains(runtimeLowestTag)),
  );
}

String? _bestChildTag(
  ProxyCacheBuildInput input,
  List<String> childTags,
  Map<String, AppProxySummary> summariesByTag,
) {
  String? bestTag;
  int? bestLatency;
  for (final tag in childTags) {
    if (input.unavailableLatencyTags.contains(tag)) {
      continue;
    }
    final summary = summariesByTag[tag];
    final latency = summary?.latency;
    if (latency == null) {
      continue;
    }
    if (bestLatency == null || latency < bestLatency) {
      bestLatency = latency;
      bestTag = tag;
    }
  }
  return bestTag ?? (childTags.isEmpty ? null : childTags.first);
}

AppProxySummary? _groupSummaryByTag(List<AppProxySummary> groups, String tag) {
  for (final group in groups) {
    if (group.tag == tag) {
      return group;
    }
  }
  return null;
}

AppProxySummary _withParentGroup(
  ProxyCacheBuildInput input,
  AppProxySummary summary,
  String? parentTag,
) {
  final highlightedByGroupUrlTest =
      parentTag != null &&
      input.runtimeGroupSelections[parentTag] == summary.tag;
  final runtimeLowestTag = _activeRuntimeLowestOutboundTag(input);
  final highlightedByLowest =
      isLowestProxyTag(input.selectedProxyTag) &&
      runtimeLowestTag == summary.tag;
  return AppProxySummary(
    tag: summary.tag,
    displayName: summary.displayName,
    countryCode: summary.countryCode,
    type: summary.type,
    server: summary.server,
    port: summary.port,
    detailText: summary.detailText,
    ip: summary.ip,
    latency: summary.latency,
    latencyFresh: summary.latencyFresh,
    latencyChecking: summary.latencyChecking,
    latencyUnavailable: summary.latencyUnavailable,
    latencyError: summary.latencyError,
    protocolLabel: summary.protocolLabel,
    endpointLabel: summary.endpointLabel,
    parentGroupTag: parentTag,
    childCount: summary.childCount,
    highlighted:
        summary.highlighted || highlightedByGroupUrlTest || highlightedByLowest,
  );
}

AppProxySummary _fallbackDisplayProxy(
  Subscription subscription,
  List<Outbound> visibleOutbounds,
) {
  String fallbackName = subscription.name;
  if (visibleOutbounds.isNotEmpty) {
    fallbackName = visibleOutbounds.first.name;
  }
  return AppProxySummary(
    tag: '',
    displayName: fallbackName,
    countryCode: '',
    type: '',
    server: '',
    port: 0,
    detailText: '',
    ip: '',
    latency: null,
    latencyFresh: false,
    latencyChecking: false,
    latencyUnavailable: false,
    latencyError: null,
    protocolLabel: '',
    endpointLabel: '',
  );
}

String _normalizeCountryCode(String? countryCode) {
  final normalized = countryCode?.trim().toUpperCase() ?? '';
  return RegExp(r'^[A-Z]{2}$').hasMatch(normalized) ? normalized : '';
}

String _displayOutboundCountry(ProxyCacheBuildInput input, Outbound outbound) {
  return outboundDisplayCountryCode(
    outbound,
    markAllServersRussia: input.markAllServersRussia,
  );
}

String _sourceOutboundCountry(ProxyCacheBuildInput input, Outbound outbound) {
  return input.markAllServersRussia
      ? 'RU'
      : _normalizeCountryCode(outbound.info.country);
}

String? _securityLabel(Map<String, dynamic> config) {
  final tls = config['tls'];
  if (tls is Map) {
    final reality = tls['reality'];
    if (reality is Map && reality['enabled'] == true) {
      return 'REALITY';
    }
    if (tls['enabled'] == true) {
      return 'TLS';
    }
  }

  final security = (config['security'] as String?)?.trim();
  if (security == null ||
      security.isEmpty ||
      security.toLowerCase() == 'none') {
    return null;
  }
  return security.toUpperCase();
}

String? _transportLabel(Map<String, dynamic> config) {
  final transport = config['transport'];
  if (transport is Map) {
    final type = (transport['type'] as String?)?.trim();
    if (type != null && type.isNotEmpty) {
      return type.toUpperCase();
    }
  }
  return null;
}

String _endpointLabel(Outbound outbound) {
  if (outbound.server.isEmpty) {
    return outbound.tag;
  }
  if (outbound.port <= 0) {
    return outbound.server;
  }
  return '${outbound.server}:${outbound.port}';
}
