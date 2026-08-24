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
      expect(capabilities.tunStacks, isEmpty);
      expect(
        capabilities.urlTestCompletionModel,
        UrlTestCompletionModel.groupEvents,
      );
    });
  });
}
