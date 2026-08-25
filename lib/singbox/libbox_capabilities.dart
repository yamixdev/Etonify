import 'dart:convert';

enum UrlTestCompletionModel { rpcCompletion, groupEvents }

enum LibboxContractStatus { legacy, compatible, incompatible }

/// Describes the native features available to this client build.
class LibboxCapabilities {
  const LibboxCapabilities({
    this.contractStatus = LibboxContractStatus.compatible,
    this.contractError = '',
    required this.apiVersion,
    required this.coreVersion,
    required this.supportsTargetedUrlTest,
    required this.supportsGroupUrlTestSessions,
    required this.supportsStructuredProbeErrors,
    required this.supportsOutboundExternalInfo,
    this.supportsOutboundHttpFetch = false,
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
    this.supportsUrlTestFailover = false,
    this.xHttpClientOnly = false,
    this.xHttpProfile = '',
    this.xHttpModes = const <String>{},
    this.xHttpMaxPoolConnections = 0,
    this.xHttpMaxPacketUploadBytes = 0,
    this.supportsXHttpCloseAll = false,
    this.vlessEncryptionClientOnly = false,
    this.vlessEncryptionModes = const <String>{},
    this.vlessEncryptionMaxRelays = 0,
    this.vlessEncryptionHandshakeTimeoutMillis = 0,
    required this.tunStacks,
  });

  static const minimumSupportedApiVersion = 2;
  static const maximumSupportedApiVersion = 2;
  static const expectedCoreSeries = '1.14.';

  static const bundledLegacy = LibboxCapabilities(
    contractStatus: LibboxContractStatus.legacy,
    apiVersion: 0,
    coreVersion: '',
    supportsTargetedUrlTest: false,
    supportsGroupUrlTestSessions: false,
    supportsStructuredProbeErrors: false,
    supportsOutboundExternalInfo: false,
    supportsOutboundHttpFetch: false,
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

  static const incompatible = LibboxCapabilities(
    contractStatus: LibboxContractStatus.incompatible,
    contractError: 'core_contract_unavailable',
    apiVersion: 0,
    coreVersion: '',
    supportsTargetedUrlTest: false,
    supportsGroupUrlTestSessions: false,
    supportsStructuredProbeErrors: false,
    supportsOutboundExternalInfo: false,
    supportsOutboundHttpFetch: false,
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
    supportsRealitySpiderX: false,
    tunStacks: <String>{},
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
      return _parseVersioned(json) ?? bundledLegacy;
    } on FormatException {
      return bundledLegacy;
    } on TypeError {
      return bundledLegacy;
    }
  }

