part of 'app_background_tasks.dart';

// Bump when config generation/validation semantics change, even if the native
// contract stays the same. Only one entry is retained, in private app storage.
const _configCacheSchema = 2;

Future<String> singboxConfigFingerprintInBackground(
  SingboxConfigBuildInput input,
) => Isolate.run(
  () => _configFingerprint(input),
  debugName: 'meow-config-fingerprint',
);

Future<String> _configFingerprint(
  SingboxConfigBuildInput input, {
  String? selectedProxyTagOverride,
}) async {
  final rules = <String, String>{};
  for (final path in <String?>[
    input.adBlockBlockRuleSetPath,
    input.adBlockAllowRuleSetPath,
    input.russiaGeositeRuBlockedPath,
    input.russiaGeositeRuAvailableOnlyInsidePath,
    input.russiaGeositeCategoryRuPath,
    input.russiaGeoipRuBlockedPath,
    input.russiaGeoipRuWhitelistPath,
    input.russiaGeoipRuPath,
    input.russiaCuratedDirectServicesPath,
    input.russiaAiServicesPath,
    input.russiaSocialServicesPath,
  ].whereType<String>().where((path) => path.isNotEmpty).toSet()) {
    final file = File(path);
    rules[path] = await file.exists()
        ? (await sha256.bind(file.openRead()).first).toString()
        : 'missing';
  }
  final sub = input.activeSubscription;
  final identity = <String, Object?>{
    'schema': _configCacheSchema,
    'coreSettings': input.coreSettings.toMap(),
    'activeSubscription': sub == null
        ? null
        : (sub.payloadRevision.isNotEmpty
            ? {'id': sub.id, 'revision': sub.payloadRevision}
            : sha256.convert(utf8.encode(jsonEncode(sub.toMap()))).toString()),
    'selectedProxyTag': selectedProxyTagOverride ?? input.selectedProxyTag,
    'excludedOutboundTags': (input.excludedOutboundTags.toList()..sort()),
    'vpnInboundEnabled': input.vpnInboundEnabled,
    'vpnMtu': input.vpnMtu,
    'vpnStrictRoute': input.vpnStrictRoute,
    'vpnTunImplementation': input.vpnTunImplementation.name,
    'proxyInboundEnabled': input.proxyInboundEnabled,
    'proxyMixedListen': input.proxyMixedListen,
    'proxyMixedPort': input.proxyMixedPort,
    'proxyUsername': input.proxyUsername,
    'proxyPassword': input.proxyPassword,
    'dnsDirectResolver': input.dnsDirectResolver,
    'dnsProxyResolver': input.dnsProxyResolver,
    'dnsPreferIpv6': input.dnsPreferIpv6,
    'dnsSecureOnly': input.dnsSecureOnly,
    'dnsDirectThroughProxy': input.dnsDirectThroughProxy,
    'russiaDnsDirectResolver': input.russiaDnsDirectResolver,
    'urlTestUrl': input.urlTestUrl,
    'urlTestIntervalSeconds': input.urlTestIntervalSeconds,
    'urlTestTimeoutSeconds': input.urlTestTimeoutSeconds,
    'urlTestConcurrency': input.urlTestConcurrency,
    'urlTestUnavailableCheckIntervalSeconds':
        input.urlTestUnavailableCheckIntervalSeconds,
    'blockLeaks': input.blockLeaks,
    'adBlockEnabled': input.adBlockEnabled,
    'adBlockBlockRuleSetPath': input.adBlockBlockRuleSetPath,
    'adBlockAllowRuleSetPath': input.adBlockAllowRuleSetPath,
    'useRussiaRouteData': input.useRussiaRouteData,
    'russiaGeositeRuBlockedPath': input.russiaGeositeRuBlockedPath,
    'russiaGeositeRuAvailableOnlyInsidePath':
        input.russiaGeositeRuAvailableOnlyInsidePath,
    'russiaGeositeCategoryRuPath': input.russiaGeositeCategoryRuPath,
    'russiaGeoipRuBlockedPath': input.russiaGeoipRuBlockedPath,
    'russiaGeoipRuWhitelistPath': input.russiaGeoipRuWhitelistPath,
    'russiaGeoipRuPath': input.russiaGeoipRuPath,
    'russiaCuratedDirectServicesPath': input.russiaCuratedDirectServicesPath,
    'russiaAiServicesPath': input.russiaAiServicesPath,
    'russiaSocialServicesPath': input.russiaSocialServicesPath,
    'trafficRulePreset': input.trafficRulePreset.name,
    'bypassLocalNetwork': input.bypassLocalNetwork,
    'splitRoutingMode': input.splitRoutingMode.name,
    'splitRoutingPackages': input.splitRoutingPackages,
    'logLevel': input.logLevel,
    'tcpFastOpenEnabled': input.tcpFastOpenEnabled,
    'tcpMultiPathEnabled': input.tcpMultiPathEnabled,
    'tlsFragmentationMode': input.tlsFragmentationMode.name,
    'allowUntrustedProxyCertificates': input.allowUntrustedProxyCertificates,
    'interruptExistingConnections': input.interruptExistingConnections,
    'urlTestStrictTolerance': input.urlTestStrictTolerance,
    'experimentalFakeIpEnabled': input.experimentalFakeIpEnabled,
    'markAllServersRussia': input.markAllServersRussia,
    'capabilities': <String, Object?>{
      'apiVersion': input.capabilities.apiVersion,
      'contractStatus': input.capabilities.contractStatus.name,
      'contractError': input.capabilities.contractError,
      'coreVersion': input.capabilities.coreVersion,
      'supportsTargetedUrlTest': input.capabilities.supportsTargetedUrlTest,
      'supportsGroupUrlTestSessions':
          input.capabilities.supportsGroupUrlTestSessions,
      'supportsStructuredProbeErrors':
          input.capabilities.supportsStructuredProbeErrors,
      'supportsOutboundExternalInfo':
          input.capabilities.supportsOutboundExternalInfo,
      'supportsOutboundHttpFetch': input.capabilities.supportsOutboundHttpFetch,
      'supportsMixedRoutingOutbound':
          input.capabilities.supportsMixedRoutingOutbound,
      'supportsUrlTestTimeout': input.capabilities.supportsUrlTestTimeout,
      'supportsUrlTestConcurrency':
          input.capabilities.supportsUrlTestConcurrency,
      'supportsUrlTestDeadline': input.capabilities.supportsUrlTestDeadline,
      'supportsUrlTestForce': input.capabilities.supportsUrlTestForce,
      'supportsUrlTestFailover': input.capabilities.supportsUrlTestFailover,
      'supportsUrlTestQueuePriority':
          input.capabilities.supportsUrlTestQueuePriority,
      'supportsUrlTestUnavailableCheckInterval':
          input.capabilities.supportsUrlTestUnavailableCheckInterval,
      'supportsUrlTestMethod': input.capabilities.supportsUrlTestMethod,
      'supportsUrlTestInterruptDelayThreshold':
          input.capabilities.supportsUrlTestInterruptDelayThreshold,
      'urlTestCompletionModel': input.capabilities.urlTestCompletionModel.name,
      'supportsConfigCheck': input.capabilities.supportsConfigCheck,
      'supportsCloseConnections': input.capabilities.supportsCloseConnections,
      'supportsRealitySpiderX': input.capabilities.supportsRealitySpiderX,
      'supportsXHttp': input.capabilities.supportsXHttp,
      'supportsSplitHttpAlias': input.capabilities.supportsSplitHttpAlias,
      'supportsVlessEncryption': input.capabilities.supportsVlessEncryption,
      'xHttpClientOnly': input.capabilities.xHttpClientOnly,
      'xHttpProfile': input.capabilities.xHttpProfile,
      'xHttpModes': (input.capabilities.xHttpModes.toList()..sort()),
      'xHttpMaxPoolConnections': input.capabilities.xHttpMaxPoolConnections,
      'xHttpMaxPacketUploadBytes': input.capabilities.xHttpMaxPacketUploadBytes,
      'supportsXHttpCloseAll': input.capabilities.supportsXHttpCloseAll,
      'vlessEncryptionClientOnly': input.capabilities.vlessEncryptionClientOnly,
      'vlessEncryptionModes': (input.capabilities.vlessEncryptionModes.toList()
        ..sort()),
      'vlessEncryptionMaxRelays': input.capabilities.vlessEncryptionMaxRelays,
      'vlessEncryptionHandshakeTimeoutMillis':
          input.capabilities.vlessEncryptionHandshakeTimeoutMillis,
      'tunStacks': (input.capabilities.tunStacks.toList()..sort()),
    },
    'ruleContents': rules,
  };
  return sha256.convert(utf8.encode(jsonEncode(identity))).toString();
}

