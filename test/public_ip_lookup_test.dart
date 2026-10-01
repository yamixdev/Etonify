import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meow_client/features/home/public_ip_controller.dart';

void main() {
  test(
    'normal HTTPS request reads the public IP without proxy metadata',
    () async {
      final lookup = PublicIpLookup(
        clientFactory: () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://1.1.1.1/cdn-cgi/trace');
          expect(request.followRedirects, isFalse);
          expect(request.headers['Cache-Control'], 'no-cache');
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response('ip=203.0.113.8\nloc=SE\ncolo=AMS', 200);
        }),
      );
      final info = await lookup.load();
      expect(info.ip, '203.0.113.8');
      expect(info.countryCode, 'SE');
      lookup.cancel();
    },
  );

  test(
    'HTTP error or malformed primary response uses the domain fallback',
    () async {
      for (final primary in [
        http.Response('unavailable', 503),
        http.Response('loc=SE', 200),
      ]) {
        final lookup = PublicIpLookup(
          clientFactory: () => MockClient((request) async {
            if (request.url.host == '1.1.1.1') return primary;
            expect(
              request.url.toString(),
              'https://cloudflare.com/cdn-cgi/trace',
            );
            return http.Response('ip=2001:db8::8\nloc=DE', 200);
          }),
        );
        final info = await lookup.load();
        expect(info.ip, '2001:db8::8');
        expect(info.countryCode, 'DE');
      }
    },
  );

  test(
    'oversized chunked response is rejected rather than rendered as an IP',
    () async {
      final lookup = PublicIpLookup(
        clientFactory: () => MockClient.streaming((request, body) async {
          return http.StreamedResponse(
            Stream.fromIterable([
              utf8.encode('ip=203.0.113.8\nloc=SE\n'),
              List.filled(8192, 65),
            ]),
            200,
          );
        }),
      );
      await expectLater(lookup.load(), throwsFormatException);
    },
  );

  testWidgets(
    'lookup bounds a stalled request and cancels without a fallback',
    (tester) async {
      final stalled = Completer<http.Response>();
      var requests = 0;
      final lookup = PublicIpLookup(
        clientFactory: () => MockClient((request) {
          requests++;
          return stalled.future;
        }),
      );
      final request = lookup.load();
      final error = expectLater(request, throwsStateError);
      await tester.pump();
      lookup.cancel();
      await tester.pump(const Duration(seconds: 3));
      await error;
      expect(requests, 1);
      stalled.complete(http.Response('ip=203.0.113.8\nloc=SE', 200));
      await tester.pump();
    },
  );

  testWidgets('both stalled endpoints time out in six seconds', (tester) async {
    final stalled = Completer<http.Response>();
    var requests = 0;
    final lookup = PublicIpLookup(
      clientFactory: () => MockClient((request) {
        requests++;
        return stalled.future;
      }),
    );
    final error = expectLater(lookup.load(), throwsA(isA<TimeoutException>()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await error;
    expect(requests, 2);
    stalled.complete(http.Response('ip=203.0.113.8\nloc=SE', 200));
    await tester.pump();
  });
}
