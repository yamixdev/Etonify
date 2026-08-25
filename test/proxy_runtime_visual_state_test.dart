import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';

void main() {
  test(
    'visual store releases notifiers for proxies no longer in the profile',
    () {
      final store = ProxyRuntimeVisualStore();
      addTearDown(store.dispose);

      store.listenableFor('old-server');
      store.replaceAll(const {
        'old-server': ProxyRuntimeVisualState(latency: 120),
      });

      expect(store.retainedNotifierCount, 1);

      store.replaceAll(const {
        'new-server': ProxyRuntimeVisualState(latency: 80),
      });

      expect(store.retainedNotifierCount, 0);
      expect(store.valueFor('old-server'), isNull);
      expect(store.valueFor('new-server')?.latency, 80);
    },
  );

  test('visual store publishes the offline network state', () {
    final store = ProxyRuntimeVisualStore();
    addTearDown(store.dispose);

    final listenable = store.listenableFor('server');
    store.replaceAll(const {'server': ProxyRuntimeVisualState(latency: 120)});
    store.replaceAll(const {
      'server': ProxyRuntimeVisualState(latency: 120, networkUnavailable: true),
    });

    expect(listenable.value?.networkUnavailable, isTrue);
  });

  test('small visual updates do not force a global resort revision', () {
    final store = ProxyRuntimeVisualStore();
    addTearDown(store.dispose);
    final active = store.listenableFor('active');
    store.replaceAll(const {
      'active': ProxyRuntimeVisualState(latency: 120),
      'other': ProxyRuntimeVisualState(latency: 80),
    });
    final revisionBefore = store.revision.value;

    store.updateTags(const {
      'active': ProxyRuntimeVisualState(),
    }, notifyRevision: false);

    expect(active.value?.latency, isNull);
    expect(store.valueFor('other')?.latency, 80);
    expect(store.revision.value, revisionBefore);
  });

  test('resolver retains only pinned and currently observed proxy states', () {
    final store = ProxyRuntimeVisualStore();
    addTearDown(store.dispose);
    final observed = store.listenableFor('visible');
    void listener() {}

    observed.addListener(listener);
    store.replaceResolver(
      (tag) => ProxyRuntimeVisualState(latency: tag.length),
      pinnedTags: const ['active'],
    );

    expect(store.valueFor('visible')?.latency, 7);
    expect(store.valueFor('offscreen')?.latency, 9);
    expect(store.retainedStateCount, 2);

    observed.removeListener(listener);
    store.pruneUnobserved();

    expect(store.retainedNotifierCount, 0);
    expect(store.retainedStateCount, 1);
    expect(store.valueFor('active')?.latency, 6);
  });

  test('an observed unavailable row receives a later resolved state', () {
    final store = ProxyRuntimeVisualStore();
    addTearDown(store.dispose);
    var available = false;
    final observed = store.listenableFor('visible');
    void listener() {}

    observed.addListener(listener);
    store.replaceResolver(
      (_) => available ? const ProxyRuntimeVisualState(latency: 95) : null,
    );

    expect(observed.value, isNull);

    available = true;
    store.refreshTags(const ['visible']);

    expect(observed.value?.latency, 95);
    observed.removeListener(listener);
  });
}
