import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/latency_dependencies.dart';

void main() {
  test('target follows nested selections and rejects cycles', () {
    expect(
      latencyTargetTag('LTE', {'LTE': 'region', 'region': 'cand-43'}),
      'cand-43',
    );
    expect(latencyTargetTag('direct', {}), 'direct');
    expect(latencyTargetTag('a', {'a': 'b', 'b': 'a'}), isNull);
  });
  test(
    'hidden leaf refreshes provider and nested visible ancestors immediately',
    () {
      expect(
        latencyAffectedTags(
          ['hidden-candidate'],
          {
            'Germany': ['hidden-candidate', 'other'],
            'Auto': ['Germany'],
            'Unrelated': ['other'],
          },
        ),
        {'hidden-candidate', 'Germany', 'Auto'},
      );
    },
  );
  test('cycles and shared candidates are bounded', () {
    expect(
      latencyAffectedTags(
        ['leaf'],
        {
          'a': ['leaf', 'b'],
          'b': ['a', 'leaf'],
        },
      ),
      {'leaf', 'a', 'b'},
    );
  });

  test('URLTest budget includes hidden runtime outbound targets', () {
    expect(
      latencySessionOutboundCount(
        visibleOutboundCount: 3,
        runtimeOutboundTags: ['visible', 'cand-01', 'cand-02', 'cand-03'],
      ),
      4,
    );
    expect(
      latencySessionOutboundCount(
        visibleOutboundCount: 7,
        runtimeOutboundTags: const <String>[],
      ),
      7,
    );
  });
}
