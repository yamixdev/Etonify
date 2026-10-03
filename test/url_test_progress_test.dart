import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/models/url_test_progress.dart';

void main() {
  test('temporary metadata-only reload preserves a sweep before hydration', () {
    final counter = UrlTestProgressCounter();
    void synchronize({bool hydrated = true}) => counter.synchronizeCatalog(
      scopeKey: 'profile',
      catalogKey: Object(),
      catalogComplete: hydrated,
      visibleTags: () => hydrated ? const ['a', 'b'] : const [],
      testableTags: () => const {'a', 'b'},
      resultForTag: (_) => true,
    );
    synchronize();
    counter.reset(
      visibleTags: const ['a', 'b'],
      testableTags: const {'a', 'b'},
      resultForTag: (_) => null,
    );
    counter.applyCoreSessionSnapshot(total: 2, completed: 1);
    counter.update(['a'], (_) => true);
    synchronize(hydrated: false);
    expect(
      counter.state(),
      const UrlTestProgressState(total: 2, working: 1, completed: 1),
    );
    synchronize();
    expect(
      counter.state(),
      const UrlTestProgressState(total: 2, working: 1, completed: 1),
    );
  });

  test('hydration initializes manual progress without a full sweep', () {
    final counter = UrlTestProgressCounter();
    final results = <String, bool?>{'sweden': true};
    counter.reset(
      visibleTags: const [],
      testableTags: const {},
      resultForTag: (tag) => results[tag],
    );
    final tags = ['sweden', for (var i = 0; i < 12; i++) 'child-$i'];
    final catalogKey = Object();
    void synchronize() => counter.synchronizeCatalog(
      catalogKey: catalogKey,
      visibleTags: () => tags,
      testableTags: () => tags.toSet(),
      resultForTag: (tag) => results[tag],
    );
    synchronize();
    expect(counter.state(), const UrlTestProgressState(total: 13, working: 1));
    for (var i = 0; i < 9; i++) {
      results['child-$i'] = true;
      synchronize();
      counter.update(['child-$i', 'auto-group'], (tag) => results[tag]);
    }
    expect(counter.state(), const UrlTestProgressState(total: 13, working: 10));
    counter.update(['sweden', 'child-0'], (tag) => results[tag]);
    expect(counter.state().working, 10);
  });

  test('unchanged catalog does not seed old results into a new full sweep', () {
    final counter = UrlTestProgressCounter();
    final key = Object();
    var scans = 0;
    void synchronize() => counter.synchronizeCatalog(
      catalogKey: key,
      visibleTags: () {
        scans++;
        return const ['a', 'b'];
      },
      testableTags: () => const {'a', 'b'},
      resultForTag: (_) => true,
    );
    synchronize();
    counter.reset(
      visibleTags: const ['a', 'b'],
      testableTags: const {'a', 'b'},
      resultForTag: (_) => null,
    );
    counter.applyCoreSessionSnapshot(total: 2, completed: 1);
    counter.update(['a'], (_) => true);
    synchronize();
    expect(scans, 1);
    expect(
      counter.state(),
      const UrlTestProgressState(total: 2, working: 1, completed: 1),
    );
  });

  test(
    'metadata replacement preserves an in-progress sweep for the same tags',
    () {
      final counter = UrlTestProgressCounter();
      void synchronize() => counter.synchronizeCatalog(
        scopeKey: 'profile',
        catalogKey: Object(),
        visibleTags: () => const ['a', 'b'],
        testableTags: () => const {'a', 'b'},
        resultForTag: (_) => true,
      );
      synchronize();
      counter.reset(
        visibleTags: const ['a', 'b'],
        testableTags: const {'a', 'b'},
        resultForTag: (_) => null,
      );
      counter.applyCoreSessionSnapshot(total: 2, completed: 1);
      counter.update(['a'], (_) => true);
      synchronize();
      expect(
        counter.state(),
        const UrlTestProgressState(total: 2, working: 1, completed: 1),
      );
    },
  );

  test(
    'another profile with identical tags does not retain previous results',
    () {
      final counter = UrlTestProgressCounter();
      for (final profile in ['first', 'second']) {
        counter.synchronizeCatalog(
          scopeKey: profile,
          catalogKey: Object(),
          visibleTags: () => const ['a', 'b'],
          testableTags: () => const {'a', 'b'},
          resultForTag: (_) => profile == 'first' ? true : null,
        );
      }
      expect(counter.state(), const UrlTestProgressState(total: 2));
    },
  );

  test(
    'changed catalog drops removed servers and retains only fresh results',
    () {
      final counter = UrlTestProgressCounter();
      void synchronize(Object key, List<String> tags) =>
          counter.synchronizeCatalog(
            catalogKey: key,
            visibleTags: () => tags,
            testableTags: () => tags.toSet(),
            resultForTag: (tag) => tag == 'stale' ? null : true,
          );
      synchronize(Object(), ['old', 'retained']);
      synchronize(Object(), ['retained', 'stale', 'pending']);
      counter.update(['old'], (_) => true);
      expect(counter.state(), const UrlTestProgressState(total: 3, working: 2));
    },
  );

  test(
    'reconciliation retains current server plus three unique group children',
    () {
      final counter = UrlTestProgressCounter();
      final results = <String, bool?>{
        'sweden': true,
        'a': true,
        'b': true,
        'c': true,
      };
      counter.reset(
        visibleTags: const ['sweden', 'a', 'b', 'c', 'untested'],
        testableTags: const {'a', 'b', 'c'},
        includeKnownVisibleResults: true,
        resultForTag: (tag) => results[tag],
      );
      counter.update([
        'auto',
        'sweden',
        'a',
        'b',
        'c',
        'a',
      ], (tag) => results[tag]);
      expect(counter.state().working, 4);
      expect(counter.state().tested, 4);
      expect(counter.state().total, 5);
    },
  );
  test(
    'checked count never trails visible successes when status event lags',
    () {
      const progress = UrlTestProgressState(total: 3, working: 2, completed: 1);
      expect(progress.tested, 2);
    },
  );

  test(
    'progress leaves untested visible nodes pending and updates changed tags',
    () {
      final counter = UrlTestProgressCounter();
      final results = <String, bool?>{'a': true, 'b': null, 'c': true};
      counter.reset(
        visibleTags: const ['a', 'b', 'c'],
        testableTags: const {'a', 'b'},
        resultForTag: (tag) => results[tag],
      );
      expect(counter.state(), const UrlTestProgressState(total: 3, working: 1));

      final visited = <String>[];
      results['b'] = false;
      counter.update(['b'], (tag) {
        visited.add(tag);
        return results[tag];
      });
      expect(visited, ['b']);
      expect(
        counter.state(),
        const UrlTestProgressState(total: 3, working: 1, failed: 1),
      );

      results['a'] = false;
      counter.update(['a'], (tag) => results[tag]);
      expect(counter.state(), const UrlTestProgressState(total: 3, failed: 2));
    },
  );

  test('reset drops measurements from the previous profile', () {
    final counter = UrlTestProgressCounter();
    counter.reset(
      visibleTags: const ['a'],
      testableTags: const {'a'},
      resultForTag: (_) => true,
    );
    counter.reset(
      visibleTags: const ['b'],
      testableTags: const {'b'},
      resultForTag: (_) => null,
    );
    expect(counter.state(), const UrlTestProgressState(total: 1));
    counter.update(['a'], (_) => true);
    expect(counter.state(), const UrlTestProgressState(total: 1));
  });

  test('visible total retains skipped nodes when core queue is smaller', () {
    final counter = UrlTestProgressCounter();
    counter.reset(
      visibleTags: List.generate(239, (index) => 'node-$index'),
      testableTags: {for (var index = 0; index < 239; index++) 'node-$index'},
      resultForTag: (_) => null,
    );
    counter.applyCoreSessionSnapshot(total: 219, completed: 219);
    expect(
      counter.state(),
      const UrlTestProgressState(total: 239, completed: 219),
    );

    counter.update(['node-0'], (_) => true);
    expect(counter.state().tested, 219);
    expect(counter.state().working, 1);
    counter.reset(
      visibleTags: const ['new'],
      testableTags: const {'new'},
      resultForTag: (_) => null,
    );
    expect(counter.state(), const UrlTestProgressState(total: 1));
  });

  test(
    'working count follows visible result rows, not the earlier core total',
    () {
      final counter = UrlTestProgressCounter();
      final results = <String, bool?>{'a': null, 'b': null, 'c': null};
      counter.reset(
        visibleTags: const ['a', 'b', 'c'],
        testableTags: const {'a', 'b', 'c'},
        resultForTag: (tag) => results[tag],
      );
      counter.applyCoreSessionSnapshot(total: 3, completed: 2);
      expect(counter.state().working, 0);
      expect(counter.state().tested, 2);

      results['a'] = true;
      counter.update(['a'], (tag) => results[tag]);
      expect(counter.state().working, 1);

      results['b'] = true;
      counter.update(['b'], (tag) => results[tag]);
      expect(counter.state().working, 2);
    },
  );

  test('targeted recheck updates a completed full-session summary', () {
    final counter = UrlTestProgressCounter();
    counter.reset(
      visibleTags: const ['node-a', 'node-b'],
      testableTags: const {'node-a', 'node-b'},
      resultForTag: (tag) => tag == 'node-a',
    );
    counter.applyCoreSessionSnapshot(total: 2, completed: 2);
    counter.update(['node-a'], (_) => false);
    expect(
      counter.state(),
      const UrlTestProgressState(total: 2, working: 0, failed: 2, completed: 2),
    );
  });

  test('manual check adds a previously skipped nested group child once', () {
    final counter = UrlTestProgressCounter();
    counter.reset(
      visibleTags: const ['regular', 'nested-child'],
      testableTags: const {'regular'},
      resultForTag: (tag) => tag == 'regular' ? true : null,
    );
    counter.applyCoreSessionSnapshot(total: 1, completed: 1);
    counter.update(['nested-child'], (_) => true);
    expect(
      counter.state(),
      const UrlTestProgressState(total: 2, working: 2, completed: 2),
    );
    counter.update(['nested-child'], (_) => true);
    expect(counter.state().working, 2);
    expect(counter.state().tested, 2);
  });
}
