import 'dart:async';

class StartupUrlTestLeaseExpired implements Exception {
  const StartupUrlTestLeaseExpired();

  @override
  String toString() => 'startup lease expired';
}

Future<bool> runStartupUrlTestHandoff({
  required int runtimeGeneration,
  required int networkGeneration,
  required List<String> coveredTags,
  required Future<Map<String, dynamic>> Function(List<String>) prepare,
  required bool Function() isCurrent,
  required Future<bool> Function(List<String>, int startupLeaseToken)
  runRemaining,
  void Function(Map<String, dynamic>)? acceptBorrowed,
  bool Function(Map<String, dynamic>)? acceptNativeSelection,
}) async {
  final tags = coveredTags
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();
  if (tags.isEmpty || !isCurrent()) return false;
  // Only a definitive dispatch fence permits one fresh ownership attempt.
  // A bridge timeout or an ordinary failed probe does not prove non-dispatch.
  for (var attempt = 0; attempt < 2 && isCurrent(); attempt++) {
    final Map<String, dynamic> reply;
    try {
      // Native bounds a borrowed probe by its deadline (at most 36 seconds).
      reply = await prepare(tags).timeout(const Duration(seconds: 40));
    } catch (_) {
      return false;
    }
    if (!isCurrent()) return false;
    if (reply.isNotEmpty &&
        (reply['valid'] != true ||
            reply['runtimeGeneration'] != runtimeGeneration ||
            reply['networkGeneration'] != networkGeneration)) {
      return false;
    }
    // Native may publish a selector change before the coalesced groups event
    // reaches Dart. Never exclude a borrowed leaf or dispatch stale coverage
    // until the caller has reconciled that authoritative selection.
    if (acceptNativeSelection?.call(reply) == false || !isCurrent()) {
      return false;
    }
    final borrowedTag = reply['borrowedTag']?.toString() ?? '';
    final borrowed = tags.contains(borrowedTag);
    final remaining = borrowed
        ? tags.where((tag) => tag != borrowedTag).toList()
        : tags;
    final hasResult =
        borrowed &&
        (reply['measuredAtMillis'] as num? ?? 0) > 0 &&
        (reply['revision'] as num? ?? 0) > 0 &&
        (reply['sessionId'] as num? ?? 0) > 0;
    final available =
        hasResult &&
        (reply['delayMillis'] as num? ?? 0) > 0 &&
        reply['status']?.toString().toLowerCase() != 'unavailable';
    if (hasResult) acceptBorrowed?.call(reply);
    if (!isCurrent()) return false;
    if (remaining.isEmpty) return available;
    try {
      final token = (reply['startupLeaseToken'] as num?)?.toInt() ?? 0;
      final success = await runRemaining(remaining, token);
      return isCurrent() && (success || available);
    } on StartupUrlTestLeaseExpired {
      // The coordinator propagates this only after it has released its UI,
      // timers and native-command slot. Re-prepare the *original* coverage.
      if (attempt != 0 || !isCurrent()) return false;
    } catch (_) {
      return false;
    }
  }
  return false;
}
