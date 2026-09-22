import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/latency_coordinator.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';

const _testPolicy = LatencyUiPolicy(
  rpcAckTimeout: Duration(milliseconds: 80),
  initialEventTimeout: Duration(milliseconds: 60),
  eventInactivityTimeout: Duration(milliseconds: 25),
  hardWatchdog: Duration(milliseconds: 500),
);

void main() {
  test(
    'full session accepts partial results and executes targeted probe with force',
    () async {
      final calls = <LatencyTestRequest>[];
      final coordinator = _coordinator(
        runTest: (request) async {
          calls.add(request);
        },
        expectedTags: () => ['a', 'b', 'c'],
        capabilities: LibboxCapabilities.parseOrLegacy('''{
        "api_version": 2, "core_version": "1.14.0",
        "supports_targeted_url_test": true,
        "supports_url_test_queue_priority": true
      }'''),
      );
      addTearDown(coordinator.dispose);
      final full = coordinator.runFull(reason: 'test');
      await Future<void>.delayed(Duration.zero);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      coordinator.handleGroupEvent(tag: 'a', timeSeconds: now, available: true);
      expect(coordinator.isChecking('a'), isFalse);
      expect(coordinator.isChecking('b'), isTrue);
      expect(coordinator.isRunning, isTrue);
      await coordinator.runTarget(targetOutboundTag: 'c', reason: 'tap');
      expect(calls, hasLength(2));
      expect(calls.last.targetOutboundTag, 'c');
      expect(calls.last.force, isTrue);
      coordinator.handleGroupEvent(
        tag: 'c',
        timeSeconds: now,
        available: false,
      );
      expect(coordinator.isChecking('c'), isFalse);
      await coordinator.runTarget(targetOutboundTag: 'c', reason: 'repeat');
      expect(calls, hasLength(3));
      expect(calls.last.targetOutboundTag, 'c');
      coordinator.handleGroupEvent(tag: 'b', timeSeconds: now, available: true);
      expect(await full, isTrue);
    },
  );

  test(
    'unknown expected tags stop checking each proxy as its result arrives',
    () async {
      final coordinator = _coordinator(
        runTest: (_) async {},
        expectedTags: () => const <String>[],
      );
      addTearDown(coordinator.dispose);

      final result = coordinator.runFull(reason: 'manual');
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.isChecking('proxy-a'), isTrue);
      expect(coordinator.isChecking('proxy-b'), isTrue);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      expect(
        coordinator.handleGroupEvent(
          tag: 'proxy-a',
          timeSeconds: now,
          available: true,
        ),
        isTrue,
      );

      expect(coordinator.isChecking('proxy-a'), isFalse);
      expect(coordinator.isChecking('proxy-b'), isTrue);
      expect(coordinator.isRunning, isTrue);

      coordinator.cancel();
      expect(await result, isFalse);
    },
  );

  test(
    'parallel targeted check executes concurrently during full session without blocking',
    () async {
      final calls = <LatencyTestRequest>[];
      final coordinator = _coordinator(
        runTest: (request) async => calls.add(request),
        expectedTags: () => ['p-1', 'p-2', 'p-active'],
        capabilities: LibboxCapabilities.parseOrLegacy('''{
        "api_version": 2, "core_version": "1.14.0",
        "supports_targeted_url_test": true,
        "supports_url_test_queue_priority": true
      }'''),
      );
      addTearDown(coordinator.dispose);

      final fullFuture = coordinator.runFull(reason: 'test_all');
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.isRunning, isTrue);
      expect(coordinator.isChecking('p-active'), isTrue);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      coordinator.handleGroupEvent(
        tag: 'p-active',
        timeSeconds: now,
        available: true,
      );
      expect(coordinator.isChecking('p-active'), isFalse);
      expect(coordinator.isRunning, isTrue);

      final targetOk = await coordinator.runTarget(
        targetOutboundTag: 'p-active',
        reason: 'manual_active',
      );
      expect(targetOk, isTrue);
      expect(calls, hasLength(2));
      expect(calls.last.targetOutboundTag, 'p-active');
      expect(coordinator.isChecking('p-active'), isTrue);

      coordinator.handleGroupEvent(
        tag: 'p-active',
        timeSeconds: now + 1,
        available: true,
      );
      expect(coordinator.isChecking('p-active'), isFalse);
      expect(coordinator.isRunning, isTrue);

      coordinator.handleGroupEvent(
        tag: 'p-1',
        timeSeconds: now + 1,
        available: true,
      );
      coordinator.handleGroupEvent(
        tag: 'p-2',
        timeSeconds: now + 1,
        available: true,
      );
      expect(await fullFuture, isTrue);
      expect(coordinator.isRunning, isFalse);
    },
  );

  test('unrelated group events cannot complete a targeted session', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final coordinator = _coordinator(
      runTest: (_) async {},
      expectedTags: () => const ['target'],
      capabilities: LibboxCapabilities.parseOrLegacy('''{
        "api_version": 2, "core_version": "1.14.0",
        "supports_targeted_url_test": true
      }'''),
    );
    addTearDown(coordinator.dispose);

    final result = coordinator.runTarget(
      targetOutboundTag: 'target',
      reason: 'test',
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      coordinator.handleGroupEvent(
        tag: 'unrelated',
        timeSeconds: now + 1,
        available: true,
      ),
      isFalse,
    );
    expect(coordinator.isRunning, isTrue);

    coordinator.handleGroupEvent(
      tag: 'target',
      timeSeconds: now + 1,
      available: true,
    );
    expect(await result, isTrue);
  });

  test('parallel target captures its own latest event baseline', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var baseline = <String, int>{'target': now};
    final coordinator = _coordinator(
      runTest: (_) async {},
      expectedTags: () => const ['target', 'other'],
      eventBaselineTimes: () => baseline,
      capabilities: LibboxCapabilities.parseOrLegacy('''{
        "api_version": 2, "core_version": "1.14.0",
        "supports_targeted_url_test": true,
        "supports_url_test_queue_priority": true
      }'''),
    );
    addTearDown(coordinator.dispose);

    unawaited(coordinator.runFull(reason: 'all'));
    await Future<void>.delayed(Duration.zero);
    baseline = <String, int>{'target': now + 5};
    expect(
      await coordinator.runTarget(
        targetOutboundTag: 'target',
        reason: 'manual',
      ),
      isTrue,
    );

    expect(
      coordinator.handleGroupEvent(
        tag: 'target',
        timeSeconds: now + 1,
        available: true,
      ),
      isFalse,
    );
    expect(coordinator.isChecking('target'), isTrue);
    expect(
      coordinator.handleGroupEvent(
        tag: 'target',
        timeSeconds: now + 6,
        available: true,
      ),
      isTrue,
    );
    expect(coordinator.isChecking('target'), isFalse);
  });
  testWidgets('missing expected results release the session before watchdog', (
    tester,
  ) async {
    final coordinator = _coordinator(
      runTest: (_) async {},
      expectedTags: () => ['never-reached'],
      outboundCount: () => 900,
      timeoutSeconds: () => 1,
      uiPolicy: const LatencyUiPolicy(hardWatchdog: Duration(seconds: 125)),
    );
    addTearDown(coordinator.dispose);
    final result = coordinator.runFull(reason: 'no events');
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(coordinator.isChecking('never-reached'), isTrue);
    await tester.pump(const Duration(seconds: 15));
    expect(coordinator.isRunning, isFalse);
    expect(await result, isFalse);
    expect(coordinator.isChecking('never-reached'), isFalse);
  });

  test(
    'manual session event run releases when the core stays silent',
    () async {
      final coordinator = _coordinator(
        runTest: (_) async {},
        expectedTags: () => const ['a', 'b'],
        capabilities: _v3Capabilities,
        uiPolicy: const LatencyUiPolicy(
          rpcAckTimeout: Duration(milliseconds: 20),
          initialEventTimeout: Duration(milliseconds: 20),
          eventInactivityTimeout: Duration(milliseconds: 20),
          hardWatchdog: Duration(milliseconds: 60),
        ),
      );
      addTearDown(coordinator.dispose);

      // The core acknowledges the URLTest and then emits nothing, for example
      // because the service reloaded mid-test. Without a watchdog the session
      // would report isRunning forever and block every automatic check.
      final result = coordinator.runFull(reason: 'manual');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(coordinator.isRunning, isFalse);
      expect(await result, isFalse);
    },
  );

  test(
    '900 queued proxies keep checking across gaps between batches',
    () async {
      final tags = List.generate(900, (index) => 'proxy-$index');
      final coordinator = _coordinator(
        runTest: (_) async {},
        expectedTags: () => tags,
        outboundCount: () => tags.length,
      );
      addTearDown(coordinator.dispose);
      final result = coordinator.runFull(reason: 'large subscription');
      expect(tags.every(coordinator.isChecking), isTrue);
      expect(coordinator.isChecking('excluded-proxy'), isFalse);

      // The queue must outlive both the first-event and inactivity heuristics.
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(coordinator.isChecking(tags.last), isTrue);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      coordinator.handleGroupEvent(
        tag: tags.first,
        timeSeconds: now,
        available: true,
      );
      coordinator.handleGroupEvent(
        tag: tags[1],
        timeSeconds: now,
        available: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(coordinator.isRunning, isTrue);
      expect(coordinator.isChecking(tags.first), isFalse);
      expect(coordinator.isChecking(tags[1]), isFalse);
      expect(coordinator.isChecking(tags.last), isTrue);
      coordinator.cancel();
      expect(await result, isFalse);
      expect(tags.any(coordinator.isChecking), isFalse);
    },
  );

  test(
    'deadline releases untested queue without fabricating success',
    () async {
      final coordinator = _coordinator(
        runTest: (_) async {},
        expectedTags: () => ['never-reached'],
      );
      addTearDown(coordinator.dispose);
      expect(await coordinator.runFull(reason: 'deadline'), isFalse);
      expect(coordinator.isChecking('never-reached'), isFalse);
      expect(coordinator.isRunning, isFalse);
    },
  );

  test('bundled core capabilities do not advertise unsupported controls', () {
    const capabilities = LibboxCapabilities.bundledLegacy;

    expect(capabilities.supportsTargetedUrlTest, isFalse);
    expect(capabilities.supportsUrlTestTimeout, isFalse);
    expect(capabilities.supportsUrlTestConcurrency, isFalse);
    expect(capabilities.supportsUrlTestDeadline, isFalse);
    expect(capabilities.supportsUrlTestForce, isFalse);
    expect(
      capabilities.urlTestCompletionModel,
      UrlTestCompletionModel.groupEvents,
    );
  });

  test('targeted session checks only the selected concrete outbound', () async {
    final requests = <LatencyTestRequest>[];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final coordinator = _coordinator(
      runTest: (request) async => requests.add(request),
      capabilities: LibboxCapabilities.parseOrLegacy(
        '{"api_version":1,"supports_targeted_url_test":true}',
      ),
    );
    addTearDown(coordinator.dispose);

    final result = coordinator.runTarget(
      targetOutboundTag: 'proxy-2',
      reason: 'home',
    );
    await Future<void>.delayed(Duration.zero);

    expect(requests, hasLength(1));
    expect(requests.single.groupTag, 'select');
    expect(requests.single.targetOutboundTag, 'proxy-2');
    expect(requests.single.priorityOutboundTag, 'proxy-2');
    expect(requests.single.concurrency, 1);
    expect(coordinator.kind, LatencySessionKind.targeted);
    expect(coordinator.isChecking('proxy-2'), isTrue);
    expect(coordinator.isChecking('proxy-1'), isFalse);
    expect(
      coordinator.handleGroupEvent(
        tag: 'proxy-2',
        timeSeconds: now,
        available: true,
      ),
      isTrue,
    );
    expect(await result, isTrue);
  });

  test(
    'manual checks use configured and core-bounded URLTest limits',
    () async {
      final requests = <LatencyTestRequest>[];
      final coordinator = _coordinator(
        runTest: (request) async => requests.add(request),
        outboundCount: () => 10,
        timeoutSeconds: () => 7,
        concurrency: () => 3,
      );
      addTearDown(coordinator.dispose);

      final result = coordinator.runFull(reason: 'manual');
      await Future<void>.delayed(Duration.zero);

      expect(requests, hasLength(1));
      expect(requests.single.timeoutMillis, 7000);
      expect(requests.single.concurrency, 3);
      // 4 batches * 7000ms + 10000ms headroom = 38000ms
      expect(requests.single.deadlineMillis, 38000);
      coordinator.cancel();
      expect(await result, isFalse);

      final boundedRequests = <LatencyTestRequest>[];
      final boundedCoordinator = _coordinator(
        runTest: (request) async => boundedRequests.add(request),
        outboundCount: () => 1000,
        timeoutSeconds: () => 90,
        concurrency: () => 99,
      );
      addTearDown(boundedCoordinator.dispose);

      final boundedResult = boundedCoordinator.runFull(reason: 'bounded');
      await Future<void>.delayed(Duration.zero);

      expect(boundedRequests.single.timeoutMillis, 30000);
      expect(boundedRequests.single.concurrency, 16);
      expect(boundedRequests.single.deadlineMillis, 1800000);
      boundedCoordinator.cancel();
      expect(await boundedResult, isFalse);
    },
  );

  test(
    'RPC acceptance without fresh events does not fabricate success',
    () async {
      var completed = false;
      final coordinator = _coordinator(runTest: (_) async {});
      addTearDown(coordinator.dispose);

      final result = coordinator.runFull(reason: 'manual').then((value) {
        completed = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.isRunning, isTrue);
      expect(coordinator.phase, LatencySessionPhase.collectingEvents);
      expect(completed, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(completed, isFalse);
      expect(await result, isFalse);
      expect(coordinator.isRunning, isFalse);
    },
  );

  test('only fresh per-tag events extend a running session', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final coordinator = _coordinator(
      runTest: (_) async {},
      eventBaselineTimes: () => <String, int>{
        'proxy-1': now,
        'proxy-2': now - 5,
      },
    );
    addTearDown(coordinator.dispose);

    final result = coordinator.runFull(reason: 'manual');
    await Future<void>.delayed(Duration.zero);

    expect(
      coordinator.handleGroupEvent(
        tag: 'proxy-1',
        timeSeconds: now,
        available: true,
      ),
      isFalse,
    );
    expect(
      coordinator.handleGroupEvent(
        tag: 'proxy-2',
        timeSeconds: now,
        available: true,
      ),
      isTrue,
    );
    expect(
      coordinator.handleGroupEvent(
        tag: 'proxy-2',
        timeSeconds: now,
        available: true,
      ),
      isFalse,
    );
    expect(await result, isTrue);
  });

  test('all expected terminal results settle immediately', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final coordinator = _coordinator(
      runTest: (_) async {},
      expectedTags: () => const <String>{'proxy-1', 'proxy-2'},
    );
    addTearDown(coordinator.dispose);

    var completed = false;
    final result = coordinator.runFull(reason: 'manual').then((value) {
      completed = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.isChecking('proxy-1'), isTrue);
    expect(coordinator.isChecking('proxy-2'), isTrue);
    expect(coordinator.isChecking('not-expected'), isFalse);
    expect(coordinator.shouldIgnoreGroupResult('proxy-1', now - 1), isTrue);
    expect(
      coordinator.shouldIgnoreGroupResult('not-expected', now - 1),
      isFalse,
    );

    expect(
      coordinator.handleGroupEvent(
        tag: 'proxy-1',
        timeSeconds: now,
        available: true,
      ),
      isTrue,
    );
    expect(coordinator.isChecking('proxy-1'), isFalse);
    expect(coordinator.isChecking('proxy-2'), isTrue);
    expect(coordinator.shouldIgnoreGroupResult('proxy-1', now), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(completed, isFalse);
    expect(
      coordinator.handleGroupEvent(
        tag: 'proxy-2',
        timeSeconds: now,
        available: true,
      ),
      isTrue,
    );
    expect(await result, isTrue);
    expect(completed, isTrue);
    expect(coordinator.isChecking('proxy-2'), isFalse);
  });

  test(
    'a second request is not queued while a session is collecting',
    () async {
      final coordinator = _coordinator(runTest: (_) async {});
      addTearDown(coordinator.dispose);

      final first = coordinator.runFull(reason: 'manual');
      await Future<void>.delayed(Duration.zero);
      expect(await coordinator.runFull(reason: 'manual_repeat'), isFalse);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(
        coordinator.handleGroupEvent(
          tag: 'proxy-1',
          timeSeconds: now,
          available: true,
        ),
        isTrue,
      );
      expect(await first, isTrue);
    },
  );

  test(
    'native command timeout ends UI without starting another command',
    () async {
      final blocker = Completer<void>();
      var calls = 0;
      final coordinator = _coordinator(
        runTest: (_) {
          calls++;
          return blocker.future;
        },
      );
      addTearDown(coordinator.dispose);

      expect(await coordinator.runFull(reason: 'manual'), isFalse);
      expect(coordinator.isRunning, isFalse);
      expect(
        await coordinator.runFull(reason: 'repeat_after_ui_timeout'),
        isFalse,
      );
      expect(calls, 1);

      blocker.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('unavailable terminal results never fabricate success', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final coordinator = _coordinator(
      runTest: (_) async {},
      expectedTags: () => const <String>{'proxy-1', 'proxy-2'},
    );
    addTearDown(coordinator.dispose);

    final result = coordinator.runFull(reason: 'manual');
    await Future<void>.delayed(Duration.zero);

    coordinator.handleGroupEvent(
      tag: 'proxy-1',
      timeSeconds: now,
      available: false,
    );
    coordinator.handleGroupEvent(
      tag: 'proxy-2',
      timeSeconds: now,
      available: false,
    );

    expect(await result, isFalse);
  });

  test('a mixed terminal batch succeeds when one proxy has a delay', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final coordinator = _coordinator(
      runTest: (_) async {},
      expectedTags: () => const <String>{'proxy-1', 'proxy-2'},
    );
    addTearDown(coordinator.dispose);

    final result = coordinator.runFull(reason: 'manual');
    await Future<void>.delayed(Duration.zero);

    coordinator.handleGroupEvent(
      tag: 'proxy-1',
      timeSeconds: now,
      available: false,
    );
    coordinator.handleGroupEvent(
      tag: 'proxy-2',
      timeSeconds: now,
      available: true,
    );

    expect(await result, isTrue);
  });

  test('does not start tests in background or while disconnected', () async {
    var connected = false;
    var foreground = true;
    var calls = 0;
    final coordinator = _coordinator(
      runTest: (_) async => calls++,
      isConnected: () => connected,
      isForeground: () => foreground,
    );
    addTearDown(coordinator.dispose);

    expect(await coordinator.runFull(reason: 'disconnected'), isFalse);
    connected = true;
    foreground = false;
    expect(await coordinator.runFull(reason: 'background'), isFalse);
    expect(calls, 0);
  });

  test('late RPC completion from an old runtime is discarded', () async {
    final blocker = Completer<void>();
    var operationGeneration = 1;
    final coordinator = _coordinator(
      runTest: (_) => blocker.future,
      operationGeneration: () => operationGeneration,
    );
    addTearDown(coordinator.dispose);

    final result = coordinator.runFull(reason: 'old_runtime');
    await Future<void>.delayed(Duration.zero);
    operationGeneration++;
    blocker.complete();

    expect(await result, isFalse);
    expect(coordinator.isRunning, isFalse);
  });

  test('manual cancellation waits for the native command lane', () async {
    final blocker = Completer<void>();
    final coordinator = _coordinator(runTest: (_) => blocker.future);
    addTearDown(coordinator.dispose);

    final active = coordinator.runFull(reason: 'manual');
    await Future<void>.delayed(Duration.zero);
    var waitFinished = false;
    final wait = coordinator.cancelAndWait().then((_) => waitFinished = true);
    await Future<void>.delayed(Duration.zero);
    expect(waitFinished, isFalse);
    expect(coordinator.canStartSession, isFalse);

    blocker.complete();
    await wait;
    expect(await active, isFalse);
    expect(waitFinished, isTrue);
    expect(coordinator.canStartSession, isTrue);
  });

  test(
    'full check uses the root selector for complete subscription coverage',
    () async {
      final requests = <LatencyTestRequest>[];
      final coordinator = _coordinator(
        runTest: (request) async => requests.add(request),
      );
      addTearDown(coordinator.dispose);

      unawaited(coordinator.runFull(reason: 'test'));
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(1));
      expect(requests.single.groupTag, 'select');
    },
  );

  test(
    'URLTest v3 publishes progressive results and settles on status',
    () async {
      final requests = <LatencyTestRequest>[];
      final coordinator = _coordinator(
        runTest: (request) async => requests.add(request),
        expectedTags: () => const ['a', 'b'],
        capabilities: _v3Capabilities,
      );
      addTearDown(coordinator.dispose);

      final completed = coordinator.runFull(reason: 'manual');
      await Future<void>.delayed(Duration.zero);
      expect(requests.single.mode, 'manual');
      expect(requests.single.deadlineMillis, 0);
      expect(coordinator.isChecking('a'), isTrue);

      expect(
        coordinator.handleCoreSession(
          sessionId: 4,
          groupTag: 'select',
          targetTag: '',
          mode: 'manual',
          state: 'running',
          terminalReason: '',
          available: 0,
        ),
        isTrue,
      );
      expect(
        coordinator.handleCoreResult(
          tag: 'a',
          sessionId: 3,
          revision: 9,
          available: true,
        ),
        isFalse,
      );
      expect(
        coordinator.handleCoreResult(
          tag: 'a',
          sessionId: 4,
          revision: 10,
          available: true,
        ),
        isTrue,
      );
      expect(coordinator.isChecking('a'), isFalse);
      expect(coordinator.isRunning, isTrue);
      // A duplicate revision cannot revive or overwrite the row.
      expect(
        coordinator.handleCoreResult(
          tag: 'a',
          sessionId: 4,
          revision: 10,
          available: false,
        ),
        isFalse,
      );
      coordinator.handleCoreSession(
        sessionId: 4,
        groupTag: 'select',
        targetTag: '',
        mode: 'manual',
        state: 'completed',
        terminalReason: 'completed',
        available: 1,
      );
      expect(await completed, isTrue);
    },
  );

  test('URLTest v3 background work is bounded and cancellable', () async {
    final requests = <LatencyTestRequest>[];
    final cancellations = <String>[];
    final coordinator = LatencyCoordinator(
      runTest: (request) async => requests.add(request),
      cancelTest: (group, target) async => cancellations.add('$group|$target'),
      isConnected: () => true,
      isForeground: () => true,
      activeOutboundTag: () => 'a',
      testUrl: () => '',
      outboundCount: () => 5000,
      timeoutSeconds: () => 15,
      concurrency: () => 10,
      capabilities: _v3Capabilities,
      onSessionChanged: (_, _, _) {},
      uiPolicy: _testPolicy,
    );
    addTearDown(coordinator.dispose);

    final completed = coordinator.runFull(
      reason: 'startup',
      mode: 'background',
    );
    await Future<void>.delayed(Duration.zero);
    expect(requests.single.mode, 'background');
    expect(requests.single.concurrency, 10);
    expect(requests.single.deadlineMillis, 1800000);
    coordinator.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(cancellations, ['select|']);
    expect(await completed, isFalse);
  });

  test(
    'background deadline dynamically scales for large subscription',
    () async {
      final requests = <LatencyTestRequest>[];
      final coordinator = LatencyCoordinator(
        runTest: (request) async => requests.add(request),
        isConnected: () => true,
        isForeground: () => true,
        activeOutboundTag: () => 'a',
        testUrl: () => '',
        outboundCount: () => 215,
        timeoutSeconds: () => 6,
        concurrency: () => 10,
        capabilities: _v3Capabilities,
        onSessionChanged: (_, _, _) {},
        uiPolicy: _testPolicy,
      );
      addTearDown(coordinator.dispose);

      final completed = coordinator.runFull(
        reason: 'startup',
        mode: 'background',
      );
      await Future<void>.delayed(Duration.zero);
      expect(requests.single.mode, 'background');
      expect(requests.single.concurrency, 10);
      // 22 batches * 6000ms + 22000ms headroom = 154000ms (> 120s old cap)
      expect(requests.single.deadlineMillis, 154000);
      coordinator.cancel();
      await completed;
    },
  );

  test(
    'background session watchdog never outlives its configured hard limit',
    () async {
      const policy = LatencyUiPolicy(
        rpcAckTimeout: Duration(milliseconds: 80),
        initialEventTimeout: Duration(milliseconds: 60),
        eventInactivityTimeout: Duration(milliseconds: 25),
        hardWatchdog: Duration(milliseconds: 50),
      );
      final coordinator = LatencyCoordinator(
        runTest: (_) async {},
        isConnected: () => true,
        isForeground: () => true,
        activeOutboundTag: () => 'a',
        testUrl: () => '',
        outboundCount: () => 1,
        timeoutSeconds: () => 1,
        concurrency: () => 1,
        capabilities: _v3Capabilities,
        onSessionChanged: (_, _, _) {},
        uiPolicy: policy,
      );
      addTearDown(coordinator.dispose);

      final completed = coordinator.runFull(
        reason: 'startup',
        mode: 'background',
      );

      expect(
        await completed.timeout(const Duration(milliseconds: 500)),
        isFalse,
      );
      expect(coordinator.isRunning, isFalse);
    },
  );

  test(
    'runFull defaults to exhaustive manual mode and supports automatic session cancellation',
    () async {
      final requests = <LatencyTestRequest>[];
      final cancellations = <String>[];
      final coordinator = LatencyCoordinator(
        runTest: (request) async => requests.add(request),
        cancelTest: (group, target) async =>
            cancellations.add('$group|$target'),
        isConnected: () => true,
        isForeground: () => true,
        activeOutboundTag: () => 'a',
        testUrl: () => '',
        outboundCount: () => 100,
        timeoutSeconds: () => 5,
        concurrency: () => 10,
        capabilities: _v3Capabilities,
        onSessionChanged: (_, _, _) {},
        uiPolicy: _testPolicy,
      );
      addTearDown(coordinator.dispose);

      final autoCompleted = coordinator.runFull(reason: 'connect');
      await Future<void>.delayed(Duration.zero);
      expect(requests.single.mode, 'manual');
      expect(requests.single.deadlineMillis, 0);
      expect(coordinator.isCurrentSessionAutomatic, isTrue);
      expect(coordinator.isCurrentSessionManual, isFalse);

      coordinator.cancelAutomaticSession();
      expect(await autoCompleted, isFalse);
      expect(coordinator.isRunning, isFalse);

      requests.clear();
      final manualCompleted = coordinator.runFull(reason: 'manual_button');
      await Future<void>.delayed(Duration.zero);
      expect(requests.single.mode, 'manual');
      expect(coordinator.isCurrentSessionManual, isTrue);
      expect(coordinator.isCurrentSessionAutomatic, isFalse);

      // cancelAutomaticSession should NOT cancel manual session
      coordinator.cancelAutomaticSession();
      expect(coordinator.isRunning, isTrue);
      coordinator.cancel();
      expect(await manualCompleted, isFalse);
    },
  );

  test(
    'full session continues while forced target completes independently with a distinct sessionId',
    () async {
      final requests = <LatencyTestRequest>[];
      final coordinator = _coordinator(
        runTest: (request) async => requests.add(request),
        expectedTags: () => const ['server-1', 'server-2'],
        capabilities: _v3Capabilities,
      );
      addTearDown(coordinator.dispose);

      final fullCompleted = coordinator.runFull(reason: 'manual');
      await Future<void>.delayed(Duration.zero);
      expect(requests.first.mode, 'manual');
      expect(coordinator.isChecking('server-1'), isTrue);
      expect(coordinator.isChecking('server-2'), isTrue);

      expect(
        coordinator.handleCoreSession(
          sessionId: 15,
          groupTag: 'select',
          targetTag: '',
          mode: 'manual',
          state: 'running',
          terminalReason: '',
          available: 0,
        ),
        isTrue,
      );

      final targetResult = coordinator.runTarget(
        targetOutboundTag: 'server-1',
        reason: 'manual_tap',
      );
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(2));
      expect(requests.last.mode, 'targeted');
      expect(requests.last.targetOutboundTag, 'server-1');
      expect(requests.last.force, isTrue);
      expect(coordinator.isChecking('server-1'), isTrue);

      expect(
        coordinator.handleCoreResult(
          tag: 'server-1',
          sessionId: 16,
          revision: 101,
          available: true,
        ),
        isTrue,
      );

      expect(coordinator.isChecking('server-1'), isFalse);
      expect(coordinator.isChecking('server-2'), isTrue);
      expect(coordinator.isRunning, isTrue);
      expect(await targetResult, isTrue);

      expect(
        coordinator.handleCoreResult(
          tag: 'server-2',
          sessionId: 15,
          revision: 102,
          available: true,
        ),
        isTrue,
      );
      expect(coordinator.isChecking('server-2'), isFalse);

      coordinator.handleCoreSession(
        sessionId: 15,
        groupTag: 'select',
        targetTag: '',
        mode: 'manual',
        state: 'completed',
        terminalReason: 'completed',
        available: 2,
      );
      expect(await fullCompleted, isTrue);
      expect(coordinator.isRunning, isFalse);
    },
  );

  test('v3 results that arrive before the running event still count', () async {
    final coordinator = _coordinator(
      runTest: (_) async {},
      expectedTags: () => const ['a', 'b'],
      capabilities: _v3Capabilities,
    );
    addTearDown(coordinator.dispose);

    final completed = coordinator.runFull(reason: 'manual');
    await Future<void>.delayed(Duration.zero);

    // The core can finish a probe before the session status event reaches
    // the client. Dropping it made a finished sweep look unfinished.
    expect(
      coordinator.handleCoreResult(
        tag: 'a',
        sessionId: 7,
        revision: 1,
        available: true,
      ),
      isTrue,
    );
    expect(coordinator.isChecking('a'), isFalse);
    expect(coordinator.isChecking('b'), isTrue);

    // A result from a different session is still rejected.
    expect(
      coordinator.handleCoreResult(
        tag: 'b',
        sessionId: 6,
        revision: 1,
        available: true,
      ),
      isFalse,
    );

    // The status event stays authoritative and re-pins the session.
    expect(
      coordinator.handleCoreSession(
        sessionId: 8,
        groupTag: 'select',
        targetTag: '',
        mode: 'manual',
        state: 'running',
        terminalReason: '',
        available: 0,
      ),
      isTrue,
    );
    expect(
      coordinator.handleCoreResult(
        tag: 'b',
        sessionId: 7,
        revision: 2,
        available: true,
      ),
      isFalse,
    );
    expect(
      coordinator.handleCoreResult(
        tag: 'b',
        sessionId: 8,
        revision: 2,
        available: true,
      ),
      isTrue,
    );
    coordinator.handleCoreSession(
      sessionId: 8,
      groupTag: 'select',
      targetTag: '',
      mode: 'manual',
      state: 'completed',
      terminalReason: 'completed',
      available: 2,
    );
    expect(await completed, isTrue);
  });

  test(
    'settling reports measurements the core took but events missed',
    () async {
      AppLogStore.clear();
      addTearDown(AppLogStore.clear);
      final startedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final coreMeasurements = <String, int>{};
      final coordinator = _coordinator(
        runTest: (_) async {},
        expectedTags: () => const ['a', 'b', 'c'],
        eventBaselineTimes: () => Map<String, int>.from(coreMeasurements),
        capabilities: _v3Capabilities,
      );
      addTearDown(coordinator.dispose);

      final completed = coordinator.runFull(reason: 'manual');
      await Future<void>.delayed(Duration.zero);

      expect(
        coordinator.handleCoreResult(
          tag: 'a',
          sessionId: 1,
          revision: 1,
          available: true,
        ),
        isTrue,
      );
      // Two further probes finished inside the core, and only one of them is
      // newer than the measurement this session started from.
      coreMeasurements
        ..['a'] = startedAt + 5
        ..['b'] = startedAt + 5
        ..['c'] = startedAt - 60;
      coordinator.handleCoreSession(
        sessionId: 1,
        groupTag: 'select',
        targetTag: '',
        mode: 'manual',
        state: 'completed',
        terminalReason: 'completed',
        available: 1,
      );
      expect(await completed, isTrue);

      final settled = AppLogStore.dump()
          .split('\n')
          .lastWhere((line) => line.contains('latency session settled'));
      expect(settled, contains('expected=3'));
      expect(settled, contains('received=2'));
    },
  );
}

