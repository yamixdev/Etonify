import 'dart:async';
import 'package:flutter/services.dart';

enum RootAvailability { unknown, noSu, granted, denied }

enum RootModuleState { notInstalled, ready, failed }

/// Migration status only. Root routing cannot be enabled by this client.
class RootModeStatus {
  const RootModeStatus({
    this.rootAvailability = RootAvailability.unknown,
    this.moduleState = RootModuleState.notInstalled,
    this.moduleVersion,
    this.busy = false,
    this.reason,
  });
  const RootModeStatus.unavailable([this.reason = 'service_unavailable'])
    : rootAvailability = RootAvailability.unknown,
      moduleState = RootModuleState.failed,
      moduleVersion = null,
      busy = false;

  factory RootModeStatus.fromMap(Object? value) {
    const invalid = RootModeStatus.unavailable('invalid_response');
    if (value is! Map || value['enabled'] != false || value['busy'] is! bool) {
      return invalid;
    }
    final roots = RootAvailability.values.where(
      (v) => v.name == value['rootAvailability'],
    );
    final modules = RootModuleState.values.where(
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
    return RootModeStatus(
      rootAvailability: roots.single,
      moduleState: modules.single,
      moduleVersion: version as String?,
      busy: value['busy'] as bool,
      reason: reason as String?,
    );
  }
  static final safeReason = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
  final RootAvailability rootAvailability;
  final RootModuleState moduleState;
  final String? moduleVersion;
  final bool busy;
  final String? reason;
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

/// The only privileged operation left is an explicitly confirmed legacy removal.
class RootModeClient {
  RootModeClient({RootModeTransport? transport})
    : _transport = transport ?? _ChannelRootModeTransport();
  final RootModeTransport _transport;
  Future<RootModeStatus> snapshot() => _invoke('snapshot');
  Future<RootModeStatus> remove() => _invoke('remove');
  Stream<RootModeStatus> get events => _transport.events.transform(
    StreamTransformer<Object?, RootModeStatus>.fromHandlers(
      handleData: (value, sink) => sink.add(RootModeStatus.fromMap(value)),
      handleError: (Object error, StackTrace stack, sink) =>
          sink.add(_failure(error)),
    ),
  );
  Future<RootModeStatus> _invoke(String method) async {
    try {
      return RootModeStatus.fromMap(await _transport.invoke(method));
    } catch (error) {
      return _failure(error);
    }
  }

  static RootModeStatus _failure(Object error) => RootModeStatus.unavailable(
    error is PlatformException && RootModeStatus.safeReason.hasMatch(error.code)
        ? error.code
        : 'service_unavailable',
  );
}
