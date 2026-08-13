import 'package:flutter/foundation.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/models/subscription.dart';

typedef StaleLatencyResultFilter = bool Function(String tag, int timeSeconds);

class ProxyRuntimeGroupUpdateInput {
  const ProxyRuntimeGroupUpdateInput({
    required this.rawGroups,
    required this.activeSubscription,
    required this.selectedProxyTag,
    required this.pendingRuntimeSelectTag,
    required this.currentResolvedActiveOutboundTag,
    required this.activeOutboundTags,
    required this.latencySessionRunning,
    required this.shouldIgnoreLatencyResult,
    required this.proxyCacheContainsTag,
    required this.visibleGroupProxyCacheMissingChild,
  });

  final List<dynamic> rawGroups;
  final Subscription activeSubscription;
  final String selectedProxyTag;
  final String? pendingRuntimeSelectTag;
  final String? currentResolvedActiveOutboundTag;
  final Set<String> activeOutboundTags;
  final bool latencySessionRunning;
  final StaleLatencyResultFilter shouldIgnoreLatencyResult;
  final bool Function(String? tag) proxyCacheContainsTag;
  final bool Function(String groupTag, String childTag)
  visibleGroupProxyCacheMissingChild;
}

class ProxyRuntimeGroupUpdateResult {
  const ProxyRuntimeGroupUpdateResult({
    required this.changed,
    required this.requiresRootRebuild,
    required this.shouldRebuildProxyCache,
    required this.shouldClearRuntimeProxySelectionGuard,
    required this.realOutboundRuntimeStateChanged,
  });

  static const noChanges = ProxyRuntimeGroupUpdateResult(
    changed: false,
    requiresRootRebuild: false,
    shouldRebuildProxyCache: false,
    shouldClearRuntimeProxySelectionGuard: false,
    realOutboundRuntimeStateChanged: false,
  );

  final bool changed;
  final bool requiresRootRebuild;
  final bool shouldRebuildProxyCache;
  final bool shouldClearRuntimeProxySelectionGuard;
  final bool realOutboundRuntimeStateChanged;
}

class ProxyRuntimeController {
  static const urlTestStatusUnavailable = 'unavailable';

  static bool effectiveLatencyUnavailable({
    required bool urlTestUnavailable,
    required bool endpointFallbackReachable,
  }) {
    // Endpoint probing only proves that the host:port accepted a TCP socket.
    // It must not turn a failed sing-box URLTest into a healthy proxy ping:
    // VLESS/Trojan TLS/Reality/WS can still fail after the port opens.
    return urlTestUnavailable;
  }

  static String? effectiveLatencyError({
    required String? urlTestError,
    required bool endpointFallbackReachable,
  }) {
    return urlTestError;
  }

  int? lowestLatency;
  String? runtimeLowestOutboundTag;
  final Map<String, String> runtimeLowestSelections = <String, String>{};
  final Map<String, int> runtimeLatencies = <String, int>{};
  final Map<String, int> runtimeLatencyTimes = <String, int>{};
  final Set<String> unavailableLatencyTags = <String>{};
  final Set<String> invalidatedLatencyTags = <String>{};
  final Map<String, String> latencyErrors = <String, String>{};
  final Map<String, int> latencyFailureCounts = <String, int>{};
  final Map<String, String> runtimeGroupSelections = <String, String>{};

  bool _updatesFrozen = false;

  bool get updatesFrozen => _updatesFrozen;

  void dispose() {}

  void beginTransition() {
    if (_updatesFrozen) {
      return;
    }
    _updatesFrozen = true;
    AppLogStore.info(
      'proxy',
      'urlTest updates frozen during runtime transition',
    );
  }

  void endTransition() {
    if (!_updatesFrozen) {
      return;
    }
    _updatesFrozen = false;
    AppLogStore.info(
      'proxy',
      'urlTest updates unfrozen after runtime transition',
    );
  }

