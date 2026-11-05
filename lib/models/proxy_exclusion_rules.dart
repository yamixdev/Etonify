import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meow_client/core/outbound_location.dart';
import 'package:meow_client/models/subscription.dart';

String? _normalized(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim().toLowerCase();
}

/// All fields in one condition must match. Empty conditions never match.
class ProxyExclusionCondition {
  ProxyExclusionCondition({
    String? protocol,
    String? security,
    String? transport,
    String? country,
  }) : protocol = _normalized(protocol),
       security = _normalized(security),
       transport = _normalized(transport),
       country = _normalized(country)?.toUpperCase();
  final String? protocol;
  final String? security;
  final String? transport;
  final String? country;
  bool get isEmpty =>
      protocol == null &&
      security == null &&
      transport == null &&
      country == null;
  static String protocolOf(Outbound node) =>
      _normalized(node.config['type']) ?? 'unknown';
  static String securityOf(Outbound node) {
    final tls = node.config['tls'];
    if (tls is! Map || tls['enabled'] != true) return 'none';
    final reality = tls['reality'];
    return reality is Map && reality['enabled'] == true ? 'reality' : 'tls';
  }

  static String transportOf(Outbound node) {
    final transport = node.config['transport'];
    if (transport is! Map &&
        const {
          'hysteria',
          'hysteria2',
          'tuic',
          'wireguard',
        }.contains(protocolOf(node))) {
      return 'udp';
    }
    return transport is Map ? _normalized(transport['type']) ?? 'tcp' : 'tcp';
  }

  bool matches(Outbound node, {String? countryCode}) =>
      !isEmpty &&
      (protocol == null || protocol == protocolOf(node)) &&
      (security == null || security == securityOf(node)) &&
      (transport == null || transport == transportOf(node)) &&
      (country == null ||
          country ==
              normalizeOutboundCountryCode(
                countryCode ??
                    outboundDisplayCountryCode(
                      node,
                      markAllServersRussia: false,
                    ),
              ));
  Map<String, dynamic> toMap() => {
    if (protocol != null) 'protocol': protocol,
    if (security != null) 'security': security,
    if (transport != null) 'transport': transport,
    if (country != null) 'country': country,
  };
  factory ProxyExclusionCondition.fromMap(Map<dynamic, dynamic> map) =>
      ProxyExclusionCondition(
        protocol: map['protocol'] is String ? map['protocol'] as String : null,
        security: map['security'] is String ? map['security'] as String : null,
        transport: map['transport'] is String
            ? map['transport'] as String
            : null,
        country: map['country'] is String ? map['country'] as String : null,
      );
}

class ProxyExclusionRules {
  ProxyExclusionRules({
    Iterable<String> excludedTags = const [],
    Iterable<String> excludedServerIds = const [],
    this.legacyTagsBound = false,
    Iterable<ProxyExclusionCondition> conditions = const [],
  }) : excludedTags = Set.unmodifiable(
         excludedTags.where((tag) => tag.trim().isNotEmpty),
       ),
       excludedServerIds = Set.unmodifiable(excludedServerIds),
       conditions = List.unmodifiable(
         conditions.where((rule) => !rule.isEmpty),
       );
  final Set<String> excludedTags;
  final Set<String> excludedServerIds;
  final bool legacyTagsBound;
  final List<ProxyExclusionCondition> conditions;
  bool get isEmpty =>
      excludedServerIds.isEmpty &&
      (legacyTagsBound || excludedTags.isEmpty) &&
      conditions.isEmpty;

  /// Persist this result against the current payload BEFORE accepting updates.
  /// Missing legacy tags are deliberately retired rather than rebound later.
  ProxyExclusionRules bindLegacyTags(Subscription subscription) {
    if (legacyTagsBound || excludedTags.isEmpty) return this;
    final servers = concreteServers(subscription);
    final identities = _ServerIdentities(subscription, servers);
    return ProxyExclusionRules(
      excludedTags: excludedTags,
      excludedServerIds: {
        ...excludedServerIds,
        for (final server in servers)
          if (excludedTags.contains(server.tag)) identities.id(server),
      },
      legacyTagsBound: true,
      conditions: conditions,
    );
  }

  /// Computes the concrete catalog and matching rules once for both projections.
  ProxyExclusionProjection prepare(Subscription subscription) {
    final excluded = excludedTagsFor(subscription);
    return ProxyExclusionProjection(
      excludedTags: excluded,
      runtimeSubscription: _runtimeSubscription(subscription, excluded),
      eligibleSubscription: _eligibleSubscription(subscription, excluded),
    );
  }

  static Map<String, String> manualServerIdsFor(Subscription subscription) {
    final servers = concreteServers(subscription);
    final identities = _ServerIdentities(subscription, servers);
    return Map.unmodifiable({
      for (final server in servers) server.tag: identities.id(server),
    });
  }

