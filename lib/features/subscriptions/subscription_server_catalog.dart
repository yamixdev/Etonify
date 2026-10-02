import 'package:meow_client/data/subscription/outbound_support.dart';
import 'package:meow_client/core/proxy_selection_catalog.dart';
import 'package:meow_client/models/subscription.dart';

/// Presentation-only hierarchy. Never rewrites the profile or infers ownership
/// from names such as `cand-01`: only explicit provider references are used.
class SubscriptionServerCatalog {
  SubscriptionServerCatalog(Subscription subscription) {
    final visible = filterProxyDependencies(
      subscription.outbounds
          .where((node) => isSupportedOutboundConfig(node.config))
          .toList(),
      subscription.groups,
    );
    for (final node in visible.outbounds) {
      _nodes[node.tag] = node;
    }
    for (final group in visible.groups) {
      final direct = group.config['_direct_outbounds'];
      if (direct is Map) {
        for (final entry in direct.entries) {
          if (entry.value is! Map) continue;
          final tag = entry.key.toString();
          _nodes.putIfAbsent(
            tag,
            () => Outbound(
              tag: tag,
              name: tag,
              config: Map<String, dynamic>.from(entry.value as Map),
            ),
          );
        }
      }
      _fallbacks[group.tag] = group.fallbackOutboundTags;
      if (_nodes.containsKey(group.tag)) continue;
      final tuning = group.urlTestConfig;
      // Provider strategies (e.g. Xray leastPing) are managed URLTest
      // groups in our runtime, not standalone outbound protocol types.
      final type = group.type == 'selector' ? 'selector' : 'urltest';
      _nodes[group.tag] = Outbound(
        tag: group.tag,
        name: group.name,
        info: OutboundInfo(country: group.country),
        config: {
          ...group.config,
          'tag': group.tag,
          'type': type,
          'outbounds': group.config['outbounds'] ?? group.outboundTags,
          if (type == 'urltest') ...{
            if (tuning.url != null) 'url': tuning.url,
            if (tuning.intervalSeconds != null)
              'interval': '${tuning.intervalSeconds}s',
          },
        },
      );
    }
    final owned = <String>{};
    for (final node in _nodes.values) {
      if (!isGroup(node)) continue;
      final tags = <String>{
        ..._references(node),
        ...?_fallbacks[node.tag],
      }.where((tag) => tag != node.tag && _nodes.containsKey(tag)).toList();
      _children[node.tag] = tags;
      owned.addAll(tags);
    }
    roots = [
      for (final node in _nodes.values)
        if (isGroup(node) &&
            !owned.contains(node.tag) &&
            node.config['_group_only'] != true &&
            members(node.tag).isNotEmpty)
          node,
      for (final node in _nodes.values)
        if (!isGroup(node) &&
            !owned.contains(node.tag) &&
            _isProxyLeaf(node) &&
            node.config['_group_only'] != true)
          node,
    ];
    final originalPositions = {
      for (var i = 0; i < roots.length; i++) roots[i].tag: i,
    };
    roots.sort((a, b) {
      final left = a.config['_source_order'];
      final right = b.config['_source_order'];
      if (left is num && right is num) {
        final byOrder = left.compareTo(right);
        if (byOrder != 0) return byOrder;
      } else if (left is num) {
        return -1;
      } else if (right is num) {
        return 1;
      }
      return originalPositions[a.tag]!.compareTo(originalPositions[b.tag]!);
    });
    // A provider's entry selector is a navigation wrapper; show its choices in
    // the declared order, not the implementation order of the raw outbounds.
    final expandedRoots = [
      for (final node in roots)
        if (node.config['_provider_root'] == true)
          ...members(
            node.tag,
          ).where((child) => isGroup(child) || _isProxyLeaf(child))
        else
          node,
    ];
    roots
      ..clear()
      ..addAll(expandedRoots);
    // A malformed cycle must neither recurse forever nor hide the entire group.
    final reachable = <String>{};
    void mark(String tag) {
      final pending = <String>[tag];
      while (pending.isNotEmpty) {
        final next = pending.removeLast();
        if (!reachable.add(next)) continue;
        pending.addAll(_children[next] ?? const []);
      }
    }

    for (final node in roots) {
      mark(node.tag);
    }
    for (final node in _nodes.values) {
      if (isGroup(node) &&
          !reachable.contains(node.tag) &&
          node.config['_provider_root'] != true &&
          node.config['_group_only'] != true &&
          members(node.tag).isNotEmpty) {
        roots.add(node);
        mark(node.tag);
      }
    }
  }

  final _nodes = <String, Outbound>{};
  final _children = <String, List<String>>{};
  final _fallbacks = <String, List<String>>{};
  final _memberCounts = <String, int>{};
  late final List<Outbound> roots;

