import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';

const currentCoreConfigSchemaVersion = 4;

enum CoreConfigMigrationStatus { notRequired, readyForValidation, blocked }

/// A non-destructive migration candidate.
///
/// The caller must validate a generated sing-box config before persisting
/// [state]. Planning alone never marks an upgrade as completed.
class CoreConfigMigrationResult {
  const CoreConfigMigrationResult({
    required this.status,
    required this.state,
    this.changes = const <String>[],
    this.steps = const <CoreConfigMigrationStep>[],
    this.blockReason = '',
  });

  final CoreConfigMigrationStatus status;
  final AppSettingsState state;
  final List<String> changes;
  final List<CoreConfigMigrationStep> steps;
  final String blockReason;

  bool get requiresValidation =>
      status == CoreConfigMigrationStatus.readyForValidation;
}

class CoreConfigMigrationStep {
  const CoreConfigMigrationStep({
    required this.fromVersion,
    required this.toVersion,
    required this.changes,
  });

  final int fromVersion;
  final int toVersion;
  final List<String> changes;
}

class CoreConfigMigration {
  const CoreConfigMigration._();

  static CoreConfigMigrationResult plan({
    required AppSettingsState state,
    required LibboxCapabilities capabilities,
  }) {
    if (capabilities.isLegacyContract) {
      return CoreConfigMigrationResult(
        status: CoreConfigMigrationStatus.notRequired,
        state: state,
      );
    }
    if (!capabilities.isCompatible) {
      return CoreConfigMigrationResult(
        status: CoreConfigMigrationStatus.blocked,
        state: state,
        blockReason: capabilities.contractError,
      );
    }
    if (state.coreConfigSchemaVersion > currentCoreConfigSchemaVersion) {
      return CoreConfigMigrationResult(
        status: CoreConfigMigrationStatus.blocked,
        state: state,
        blockReason: 'settings_from_newer_client',
      );
    }
    if (state.coreConfigSchemaVersion == currentCoreConfigSchemaVersion) {
      return CoreConfigMigrationResult(
        status: CoreConfigMigrationStatus.notRequired,
        state: state,
      );
    }
    if (capabilities.tunStacks.isEmpty) {
      return CoreConfigMigrationResult(
        status: CoreConfigMigrationStatus.blocked,
        state: state,
        blockReason: 'core_tun_capabilities_missing',
      );
    }

    var candidate = state;
    final steps = <CoreConfigMigrationStep>[];
    while (candidate.coreConfigSchemaVersion < currentCoreConfigSchemaVersion) {
      final fromVersion = candidate.coreConfigSchemaVersion;
      final migration = switch (fromVersion) {
        0 => _migrateSchema0To1(candidate, capabilities),
        1 => _migrateSchema1To2(candidate),
        2 => _migrateSchema2To3(candidate),
        3 => _migrateSchema3To4(candidate, capabilities),
        _ => null,
      };
      if (migration == null) {
        return CoreConfigMigrationResult(
          status: CoreConfigMigrationStatus.blocked,
          state: state,
          blockReason: 'unsupported_settings_schema_$fromVersion',
        );
      }
      candidate = migration.state;
      steps.add(migration.step);
    }
    final changes = <String>[for (final step in steps) ...step.changes];

    return CoreConfigMigrationResult(
      status: CoreConfigMigrationStatus.readyForValidation,
      state: candidate,
      changes: List<String>.unmodifiable(changes),
      steps: List<CoreConfigMigrationStep>.unmodifiable(steps),
    );
  }

  static _StepResult _migrateSchema0To1(
    AppSettingsState state,
    LibboxCapabilities capabilities,
  ) {
    var tunImplementation = state.vpnTunImplementation;
    var selectedProxyTag = state.selectedProxyTag;
    final changes = <String>[];
    if (!capabilities.supportsTunStack(tunImplementation.name)) {
      final fallback = _firstSupportedTunStack(capabilities);
      if (fallback == null) {
        throw StateError('no_compatible_tun_stack');
      }
      changes.add(
        'vpn_tun_implementation:${tunImplementation.name}->${fallback.name}',
      );
      tunImplementation = fallback;
    }
    final normalizedSelectedProxyTag = normalizeProxySelectionTag(
      selectedProxyTag,
    );
    if (normalizedSelectedProxyTag != selectedProxyTag) {
      changes.add(
        'selected_proxy_tag:$selectedProxyTag->$normalizedSelectedProxyTag',
      );
      selectedProxyTag = normalizedSelectedProxyTag;
    }
    return _step(
      from: 0,
      state: state.copyWith(
        coreConfigSchemaVersion: 1,
        vpnTunImplementation: tunImplementation,
        selectedProxyTag: selectedProxyTag,
      ),
      changes: changes,
    );
  }

