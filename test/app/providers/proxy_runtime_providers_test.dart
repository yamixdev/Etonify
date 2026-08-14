import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/app/latency_coordinator.dart';
import 'package:meow_client/app/providers/proxy_runtime_providers.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';

void main() {
  test('latency session exposes one immutable operation snapshot', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(proxyLatencySessionProvider.notifier);
    notifier.update(
      running: true,
      kind: LatencySessionKind.targeted,
      targetTag: ' proxy-1 ',
    );

    final running = container.read(proxyLatencySessionProvider);
    expect(running.running, isTrue);
    expect(running.kind, LatencySessionKind.targeted);
    expect(running.targetTag, 'proxy-1');
    expect(running.generation, 1);

    notifier.update(
      running: true,
      kind: LatencySessionKind.targeted,
      targetTag: 'proxy-1',
    );
    expect(container.read(proxyLatencySessionProvider), same(running));

    notifier.update(running: false);
    final settled = container.read(proxyLatencySessionProvider);
    expect(settled.running, isFalse);
    expect(settled.kind, isNull);
    expect(settled.targetTag, isEmpty);
    expect(settled.generation, 2);
  });

  test('runtime visual store remains stable across point updates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final store = container.read(proxyRuntimeVisualStoreProvider);
    expect(container.read(proxyRuntimeVisualStoreProvider), same(store));

    const first = ProxyRuntimeVisualState(latency: 120);
    const updated = ProxyRuntimeVisualState(latency: 80);
    const second = ProxyRuntimeVisualState(latency: 240);
    store.replaceAll(const {'first': first, 'second': second});
    final secondListenable = store.listenableFor('second');

    store.updateTags(const {'first': updated});

    expect(store.valueFor('first'), updated);
    expect(secondListenable.value, second);
  });
}
