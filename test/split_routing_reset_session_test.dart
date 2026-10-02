import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/split_routing_reset_session.dart';

void main() {
  test('acknowledgement failure never consumes the pending notice', () async {
    final session = SplitRoutingResetSession(pending: true);
    await expectLater(
      session.handle(
        stop: () async => true,
        showNotice: () async => false,
        acknowledge: () async => throw StateError('disk full'),
      ),
      throwsStateError,
    );
    expect(session.pending, isTrue);
    expect(session.suppressAutoConnect, isTrue);
    await session.handle(
      stop: () async => true,
      showNotice: () async => false,
      acknowledge: () async {},
    );
    expect(session.pending, isFalse);
  });
  test(
    'reset suppresses only this launch and acknowledges after confirmed stop',
    () async {
      final order = <String>[];
      final session = SplitRoutingResetSession(pending: true);
      expect(session.suppressAutoConnect, isTrue);
      final open = await session.handle(
        stop: () async {
          order.add('stop');
          return true;
        },
        showNotice: () async {
          order.add('notice');
          return true;
        },
        acknowledge: () async {
          order.add('save');
        },
      );
      expect(open, isTrue);
      expect(order, ['stop', 'notice', 'save']);
      expect(session.pending, isFalse);
      expect(session.suppressAutoConnect, isTrue);
      expect(
        SplitRoutingResetSession(pending: false).suppressAutoConnect,
        isFalse,
      );
      await session.handle(
        stop: () async => throw StateError('must not stop again'),
        showNotice: () async => throw StateError('must not show again'),
        acknowledge: () async => throw StateError('must not save again'),
      );
    },
  );

  test(
    'failed stop and dismissed notice keep reset pending for retry',
    () async {
      final session = SplitRoutingResetSession(pending: true);
      await expectLater(
        session.handle(
          stop: () async => false,
          showNotice: () async => throw StateError('must not show before stop'),
          acknowledge: () async => throw StateError('must not acknowledge'),
        ),
        throwsStateError,
      );
      expect(session.pending, isTrue);
      await session.handle(
        stop: () async => true,
        showNotice: () async => null,
        acknowledge: () async => throw StateError('must not acknowledge'),
      );
      expect(session.pending, isTrue);
      await session.handle(
        stop: () async => true,
        showNotice: () async => false,
        acknowledge: () async {},
      );
      expect(session.pending, isFalse);
    },
  );
}
