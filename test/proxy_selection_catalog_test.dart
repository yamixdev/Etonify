import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/proxy_selection_catalog.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test(
    'fallback ownership survives serialization without becoming a member',
    () {
      final saved = SubscriptionGroup.fromMap(
        const SubscriptionGroup(
          tag: 'auto',
          name: 'Auto',
          outboundTags: ['primary'],
          fallbackOutboundTags: ['backup'],
        ).toMap(),
      );
      final catalog = ProxySelectionCatalog(
        const [
          Outbound(tag: 'primary', name: 'Primary', config: {}),
          Outbound(tag: 'backup', name: 'Any name', config: {}),
          Outbound(tag: 'cand-own', name: 'Own', config: {}),
        ],
        [saved.copyWith(name: 'Renamed')],
      );
      expect(catalog.candidateTags, ['auto', 'cand-own']);
      expect(catalog.resolveSelection('backup'), 'auto');
      expect(catalog.groups.single.outboundTags, ['primary']);
      final missingPrimary = ProxySelectionCatalog(
        const [Outbound(tag: 'backup', name: 'Any name', config: {})],
        [saved],
      );
      expect(missingPrimary.candidateTags, isEmpty);
    },
  );
  const members = [
    Outbound(tag: 'cand-1', name: 'Internal', config: {}),
    Outbound(tag: 'real-name', name: 'Internal too', config: {}),
  ];
  const group = SubscriptionGroup(
    tag: 'provider-auto',
    name: 'Provider auto',
    outboundTags: ['cand-1', 'real-name'],
  );

  test('single provider group is the only selectable route', () {
    final catalog = ProxySelectionCatalog(members, [group]);
    expect(catalog.candidateTags, ['provider-auto']);
    expect(catalog.hasLowest, isFalse);
    expect(catalog.resolveSelection('lowest'), 'provider-auto');
    expect(catalog.resolveSelection('cand-1'), 'provider-auto');
    expect(catalog.resolveSelection('real-name'), 'provider-auto');
  });

  test('membership, not technical-looking names, determines visibility', () {
    final catalog = ProxySelectionCatalog(
      [
        ...members,
        const Outbound(tag: 'cand-standalone', name: 'Own server', config: {}),
      ],
      [group],
    );
    expect(catalog.candidateTags, ['provider-auto', 'cand-standalone']);
    expect(catalog.defaultTag, 'lowest');
    expect(catalog.resolveSelection('cand-standalone'), 'cand-standalone');
  });

  test('one surviving group member stays behind the group', () {
    final catalog = ProxySelectionCatalog([members.first], [group]);
    expect(catalog.groups.single.outboundTags, ['cand-1']);
    expect(catalog.resolveSelection(''), 'provider-auto');
  });

  test('empty groups and orphaned chain helpers cannot be selected', () {
    final catalog = ProxySelectionCatalog(
      [
        const Outbound(
          tag: 'helper',
          name: 'Helper',
          config: {'_group_only': true},
        ),
      ],
      [group],
    );
    expect(catalog.candidateTags, isEmpty);
    expect(catalog.resolveSelection('helper'), '');
  });
}
