/// Both success and failure are reusable terminal results, but never a
/// persisted ping without a runtime timestamp or a previous network's result.
bool latencyResultIsFresh({
  required bool? result,
  required int? measuredAtSeconds,
  required int nowSeconds,
  required int maxAgeSeconds,
  required bool invalidated,
}) {
  if (invalidated ||
      result == null ||
      measuredAtSeconds == null ||
      measuredAtSeconds <= 0 ||
      maxAgeSeconds <= 0) {
    return false;
  }
  final age = nowSeconds - measuredAtSeconds;
  return age >= -5 && age <= maxAgeSeconds;
}

/// Includes every ancestor of a changed leaf, even when its children are
/// intentionally hidden from the proxy list. Cycles are harmless here.
Set<String> latencyAffectedTags(
  Iterable<String> changed,
  Map<String, Iterable<String>> groups,
) => LatencyDependencyIndex(groups).affectedTags(changed);

/// Builds the reverse group edges once for a subscription, then resolves each
/// URLTest result without scanning every provider and child again.
class LatencyDependencyIndex {
  LatencyDependencyIndex(Map<String, Iterable<String>> groups) {
    for (final entry in groups.entries) {
      for (final child in entry.value) {
        (_parents[child] ??= []).add(entry.key);
      }
    }
  }

  final Map<String, List<String>> _parents = {};

  Set<String> affectedTags(Iterable<String> changed) {
    final affected = changed.toSet();
    final queue = affected.toList();
    for (var index = 0; index < queue.length; index++) {
      for (final parent in _parents[queue[index]] ?? const <String>[]) {
        if (affected.add(parent)) queue.add(parent);
      }
    }
    return affected;
  }
}

/// Uses the actual runtime probe set when it is larger than the visible list.
/// Provider candidates may be hidden in the UI but still occupy URLTest queue
/// slots and therefore must be included in the background session deadline.
int latencySessionOutboundCount({
  required int visibleOutboundCount,
  required Iterable<String> runtimeOutboundTags,
}) {
  final runtimeCount = runtimeOutboundTags
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .length;
  return runtimeCount > visibleOutboundCount
      ? runtimeCount
      : visibleOutboundCount;
}

/// Resolves nested auto groups without confusing the visible group tag with
/// the concrete tag used by the native test queue.
String? latencyTargetTag(String tag, Map<String, String> selections) {
  final visited = <String>{};
  var current = tag.trim();
  while (current.isNotEmpty && visited.add(current)) {
    final next = selections[current]?.trim();
    if (next == null || next.isEmpty) return current;
    current = next;
  }
  return null;
}

/// A group-row check probes its concrete children, never synthetic group tags.
/// The set also prevents duplicate probes and breaks malformed group cycles.
List<String> latencyConcreteGroupTags(
  String groupTag,
  Map<String, Iterable<String>> groups,
  Set<String> visibleTags,
) {
  final visitedGroups = <String>{};
  final result = <String>{};
  void visit(String tag) {
    final children = groups[tag];
    if (children != null) {
      if (!visitedGroups.add(tag)) return;
      for (final child in children) {
        visit(child);
      }
    } else if (visibleTags.contains(tag)) {
      result.add(tag);
    }
  }

  visit(groupTag);
  return result.toList(growable: false);
}
