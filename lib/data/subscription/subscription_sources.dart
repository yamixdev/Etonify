import 'package:meow_client/models/subscription.dart';

({List<Outbound> outbounds, List<SubscriptionGroup> groups})
composeSubscriptionSources(List<SubscriptionSource> sources) {
  final outbounds = <Outbound>[];
  final groups = <SubscriptionGroup>[];
  for (final source in sources.where((s) => s.enabled)) {
    final snapshot = source.snapshot;
    final sourceTags = <String>{
      ...snapshot.outbounds.map((o) => o.tag),
      ...snapshot.groups.map((g) => g.tag),
    };
    void collectEmbeddedTags(Object? value) {
      if (value is Map) {
        final direct = value['_direct_outbounds'];
        if (direct is Map) {
          for (final entry in direct.entries) {
            sourceTags.add(entry.key.toString());
            final config = entry.value;
            if (config is Map && config['tag'] is String) {
              sourceTags.add(config['tag'] as String);
            }
          }
        }
        for (final child in value.values) {
          collectEmbeddedTags(child);
        }
      } else if (value is List) {
        for (final child in value) {
          collectEmbeddedTags(child);
        }
      }
    }

    for (final outbound in snapshot.outbounds) {
      collectEmbeddedTags(outbound.config);
    }
    for (final group in snapshot.groups) {
      collectEmbeddedTags(group.config);
    }
    final tags = <String, String>{
      for (final tag in sourceTags)
        tag: source.id == 'primary' ? tag : 'source:${source.id}:$tag',
    };
    Object? rewrite(Object? value, [String key = '']) {
      const references = {
        'tag',
        'detour',
        'outbound',
        'default',
        'outbounds',
        'fallback',
        '_group_tag',
        '_group_tags',
        '_provider_group',
        '_provider_groups',
      };
      if (value is String) {
        return references.contains(key) ? tags[value] ?? value : value;
      }
      if (value is List) {
        return value.map((v) => rewrite(v, key)).toList();
      }
      if (value is Map) {
        return {
          for (final entry in value.entries)
            (key == '_direct_outbounds'
                ? tags[entry.key.toString()] ?? entry.key.toString()
                : entry.key.toString()): rewrite(
              entry.value,
              entry.key.toString(),
            ),
        };
      }
      return value;
    }

    outbounds.addAll(
      snapshot.outbounds.map(
        (o) => o.copyWith(
          tag: tags[o.tag],
          config: Map<String, dynamic>.from(rewrite(o.config) as Map),
        ),
      ),
    );
    groups.addAll(
      snapshot.groups.map(
        (g) => g.copyWith(
          tag: tags[g.tag],
          outboundTags: g.outboundTags.map((t) => tags[t] ?? t).toList(),
          fallbackOutboundTags: g.fallbackOutboundTags
              .map((t) => tags[t] ?? t)
              .toList(),
          config: Map<String, dynamic>.from(rewrite(g.config) as Map),
        ),
      ),
    );
  }
  return (outbounds: outbounds, groups: groups);
}
