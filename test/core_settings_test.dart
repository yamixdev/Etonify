import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/models/core_settings.dart';
import 'package:meow_client/singbox/core_settings_config.dart';

Map<String, dynamic> config() => {
  'route': {'default_domain_resolver': 'dns-local'},
  'inbounds': [
    {'type': 'tun', 'tag': 'tun-in', 'mtu': 1500},
    {'type': 'mixed'},
  ],
  'outbounds': [
    {
      'type': 'trojan',
      'tag': 'one',
      'server': 'example.com',
      'connect_timeout': '9s',
      'tls': {'enabled': true, 'insecure': false},
      'multiplex': {
        'enabled': true,
        'protocol': 'smux',
        'max_connections': 4,
        'min_streams': 2,
      },
    },
    {
      'type': 'hysteria2',
      'tag': 'quic',
      'tls': {'enabled': true},
    },
    {
      'type': 'selector',
      'tag': 'select',
      'outbounds': ['one'],
    },
    {'type': 'direct', 'tag': 'direct'},
    {'type': 'vless', 'tag': 'hop', 'detour': 'one'},
  ],
};

void main() {
  test('settings config matches the native validation corpus', () {
    final fixture = File('test/fixtures/core_settings_config.json');
    final cases = jsonDecode(fixture.readAsStringSync()) as List;
    for (final entry in cases) {
      final value =
          jsonDecode(jsonEncode(entry['input'])) as Map<String, dynamic>;
      applyCoreSettings(
        value,
        CoreSettings.fromMap(entry['settings'] as Map),
        profileId: 'profile',
      );
      expect(value, entry['expected'], reason: entry['name'] as String);
    }
    final native = File(
      'etonify-core/experimental/libbox/testdata/etonify_core_settings.json',
    );
    if (native.existsSync()) {
      expect(jsonDecode(native.readAsStringSync()), cases);
    }
  });
  test('defaults are a no-op, including provider multiplex', () {
    final value = config();
    final before = jsonEncode(value);
    applyCoreSettings(value, const CoreSettings(), profileId: 'p');
    expect(jsonEncode(value), before);
  });
  test('malformed persisted values fall back safely', () {
    expect(CoreSettings.decode('{'), const CoreSettings());
    final value = CoreSettings.fromMap({
      'connectTimeoutSeconds': -1,
      'udpNatMax': 999999,
      'keepAliveSeconds': 0,
      'networkStrategy': 'invented',
    });
    expect(value, const CoreSettings());
  });
  test('serialization is stable and imported maps are not retained', () {
    final input = {'connectTimeoutSeconds': 10};
    final value = CoreSettings.fromMap(input);
    input['connectTimeoutSeconds'] = 20;
    expect(value.connectTimeoutSeconds, 10);
    expect(CoreSettings.decode(jsonEncode(value.toMap())), value);
    expect(
      () => value.multiplex['x'] = const CoreMuxSettings(),
      throwsUnsupportedError,
    );
  });
  test('network fields belong to route and NAT fields only to TUN', () {
    final value = config();
    applyCoreSettings(
      value,
      const CoreSettings(
        networkStrategy: CoreNetworkStrategy.fallback,
        networkType: CoreNetworkType.wifi,
        fallbackNetworkType: CoreNetworkType.cellular,
        fallbackDelayMs: 500,
        udpMapping: CoreNatBehavior.addressDependent,
        udpFiltering: CoreNatBehavior.addressAndPortDependent,
        udpNatMax: 8192,
        udpTimeoutSeconds: 300,
      ),
      profileId: 'p',
    );
    expect(value['route']['default_network_strategy'], 'fallback');
    expect(value['route']['default_network_type'], ['wifi']);
    expect(value['route']['default_fallback_network_type'], ['cellular']);
    expect(value['route']['default_fallback_delay'], '500ms');
    expect(value['inbounds'][0]['udp_mapping'], 'address_dependent');
    expect(value['inbounds'][0]['udp_filtering'], 'address_and_port_dependent');
    expect(value['inbounds'][0]['udp_nat_max'], 8192);
    expect(value['inbounds'][0]['mtu'], 1500);
    expect(value['inbounds'][1], {'type': 'mixed'});
    expect(value['outbounds'][0].containsKey('network_strategy'), isFalse);
  });
  test('hidden fallback controls do not leak into hybrid or defaults', () {
    for (final strategy in [
      CoreNetworkStrategy.defaults,
      CoreNetworkStrategy.hybrid,
    ]) {
      final value = config();
      applyCoreSettings(
        value,
        CoreSettings(
          networkStrategy: strategy,
          fallbackDelayMs: 123,
          fallbackNetworkType: CoreNetworkType.cellular,
        ),
        profileId: 'p',
      );
      expect(value['route'].containsKey('default_fallback_delay'), isFalse);
      expect(
        value['route'].containsKey('default_fallback_network_type'),
        isFalse,
      );
    }
  });
  test(
    'dial settings skip groups, direct, and detour socket owners; TLS is copied',
    () {
      final value = config();
      final originalTls = value['outbounds'][0]['tls'];
      applyCoreSettings(
        value,
        const CoreSettings(
          connectTimeoutSeconds: 20,
          keepAlive: CoreKeepAlive.manual,
          keepAliveSeconds: 40,
          keepAliveIntervalSeconds: 15,
          tlsHandshakeTimeoutSeconds: 12,
          udpFragment: CoreUdpFragment.disabled,
        ),
        profileId: 'p',
      );
      final proxy = value['outbounds'][0];
      expect(proxy['connect_timeout'], '20s');
      expect(proxy['tcp_keep_alive'], '40s');
      expect(proxy['tcp_keep_alive_interval'], '15s');
      expect(proxy['disable_tcp_keep_alive'], false);
      expect(proxy['tls']['handshake_timeout'], '12s');
      expect(proxy['tls']['insecure'], false);
      expect(originalTls.containsKey('handshake_timeout'), false);
      expect(value['outbounds'][1].containsKey('tcp_keep_alive'), false);
      expect(
        value['outbounds'][1]['tls'].containsKey('handshake_timeout'),
        false,
      );
      for (final index in [2, 3, 4]) {
        expect(value['outbounds'][index].containsKey('connect_timeout'), false);
      }
    },
  );
  test(
    'manual multiplex is scoped by profile and tag and has no conflicting limits',
    () {
      final settings = const CoreSettings().withMux(
        'p',
        'one',
        const CoreMuxSettings(
          mode: CoreMuxMode.manual,
          protocol: CoreMuxProtocol.yamux,
          maxStreams: 16,
        ),
      );
      final value = config();
      applyCoreSettings(value, settings, profileId: 'p');
      expect(value['outbounds'][0]['multiplex'], {
        'enabled': true,
        'protocol': 'yamux',
        'max_streams': 16,
        'padding': false,
      });
      final other = config();
      final before = jsonEncode(other);
      applyCoreSettings(other, settings, profileId: 'other');
      expect(jsonEncode(other), before);
      expect(
        settings.withMux('p', 'one', const CoreMuxSettings()),
        const CoreSettings(),
      );
    },
  );
  test('XHTTP, QUIC and Vision cannot receive manual sing-mux', () {
    for (final value in [
      {'type': 'vless', 'flow': 'xtls-rprx-vision'},
      {
        'type': 'vless',
        'transport': {
          'type': 'xhttp',
          'xmux': {'maxConcurrency': 4},
        },
      },
      {'type': 'hysteria2'},
      {'type': 'urltest'},
    ]) {
      expect(CoreMuxSettings.supports(value), false);
    }
  });
  test(
    'an old standalone override does not change a node now owned by a group',
    () {
      final settings = const CoreSettings().withMux(
        'p',
        'one',
        const CoreMuxSettings(mode: CoreMuxMode.disabled),
      );
      final value = config();
      final before = jsonEncode(value);
      applyCoreSettings(
        value,
        settings,
        profileId: 'p',
        multiplexEligibleTags: {},
      );
      expect(jsonEncode(value), before);
    },
  );
  test(
    'NaiveProxy and QUIC outbounds do not receive TLS handshake_timeout or TCP keepalive',
    () {
      final value = {
        'outbounds': [
          {
            'type': 'naive',
            'tag': 'naive-https',
            'server': 'naive.example.com',
            'server_port': 443,
            'tls': {'enabled': true, 'server_name': 'naive.example.com'},
          },
          {
            'type': 'naive',
            'tag': 'naive-quic',
            'server': 'naive-quic.example.com',
            'server_port': 443,
            'quic': true,
            'tls': {'enabled': true, 'server_name': 'naive-quic.example.com'},
          },
          {
            'type': 'vless',
            'tag': 'vless-quic',
            'server': 'vless.example.com',
            'server_port': 443,
            'transport': {'type': 'quic'},
            'tls': {'enabled': true, 'server_name': 'vless.example.com'},
          },
          {
            'type': 'anytls',
            'tag': 'anytls-node',
            'server': 'anytls.example.com',
            'server_port': 443,
            'tls': {'enabled': true, 'server_name': 'anytls.example.com'},
          },
        ],
      };

      applyCoreSettings(
        value,
        const CoreSettings(
          tlsHandshakeTimeoutSeconds: 12,
          keepAlive: CoreKeepAlive.manual,
          keepAliveSeconds: 45,
          keepAliveIntervalSeconds: 10,
        ),
        profileId: 'p',
      );

      final outbounds =
          (value['outbounds'] as List).cast<Map<String, dynamic>>();
      final naiveHttps = outbounds.firstWhere((o) => o['tag'] == 'naive-https');
      final naiveQuic = outbounds.firstWhere((o) => o['tag'] == 'naive-quic');
      final vlessQuic = outbounds.firstWhere((o) => o['tag'] == 'vless-quic');
      final anytls = outbounds.firstWhere((o) => o['tag'] == 'anytls-node');

      expect(naiveHttps['tls'].containsKey('handshake_timeout'), isFalse);
      expect(naiveQuic['tls'].containsKey('handshake_timeout'), isFalse);

      expect(vlessQuic['tls'].containsKey('handshake_timeout'), isFalse);
      expect(vlessQuic.containsKey('tcp_keep_alive'), isFalse);
      expect(naiveQuic.containsKey('tcp_keep_alive'), isFalse);
      expect(naiveHttps.containsKey('tcp_keep_alive'), isFalse);

      expect(anytls['tls']['handshake_timeout'], '12s');
      expect(anytls['tcp_keep_alive'], '45s');
      expect(anytls['tcp_keep_alive_interval'], '10s');
    },
  );
}
