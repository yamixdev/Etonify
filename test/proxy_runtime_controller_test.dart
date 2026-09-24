import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/proxy_runtime_controller.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test(
    'compact URLTest results use revisions instead of second timestamps',
    () {
      final controller = ProxyRuntimeController();
      addTearDown(controller.dispose);

      expect(
        controller.applyUrlTestResult(
          tag: 'vless-1',
          measuredAtMillis: 100100,
          delay: 80,
          status: 'available',
          error: '',
          revision: 1,
        ),
        {'vless-1'},
      );
      expect(
        controller.applyUrlTestResult(
          tag: 'vless-1',
          measuredAtMillis: 100900,
          delay: 55,
          status: 'available',
          error: '',
          revision: 2,
        ),
        {'vless-1'},
      );
      expect(controller.runtimeLatencies['vless-1'], 55);
      expect(controller.runtimeLatencyTimes['vless-1'], 100);
      expect(
        controller.applyUrlTestResult(
          tag: 'vless-1',
          measuredAtMillis: 100950,
          delay: 99,
          status: 'available',
          error: '',
          revision: 1,
        ),
        isEmpty,
      );
      expect(controller.runtimeLatencies['vless-1'], 55);
    },
  );

  test('a new native runtime keeps ping but accepts a fresh revision', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    controller.applyUrlTestResult(
      tag: 'vless-1',
      measuredAtMillis: 100100,
      delay: 80,
      status: 'available',
      error: '',
      revision: 200,
    );

    controller.beginNewNativeRuntime();
    expect(controller.runtimeLatencies['vless-1'], 80);
    expect(controller.runtimeLatencyTimes['vless-1'], 100);
    expect(controller.runtimeLatencyRevisions, isEmpty);

    expect(
      controller.applyUrlTestResult(
        tag: 'vless-1',
        measuredAtMillis: 100900,
        delay: 55,
        status: 'available',
        error: '',
        revision: 1,
      ),
      {'vless-1'},
    );
    expect(controller.runtimeLatencies['vless-1'], 55);
  });

  test(
    'network handover keeps stale display and accepts same-second result',
    () {
      final controller = ProxyRuntimeController();
      controller.runtimeLatencies.addAll({'vless-1': 50, 'vless-2': 70});
      controller.runtimeLatencyTimes.addAll({'vless-1': 100, 'vless-2': 100});
      controller.invalidateNetworkMeasurements(['vless-1', 'vless-2']);
      expect(controller.runtimeLatencies, {'vless-1': 50, 'vless-2': 70});
      expect(controller.runtimeLatencyTimes, isEmpty);
      expect(controller.isLatencyInvalidated('vless-2'), isTrue);
      void update(int time, int delay) => controller.applyGroupUpdates(
        _input(
          rawGroups: [
            {
              'tag': 'select',
              'items': [
                {
                  'tag': 'vless-2',
                  'delay': delay,
                  'time': time,
                  'status': 'available',
                },
              ],
            },
          ],
        ),
      );
      // The old seconds-based cutoff rejected this valid result when handover
      // and URLTest completed within the same wall-clock second.
      update(100, 180);
      expect(controller.runtimeLatencies['vless-2'], 180);
      expect(controller.isLatencyInvalidated('vless-2'), isFalse);
      expect(controller.isLatencyInvalidated('vless-1'), isTrue);
      expect(controller.lowestLatency, 180);
    },
  );

  test('progressive URLTest keeps and repairs the running minimum', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);

    void result(String tag, int delay, int revision, {bool failed = false}) {
      controller.applyUrlTestResult(
        tag: tag,
        measuredAtMillis: revision * 1000,
        delay: failed ? 0 : delay,
        status: failed ? 'unavailable' : 'available',
        error: failed ? 'timeout' : '',
        revision: revision,
      );
    }

    result('a', 80, 1);
    result('b', 50, 2);
    expect(controller.lowestLatency, 50);

    result('b', 120, 3);
    expect(controller.lowestLatency, 80);

    result('a', 0, 4, failed: true);
    expect(controller.lowestLatency, 120);
  });

  test('startup deadline marks only proxies without terminal telemetry', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    controller.runtimeLatencies['vless-fast'] = 73;
    controller.runtimeLatencies['vless-stale'] = 140;
    controller.unavailableLatencyTags.add('vless-failed');
    controller.latencyErrors['vless-failed'] = 'TLS handshake failed';
    controller.latencyFailureCounts['vless-failed'] = 2;
    controller.lowestLatency = 73;

    final affected = controller.markMissingStartupMeasurementsUnavailable([
      'vless-fast',
      'vless-missing',
      'vless-failed',
      'vless-missing',
      '',
    ]);

    expect(affected, {'vless-missing'});
    expect(controller.runtimeLatencies['vless-fast'], 73);
    expect(controller.runtimeLatencies['vless-stale'], 140);
    expect(controller.latencyErrors['vless-failed'], 'TLS handshake failed');
    expect(controller.latencyFailureCounts['vless-failed'], 2);
    expect(controller.unavailableLatencyTags, {
      'vless-failed',
      'vless-missing',
    });
    expect(
      controller.latencyErrors['vless-missing'],
      ProxyRuntimeController.startupUrlTestNoDataError,
    );
    expect(controller.latencyFailureCounts['vless-missing'], 1);
    expect(controller.lowestLatency, 73);
  });

  test('fresh URLTest recovers a proxy missing at startup', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    controller.markMissingStartupMeasurementsUnavailable(const ['vless-1']);

    final result = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'available',
                'delay': 91,
                'time': 100,
              },
            ],
          },
        ],
      ),
    );

    expect(result.changed, isTrue);
    expect(controller.runtimeLatencies['vless-1'], 91);
    expect(controller.unavailableLatencyTags, isNot(contains('vless-1')));
    expect(controller.latencyErrors['vless-1'], isNull);
    expect(controller.latencyFailureCounts['vless-1'], isNull);
    expect(controller.lowestLatency, 91);
  });

  test('URLTest group delay updates runtime latency', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);

    final result = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'selected': 'vless-1',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'available',
                'delay': 73,
                'time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              },
            ],
          },
        ],
        latencySessionRunning: true,
      ),
    );

    expect(result.changed, isTrue);
    expect(result.requiresRootRebuild, isFalse);
    expect(result.shouldRebuildProxyCache, isFalse);
    expect(result.affectedProxyTags, {'vless-1'});
    expect(result.latencyEvents, hasLength(1));
    expect(result.latencyEvents.single.tag, 'vless-1');
    expect(result.latencyEvents.single.available, isTrue);
    expect(result.latencyEvents.single.timeSeconds, greaterThan(0));
    expect(controller.runtimeLatencies['vless-1'], 73);
    expect(controller.lowestLatency, 73);
    expect(controller.unavailableLatencyTags, isNot(contains('vless-1')));
  });

  test('URLTest failures clear stale latency and mark proxy unavailable', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    controller.runtimeLatencies['vless-1'] = 82;

    final first = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'unavailable',
                'error': 'context deadline exceeded',
                'time': 1,
              },
            ],
          },
        ],
      ),
    );

    expect(first.changed, isTrue);
    expect(controller.unavailableLatencyTags, contains('vless-1'));
    expect(controller.runtimeLatencies['vless-1'], isNull);
    expect(controller.latencyErrors['vless-1'], 'context deadline exceeded');
    expect(controller.latencyFailureCounts['vless-1'], 1);

    final second = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'unavailable',
                'error': 'context deadline exceeded',
                'time': 2,
              },
            ],
          },
        ],
      ),
    );

    expect(second.changed, isTrue);
    expect(controller.unavailableLatencyTags, contains('vless-1'));
    expect(controller.runtimeLatencies['vless-1'], isNull);
    expect(controller.latencyErrors['vless-1'], 'context deadline exceeded');
    expect(controller.latencyFailureCounts['vless-1'], 2);
  });

  test('network handover invalidates only the active route when requested', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    controller.runtimeLatencies.addAll({'vless-active': 81, 'vless-other': 44});
    controller.runtimeLatencyTimes.addAll({
      'vless-active': 10,
      'vless-other': 10,
    });

    final changed = controller.invalidateNetworkMeasurements(const [
      'vless-active',
    ], preserveUnrelatedMeasurements: true);

    expect(changed, isTrue);
    expect(controller.runtimeLatencies['vless-active'], 81);
    expect(controller.runtimeLatencyTimes['vless-active'], isNull);
    expect(controller.isLatencyInvalidated('vless-active'), isTrue);
    expect(controller.runtimeLatencies['vless-other'], 44);
    expect(controller.isLatencyInvalidated('vless-other'), isFalse);
  });

  test('failed lowest endpoint is no longer presented as selected', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    controller.runtimeLowestSelections['lowest'] = 'vless-1';

    controller.applyGroupUpdates(
      _input(
        selectedProxyTag: 'lowest',
        rawGroups: [
          {
            'tag': 'lowest',
            'selected': 'vless-1',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'unavailable',
                'error': 'context deadline exceeded',
                'time': 1,
              },
            ],
          },
        ],
      ),
    );

    expect(controller.unavailableLatencyTags, contains('vless-1'));
    expect(controller.runtimeLowestSelections, isNot(contains('lowest')));
  });

  test('frozen transition keeps existing latency and ignores failures', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);

    controller.runtimeLatencies['vless-1'] = 73;
    controller.lowestLatency = 73;
    controller.beginTransition();

    final result = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'unavailable',
                'error': 'no available network interface',
                'time': 2,
              },
            ],
          },
        ],
      ),
    );

    expect(result.changed, isFalse);
    expect(controller.updatesFrozen, isTrue);
    expect(controller.runtimeLatencies['vless-1'], 73);
    expect(controller.lowestLatency, 73);
    expect(controller.unavailableLatencyTags, isEmpty);

    controller.endTransition();
    final next = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {'tag': 'vless-1', 'status': 'available', 'delay': 91, 'time': 3},
            ],
          },
        ],
      ),
    );

    expect(next.changed, isTrue);
    expect(controller.runtimeLatencies['vless-1'], 91);
    expect(controller.lowestLatency, 91);
  });

  test('session owner filters cached values before applying fresh result', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    controller.runtimeLatencies.addAll({'vless-1': 42, 'vless-2': 51});
    controller.runtimeLatencyTimes.addAll({'vless-1': 100, 'vless-2': 100});

    final cachedSnapshot = controller.applyGroupUpdates(
      _input(
        shouldIgnoreLatencyResult: (_, timeSeconds) => timeSeconds <= 100,
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'available',
                'delay': 42,
                'time': 100,
              },
            ],
          },
        ],
      ),
    );

    expect(cachedSnapshot.changed, isFalse);

    final freshSnapshot = controller.applyGroupUpdates(
      _input(
        shouldIgnoreLatencyResult: (_, timeSeconds) => timeSeconds <= 100,
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'available',
                'delay': 73,
                'time': 101,
              },
            ],
          },
        ],
      ),
    );

    expect(freshSnapshot.changed, isTrue);
    expect(controller.runtimeLatencies['vless-1'], 73);
    expect(controller.runtimeLatencies['vless-2'], 51);
    expect(controller.latencyErrors['vless-2'], isNull);
  });

  test('duplicate failure timestamp is applied only once', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    final snapshot = [
      {
        'tag': 'select',
        'items': [
          {
            'tag': 'vless-1',
            'status': 'unavailable',
            'error': 'timeout',
            'time': 50,
          },
        ],
      },
    ];

    final first = controller.applyGroupUpdates(_input(rawGroups: snapshot));
    final duplicate = controller.applyGroupUpdates(_input(rawGroups: snapshot));

    expect(first.changed, isTrue);
    expect(duplicate.changed, isFalse);
    expect(controller.latencyFailureCounts['vless-1'], 1);
  });

  test('older URLTest snapshots cannot overwrite a newer result', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);

    final newer = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'available',
                'delay': 73,
                'time': 20,
              },
            ],
          },
        ],
      ),
    );
    final older = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'available',
                'delay': 999,
                'time': 19,
              },
            ],
          },
        ],
      ),
    );

    expect(newer.changed, isTrue);
    expect(older.changed, isFalse);
    expect(controller.runtimeLatencies['vless-1'], 73);
    expect(controller.runtimeLatencyTimes['vless-1'], 20);
  });

  test('newest result wins for duplicate tags inside one snapshot', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);

    final result = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'available',
                'delay': 73,
                'time': 20,
              },
              {
                'tag': 'vless-1',
                'status': 'available',
                'delay': 999,
                'time': 19,
              },
            ],
          },
        ],
      ),
    );

    expect(result.changed, isTrue);
    expect(controller.runtimeLatencies['vless-1'], 73);
    expect(controller.runtimeLatencyTimes['vless-1'], 20);
  });

  test('partial snapshot preserves every unrelated latency collection', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    controller.runtimeLatencies.addAll({'vless-1': 42, 'vless-2': 51});
    controller.runtimeLatencyTimes.addAll({'vless-1': 100, 'vless-2': 90});
    controller.unavailableLatencyTags.add('vless-3');
    controller.invalidatedLatencyTags.add('vless-4');
    controller.latencyErrors['vless-3'] = 'old timeout';
    controller.latencyFailureCounts['vless-3'] = 2;

    final result = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'available',
                'delay': 73,
                'time': 101,
              },
            ],
          },
        ],
      ),
    );

    expect(result.changed, isTrue);
    expect(result.affectedProxyTags, {'vless-1'});
    expect(controller.runtimeLatencies, {'vless-1': 73, 'vless-2': 51});
    expect(controller.runtimeLatencyTimes, {'vless-1': 101, 'vless-2': 90});
    expect(controller.unavailableLatencyTags, {'vless-3'});
    expect(controller.invalidatedLatencyTags, {'vless-4'});
    expect(controller.latencyErrors, {'vless-3': 'old timeout'});
    expect(controller.latencyFailureCounts, {'vless-3': 2});
  });

  test('non-terminal group status does not mutate runtime latency state', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    controller.runtimeLatencies['vless-1'] = 73;
    controller.runtimeLatencyTimes['vless-1'] = 100;
    controller.lowestLatency = 73;

    final result = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {'tag': 'vless-1', 'status': 'checking', 'delay': 0, 'time': 101},
            ],
          },
        ],
      ),
    );

    expect(result, same(ProxyRuntimeGroupUpdateResult.noChanges));
    expect(controller.runtimeLatencies, {'vless-1': 73});
    expect(controller.runtimeLatencyTimes, {'vless-1': 100});
  });

  test('an error without an unavailable status is still a failed URLTest', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    controller.runtimeLatencies['vless-1'] = 73;

    controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {'tag': 'vless-1', 'error': 'TLS handshake failed', 'time': 30},
            ],
          },
        ],
      ),
    );

    expect(controller.runtimeLatencies['vless-1'], isNull);
    expect(controller.unavailableLatencyTags, contains('vless-1'));
    expect(controller.latencyErrors['vless-1'], 'TLS handshake failed');
  });

  test('reachable endpoint fallback does not override URLTest failure', () {
    expect(
      ProxyRuntimeController.effectiveLatencyUnavailable(
        urlTestUnavailable: true,
        endpointFallbackReachable: true,
      ),
      isTrue,
    );
    expect(
      ProxyRuntimeController.effectiveLatencyError(
        urlTestError: 'context deadline exceeded',
        endpointFallbackReachable: true,
      ),
      'context deadline exceeded',
    );
    expect(
      ProxyRuntimeController.effectiveLatencyUnavailable(
        urlTestUnavailable: true,
        endpointFallbackReachable: false,
      ),
      isTrue,
    );
  });

  test('runtime selector state never overwrites a manual proxy choice', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);

    final result = controller.applyGroupUpdates(
      _input(
        selectedProxyTag: 'vless-2',
        rawGroups: [
          {
            'tag': 'select',
            'selected': 'vless-1',
            'items': [
              {'tag': 'vless-1', 'status': 'available', 'delay': 73, 'time': 1},
            ],
          },
        ],
      ),
    );

    expect(result.changed, isTrue);
    expect(result.requiresRootRebuild, isFalse);
    expect(result.shouldClearRuntimeProxySelectionGuard, isFalse);
    expect(controller.runtimeLatencies['vless-1'], 73);
  });

  test('session activity without new telemetry does not rebuild UI', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);

    final result = controller.applyGroupUpdates(
      _input(
        latencySessionRunning: true,
        rawGroups: [
          {'tag': 'select', 'selected': 'vless-1', 'items': const <dynamic>[]},
        ],
      ),
    );

    expect(result.changed, isFalse);
    expect(result.requiresRootRebuild, isFalse);
  });

  test('runtime selector state cannot replace a manual proxy choice', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);

    final result = controller.applyGroupUpdates(
      _input(
        selectedProxyTag: 'vless-2',
        rawGroups: [
          {'tag': 'select', 'selected': 'vless-1', 'items': const <dynamic>[]},
        ],
      ),
    );

    expect(result, same(ProxyRuntimeGroupUpdateResult.noChanges));
  });

  test('matching runtime selector state confirms a manual proxy choice', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);

    final result = controller.applyGroupUpdates(
      _input(
        selectedProxyTag: 'france',
        pendingRuntimeSelectTag: 'france',
        rawGroups: [
          {'tag': 'select', 'selected': 'france', 'items': const <dynamic>[]},
        ],
      ),
    );

    expect(result.changed, isTrue);
    expect(result.shouldClearRuntimeProxySelectionGuard, isTrue);
    expect(result.requiresRootRebuild, isFalse);
  });

  test('stale runtime selection cannot replace pending startup choice', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);

    final result = controller.applyGroupUpdates(
      _input(
        selectedProxyTag: 'france',
        pendingRuntimeSelectTag: 'france',
        rawGroups: [
          {'tag': 'select', 'selected': 'sweden', 'items': const <dynamic>[]},
        ],
      ),
    );

    expect(result, same(ProxyRuntimeGroupUpdateResult.noChanges));
    expect(result.shouldClearRuntimeProxySelectionGuard, isFalse);
  });

  test('network change hides stale latency until fresh telemetry arrives', () {
    final controller = ProxyRuntimeController();
    addTearDown(controller.dispose);
    controller.runtimeLatencies['vless-1'] = 73;
    controller.runtimeLatencyTimes['vless-1'] = 100;
    controller.unavailableLatencyTags.add('vless-2');
    controller.latencyErrors['vless-2'] = 'old timeout';
    controller.latencyFailureCounts['vless-2'] = 2;
    controller.lowestLatency = 73;
    controller.runtimeLowestSelections['lowest'] = 'vless-1';
    controller.runtimeGroupSelections['group-1'] = 'vless-2';

    final changed = controller.invalidateNetworkMeasurements(const [
      'vless-1',
      'vless-2',
    ]);

    expect(changed, isTrue);
    expect(controller.runtimeLatencies, {'vless-1': 73});
    expect(controller.runtimeLatencyTimes, isEmpty);
    expect(controller.unavailableLatencyTags, isEmpty);
    expect(controller.latencyErrors, isEmpty);
    expect(controller.latencyFailureCounts, isEmpty);
    expect(controller.lowestLatency, isNull);
    expect(controller.invalidatedLatencyTags, {'vless-1', 'vless-2'});
    expect(controller.runtimeLowestSelections['lowest'], 'vless-1');
    expect(controller.runtimeGroupSelections['group-1'], 'vless-2');

    final fresh = controller.applyGroupUpdates(
      _input(
        rawGroups: [
          {
            'tag': 'select',
            'items': [
              {
                'tag': 'vless-1',
                'status': 'available',
                'delay': 91,
                'time': 100,
              },
            ],
          },
        ],
      ),
    );

    expect(fresh.changed, isTrue);
    expect(controller.runtimeLatencies['vless-1'], 91);
    expect(controller.invalidatedLatencyTags, {'vless-2'});
  });
}

