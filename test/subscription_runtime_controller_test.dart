import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/subscription_runtime_controller.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test(
    'resolveMetadata chooses requested active subscription and preferred tag',
    () {
      final controller = SubscriptionRuntimeController();
      final resolved = controller.resolveMetadata(
        metadataSubscriptions: [
          _subscription(id: 'sub-1', selectedProxyTag: 'vless-1'),
          _subscription(id: 'sub-2', selectedProxyTag: 'vless-2'),
        ],
        activeSubscriptionId: 'sub-2',
        selectedProxyTag: 'vless-3',
        preferSelectedProxyTag: true,
      );

      expect(resolved.normalized.activeSubscriptionId, 'sub-2');
      expect(resolved.normalized.selectedProxyTag, 'vless-3');
      expect(resolved.subscriptions.map((subscription) => subscription.id), [
        'sub-1',
        'sub-2',
      ]);
    },
  );

  test('normalize selection falls back to the only visible outbound', () {
    final selection = normalizeActiveSubscriptionSelection(
      _subscription(
        id: 'sub-1',
        selectedProxyTag: lowestProxyTag,
        outbounds: [_outbound('only')],
      ),
      selectedProxyTag: '',
      preferSelectedProxyTag: false,
    );

    expect(selection.activeSubscriptionId, 'sub-1');
    expect(selection.selectedProxyTag, 'only');
  });

  test(
    'normalize selection defaults an unused multi-server profile to lowest',
    () {
      final selection = normalizeActiveSubscriptionSelection(
        _subscription(
          id: 'sub-1',
          outbounds: [_outbound('amsterdam'), _outbound('france')],
        ),
        selectedProxyTag: '',
        preferSelectedProxyTag: false,
      );

      expect(selection.activeSubscriptionId, 'sub-1');
      expect(selection.selectedProxyTag, lowestProxyTag);
    },
  );

  test('metadata keeps the last server stored by each profile', () {
    final controller = SubscriptionRuntimeController();
    final resolved = controller.resolveMetadata(
      metadataSubscriptions: [
        _subscription(
          id: 'furkvpn',
          selectedProxyTag: 'amsterdam',
          outbounds: [_outbound('amsterdam'), _outbound('france')],
        ),
        _subscription(
          id: 'other',
          selectedProxyTag: 'france',
          outbounds: [_outbound('amsterdam'), _outbound('france')],
        ),
      ],
      activeSubscriptionId: 'furkvpn',
      selectedProxyTag: '',
      preferSelectedProxyTag: false,
    );

    expect(resolved.normalized.activeSubscriptionId, 'furkvpn');
    expect(resolved.normalized.selectedProxyTag, 'amsterdam');
  });

  test(
    'hydration keeps the preferred offline selection in the model and UI',
    () async {
      final controller = SubscriptionRuntimeController();
      final stored = _subscription(
        id: 'sub-1',
        selectedProxyTag: 'sweden',
        outbounds: [_outbound('sweden'), _outbound('france')],
      );

      final hydrated = await controller
          .hydrateActiveSubscriptionAndBuildProxyCache(
            metadata: stored.copyWith(outbounds: const []),
            selectedProxyTag: 'france',
            preferSelectedProxyTag: true,
            preserveRuntimeState: false,
            runtimeSnapshot: const SubscriptionRuntimeSnapshot(),
            payloadSnapshot: jsonEncode(stored.toPayloadMap()),
          );

      expect(hydrated.normalized.selectedProxyTag, 'france');
      expect(hydrated.subscription.selectedProxyTag, 'france');
      expect(hydrated.proxyCache.displayProxy?.tag, 'france');
    },
  );

  test(
    'hydration does not retain raw subscription content in runtime',
    () async {
      final controller = SubscriptionRuntimeController();
      final stored = _subscription(
        id: 'large-subscription',
        selectedProxyTag: 'vless-1',
        outbounds: [_outbound('vless-1')],
      ).copyWith(rawContent: 'vless://stored-secret@example.test:443');
      final metadata = Subscription.fromMetadataMap(stored.toMetadataMap());

      final hydrated = await controller
          .hydrateActiveSubscriptionAndBuildProxyCache(
            metadata: metadata,
            selectedProxyTag: 'vless-1',
            preferSelectedProxyTag: true,
            preserveRuntimeState: false,
            runtimeSnapshot: const SubscriptionRuntimeSnapshot(),
            payloadSnapshot: jsonEncode(stored.toPayloadMap()),
          );

      expect(hydrated.subscription.rawContent, isEmpty);
      expect(hydrated.subscription.hasRawPayload, isTrue);
      expect(hydrated.subscription.outbounds, hasLength(1));
      expect(
        hydrated.subscription.toMetadataMap(),
        containsPair('has_raw_payload', true),
      );
    },
  );

  test('runtime fingerprint is stable for equivalent config map order', () {
    final controller = SubscriptionRuntimeController();
    final left = _subscription(
      id: 'sub-1',
      outbounds: [
        _outbound(
          'vless-1',
          config: {
            'type': 'vless',
            'server': 'example.test',
            'server_port': 443,
          },
        ),
      ],
    );
    final right = _subscription(
      id: 'sub-1',
      outbounds: [
        _outbound(
          'vless-1',
          config: {
            'server_port': 443,
            'server': 'example.test',
            'type': 'vless',
          },
        ),
      ],
    );

    expect(
      controller.subscriptionRuntimeFingerprint(left),
      controller.subscriptionRuntimeFingerprint(right),
    );
  });

  test('auto refresh failure applies backoff and then can be cleared', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1_000_000);
    final controller = SubscriptionRuntimeController(now: () => now);
    final subscription = _subscription(
      id: 'sub-1',
      lastUpdated: 0,
      autoRefreshMinutes: 1,
    );

    expect(controller.dueAutoRefreshSubscriptions([subscription]), [
      subscription,
    ]);

    final backoff = controller.recordAutoRefreshFailure(subscription.id);

    expect(backoff.failures, 1);
    expect(backoff.backoffMinutes, 15);
    expect(controller.dueAutoRefreshSubscriptions([subscription]), isEmpty);
    expect(
      controller.nextAutoRefreshDelay([subscription]),
      const Duration(minutes: 15),
    );

    controller.clearAutoRefreshFailure(subscription.id);

    expect(controller.dueAutoRefreshSubscriptions([subscription]), [
      subscription,
    ]);
    expect(
      controller.nextAutoRefreshDelay([subscription]),
      const Duration(seconds: 30),
    );
  });
}

Subscription _subscription({
  required String id,
  String selectedProxyTag = '',
  int lastUpdated = 0,
  int autoRefreshMinutes = 360,
  List<Outbound>? outbounds,
}) {
  return Subscription(
    id: id,
    name: id,
    url: 'https://example.test/$id',
    selectedProxyTag: selectedProxyTag,
    lastUpdated: lastUpdated,
    autoRefreshMinutes: autoRefreshMinutes,
    outbounds:
        outbounds ??
        [_outbound(selectedProxyTag.isEmpty ? 'vless-1' : selectedProxyTag)],
  );
}

Outbound _outbound(String tag, {Map<String, dynamic>? config}) {
  return Outbound(
    tag: tag,
    name: tag,
    config:
        config ??
        {'type': 'vless', 'server': '$tag.example.test', 'server_port': 443},
  );
}
