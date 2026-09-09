/// Includes every ancestor of a changed leaf, even when its children are
/// intentionally hidden from the proxy list. Cycles are harmless here.
Set<String> latencyAffectedTags(
  Iterable<String> changed,
  Map<String, Iterable<String>> groups,
) {
  final parents = <String, List<String>>{};
  for (final entry in groups.entries) {
    for (final child in entry.value) {
      (parents[child] ??= []).add(entry.key);
    }
  }
  final affected = changed.toSet();
  final queue = affected.toList();
  for (var index = 0; index < queue.length; index++) {
    for (final parent in parents[queue[index]] ?? const <String>[]) {
      if (affected.add(parent)) queue.add(parent);
    }
  }
  return affected;
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
