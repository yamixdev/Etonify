import 'dart:async';

import 'package:flutter/services.dart';

enum RootAvailability { unknown, noSu, granted, denied }

enum RootModuleState {
  notInstalled,
  downloading,
  verifying,
  installing,
  ready,
  incompatible,
  failed,
}

class RootModeStatus {
  const RootModeStatus._({
    required this.rootAvailability,
    required this.moduleState,
    this.moduleVersion,
    this.enabled = false,
    this.busy = false,
    this.reason,
    this.progress = 0,
    this.updateAvailable,
    this.availableModuleVersion,
  });

  const RootModeStatus.unavailable([String reason = 'service_unavailable'])
    : this._(
        rootAvailability: RootAvailability.unknown,
        moduleState: RootModuleState.failed,
        reason: reason,
      );

  factory RootModeStatus.fromMap(Object? value) {
    const invalid = RootModeStatus.unavailable('invalid_response');
    if (value is! Map) return invalid;
    final rootName = value['rootAvailability'];
    final moduleName = value['moduleState'];
    final roots = RootAvailability.values.where(
      (item) => item.name == rootName,
    );
    final modules = RootModuleState.values.where(
      (item) => item.name == moduleName,
    );
    final version = value['moduleVersion'];
    final reason = value['reason'];
    final progress = value['progress'] ?? 0;
    final updateAvailable = value['updateAvailable'];
    final availableVersion = value['availableModuleVersion'];
    if (roots.isEmpty ||
        modules.isEmpty ||
        value['enabled'] is! bool ||
        value['busy'] is! bool ||
        (version != null &&
            (version is! String ||
                !RegExp(
                  r'^[a-zA-Z0-9][a-zA-Z0-9.+_\-]{0,63}$',
                ).hasMatch(version))) ||
        (reason != null &&
            (reason is! String || !_safeReason.hasMatch(reason))) ||
        (updateAvailable != null && updateAvailable is! bool) ||
        (availableVersion != null &&
            (availableVersion is! String ||
                !_safeVersion.hasMatch(availableVersion))) ||
        (updateAvailable == true && availableVersion == null) ||
        progress is! num ||
        !progress.isFinite ||
        progress < 0 ||
        progress > 1) {
      return invalid;
    }
    final root = roots.single;
    final module = modules.single;
    return RootModeStatus._(
      rootAvailability: root,
      moduleState: module,
      moduleVersion: version as String?,
      // This is the requested mode, not evidence of current privileges. Native
      // authorization is mandatory at launch; the user can always turn it off.
      enabled: value['enabled'] == true,
      busy:
          value['busy'] == true ||
          module == RootModuleState.downloading ||
          module == RootModuleState.verifying ||
          module == RootModuleState.installing,
      reason: reason as String?,
      progress: progress.toDouble(),
      updateAvailable: reason == null ? updateAvailable as bool? : null,
      availableModuleVersion: reason == null
          ? availableVersion as String?
          : null,
    );
  }

  static final _safeReason = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
  static final _safeVersion = RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$');

  final RootAvailability rootAvailability;
  final RootModuleState moduleState;
  final String? moduleVersion;
  final bool enabled;
  final bool busy;
  final String? reason;
  final double progress;
  final bool? updateAvailable;
  final String? availableModuleVersion;

  bool get canEnable =>
      !busy &&
      rootAvailability == RootAvailability.granted &&
      moduleState == RootModuleState.ready;
}

abstract interface class RootModeTransport {
  Future<Object?> invoke(String method, [Map<String, Object?>? arguments]);
  Stream<Object?> get events;
}

class _ChannelRootModeTransport implements RootModeTransport {
  static const _methods = MethodChannel('meow_client/root_mode');
  static const _events = EventChannel('meow_client/root_mode_events');

  @override
  Future<Object?> invoke(String method, [Map<String, Object?>? arguments]) =>
      _methods.invokeMethod<Object?>(method, arguments);

  @override
  Stream<Object?> get events => _events.receiveBroadcastStream();
}

class RootModeClient {
  RootModeClient({RootModeTransport? transport})
    : _transport = transport ?? _ChannelRootModeTransport();

  final RootModeTransport _transport;

  Future<RootModeStatus> snapshot() => _invoke('snapshot');
  Future<RootModeStatus> requestAuthorization() =>
      _invoke('requestAuthorization');
  Future<RootModeStatus> install() => _invoke('install');
  Future<RootModeStatus> remove() => _invoke('remove');
  Future<RootModeStatus> checkUpdate() => _invoke('checkUpdate');
  Future<RootModeStatus> setEnabled(bool enabled) =>
      _invoke('setEnabled', {'enabled': enabled});
  Future<RootModeStatus> cancel() => _invoke('cancel');

  Stream<RootModeStatus> get events => _transport.events.transform(
    StreamTransformer<Object?, RootModeStatus>.fromHandlers(
      handleData: (value, sink) => sink.add(RootModeStatus.fromMap(value)),
      handleError: (Object error, StackTrace stack, sink) =>
          sink.add(_failure(error)),
    ),
  );

  Future<RootModeStatus> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return RootModeStatus.fromMap(await _transport.invoke(method, arguments));
    } catch (error) {
      return _failure(error);
    }
  }

  static RootModeStatus _failure(Object error) {
    final code =
        error is PlatformException &&
            RootModeStatus._safeReason.hasMatch(error.code)
        ? error.code
        : 'service_unavailable';
    return RootModeStatus.unavailable(code);
  }
}
