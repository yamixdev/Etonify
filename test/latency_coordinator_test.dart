import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/latency_coordinator.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';

const _testPolicy = LatencyUiPolicy(
  nativeCommandTimeout: Duration(milliseconds: 80),
  initialEventTimeout: Duration(milliseconds: 60),
  eventInactivityTimeout: Duration(milliseconds: 25),
  hardWatchdog: Duration(milliseconds: 500),
);

void main() {
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
      expect(requests.single.deadlineMillis, 33000);
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
      expect(boundedRequests.single.deadlineMillis, 120000);
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

    blocker.complete();
    await wait;
    expect(await active, isFalse);
    expect(waitFinished, isTrue);
  });
}

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
    uiPolicy: _testPolicy,
  );
}
