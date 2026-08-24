import 'dart:convert';

enum UrlTestCompletionModel { rpcCompletion, groupEvents }

/// Describes the native features available to this client build.
class LibboxCapabilities {
  const LibboxCapabilities({
    required this.apiVersion,
    required this.coreVersion,
    required this.supportsTargetedUrlTest,
    required this.supportsGroupUrlTestSessions,
    required this.supportsStructuredProbeErrors,
    required this.supportsOutboundExternalInfo,
    required this.supportsMixedRoutingOutbound,
    required this.supportsUrlTestTimeout,
    required this.supportsUrlTestConcurrency,
    required this.supportsUrlTestDeadline,
    required this.supportsUrlTestForce,
    required this.supportsUrlTestUnavailableCheckInterval,
    required this.supportsUrlTestMethod,
    required this.supportsUrlTestInterruptDelayThreshold,
    required this.urlTestCompletionModel,
    required this.supportsConfigCheck,
    required this.supportsCloseConnections,
    required this.supportsRealitySpiderX,
    this.supportsXHttp = false,
    this.supportsSplitHttpAlias = false,
    this.supportsVlessEncryption = false,
    required this.tunStacks,
  });

  static const bundledLegacy = LibboxCapabilities(
    apiVersion: 0,
    coreVersion: '',
    supportsTargetedUrlTest: false,
    supportsGroupUrlTestSessions: false,
    supportsStructuredProbeErrors: false,
    supportsOutboundExternalInfo: false,
    supportsMixedRoutingOutbound: false,
    supportsUrlTestTimeout: false,
    supportsUrlTestConcurrency: false,
    supportsUrlTestDeadline: false,
    supportsUrlTestForce: false,
    supportsUrlTestUnavailableCheckInterval: false,
    supportsUrlTestMethod: false,
    supportsUrlTestInterruptDelayThreshold: false,
    urlTestCompletionModel: UrlTestCompletionModel.groupEvents,
    supportsConfigCheck: false,
    supportsCloseConnections: false,
    // The unversioned libbox bundled with Etonify 0.2.1 accepted spider_x.
    supportsRealitySpiderX: true,
    // Keep the last unversioned Etonify core compatible. Replacement cores
    // must advertise these extensions through the versioned contract.
    supportsXHttp: true,
    supportsSplitHttpAlias: true,
    supportsVlessEncryption: true,
    tunStacks: <String>{'system', 'gvisor', 'mixed'},
  );

  /// Parses the versioned contract exposed by Etonify's libbox build.
  ///
  /// Every optional capability fails closed. An absent bridge, malformed JSON,
  /// or an unversioned document preserves the behavior of the bundled legacy
  /// core instead of guessing what a replacement core supports.
  static LibboxCapabilities parseOrLegacy(String? raw) {
    final normalized = raw?.trim() ?? '';
    if (normalized.isEmpty) return bundledLegacy;
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) return bundledLegacy;
      final json = decoded.map((key, value) => MapEntry(key.toString(), value));
      final apiVersion = _readInt(json, 'api_version');
      if (apiVersion <= 0) return bundledLegacy;
      final completionModel = switch (_readString(
        json,
        'url_test_completion_model',
      )) {
        'rpc_completion' => UrlTestCompletionModel.rpcCompletion,
        _ => UrlTestCompletionModel.groupEvents,
      };
      return LibboxCapabilities(
        apiVersion: apiVersion,
        coreVersion: _readString(json, 'core_version'),
        supportsTargetedUrlTest: _readBool(json, 'supports_targeted_url_test'),
        supportsGroupUrlTestSessions: _readBool(
          json,
          'supports_group_url_test_sessions',
        ),
        supportsStructuredProbeErrors: _readBool(
          json,
          'supports_structured_probe_errors',
        ),
        supportsOutboundExternalInfo: _readBool(
          json,
          'supports_outbound_external_info',
        ),
        supportsMixedRoutingOutbound: _readBool(
          json,
          'supports_mixed_routing_outbound',
        ),
        supportsUrlTestTimeout: _readBool(json, 'supports_url_test_timeout'),
        supportsUrlTestConcurrency: _readBool(
          json,
          'supports_url_test_concurrency',
        ),
        supportsUrlTestDeadline: _readBool(json, 'supports_url_test_deadline'),
        supportsUrlTestForce: _readBool(json, 'supports_url_test_force'),
        supportsUrlTestUnavailableCheckInterval: _readBool(
          json,
          'supports_url_test_unavailable_check_interval',
        ),
        supportsUrlTestMethod: _readBool(json, 'supports_url_test_method'),
        supportsUrlTestInterruptDelayThreshold: _readBool(
          json,
          'supports_url_test_interrupt_delay_threshold',
        ),
        urlTestCompletionModel: completionModel,
        supportsConfigCheck: _readBool(json, 'supports_config_check'),
        supportsCloseConnections: _readBool(json, 'supports_close_connections'),
        supportsRealitySpiderX: _readBool(json, 'supports_reality_spider_x'),
        supportsXHttp: _readBool(json, 'supports_xhttp'),
        supportsSplitHttpAlias: _readBool(json, 'supports_splithttp_alias'),
        supportsVlessEncryption: _readBool(json, 'supports_vless_encryption'),
        tunStacks: _readStringSet(json, 'tun_stacks'),
      );
    } on FormatException {
      return bundledLegacy;
    } on TypeError {
      return bundledLegacy;
    }
  }

  static bool _readBool(Map<String, Object?> json, String key) =>
      json[key] == true;

  static int _readInt(Map<String, Object?> json, String key) {
    final value = json[key];
    return value is num ? value.toInt() : 0;
  }

  static String _readString(Map<String, Object?> json, String key) {
    final value = json[key];
    return value is String ? value.trim() : '';
  }

  static Set<String> _readStringSet(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! List) return const <String>{};
    return Set<String>.unmodifiable(
      value
          .whereType<String>()
          .map((entry) => entry.trim().toLowerCase())
          .where((entry) => entry.isNotEmpty),
    );
  }

  final int apiVersion;
  final String coreVersion;
  final bool supportsTargetedUrlTest;
  final bool supportsGroupUrlTestSessions;
  final bool supportsStructuredProbeErrors;
  final bool supportsOutboundExternalInfo;
  final bool supportsMixedRoutingOutbound;
  final bool supportsUrlTestTimeout;
  final bool supportsUrlTestConcurrency;
  final bool supportsUrlTestDeadline;
  final bool supportsUrlTestForce;
  final bool supportsUrlTestUnavailableCheckInterval;
  final bool supportsUrlTestMethod;
  final bool supportsUrlTestInterruptDelayThreshold;
  final UrlTestCompletionModel urlTestCompletionModel;
  final bool supportsConfigCheck;
  final bool supportsCloseConnections;
  final bool supportsRealitySpiderX;
  final bool supportsXHttp;
  final bool supportsSplitHttpAlias;
  final bool supportsVlessEncryption;
  final Set<String> tunStacks;

  bool get hasVersionedContract => apiVersion > 0;

  bool supportsTunStack(String value) =>
      tunStacks.contains(value.trim().toLowerCase());
}