ProxyRuntimeGroupUpdateInput _input({
  required List<dynamic> rawGroups,
  String selectedProxyTag = 'vless-1',
  String? pendingRuntimeSelectTag,
  bool latencySessionRunning = false,
  StaleLatencyResultFilter? shouldIgnoreLatencyResult,
}) {
  return ProxyRuntimeGroupUpdateInput(
    rawGroups: rawGroups,
    activeSubscription: const Subscription(
      id: 'sub-1',
      name: 'Subscription',
      url: 'https://example.test/sub',
      outbounds: [
        Outbound(
          tag: 'vless-1',
          name: 'VLESS 1',
          config: {
            'type': 'vless',
            'server': 'example.test',
            'server_port': 443,
          },
        ),
      ],
    ),
    selectedProxyTag: selectedProxyTag,
    pendingRuntimeSelectTag: pendingRuntimeSelectTag,
    currentResolvedActiveOutboundTag: 'vless-1',
    activeOutboundTags: const {'vless-1', 'vless-2'},
    latencySessionRunning: latencySessionRunning,
    shouldIgnoreLatencyResult: shouldIgnoreLatencyResult ?? (_, _) => false,
    proxyCacheContainsTag: (tag) => tag == 'vless-1',
    visibleGroupProxyCacheMissingChild: (_, _) => false,
  );
}
