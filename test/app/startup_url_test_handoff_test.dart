import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/startup_url_test_handoff.dart';
import 'package:meow_client/app/proxy_selection_controller.dart';
import 'package:meow_client/app/proxy_runtime_controller.dart';
import 'package:meow_client/app/latency_coordinator.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test(
    'fresh native borrow repairs lowest before a delayed groups snapshot',
    () async {
      final runtime = ProxyRuntimeController();
      addTearDown(runtime.dispose);
      runtime.runtimeLowestSelections['lowest'] = 'A';
      runtime.unavailableLatencyTags.add('B');
      runtime.latencyErrors['B'] = 'old timeout';
      final coordinator = LatencyCoordinator(
        runTest: (_) async {},
        isConnected: () => true,
        isForeground: () => true,
        activeOutboundTag: () =>
            runtime.runtimeLowestSelections['lowest'] ?? '',
        testUrl: () => 'https://example.test/generate_204',
        outboundCount: () => 2,
        timeoutSeconds: () => 15,
        concurrency: () => 2,
        capabilities: LibboxCapabilities.parseOrLegacy(
          '{"api_version":3,"core_version":"1.15.0-etonify",'
          '"supports_url_test_delta_stream":true,'
          '"supports_url_test_session_status":true,'
          '"supports_url_test_result_revision":true,'
          '"url_test_completion_model":"session_events"}',
        ),
        onSessionChanged: (_, _, _) {},
      );
      addTearDown(coordinator.dispose);
      final reply = <String, dynamic>{
        'valid': true,
        'runtimeGeneration': 7,
        'networkGeneration': 3,
        'selectedOutbounds': {'select': 'lowest', 'lowest': 'B'},
        'borrowedTag': 'B',
        'delayMillis': 26,
        'measuredAtMillis': 5000,
        'revision': 18,
        'sessionId': 9,
      };
      void replay({bool reconciles = false}) {
        if (!coordinator.handleCoreResult(
          tag: 'B',
          sessionId: 9,
          revision: 18,
          available: true,
          borrowedStartupResult: reconciles,
        )) {
          return;
        }
        runtime.applyUrlTestResult(
          tag: 'B',
          measuredAtMillis: 5000,
          delay: 26,
          status: 'available',
          error: '',
          revision: 18,
        );
      }

      var prepares = 0;
      final dispatched = <List<String>>[];
      Future<bool> run() => runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['A', 'B'],
        prepare: (_) async {
          prepares++;
          return reply;
        },
        isCurrent: () => true,
        acceptNativeSelection: (_) {
          if (runtime.runtimeLowestSelections['lowest'] == 'B') return true;
          replay(reconciles: true);
          runtime.applyGroupUpdates(
            ProxyRuntimeGroupUpdateInput(
              rawGroups: [
                {'tag': 'lowest', 'selected': 'B'},
              ],
              activeSubscription: const Subscription(
                id: 'sub',
                name: 'Subscription',
                url: 'https://example.test/sub',
              ),
              selectedProxyTag: 'lowest',
              pendingRuntimeSelectTag: null,
              currentResolvedActiveOutboundTag: 'A',
              activeOutboundTags: {'A', 'B'},
              latencySessionRunning: false,
              shouldIgnoreLatencyResult: (_, _) => false,
              proxyCacheContainsTag: (_) => true,
              visibleGroupProxyCacheMissingChild: (_, _) => false,
            ),
          );
          return false;
        },
        acceptBorrowed: (_) => replay(),
        runRemaining: (tags, _) async {
          dispatched.add(tags);
          return true;
        },
      );
      expect(await run(), isFalse);
      expect(runtime.runtimeLowestSelections['lowest'], 'B');
      expect(runtime.unavailableLatencyTags, isNot(contains('B')));
      expect(runtime.runtimeLatencies['B'], 26);
      expect(await run(), isTrue);
      expect(prepares, 2);
      expect(dispatched, [
        ['A'],
      ]);
    },
  );

  test(
    'native selection is fenced before borrowed replay or dispatch',
    () async {
      var dartLeaf = 'A';
      var replayed = false;
      var dispatched = false;
      final success = await runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['A', 'B'],
        prepare: (_) async => {
          'valid': true,
          'runtimeGeneration': 7,
          'networkGeneration': 3,
          'selectedOutbounds': {'select': 'B'},
          'borrowedTag': 'B',
          'delayMillis': 26,
          'measuredAtMillis': 5000,
          'revision': 18,
          'sessionId': 9,
        },
        isCurrent: () => true,
        acceptNativeSelection: (reply) {
          final nativeLeaf = (reply['selectedOutbounds'] as Map)['select'];
          if (dartLeaf == nativeLeaf) return true;
          dartLeaf = nativeLeaf as String;
          return false;
        },
        acceptBorrowed: (_) => replayed = true,
        runRemaining: (_, _) async {
          dispatched = true;
          return true;
        },
      );
      expect(dartLeaf, 'B');
      expect(success, isFalse);
      expect(replayed, isFalse);
      expect(dispatched, isFalse);
    },
  );

  test(
    'an ordinary dispatch error does not retry uncertain native work',
    () async {
      var prepares = 0;
      final result = runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['leaf'],
        prepare: (_) async {
          prepares++;
          return {
            'valid': true,
            'runtimeGeneration': 7,
            'networkGeneration': 3,
            'borrowedTag': '',
            'startupLeaseToken': 41,
          };
        },
        isCurrent: () => true,
        runRemaining: (_, _) async => throw StateError('bridge disconnected'),
      );
      expect(await result, isFalse);
      expect(prepares, 1);
    },
  );
  test(
    'pending native leaf is excluded without replaying a fabricated result',
    () async {
      var applied = 0;
      List<String>? probes;
      final success = await runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['leaf', 'other'],
        prepare: (_) async => {
          'valid': true,
          'runtimeGeneration': 7,
          'networkGeneration': 3,
          'borrowedTag': 'leaf',
          'delayMillis': 26,
          'measuredAtMillis': 0,
          'revision': 0,
          'sessionId': 0,
        },
        isCurrent: () => true,
        acceptBorrowed: (_) => applied++,
        runRemaining: (tags, _) async {
          probes = tags;
          return false;
        },
      );
      expect(applied, 0);
      expect(probes, ['other']);
      expect(success, isFalse);
    },
  );

  test(
    'a real unavailable borrowed delta is replayed without another leaf probe',
    () async {
      Map<String, dynamic>? applied;
      var probes = 0;
      final success = await runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['leaf'],
        prepare: (_) async => {
          'valid': true,
          'runtimeGeneration': 7,
          'networkGeneration': 3,
          'borrowedTag': 'leaf',
          'delayMillis': null,
          'measuredAtMillis': 5000,
          'revision': 18,
          'sessionId': 9,
          'status': 'unavailable',
          'error': 'timeout',
        },
        isCurrent: () => true,
        acceptBorrowed: (result) => applied = result,
        runRemaining: (_, _) async {
          probes++;
          return true;
        },
      );
      expect(applied!['status'], 'unavailable');
      expect(applied!['error'], 'timeout');
      expect(applied!['delayMillis'], isNull);
      expect(probes, 0);
      expect(success, isFalse);
    },
  );

  test(
    'an invalid native ownership fence neither replays nor probes',
    () async {
      var actions = 0;
      final success = await runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['leaf'],
        prepare: (_) async => {
          'valid': false,
          'runtimeGeneration': 7,
          'networkGeneration': 3,
          'borrowedTag': 'leaf',
          'delayMillis': 26,
          'measuredAtMillis': 5000,
          'revision': 18,
          'sessionId': 9,
        },
        isCurrent: () => true,
        acceptBorrowed: (_) => actions++,
        runRemaining: (_, _) async {
          actions++;
          return true;
        },
      );
      expect(actions, 0);
      expect(success, isFalse);
    },
  );

  test(
    'an expired dispatch retries original coverage once with a new token',
    () async {
      final coverage = <List<String>>[];
      final tokens = <int>[];
      final dispatched = <List<String>>[];
      final success = await runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['leaf', 'other', 'leaf'],
        prepare: (tags) async {
          coverage.add(List.of(tags));
          return {
            'valid': true,
            'runtimeGeneration': 7,
            'networkGeneration': 3,
            'borrowedTag': '',
            'startupLeaseToken': coverage.length == 1 ? 41 : 42,
          };
        },
        isCurrent: () => true,
        runRemaining: (tags, token) async {
          tokens.add(token);
          dispatched.add(tags);
          if (tokens.length == 1) throw const StartupUrlTestLeaseExpired();
          return true;
        },
      );
      expect(success, isTrue);
      expect(coverage, [
        ['leaf', 'other'],
        ['leaf', 'other'],
      ]);
      expect(dispatched, [
        ['leaf', 'other'],
        ['leaf', 'other'],
      ]);
      expect(tokens, [41, 42]);
    },
  );

  test(
    'a second expired dispatch does not create a third reservation',
    () async {
      var prepares = 0;
      final success = await runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['leaf'],
        prepare: (_) async {
          prepares++;
          return {
            'valid': true,
            'runtimeGeneration': 7,
            'networkGeneration': 3,
            'borrowedTag': '',
            'startupLeaseToken': prepares,
          };
        },
        isCurrent: () => true,
        runRemaining: (_, _) async => throw const StartupUrlTestLeaseExpired(),
      );
      expect(prepares, 2);
      expect(success, isFalse);
    },
  );

  test(
    'selection ABA while preparing invalidates the original lease',
    () async {
      final selection = ProxySelectionController();
      addTearDown(selection.dispose);
      final generation = selection.generation;
      var tag = 'leaf';
      var actions = 0;
      final response = Completer<Map<String, dynamic>>();
      final result = runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['leaf'],
        prepare: (_) => response.future,
        isCurrent: () =>
            selection.isCurrentGeneration(generation) && tag == 'leaf',
        acceptBorrowed: (_) => actions++,
        runRemaining: (_, _) async {
          actions++;
          return true;
        },
      );
      selection.beginLocalSelection();
      tag = 'other';
      selection.beginLocalSelection();
      tag = 'leaf';
      response.complete({
        'valid': true,
        'runtimeGeneration': 7,
        'networkGeneration': 3,
        'borrowedTag': 'leaf',
        'delayMillis': 26,
        'measuredAtMillis': 5000,
        'revision': 18,
        'sessionId': 9,
      });
      expect(await result, isFalse);
      expect(actions, 0);
    },
  );
  test(
    'a borrowed result is applied before the remaining sweep when its original stream was missed',
    () async {
      final order = <String>[];
      Map<String, dynamic>? applied;
      await runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['leaf', 'other'],
        prepare: (_) async => {
          'valid': true,
          'runtimeGeneration': 7,
          'networkGeneration': 3,
          'borrowedTag': 'leaf',
          'delayMillis': 26,
          'measuredAtMillis': 5000,
          'revision': 18,
          'sessionId': 9,
        },
        isCurrent: () => true,
        acceptBorrowed: (result) {
          applied = result;
          order.add('applied');
        },
        runRemaining: (_, _) async {
          order.add('probe');
          return true;
        },
      );
      expect(order, ['applied', 'probe']);
      expect(applied!['delayMillis'], 26);
      expect(applied!['revision'], 18);
      expect(applied!['sessionId'], 9);
    },
  );
  test('native-first full startup excludes only the measured leaf', () async {
    List<String>? probes;
    final success = await runStartupUrlTestHandoff(
      runtimeGeneration: 7,
      networkGeneration: 3,
      coveredTags: ['leaf', 'other'],
      prepare: (_) async => {
        'valid': true,
        'runtimeGeneration': 7,
        'networkGeneration': 3,
        'borrowedTag': 'leaf',
        'delayMillis': 26,
        'measuredAtMillis': 5000,
        'revision': 18,
        'sessionId': 9,
      },
      isCurrent: () => true,
      runRemaining: (tags, _) async {
        probes = tags;
        return true;
      },
    );
    expect(probes, ['other']);
    expect(success, isTrue);
  });

  test('native-first targeted startup borrows without another RPC', () async {
    var requests = 0;
    final success = await runStartupUrlTestHandoff(
      runtimeGeneration: 7,
      networkGeneration: 3,
      coveredTags: ['leaf'],
      prepare: (_) async => {
        'valid': true,
        'runtimeGeneration': 7,
        'networkGeneration': 3,
        'borrowedTag': 'leaf',
        'delayMillis': 26,
        'measuredAtMillis': 5000,
        'revision': 18,
        'sessionId': 9,
      },
      isCurrent: () => true,
      runRemaining: (_, _) async {
        requests++;
        return true;
      },
    );
    expect(requests, 0);
    expect(success, isTrue);
  });

  test('client-first startup retains its original coverage', () async {
    List<String>? probes;
    await runStartupUrlTestHandoff(
      runtimeGeneration: 7,
      networkGeneration: 3,
      coveredTags: ['leaf', 'other'],
      prepare: (_) async => {
        'valid': true,
        'runtimeGeneration': 7,
        'networkGeneration': 3,
        'borrowedTag': '',
      },
      isCurrent: () => true,
      runRemaining: (tags, _) async {
        probes = tags;
        return true;
      },
    );
    expect(probes, ['leaf', 'other']);
  });

  test(
    'stopped restarted or changed selection aborts the awaited startup',
    () async {
      final response = Completer<Map<String, dynamic>>();
      var current = true;
      var requests = 0;
      final result = runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['leaf'],
        prepare: (_) => response.future,
        isCurrent: () => current,
        runRemaining: (_, _) async {
          requests++;
          return true;
        },
      );
      current = false;
      response.complete({
        'runtimeGeneration': 7,
        'networkGeneration': 3,
        'borrowedTag': 'leaf',
        'delayMillis': 26,
      });
      expect(await result, isFalse);
      expect(requests, 0);
    },
  );

  test(
    'a result from another network is not treated as a startup answer',
    () async {
      var requests = 0;
      final result = await runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['leaf'],
        prepare: (_) async => {
          'valid': true,
          'runtimeGeneration': 7,
          'networkGeneration': 4,
          'borrowedTag': 'leaf',
          'delayMillis': 26,
        },
        isCurrent: () => true,
        runRemaining: (_, _) async {
          requests++;
          return true;
        },
      );
      expect(result, isFalse);
      expect(requests, 0);
    },
  );

  test(
    'native failed measurement is borrowed as unavailable not retried',
    () async {
      var requests = 0;
      final result = await runStartupUrlTestHandoff(
        runtimeGeneration: 7,
        networkGeneration: 3,
        coveredTags: ['leaf'],
        prepare: (_) async => {
          'valid': true,
          'runtimeGeneration': 7,
          'networkGeneration': 3,
          'borrowedTag': 'leaf',
          'delayMillis': null,
        },
        isCurrent: () => true,
        runRemaining: (_, _) async {
          requests++;
          return true;
        },
      );
      expect(result, isFalse);
      expect(requests, 0);
    },
  );
}
