import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meow_client/features/home/server_ip_metadata.dart';

Map<String, Object?> response(String ip) => {
  'ip': ip,
  'network': {
    'cidr': '203.0.113.0/24',
    'autonomous_system': {
      'asn': 64500,
      'name': 'EXAMPLE',
      'organization': 'Example Network',
      'country': 'US',
      'rir': 'TEST',
    },
  },
  'location': {
    'city': 'Stockholm',
    'country': 'Sweden',
    'timezone': 'Europe/Stockholm',
  },
};

void main() {
  test(
    'cancelling a response prevents it from becoming cached metadata',
    () async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final lookup = ServerIpMetadataLookup(
        clientFactory: () => MockClient((_) {
          calls++;
          return calls == 1
              ? pending.future
              : Future.value(
                  http.Response(jsonEncode(response('203.0.113.7')), 200),
                );
        }),
      );
      final first = lookup.load('203.0.113.7');
      final rejection = expectLater(first, throwsStateError);
      lookup.cancel();
      pending.complete(http.Response(jsonEncode(response('203.0.113.7')), 200));
      await rejection;
      await lookup.load('203.0.113.7');
      expect(calls, 2);
    },
  );

  test(
    'oversized chunked metadata is rejected without a content length',
    () async {
      final lookup = ServerIpMetadataLookup(
        clientFactory: () => MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            Stream.fromIterable([
              List.filled(40000, 32),
              List.filled(40000, 32),
            ]),
            200,
          ),
        ),
      );
      await expectLater(lookup.load('203.0.113.7'), throwsFormatException);
    },
  );

  test(
    'looks up an explicit IP and keeps ASN registration separate from location',
    () async {
      final lookup = ServerIpMetadataLookup(
        clientFactory: () => MockClient((request) async {
          expect(request.url, Uri.parse('https://ip.guide/203.0.113.7'));
          expect(request.followRedirects, isFalse);
          return http.Response(jsonEncode(response('203.0.113.7')), 200);
        }),
      );
      final info = await lookup.load('203.0.113.7');
      expect(info.ip, '203.0.113.7');
      expect(info.organization, 'Example Network');
      expect(info.asn, 64500);
      expect(info.countryName, 'Sweden');
      expect(info.city, 'Stockholm');
    },
  );

  test(
    'rejects a response for the requester IP instead of the queried IP',
    () async {
      final lookup = ServerIpMetadataLookup(
        clientFactory: () => MockClient(
          (_) async => http.Response(jsonEncode(response('198.51.100.9')), 200),
        ),
      );
      await expectLater(lookup.load('203.0.113.7'), throwsFormatException);
    },
  );

  test('accepts canonical equivalents of IPv6 and rejects hostnames', () async {
    var requests = 0;
    final lookup = ServerIpMetadataLookup(
      clientFactory: () => MockClient((request) async {
        requests++;
        expect(request.url.path, '/2001:db8::7');
        return http.Response(jsonEncode(response('2001:db8:0:0:0:0:0:7')), 200);
      }),
    );
    expect((await lookup.load('2001:db8::7')).ip, '2001:db8::7');
    await expectLater(lookup.load('server.example'), throwsFormatException);
    expect(requests, 1);
  });

  test(
    'rejects redirects, rate limits, oversized and malformed bodies',
    () async {
      for (final item in [
        http.Response('', 302),
        http.Response('', 429),
        http.Response('x' * 65537, 200),
        http.Response('[]', 200),
        http.Response('{', 200),
      ]) {
        final lookup = ServerIpMetadataLookup(
          clientFactory: () => MockClient((_) async => item),
        );
        await expectLater(lookup.load('203.0.113.7'), throwsA(anything));
      }
    },
  );

  test(
    'switching server ignores a late ISP result and disconnect clears it',
    () async {
      final first = Completer<ServerIpMetadata>();
      final second = Completer<ServerIpMetadata>();
      final controller = ServerIpMetadataController(
        load: (ip) => ip == '203.0.113.7' ? first.future : second.future,
      );
      addTearDown(controller.dispose);
      controller.select('A', '203.0.113.7');
      controller.select('B', '198.51.100.8');
      first.complete(
        const ServerIpMetadata(ip: '203.0.113.7', organization: 'Old network'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.info, isNull);
      second.complete(
        const ServerIpMetadata(
          ip: '198.51.100.8',
          organization: 'Current network',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.info?.organization, 'Current network');
      controller.select('', '');
      expect(controller.info, isNull);
      expect(controller.loading, isFalse);
    },
  );

  test(
    'repeated snapshots do not duplicate a lookup and errors can retry',
    () async {
      var requests = 0;
      final controller = ServerIpMetadataController(
        load: (ip) async {
          requests++;
          if (requests == 1) throw StateError('offline');
          return ServerIpMetadata(ip: ip, asn: 64500);
        },
      );
      addTearDown(controller.dispose);
      controller.select('A', '203.0.113.7');
      controller.select('A', '203.0.113.7');
      await Future<void>.delayed(Duration.zero);
      expect(controller.failed, isTrue);
      expect(requests, 1);
      await controller.refresh();
      expect(controller.info?.asn, 64500);
      expect(controller.failed, isFalse);
      expect(requests, 2);
    },
  );

  test(
    'cache reuses an IP across sessions but expires and is bounded',
    () async {
      var now = DateTime(2026);
      var requests = 0;
      final lookup = ServerIpMetadataLookup(
        now: () => now,
        clientFactory: () => MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode(response(request.url.path.substring(1))),
            200,
          );
        }),
      );
      await lookup.load('203.0.113.7');
      await lookup.load('203.0.113.7');
      expect(requests, 1);
      now = now.add(const Duration(hours: 7));
      await lookup.load('203.0.113.7');
      expect(requests, 2);
      for (var i = 20; i < 53; i++) {
        await lookup.load('203.0.113.$i');
      }
      await lookup.load('203.0.113.7');
      expect(requests, 36);
    },
  );
}
