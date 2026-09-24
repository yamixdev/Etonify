import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/group_url_test_scheduler.dart';

void main() {
  test('latest automatic URLTest replaces the previous timer', () async {
    final scheduler = GroupUrlTestScheduler();
    addTearDown(scheduler.dispose);
    final calls = <String>[];

    scheduler.schedule(
      delay: const Duration(milliseconds: 30),
      canRun: () => true,
      run: () async {
        calls.add('first');
        return true;
      },
    );
    scheduler.schedule(
      delay: const Duration(milliseconds: 10),
      canRun: () => true,
      run: () async {
        calls.add('second');
        return true;
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(calls, const <String>['second']);
    expect(scheduler.isScheduled, isFalse);
  });

  test('temporarily unavailable automatic check waits until ready', () async {
    final scheduler = GroupUrlTestScheduler();
    addTearDown(scheduler.dispose);
    var ready = false;
    var calls = 0;

    scheduler.schedule(
      delay: Duration.zero,
      readinessRetryDelay: const Duration(milliseconds: 10),
      readinessTimeout: const Duration(milliseconds: 80),
      canRun: () => ready,
      run: () async {
        calls++;
        return true;
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(calls, 0);

    ready = true;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(calls, 1);
    expect(scheduler.hasPendingWork, isFalse);
  });

  test('failed automatic check is retried once and then settles', () async {
    final scheduler = GroupUrlTestScheduler();
    addTearDown(scheduler.dispose);
    var calls = 0;
    bool? settled;

    scheduler.schedule(
      delay: Duration.zero,
      runRetryDelay: const Duration(milliseconds: 10),
      maxRunAttempts: 2,
      canRun: () => true,
      run: () async {
        calls++;
        return calls == 2;
      },
      onSettled: (success) => settled = success,
    );

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(calls, 2);
    expect(settled, isTrue);
    expect(scheduler.hasPendingWork, isFalse);
  });

  test(
    'long failed check does not start another expensive full pass',
    () async {
      final scheduler = GroupUrlTestScheduler();
      addTearDown(scheduler.dispose);
      var calls = 0;
      bool? settled;

      scheduler.schedule(
        delay: Duration.zero,
        runRetryDelay: const Duration(milliseconds: 1),
        retryFailedRunWithin: const Duration(milliseconds: 5),
        maxRunAttempts: 2,
        canRun: () => true,
        run: () async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 15));
          return false;
        },
        onSettled: (success) => settled = success,
      );

      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(calls, 1);
      expect(settled, isFalse);
      expect(scheduler.hasPendingWork, isFalse);
    },
  );

  test('cancel stops readiness retries and clears pending work', () async {
    final scheduler = GroupUrlTestScheduler();
    addTearDown(scheduler.dispose);
    var calls = 0;

    scheduler.schedule(
      delay: Duration.zero,
      readinessRetryDelay: const Duration(milliseconds: 10),
      readinessTimeout: const Duration(milliseconds: 100),
      canRun: () => false,
      run: () async {
        calls++;
        return true;
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(scheduler.hasPendingWork, isTrue);

    scheduler.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(calls, 0);
    expect(scheduler.hasPendingWork, isFalse);
  });

  test('pending reason tracks the latest automatic trigger', () {
    final scheduler = GroupUrlTestScheduler();
    addTearDown(scheduler.dispose);
    scheduler.schedule(
      reason: 'periodic',
      delay: const Duration(hours: 1),
      canRun: () => true,
      run: () async => true,
    );
    expect(scheduler.pendingReason, 'periodic');
    scheduler.schedule(
      reason: 'network_changed',
      delay: const Duration(hours: 1),
      canRun: () => true,
      run: () async => true,
    );
    expect(scheduler.pendingReason, 'network_changed');
    scheduler.cancel();
    expect(scheduler.pendingReason, isNull);
  });
}
