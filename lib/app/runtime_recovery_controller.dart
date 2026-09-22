import 'dart:async';

import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/singbox/runtime_start_error.dart';

class InvalidOutboundRecovery {
  const InvalidOutboundRecovery({required this.tag, required this.reason});

  final String tag;
  final String reason;
}

class RuntimeStartupValidation {
  const RuntimeStartupValidation({
    required this.canStart,
    required this.selectedProxyInvalid,
    this.warning,
  });

  final bool canStart;
  final bool selectedProxyInvalid;
  final String? warning;
}

/// Owns retry generations and the cached config used by invalid-outbound
/// recovery.
///
/// The controller deliberately does not start or stop the native runtime. It
/// only owns recovery state, so UI lifecycle code can invalidate stale work
/// without duplicating timers, maps and generation checks.
class RuntimeRecoveryController {
  RuntimeRecoveryController({
    this.retryDelay = const Duration(milliseconds: 300),
  });

  final Duration retryDelay;

  Timer? _retryTimer;
  bool _retryScheduled = false;
  int _retryGeneration = 0;
  final Set<String> _excludedOutboundTags = <String>{};
  Map<int, String>? _proxyOutboundTagsByIndex;
  Map<String, dynamic>? _lastStartedConfig;
  Set<String> _lastStartedUrlTestOutboundTags = <String>{};

  /// Tags excluded from the running set but still present in
  /// [_lastStartedConfig], i.e. not yet removed by a mutation or a rebuild.
  final Set<String> _pendingMutationExcludedTags = <String>{};
  String? _mutationTagInFlight;
  String? _lastPresentedRuntimeError;

  bool get retryScheduled => _retryScheduled;
  Set<String> get excludedOutboundTags =>
      Set<String>.unmodifiable(_excludedOutboundTags);
  Set<String> get lastStartedUrlTestOutboundTags =>
      Set<String>.unmodifiable(_lastStartedUrlTestOutboundTags);

  void dispose() {
    cancelRetry();
    clearBuildCache();
    _excludedOutboundTags.clear();
  }

  int scheduleRetry(void Function(int generation) onReady) {
    _retryScheduled = true;
    final generation = ++_retryGeneration;
    _retryTimer?.cancel();
    _retryTimer = Timer(retryDelay, () {
      _retryTimer = null;
      if (isCurrent(generation, ownerActive: true)) {
        onReady(generation);
      }
    });
    return generation;
  }

