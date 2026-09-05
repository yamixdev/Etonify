import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/models/subscription.dart';

/// The choices exposed to a user, as distinct from the concrete outbounds
/// needed by the core. Subscription groups are managed URLTest outbounds;
/// selecting one of their implementation members would bypass that policy.
class ProxySelectionCatalog {
  ProxySelectionCatalog(
    List<Outbound> outbounds,
    List<SubscriptionGroup> groups,
  ) {
    final liveTags = outbounds
        .where((outbound) => !outbound.info.deleted)
        .map((outbound) => outbound.tag)
        .toSet();
    this.groups = groups
        .map(
          (group) => group.copyWith(
            outboundTags: group.outboundTags.where(liveTags.contains).toList(),
          ),
        )
        .where((group) => group.outboundTags.isNotEmpty)
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
              !memberTags.contains(outbound.tag),
        )
        .toList(growable: false);
    candidateTags = [
      ...this.groups.map((group) => group.tag),
      ...standaloneOutbounds.map((outbound) => outbound.tag),
    ];
  }

  late final List<SubscriptionGroup> groups;
  late final Set<String> memberTags;
  late final List<Outbound> standaloneOutbounds;
  late final List<String> candidateTags;

  bool get hasLowest => candidateTags.length > 1;
  String get defaultTag =>
      hasLowest ? lowestProxyTag : candidateTags.firstOrNull ?? '';

  String resolveSelection(String preferredTag) {
    final normalized = normalizeProxySelectionTag(preferredTag);
    if (candidateTags.contains(normalized)) return normalized;
    if (isLowestProxyTag(normalized)) return defaultTag;
    // Migrate an old saved selection of an internal member to its group.
    for (final group in groups) {
      if (group.outboundTags.contains(normalized) ||
          group.fallbackOutboundTags.contains(normalized)) {
        return group.tag;
      }
    }
    return defaultTag;
  }
}
