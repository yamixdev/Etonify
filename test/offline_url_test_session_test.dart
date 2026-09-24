import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/offline_url_test_session.dart';

void main() {
  test('completed offline sweep suppresses only duplicate startup checks', () {
    final session = OfflineUrlTestSession(
      id: 'manual-startup',
      fingerprint: 'config-a',
      physicalNetworkEpoch: 9,
      tags: {'a'},
    )..runOffline();
    session.accept(
      tag: 'a',
      delayMillis: 51,
      available: true,
      logicalSessionId: 'manual-startup',
      physicalNetworkEpoch: 9,
    );

    expect(
      session.suppressesAutomaticCheck(
        reason: 'runtime_diagnostics_ready',
        physicalNetworkEpoch: 9,
      ),
      isTrue,
    );
    expect(
      session.suppressesAutomaticCheck(
        reason: 'network_changed',
        physicalNetworkEpoch: 9,
      ),
      isTrue,
    );
    expect(
      session.suppressesAutomaticCheck(
        reason: 'selection',
        physicalNetworkEpoch: 9,
      ),
      isTrue,
    );
    expect(
      session.suppressesAutomaticCheck(
        reason: 'periodic',
        physicalNetworkEpoch: 9,
      ),
      isFalse,
    );
    expect(
      session.suppressesAutomaticCheck(
        reason: 'runtime_diagnostics_ready',
        physicalNetworkEpoch: 10,
      ),
      isFalse,
    );
  });

  test('keeps completed results and resumes only pending tags', () {
    final session = OfflineUrlTestSession(
      id: 'manual-1',
      fingerprint: 'config-a',
      physicalNetworkEpoch: 7,
      tags: {'a', 'b', 'c'},
    );
    expect(
      session.accept(
        tag: 'a',
        delayMillis: 53,
        available: true,
        logicalSessionId: 'manual-1',
        physicalNetworkEpoch: 7,
      ),
      isTrue,
    );
    expect(
      session.accept(
        tag: 'a',
        delayMillis: 55,
        available: true,
        logicalSessionId: 'manual-1',
        physicalNetworkEpoch: 7,
      ),
      isFalse,
    );
    session.pauseForVpn();
    expect(session.pendingTags, {'b', 'c'});
    expect(session.measurements['a']?.delayMillis, 53);
    expect(
      session.accept(
        tag: 'b',
        delayMillis: 44,
        available: true,
        logicalSessionId: 'manual-1',
        physicalNetworkEpoch: 7,
      ),
      isFalse,
    );
    expect(
      session.accept(
        tag: 'b',
        delayMillis: 61,
        available: true,
        logicalSessionId: 'manual-old',
        physicalNetworkEpoch: 7,
      ),
      isFalse,
    );
    session.resumeOnVpn();
    expect(
      session.accept(
        tag: 'b',
        delayMillis: 0,
        available: false,
        logicalSessionId: 'manual-1',
        physicalNetworkEpoch: 7,
      ),
      isTrue,
    );
    expect(session.completed, 2);
    expect(session.working, 1);
  });

  test('physical handover invalidates, virtual TUN does not', () {
    final session = OfflineUrlTestSession(
      id: 'manual-2',
      fingerprint: 'config-a',
      physicalNetworkEpoch: 3,
      tags: {'a', 'b'},
    );
    session.accept(
      tag: 'a',
      delayMillis: 20,
      available: true,
      logicalSessionId: 'manual-2',
      physicalNetworkEpoch: 3,
    );
    expect(
      session.reconcile(fingerprint: 'config-a', physicalNetworkEpoch: 3),
      isTrue,
    );
    expect(session.pendingTags, {'b'});
    expect(
      session.reconcile(fingerprint: 'config-a', physicalNetworkEpoch: 4),
      isFalse,
    );
    expect(session.pendingTags, {'a', 'b'});
    expect(
      session.accept(
        tag: 'b',
        delayMillis: 30,
        available: true,
        logicalSessionId: 'manual-2',
        physicalNetworkEpoch: 3,
      ),
      isFalse,
    );
  });

  test('5000 tags use only pending set without a duplicate queue', () {
    final tags = {for (var i = 0; i < 5000; i++) 'node-$i'};
    final session = OfflineUrlTestSession(
      id: 'manual-3',
      fingerprint: 'config-a',
      physicalNetworkEpoch: 1,
      tags: tags,
    );
    for (var i = 0; i < 200; i++) {
      session.accept(
        tag: 'node-$i',
        delayMillis: 20,
        available: true,
        logicalSessionId: 'manual-3',
        physicalNetworkEpoch: 1,
      );
    }
    session.pauseForVpn();
    expect(session.pendingTags.length, 4800);
    expect(session.total, 5000);
  });

  test(
    'configuration change ends the old queue without losing its evidence',
    () {
      final session = OfflineUrlTestSession(
        id: 'manual-4',
        fingerprint: 'old',
        physicalNetworkEpoch: 1,
        tags: {'a', 'b'},
      )..runOffline();
      session.accept(
        tag: 'a',
        delayMillis: 90,
        available: true,
        logicalSessionId: 'manual-4',
        physicalNetworkEpoch: 1,
      );
      expect(
        session.reconcile(fingerprint: 'new', physicalNetworkEpoch: 1),
        isFalse,
      );
      expect(session.phase, OfflineUrlTestPhase.failed);
      expect(session.measurements['a']?.delayMillis, 90);
      expect(
        session.accept(
          tag: 'b',
          delayMillis: 45,
          available: true,
          logicalSessionId: 'manual-4',
          physicalNetworkEpoch: 1,
        ),
        isFalse,
      );
    },
  );
}