  /// Retain every runtime member for live unexclude. Eligibility is initialized
  /// in the core before startup, never by deleting runtime group membership.
  Subscription runtimeSubscription(Subscription subscription) {
    final excluded = excludedTagsFor(subscription);
    return _runtimeSubscription(subscription, excluded);
  }

  Subscription _runtimeSubscription(
    Subscription subscription,
    Set<String> excluded,
  ) {
    if (excluded.isEmpty) return subscription;
    Map<String, dynamic> mark(String tag, Map<String, dynamic> config) => {
      ...config,
      if (excluded.contains(tag)) '_excluded_by_user': true,
    };
    return subscription.copyWith(
      payloadRevision: subscription.payloadRevision.isEmpty
          ? ''
          : '${subscription.payloadRevision}|exclusions:${jsonEncode(toMap())}',
      outbounds: [
        for (final node in subscription.outbounds)
          node.copyWith(config: mark(node.tag, node.config)),
      ],
      groups: [
        for (final group in subscription.groups)
          group.copyWith(
            config: {
              ...group.config,
              if (group.config['_direct_outbounds']
                  case final Map<dynamic, dynamic> direct)
                '_direct_outbounds': {
                  for (final entry in direct.entries)
                    entry.key: entry.value is Map
                        ? mark(
                            entry.key.toString(),
                            Map<String, dynamic>.from(
                              entry.value as Map<dynamic, dynamic>,
                            ),
                          )
                        : entry.value,
                },
            },
          ),
      ],
    );
  }

  /// A runtime/presentation projection only; subscription storage is untouched.
  /// Excluded concrete configs remain hidden dependencies for surviving chains.
  Subscription eligibleSubscription(Subscription subscription) {
    final excluded = excludedTagsFor(subscription);
    return _eligibleSubscription(subscription, excluded);
  }

  Subscription _eligibleSubscription(
    Subscription subscription,
    Set<String> excluded,
  ) {
    if (excluded.isEmpty) return subscription;
    final hiddenEmbedded = <Outbound>[];
    final groups = subscription.groups.map((group) {
      final config = Map<String, dynamic>.from(group.config);
      final references = config['outbounds'];
      if (references is List) {
        config['outbounds'] = references
            .where((tag) => !excluded.contains(tag))
            .toList();
      }
      final direct = config['_direct_outbounds'];
      if (direct is Map) {
        config['_direct_outbounds'] = {
          for (final entry in direct.entries)
            if (!excluded.contains(entry.key)) entry.key: entry.value,
        };
        for (final entry in direct.entries) {
          if (excluded.contains(entry.key) && entry.value is Map) {
            hiddenEmbedded.add(
              Outbound(
                tag: entry.key.toString(),
                name: entry.key.toString(),
                config: {
                  ...Map<String, dynamic>.from(entry.value as Map),
                  '_group_only': true,
                  '_excluded_by_user': true,
                },
              ),
            );
          }
        }
      }
      if (excluded.contains(config['default'])) config.remove('default');
      return group.copyWith(
        outboundTags: group.outboundTags
            .where((tag) => !excluded.contains(tag))
            .toList(),
        fallbackOutboundTags: group.fallbackOutboundTags
            .where((tag) => !excluded.contains(tag))
            .toList(),
        config: config,
      );
    }).toList();
    final existingTags = subscription.outbounds.map((node) => node.tag).toSet();
    return subscription.copyWith(
      payloadRevision: subscription.payloadRevision.isEmpty
          ? ''
          : '${subscription.payloadRevision}|exclusions:${jsonEncode(toMap())}',
      groups: groups,
      outbounds: [
        for (final node in subscription.outbounds)
          if (excluded.contains(node.tag))
            node.copyWith(
              config: {
                ...node.config,
                '_group_only': true,
                '_excluded_by_user': true,
              },
            )
          else if (node.config['outbounds'] is List)
            node.copyWith(
              config: {
                ...node.config,
                'outbounds': (node.config['outbounds'] as List)
                    .where((tag) => !excluded.contains(tag))
                    .toList(),
              },
            )
          else
            node,
        ...hiddenEmbedded.where((node) => !existingTags.contains(node.tag)),
      ],
    );
  }