final _v3Capabilities = LibboxCapabilities.parseOrLegacy('''
{
  "api_version": 3,
  "core_version": "1.15.0-alpha.3-etonify",
  "supports_targeted_url_test": true,
  "supports_group_url_test_sessions": true,
  "supports_structured_probe_errors": true,
  "supports_url_test_timeout": true,
  "supports_url_test_concurrency": true,
  "supports_url_test_deadline": true,
  "supports_url_test_force": true,
  "supports_url_test_failover": true,
  "supports_url_test_delta_stream": true,
  "supports_url_test_session_status": true,
  "supports_url_test_result_revision": true,
  "supports_url_test_network_generation": true,
  "supports_url_test_exhaustive": true,
  "supports_url_test_cancel": true,
  "url_test_completion_model": "session_events"
}
''');

LatencyCoordinator _coordinator({
  required LatencyTestRunner runTest,
  LatencyBoolReader? isConnected,
  LatencyBoolReader? isForeground,
  LatencyIntReader? outboundCount,
  LatencyIntReader? timeoutSeconds,
  LatencyIntReader? concurrency,
  LatencyEventTimesReader? eventBaselineTimes,
  LatencyIntReader? operationGeneration,
  LatencyExpectedTagsReader? expectedTags,
  LibboxCapabilities capabilities = LibboxCapabilities.bundledLegacy,
  LatencyUiPolicy uiPolicy = _testPolicy,
}) {
  return LatencyCoordinator(
    runTest: runTest,
    isConnected: isConnected ?? () => true,
    isForeground: isForeground ?? () => true,
    activeOutboundTag: () => 'proxy-1',
    testUrl: () => 'https://example.com/generate_204',
    outboundCount: outboundCount ?? () => 12,
    timeoutSeconds: timeoutSeconds ?? () => 15,
    concurrency: concurrency ?? () => 8,
    eventBaselineTimes: eventBaselineTimes,
    expectedTags: expectedTags,
    operationGeneration: operationGeneration,
    capabilities: capabilities,
    onSessionChanged: (_, _, _) {},
    uiPolicy: uiPolicy,
  );
}