  static _StepResult _migrateSchema1To2(AppSettingsState state) {
    final direct = _normalizedDns(
      state.dnsDirectResolver,
      fallback: 'udp://1.1.1.1',
    );
    final proxy = _normalizedDns(
      state.dnsProxyResolver,
      fallback: 'https://dns.cloudflare.com/dns-query',
    );
    final russia = _normalizedDns(
      state.russiaDnsDirectResolver,
      fallback: defaultRussiaDnsDirectResolver,
    );
    final urlTest = state.urlTestUrl.trim().isEmpty
        ? defaultUrlTestUrl
        : state.urlTestUrl.trim();
    final changes = <String>[];
    _recordChange(
      changes,
      'dns_direct_resolver',
      state.dnsDirectResolver,
      direct,
    );
    _recordChange(changes, 'dns_proxy_resolver', state.dnsProxyResolver, proxy);
    _recordChange(
      changes,
      'russia_dns_direct_resolver',
      state.russiaDnsDirectResolver,
      russia,
    );
    _recordChange(changes, 'url_test_url', state.urlTestUrl, urlTest);
    final interval = state.urlTestIntervalSeconds <= 0
        ? 1800
        : state.urlTestIntervalSeconds;
    final timeout = state.urlTestTimeoutSeconds <= 0
        ? 15
        : state.urlTestTimeoutSeconds;
    final concurrency = state.urlTestConcurrency.clamp(1, 8).toInt();
    final unavailable = state.urlTestUnavailableCheckIntervalSeconds
        .clamp(120, 3600)
        .toInt();
    _recordChange(
      changes,
      'url_test_interval_seconds',
      state.urlTestIntervalSeconds,
      interval,
    );
    _recordChange(
      changes,
      'url_test_timeout_seconds',
      state.urlTestTimeoutSeconds,
      timeout,
    );
    _recordChange(
      changes,
      'url_test_concurrency',
      state.urlTestConcurrency,
      concurrency,
    );
    _recordChange(
      changes,
      'url_test_unavailable_interval_seconds',
      state.urlTestUnavailableCheckIntervalSeconds,
      unavailable,
    );
    return _step(
      from: 1,
      state: state.copyWith(
        coreConfigSchemaVersion: 2,
        dnsDirectResolver: direct,
        dnsProxyResolver: proxy,
        russiaDnsDirectResolver: russia,
        urlTestUrl: urlTest,
        urlTestIntervalSeconds: interval,
        urlTestTimeoutSeconds: timeout,
        urlTestConcurrency: concurrency,
        urlTestUnavailableCheckIntervalSeconds: unavailable,
      ),
      changes: changes,
    );
  }

  static _StepResult _migrateSchema2To3(AppSettingsState state) {
    var vpnEnabled = state.vpnInboundEnabled;
    final proxyEnabled = state.proxyInboundEnabled;
    final changes = <String>[];
    if (!vpnEnabled && !proxyEnabled) {
      vpnEnabled = true;
      changes.add('vpn_inbound_enabled:false->true');
    }
    final proxyListen = state.proxyAllowLan ? '0.0.0.0' : '127.0.0.1';
    _recordChange(
      changes,
      'proxy_mixed_listen',
      state.proxyMixedListen,
      proxyListen,
    );
    final splitPackages = state.splitRoutingPackages
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .take(maxSplitRoutingPackageCount)
        .toList(growable: false);
    if (splitPackages.length != state.splitRoutingPackages.length) {
      changes.add(
        'split_routing_packages:${state.splitRoutingPackages.length}->${splitPackages.length}',
      );
    }
    final fakeIpEnabled =
        state.experimentalFakeIpEnabled &&
        vpnEnabled &&
        state.splitRoutingMode == SplitRoutingMode.disabled;
    _recordChange(
      changes,
      'experimental_fake_ip_enabled',
      state.experimentalFakeIpEnabled,
      fakeIpEnabled,
    );
    final preset =
        state.trafficRulePreset == TrafficRulePreset.none &&
            state.useRussiaRouteData
        ? TrafficRulePreset.russianServicesDirect
        : state.trafficRulePreset;
    if (preset != state.trafficRulePreset) {
      changes.add(
        'traffic_rule_preset:${state.trafficRulePreset.storageValue}->${preset.storageValue}',
      );
    }
    return _step(
      from: 2,
      state: state.copyWith(
        coreConfigSchemaVersion: 3,
        vpnInboundEnabled: vpnEnabled,
        proxyMixedListen: proxyListen,
        splitRoutingPackages: splitPackages,
        experimentalFakeIpEnabled: fakeIpEnabled,
        trafficRulePreset: preset,
      ),
      changes: changes,
    );
  }

  static _StepResult _migrateSchema3To4(
    AppSettingsState state,
    LibboxCapabilities capabilities,
  ) {
    var tunImplementation = state.vpnTunImplementation;
    final changes = <String>[];
    if (!capabilities.supportsTunStack(tunImplementation.name)) {
      final fallback = _firstSupportedTunStack(capabilities);
      if (fallback == null) {
        throw StateError('no_compatible_tun_stack');
      }
      changes.add(
        'vpn_tun_implementation:${tunImplementation.name}->${fallback.name}',
      );
      tunImplementation = fallback;
    }
    return _step(
      from: 3,
      state: state.copyWith(
        coreConfigSchemaVersion: 4,
        vpnTunImplementation: tunImplementation,
      ),
      changes: changes,
    );
  }

  static String _normalizedDns(String value, {required String fallback}) {
    final normalized = normalizeDnsResolverInput(value);
    return normalized.isEmpty ? fallback : normalized;
  }

  static void _recordChange(
    List<String> changes,
    String field,
    Object before,
    Object after,
  ) {
    if (before != after) {
      changes.add('$field:$before->$after');
    }
  }

  static _StepResult _step({
    required int from,
    required AppSettingsState state,
    required List<String> changes,
  }) {
    return _StepResult(
      state: state,
      step: CoreConfigMigrationStep(
        fromVersion: from,
        toVersion: from + 1,
        changes: List<String>.unmodifiable(changes),
      ),
    );
  }

  static TunImplementationPreference? _firstSupportedTunStack(
    LibboxCapabilities capabilities,
  ) {
    for (final candidate in const <TunImplementationPreference>[
      TunImplementationPreference.gvisor,
      TunImplementationPreference.system,
      TunImplementationPreference.mixed,
    ]) {
      if (capabilities.supportsTunStack(candidate.name)) {
        return candidate;
      }
    }
    return null;
  }
}

class _StepResult {
  const _StepResult({required this.state, required this.step});

  final AppSettingsState state;
  final CoreConfigMigrationStep step;
}
