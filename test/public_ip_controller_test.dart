import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/home/public_ip_controller.dart';

void main() {
  test('trace uses client country, not the Cloudflare data center', () {
    final info = PublicIpInfo.fromTrace('ip=203.0.113.8\nloc=se\ncolo=AMS\n');
    expect(info.ip, '203.0.113.8');
    expect(info.countryCode, 'SE');
    expect(PublicIpInfo.fromTrace('ip=2001:db8::1\nloc=XX').countryCode, '');
    expect(
      () => PublicIpInfo.fromTrace('ip=not-an-ip\nloc=SE'),
      throwsFormatException,
    );
  });

  testWidgets('refresh gates repeated calls for four seconds', (tester) async {
    var calls = 0;
    final controller = PublicIpController(
      load: () async {
        calls++;
        return PublicIpInfo.fromTrace('ip=203.0.113.$calls\nloc=SE');
      },
    );
    await controller.refresh();
    await controller.refresh();
    expect(controller.info?.ip, '203.0.113.1');
    await tester.pump(const Duration(milliseconds: 3999));
    await controller.refresh();
    expect(controller.info?.ip, '203.0.113.1');
    await tester.pump(const Duration(milliseconds: 1));
    await controller.refresh();
    expect(controller.info?.ip, '203.0.113.2');
    controller.dispose();
  });

  testWidgets('a slow request stays exclusive after cooldown expires', (
    tester,
  ) async {
    final pending = Completer<PublicIpInfo>();
    var calls = 0;
    final controller = PublicIpController(
      load: () {
        calls++;
        return calls == 1
            ? pending.future
            : Future.value(PublicIpInfo.fromTrace('ip=203.0.113.9'));
      },
    );
    final request = controller.refresh();
    await tester.pump(const Duration(seconds: 5));
    await controller.refresh();
    pending.complete(PublicIpInfo.fromTrace('ip=203.0.113.8'));
    await request;
    expect(controller.info?.ip, '203.0.113.8');
    expect(controller.canRefresh, isTrue);
    controller.dispose();
  });

  testWidgets(
    'a failed refresh preserves the last successful address and flag',
    (tester) async {
      var calls = 0;
      final controller = PublicIpController(
        load: () async {
          if (++calls > 1) throw StateError('network unavailable');
          return PublicIpInfo.fromTrace('ip=203.0.113.8\nloc=SE');
        },
      );
      await controller.refresh();
      await tester.pump(const Duration(seconds: 4));
      await controller.refresh();
      expect(controller.info?.ip, '203.0.113.8');
      expect(controller.info?.countryCode, 'SE');
      expect(controller.failed, isTrue);
      expect(controller.loading, isFalse);
      controller.dispose();
    },
  );

  testWidgets('closing ignores late results without bypassing cooldown', (
    tester,
  ) async {
    final pending = Completer<PublicIpInfo>();
    final controller = PublicIpController(load: () => pending.future);
    final request = controller.refresh();
    controller.cancel();
    pending.complete(PublicIpInfo.fromTrace('ip=203.0.113.8\nloc=SE'));
    await request;
    expect(controller.info, isNull);
    expect(controller.loading, isFalse);
    expect(controller.canRefresh, isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(controller.canRefresh, isTrue);
    controller.dispose();
  });
}
