import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/models/subscription.dart';

/// The choices exposed to a user, as distinct from the concrete outbounds
/// needed by the core. Top-level choices retain provider auto policies; group
/// members are separate explicit manual choices available in the group panel.
class ProxySelectionCatalog {
  ProxySelectionCatalog(
    List<Outbound> outbounds,
    List<SubscriptionGroup> groups,
  ) {
    final liveTags = outbounds
        .where((outbound) => !outbound.info.deleted)
        .map((outbound) => outbound.tag)
        .toSet();
    liveTags.addAll(providerDirectOutbounds(groups).keys);
    final liveGroups = groups
        .map(
          (group) => group.copyWith(
            outboundTags: group.outboundTags.where(liveTags.contains).toList(),
          ),
        )
        .where((group) => group.outboundTags.isNotEmpty)
        .toList(growable: false);
    final nativeOwned = <String>{};
    final explicitRoots = <String>[];
    for (final group in liveGroups) {
      final references = group.config['outbounds'];
      if (references is! List) continue;
      nativeOwned.addAll(references.whereType<String>());
      if (group.config['_provider_root'] == true) {
        explicitRoots.addAll(references.whereType<String>());
      }
    }
    this.groups = liveGroups
        .where(
          (group) =>
              group.config['_provider_root'] != true &&
              (explicitRoots.contains(group.tag) ||
                  (!nativeOwned.contains(group.tag) &&
                      group.config['_group_only'] != true)),
        )
        .toList(growable: false);
    // Even if a group loses its last usable primary, its fallback must not
    // silently become a standalone/root URLTest candidate.
    memberTags = groups
        .expand(
          (group) => [...group.outboundTags, ...group.fallbackOutboundTags],
        )
        .toSet();
    standaloneOutbounds = outbounds
        .where(
          (outbound) =>
              !outbound.info.deleted &&
              outbound.config['_group_only'] != true &&
              (!memberTags.contains(outbound.tag) ||
                  explicitRoots.contains(outbound.tag)),
        )
        .toList(growable: false);
    candidateTags = [
      ...this.groups.map((group) => group.tag),
      ...standaloneOutbounds.map((outbound) => outbound.tag),
    ];
    if (explicitRoots.isNotEmpty) {
      final ordered = [
        ...explicitRoots.where(candidateTags.contains).toSet(),
        ...candidateTags.where((tag) => !explicitRoots.contains(tag)),
      ];
      candidateTags
        ..clear()
        ..addAll(ordered);
    }
    final groupByTag = {for (final group in liveGroups) group.tag: group};
    final concreteTags = concreteSubscriptionServerTags(outbounds, liveGroups);
    final seen = <String>{};
    manualSelectionTags = candidateTags.toSet();
    void visit(String tag) {
      if (!seen.add(tag)) return;
      final group = groupByTag[tag];
      if (group == null) {
        if (concreteTags.contains(tag)) manualSelectionTags.add(tag);
        return;
      }
      manualSelectionTags.add(tag);
      final references = group.config['outbounds'];
      for (final child in <String>{
        ...group.outboundTags,
        if (references is List) ...references.whereType<String>(),
      }) {
        visit(child);
      }
    }

    for (final tag in candidateTags) {
      visit(tag);
    }
  }

  late final List<SubscriptionGroup> groups;
  late final Set<String> memberTags;
  late final List<Outbound> standaloneOutbounds;
  late final List<String> candidateTags;
  late final Set<String> manualSelectionTags;

  bool get hasLowest => candidateTags.length > 1;
  String get defaultTag =>
      hasLowest ? lowestProxyTag : candidateTags.firstOrNull ?? '';

  String resolveSelection(String preferredTag) {
    final normalized = normalizeProxySelectionTag(preferredTag);
    if (manualSelectionTags.contains(normalized)) return normalized;
    if (isLowestProxyTag(normalized)) return defaultTag;
    // Old selections of hidden dependencies still resolve to their owner.
    for (final group in groups) {
      if (group.outboundTags.contains(normalized) ||
          group.fallbackOutboundTags.contains(normalized)) {
        return group.tag;
      }
    }
    return defaultTag;
  }
}

/// Non-proxy dependencies of native selectors; never server-list candidates.
Map<String, Map<String, dynamic>> providerDirectOutbounds(
  Iterable<SubscriptionGroup> groups,
) {
  final result = <String, Map<String, dynamic>>{};
  for (final group in groups) {
    final direct = group.config['_direct_outbounds'];
    if (direct is! Map) continue;
    for (final entry in direct.entries) {
      if (entry.value is Map) {
        result[entry.key.toString()] = Map<String, dynamic>.from(
          entry.value as Map,
        );
      }
    }
  }
  return result;
}

/// Core group snapshots report an immediate child, which may itself be a group.
String? resolveRuntimeGroupLeaf(
  Map<String, SubscriptionGroup> groups,
  String rootTag,
  Map<String, String> selections,
) {
  final seen = <String>{};
  var tag = rootTag;
  while (seen.add(tag)) {
    final group = groups[tag];
    if (group == null) return tag == rootTag ? null : tag;
    final selected = selections[tag]?.trim();
    if (selected == null || selected.isEmpty) return null;
    final references = group.config['outbounds'];
    final allowed = references is List ? references : group.outboundTags;
    if (!allowed.contains(selected)) return null;
    tag = selected;
  }
  return null;
}

/// Remove broken dependency chains after import or runtime capability/deletion
/// filtering. Removing a node may invalidate its parent on the next pass.
({List<Outbound> outbounds, List<SubscriptionGroup> groups})
filterProxyDependencies(
  List<Outbound> outbounds,
  List<SubscriptionGroup> groups,
) {
  var nodes = outbounds.where((node) => !node.info.deleted).toList();
  var activeGroups = [...groups];
  var changed = true;
  while (changed) {
    final leaves = {
      for (final node in nodes) node.tag,
      ...providerDirectOutbounds(activeGroups).keys,
    };
    final available = {...leaves, ...activeGroups.map((group) => group.tag)};
    final nextNodes = nodes.where((node) {
      final detour = node.config['detour'];
      return detour is! String || available.contains(detour);
    }).toList();
    final nextGroups = <SubscriptionGroup>[];
    for (final group in activeGroups) {
      final members = group.outboundTags.where(leaves.contains).toList();
      if (members.isEmpty) continue;
      final config = Map<String, dynamic>.from(group.config);
      final refs = config['outbounds'];
      if (refs is List) {
        final children = refs
            .whereType<String>()
            .where(available.contains)
            .toList();
        if (children.isEmpty) continue;
        config['outbounds'] = children;
        if (!children.contains(config['default'])) config.remove('default');
      }
      nextGroups.add(group.copyWith(outboundTags: members, config: config));
    }
    changed =
        nextNodes.length != nodes.length ||
        nextGroups.length != activeGroups.length;
    nodes = nextNodes;
    activeGroups = nextGroups;
  }
  return (outbounds: nodes, groups: activeGroups);
}
