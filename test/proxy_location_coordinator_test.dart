import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/coordinators/proxy_location_coordinator.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

class _FakeSingboxRuntime extends Fake implements SingboxRuntime {
  _FakeSingboxRuntime(this._lookupHandler);

  final Future<Map<String, dynamic>> Function(String outboundTag)
  _lookupHandler;

  @override
  Future<Map<String, dynamic>> lookupOutboundExternalInfo({
    required String outboundTag,
  }) {
    return _lookupHandler(outboundTag);
  }
}

void main() {
  group('ResolvedExternalIpInfo', () {
    test('parses valid IP and 2-letter country code', () {
      final info = ResolvedExternalIpInfo.fromResponse({
        'ip': '1.2.3.4',
        'countryCode': 'de',
      }, normalizeCountryCode: ResolvedExternalIpInfo.normalizeCountryCode);

      expect(info, isNotNull);
      expect(info!.ip, '1.2.3.4');
      expect(info.countryCode, 'DE');
    });

    test('returns null when IP is missing or empty', () {
      final info = ResolvedExternalIpInfo.fromResponse({
        'countryCode': 'us',
      }, normalizeCountryCode: ResolvedExternalIpInfo.normalizeCountryCode);

      expect(info, isNull);
    });

    test('normalizes country codes to uppercase 2-letter codes', () {
      expect(ResolvedExternalIpInfo.normalizeCountryCode('ru'), 'RU');
      expect(ResolvedExternalIpInfo.normalizeCountryCode('USA'), '');
      expect(ResolvedExternalIpInfo.normalizeCountryCode(''), '');
      expect(ResolvedExternalIpInfo.normalizeCountryCode(null), '');
    });
  });

  group('LocationLookupSlot', () {
    test('releases only once', () {
      var releaseCount = 0;
      final slot = LocationLookupSlot(() => releaseCount++);

      slot.release();
      slot.release();

      expect(releaseCount, 1);
    });
  });

  group('ProxyLocationCoordinator', () {
    test(
      'queued lookup does not start after its row leaves the list',
      () async {
        final firstLookup = Completer<Map<String, dynamic>>();
        final requestedTags = <String>[];
        final runtime = _FakeSingboxRuntime((tag) {
          requestedTags.add(tag);
          return tag == 'first'
              ? firstLookup.future
              : Future.value({'ip': '2.2.2.2', 'countryCode': 'de'});
        });
        final coordinator = ProxyLocationCoordinator(
          runtime: runtime,
          getLocationLookupLimit: () => 5,
          getLocationLookupTimeoutSeconds: () => 5,
          getLocationLookupConcurrency: () => 1,
          isConnected: () => true,
          isForegroundLifecycleActive: () => true,
          isMarkAllServersRussia: () => false,
          isProxyPanelInteractionActive: () => false,
          getDiagnosticGeneration: () => 1,
          getActiveSubscription: () => null,
          getBestOutbounds: () => const [],
          hasResolvedExternalLocation: (_) => false,
          getEffectiveOutboundLatency: (_) => 100,
          onApplyResolvedInfos:
              ({required subscriptionId, required resolvedByTag}) async {},
        );

        final first = coordinator.fetchExternalIpInfo(outboundTag: 'first');
        var secondRowVisible = true;
        final second = coordinator.fetchExternalIpInfo(
          outboundTag: 'second',
          shouldStart: () => secondRowVisible,
        );
        secondRowVisible = false;
        firstLookup.complete({'ip': '1.1.1.1', 'countryCode': 'us'});

        expect((await first)?.ip, '1.1.1.1');
        expect(await second, isNull);
        expect(requestedTags, ['first']);
        coordinator.dispose();
      },
    );

    test(
      'fetches external IP info and deduplicates concurrent lookups',
      () async {
        var callCount = 0;
        final completer = Completer<Map<String, dynamic>>();

        final runtime = _FakeSingboxRuntime((tag) {
          callCount++;
          return completer.future;
        });

        final coordinator = ProxyLocationCoordinator(
          runtime: runtime,
          getLocationLookupLimit: () => 5,
          getLocationLookupTimeoutSeconds: () => 5,
          getLocationLookupConcurrency: () => 2,
          isConnected: () => true,
          isForegroundLifecycleActive: () => true,
          isMarkAllServersRussia: () => false,
          isProxyPanelInteractionActive: () => false,
          getDiagnosticGeneration: () => 1,
          getActiveSubscription: () => null,
          getBestOutbounds: () => const [],
          hasResolvedExternalLocation: (_) => false,
          getEffectiveOutboundLatency: (_) => 100,
          onApplyResolvedInfos:
              ({required subscriptionId, required resolvedByTag}) async {},
        );

        // Start two concurrent lookups for the same tag
        final future1 = coordinator.fetchExternalIpInfo(
          outboundTag: 'server-1',
          highPriority: true,
        );
        final future2 = coordinator.fetchExternalIpInfo(
          outboundTag: 'server-1',
          highPriority: true,
        );

        expect(callCount, 1);

        completer.complete({'ip': '5.6.7.8', 'countryCode': 'nl'});

        final result1 = await future1;
        final result2 = await future2;

        expect(result1?.ip, '5.6.7.8');
        expect(result1?.countryCode, 'NL');
        expect(result2?.ip, '5.6.7.8');
        expect(result2?.countryCode, 'NL');

        coordinator.dispose();
      },
    );

    test('respects concurrency limit and queues slots', () async {
      final completers = <String, Completer<Map<String, dynamic>>>{
        'tag-1': Completer<Map<String, dynamic>>(),
        'tag-2': Completer<Map<String, dynamic>>(),
      };

      final runtime = _FakeSingboxRuntime((tag) {
        return completers[tag]!.future;
      });

      final coordinator = ProxyLocationCoordinator(
        runtime: runtime,
        getLocationLookupLimit: () => 5,
        getLocationLookupTimeoutSeconds: () => 5,
        getLocationLookupConcurrency: () => 1, // Concurrency = 1
        isConnected: () => true,
        isForegroundLifecycleActive: () => true,
        isMarkAllServersRussia: () => false,
        isProxyPanelInteractionActive: () => false,
        getDiagnosticGeneration: () => 1,
        getActiveSubscription: () => null,
        getBestOutbounds: () => const [],
        hasResolvedExternalLocation: (_) => false,
        getEffectiveOutboundLatency: (_) => 100,
        onApplyResolvedInfos:
            ({required subscriptionId, required resolvedByTag}) async {},
      );

      // First call acquires the single slot
      final future1 = coordinator.fetchExternalIpInfo(outboundTag: 'tag-1');
      // Second call must wait for the slot
      final future2 = coordinator.fetchExternalIpInfo(outboundTag: 'tag-2');

      // Complete first
      completers['tag-1']!.complete({'ip': '1.1.1.1', 'countryCode': 'us'});
      final result1 = await future1;
      expect(result1?.ip, '1.1.1.1');

      // Now complete second
      completers['tag-2']!.complete({'ip': '2.2.2.2', 'countryCode': 'ca'});
      final result2 = await future2;
      expect(result2?.ip, '2.2.2.2');

      coordinator.dispose();
    });

    test('reset cancels queued lookups and resets state', () async {
      final completer = Completer<Map<String, dynamic>>();
      final runtime = _FakeSingboxRuntime((tag) => completer.future);

      final coordinator = ProxyLocationCoordinator(
        runtime: runtime,
        getLocationLookupLimit: () => 5,
        getLocationLookupTimeoutSeconds: () => 5,
        getLocationLookupConcurrency: () => 1,
        isConnected: () => true,
        isForegroundLifecycleActive: () => true,
        isMarkAllServersRussia: () => false,
        isProxyPanelInteractionActive: () => false,
        getDiagnosticGeneration: () => 1,
        getActiveSubscription: () => null,
        getBestOutbounds: () => const [],
        hasResolvedExternalLocation: (_) => false,
        getEffectiveOutboundLatency: (_) => 100,
        onApplyResolvedInfos:
            ({required subscriptionId, required resolvedByTag}) async {},
      );

      // Acquire slot
      final _ = coordinator.fetchExternalIpInfo(outboundTag: 'tag-1');
      // Queue second
      final future2 = coordinator.fetchExternalIpInfo(outboundTag: 'tag-2');

      coordinator.reset();

      final result2 = await future2;
      expect(result2, isNull);

      coordinator.dispose();
    });
  });

  test('visible location results are applied together', () async {
    final batches = <Map<String, ResolvedExternalIpInfo>>[];
    final batcher = ProxyLocationResultBatcher(
      delay: const Duration(milliseconds: 200),
      onApplyResolvedInfos:
          ({required subscriptionId, required resolvedByTag}) async {
            expect(subscriptionId, 'profile');
            batches.add(resolvedByTag);
          },
    );
    addTearDown(batcher.dispose);

    batcher.add(
      subscriptionId: 'profile',
      outboundTag: 'one',
      info: const ResolvedExternalIpInfo(ip: '1.1.1.1', countryCode: 'US'),
    );
    batcher.add(
      subscriptionId: 'profile',
      outboundTag: 'two',
      info: const ResolvedExternalIpInfo(ip: '2.2.2.2', countryCode: 'DE'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(batches, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 220));

    expect(batches, hasLength(1));
    expect(batches.single.keys, unorderedEquals(['one', 'two']));
  });
}