/// Hashing, cache I/O, decoding and generation all stay off the UI isolate.
/// The active runtime config is never used as the cache: the runtime may have
/// mutated it, or a failed reconfiguration may have rolled it back.
Future<SingboxConfigBuildResult> buildOrReuseSingboxConfigInBackground(
  SingboxConfigBuildInput input, {
  required String cachePath,
}) => Isolate.run(() async {
  final fingerprint = await _configFingerprint(input);
  Map<String, dynamic>? entry;
  try {
    final envelope =
        jsonDecode(File(cachePath).readAsStringSync()) as Map<String, dynamic>;
    final payload = envelope['payload'] as String;
    if (envelope['sha256'] == sha256.convert(utf8.encode(payload)).toString()) {
      final candidate = jsonDecode(payload) as Map<String, dynamic>;
      if (candidate['fingerprint'] == fingerprint) entry = candidate;
    }
  } on FileSystemException {
    // Cache absence or an interrupted write is a miss, not a startup failure.
  } on FormatException {
    // Regenerate corrupt cache.
  } on TypeError {
    // Regenerate incompatible cache.
  }
  if (entry != null) {
    try {
      final restored = _restoreConfigEntry(entry, input, fingerprint, true);
      return restored;
    } on FormatException {
      // Invalid cached metadata is also a miss.
    } on TypeError {
      // A changed schema must never break normal config generation.
    }
  }
  final built = buildSingboxConfig(input);
  final json = built.configJson.isNotEmpty
      ? built.configJson
      : File(built.configPath!).readAsStringSync();
  final fresh = <String, dynamic>{
    'fingerprint': fingerprint,
    // Startup validation deliberately switches an invalid selection to lowest.
    // Accept that one transition only if the generated selector already does so.
    'fallbackFingerprint':
        built.selectedProxyInvalid &&
            ((jsonDecode(json) as Map)['outbounds'] as List).any(
              (outbound) =>
                  outbound['tag'] == 'select' &&
                  (outbound['default'] == lowestProxyTag ||
                      (outbound['outbounds'] as List).length == 1),
            )
        ? await _configFingerprint(
            input,
            selectedProxyTagOverride: lowestProxyTag,
          )
        : null,
    'configJson': json,
    'proxyOutboundTagsByIndex': built.plan.proxyOutboundTagsByIndex.map(
      (key, value) => MapEntry(key.toString(), value),
    ),
    'visibleProxyOutboundCount': built.plan.visibleProxyOutboundCount,
    'urlTestOutboundTags': built.plan.urlTestOutboundTags,
    'configOutboundCount': built.configOutboundCount,
    'configInboundCount': built.configInboundCount,
    'configRouteRuleCount': built.configRouteRuleCount,
    'invalidOutbounds': [
      for (final invalid in built.invalidOutbounds)
        {'tag': invalid.tag, 'name': invalid.name, 'reason': invalid.reason},
    ],
    'invalidOutboundCount': built.invalidOutboundCount,
    'selectedProxyInvalid': built.selectedProxyInvalid,
    'startableOutboundCount': built.startableOutboundCount,
  };
  // Do not publish a build made while a rule file was being replaced.
  if (await _configFingerprint(input) != fingerprint) {
    throw StateError(
      'Config inputs changed during preparation. Retry connection.',
    );
  }
  try {
    final payload = jsonEncode(fresh);
    _writeConfigJsonAtomically(
      cachePath,
      jsonEncode({
        'payload': payload,
        'sha256': sha256.convert(utf8.encode(payload)).toString(),
      }),
    );
  } on FileSystemException {
    // An optional cache write must not prevent a valid connection.
  }
  return _restoreConfigEntry(
    fresh,
    input,
    fingerprint,
    false,
    writeCandidate: false,
  );
}, debugName: 'meow-singbox-config-cache');

