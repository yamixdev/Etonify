import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/proxy_exclusion_sync.dart';

void main() {
  test('a rejected policy is retried on the next event', () async {
    var calls = 0;
    final sync = ProxyExclusionSync(
      apply: (tags, generation) async {
        if (++calls == 1) throw StateError('temporarily disconnected');
      },
    );
    await expectLater(
      sync.synchronize(tags: ['a'], runtimeGeneration: 1),
      throwsStateError,
    );
    await sync.synchronize(tags: ['a'], runtimeGeneration: 1);
    await sync.synchronize(tags: ['a'], runtimeGeneration: 1);
    expect(calls, 2);
  });

  test(
    'pending duplicates coalesce and changed policies retain order',
    () async {
      final gate = Completer<void>();
      final sent = <String>[];
      final sync = ProxyExclusionSync(
        apply: (tags, generation) async {
          sent.add('$generation:${tags.join(',')}');
          if (sent.length == 1) await gate.future;
        },
      );
      final first = sync.synchronize(
        tags: ['b', 'a', 'a'],
        runtimeGeneration: 1,
      );
      final duplicate = sync.synchronize(
        tags: ['a', 'b'],
        runtimeGeneration: 1,
      );
      final clear = sync.synchronize(tags: [], runtimeGeneration: 1);
      gate.complete();
      await Future.wait([first, duplicate, clear]);
      expect(sent, ['1:a,b', '1:']);
      await sync.synchronize(tags: [], runtimeGeneration: 2);
      expect(sent, ['1:a,b', '1:', '2:']);
    },
  );
}