  void setRetryScheduled(bool value) {
    _retryScheduled = value;
    if (!value) {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }

  bool isCurrent(int generation, {required bool ownerActive}) {
    return ownerActive && _retryScheduled && generation == _retryGeneration;
  }

  bool cancelRetry() {
    final hadPending = _retryScheduled || _retryTimer != null;
    _retryGeneration++;
    _retryScheduled = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    return hadPending;
  }

  void cacheStartedBuild(SingboxConfigBuildResult build) {
    _proxyOutboundTagsByIndex = Map<int, String>.from(
      build.plan.proxyOutboundTagsByIndex,
    );
    _lastStartedConfig = build.plan.config.isEmpty
        ? null
        : Map<String, dynamic>.from(build.plan.config);
    _lastStartedUrlTestOutboundTags = build.plan.urlTestOutboundTags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    // A freshly cached build already honours the whole exclusion set, so no
    // removal is outstanding.
    _pendingMutationExcludedTags.clear();
    _mutationTagInFlight = null;
  }

  void clearBuildCache() {
    _proxyOutboundTagsByIndex = null;
    _lastStartedConfig = null;
    _lastStartedUrlTestOutboundTags.clear();
    _pendingMutationExcludedTags.clear();
    _mutationTagInFlight = null;
  }

  void clearExcludedOutbounds() {
    _excludedOutboundTags.clear();
  }

  Future<InvalidOutboundRecovery?> registerInvalidOutboundError(
    String error, {
    Future<Map<int, String>?> Function()? loadFallbackTagsByIndex,
  }) async {
    final runtimeError = parseRuntimeInvalidOutboundError(error);
    if (runtimeError == null) {
      return null;
    }
    var tag = _proxyOutboundTagsByIndex?[runtimeError.outboundIndex];
    if (tag == null && loadFallbackTagsByIndex != null) {
      final fallbackTagsByIndex = await loadFallbackTagsByIndex();
      tag = fallbackTagsByIndex?[runtimeError.outboundIndex];
    }
    if (tag == null) {
      return null;
    }
    // Reserve atomically. The fallback lookup above awaits, so a containment
    // check followed by a later insert would let two overlapping runtime-error
    // handlers claim the same tag. Set.add reports whether this call is the
    // one that excluded it.
    if (!_excludedOutboundTags.add(tag)) {
      return null;
    }
    _pendingMutationExcludedTags.add(tag);
    return InvalidOutboundRecovery(tag: tag, reason: runtimeError.reason);
  }

  bool hasRemainingOutbounds(Iterable<String> availableTags) {
    return availableTags.any((tag) => !_excludedOutboundTags.contains(tag));
  }

  ConfigMutationInput? createMutationInput(String outputPath) {
    final config = _lastStartedConfig;
    final tagsByIndex = _proxyOutboundTagsByIndex;
    if (config == null || tagsByIndex == null) {
      return null;
    }
    // The in-place mutation removes a single tag. With more than one pending
    // removal the cached config would still carry an excluded outbound, so
    // refuse the fast path and let the caller rebuild, which honours the whole
    // exclusion set.
    if (_pendingMutationExcludedTags.length != 1) {
      return null;
    }
    final excludedTag = _pendingMutationExcludedTags.first;
    _mutationTagInFlight = excludedTag;
    return ConfigMutationInput(
      config: config,
      proxyOutboundTagsByIndex: tagsByIndex,
      tagToRemove: excludedTag,
      outputPath: outputPath,
    );
  }

  void applyMutation(ConfigMutationResult mutation) {
    final excludedTag = _mutationTagInFlight;
    _mutationTagInFlight = null;
    if (excludedTag != null) {
      _pendingMutationExcludedTags.remove(excludedTag);
      _lastStartedUrlTestOutboundTags.remove(excludedTag);
    }
    _lastStartedConfig = Map<String, dynamic>.from(mutation.config);
    _proxyOutboundTagsByIndex = Map<int, String>.from(
      mutation.proxyOutboundTagsByIndex,
    );
  }

  bool shouldPresentRuntimeError(String error) {
    if (_lastPresentedRuntimeError == error) {
      return false;
    }
    _lastPresentedRuntimeError = error;
    return true;
  }

  bool isTransientConfigRetryError(String error) {
    return error.toLowerCase().contains('decode config: unexpected eof');
  }

  RuntimeStartupValidation validateStartupBuild(
    SingboxConfigBuildResult build,
    String reason,
  ) {
    String? warning;
    if (build.invalidOutboundCount > 0) {
      final sample = build.invalidOutbounds
          .take(5)
          .map((outbound) {
            final label = outbound.name.trim().isEmpty
                ? outbound.tag
                : outbound.name.trim();
            return '"$label": ${outbound.reason}';
          })
          .join('; ');
      final sampleText = sample.isEmpty ? 'no sample' : sample;
      final suffix = build.invalidOutboundCount > build.invalidOutbounds.length
          ? '; +${build.invalidOutboundCount - build.invalidOutbounds.length} more'
          : '';
      warning =
          'Skipped ${build.invalidOutboundCount} invalid outbounds before '
          'start ($reason): $sampleText$suffix';
    }
    return RuntimeStartupValidation(
      canStart: build.startableOutboundCount > 0,
      selectedProxyInvalid: build.selectedProxyInvalid,
      warning: warning,
    );
  }
}
