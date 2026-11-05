import 'package:flutter/services.dart';

enum LegacyRootAvailability { unknown, noSu, granted, denied }

enum LegacyModuleState { notInstalled, ready, failed }

/// Migration status only. Root routing cannot be enabled by this client.
class LegacyCleanupStatus {
  const LegacyCleanupStatus({
    this.rootAvailability = LegacyRootAvailability.unknown,
    this.moduleState = LegacyModuleState.notInstalled,
    this.moduleVersion,
    this.busy = false,
    this.reason,
    this.promptPending = false,
  });
  const LegacyCleanupStatus.unavailable([this.reason = 'service_unavailable'])
    : rootAvailability = LegacyRootAvailability.unknown,
      moduleState = LegacyModuleState.failed,
      moduleVersion = null,
      busy = false,
      promptPending = false;

  factory LegacyCleanupStatus.fromMap(Object? value) {
    const invalid = LegacyCleanupStatus.unavailable('invalid_response');
    if (value is! Map || value['enabled'] != false || value['busy'] is! bool) {
      return invalid;
    }
    final roots = LegacyRootAvailability.values.where(
      (v) => v.name == value['rootAvailability'],
    );
    final modules = LegacyModuleState.values.where(
      (v) => v.name == value['moduleState'],
    );
    final version = value['moduleVersion'];
    final reason = value['reason'];
    if (roots.isEmpty ||
        modules.isEmpty ||
        (version != null &&
            (version is! String ||
                !RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$').hasMatch(version))) ||
        (reason != null &&
            (reason is! String || !safeReason.hasMatch(reason)))) {
      return invalid;
    }
    return LegacyCleanupStatus(
      rootAvailability: roots.single,
      moduleState: modules.single,
      moduleVersion: version as String?,
      busy: value['busy'] as bool,
      promptPending: value['promptPending'] == true,
      reason: reason as String?,
    );
  }
  static final safeReason = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
  final LegacyRootAvailability rootAvailability;
  final LegacyModuleState moduleState;
  final String? moduleVersion;
  final bool busy;
  final bool promptPending;
  final String? reason;
}

abstract interface class LegacyCleanupTransport {
  Future<Object?> invoke(String method, [Map<String, Object?>? arguments]);
}

class _ChannelLegacyCleanupTransport implements LegacyCleanupTransport {
  static const _methods = MethodChannel('meow_client/legacy_module_cleanup');
  @override
  Future<Object?> invoke(String method, [Map<String, Object?>? arguments]) =>
      _methods.invokeMethod<Object?>(method, arguments);
}

/// The only privileged operation left is an explicitly confirmed legacy removal.
class LegacyModuleCleanupClient {
  LegacyModuleCleanupClient({LegacyCleanupTransport? transport})
    : _transport = transport ?? _ChannelLegacyCleanupTransport();
  final LegacyCleanupTransport _transport;
  Future<LegacyCleanupStatus> snapshot() => _invoke('snapshot');
  Future<LegacyCleanupStatus> remove() => _invoke('remove');
  Future<LegacyCleanupStatus> acknowledgePrompt() =>
      _invoke('acknowledgePrompt');
  Future<LegacyCleanupStatus> _invoke(String method) async {
    try {
      return LegacyCleanupStatus.fromMap(await _transport.invoke(method));
    } catch (error) {
      return _failure(error);
    }
  }

  static LegacyCleanupStatus _failure(Object error) =>
      LegacyCleanupStatus.unavailable(
        error is PlatformException &&
                LegacyCleanupStatus.safeReason.hasMatch(error.code)
            ? error.code
            : 'service_unavailable',
      );
}