  void reset() {
    _updatesFrozen = false;
    runtimeLatencies.clear();
    runtimeLatencyTimes.clear();
    unavailableLatencyTags.clear();
    invalidatedLatencyTags.clear();
    latencyErrors.clear();
    latencyFailureCounts.clear();
    runtimeGroupSelections.clear();
    runtimeLowestSelections.clear();
    lowestLatency = null;
    runtimeLowestOutboundTag = null;
  }

  /// Drops measurements that belong to a previous Android network while
  /// keeping selector choices intact. Until fresh URLTest telemetry arrives,
  /// callers must not fall back to the persisted ping for these tags.
  bool invalidateNetworkMeasurements(
    Iterable<String> tags, {
    bool preserveUnrelatedMeasurements = false,
  }) {
    final nextInvalidatedTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    if (preserveUnrelatedMeasurements) {
      var changed = false;
      for (final tag in nextInvalidatedTags) {
        changed = runtimeLatencies.remove(tag) != null || changed;
        changed = runtimeLatencyTimes.remove(tag) != null || changed;
        changed = unavailableLatencyTags.remove(tag) || changed;
        changed = latencyErrors.remove(tag) != null || changed;
        changed = latencyFailureCounts.remove(tag) != null || changed;
        changed = invalidatedLatencyTags.add(tag) || changed;
      }
      if (nextInvalidatedTags.contains(runtimeLowestOutboundTag)) {
        lowestLatency = null;
      }
      return changed;
    }
    final changed =
        runtimeLatencies.isNotEmpty ||
        runtimeLatencyTimes.isNotEmpty ||
        unavailableLatencyTags.isNotEmpty ||
        latencyErrors.isNotEmpty ||
        latencyFailureCounts.isNotEmpty ||
        lowestLatency != null ||
        !setEquals(invalidatedLatencyTags, nextInvalidatedTags);

    runtimeLatencies.clear();
    runtimeLatencyTimes.clear();
    unavailableLatencyTags.clear();
    invalidatedLatencyTags
      ..clear()
      ..addAll(nextInvalidatedTags);
    latencyErrors.clear();
    latencyFailureCounts.clear();
    lowestLatency = null;
    return changed;
  }

  bool isLatencyInvalidated(String tag) {
    return invalidatedLatencyTags.contains(tag.trim());
  }

  String? runtimeLowestOutboundTagFor(String lowestTag) {
    final selected = runtimeLowestSelections[lowestTag];
    if (selected != null && selected.isNotEmpty) {
      return selected;
    }
    if (lowestTag == lowestProxyTag) {
      return runtimeLowestOutboundTag;
    }
    return null;
  }

