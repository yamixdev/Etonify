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
}
