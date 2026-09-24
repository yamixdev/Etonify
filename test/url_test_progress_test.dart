import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/models/url_test_progress.dart';

void main() {
  test(
    'checked count never trails visible successes when status event lags',
    () {
      const progress = UrlTestProgressState(total: 3, working: 2, completed: 1);
      expect(progress.tested, 2);
    },
  );

  test('progress counts only testable nodes and updates changed tags', () {
    final counter = UrlTestProgressCounter();
    final results = <String, bool?>{'a': true, 'b': null, 'c': true};
    counter.reset(
      visibleTags: const ['a', 'b', 'c'],
      testableTags: const {'a', 'b'},
      resultForTag: (tag) => results[tag],
    );
    expect(counter.state(), const UrlTestProgressState(total: 2, working: 1));

    final visited = <String>[];
    results['b'] = false;
    counter.update(['b'], (tag) {
      visited.add(tag);
      return results[tag];
    });
    expect(visited, ['b']);
    expect(
      counter.state(),
      const UrlTestProgressState(total: 2, working: 1, failed: 1),
    );

    results['a'] = false;
    counter.update(['a'], (tag) => results[tag]);
    expect(counter.state(), const UrlTestProgressState(total: 2, failed: 2));
  });

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

  test('core session reports its actual queue size and completed probes', () {
    final counter = UrlTestProgressCounter();
    counter.reset(
      visibleTags: List.generate(239, (index) => 'node-$index'),
      testableTags: {for (var index = 0; index < 239; index++) 'node-$index'},
      resultForTag: (_) => null,
    );
    counter.applyCoreSessionSnapshot(total: 219, completed: 219);
    expect(
      counter.state(),
      const UrlTestProgressState(total: 219, completed: 219),
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
}