  ProxyRuntimeGroupUpdateResult applyGroupUpdates(
    ProxyRuntimeGroupUpdateInput input,
  ) {
    final rawGroups = input.rawGroups;
    if (rawGroups.isEmpty) {
      return ProxyRuntimeGroupUpdateResult.noChanges;
    }
    if (_updatesFrozen) {
      AppLogStore.debug(
        'proxy',
        'ignored URLTest group update while runtime transition is active '
            'groups=${rawGroups.length}',
      );
      return ProxyRuntimeGroupUpdateResult.noChanges;
    }

    final delays = <String, int?>{};
    final statuses = <String, String>{};
    final errors = <String, String>{};
    final times = Map<String, int>.from(runtimeLatencyTimes);
    String? runtimeSelected;
    final subscriptionGroupTags = input.activeSubscription.groups
        .map((group) => group.tag)
        .toSet();
    final groupSelections = Map<String, String>.fromEntries(
      runtimeGroupSelections.entries.where(
        (entry) => subscriptionGroupTags.contains(entry.key),
      ),
    );
    final lowestSelections = Map<String, String>.fromEntries(
      runtimeLowestSelections.entries.where(
        (entry) => isLowestProxyTag(entry.key),
      ),
    );

    for (final rawGroup in rawGroups) {
      if (rawGroup is! Map) {
        continue;
      }
      final group = Map<String, dynamic>.from(rawGroup);
      final tag = group['tag']?.toString() ?? '';
      if (tag == 'select') {
        runtimeSelected = group['selected']?.toString();
      } else if (isLowestProxyTag(tag)) {
        final selected = group['selected']?.toString() ?? '';
        if (selected.isNotEmpty && !isLowestProxyTag(selected)) {
          lowestSelections[tag] = selected;
        } else {
          lowestSelections.remove(tag);
        }
      } else if (subscriptionGroupTags.contains(tag)) {
        final selected = group['selected']?.toString() ?? '';
        if (selected.isNotEmpty) {
          groupSelections[tag] = selected;
        }
      }
      final items = (group['items'] as List?) ?? const [];
      for (final rawItem in items) {
        if (rawItem is! Map) {
          continue;
        }
        final item = Map<String, dynamic>.from(rawItem);
        final itemTag = item['tag']?.toString() ?? '';
        if (itemTag.isEmpty || isLowestProxyTag(itemTag)) {
          continue;
        }
        final status = (item['status']?.toString() ?? '').trim().toLowerCase();
        final error = (item['error']?.toString() ?? '').trim();
        final delay = (item['delay'] as num?)?.toInt();
        final time = (item['time'] as num?)?.toInt();
        final currentTime = times[itemTag];
        final nextTime = time != null && time > 0 ? time : null;
        final positiveDelay = delay != null && delay > 0;
        final terminalFailure =
            status == urlTestStatusUnavailable ||
            (error.isNotEmpty && !positiveDelay);
        if (nextTime != null &&
            (positiveDelay || terminalFailure) &&
            input.shouldIgnoreLatencyResult(itemTag, nextTime)) {
          continue;
        }
        final hasTerminalTelemetry = positiveDelay || terminalFailure;
        final stateChangedWithoutTimestamp =
            nextTime == null &&
            terminalFailure &&
            (!unavailableLatencyTags.contains(itemTag) ||
                latencyErrors[itemTag] !=
                    (error.isNotEmpty ? error : 'URL test failed'));
        final shouldReplace = hasTerminalTelemetry
            ? (nextTime != null
                  ? currentTime == null || nextTime > currentTime
                  : stateChangedWithoutTimestamp)
            : true;
        if (!shouldReplace) {
          continue;
        }
        if (status.isNotEmpty) {
          statuses[itemTag] = status;
        } else {
          statuses.remove(itemTag);
        }
        if (error.isNotEmpty) {
          errors[itemTag] = error;
        } else {
          errors.remove(itemTag);
        }
        if (nextTime != null && (positiveDelay || terminalFailure)) {
          times[itemTag] = nextTime;
        }
        delays[itemTag] = delay != null && delay > 0 ? delay : null;
      }
    }

    _logUrlTestGroupUpdateSummary(
      groupCount: rawGroups.length,
      delays: delays,
      statuses: statuses,
      errors: errors,
      runtimeSelected: runtimeSelected,
      activeOutboundTag: input.currentResolvedActiveOutboundTag,
      latencySessionRunning: input.latencySessionRunning,
    );

    if (delays.isEmpty &&
        statuses.isEmpty &&
        runtimeSelected == null &&
        mapEquals(runtimeLowestSelections, lowestSelections) &&
        mapEquals(runtimeGroupSelections, groupSelections)) {
      return ProxyRuntimeGroupUpdateResult.noChanges;
    }

    final nextRuntimeLatencies = Map<String, int>.from(runtimeLatencies);
    final nextRuntimeLatencyTimes = Map<String, int>.from(runtimeLatencyTimes);
    final nextUnavailableLatencyTags = Set<String>.from(unavailableLatencyTags);
    final nextInvalidatedLatencyTags = Set<String>.from(invalidatedLatencyTags);
    final nextLatencyErrors = Map<String, String>.from(latencyErrors);
    final nextLatencyFailureCounts = Map<String, int>.from(
      latencyFailureCounts,
    );
    final touchedTags = <String>{
      ...delays.keys,
      ...statuses.keys,
      ...errors.keys,
    };
    for (final tag in touchedTags) {
      final status = statuses[tag];
      final delay = delays[tag];
      final hasPositiveDelay = delay != null && delay > 0;
      final error = errors[tag]?.trim() ?? '';
      final terminalFailure =
          status == urlTestStatusUnavailable ||
          (error.isNotEmpty && !hasPositiveDelay);
      if (terminalFailure) {
        nextInvalidatedLatencyTags.remove(tag);
        final failureCount = (nextLatencyFailureCounts[tag] ?? 0) + 1;
        nextLatencyFailureCounts[tag] = failureCount;
        nextRuntimeLatencies.remove(tag);
        nextUnavailableLatencyTags.add(tag);
        nextLatencyErrors[tag] = error.isNotEmpty ? error : 'URL test failed';
        final time = times[tag];
        if (time != null) {
          nextRuntimeLatencyTimes[tag] = time;
        }
        continue;
      }
      if (hasPositiveDelay) {
        nextInvalidatedLatencyTags.remove(tag);
        nextRuntimeLatencies[tag] = delay;
        nextUnavailableLatencyTags.remove(tag);
        nextLatencyErrors.remove(tag);
        nextLatencyFailureCounts.remove(tag);
        final time = times[tag];
        if (time != null) {
          nextRuntimeLatencyTimes[tag] = time;
        }
      }
    }

    // Do not keep presenting a child that the same URLTest update has already
    // marked unavailable. For nested provider groups, validate the confirmed
    // leaf selection rather than only the group tag.
    lowestSelections.removeWhere((_, selectedTag) {
      final selectedLeaf = groupSelections[selectedTag];
      final effectiveTag = selectedLeaf != null && selectedLeaf.isNotEmpty
          ? selectedLeaf
          : selectedTag;
      return nextUnavailableLatencyTags.contains(effectiveTag) ||
          nextLatencyErrors.containsKey(effectiveTag);
    });

    final nextLowestLatency = _computeLowestLatency(
      nextRuntimeLatencies,
      nextUnavailableLatencyTags,
    );

    final pendingRuntimeSelectTag = input.pendingRuntimeSelectTag;
    // The app owns the persisted `select` choice. Native status is used only
    // to confirm a user action; a URLTest group's background failover must not
    // silently replace a manually selected outbound in the profile.
    final runtimeSelectionConfirmsPending =
        pendingRuntimeSelectTag != null &&
        runtimeSelected == pendingRuntimeSelectTag;
    final runtimeSelectionIsStaleDuringPending =
        pendingRuntimeSelectTag != null &&
        runtimeSelected != null &&
        runtimeSelected.isNotEmpty &&
        runtimeSelected != pendingRuntimeSelectTag &&
        input.selectedProxyTag == pendingRuntimeSelectTag;
    if (runtimeSelectionIsStaleDuringPending) {
      AppLogStore.info(
        'proxy',
        'ignored stale runtime selected outbound tag=$runtimeSelected '
            'while pending tag=$pendingRuntimeSelectTag',
      );
    }

    final latencyStateChanged =
        lowestLatency != nextLowestLatency ||
        !mapEquals(runtimeLatencies, nextRuntimeLatencies) ||
        !mapEquals(runtimeLatencyTimes, nextRuntimeLatencyTimes) ||
        !setEquals(unavailableLatencyTags, nextUnavailableLatencyTags) ||
        !setEquals(invalidatedLatencyTags, nextInvalidatedLatencyTags) ||
        !mapEquals(latencyErrors, nextLatencyErrors) ||
        !mapEquals(latencyFailureCounts, nextLatencyFailureCounts) ||
        !mapEquals(runtimeLowestSelections, lowestSelections) ||
        !mapEquals(runtimeGroupSelections, groupSelections);
    final realOutboundRuntimeStateChanged =
        touchedTags.any(input.activeOutboundTags.contains) ||
        !mapEquals(runtimeLowestSelections, lowestSelections) ||
        !mapEquals(runtimeGroupSelections, groupSelections);

    if (!runtimeSelectionConfirmsPending && !latencyStateChanged) {
      return ProxyRuntimeGroupUpdateResult.noChanges;
    }

    final nextRuntimeLowestOutboundTag = lowestSelections[lowestProxyTag];
    final shouldRebuildProxyCache =
        lowestSelections.values.any(
          (tag) => !input.proxyCacheContainsTag(tag),
        ) ||
        groupSelections.entries.any(
          (entry) =>
              input.visibleGroupProxyCacheMissingChild(entry.key, entry.value),
        );
    final lowestSelectionsChanged = !mapEquals(
      runtimeLowestSelections,
      lowestSelections,
    );
    final groupSelectionsChanged = !mapEquals(
      runtimeGroupSelections,
      groupSelections,
    );
    final requiresRootRebuild =
        lowestSelectionsChanged || groupSelectionsChanged;

    runtimeLatencies
      ..clear()
      ..addAll(nextRuntimeLatencies);
    runtimeLatencyTimes
      ..clear()
      ..addAll(nextRuntimeLatencyTimes);
    unavailableLatencyTags
      ..clear()
      ..addAll(nextUnavailableLatencyTags);
    invalidatedLatencyTags
      ..clear()
      ..addAll(nextInvalidatedLatencyTags);
    latencyErrors
      ..clear()
      ..addAll(nextLatencyErrors);
    latencyFailureCounts
      ..clear()
      ..addAll(nextLatencyFailureCounts);
    runtimeGroupSelections
      ..clear()
      ..addAll(groupSelections);
    runtimeLowestSelections
      ..clear()
      ..addAll(lowestSelections);
    lowestLatency = nextLowestLatency;
    runtimeLowestOutboundTag = nextRuntimeLowestOutboundTag;
    return ProxyRuntimeGroupUpdateResult(
      changed: true,
      requiresRootRebuild: requiresRootRebuild,
      shouldRebuildProxyCache: shouldRebuildProxyCache,
      shouldClearRuntimeProxySelectionGuard: runtimeSelectionConfirmsPending,
      realOutboundRuntimeStateChanged: realOutboundRuntimeStateChanged,
    );
  }

