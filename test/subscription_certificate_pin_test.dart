import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/subscription/outbound_schema.dart';
import 'package:meow_client/data/subscription/parsers/cert_pin_utils.dart';
import 'package:meow_client/data/subscription/parsers/clash_parser.dart';
import 'package:meow_client/data/subscription/parsers/link_parser.dart';
import 'package:meow_client/data/subscription/parsers/xray_config_parser.dart';

void main() {
  group('Certificate PIN Normalization', () {
    const rawHex =
        '286a028eb00102030405060708090a0b0c0d0e0f101112131415161718191a1b';
    const hexWithColons =
        '28:6A:02:8E:B0:01:02:03:04:05:06:07:08:09:0A:0B:0C:0D:0E:0F:10:11:12:13:14:15:16:17:18:19:1A:1B';
    const hexWithSpaces =
        '28 6a 02 8e b0 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b';

    final expectedBytes = [
      0x28,
      0x6a,
      0x02,
      0x8e,
      0xb0,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x09,
      0x0a,
      0x0b,
      0x0c,
      0x0d,
      0x0e,
      0x0f,
      0x10,
      0x11,
      0x12,
      0x13,
      0x14,
      0x15,
      0x16,
      0x17,
      0x18,
      0x19,
      0x1a,
      0x1b,
    ];
    final expectedBase64 = base64.encode(expectedBytes);

    test('normalizes hex with colons', () {
      final pins = normalizeCertPins(hexWithColons);
      expect(pins, [expectedBase64]);
    });

    test('normalizes plain hex', () {
      final pins = normalizeCertPins(rawHex);
      expect(pins, [expectedBase64]);
    });

    test('normalizes hex with spaces', () {
      final pins = normalizeCertPins(hexWithSpaces);
      expect(pins, [expectedBase64]);
    });

    test('normalizes base64 string', () {
      final pins = normalizeCertPins(expectedBase64);
      expect(pins, [expectedBase64]);
    });

    test('normalizes list of mixed pins', () {
      final pins = normalizeCertPins([hexWithColons, expectedBase64]);
      // Should deduplicate identical hashes
      expect(pins, [expectedBase64]);
    });
  });

  group('XrayConfigParser certificate_sha256', () {
    test('parses pinnedPeerCertSha256 and grpc transport', () {
      const xrayJson = '''
      {
        "outbounds": [
          {
            "tag": "proxy-lte-118",
            "protocol": "vless",
            "settings": {
              "vnext": [
                {
                  "address": "198.51.100.1",
                  "port": 443,
                  "users": [
                    {
                      "id": "a0000000-0000-0000-0000-000000000001",
                      "encryption": "none"
                    }
                  ]
                }
              ]
            },
            "streamSettings": {
              "network": "grpc",
              "security": "tls",
              "tlsSettings": {
                "serverName": "lte118.vpn.internal",
                "pinnedPeerCertSha256": "28:6A:02:8E:B0:01:02:03:04:05:06:07:08:09:0A:0B:0C:0D:0E:0F:10:11:12:13:14:15:16:17:18:19:1A:1B",
                "fingerprint": "qq"
              },
              "grpcSettings": {
                "serviceName": "vless-grpc"
              }
            }
          }
        ]
      }
      ''';

      final outbounds = XrayConfigParser.parse(xrayJson);
      expect(outbounds.length, 1);

      final outbound = outbounds.first;
      expect(outbound['type'], 'vless');
      expect(outbound['server'], '198.51.100.1');
      expect(outbound['server_port'], 443);

      final tls = outbound['tls'] as Map<String, dynamic>;
      expect(tls['enabled'], true);
      expect(tls['server_name'], 'lte118.vpn.internal');
      expect(tls['utls']?['fingerprint'], 'qq');

      final pins = tls['certificate_sha256'] as List<String>;
      expect(pins.length, 1);

      // Verify it passes ParsedOutboundSchema sanitize and validate
      final sanitized = ParsedOutboundSchema.sanitize(outbound);
      expect(sanitized, isNotNull);
      final sanitizedTls = sanitized!['tls'] as Map<String, dynamic>;
      expect(sanitizedTls['certificate_sha256'], pins);
    });
  });

  group('LinkParser certificate_sha256', () {
    test('parses pinnedPeerCertSha256 from URI query parameter', () {
      const uri =
          'vless://a0000000-0000-0000-0000-000000000001@198.51.100.1:443?security=tls&sni=lte118.vpn.internal&fp=qq&pinnedPeerCertSha256=28:6A:02:8E:B0:01:02:03:04:05:06:07:08:09:0A:0B:0C:0D:0E:0F:10:11:12:13:14:15:16:17:18:19:1A:1B&type=grpc&serviceName=vless-grpc#0.1X%20-%20LTE%20%E2%84%96118%20-%20%D0%9C%D0%BE%D1%81%D0%BA%D0%B2%D0%B0';
      final parsed = LinkParser.tryParse(uri);
      expect(parsed, isNotNull);

      final tls = parsed!['tls'] as Map<String, dynamic>;
      expect(tls['enabled'], true);
      expect(tls['server_name'], 'lte118.vpn.internal');
      expect(tls['certificate_sha256'], isNotEmpty);

      final sanitized = ParsedOutboundSchema.sanitize(parsed);
      expect(sanitized, isNotNull);
      expect((sanitized!['tls'] as Map)['certificate_sha256'], isNotEmpty);
    });
  });

  group('ClashParser certificate_sha256', () {
    test('parses pinned-peer-cert-sha256 from Clash Meta proxy', () {
      const clashYaml = '''
proxies:
  - name: "LTE 118"
    type: vless
    server: 198.51.100.1
    port: 443
    uuid: a0000000-0000-0000-0000-000000000001
    tls: true
    servername: lte118.vpn.internal
    client-fingerprint: qq
    pinned-peer-cert-sha256: 28:6A:02:8E:B0:01:02:03:04:05:06:07:08:09:0A:0B:0C:0D:0E:0F:10:11:12:13:14:15:16:17:18:19:1A:1B
    network: grpc
    grpc-opts:
      grpc-service-name: vless-grpc
''';

      final outbounds = ClashParser.parse(clashYaml);
      expect(outbounds.length, 1);

      final outbound = outbounds.first;
      final tls = outbound['tls'] as Map<String, dynamic>;
      expect(tls['enabled'], true);
      expect(tls['certificate_sha256'], isNotEmpty);

      final sanitized = ParsedOutboundSchema.sanitize(outbound);
      expect(sanitized, isNotNull);
      expect((sanitized!['tls'] as Map)['certificate_sha256'], isNotEmpty);
    });
  });
}
