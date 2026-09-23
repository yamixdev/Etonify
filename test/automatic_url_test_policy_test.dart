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
}