  static int? _computeLowestLatency(
    Map<String, int> latencies,
    Set<String> unavailableTags,
  ) {
    int? result;
    for (final entry in latencies.entries) {
      if (unavailableTags.contains(entry.key)) {
        continue;
      }
      if (result == null || entry.value < result) {
        result = entry.value;
      }
    }
    return result;
  }

  void _logUrlTestGroupUpdateSummary({
    required int groupCount,
    required Map<String, int?> delays,
    required Map<String, String> statuses,
    required Map<String, String> errors,
    required String? runtimeSelected,
    required String? activeOutboundTag,
    required bool latencySessionRunning,
  }) {
    final positiveDelays = delays.entries
        .where((entry) => entry.value != null && entry.value! > 0)
        .toList();
    if (positiveDelays.isEmpty && !latencySessionRunning) {
      return;
    }
    MapEntry<String, int?>? minEntry;
    MapEntry<String, int?>? maxEntry;
    for (final entry in positiveDelays) {
      if (minEntry == null || entry.value! < minEntry.value!) {
        minEntry = entry;
      }
      if (maxEntry == null || entry.value! > maxEntry.value!) {
        maxEntry = entry;
      }
    }
    final maxDelay = maxEntry?.value ?? 0;
    if (!latencySessionRunning && maxDelay < 1000) {
      return;
    }
    final unavailableCount = statuses.values
        .where((status) => status == urlTestStatusUnavailable)
        .length;
    final errorSummary = errors.entries
        .take(4)
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
    final message =
        'urlTest group update groups=$groupCount '
        'delays=${positiveDelays.length}/${delays.length} '
        'min=${minEntry?.key ?? ''}:${minEntry?.value ?? ''} '
        'max=${maxEntry?.key ?? ''}:$maxDelay '
        'unavailable=$unavailableCount '
        'selected=${runtimeSelected ?? ''} '
        'active=${activeOutboundTag ?? ''}'
        '${errorSummary.isEmpty ? '' : ' errors=$errorSummary'}';
    if (maxDelay >= 1000) {
      AppLogStore.warning('proxy', message);
    } else {
      AppLogStore.info('proxy', message);
    }
  }
}
