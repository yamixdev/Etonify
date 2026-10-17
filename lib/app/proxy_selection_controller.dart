import 'dart:async';

import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/core/proxy_selection_catalog.dart';
import 'package:meow_client/models/subscription.dart';

class ProxySelectionTimeout {
  const ProxySelectionTimeout({
    required this.generation,
    required this.tag,
    required this.previousTag,
  });

  final int generation;
  final String tag;
  final String? previousTag;
}

class ProxySelectionController {
  static const defaultConfirmationTimeout = Duration(seconds: 12);

  static String? rootSelectionFromSnapshot(
    Map<String, dynamic> snapshot, {
    required int runtimeGeneration,
  }) {
    if (runtimeGeneration <= 0 ||
        snapshot['runtimeGeneration'] != runtimeGeneration) {
      return null;
    }
    final selections = snapshot['selectedOutbounds'];
    if (selections is! Map || selections['select'] is! String) return null;
    final root = (selections['select'] as String).trim();
    return root.isEmpty ? null : root;
  }

  int _generation = 0;
  Future<void> _persistenceQueue = Future<void>.value();
  String? _pendingRuntimeSelectTag;
  String? _pendingRuntimeSelectPreviousTag;
  Timer? _pendingRuntimeSelectTimer;
  String? _confirmedRuntimeTag;
  bool _runtimeSelectionUnconfirmed = false;
  bool _pendingRuntimeSelectionIsStartGuard = false;

  int get generation => _generation;
  String? get pendingRuntimeSelectTag => _pendingRuntimeSelectTag;
  String? get pendingRuntimeSelectPreviousTag =>
      _pendingRuntimeSelectPreviousTag;
  bool get hasPendingRuntimeSelection => _pendingRuntimeSelectTag != null;
  bool get pendingRuntimeSelectionIsStartGuard =>
      _pendingRuntimeSelectionIsStartGuard;
  String? get confirmedRuntimeTag => _confirmedRuntimeTag;
  bool get runtimeSelectionUnconfirmed => _runtimeSelectionUnconfirmed;

  bool resolveRuntimeSelection({required int generation, String? actualTag}) {
    if (!isCurrentGeneration(generation)) return false;
    final normalized = actualTag?.trim();
    _confirmedRuntimeTag = normalized == null || normalized.isEmpty
        ? null
        : normalized;
    _runtimeSelectionUnconfirmed = _confirmedRuntimeTag == null;
    _clearPendingRuntimeSelection();
    return true;
  }

  void dispose() {
    _pendingRuntimeSelectTimer?.cancel();
  }

  int beginLocalSelection() {
    _generation++;
    _confirmedRuntimeTag = null;
    _runtimeSelectionUnconfirmed = false;
    _clearPendingRuntimeSelection();
    return _generation;
  }

  int beginRuntimeSelection({
    required String tag,
    required String previousTag,
    required void Function(ProxySelectionTimeout timeout) onTimeout,
    Duration confirmationTimeout = defaultConfirmationTimeout,
  }) {
    final generation = ++_generation;
    _runtimeSelectionUnconfirmed = false;
    _setPendingRuntimeSelection(
      generation: generation,
      tag: tag,
      previousTag: previousTag,
      onTimeout: onTimeout,
      confirmationTimeout: confirmationTimeout,
    );
    return generation;
  }

  int guardCurrentSelectionForRuntime({
    required String tag,
    required String previousTag,
    required void Function(ProxySelectionTimeout timeout) onTimeout,
    Duration confirmationTimeout = defaultConfirmationTimeout,
  }) {
    final generation = _generation;
    _setPendingRuntimeSelection(
      generation: generation,
      tag: tag,
      previousTag: previousTag,
      onTimeout: onTimeout,
      confirmationTimeout: confirmationTimeout,
      isStartGuard: true,
    );
    return generation;
  }

  Future<void> enqueuePersistence({
    required int generation,
    required Future<void> Function() action,
  }) {
    final operation = _persistenceQueue.then((_) async {
      if (!isCurrentGeneration(generation)) {
        return;
      }
      await action();
    });
    _persistenceQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> waitForPersistence() async {
    while (true) {
      final pending = _persistenceQueue;
      await pending;
      if (identical(pending, _persistenceQueue)) {
        return;
      }
    }
  }

  void _setPendingRuntimeSelection({
    required int generation,
    required String tag,
    required String previousTag,
    required void Function(ProxySelectionTimeout timeout) onTimeout,
    required Duration confirmationTimeout,
    bool isStartGuard = false,
  }) {
    _runtimeSelectionUnconfirmed = false;
    _pendingRuntimeSelectionIsStartGuard = isStartGuard;
    _pendingRuntimeSelectTag = tag;
    _pendingRuntimeSelectPreviousTag = previousTag;
    _pendingRuntimeSelectTimer?.cancel();
    _pendingRuntimeSelectTimer = Timer(confirmationTimeout, () {
      if (_generation != generation || _pendingRuntimeSelectTag != tag) {
        return;
      }
      onTimeout(
        ProxySelectionTimeout(
          generation: generation,
          tag: tag,
          previousTag: _pendingRuntimeSelectPreviousTag,
        ),
      );
    });
  }

  bool clearRuntimeSelection({int? generation}) {
    if (generation != null && generation != _generation) {
      return false;
    }
    final hadPending = hasPendingRuntimeSelection;
    _clearPendingRuntimeSelection();
    return hadPending;
  }

  bool isCurrentGeneration(int generation) => generation == _generation;

  Subscription withSelectedOutbound(Subscription subscription, String tag) {
    return subscription.copyWith(
      selectedProxyTag: normalizeProxySelectionTag(tag),
    );
  }

  List<Subscription> replaceSubscription(
    List<Subscription> subscriptions,
    Subscription updated,
  ) {
    return subscriptions
        .map(
          (subscription) =>
              subscription.id == updated.id ? updated : subscription,
        )
        .toList(growable: false);
  }

  String validSelectedProxyTagForSubscription(
    Subscription subscription,
    String preferredTag,
  ) {
    final normalized = normalizeProxySelectionTag(preferredTag);
    final proxyChainTags = subscription.proxyChains
        .map((chain) => chain.tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    if (proxyChainTags.contains(normalized)) {
      return normalized;
    }
    return ProxySelectionCatalog(
      subscription.outbounds,
      subscription.groups,
    ).resolveSelection(normalized);
  }

  static String effectiveSelectedProxyTag({
    required String metadataSelectedProxyTag,
    required String preferredSelectedProxyTag,
    required bool preferPreferred,
  }) {
    final preferred = normalizeProxySelectionTag(preferredSelectedProxyTag);
    final metadata = normalizeProxySelectionTag(metadataSelectedProxyTag);
    if (preferPreferred && preferred.isNotEmpty) {
      return preferred;
    }
    if (metadata.isNotEmpty) {
      return metadata;
    }
    return preferred;
  }

  bool runtimeSelectionUpdatesAllowed({
    required bool connected,
    required bool connectionStable,
    required bool transitionInProgress,
  }) {
    return connected && connectionStable && !transitionInProgress;
  }

  void _clearPendingRuntimeSelection() {
    _pendingRuntimeSelectionIsStartGuard = false;
    _pendingRuntimeSelectTimer?.cancel();
    _pendingRuntimeSelectTimer = null;
    _pendingRuntimeSelectTag = null;
    _pendingRuntimeSelectPreviousTag = null;
  }
}