  static bool isGroup(Outbound node) =>
      node.type == 'urltest' || node.type == 'selector';

  Outbound? node(String tag) => _nodes[tag];

  List<Outbound> members(String tag) => [
    for (final child in _children[tag] ?? const <String>[]) ?_nodes[child],
  ];

  int memberCount(String tag) {
    return _memberCounts.putIfAbsent(tag, () => _countLeaves([tag]));
  }

  late final int visibleProxyCount = _countLeaves(
    roots.map((node) => node.tag),
  );

  int _countLeaves(Iterable<String> tags) {
    final leaves = <String>{};
    final seen = <String>{};
    final pending = [...tags];
    while (pending.isNotEmpty) {
      final next = pending.removeLast();
      if (!seen.add(next)) continue;
      final node = _nodes[next];
      if (node == null) continue;
      if (isGroup(node)) {
        pending.addAll(_children[next] ?? const []);
      } else if (_isProxyLeaf(node)) {
        leaves.add(next);
      }
    }
    return leaves.length;
  }

  String searchText(Outbound node) {
    final parts = <String>[];
    final seen = <String>{};
    final pending = <String>[node.tag];
    while (pending.isNotEmpty) {
      final tag = pending.removeLast();
      if (!seen.add(tag)) continue;
      final current = _nodes[tag];
      if (current == null) continue;
      parts.add('${current.name} ${current.type} ${current.server}');
      pending.addAll(_children[tag] ?? const []);
    }
    return parts.join(' ').toLowerCase();
  }

  Map<String, dynamic> exportGroup(String tag) {
    if (!_nodes.containsKey(tag)) {
      throw const SubscriptionServerExportException();
    }
    final seen = <String>{};
    final pending = <String>[tag];
    final configs = <Map<String, dynamic>>[];
    while (pending.isNotEmpty) {
      final next = pending.removeLast();
      if (!seen.add(next)) continue;
      final current = _nodes[next];
      if (current == null) continue;
      final config = Map<String, dynamic>.from(current.config)
        ..removeWhere((key, _) => key.startsWith('_'))
        ..['tag'] = current.tag;
      if (isGroup(current)) {
        final children = _references(
          current,
        ).where(_nodes.containsKey).toSet().toList();
        if (children.isEmpty) throw const SubscriptionServerExportException();
        config['outbounds'] = children;
        if (current.type == 'urltest') {
          // Current core accepts these URLTest JSON fields. Custom tuning is
          // retained in full-profile exports, not legacy sing-box extensions.
          config.remove('method');
          config.remove('timeout');
          config.remove('concurrency');
          config.remove('unavailable_check_interval');
        }
        if (config['default'] != null &&
            !children.contains(config['default'])) {
          config.remove('default');
        }
      }
      configs.add(config);
      pending.addAll(_references(current).toList().reversed);
      pending.addAll((_fallbacks[current.tag] ?? const <String>[]).reversed);
      final detour = config['detour'];
      if (detour is String) {
        if (!_nodes.containsKey(detour)) {
          throw const SubscriptionServerExportException();
        }
        pending.add(detour);
      }
    }
    // Reject dependency cycles rather than exporting a document the core cannot
    // load. The iterative walk stays bounded for deeply nested profiles.
    final dependencies = {
      for (final config in configs)
        config['tag'] as String: <String>{
          if (config['outbounds'] is List)
            ...(config['outbounds'] as List).whereType<String>(),
          if (config['detour'] is String) config['detour'] as String,
        },
    };
    final dependents = <String, List<String>>{};
    final degree = <String, int>{};
    for (final entry in dependencies.entries) {
      degree[entry.key] = entry.value.length;
      for (final child in entry.value) {
        if (!dependencies.containsKey(child)) {
          throw const SubscriptionServerExportException();
        }
        dependents.putIfAbsent(child, () => []).add(entry.key);
      }
    }
    final ready = degree.keys.where((tag) => degree[tag] == 0).toList();
    var completed = 0;
    while (ready.isNotEmpty) {
      final tag = ready.removeLast();
      completed++;
      for (final parent in dependents[tag] ?? const <String>[]) {
        degree[parent] = degree[parent]! - 1;
        if (degree[parent] == 0) ready.add(parent);
      }
    }
    if (completed != configs.length) {
      throw const SubscriptionServerExportException();
    }
    return {'outbounds': configs};
  }

  static Iterable<String> _references(Outbound node) {
    final references = node.config['outbounds'];
    return references is List ? references.whereType<String>() : const [];
  }

  static bool _isProxyLeaf(Outbound node) =>
      node.type != 'direct' && node.type != 'block' && node.type != 'dns';
}

class SubscriptionServerExportException implements Exception {
  const SubscriptionServerExportException();
}
