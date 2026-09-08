import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/subscription/outbound_schema.dart';
import 'package:meow_client/data/subscription/subscription_parser.dart';

void main() {
  final corpus =
      jsonDecode(
            File('test/fixtures/etonify_schema114.json').readAsStringSync(),
          )
          as List;
  final coreCorpus = File(
    'etonify-core/experimental/libbox/testdata/etonify_schema114.json',
  );
  test('client and core corpora stay identical', () {
    expect(jsonDecode(coreCorpus.readAsStringSync()), corpus);
  }, skip: coreCorpus.existsSync() ? false : 'Core submodule not checked out');
  for (final fixture in corpus.cast<Map<String, dynamic>>()) {
    test('1.14 corpus: ${fixture['name']}', () {
      final input = fixture['input'] as Map<String, dynamic>;
      final original = jsonEncode(input);
      final result = ParsedOutboundSchema.sanitize(input);
      expect(result, fixture['expected']);
      expect(ParsedOutboundSchema.sanitize(result!), result);
      expect(jsonEncode(input), original);
    });
    test('subscription import 1.14: ${fixture['name']}', () {
      final parsed = SubscriptionParser.parse(
        jsonEncode({
          'outbounds': [fixture['input']],
        }),
      );
      expect(parsed.outbounds, hasLength(1));
      for (final entry in (fixture['expected'] as Map).entries) {
        expect(parsed.outbounds.single, containsPair(entry.key, entry.value));
      }
    });
  }

  test('modern Hysteria values win, including false and zero', () {
    final config = <String, dynamic>{
      'type': 'hysteria',
      'recv_window_conn': 100,
      'stream_receive_window': 0,
      'recv_window': 200,
      'connection_receive_window': '4MiB',
      'disable_mtu_discovery': true,
      'disable_path_mtu_discovery': false,
    };
    ParsedOutboundSchema.migrateTo114(config);
    expect(config, {
      'type': 'hysteria',
      'stream_receive_window': 0,
      'connection_receive_window': '4MiB',
      'disable_path_mtu_discovery': false,
    });
  });

  test('preserves explicit resolver and modern strategy', () {
    for (final resolver in <dynamic>[
      'dns-local',
      {'server': 'dns-local', 'strategy': 'ipv6_only', 'disable_cache': true},
    ]) {
      final config = <String, dynamic>{
        'domain_strategy': 'prefer_ipv4',
        'domain_resolver': resolver,
      };
      ParsedOutboundSchema.migrateTo114(config);
      expect(config.containsKey('domain_strategy'), false);
      expect(
        config['domain_resolver'],
        resolver is Map
            ? resolver
            : {'server': 'dns-local', 'strategy': 'prefer_ipv4'},
      );
    }
  });

  test('legacy strategy does not force local resolution on a detour', () {
    final config = <String, dynamic>{
      'detour': 'upstream',
      'domain_strategy': 'prefer_ipv4',
    };
    ParsedOutboundSchema.migrateTo114(config);
    expect(config, {'detour': 'upstream'});
  });

  test('QUIC options stay protocol-specific', () {
    final config = <String, dynamic>{
      'type': 'trojan',
      'server': 'example.com',
      'server_port': 443,
      'password': 'test',
      'initial_packet_size': 1200,
      'stream_receive_window': 100,
    };
    final result = ParsedOutboundSchema.sanitize(config)!;
    expect(result.containsKey('initial_packet_size'), false);
    expect(result.containsKey('stream_receive_window'), false);
  });

  test('salamander stays supported, unknown obfs is rejected', () {
    final base = <String, dynamic>{
      'type': 'hysteria2',
      'server': 'example.com',
      'server_port': 443,
      'password': 'test',
      'tls': {'enabled': true},
    };
    expect(
      ParsedOutboundSchema.sanitize({
        ...base,
        'obfs': {
          'type': 'salamander',
          'password': 'secret',
          'min_packet_size': 512,
        },
      })!['obfs'],
      {'type': 'salamander', 'password': 'secret'},
    );
    expect(
      ParsedOutboundSchema.sanitize({
        ...base,
        'obfs': {'type': 'unknown', 'password': 'secret'},
      }),
      isNull,
    );
  });
}
