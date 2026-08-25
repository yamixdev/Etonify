import 'package:flutter/foundation.dart';
import 'package:meow_client/models/app_view_models.dart';

typedef ProxyRuntimeVisualStateResolver =
    ProxyRuntimeVisualState? Function(String tag);

@immutable
class ProxyRuntimeVisualState {
  const ProxyRuntimeVisualState({
    this.latency,
    this.latencyFresh = false,
    this.latencyChecking = false,
    this.latencyUnavailable = false,
    this.latencyError,
    this.networkUnavailable = false,
    this.highlighted = false,
    this.selecting = false,
  });

  final int? latency;
  final bool latencyFresh;
  final bool latencyChecking;
  final bool latencyUnavailable;
  final String? latencyError;
  final bool networkUnavailable;
  final bool highlighted;
  final bool selecting;

  @override
  bool operator ==(Object other) {
    return other is ProxyRuntimeVisualState &&
        other.latency == latency &&
        other.latencyFresh == latencyFresh &&
        other.latencyChecking == latencyChecking &&
        other.latencyUnavailable == latencyUnavailable &&
        other.latencyError == latencyError &&
        other.networkUnavailable == networkUnavailable &&
        other.highlighted == highlighted &&
        other.selecting == selecting;
  }

  @override
  int get hashCode => Object.hash(
    latency,
    latencyFresh,
    latencyChecking,
    latencyUnavailable,
    latencyError,
    networkUnavailable,
    highlighted,
    selecting,
  );
}

class _TrackedProxyRuntimeNotifier
    extends ValueNotifier<ProxyRuntimeVisualState?> {
  _TrackedProxyRuntimeNotifier(super.value);

  int _listenerCount = 0;

  bool get observed => _listenerCount > 0;

  @override
  void addListener(VoidCallback listener) {
    _listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_listenerCount > 0) {
      _listenerCount--;
    }
    super.removeListener(listener);
  }
}

