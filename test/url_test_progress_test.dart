import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/models/url_test_progress.dart';

void main() {
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
}
