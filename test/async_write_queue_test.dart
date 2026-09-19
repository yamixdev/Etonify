import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/async_write_queue.dart';

void main() {
  test('a later settings write waits for the current write', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final events = <String>[];
    final queue = AsyncWriteQueue<int>((value) async {
      events.add('start:$value');
      if (value == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      }
      events.add('end:$value');
    });

    final first = queue.add(1);
    await firstStarted.future;
    final second = queue.add(2);
    await Future<void>.delayed(Duration.zero);

    expect(events, const ['start:1']);
    releaseFirst.complete();
    await Future.wait([first, second]);
    expect(events, const ['start:1', 'end:1', 'start:2', 'end:2']);
  });

  test('a failed write does not poison later settings writes', () async {
    final persisted = <int>[];
    final queue = AsyncWriteQueue<int>((value) async {
      if (value == 1) {
        throw StateError('disk write failed');
      }
      persisted.add(value);
    });

    await expectLater(queue.add(1), throwsStateError);
    await queue.add(2);

    expect(persisted, const [2]);
  });
}
