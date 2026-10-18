import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/offline_url_test_requests.dart';

void main() {
  test(
    'fresh same-row tap waits for canceled owner then starts again',
    () async {
      final requests = OfflineUrlTestRequests();
      final oldDone = Completer<void>();
      var starts = 0;
      final old = requests.run(
        tags: {'a'},
        isCurrent: () => true,
        execute: () {
          starts++;
          return oldDone.future;
        },
      );
      requests.cancelPending();
      final fresh = requests.run(
        tags: {'a'},
        isCurrent: () => true,
        execute: () async {
          starts++;
        },
      );
      expect(starts, 1);
      oldDone.complete();
      await Future.wait([old, fresh]);
      expect(starts, 2);
    },
  );
  test('same and contained requests join one running probe', () async {
    final requests = OfflineUrlTestRequests();
    final done = Completer<void>();
    var starts = 0;
    Future<void> start() {
      starts++;
      return done.future;
    }

    final first = requests.run(
      tags: {'a', 'b'},
      isCurrent: () => true,
      execute: start,
    );
    final second = requests.run(
      tags: {'a'},
      isCurrent: () => true,
      execute: start,
    );
    expect(starts, 1);
    done.complete();
    await Future.wait([first, second]);
    expect(starts, 1);
  });

  test('different rows serialize and queued repeats join', () async {
    final requests = OfflineUrlTestRequests();
    final firstDone = Completer<void>();
    final secondDone = Completer<void>();
    final starts = <String>[];
    final a = requests.run(
      tags: {'a'},
      isCurrent: () => true,
      execute: () {
        starts.add('a');
        return firstDone.future;
      },
    );
    Future<void> startB() {
      starts.add('b');
      return secondDone.future;
    }

    final b = requests.run(tags: {'b'}, isCurrent: () => true, execute: startB);
    final bAgain = requests.run(
      tags: {'b'},
      isCurrent: () => true,
      execute: startB,
    );
    expect(starts, ['a']);
    firstDone.complete();
    await a;
    await Future<void>.delayed(Duration.zero);
    expect(starts, ['a', 'b']);
    secondDone.complete();
    await Future.wait([b, bAgain]);
    expect(starts, ['a', 'b']);
  });

  test('cancel and scope change discard queued requests', () async {
    for (final cancel in [true, false]) {
      final requests = OfflineUrlTestRequests();
      final done = Completer<void>();
      var current = true;
      var queuedStarts = 0;
      final a = requests.run(
        tags: null,
        isCurrent: () => true,
        execute: () => done.future,
      );
      // A full sweep already owns a, but the next full request must queue.
      final b = requests.run(
        tags: null,
        isCurrent: () => current,
        execute: () async {
          queuedStarts++;
        },
      );
      if (cancel) {
        requests.cancelPending();
      } else {
        current = false;
      }
      done.complete();
      await Future.wait([a, b]);
      expect(queuedStarts, 0);
    }
  });

  test('failed probe releases ownership for next request', () async {
    final requests = OfflineUrlTestRequests();
    await expectLater(
      requests.run(
        tags: {'a'},
        isCurrent: () => true,
        execute: () async {
          throw StateError('start failed');
        },
      ),
      throwsStateError,
    );
    var started = false;
    await requests.run(
      tags: {'b'},
      isCurrent: () => true,
      execute: () async {
        started = true;
      },
    );
    expect(started, isTrue);
  });
}
