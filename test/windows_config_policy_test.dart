import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/platform/windows/desktop_preferences.dart';
import 'package:meow_client/platform/windows/windows_config_policy.dart';
import 'package:meow_client/singbox/singbox_config_builder.dart';
import 'package:meow_client/data/local/app_settings_store.dart';

Map<String, Object?> fixture() => {
  'inbounds': [
    {
      'type': 'tun',
      'tag': 'tun-in',
      'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
      'include_package': ['android.app'],
      'exclude_package': ['another.app'],
    },
    {
      'type': 'mixed',
      'tag': 'mixed-in',
      'listen': '0.0.0.0',
      'listen_port': 2080,
      'set_system_proxy': true,
    },
  ],
  'dns': {
    'servers': [
      {'type': 'local', 'tag': 'dns-local'},
    ],
    'final': 'dns-remote',
  },
  'route': {
    'final': 'select',
    'rules': [
      {'action': 'sniff'},
      {
        'type': 'logical',
        'mode': 'or',
        'rules': [
          {'protocol': 'dns'},
          {'port': 53},
        ],
        'action': 'hijack-dns',
      },
      {'ip_is_private': true, 'outbound': 'direct'},
      {
        'domain_suffix': ['ru'],
        'outbound': 'direct',
      },
      {
        'ip_cidr': ['2001:db8::/32'],
        'outbound': 'select',
      },
    ],
  },
};