class ProxyRuntimeVisualStore {
  final Map<String, _TrackedProxyRuntimeNotifier> _notifiers =
      <String, _TrackedProxyRuntimeNotifier>{};
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);
  final Map<String, ProxyRuntimeVisualState> _states =
      <String, ProxyRuntimeVisualState>{};
  ProxyRuntimeVisualStateResolver? _resolver;
  Set<String> _pinnedTags = const <String>{};

  ValueListenable<int> get revision => _revision;

  ValueListenable<ProxyRuntimeVisualState?> listenableFor(String tag) {
    return _notifiers.putIfAbsent(tag, () {
      final resolved = _states[tag] ?? _resolver?.call(tag);
      if (resolved != null) {
        _states[tag] = resolved;
      }
      return _TrackedProxyRuntimeNotifier(resolved);
    });
  }

  /// Replaces the backing source without materializing visual state for every
  /// proxy. Only the active/pinned tags and rows that currently have listeners
  /// remain strongly retained.
  void replaceResolver(
    ProxyRuntimeVisualStateResolver resolver, {
    Iterable<String> pinnedTags = const <String>[],
  }) {
    _resolver = resolver;
    _pinnedTags = pinnedTags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    pruneUnobserved();

    final retainedTags = <String>{
      ..._pinnedTags,
      for (final entry in _notifiers.entries)
        if (entry.value.observed) entry.key,
    };
    final next = <String, ProxyRuntimeVisualState>{};
    for (final tag in retainedTags) {
      final state = resolver(tag);
      if (state != null) {
        next[tag] = state;
      }
    }
    _replaceRetainedStates(next);
  }

  void replaceAll(Map<String, ProxyRuntimeVisualState> next) {
    _resolver = null;
    _pinnedTags = next.keys.toSet();
    _replaceRetainedStates(next);
  }

  void _replaceRetainedStates(Map<String, ProxyRuntimeVisualState> next) {
    if (mapEquals(_states, next)) {
      return;
    }
    final previousKeys = _states.keys.toSet();
    _states
      ..clear()
      ..addAll(next);
    final changed = <String>{...previousKeys, ...next.keys};
    for (final tag in changed) {
      final notifier = _notifiers[tag];
      if (notifier == null) {
        continue;
      }
      final value = next[tag];
      if (notifier.value != value) {
        notifier.value = value;
      }
    }
    for (final tag
        in _notifiers.keys
            .where((tag) => !next.containsKey(tag))
            .toList(growable: false)) {
      final notifier = _notifiers[tag];
      if (notifier == null || notifier.observed || _pinnedTags.contains(tag)) {
        continue;
      }
      _notifiers.remove(tag)?.dispose();
    }
    _revision.value++;
  }

  /// Recomputes only currently observed or pinned tags. A global revision can
  /// still be published so latency/availability sorting sees the fresh source
  /// values without retaining one state object per proxy.
  void refreshTags(Iterable<String> tags, {bool notifyRevision = true}) {
    final resolver = _resolver;
    if (resolver == null) {
      return;
    }
    var changed = false;
    var hadTag = false;
    for (final rawTag in tags) {
      final tag = rawTag.trim();
      if (tag.isEmpty) {
        continue;
      }
      hadTag = true;
      final notifier = _notifiers[tag];
      final retained =
          _pinnedTags.contains(tag) || (notifier != null && notifier.observed);
      if (!retained) {
        _states.remove(tag);
        continue;
      }
      final next = resolver(tag);
      final previous = _states[tag];
      if (previous == next && (next != null || !_states.containsKey(tag))) {
        continue;
      }
      changed = true;
      if (next == null) {
        _states.remove(tag);
      } else {
        _states[tag] = next;
      }
      if (notifier != null && notifier.value != next) {
        notifier.value = next;
      }
    }
    pruneUnobserved();
    if (notifyRevision && (changed || hadTag)) {
      _revision.value++;
    }
  }

  /// Applies a small runtime delta without rebuilding visual state for every
  /// proxy. Network handovers commonly affect only the active route; replacing
  /// thousands of cached rows on that event blocks the UI thread.
  void updateTags(
    Map<String, ProxyRuntimeVisualState?> updates, {
    bool notifyRevision = true,
  }) {
    if (updates.isEmpty) {
      return;
    }
    var changed = false;
    for (final entry in updates.entries) {
      final tag = entry.key.trim();
      if (tag.isEmpty) {
        continue;
      }
      final next = entry.value;
      final previous = _states[tag];
      if (previous == next && (next != null || !_states.containsKey(tag))) {
        continue;
      }
      changed = true;
      if (next == null) {
        _states.remove(tag);
      } else {
        _states[tag] = next;
      }
      final notifier = _notifiers[tag];
      if (notifier != null && notifier.value != next) {
        notifier.value = next;
      }
    }
    if (changed && notifyRevision) {
      _revision.value++;
    }
  }

  ProxyRuntimeVisualState? valueFor(String tag) =>
      _states[tag] ?? _resolver?.call(tag);

  /// Releases rows that left the viewport. Their ValueNotifiers no longer
  /// have listeners after Flutter disposes the corresponding list elements.
  void pruneUnobserved({Iterable<String> additionalPinnedTags = const []}) {
    final keep = <String>{
      ..._pinnedTags,
      ...additionalPinnedTags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty),
    };
    final removable = _notifiers.entries
        .where((entry) => !entry.value.observed && !keep.contains(entry.key))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final tag in removable) {
      final notifier = _notifiers.remove(tag);
      _states.remove(tag);
      notifier?.dispose();
    }
    _states.removeWhere(
      (tag, _) => !keep.contains(tag) && !_notifiers.containsKey(tag),
    );
  }

  @visibleForTesting
  int get retainedNotifierCount => _notifiers.length;

  @visibleForTesting
  int get retainedStateCount => _states.length;

  void dispose() {
    for (final notifier in _notifiers.values) {
      notifier.dispose();
    }
    _notifiers.clear();
    _revision.dispose();
  }
}

AppProxySummary applyProxyRuntimeVisualState(
  AppProxySummary proxy,
  ProxyRuntimeVisualState? state,
) {
  if (state == null) {
    return proxy;
  }
  return proxy.copyWith(
    latency: state.latency,
    clearLatency: state.latency == null,
    latencyFresh: state.latencyFresh,
    latencyChecking: state.latencyChecking,
    latencyUnavailable: state.latencyUnavailable,
    latencyError: state.latencyError,
    clearLatencyError: state.latencyError == null,
    highlighted: state.highlighted,
  );
}
