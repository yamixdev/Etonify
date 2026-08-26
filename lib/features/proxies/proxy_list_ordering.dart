import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';

typedef ProxyRuntimeStateResolver =
    ProxyRuntimeVisualState? Function(String tag);

void sortProxySummaries(
  List<AppProxySummary> items,
  ProxySort sort, {
  bool keepPinnedFirst = true,
  ProxyRuntimeStateResolver? runtimeStateFor,
}) {
  if (sort == ProxySort.source || items.length < 2) {
    return;
  }

  // Resolve mutable runtime state and pinned ranks once per row. A comparator
  // is invoked O(N log N) times, so doing these lookups from inside it makes a
  // mass URLTest needlessly expensive for large subscriptions.
  final prepared = List<_PreparedProxySort>.generate(
    items.length,
    (index) => _PreparedProxySort(
      items[index],
      sort: sort,
      keepPinnedFirst: keepPinnedFirst,
      runtimeState: sort == ProxySort.latency || sort == ProxySort.working
          ? runtimeStateFor?.call(items[index].tag)
          : null,
    ),
    growable: false,
  );
  prepared.sort((a, b) => a.compareTo(b, sort));
  for (var index = 0; index < items.length; index++) {
    items[index] = prepared[index].proxy;
  }
}

class _PreparedProxySort {
  _PreparedProxySort(
    this.proxy, {
    required ProxySort sort,
    required bool keepPinnedFirst,
    required ProxyRuntimeVisualState? runtimeState,
  }) : pinned = keepPinnedFirst && isPinnedProxyTag(proxy.tag),
       pinnedOrder = keepPinnedFirst ? pinnedProxyTagOrder(proxy.tag) : 0,
       latencyRank = sort == ProxySort.latency || sort == ProxySort.working
           ? _latencyRank(proxy, runtimeState)
           : 0,
       latency = runtimeState == null ? proxy.latency : runtimeState.latency;

  final AppProxySummary proxy;
  final bool pinned;
  final int pinnedOrder;
  final int latencyRank;
  final int? latency;

  int compareTo(_PreparedProxySort other, ProxySort sort) {
    if (pinned && other.pinned) {
      return pinnedOrder.compareTo(other.pinnedOrder);
    }
    if (pinned) {
      return -1;
    }
    if (other.pinned) {
      return 1;
    }

    return switch (sort) {
      ProxySort.source => 0,
      ProxySort.name => proxy.displayName.compareTo(other.proxy.displayName),
      ProxySort.country => proxy.countryCode.compareTo(other.proxy.countryCode),
      ProxySort.latency || ProxySort.working => _compareLatencyTo(other),
    };
  }

  int _compareLatencyTo(_PreparedProxySort other) {
    final rankOrder = latencyRank.compareTo(other.latencyRank);
    if (rankOrder != 0) {
      return rankOrder;
    }
    if (latencyRank == 0 || latencyRank == 2) {
      final latencyOrder = (latency ?? 1 << 30).compareTo(
        other.latency ?? 1 << 30,
      );
      if (latencyOrder != 0) {
        return latencyOrder;
      }
    }
    return proxy.displayName.compareTo(other.proxy.displayName);
  }
}

int compareProxySummaries(
  AppProxySummary a,
  AppProxySummary b, {
  required ProxySort sort,
  bool keepPinnedFirst = true,
  ProxyRuntimeStateResolver? runtimeStateFor,
}) {
  final pinnedOrder = _comparePinned(a, b, keepPinnedFirst);
  if (pinnedOrder != null) {
    return pinnedOrder;
  }
  return switch (sort) {
    ProxySort.source => 0,
    ProxySort.name => a.displayName.compareTo(b.displayName),
    ProxySort.country => a.countryCode.compareTo(b.countryCode),
    ProxySort.latency => _compareLatency(
      a,
      b,
      aState: runtimeStateFor?.call(a.tag),
      bState: runtimeStateFor?.call(b.tag),
    ),
    ProxySort.working => _compareLatency(
      a,
      b,
      aState: runtimeStateFor?.call(a.tag),
      bState: runtimeStateFor?.call(b.tag),
    ),
  };
}

/// The "working only" mode deliberately hides only a server that URLTest has
/// confirmed as unavailable. Untested and in-progress rows stay visible, so a
/// newly imported subscription never looks empty before its first check.
bool shouldShowProxyForSort(
  AppProxySummary proxy,
  ProxySort sort, {
  ProxyRuntimeVisualState? runtimeState,
}) {
  if (sort != ProxySort.working) {
    return true;
  }
  return !(runtimeState?.latencyUnavailable ?? proxy.latencyUnavailable);
}

int _compareLatency(
  AppProxySummary a,
  AppProxySummary b, {
  ProxyRuntimeVisualState? aState,
  ProxyRuntimeVisualState? bState,
}) {
  final aRank = _latencyRank(a, aState);
  final bRank = _latencyRank(b, bState);
  final rankOrder = aRank.compareTo(bRank);
  if (rankOrder != 0) {
    return rankOrder;
  }
  if (aRank == 0 || aRank == 2) {
    final aLatency = aState == null ? a.latency : aState.latency;
    final bLatency = bState == null ? b.latency : bState.latency;
    final latencyOrder = (aLatency ?? 1 << 30).compareTo(bLatency ?? 1 << 30);
    if (latencyOrder != 0) {
      return latencyOrder;
    }
  }
  return a.displayName.compareTo(b.displayName);
}

int? _comparePinned(
  AppProxySummary a,
  AppProxySummary b,
  bool keepPinnedFirst,
) {
  if (!keepPinnedFirst) {
    return null;
  }
  final aPinned = isPinnedProxyTag(a.tag);
  final bPinned = isPinnedProxyTag(b.tag);
  if (aPinned && bPinned) {
    return pinnedProxyTagOrder(a.tag).compareTo(pinnedProxyTagOrder(b.tag));
  }
  if (aPinned) {
    return -1;
  }
  if (bPinned) {
    return 1;
  }
  return null;
}

int _latencyRank(AppProxySummary proxy, ProxyRuntimeVisualState? runtimeState) {
  final checking = runtimeState?.latencyChecking ?? proxy.latencyChecking;
  final unavailable =
      runtimeState?.latencyUnavailable ?? proxy.latencyUnavailable;
  final fresh = runtimeState?.latencyFresh ?? proxy.latencyFresh;
  final latency = runtimeState == null ? proxy.latency : runtimeState.latency;
  if (checking) {
    return 1;
  }
  if (unavailable) {
    return 4;
  }
  if (fresh && latency != null) {
    return 0;
  }
  if (latency != null) {
    return 2;
  }
  return 3;
}
