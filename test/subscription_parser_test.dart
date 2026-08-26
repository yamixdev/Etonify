import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/subscription/parsers/clash_parser.dart';
import 'package:meow_client/data/subscription/parsers/link_parser.dart';
import 'package:meow_client/data/subscription/parsers/singbox_config_parser.dart';
import 'package:meow_client/data/subscription/parsers/sip008_parser.dart';
import 'package:meow_client/data/subscription/parsers/wireguard_config_parser.dart';
import 'package:meow_client/data/subscription/parsers/xray_config_parser.dart';
import 'package:meow_client/data/subscription/outbound_schema.dart';
import 'package:meow_client/data/subscription/subscription_parser.dart';

void main() {
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Link Parser Tests
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('LinkParser', () {
    test('parses VLESS link', () {
      const link =
          'vless://7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f@server.com:443'
          '?type=ws&security=tls&sni=example.com&fp=chrome&flow=xtls-rprx-vision&packetEncoding=xudp'
          '&path=%2Fpath&host=example.com#My%20Server';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'vless');
      expect(r['server'], 'server.com');
      expect(r['server_port'], 443);
      expect(r['uuid'], '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f');
      expect(r['flow'], 'xtls-rprx-vision');
      expect(r['packet_encoding'], 'xudp');
      expect(r['tls']['enabled'], true);
      expect(r['tls']['server_name'], 'example.com');
      expect(r['tls']['utls']['fingerprint'], 'chrome');
      expect(r['transport']['type'], 'ws');
      expect(r['transport']['path'], '/path');
      expect(r['_name'], 'My Server');
    });

    test('parses VLESS link with Reality', () {
      const link =
          'vless://uuid@server.com:443'
          '?type=tcp&security=reality&sni=www.google.com'
          '&fp=chrome&pbk=publickey123&sid=ab01#Reality';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'vless');
      expect(r['tls']['enabled'], true);
      expect(r['tls']['reality']['enabled'], true);
      expect(r['tls']['reality']['public_key'], 'publickey123');
      expect(r['tls']['reality']['short_id'], 'ab01');
    });

    test('parses VLESS link with Reality spider_x', () {
      const link =
          'vless://uuid@server.com:443'
          '?type=tcp&security=reality&sni=www.google.com'
          '&fp=chrome&pbk=publickey123&sid=ab01&spx=%2Fassets%3Fed%3D2560#Reality';

      final r = LinkParser.tryParse(link)!;
      expect(r['tls']['reality']['spider_x'], '/assets?ed=2560');
    });

    test('uses interoperable ALPN defaults for VLESS XHTTP links', () {
      const link =
          'vless://uuid@server.com:443'
          '?type=xhttp&security=tls&sni=example.com#XHTTP';

      final r = LinkParser.tryParse(link)!;

      expect(r['transport']['type'], 'xhttp');
      expect(r['tls']['alpn'], ['h2', 'http/1.1']);
    });

    test('preserves explicit ALPN values for VLESS XHTTP links', () {
      const link =
          'vless://uuid@server.com:443'
          '?type=xhttp&security=tls&sni=example.com&alpn=h3%2Ch2#XHTTP';

      final r = LinkParser.tryParse(link)!;

      expect(r['tls']['alpn'], ['h3', 'h2']);
    });

    test('parses VLESS link encryption', () {
      const link =
          'vless://uuid@server.com:443'
          '?type=tcp&encryption=mlkem768x25519plus.native.0rtt.MDG42I0GTLyH5a6fuXipicFe-A_m-FHNYyJGkheQJTs#Encrypted';

      final r = LinkParser.tryParse(link)!;
      expect(
        r['encryption'],
        'mlkem768x25519plus.native.0rtt.MDG42I0GTLyH5a6fuXipicFe-A_m-FHNYyJGkheQJTs',
      );
    });

    test('rejects invalid VLESS packet encoding during import validation', () {
      const outbound = {
        'type': 'vless',
        'tag': 'bad-vless',
        'server': 'server.com',
        'server_port': 443,
        'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
        'packet_encoding': 'wat',
      };

      expect(
        ParsedOutboundSchema.validate(outbound),
        'invalid vless packet_encoding: wat',
      );
      expect(ParsedOutboundSchema.sanitize(outbound), isNull);
    });

    test('rejects Snowtun outbounds without client runtime integration', () {
      const outbound = {
        'type': 'snowtun',
        'tag': 'snowtun',
        'server': 'server.example',
        'server_port': 443,
        'conf_id': 'example',
        'xtun': {'enabled': true},
      };

      expect(
        ParsedOutboundSchema.validate(outbound),
        'unsupported outbound type: snowtun',
      );
      expect(ParsedOutboundSchema.sanitize(outbound), isNull);
    });

    test(
      'validates VLESS reality flow during import and startup validation',
      () {
        const baseOutbound = {
          'type': 'vless',
          'tag': 'vless',
          'server': 'server.com',
          'server_port': 443,
          'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
          'tls': {
            'enabled': true,
            'utls': {'enabled': true, 'fingerprint': 'chrome'},
            'reality': {
              'enabled': true,
              'public_key': 'thwa3P0vSbbPNr0n94LqAzpFJGwTX3bpIlTyrIis7S8',
            },
          },
        };

        expect(
          ParsedOutboundSchema.validate({
            ...baseOutbound,
            'flow': 'xtls-rprx-vision',
          }),
          isNull,
        );
        expect(
          ParsedOutboundSchema.validate({...baseOutbound, 'flow': ''}),
          isNull,
        );
        expect(
          ParsedOutboundSchema.validate({
            ...baseOutbound,
            'flow': 'xtls-rprx-direct',
          }),
          'unsupported vless flow: xtls-rprx-direct',
        );
        expect(
          ParsedOutboundSchema.sanitize({
            ...baseOutbound,
            'flow': 'xtls-rprx-direct',
          }),
          isNull,
        );
      },
    );

    test(
      'rejects transport paths with invalid URL escapes during import validation',
      () {
        const baseOutbound = {
          'type': 'vless',
          'tag': 'bad-path',
          'server': 'server.com',
          'server_port': 443,
          'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
        };

        final invalidWsPath = {
          ...baseOutbound,
          'transport': {'type': 'ws', 'path': '/api/%zz'},
        };
        final invalidXhttpPath = {
          ...baseOutbound,
          'transport': {'type': 'xhttp', 'path': '/api?ed=%'},
        };

        expect(
          ParsedOutboundSchema.validate(invalidWsPath),
          'invalid ws path: invalid URL escape "%zz"',
        );
        expect(ParsedOutboundSchema.sanitize(invalidWsPath), isNull);
        expect(
          ParsedOutboundSchema.validate(invalidXhttpPath),
          'invalid xhttp path: invalid URL escape "%"',
        );
        expect(ParsedOutboundSchema.sanitize(invalidXhttpPath), isNull);
      },
    );

    test('validates more sing-box init constraints before startup', () {
      expect(
        ParsedOutboundSchema.validate(const {
          'type': 'vmess',
          'tag': 'bad-vmess',
          'server': 'server.com',
          'server_port': 443,
          'uuid': 'test-uuid',
          'packet_encoding': 'wat',
        }),
        'invalid vmess packet_encoding: wat',
      );
      expect(
        ParsedOutboundSchema.validate(const {
          'type': 'tuic',
          'tag': 'bad-tuic',
          'server': 'server.com',
          'server_port': 443,
          'uuid': 'test-uuid',
        }),
        'invalid tuic uuid: test-uuid',
      );
      expect(
        ParsedOutboundSchema.validate(const {
          'type': 'tuic',
          'tag': 'bad-tuic',
          'server': 'server.com',
          'server_port': 443,
          'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
          'udp_over_stream': true,
          'udp_relay_mode': 'quic',
        }),
        'udp_over_stream is conflict with udp_relay_mode',
      );
      expect(
        ParsedOutboundSchema.validate(const {
          'type': 'hysteria2',
          'tag': 'bad-hy2',
          'server': 'server.com',
          'server_port': 443,
          'tls': {'enabled': true},
          'obfs': {'type': 'salamander'},
        }),
        'missing hysteria2 obfs password',
      );
      expect(
        ParsedOutboundSchema.validate(const {
          'type': 'wireguard',
          'tag': 'bad-wg',
          'private_key': 'broken',
          'address': ['10.0.0.2/32'],
        }),
        'invalid wireguard private_key',
      );
    });

    test('validates reality short_id and utls fingerprint before startup', () {
      const baseOutbound = {
        'type': 'vless',
        'tag': 'bad-reality',
        'server': 'server.com',
        'server_port': 443,
        'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
        'tls': {
          'enabled': true,
          'utls': {'enabled': true, 'fingerprint': 'chrome'},
          'reality': {
            'enabled': true,
            'public_key': 'thwa3P0vSbbPNr0n94LqAzpFJGwTX3bpIlTyrIis7S8',
          },
        },
      };

      expect(
        ParsedOutboundSchema.validate({
          ...baseOutbound,
          'tls': {
            'enabled': true,
            'utls': {'enabled': true, 'fingerprint': 'chrome'},
            'reality': {
              'enabled': true,
              'public_key': 'thwa3P0vSbbPNr0n94LqAzpFJGwTX3bpIlTyrIis7S8',
              'short_id': 'xyz',
            },
          },
        }),
        'invalid reality short_id',
      );
      expect(
        ParsedOutboundSchema.validate({
          ...baseOutbound,
          'tls': {
            'enabled': true,
            'utls': {'enabled': true, 'fingerprint': 'chrome'},
            'reality': {
              'enabled': true,
              'public_key': 'thwa3P0vSbbPNr0n94LqAzpFJGwTX3bpIlTyrIis7S8',
              'short_id': 'ab01,cd02',
            },
          },
        }),
        isNull,
      );
      expect(
        ParsedOutboundSchema.validate({
          ...baseOutbound,
          'tls': {
            'enabled': true,
            'utls': {'enabled': true, 'fingerprint': 'potato'},
            'reality': {
              'enabled': true,
              'public_key': 'thwa3P0vSbbPNr0n94LqAzpFJGwTX3bpIlTyrIis7S8',
            },
          },
        }),
        'unknown utls fingerprint: potato',
      );
      final sanitized = ParsedOutboundSchema.sanitize({
        ...baseOutbound,
        'tls': {
          'enabled': true,
          'utls': {'enabled': true, 'fingerprint': 'QQ'},
          'reality': {
            'enabled': true,
            'public_key': 'thwa3P0vSbbPNr0n94LqAzpFJGwTX3bpIlTyrIis7S8',
            'short_id': 'ab01,cd02',
          },
        },
      });
      expect(sanitized?['tls']['utls']['fingerprint'], 'qq');
      expect(sanitized?['tls']['reality']['short_id'], 'ab01');
    });

    test('keeps QUIC SNI and ALPN while removing unsupported uTLS', () {
      const quicOutbounds = [
        {
          'type': 'hysteria2',
          'tag': 'hy2',
          'server': 'hy2.example.com',
          'server_port': 443,
          'tls': {
            'enabled': true,
            'server_name': 'front.hy2.example',
            'alpn': 'h3, h2',
            'utls': {'enabled': true, 'fingerprint': 'chrome'},
          },
        },
        {
          'type': 'tuic',
          'tag': 'tuic',
          'server': 'tuic.example.com',
          'server_port': 443,
          'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
          'tls': {
            'enabled': true,
            'server_name': 'front.tuic.example',
            'alpn': ['h3', 'h3'],
            'utls': {'enabled': true, 'fingerprint': 'chrome'},
          },
        },
        {
          'type': 'naive',
          'tag': 'naive-quic',
          'server': 'naive.example.com',
          'server_port': 443,
          'quic': true,
          'tls': {
            'enabled': true,
            'server_name': 'front.naive.example',
            'alpn': ['h3'],
            'utls': {'enabled': true, 'fingerprint': 'chrome'},
          },
        },
        {
          'type': 'vless',
          'tag': 'vless-quic',
          'server': 'vless.example.com',
          'server_port': 443,
          'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
          'transport': {'type': 'quic'},
          'tls': {
            'enabled': true,
            'server_name': 'front.vless.example',
            'alpn': ['h3'],
            'utls': {'enabled': true, 'fingerprint': 'chrome'},
          },
        },
      ];

      for (final outbound in quicOutbounds) {
        final sanitized = ParsedOutboundSchema.sanitize(outbound);
        final tls = (sanitized?['tls'] as Map?)?.cast<String, dynamic>();
        expect(
          tls,
          isNotNull,
          reason: 'TLS is retained for ${outbound['tag']}',
        );
        expect(tls!['server_name'], startsWith('front.'));
        expect(tls.containsKey('utls'), isFalse);
        expect(tls['alpn'], isNotEmpty);
      }

      final hy2 = ParsedOutboundSchema.sanitize(quicOutbounds.first)!;
      expect(hy2['tls']['alpn'], ['h3', 'h2']);
    });

    test('validates VLESS encryption during import and startup validation', () {
      const baseOutbound = {
        'type': 'vless',
        'tag': 'vless',
        'server': 'server.com',
        'server_port': 443,
        'uuid': '7c6a5b3e-4f1a-4d2b-8c9e-1a2b3c4d5e6f',
      };
      const encrypted =
          'mlkem768x25519plus.native.0rtt.MDG42I0GTLyH5a6fuXipicFe-A_m-FHNYyJGkheQJTs';
      const structuredEncrypted =
          'mlkem768x25519plus.native.0rtt.100-111-1111.75-0-111.50-0-3333.'
          'PJUiVjxhudMO-vFYcUl5PMO5xVg8WdG4Kbo1IVKrFuc_2kQ_Y2MsH2pErIQQ3YB0';

      expect(
        ParsedOutboundSchema.validate({...baseOutbound, 'encryption': 'none'}),
        isNull,
      );
      expect(
        ParsedOutboundSchema.validate({
          ...baseOutbound,
          'encryption': encrypted,
        }),
        isNull,
      );
      expect(
        ParsedOutboundSchema.validate({
          ...baseOutbound,
          'encryption': structuredEncrypted,
        }),
        isNull,
      );
      expect(
        ParsedOutboundSchema.validate({...baseOutbound, 'encryption': 'auto'}),
        'invalid vless encryption: auto',
      );
      expect(
        ParsedOutboundSchema.sanitize({...baseOutbound, 'encryption': 'auto'}),
        isNull,
      );
    });

    test('parses VMess link', () {
      final vmessJson = base64Encode(
        utf8.encode(
          jsonEncode({
            'v': '2',
            'ps': 'Test VMess',
            'add': 'vmess.server.com',
            'port': '443',
            'id': 'test-uuid-1234',
            'aid': '0',
            'scy': 'auto',
            'net': 'ws',
            'type': 'none',
            'host': 'ws.host.com',
            'path': '/ws-path',
            'tls': 'tls',
            'sni': 'sni.host.com',
            'fp': 'chrome',
            'alpn': 'h2,http/1.1',
          }),
        ),
      );

      final r = LinkParser.tryParse('vmess://$vmessJson')!;
      expect(r['type'], 'vmess');
      expect(r['server'], 'vmess.server.com');
      expect(r['server_port'], 443);
      expect(r['uuid'], 'test-uuid-1234');
      expect(r['security'], 'auto');
      expect(r['alter_id'], 0);
      expect(r['tls']['enabled'], true);
      expect(r['tls']['server_name'], 'sni.host.com');
      expect(r['tls']['alpn'], ['h2', 'http/1.1']);
      expect(r['transport']['type'], 'ws');
      expect(r['transport']['path'], '/ws-path');
      expect(r['_name'], 'Test VMess');
    });

    test('parses Trojan link', () {
      const link =
          'trojan://my-password@trojan.server.com:443'
          '?security=tls&sni=trojan.sni.com&type=grpc'
          '&serviceName=my-grpc-service&fp=firefox#Trojan%20Node';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'trojan');
      expect(r['server'], 'trojan.server.com');
      expect(r['server_port'], 443);
      expect(r['password'], 'my-password');
      expect(r['tls']['enabled'], true);
      expect(r['tls']['server_name'], 'trojan.sni.com');
      expect(r['transport']['type'], 'grpc');
      expect(r['transport']['service_name'], 'my-grpc-service');
      expect(r['_name'], 'Trojan Node');
    });

    test('parses SOCKS link with base64 userinfo credentials', () {
      const link =
          'socks5://VzBzbTRTOkJETEx0Vw==@178.171.42.39:9909#178.171.42.39%3A9909';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'socks');
      expect(r['server'], '178.171.42.39');
      expect(r['server_port'], 9909);
      expect(r['version'], '5');
      expect(r['username'], 'W0sm4S');
      expect(r['password'], 'BDLLtW');
      expect(r['_name'], '178.171.42.39:9909');
    });

    test('parses SS SIP002 link', () {
      final userInfo = base64Encode(utf8.encode('aes-256-gcm:mypassword'));
      final link = 'ss://$userInfo@ss.server.com:8388#SS%20Node';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'shadowsocks');
      expect(r['server'], 'ss.server.com');
      expect(r['server_port'], 8388);
      expect(r['method'], 'aes-256-gcm');
      expect(r['password'], 'mypassword');
      expect(r['_name'], 'SS Node');
    });

    test('parses SS legacy link', () {
      final encoded = base64Encode(
        utf8.encode('chacha20-ietf-poly1305:password123@legacy.com:8388'),
      );
      final link = 'ss://$encoded#Legacy';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'shadowsocks');
      expect(r['server'], 'legacy.com');
      expect(r['server_port'], 8388);
      expect(r['method'], 'chacha20-ietf-poly1305');
      expect(r['password'], 'password123');
    });

    test('parses SSR link', () {
      final inner =
          'server.com:8388:auth_aes128_md5:aes-256-cfb:tls1.2_ticket_auth:'
          '${base64Encode(utf8.encode('password123'))}/?'
          'remarks=${base64Encode(utf8.encode('SSR Node'))}'
          '&obfsparam=${base64Encode(utf8.encode('param1'))}';
      final encoded = base64Encode(
        utf8.encode(inner),
      ).replaceAll('+', '-').replaceAll('/', '_');
      final link = 'ssr://$encoded';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'shadowsocksr');
      expect(r['server'], 'server.com');
      expect(r['server_port'], 8388);
      expect(r['method'], 'aes-256-cfb');
      expect(r['password'], 'password123');
      expect(r['protocol'], 'auth_aes128_md5');
      expect(r['obfs'], 'tls1.2_ticket_auth');
      expect(r['_name'], 'SSR Node');
    });

    test('parses SOCKS proxy links', () {
      const link = 'socks5://user:p%40ss@socks.server.com:1080#SOCKS%20Node';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'socks');
      expect(r['server'], 'socks.server.com');
      expect(r['server_port'], 1080);
      expect(r['version'], '5');
      expect(r['username'], 'user');
      expect(r['password'], 'p@ss');
      expect(r['_name'], 'SOCKS Node');
    });

    test('parses SOCKS4 proxy links', () {
      const link = 'socks4://legacy.socks.com:1080#SOCKS4';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'socks');
      expect(r['server'], 'legacy.socks.com');
      expect(r['server_port'], 1080);
      expect(r['version'], '4');
    });

    test('parses HTTP proxy links', () {
      const link = 'http://user:p%40ss@proxy.server.com:8080#HTTP%20Proxy';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'http');
      expect(r['server'], 'proxy.server.com');
      expect(r['server_port'], 8080);
      expect(r['username'], 'user');
      expect(r['password'], 'p@ss');
      expect(r['_name'], 'HTTP Proxy');
      expect(r.containsKey('tls'), isFalse);
    });

    test('parses HTTPS proxy links with TLS', () {
      const link = 'https://secure.proxy.com:443#HTTPS%20Proxy';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'http');
      expect(r['server'], 'secure.proxy.com');
      expect(r['server_port'], 443);
      expect(r['tls']['enabled'], true);
      expect(r['_name'], 'HTTPS Proxy');
    });

    test('parses NaiveProxy HTTPS links', () {
      const link =
          'naive+https://user:p%40ss@naive.server.com'
          '?sni=front.example&extra-headers=Foo%3A%20bar%0D%0ABaz%3A%20qux'
          '#Naive%20HTTPS';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'naive');
      expect(r['server'], 'naive.server.com');
      expect(r['server_port'], 443);
      expect(r['username'], 'user');
      expect(r['password'], 'p@ss');
      expect(r['tls']['enabled'], true);
      expect(r['tls']['server_name'], 'front.example');
      expect(r['extra_headers'], {'Foo': 'bar', 'Baz': 'qux'});
      expect(r['_name'], 'Naive HTTPS');
    });

    test('parses NaiveProxy QUIC links', () {
      const link =
          'naive+quic://user:pass@naive.server.com:443'
          '?quic_congestion_control=BBR#Naive%20QUIC';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'naive');
      expect(r['quic'], true);
      expect(r['quic_congestion_control'], 'BBR');
    });

    test('parses Hysteria2 link', () {
      const link =
          'hy2://myauth@hy2.server.com:443'
          '?sni=sni.hy2.com&obfs=salamander&obfs-password=obfs123#Hy2%20Node';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'hysteria2');
      expect(r['server'], 'hy2.server.com');
      expect(r['server_port'], 443);
      expect(r['password'], 'myauth');
      expect(r['tls']['enabled'], true);
      expect(r['tls']['server_name'], 'sni.hy2.com');
      expect(r['obfs']['type'], 'salamander');
      expect(r['obfs']['password'], 'obfs123');
      expect(r['_name'], 'Hy2 Node');
    });

    test('parses Hysteria v1 link', () {
      const link =
          'hysteria://hy.server.com:443'
          '?auth=myauth&peer=sni.hy.com&insecure=1'
          '&upmbps=100&downmbps=200&alpn=h3'
          '&obfsParam=obfs-secret#Hy1%20Node';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'hysteria');
      expect(r['server'], 'hy.server.com');
      expect(r['auth_string'], 'myauth');
      expect(r['up_mbps'], 100);
      expect(r['down_mbps'], 200);
      expect(r['obfs'], 'obfs-secret');
      expect(r['tls']['insecure'], true);
      expect(r['tls']['server_name'], 'sni.hy.com');
    });

    test('parses TUIC link', () {
      const link =
          'tuic://uuid123:password456@tuic.server.com:443'
          '?congestion_control=bbr&alpn=h3&sni=tuic.sni.com'
          '&udp_relay_mode=native#TUIC%20Node';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'tuic');
      expect(r['server'], 'tuic.server.com');
      expect(r['server_port'], 443);
      expect(r['uuid'], 'uuid123');
      expect(r['password'], 'password456');
      expect(r['congestion_control'], 'bbr');
      expect(r['udp_relay_mode'], 'native');
      expect(r['tls']['server_name'], 'tuic.sni.com');
      expect(r['tls']['alpn'], ['h3']);
    });

    test('parses AnyTLS link', () {
      const link =
          'anytls://mypassword@anytls.server.com:443'
          '?sni=sni.anytls.com&fp=chrome#AnyTLS%20Node';

      final r = LinkParser.tryParse(link)!;
      expect(r['type'], 'anytls');
      expect(r['server'], 'anytls.server.com');
      expect(r['server_port'], 443);
      expect(r['password'], 'mypassword');
      expect(r['tls']['enabled'], true);
      expect(r['tls']['server_name'], 'sni.anytls.com');
      expect(r['tls']['utls']['fingerprint'], 'chrome');
      expect(r['_name'], 'AnyTLS Node');
    });

    test('returns null for invalid links', () {
      expect(LinkParser.tryParse(''), isNull);
      expect(LinkParser.tryParse('# comment'), isNull);
      expect(LinkParser.tryParse('https://google.com'), isNull);
      expect(LinkParser.tryParse('garbage'), isNull);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SIP008 Parser Tests
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('Sip008Parser', () {
    test('parses SIP008 JSON', () {
      final content = jsonEncode({
        'version': 1,
        'servers': [
          {
            'id': 'uuid-1',
            'remarks': 'Japan SS',
            'server': 'jp.example.com',
            'server_port': 8388,
            'method': 'aes-256-gcm',
            'password': 'pass123',
          },
          {
            'remarks': 'US SS',
            'server': 'us.example.com',
            'server_port': 8389,
            'method': 'chacha20-ietf-poly1305',
            'password': 'pass456',
          },
        ],
      });

      expect(Sip008Parser.canParse(content), isTrue);
      final results = Sip008Parser.parse(content);
      expect(results.length, 2);
      expect(results[0]['type'], 'shadowsocks');
      expect(results[0]['server'], 'jp.example.com');
      expect(results[0]['_name'], 'Japan SS');
      expect(results[1]['server'], 'us.example.com');
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Sing-box Config Parser Tests
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('SingboxConfigParser', () {
    test('extracts proxy outbounds from sing-box config', () {
      final content = jsonEncode({
        'outbounds': [
          {
            'type': 'vless',
            'tag': 'vless-proxy',
            'server': 'a.com',
            'server_port': 443,
            'uuid': '11111111-1111-1111-1111-111111111111',
          },
          {'type': 'direct', 'tag': 'direct'},
          {
            'type': 'vmess',
            'tag': 'vmess-proxy',
            'server': 'b.com',
            'server_port': 443,
            'uuid': '22222222-2222-2222-2222-222222222222',
          },
          {'type': 'block', 'tag': 'block'},
          {'type': 'selector', 'tag': 'select'},
        ],
      });

      expect(SingboxConfigParser.canParse(content), isTrue);
      final results = SingboxConfigParser.parse(content);
      expect(results.length, 2);
      expect(results[0]['type'], 'vless');
      expect(results[0]['_name'], 'vless-proxy');
      expect(results[1]['type'], 'vmess');
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Xray Config Parser Tests
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('XrayConfigParser', () {
    test('converts Xray VLESS outbound to sing-box format', () {
      final content = jsonEncode({
        'outbounds': [
          {
            'protocol': 'vless',
            'tag': 'my-vless',
            'settings': {
              'vnext': [
                {
                  'address': 'xray.server.com',
                  'port': 443,
                  'users': [
                    {
                      'id': 'my-uuid',
                      'encryption': 'none',
                      'flow': 'xtls-rprx-vision',
                    },
                  ],
                },
              ],
            },
            'streamSettings': {
              'network': 'tcp',
              'security': 'tls',
              'tlsSettings': {
                'serverName': 'xray.sni.com',
                'fingerprint': 'chrome',
                'alpn': ['h2'],
              },
            },
          },
          {'protocol': 'freedom', 'tag': 'direct'},
        ],
      });

      expect(XrayConfigParser.canParse(content), isTrue);
      final results = XrayConfigParser.parse(content);
      expect(results.length, 1);

      final r = results[0];
      expect(r['type'], 'vless');
      expect(r['server'], 'xray.server.com');
      expect(r['server_port'], 443);
      expect(r['uuid'], 'my-uuid');
      expect(r['flow'], 'xtls-rprx-vision');
      expect(r['encryption'], 'none');
      expect(r['tls']['enabled'], true);
      expect(r['tls']['server_name'], 'xray.sni.com');
      expect(r['_name'], 'my-vless');
    });

    test('parses JSON array of Xray configs', () {
      final content = jsonEncode([
        {
          'outbounds': [
            {
              'protocol': 'vless',
              'tag': 'node-1',
              'settings': {
                'vnext': [
                  {
                    'address': 'one.example',
                    'port': 443,
                    'users': [
                      {'id': 'uuid-1', 'encryption': 'none'},
                    ],
                  },
                ],
              },
              'streamSettings': {
                'network': 'tcp',
                'security': 'reality',
                'realitySettings': {
                  'serverName': 'www.vk.com',
                  'publicKey': 'hOKJ1Zm_GHspM0qZYvk4lzHN8Rcpb1P4qjaKs7cJWj4',
                  'shortId': '8ed8c97a90673736',
                  'fingerprint': 'qq',
                  'spiderX': '/',
                },
              },
            },
          ],
        },
        {
          'outbounds': [
            {
              'protocol': 'vless',
              'tag': 'node-2',
              'settings': {
                'vnext': [
                  {
                    'address': 'two.example',
                    'port': 8443,
                    'users': [
                      {'id': 'uuid-2', 'encryption': 'none'},
                    ],
                  },
                ],
              },
              'streamSettings': {
                'network': 'tcp',
                'security': 'reality',
                'realitySettings': {
                  'serverName': 'max.ru',
                  'publicKey': 'pGFgy_rrpU51v3IFm-dYHOJskMDJO0kCAkIIHJdUSF8',
                  'shortId': 'f3e8b2b1',
                  'fingerprint': 'qq',
                  'spiderX': '/',
                },
              },
            },
          ],
        },
      ]);

      expect(XrayConfigParser.canParse(content), isTrue);
      final results = XrayConfigParser.parse(content);
      expect(results.length, 2);
      expect(results[0]['tls']['reality']['spider_x'], '/');
      expect(results[1]['tls']['reality']['spider_x'], '/');
      expect(results[0]['server'], 'one.example');
      expect(results[1]['server'], 'two.example');
    });

    test('uses remarks as name for single-proxy xray configs', () {
      final content = jsonEncode({
        'remarks': '⚡ 🇷🇺 Россия Москва',
        'outbounds': [
          {
            'protocol': 'vless',
            'tag': 'NODE-1',
            'settings': {
              'vnext': [
                {
                  'address': 'one.example',
                  'port': 443,
                  'users': [
                    {'id': 'uuid-1', 'encryption': 'none'},
                  ],
                },
              ],
            },
          },
          {'protocol': 'freedom', 'tag': 'direct'},
        ],
      });

      final results = XrayConfigParser.parse(content);
      expect(results.length, 1);
      expect(results.first['_name'], '⚡ 🇷🇺 Россия Москва');
    });

    test('converts Xray Hysteria2 outbound to sing-box format', () {
      final content = jsonEncode({
        'outbounds': [
          {
            'protocol': 'hysteria',
            'tag': 'hy2-node',
            'settings': {
              'version': 2,
              'address': 'hy2.example.com',
              'port': 8443,
            },
            'streamSettings': {
              'network': 'hysteria',
              'security': 'tls',
              'tlsSettings': {
                'serverName': 'sni.hy2.example.com',
                'alpn': ['h3'],
                'allowInsecure': true,
              },
              'hysteriaSettings': {'auth': 'secret-pass'},
            },
          },
        ],
      });

      expect(XrayConfigParser.canParse(content), isTrue);
      final results = XrayConfigParser.parse(content);
      expect(results.length, 1);

      final r = results.first;
      expect(r['type'], 'hysteria2');
      expect(r['server'], 'hy2.example.com');
      expect(r['server_port'], 8443);
      expect(r['password'], 'secret-pass');
      expect(r['tls']['enabled'], true);
      expect(r['tls']['server_name'], 'sni.hy2.example.com');
      expect(r['tls']['alpn'], ['h3']);
      expect(r['tls']['insecure'], true);
      expect(r['_name'], 'hy2-node');
    });

    test(
      'converts Astracat-style Xray Hysteria2 outbound to sing-box format',
      () {
        final content = jsonEncode({
          'outbounds': [
            {
              'tag': 'proxy',
              'protocol': 'hysteria',
              'settings': {
                'address': 'nl2.astracat.ru',
                'port': 443,
                'version': 2,
              },
              'streamSettings': {
                'network': 'hysteria',
                'hysteriaSettings': {
                  'version': 2,
                  'auth': '0de99f86-bc7a-4770-82e0-97c0c544ed0a',
                },
                'security': 'tls',
                'tlsSettings': {
                  'serverName': 'nl2.astracat.ru',
                  'fingerprint': 'chrome',
                  'alpn': ['h3'],
                },
              },
            },
          ],
        });

        final results = XrayConfigParser.parse(content);
        expect(results.length, 1);

        final r = results.first;
        expect(r['type'], 'hysteria2');
        expect(r['server'], 'nl2.astracat.ru');
        expect(r['server_port'], 443);
        expect(r['password'], '0de99f86-bc7a-4770-82e0-97c0c544ed0a');
        expect(r['tls']['enabled'], true);
        expect(r['tls']['server_name'], 'nl2.astracat.ru');
        expect(r['tls']['alpn'], ['h3']);
        expect(r['tls']['utls'], {'enabled': true, 'fingerprint': 'chrome'});
        expect(r['_name'], 'proxy');
      },
    );
  });

  group('SubscriptionParser', () {
    test('forces h2 alpn for grpc transport in xray configs', () {
      final content = jsonEncode({
        'outbounds': [
          {
            'protocol': 'trojan',
            'tag': 'proxy',
            'settings': {
              'servers': [
                {
                  'address': 'usa1.astracat.ru',
                  'port': 443,
                  'password': 'secret',
                },
              ],
            },
            'streamSettings': {
              'network': 'grpc',
              'grpcSettings': {'serviceName': 'PushNotificationService'},
              'security': 'tls',
              'tlsSettings': {
                'serverName': 'usa1.astracat.ru',
                'fingerprint': 'chrome',
                'alpn': ['h3'],
              },
            },
          },
        ],
      });

      final result = SubscriptionParser.parse(content);
      expect(result.outbounds, hasLength(1));
      expect(result.outbounds.first['transport']['type'], 'grpc');
      expect(result.outbounds.first['tls']['alpn'], ['h2']);
    });

    test('forces h2 alpn for grpc transport in sing-box configs', () {
      final content = jsonEncode({
        'outbounds': [
          {
            'type': 'trojan',
            'tag': 'proxy',
            'server': 'usa1.astracat.ru',
            'server_port': 443,
            'password': 'secret',
            'transport': {
              'type': 'grpc',
              'service_name': 'PushNotificationService',
            },
            'tls': {
              'enabled': true,
              'server_name': 'usa1.astracat.ru',
              'alpn': ['h3'],
            },
          },
        ],
      });

      final result = SubscriptionParser.parse(content);
      expect(result.outbounds, hasLength(1));
      expect(result.outbounds.first['transport']['type'], 'grpc');
      expect(result.outbounds.first['tls']['alpn'], ['h2']);
    });

    test('drops empty transport headers in xray configs', () {
      final content = jsonEncode({
        'outbounds': [
          {
            'protocol': 'trojan',
            'tag': 'proxy',
            'settings': {
              'servers': [
                {
                  'address': 'tr1.astracat.ru',
                  'port': 443,
                  'password': 'secret',
                },
              ],
            },
            'streamSettings': {
              'network': 'ws',
              'wsSettings': {
                'path': '/api/v2/monitoring/status',
                'headers': {
                  'Host': '',
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                },
              },
              'security': 'tls',
              'tlsSettings': {'serverName': 'tr1.astracat.ru'},
            },
          },
        ],
      });

      final result = SubscriptionParser.parse(content);
      expect(result.outbounds, hasLength(1));
      expect(result.outbounds.first['transport']['headers'], {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      });
    });

    test('drops empty transport headers in sing-box configs', () {
      final content = jsonEncode({
        'outbounds': [
          {
            'type': 'trojan',
            'tag': 'proxy',
            'server': 'tr1.astracat.ru',
            'server_port': 443,
            'password': 'secret',
            'transport': {
              'type': 'ws',
              'path': '/api/v2/monitoring/status',
              'headers': {'Host': '', 'User-Agent': 'Mozilla/5.0'},
            },
            'tls': {'enabled': true, 'server_name': 'tr1.astracat.ru'},
          },
        ],
      });

      final result = SubscriptionParser.parse(content);
      expect(result.outbounds, hasLength(1));
      expect(result.outbounds.first['transport']['headers'], {
        'User-Agent': 'Mozilla/5.0',
      });
    });

    test('drops empty top-level headers in http outbounds', () {
      final content = jsonEncode({
        'outbounds': [
          {
            'type': 'http',
            'tag': 'proxy',
            'server': 'proxy.example',
            'server_port': 443,
            'path': '/api',
            'headers': {'Host': '', 'X-Test': ' ok '},
            'tls': {'enabled': true, 'server_name': ' proxy.example '},
          },
        ],
      });

      final result = SubscriptionParser.parse(content);
      expect(result.outbounds, hasLength(1));
      expect(result.outbounds.first['headers'], {'X-Test': 'ok'});
      expect(result.outbounds.first['tls']['server_name'], 'proxy.example');
    });

    test('drops unknown xhttp extra parameters from share links', () {
      const content =
          'vless://test-uuid@1.1.1.1:29731?encryption=none&type=xhttp&path=%2Fapi%2Fv1%2Fdata&mode=stream-up&extra=%7B%22speed%22%3A%22true%22%2C%22xmux%22%3A%7B%22maxConcurrency%22%3A%7B%22from%22%3A1%2C%22to%22%3A4%7D%2C%22speed%22%3Atrue%7D%7D&security=reality&sni=yastatic.net&fp=chrome&pbk=thwa3P0vSbbPNr0n94LqAzpFJGwTX3bpIlTyrIis7S8#xhttp';

      final result = SubscriptionParser.parse(content);
      expect(result.outbounds, hasLength(1));

      final transport = result.outbounds.first['transport'] as Map;
      expect(transport['type'], 'xhttp');
      expect(transport.containsKey('speed'), isFalse);
      expect(transport['path'], '/api/v1/data');
      expect(transport['mode'], 'stream-up');
      expect(transport['xmux'], {
        'max_concurrency': {'from': 1, 'to': 4},
      });
    });

    test('drops invalid xhttp mode from share links', () {
      const content =
          'vless://8b53c90b-7523-422f-963b-2be108685376@2.27.13.230:8443?encryption=mlkem768x25519plus.native.0rtt.MDG42I0GTLyH5a6fuXipicFe-A_m-FHNYyJGkheQJTs&fp=chrome&host=fonts.gstatic.com&mode=auto&path=%2Fcss2&pbk=z0S7qx_G_rb8nATkZmCJpPC-hiQPNmqkXGkSmKM5fXY&security=reality&sid=e63ca6d5&sni=aws.amazon.com&spx=%2Fewh6P1O3aLaR0D3&type=xhttp#Xhttp';

      final result = SubscriptionParser.parse(content);
      expect(result.outbounds, hasLength(1));

      final outbound = result.outbounds.first;
      final transport = outbound['transport'] as Map;
      expect(
        outbound['encryption'],
        'mlkem768x25519plus.native.0rtt.MDG42I0GTLyH5a6fuXipicFe-A_m-FHNYyJGkheQJTs',
      );
      expect(outbound['tls']['reality']['spider_x'], '/ewh6P1O3aLaR0D3');
      expect(transport['type'], 'xhttp');
      expect(transport.containsKey('mode'), isFalse);
      expect(transport['host'], 'fonts.gstatic.com');
      expect(transport['path'], '/css2');
    });

    test('drops invalid outbounds during parsing', () {
      final content = jsonEncode({
        'outbounds': [
          {
            'type': 'vless',
            'tag': 'broken',
            'server': '1.1.1.1',
            'server_port': 443,
            'uuid': 'test-uuid',
            'tls': {
              'enabled': true,
              'reality': {'enabled': true, 'public_key': 'broken-key'},
            },
          },
        ],
      });

      final result = SubscriptionParser.parse(content);
      expect(result.outbounds, isEmpty);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // WireGuard Config Parser Tests
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('WireGuardConfigParser', () {
    test('parses WireGuard .conf', () {
      const content = '''
[Interface]
PrivateKey = yGXGKezPjPNbRfHAJNmkDDT4hPsYRFJ+/GIOQ1kzIXM=
Address = 10.0.0.2/32, fd00::2/128
DNS = 1.1.1.1
MTU = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
PresharedKey = e6OeLbqRHGEhDi1n3dRNqHQO3RKSIWJgc9jX7WFR2EU=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = wg.server.com:51820
PersistentKeepalive = 25
''';

      expect(WireGuardConfigParser.canParse(content), isTrue);
      final results = WireGuardConfigParser.parse(content);
      expect(results.length, 1);

      final r = results[0];
      expect(r['type'], 'wireguard');
      expect(r['private_key'], 'yGXGKezPjPNbRfHAJNmkDDT4hPsYRFJ+/GIOQ1kzIXM=');
      expect(r['address'], ['10.0.0.2/32', 'fd00::2/128']);
      expect(r['mtu'], 1280);
      expect(r['peers'][0]['address'], 'wg.server.com');
      expect(r['peers'][0]['port'], 51820);
      expect(
        r['peers'][0]['public_key'],
        'bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=',
      );
      expect(
        r['peers'][0]['pre_shared_key'],
        'e6OeLbqRHGEhDi1n3dRNqHQO3RKSIWJgc9jX7WFR2EU=',
      );
      expect(r['peers'][0]['persistent_keepalive_interval'], 25);
    });

    test('preserves every peer and bracketed IPv6 endpoints', () {
      const content = '''
[Interface]
PrivateKey = yGXGKezPjPNbRfHAJNmkDDT4hPsYRFJ+/GIOQ1kzIXM=
Address = 10.0.0.2/32

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0
Endpoint = wg-one.example:51820

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = ::/0
Endpoint = [2001:db8::1]:51821
PersistentKeepalive = 15
''';

      final result = WireGuardConfigParser.parse(content).single;
      final peers = (result['peers'] as List).cast<Map<String, dynamic>>();

      expect(peers, hasLength(2));
      expect(peers[0]['address'], 'wg-one.example');
      expect(peers[0]['port'], 51820);
      expect(peers[1]['address'], '2001:db8::1');
      expect(peers[1]['port'], 51821);
      expect(peers[1]['persistent_keepalive_interval'], 15);
    });

    test('migrates legacy keepalive durations to endpoint seconds', () {
      final sanitized = ParsedOutboundSchema.sanitize({
        'type': 'wireguard',
        'private_key': 'yGXGKezPjPNbRfHAJNmkDDT4hPsYRFJ+/GIOQ1kzIXM=',
        'address': ['10.0.0.2/32'],
        'peers': [
          {
            'address': 'wg.example.com',
            'port': 51820,
            'public_key': 'bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=',
            'allowed_ips': ['0.0.0.0/0'],
            'persistent_keepalive_interval': '25s',
          },
        ],
      });

      expect(sanitized, isNotNull);
      final peer = (sanitized!['peers'] as List).single as Map<String, dynamic>;
      expect(peer['persistent_keepalive_interval'], 25);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Clash Parser Tests
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('ClashParser', () {
    test('parses Clash YAML proxies', () {
      const content = '''
proxies:
  - name: "VLESS Node"
    type: vless
    server: clash.server.com
    port: 443
    uuid: "test-uuid"
    tls: true
    servername: clash.sni.com
    client-fingerprint: chrome
    network: ws
    ws-opts:
      path: /ws
      headers:
        Host: ws.host.com
    flow: xtls-rprx-vision

  - name: "SS Node"
    type: ss
    server: ss.clash.com
    port: 8388
    cipher: aes-256-gcm
    password: sspass123
''';

      expect(ClashParser.canParse(content), isTrue);
      final results = ClashParser.parse(content);
      expect(results.length, 2);

      final vless = results[0];
      expect(vless['type'], 'vless');
      expect(vless['server'], 'clash.server.com');
      expect(vless['uuid'], 'test-uuid');
      expect(vless['flow'], 'xtls-rprx-vision');
      expect(vless['tls']['enabled'], true);
      expect(vless['transport']['type'], 'ws');
      expect(vless['transport']['path'], '/ws');

      final ss = results[1];
      expect(ss['type'], 'shadowsocks');
      expect(ss['method'], 'aes-256-gcm');
      expect(ss['password'], 'sspass123');
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SubscriptionParser (format detection) Tests
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('SubscriptionParser', () {
    test('detects base64-encoded links', () {
      final raw = [
        'vless://uuid@server.com:443?type=tcp&security=tls#Node1',
        'trojan://pass@trojan.com:443?security=tls#Node2',
      ].join('\n');
      final b64 = base64Encode(utf8.encode(raw));

      final result = SubscriptionParser.parse(b64);
      expect(result.format, SubscriptionFormat.base64Links);
      expect(result.outbounds.length, 2);
      expect(result.outbounds[0]['type'], 'vless');
      expect(result.outbounds[1]['type'], 'trojan');
    });

    test('detects raw links', () {
      const raw =
          'vless://uuid@server.com:443?type=tcp&security=tls#Node1\n'
          'trojan://pass@trojan.com:443?security=tls#Node2\n';

      final result = SubscriptionParser.parse(raw);
      expect(result.format, SubscriptionFormat.rawLinks);
      expect(result.outbounds.length, 2);
    });

    test('detects raw SOCKS and HTTP proxy links', () {
      const raw =
          'socks5://user:pass@socks.server.com:1080#Socks\n'
          'http://proxy.server.com:8080#Http\n';

      final result = SubscriptionParser.parse(raw);
      expect(result.format, SubscriptionFormat.rawLinks);
      expect(result.outbounds.length, 2);
      expect(result.outbounds[0]['type'], 'socks');
      expect(result.outbounds[1]['type'], 'http');
    });

    test('detects raw NaiveProxy links', () {
      const raw =
          'naive+https://user:pass@naive.server.com:443?sni=front.example#Naive\n';

      final result = SubscriptionParser.parse(raw);
      expect(result.format, SubscriptionFormat.rawLinks);
      expect(result.outbounds.length, 1);
      expect(result.outbounds[0]['type'], 'naive');
      expect(result.outbounds[0]['tls']['server_name'], 'front.example');
    });

    test('detects base64-encoded SOCKS and HTTP proxy links', () {
      const raw =
          'socks4://legacy.socks.com:1080#Socks4\n'
          'https://secure.proxy.com:443#Https\n';
      final b64 = base64Encode(utf8.encode(raw));

      final result = SubscriptionParser.parse(b64);
      expect(result.format, SubscriptionFormat.base64Links);
      expect(result.outbounds.length, 2);
      expect(result.outbounds[0]['type'], 'socks');
      expect(result.outbounds[1]['type'], 'http');
      expect(result.outbounds[1]['tls']['enabled'], true);
    });

    test('splits concatenated raw links on one line', () {
      const raw =
          'vless://uuid1@one.example:443?type=tcp&security=tls#Node1 '
          'vless://uuid2@two.example:443?type=tcp&security=reality&pbk=thwa3P0vSbbPNr0n94LqAzpFJGwTX3bpIlTyrIis7S8&sni=google.com#Node2';

      final result = SubscriptionParser.parse(raw);
      expect(result.format, SubscriptionFormat.rawLinks);
      expect(result.outbounds.length, 2);
      expect(result.outbounds[0]['server'], 'one.example');
      expect(result.outbounds[1]['server'], 'two.example');
    });

    test('parses Husi-style proxy chains', () {
      const raw =
          'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@144.31.94.151:443'
          '?encryption=none&flow=xtls-rprx-vision&security=reality'
          '&sni=kinopoisk.ru&fp=chrome'
          '&pbk=mhvT7-nUtXaWrw1Xf7JmBsB0Twj4-alH73mgsN4PZz0'
          '&sid=29f847c151f96091#%D0%90%D0%B2%D1%81%D1%82%D1%80%D0%B8%D1%8F%E2%9A%A1%F0%9F%A4%96%C2%B7%20TCP'
          ' -> socks5://VzBzbTRTOkJETEx0Vw==@178.171.42.39:9909#178.171.42.39%3A9909';

      final result = SubscriptionParser.parse(raw);
      expect(result.format, SubscriptionFormat.rawLinks);
      expect(result.outbounds.length, 2);
      expect(result.outbounds[0]['type'], 'vless');
      expect(result.outbounds[0]['_group_only'], true);
      expect(result.outbounds[0]['_source_tag'], 'hop-0');
      expect(result.outbounds[1]['type'], 'socks');
      expect(result.outbounds[1]['_detour_source_tag'], 'hop-0');
      expect(result.outbounds[1]['username'], 'W0sm4S');
      expect(result.outbounds[1]['password'], 'BDLLtW');
      expect(result.outbounds[1]['_name'], contains('178.171.42.39:9909'));
    });

    test('detects sing-box config', () {
      final raw = jsonEncode({
        'outbounds': [
          {
            'type': 'vless',
            'tag': 'proxy',
            'server': 'a.com',
            'server_port': 443,
            'uuid': '11111111-1111-1111-1111-111111111111',
          },
        ],
      });
      final result = SubscriptionParser.parse(raw);
      expect(result.format, SubscriptionFormat.singboxConfig);
      expect(result.outbounds.length, 1);
    });

    test(
      'drops tls.utls for hysteria2 outbounds during subscription parsing',
      () {
        final raw = jsonEncode({
          'outbounds': [
            {
              'type': 'hysteria2',
              'tag': 'hy2-node',
              'server': 'hy2.example.com',
              'server_port': 443,
              'tls': {
                'enabled': true,
                'server_name': 'sni.hy2.example.com',
                'utls': {'enabled': true, 'fingerprint': 'chrome'},
              },
            },
          ],
        });

        final result = SubscriptionParser.parse(raw);
        expect(result.format, SubscriptionFormat.singboxConfig);
        expect(result.outbounds.length, 1);
        expect(result.outbounds.first['type'], 'hysteria2');
        expect(
          result.outbounds.first['tls']['server_name'],
          'sni.hy2.example.com',
        );
        expect(result.outbounds.first['tls'].containsKey('utls'), isFalse);
      },
    );

    test('detects JSON array of xray configs', () {
      final raw = jsonEncode([
        {
          'outbounds': [
            {
              'protocol': 'vless',
              'tag': 'proxy',
              'settings': {
                'vnext': [
                  {
                    'address': 'array.example',
                    'port': 443,
                    'users': [
                      {'id': 'uuid', 'encryption': 'none'},
                    ],
                  },
                ],
              },
            },
          ],
        },
      ]);
      final result = SubscriptionParser.parse(raw);
      expect(result.format, SubscriptionFormat.xrayConfig);
      expect(result.outbounds.length, 1);
      expect(result.outbounds.first['server'], 'array.example');
    });

    test('parses Astracat-style array of xray configs with remarks names', () {
      final raw = jsonEncode([
        {
          'outbounds': [
            {
              'tag': 'proxy',
              'protocol': 'trojan',
              'settings': {
                'servers': [
                  {
                    'address': 'si.astracat.ru',
                    'port': 443,
                    'password': 'secret-1',
                  },
                ],
              },
              'streamSettings': {
                'network': 'grpc',
                'grpcSettings': {'serviceName': 'PushNotificationService'},
                'security': 'tls',
                'tlsSettings': {
                  'serverName': 'si.astracat.ru',
                  'fingerprint': 'chrome',
                  'alpn': ['h2'],
                },
              },
            },
            {'tag': 'direct', 'protocol': 'freedom'},
            {'tag': 'block', 'protocol': 'blackhole'},
          ],
          'remarks': '🇸🇬🚀Сингапур 40 гб/с',
        },
        {
          'outbounds': [
            {
              'tag': 'proxy',
              'protocol': 'hysteria',
              'settings': {
                'address': 'nl2.astracat.ru',
                'port': 443,
                'version': 2,
              },
              'streamSettings': {
                'network': 'hysteria',
                'hysteriaSettings': {
                  'version': 2,
                  'auth': '0de99f86-bc7a-4770-82e0-97c0c544ed0a',
                },
                'security': 'tls',
                'tlsSettings': {
                  'serverName': 'nl2.astracat.ru',
                  'fingerprint': 'chrome',
                  'alpn': ['h3'],
                },
              },
            },
            {'tag': 'direct', 'protocol': 'freedom'},
            {'tag': 'block', 'protocol': 'blackhole'},
          ],
          'remarks': '🇳🇱🚀Нидерланды 10 гб/c BeastSpeed',
        },
      ]);

      final result = SubscriptionParser.parse(raw);

      expect(result.format, SubscriptionFormat.xrayConfig);
      expect(result.outbounds.length, 2);

      final trojan = result.outbounds[0];
      expect(trojan['type'], 'trojan');
      expect(trojan['server'], 'si.astracat.ru');
      expect(trojan['_name'], '🇸🇬🚀Сингапур 40 гб/с');

      final hysteria2 = result.outbounds[1];
      expect(hysteria2['type'], 'hysteria2');
      expect(hysteria2['server'], 'nl2.astracat.ru');
      expect(hysteria2['password'], '0de99f86-bc7a-4770-82e0-97c0c544ed0a');
      expect(hysteria2['_name'], '🇳🇱🚀Нидерланды 10 гб/c BeastSpeed');
    });

    test('extracts body metadata from base64 links', () {
      final raw = [
        '#profile-title: My VPN',
        '#subscription-userinfo: upload=100; download=200; total=1000; expire=9999999',
        '#support-url: https://t.me/test',
        'vless://uuid@server.com:443?type=tcp&security=tls#Node1',
      ].join('\n');
      final b64 = base64Encode(utf8.encode(raw));

      final result = SubscriptionParser.parse(b64);
      expect(result.format, SubscriptionFormat.base64Links);
      expect(result.bodyMeta['profile-title'], 'My VPN');
      expect(
        result.bodyMeta['subscription-userinfo'],
        'upload=100; download=200; total=1000; expire=9999999',
      );
      expect(result.bodyMeta['support-url'], 'https://t.me/test');
    });

    test('returns unknown for empty/garbage', () {
      expect(SubscriptionParser.parse('').format, SubscriptionFormat.unknown);
      expect(
        SubscriptionParser.parse('just some text').format,
        SubscriptionFormat.unknown,
      );
    });
  });
}
