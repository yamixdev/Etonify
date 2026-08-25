import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';

void main() {
  group('LibboxCapabilities', () {
    test('uses the legacy profile when the handshake is absent', () {
      expect(
        LibboxCapabilities.parseOrLegacy(null),
        same(LibboxCapabilities.bundledLegacy),
      );
      expect(
        LibboxCapabilities.parseOrLegacy('not-json'),
        same(LibboxCapabilities.bundledLegacy),
      );
      expect(
        LibboxCapabilities.parseOrLegacy('{"api_version":0}'),
        same(LibboxCapabilities.bundledLegacy),
      );
      expect(LibboxCapabilities.bundledLegacy.supportsXHttp, isTrue);
      expect(LibboxCapabilities.bundledLegacy.supportsSplitHttpAlias, isTrue);
      expect(LibboxCapabilities.bundledLegacy.supportsVlessEncryption, isTrue);
    });

    test('parses the versioned core contract and ignores unknown fields', () {
      final capabilities = LibboxCapabilities.parseOrLegacy('''
        {
          "api_version": 1,
          "core_version": "1.13.14-etonify",
          "supports_targeted_url_test": true,
          "supports_group_url_test_sessions": true,
          "supports_structured_probe_errors": true,
          "supports_outbound_external_info": true,
          "supports_outbound_http_fetch": true,
          "supports_mixed_routing_outbound": true,
          "supports_url_test_timeout": true,
          "supports_url_test_concurrency": true,
          "supports_url_test_deadline": true,
          "supports_url_test_force": true,
          "supports_url_test_unavailable_check_interval": true,
          "supports_url_test_method": true,
          "supports_url_test_interrupt_delay_threshold": true,
          "url_test_completion_model": "rpc_completion",
          "supports_config_check": true,
          "supports_close_connections": true,
          "supports_reality_spider_x": true,
          "supports_xhttp": true,
          "supports_splithttp_alias": true,
          "supports_vless_encryption": true,
          "tun_stacks": ["SYSTEM", "gvisor", "mixed", ""],
          "future_field": "ignored"
        }
      ''');

      expect(capabilities.hasVersionedContract, isTrue);
      expect(capabilities.apiVersion, 1);
      expect(capabilities.coreVersion, '1.13.14-etonify');
      expect(capabilities.supportsTargetedUrlTest, isTrue);
      expect(capabilities.supportsGroupUrlTestSessions, isTrue);
      expect(capabilities.supportsStructuredProbeErrors, isTrue);
      expect(capabilities.supportsOutboundExternalInfo, isTrue);
      expect(capabilities.supportsOutboundHttpFetch, isTrue);
      expect(capabilities.supportsMixedRoutingOutbound, isTrue);
      expect(capabilities.supportsUrlTestTimeout, isTrue);
      expect(capabilities.supportsUrlTestConcurrency, isTrue);
      expect(capabilities.supportsUrlTestDeadline, isTrue);
      expect(capabilities.supportsUrlTestForce, isTrue);
      expect(capabilities.supportsUrlTestUnavailableCheckInterval, isTrue);
      expect(capabilities.supportsUrlTestMethod, isTrue);
      expect(capabilities.supportsUrlTestInterruptDelayThreshold, isTrue);
      expect(
        capabilities.urlTestCompletionModel,
        UrlTestCompletionModel.rpcCompletion,
      );
      expect(capabilities.supportsConfigCheck, isTrue);
      expect(capabilities.supportsCloseConnections, isTrue);
      expect(capabilities.supportsRealitySpiderX, isTrue);
      expect(capabilities.supportsXHttp, isTrue);
      expect(capabilities.supportsSplitHttpAlias, isTrue);
      expect(capabilities.supportsVlessEncryption, isTrue);
      expect(capabilities.supportsTunStack('system'), isTrue);
      expect(capabilities.supportsTunStack(' GVISOR '), isTrue);
      expect(capabilities.supportsTunStack('mixed'), isTrue);
    });

    test('missing optional fields fail closed', () {
      final capabilities = LibboxCapabilities.parseOrLegacy(
        '{"api_version":1,"url_test_completion_model":"unknown"}',
      );

      expect(capabilities.hasVersionedContract, isTrue);
      expect(capabilities.supportsTargetedUrlTest, isFalse);
      expect(capabilities.supportsConfigCheck, isFalse);
      expect(capabilities.supportsRealitySpiderX, isFalse);
      expect(capabilities.supportsXHttp, isFalse);
      expect(capabilities.supportsSplitHttpAlias, isFalse);
      expect(capabilities.supportsVlessEncryption, isFalse);
      expect(capabilities.supportsOutboundHttpFetch, isFalse);
      expect(capabilities.tunStacks, isEmpty);
      expect(
        capabilities.urlTestCompletionModel,
        UrlTestCompletionModel.groupEvents,
      );
    });

    test('strict parser accepts the complete 1.14 API v2 contract', () {
      final capabilities = LibboxCapabilities.parseStrict(_strictContract);

      expect(capabilities.isCompatible, isTrue);
      expect(capabilities.contractError, isEmpty);
      expect(capabilities.apiVersion, 2);
      expect(capabilities.coreVersion, '1.14.0-rc.1-etonify.2');
      expect(capabilities.supportsUrlTestFailover, isTrue);
      expect(capabilities.xHttpProfile, 'etonify_client_v1');
      expect(capabilities.supportsXHttpMode('packet-up'), isTrue);
      expect(capabilities.supportsXHttpMode('unsupported'), isFalse);
      expect(capabilities.xHttpMaxPoolConnections, 16);
      expect(capabilities.xHttpMaxPacketUploadBytes, 262144);
      expect(capabilities.vlessEncryptionModes, contains('mlkem768'));
      expect(capabilities.vlessEncryptionMaxRelays, 8);
    });

    test('strict parser rejects an absent, old, or incomplete contract', () {
      expect(
        LibboxCapabilities.parseStrict(null).contractError,
        'core_contract_unavailable',
      );
      expect(
        LibboxCapabilities.parseStrict(
          _strictContract.replaceFirst('"api_version": 2', '"api_version": 1'),
        ).contractError,
        'core_api_too_old',
      );
      expect(
        LibboxCapabilities.parseStrict(
          _strictContract.replaceFirst(
            '"supports_xhttp_close_all": true',
            '"supports_xhttp_close_all": false',
          ),
        ).contractError,
        'core_xhttp_contract_incomplete',
      );
    });
  });
}