  bool excludes(
    Outbound node, {
    String? countryCode,
    Subscription? subscription,
  }) =>
      (!legacyTagsBound && excludedTags.contains(node.tag)) ||
      (subscription != null &&
          excludedServerIds.isNotEmpty &&
          excludedServerIds.contains(
            _ServerIdentities(subscription, [node]).id(node),
          )) ||
      conditions.any((rule) => rule.matches(node, countryCode: countryCode));
  Set<String> excludedTagsFor(Subscription subscription) {
    if (isEmpty) return const {};
    final servers = concreteServers(subscription);
    final identities = excludedServerIds.isEmpty
        ? null
        : _ServerIdentities(subscription, servers);
    return Set.unmodifiable({
      for (final node in servers)
        if ((!legacyTagsBound && excludedTags.contains(node.tag)) ||
            (identities != null &&
                excludedServerIds.contains(identities.id(node))) ||
            conditions.any(
              (rule) => rule.matches(
                node,
                countryCode: outboundDisplayCountryCode(
                  node,
                  markAllServersRussia: subscription.markAllServersRussia,
                ),
              ),
            ))
          node.tag,
    });
  }

  /// Embedded leaves count; navigation and detour-only nodes do not.
  static List<Outbound> concreteServers(Subscription subscription) {
    final tags = subscription.concreteServerTags;
    final nodes = {for (final node in subscription.outbounds) node.tag: node};
    for (final group in subscription.groups) {
      final direct = group.config['_direct_outbounds'];
      if (direct is! Map) continue;
      for (final entry in direct.entries) {
        if (entry.value is! Map) continue;
        final tag = entry.key.toString();
        nodes.putIfAbsent(
          tag,
          () => Outbound(
            tag: tag,
            name: tag,
            config: Map<String, dynamic>.from(entry.value as Map),
          ),
        );
      }
    }
    return List.unmodifiable(
      nodes.values.where((node) => tags.contains(node.tag)),
    );
  }

  Map<String, dynamic> toMap() => {
    'excluded_tags': excludedTags.toList(),
    'excluded_server_ids': excludedServerIds.toList(),
    'legacy_tags_bound': legacyTagsBound,
    'conditions': conditions.map((rule) => rule.toMap()).toList(),
  };
  factory ProxyExclusionRules.fromMap(Map<dynamic, dynamic> map) =>
      ProxyExclusionRules(
        legacyTagsBound: map['legacy_tags_bound'] == true,
        excludedServerIds: map['excluded_server_ids'] is List
            ? (map['excluded_server_ids'] as List).whereType<String>()
            : const [],
        excludedTags: map['excluded_tags'] is List
            ? (map['excluded_tags'] as List).whereType<String>()
            : const [],
        conditions: map['conditions'] is List
            ? (map['conditions'] as List)
                  .whereType<Map<dynamic, dynamic>>()
                  .map(ProxyExclusionCondition.fromMap)
            : const [],
      );
}

/// Only digests leave this transient object. Labels and parser bookkeeping are
/// not connection identity; detours are resolved so renaming them is harmless.
class _ServerIdentities {
  _ServerIdentities(this.subscription, List<Outbound> servers)
    : nodes = {
        for (final node in [...subscription.outbounds, ...servers])
          node.tag: node,
      };
  final Subscription subscription;
  final Map<String, Outbound> nodes;
  final Map<String, String> _ids = {};

  String id(Outbound node) => _ids.putIfAbsent(node.tag, () {
    var sourceId = 'primary';
    var sourceUrl = subscription.url;
    for (final source in subscription.sources) {
      if (source.id == 'primary' && sourceId == 'primary') {
        sourceUrl = source.url;
      }
      if (source.id != 'primary' &&
          node.tag.startsWith('source:${source.id}:') &&
          (sourceId == 'primary' || source.id.length > sourceId.length)) {
        sourceId = source.id;
        sourceUrl = source.url;
      }
    }
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              'manual-exclusion-v1',
              subscription.id,
              sourceId,
              sourceUrl,
              _config(node.config, {node.tag}),
            ]),
          ),
        )
        .toString();
  });

  Object? _value(Object? value, Set<String> visited) {
    if (value is Map) {
      return {
        for (final key
            in value.keys.map((key) => key.toString()).toList()..sort())
          key: _value(value[key], visited),
      };
    }
    if (value is List) {
      return value.map((value) => _value(value, visited)).toList();
    }
    return value;
  }

  Map<String, Object?> _config(
    Map<String, dynamic> config,
    Set<String> visited,
  ) => {
    for (final key in config.keys.toList()..sort())
      if (!key.startsWith('_') && key != 'tag' && key != 'name')
        key: key == 'detour' && nodes[config[key]] != null
            ? (visited.contains(config[key])
                  ? 'cycle'
                  : _config(nodes[config[key]]!.config, {
                      ...visited,
                      config[key] as String,
                    }))
            : _value(config[key], visited),
  };
}

class ProxyExclusionProjection {
  const ProxyExclusionProjection({
    required this.excludedTags,
    required this.runtimeSubscription,
    required this.eligibleSubscription,
  });
  final Set<String> excludedTags;
  final Subscription runtimeSubscription;
  final Subscription eligibleSubscription;
}