void main() {
  for (final policy in ProcessRoutingMode.values) {
    for (final allow in [false, true]) {
      test(
        'process $policy precedes actual builder adblock (allow=$allow)',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'a3-adblock-order-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final blockFile = File('${directory.path}/block.srs');
          await blockFile.writeAsBytes([1, 2, 3, 4, 5, 6]);
          final source = SingboxConfigBuilder(
            activeSubscription: null,
            selectedProxyTag: '',
            vpnInboundEnabled: true,
            vpnMtu: 1500,
            vpnStrictRoute: true,
            vpnTunImplementation: TunImplementationPreference.native,
            proxyInboundEnabled: false,
            proxyMixedListen: '127.0.0.1',
            proxyMixedPort: 1080,
            dnsDirectResolver: 'udp://1.1.1.1',
            dnsProxyResolver: 'https://dns.cloudflare.com/dns-query',
            urlTestUrl: 'https://example.test',
            urlTestIntervalSeconds: 1800,
            urlTestTimeoutSeconds: 15,
            urlTestConcurrency: 10,
            urlTestUnavailableCheckIntervalSeconds: 120,
            blockLeaks: true,
            adBlockEnabled: true,
            adBlockBlockRuleSetPath: blockFile.path,
            adBlockAllowRuleSetPath: allow ? blockFile.path : null,
            useRussiaRouteData: false,
            bypassLocalNetwork: true,
            splitRoutingMode: SplitRoutingMode.disabled,
            splitRoutingPackages: const [],
            logLevel: 'warning',
            tcpFastOpenEnabled: true,
            tcpMultiPathEnabled: false,
            tlsFragmentationMode: TlsFragmentationMode.disabled,
            interruptExistingConnections: true,
            urlTestStrictTolerance: true,
            markAllServersRussia: false,
          ).build();
          final result = WindowsConfigPolicy.apply(
            source,
            DesktopModePreferences(
              tunEnabled: true,
              processRoutingMode: policy,
              processPaths: [r'C:\Apps\foo.exe'],
            ),
          );
          final rules = ((result['route'] as Map)['rules'] as List)
              .cast<Map<String, Object?>>();
          expect(rules.take(5).toList(), [
            {'action': 'sniff'},
            {
              'type': 'logical',
              'mode': 'or',
              'rules': [
                {'protocol': 'dns'},
                {'port': 53},
              ],
              'action': 'hijack-dns',
            },
            {
              'inbound': 'tun-in',
              'network': 'icmp',
              'ip_cidr': '172.19.0.2/32',
              'action': 'reject',
              'method': 'drop',
            },
            {'protocol': 'stun', 'action': 'reject'},
            {'ip_is_private': true, 'outbound': 'direct'},
          ]);
          expect(rules[5], {
            'process_path_regex': [r'(?i)^c:\\apps\\foo\.exe$'],
            'outbound': policy == ProcessRoutingMode.onlySelected
                ? 'select'
                : 'direct',
          });
          final presetStart = policy == ProcessRoutingMode.onlySelected ? 7 : 6;
          if (policy == ProcessRoutingMode.onlySelected) {
            expect(rules[6], {'outbound': 'direct'});
          }
          expect(rules[presetStart], {
            if (allow) ...{
              'type': 'logical',
              'mode': 'and',
              'rules': [
                {'rule_set': 'adblock-block'},
                {'rule_set': 'adblock-allow', 'invert': true},
              ],
            } else
              'rule_set': 'adblock-block',
            'action': 'reject',
          });
        },
      );
    }
  }
  for (final tun in [false, true]) {
    for (final proxy in [false, true]) {
      test(
        'tun=$tun systemProxy=$proxy keeps local mixed and only desired TUN',
        () {
          final source = fixture();
          final before = jsonEncode(source);
          final result = WindowsConfigPolicy.apply(
            source,
            DesktopModePreferences(tunEnabled: tun, systemProxyEnabled: proxy),
          );
          final inbounds = (result['inbounds'] as List)
              .cast<Map<String, Object?>>();
          final mixed = inbounds.singleWhere((v) => v['type'] == 'mixed');
          expect(mixed['listen'], '127.0.0.1');
          expect(mixed['listen_port'], 2080);
          expect(mixed['set_system_proxy'], false);
          expect(
            inbounds.where((v) => v['type'] == 'tun'),
            hasLength(tun ? 1 : 0),
          );
          for (final inbound in inbounds) {
            expect(inbound.containsKey('include_package'), false);
            expect(inbound.containsKey('exclude_package'), false);
          }
          expect((result['route'] as Map)['auto_detect_interface'], true);
          expect(result['dns'], source['dns']);
          if (tun) {
            expect(inbounds.first['address'], [
              '172.19.0.1/30',
              'fdfe:dcba:9876::1/126',
            ]);
          }
          expect(
            jsonEncode(source),
            before,
            reason: 'do not mutate cached Android config',
          );
        },
      );
    }
  }
  test('creates mixed and desired TUN when Android inbounds are absent', () {
    final result = WindowsConfigPolicy.apply({
      'route': {'rules': <Object?>[]},
    }, const DesktopModePreferences(tunEnabled: true));
    final inbounds = (result['inbounds'] as List).cast<Map<String, Object?>>();
    expect(
      inbounds.singleWhere((v) => v['type'] == 'mixed')['listen_port'],
      1080,
    );
    expect(inbounds.singleWhere((v) => v['type'] == 'tun')['auto_route'], true);
  });
  test(
    'process policy precedes domain and IP presets but preserves DNS/local',
    () {
      final result = WindowsConfigPolicy.apply(
        fixture(),
        const DesktopModePreferences(
          processRoutingMode: ProcessRoutingMode.onlySelected,
          processPaths: [r'C:\Apps\foo.exe'],
        ),
      );
      final rules = ((result['route'] as Map)['rules'] as List)
          .cast<Map<String, Object?>>();
      expect(
        rules.take(3).toList(),
        (fixture()['route'] as Map)['rules'].take(3).toList(),
      );
      expect(rules[3], {
        'process_path_regex': [r'(?i)^c:\\apps\\foo\.exe$'],
        'outbound': 'select',
      });
      expect(rules[4], {'outbound': 'direct'});
      expect(rules[5]['domain_suffix'], ['ru']);
      expect(rules[6]['ip_cidr'], ['2001:db8::/32']);
    },
  );
}
