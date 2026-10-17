import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/proxy_selection_controller.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test(
    'returning to A during pending B is a user switch not a start guard',
    () {
      final controller = ProxySelectionController();
      addTearDown(controller.dispose);
      controller.beginRuntimeSelection(
        tag: 'b',
        previousTag: 'a',
        onTimeout: (_) {},
      );
      controller.beginRuntimeSelection(
        tag: 'a',
        previousTag: 'a',
        onTimeout: (_) {},
      );
      expect(controller.pendingRuntimeSelectionIsStartGuard, isFalse);
      controller.guardCurrentSelectionForRuntime(
        tag: 'a',
        previousTag: 'a',
        onTimeout: (_) {},
      );
      expect(controller.pendingRuntimeSelectionIsStartGuard, isTrue);
    },
  );
  test('root confirmation preserves automatic group instead of its leaf', () {
    expect(
      ProxySelectionController.rootSelectionFromSnapshot({
        'runtimeGeneration': 7,
        'selectedOutbounds': {'select': 'lowest', 'lowest': 'leaf-b'},
      }, runtimeGeneration: 7),
      'lowest',
    );
  });
  test('root confirmation rejects stale runtime and missing root', () {
    expect(
      ProxySelectionController.rootSelectionFromSnapshot({
        'runtimeGeneration': 6,
        'selectedOutbounds': {'select': 'leaf-b'},
      }, runtimeGeneration: 7),
      isNull,
    );
    expect(
      ProxySelectionController.rootSelectionFromSnapshot({
        'runtimeGeneration': 7,
        'selectedOutbounds': {'lowest': 'leaf-b'},
      }, runtimeGeneration: 7),
      isNull,
    );
  });
  test(
    'failed runtime switch reconciles to actual root instead of request',
    () {
      final controller = ProxySelectionController();
      addTearDown(controller.dispose);
      final generation = controller.beginRuntimeSelection(
        tag: 'leaf-b',
        previousTag: 'leaf-a',
        onTimeout: (_) {},
      );
      expect(
        controller.resolveRuntimeSelection(
          generation: generation,
          actualTag: 'leaf-a',
        ),
        isTrue,
      );
      expect(controller.confirmedRuntimeTag, 'leaf-a');
      expect(controller.runtimeSelectionUnconfirmed, isFalse);
      expect(controller.hasPendingRuntimeSelection, isFalse);
    },
  );

  test('missing root confirmation stays explicitly unconfirmed', () {
    final controller = ProxySelectionController();
    addTearDown(controller.dispose);
    final generation = controller.beginRuntimeSelection(
      tag: 'leaf-b',
      previousTag: 'leaf-a',
      onTimeout: (_) {},
    );
    controller.resolveRuntimeSelection(generation: generation, actualTag: null);
    expect(controller.confirmedRuntimeTag, isNull);
    expect(controller.runtimeSelectionUnconfirmed, isTrue);
    expect(controller.hasPendingRuntimeSelection, isFalse);
    controller.beginLocalSelection();
    expect(controller.runtimeSelectionUnconfirmed, isFalse);
  });

  test('late B resolution cannot clear or overwrite newer C selection', () {
    final controller = ProxySelectionController();
    addTearDown(controller.dispose);
    final older = controller.beginRuntimeSelection(
      tag: 'leaf-b',
      previousTag: 'leaf-a',
      onTimeout: (_) {},
    );
    final latest = controller.beginRuntimeSelection(
      tag: 'leaf-c',
      previousTag: 'leaf-a',
      onTimeout: (_) {},
    );
    expect(
      controller.resolveRuntimeSelection(
        generation: older,
        actualTag: 'leaf-b',
      ),
      isFalse,
    );
    expect(controller.pendingRuntimeSelectTag, 'leaf-c');
    controller.resolveRuntimeSelection(generation: latest, actualTag: 'auto');
    expect(controller.confirmedRuntimeTag, 'auto');
  });

  test('valid selection accepts proxy groups and proxy chains', () {
    final controller = ProxySelectionController();
    addTearDown(controller.dispose);

    const subscription = Subscription(
      id: 'sub-1',
      name: 'Subscription',
      url: 'https://example.test/sub',
      outbounds: [
        Outbound(
          tag: 'leaf-1',
          name: 'Leaf 1',
          config: {'type': 'vless', 'tag': 'leaf-1'},
        ),
        Outbound(
          tag: 'leaf-2',
          name: 'Leaf 2',
          config: {'type': 'vless', 'tag': 'leaf-2'},
        ),
      ],
      groups: [
        SubscriptionGroup(
          tag: 'group-auto',
          name: 'Auto group',
          outboundTags: ['leaf-1', 'leaf-2'],
        ),
      ],
      proxyChains: [
        SubscriptionProxyChain(
          tag: 'chain-exit',
          name: 'Chain',
          targetTag: 'leaf-1',
          detourTag: 'leaf-2',
        ),
      ],
    );

    expect(
      controller.validSelectedProxyTagForSubscription(
        subscription,
        'group-auto',
      ),
      'group-auto',
    );
    expect(
      controller.validSelectedProxyTagForSubscription(
        subscription,
        'chain-exit',
      ),
      'chain-exit',
    );
  });

  test('unused multi-server profile defaults to lowest', () {
    final controller = ProxySelectionController();
    addTearDown(controller.dispose);

    const subscription = Subscription(
      id: 'sub-1',
      name: 'Subscription',
      url: 'https://example.test/sub',
      outbounds: [
        Outbound(
          tag: 'amsterdam',
          name: 'Amsterdam',
          config: {'type': 'vless', 'tag': 'amsterdam'},
        ),
        Outbound(
          tag: 'france',
          name: 'France',
          config: {'type': 'vless', 'tag': 'france'},
        ),
      ],
    );

    expect(
      controller.validSelectedProxyTagForSubscription(subscription, ''),
      lowestProxyTag,
    );
  });

  test('legacy automatic selections normalize to lowest', () {
    final controller = ProxySelectionController();
    addTearDown(controller.dispose);

    const subscription = Subscription(
      id: 'sub-1',
      name: 'Subscription',
      url: 'https://example.test/sub',
      outbounds: [
        Outbound(
          tag: 'amsterdam',
          name: 'Amsterdam',
          config: {'type': 'vless', 'tag': 'amsterdam'},
        ),
        Outbound(
          tag: 'france',
          name: 'France',
          config: {'type': 'vless', 'tag': 'france'},
        ),
      ],
    );

    for (final legacyTag in const <String>[
      mixedProxyTag,
      lowestOpenProxyTag,
      lowestFreeProxyTag,
    ]) {
      expect(
        controller.validSelectedProxyTagForSubscription(
          subscription,
          legacyTag,
        ),
        lowestProxyTag,
      );
    }
  });

  test(
    'local selection clears pending runtime selection and cancels timeout',
    () async {
      final controller = ProxySelectionController();
      addTearDown(controller.dispose);
      ProxySelectionTimeout? timeout;

      final runtimeGeneration = controller.beginRuntimeSelection(
        tag: 'leaf-1',
        previousTag: 'leaf-0',
        confirmationTimeout: Duration.zero,
        onTimeout: (value) => timeout = value,
      );
      expect(controller.pendingRuntimeSelectTag, 'leaf-1');

      final localGeneration = controller.beginLocalSelection();
      expect(localGeneration, greaterThan(runtimeGeneration));
      expect(controller.pendingRuntimeSelectTag, isNull);

      await Future<void>.delayed(Duration.zero);
      expect(timeout, isNull);
    },
  );

  test('runtime selection timeout reports current pending tag', () async {
    final controller = ProxySelectionController();
    addTearDown(controller.dispose);
    ProxySelectionTimeout? timeout;

    final generation = controller.beginRuntimeSelection(
      tag: 'leaf-1',
      previousTag: 'leaf-0',
      confirmationTimeout: Duration.zero,
      onTimeout: (value) => timeout = value,
    );

    await Future<void>.delayed(Duration.zero);
    expect(timeout, isNotNull);
    expect(timeout!.generation, generation);
    expect(timeout!.tag, 'leaf-1');
    expect(timeout!.previousTag, 'leaf-0');
  });

  test('clear runtime selection ignores stale generation', () {
    final controller = ProxySelectionController();
    addTearDown(controller.dispose);

    final generation = controller.beginRuntimeSelection(
      tag: 'leaf-1',
      previousTag: 'leaf-0',
      onTimeout: (_) {},
    );

    expect(
      controller.clearRuntimeSelection(generation: generation + 1),
      isFalse,
    );
    expect(controller.pendingRuntimeSelectTag, 'leaf-1');
    expect(controller.clearRuntimeSelection(generation: generation), isTrue);
    expect(controller.pendingRuntimeSelectTag, isNull);
  });

  test('persistence writes are serialized in selection order', () async {
    final controller = ProxySelectionController();
    addTearDown(controller.dispose);
    final writes = <String>[];
    final firstGate = Completer<void>();

    final firstGeneration = controller.beginLocalSelection();
    final first = controller.enqueuePersistence(
      generation: firstGeneration,
      action: () async {
        await firstGate.future;
        writes.add('france');
      },
    );
    await Future<void>.delayed(Duration.zero);

    final secondGeneration = controller.beginLocalSelection();
    final second = controller.enqueuePersistence(
      generation: secondGeneration,
      action: () async => writes.add('germany'),
    );

    firstGate.complete();
    await Future.wait<void>([first, second]);
    await controller.waitForPersistence();

    expect(writes, ['france', 'germany']);
  });

  test('stale queued write cannot overwrite latest selection', () async {
    final controller = ProxySelectionController();
    addTearDown(controller.dispose);
    final writes = <String>[];
    final queueGate = Completer<void>();

    final blockingGeneration = controller.beginLocalSelection();
    final blocking = controller.enqueuePersistence(
      generation: blockingGeneration,
      action: () => queueGate.future,
    );
    await Future<void>.delayed(Duration.zero);

    final staleGeneration = controller.beginLocalSelection();
    final stale = controller.enqueuePersistence(
      generation: staleGeneration,
      action: () async => writes.add('france'),
    );
    final latestGeneration = controller.beginLocalSelection();
    final latest = controller.enqueuePersistence(
      generation: latestGeneration,
      action: () async => writes.add('germany'),
    );

    queueGate.complete();
    await Future.wait<void>([blocking, stale, latest]);

    expect(writes, ['germany']);
  });

  test('runtime start guard preserves current selection generation', () {
    final controller = ProxySelectionController();
    addTearDown(controller.dispose);

    final generation = controller.beginLocalSelection();
    final guardedGeneration = controller.guardCurrentSelectionForRuntime(
      tag: 'france',
      previousTag: 'france',
      onTimeout: (_) {},
    );

    expect(guardedGeneration, generation);
    expect(controller.pendingRuntimeSelectTag, 'france');
  });

  test(
    'effective selected tag prefers explicit local choice when requested',
    () {
      expect(
        ProxySelectionController.effectiveSelectedProxyTag(
          metadataSelectedProxyTag: 'old-leaf',
          preferredSelectedProxyTag: 'new-leaf',
          preferPreferred: true,
        ),
        'new-leaf',
      );
      expect(
        ProxySelectionController.effectiveSelectedProxyTag(
          metadataSelectedProxyTag: 'old-leaf',
          preferredSelectedProxyTag: 'new-leaf',
          preferPreferred: false,
        ),
        'old-leaf',
      );
    },
  );

  test('runtime selection is used only for a stable connected core', () {
    final controller = ProxySelectionController();
    addTearDown(controller.dispose);

    expect(
      controller.runtimeSelectionUpdatesAllowed(
        connected: true,
        connectionStable: true,
        transitionInProgress: false,
      ),
      isTrue,
    );
    expect(
      controller.runtimeSelectionUpdatesAllowed(
        connected: true,
        connectionStable: false,
        transitionInProgress: false,
      ),
      isFalse,
    );
    expect(
      controller.runtimeSelectionUpdatesAllowed(
        connected: false,
        connectionStable: false,
        transitionInProgress: false,
      ),
      isFalse,
    );
  });
}