const _strictContract = '''
{
  "api_version": 2,
  "core_version": "1.14.0-rc.1-etonify.2",
  "supports_targeted_url_test": true,
  "supports_group_url_test_sessions": true,
  "supports_structured_probe_errors": true,
  "supports_outbound_external_info": true,
  "supports_outbound_http_fetch": true,
  "supports_mixed_routing_outbound": false,
  "supports_url_test_timeout": true,
  "supports_url_test_concurrency": true,
  "supports_url_test_deadline": true,
  "supports_url_test_force": true,
  "supports_url_test_failover": true,
  "supports_url_test_unavailable_check_interval": false,
  "supports_url_test_method": false,
  "supports_url_test_interrupt_delay_threshold": false,
  "url_test_completion_model": "group_events",
  "supports_config_check": true,
  "supports_close_connections": true,
  "supports_reality_spider_x": true,
  "supports_xhttp": true,
  "supports_splithttp_alias": true,
  "xhttp_client_only": true,
  "xhttp_profile": "etonify_client_v1",
  "xhttp_modes": ["packet-up", "stream-up", "stream-one"],
  "xhttp_max_pool_connections": 16,
  "xhttp_max_packet_upload_bytes": 262144,
  "supports_xhttp_close_all": true,
  "supports_vless_encryption": true,
  "vless_encryption_client_only": true,
  "vless_encryption_modes": ["1rtt", "0rtt", "native", "xorpub", "random", "x25519", "mlkem768"],
  "vless_encryption_max_relays": 8,
  "vless_encryption_handshake_timeout_ms": 12000,
  "tun_stacks": ["system", "gvisor", "mixed"]
}
''';