  /// Parses the contract for an Android production runtime.
  ///
  /// Unlike [parseOrLegacy], an absent or malformed bridge fails closed. The
  /// legacy profile is only safe when the caller explicitly knows that the
  /// bundled pre-contract core is in use (tests and older app releases).
  static LibboxCapabilities parseStrict(String? raw) {
    final normalized = raw?.trim() ?? '';
    if (normalized.isEmpty) return incompatible;
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) return incompatible;
      final json = decoded.map((key, value) => MapEntry(key.toString(), value));
      final parsed = _parseVersioned(json);
      if (parsed == null) return incompatible;
      final error = parsed._compatibilityError;
      if (error.isEmpty) return parsed;
      return parsed._copyContract(
        status: LibboxContractStatus.incompatible,
        error: error,
      );
    } on FormatException {
      return incompatible;
    } on TypeError {
      return incompatible;
    }
  }

  static LibboxCapabilities? _parseVersioned(Map<String, Object?> json) {
    final apiVersion = _readInt(json, 'api_version');
    if (apiVersion <= 0) return null;
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
      supportsOutboundHttpFetch: _readBool(
        json,
        'supports_outbound_http_fetch',
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
      supportsUrlTestFailover: _readBool(json, 'supports_url_test_failover'),
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
      xHttpClientOnly: _readBool(json, 'xhttp_client_only'),
      xHttpProfile: _readString(json, 'xhttp_profile'),
      xHttpModes: _readStringSet(json, 'xhttp_modes'),
      xHttpMaxPoolConnections: _readInt(json, 'xhttp_max_pool_connections'),
      xHttpMaxPacketUploadBytes: _readInt(
        json,
        'xhttp_max_packet_upload_bytes',
      ),
      supportsXHttpCloseAll: _readBool(json, 'supports_xhttp_close_all'),
      supportsVlessEncryption: _readBool(json, 'supports_vless_encryption'),
      vlessEncryptionClientOnly: _readBool(
        json,
        'vless_encryption_client_only',
      ),
      vlessEncryptionModes: _readStringSet(json, 'vless_encryption_modes'),
      vlessEncryptionMaxRelays: _readInt(json, 'vless_encryption_max_relays'),
      vlessEncryptionHandshakeTimeoutMillis: _readInt(
        json,
        'vless_encryption_handshake_timeout_ms',
      ),
      tunStacks: _readStringSet(json, 'tun_stacks'),
    );
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
  final LibboxContractStatus contractStatus;
  final String contractError;
  final String coreVersion;
  final bool supportsTargetedUrlTest;
  final bool supportsGroupUrlTestSessions;
  final bool supportsStructuredProbeErrors;
  final bool supportsOutboundExternalInfo;
  final bool supportsOutboundHttpFetch;
  final bool supportsMixedRoutingOutbound;
  final bool supportsUrlTestTimeout;
  final bool supportsUrlTestConcurrency;
  final bool supportsUrlTestDeadline;
  final bool supportsUrlTestForce;
  final bool supportsUrlTestFailover;
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
  final bool xHttpClientOnly;
  final String xHttpProfile;
  final Set<String> xHttpModes;
  final int xHttpMaxPoolConnections;
  final int xHttpMaxPacketUploadBytes;
  final bool supportsXHttpCloseAll;
  final bool vlessEncryptionClientOnly;
  final Set<String> vlessEncryptionModes;
  final int vlessEncryptionMaxRelays;
  final int vlessEncryptionHandshakeTimeoutMillis;
  final Set<String> tunStacks;

  bool get hasVersionedContract => apiVersion > 0;
  bool get isLegacyContract => contractStatus == LibboxContractStatus.legacy;
  bool get isCompatible => contractStatus != LibboxContractStatus.incompatible;

  String get _compatibilityError {
    if (apiVersion < minimumSupportedApiVersion) {
      return 'core_api_too_old';
    }
    if (apiVersion > maximumSupportedApiVersion) {
      return 'core_api_too_new';
    }
    if (!coreVersion.startsWith(expectedCoreSeries)) {
      return 'core_version_mismatch';
    }
    if (!supportsConfigCheck || !supportsCloseConnections) {
      return 'core_lifecycle_contract_incomplete';
    }
    if (!supportsTargetedUrlTest ||
        !supportsGroupUrlTestSessions ||
        !supportsStructuredProbeErrors ||
        !supportsUrlTestTimeout ||
        !supportsUrlTestConcurrency ||
        !supportsUrlTestDeadline ||
        !supportsUrlTestForce ||
        !supportsUrlTestFailover) {
      return 'core_urltest_contract_incomplete';
    }
    if (!supportsOutboundExternalInfo || !supportsOutboundHttpFetch) {
      return 'core_network_contract_incomplete';
    }
    if (tunStacks.isEmpty) {
      return 'core_tun_capabilities_missing';
    }
    if (supportsXHttp &&
        (!xHttpClientOnly ||
            xHttpProfile.isEmpty ||
            xHttpModes.isEmpty ||
            xHttpMaxPoolConnections <= 0 ||
            xHttpMaxPacketUploadBytes <= 0 ||
            !supportsXHttpCloseAll)) {
      return 'core_xhttp_contract_incomplete';
    }
    if (supportsVlessEncryption &&
        (!vlessEncryptionClientOnly ||
            vlessEncryptionModes.isEmpty ||
            vlessEncryptionMaxRelays <= 0 ||
            vlessEncryptionHandshakeTimeoutMillis <= 0)) {
      return 'core_vless_encryption_contract_incomplete';
    }
    return '';
  }

  LibboxCapabilities _copyContract({
    required LibboxContractStatus status,
    required String error,
  }) {
    return LibboxCapabilities(
      contractStatus: status,
      contractError: error,
      apiVersion: apiVersion,
      coreVersion: coreVersion,
      supportsTargetedUrlTest: supportsTargetedUrlTest,
      supportsGroupUrlTestSessions: supportsGroupUrlTestSessions,
      supportsStructuredProbeErrors: supportsStructuredProbeErrors,
      supportsOutboundExternalInfo: supportsOutboundExternalInfo,
      supportsOutboundHttpFetch: supportsOutboundHttpFetch,
      supportsMixedRoutingOutbound: supportsMixedRoutingOutbound,
      supportsUrlTestTimeout: supportsUrlTestTimeout,
      supportsUrlTestConcurrency: supportsUrlTestConcurrency,
      supportsUrlTestDeadline: supportsUrlTestDeadline,
      supportsUrlTestForce: supportsUrlTestForce,
      supportsUrlTestFailover: supportsUrlTestFailover,
      supportsUrlTestUnavailableCheckInterval:
          supportsUrlTestUnavailableCheckInterval,
      supportsUrlTestMethod: supportsUrlTestMethod,
      supportsUrlTestInterruptDelayThreshold:
          supportsUrlTestInterruptDelayThreshold,
      urlTestCompletionModel: urlTestCompletionModel,
      supportsConfigCheck: supportsConfigCheck,
      supportsCloseConnections: supportsCloseConnections,
      supportsRealitySpiderX: supportsRealitySpiderX,
      supportsXHttp: supportsXHttp,
      supportsSplitHttpAlias: supportsSplitHttpAlias,
      supportsVlessEncryption: supportsVlessEncryption,
      xHttpClientOnly: xHttpClientOnly,
      xHttpProfile: xHttpProfile,
      xHttpModes: xHttpModes,
      xHttpMaxPoolConnections: xHttpMaxPoolConnections,
      xHttpMaxPacketUploadBytes: xHttpMaxPacketUploadBytes,
      supportsXHttpCloseAll: supportsXHttpCloseAll,
      vlessEncryptionClientOnly: vlessEncryptionClientOnly,
      vlessEncryptionModes: vlessEncryptionModes,
      vlessEncryptionMaxRelays: vlessEncryptionMaxRelays,
      vlessEncryptionHandshakeTimeoutMillis:
          vlessEncryptionHandshakeTimeoutMillis,
      tunStacks: tunStacks,
    );
  }

  bool supportsXHttpMode(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty || xHttpModes.contains(normalized);
  }

  bool supportsVlessEncryptionValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'none') return true;
    return vlessEncryptionModes.any(normalized.contains);
  }

  bool supportsTunStack(String value) =>
      tunStacks.contains(value.trim().toLowerCase());
}