SingboxConfigBuildResult _restoreConfigEntry(
  Map<String, dynamic> entry,
  SingboxConfigBuildInput input,
  String fingerprint,
  bool reused, {
  bool writeCandidate = true,
}) {
  final json = entry['configJson'] as String;
  final count = entry['configOutboundCount'] as int;
  final returnConfig = input.returnConfig || count < 100;
  final result = SingboxConfigBuildResult(
    plan: SingboxBuildPlan(
      config: returnConfig
          ? jsonDecode(json) as Map<String, dynamic>
          : const <String, dynamic>{},
      proxyOutboundTagsByIndex:
          (entry['proxyOutboundTagsByIndex'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(int.parse(key), value as String),
          ),
      visibleProxyOutboundCount: entry['visibleProxyOutboundCount'] as int,
      urlTestOutboundTags: (entry['urlTestOutboundTags'] as List)
          .cast<String>(),
    ),
    configJson: returnConfig ? json : '',
    configPath: input.outputConfigPath,
    configLength: json.length,
    configOutboundCount: count,
    configInboundCount: entry['configInboundCount'] as int,
    configRouteRuleCount: entry['configRouteRuleCount'] as int,
    invalidOutbounds: [
      for (final invalid in entry['invalidOutbounds'] as List)
        InvalidStartupOutbound(
          tag: invalid['tag'] as String,
          name: invalid['name'] as String,
          reason: invalid['reason'] as String,
        ),
    ],
    invalidOutboundCount: entry['invalidOutboundCount'] as int,
    selectedProxyInvalid: entry['selectedProxyInvalid'] as bool,
    startableOutboundCount: entry['startableOutboundCount'] as int,
    inputFingerprint: fingerprint,
    fallbackInputFingerprint: entry['fallbackFingerprint'] as String?,
    reusedConfig: reused,
  );
  final path = input.outputConfigPath;
  if (writeCandidate && path != null && path.isNotEmpty) {
    _writeConfigJsonAtomically(path, json);
  }
  return result;
}
