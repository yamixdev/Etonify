import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/automatic_url_test_policy.dart';

void main() {
  test('disabled full auto-check still targets the selected server', () {
    for (final reason in [
      'runtime_diagnostics_ready',
      'network_changed',
      'selection',
      'subscription_composition_changed',
    ]) {
      expect(
        automaticUrlTestScope(
          reason: reason,
          autoCheckServers: false,
          supportsTargeted: true,
          selectedTag: 'node-a',
        ),
        AutomaticUrlTestScope.selected,
      );
    }
  });

  test(
    'disabled auto-check never starts a periodic or fallback full sweep',
    () {
      expect(
        automaticUrlTestScope(
          reason: 'periodic',
          autoCheckServers: false,
          supportsTargeted: true,
          selectedTag: 'node-a',
        ),
        AutomaticUrlTestScope.none,
      );
      expect(
        automaticUrlTestScope(
          reason: 'network_changed',
          autoCheckServers: false,
          supportsTargeted: false,
          selectedTag: 'node-a',
        ),
        AutomaticUrlTestScope.none,
      );
    },
  );

  test('enabled auto-check keeps exhaustive checks', () {
    expect(
      automaticUrlTestScope(
        reason: 'network_changed',
        autoCheckServers: true,
        supportsTargeted: true,
        selectedTag: 'node-a',
      ),
      AutomaticUrlTestScope.full,
    );
  });

  test('background triggers coalesce into one check on resume', () {
    final deferred = DeferredAutomaticUrlTest();
    deferred.defer();
    deferred.defer();
    expect(deferred.take(), isTrue);
    expect(deferred.take(), isFalse);
    deferred.defer();
    deferred.clear();
    expect(deferred.take(), isFalse);
  });

  test('suspending a periodic timer does not request an immediate sweep', () {
    final deferred = DeferredAutomaticUrlTest();
    deferred.deferPending(reason: 'periodic', fullSessionRunning: false);
    expect(deferred.take(), isFalse);

    deferred.deferPending(reason: 'network_changed', fullSessionRunning: false);
    expect(deferred.take(), isTrue);
  });

  test('suspending an active full sweep does not queue a duplicate', () {
    final deferred = DeferredAutomaticUrlTest();
    deferred.deferPending(reason: 'resume_deferred', fullSessionRunning: true);
    expect(deferred.take(), isFalse);
  });

  test('resume coalesces a deferred trigger into an already running sweep', () {
    final deferred = DeferredAutomaticUrlTest();
    deferred.defer();
    expect(deferred.take(fullSessionRunning: true), isFalse);
    expect(deferred.take(), isFalse);
  });

  test('periodic deadline survives background and resets after sweep', () {
    final deadline = PeriodicUrlTestDeadline();
    final started = DateTime.utc(2026, 9, 24, 10);
    const interval = Duration(minutes: 30);
    expect(deadline.remaining(now: started, interval: interval), interval);
    expect(
      deadline.remaining(
        now: started.add(const Duration(minutes: 2)),
        interval: interval,
      ),
      const Duration(minutes: 28),
    );
    deadline.reset(
      now: started.add(const Duration(minutes: 25)),
      interval: interval,
    );
    expect(
      deadline.remaining(
        now: started.add(const Duration(minutes: 26)),
        interval: interval,
      ),
      const Duration(minutes: 29),
    );
  });
}
