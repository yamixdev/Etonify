import 'dart:convert';
import 'desktop_preferences.dart';

enum RuntimeEnvelopeKind { request, response, event }

enum DesktopRuntimePhase {
  stopped,
  starting,
  connected,
  applying,
  stopping,
  failed,
}

enum DesktopDistribution { installed, portable }

/// A response carries either a payload (including JSON null) or an error.
class RuntimeEnvelope {
  RuntimeEnvelope({
    this.version = 1,
    required this.kind,
    required this.id,
    required this.sessionId,
    required this.configGeneration,
    required this.networkGeneration,
    required this.method,
    this.payload,
    this.error,
  }) {
    _validate();
  }
  final int version;
  final RuntimeEnvelopeKind kind;
  final String id;
  final String sessionId;
  final int configGeneration;
  final int networkGeneration;
  final String method;
  final Object? payload;
  final DesktopRuntimeError? error;

  factory RuntimeEnvelope.fromMap(Map<String, Object?> map) {
    final kind = enumValue(RuntimeEnvelopeKind.values, map['kind'], 'kind');
    final hasError = map.containsKey('error');
    if (hasError == map.containsKey('payload') ||
        (hasError && kind != RuntimeEnvelopeKind.response)) {
      throw const FormatException('Expected payload or response error');
    }
    return RuntimeEnvelope(
      version: integerValue(map['version'], 'version'),
      kind: kind,
      id: stringValue(map['id'], 'id'),
      sessionId: stringValue(map['sessionId'], 'sessionId'),
      configGeneration: integerValue(
        map['configGeneration'],
        'configGeneration',
      ),
      networkGeneration: integerValue(
        map['networkGeneration'],
        'networkGeneration',
      ),
      method: stringValue(map['method'], 'method'),
      payload: map['payload'],
      error: hasError
          ? DesktopRuntimeError.fromMap(objectMap(map['error']))
          : null,
    );
  }

  void _validate() {
    if (version != 1) {
      throw const FormatException('Unsupported protocol version');
    }
    integerValue(configGeneration, 'configGeneration');
    integerValue(networkGeneration, 'networkGeneration');
    if (error != null &&
        (kind != RuntimeEnvelopeKind.response || payload != null)) {
      throw const FormatException('Error replaces response payload');
    }
    // Checks nested values too; the wire permits JSON data only.
    jsonEncode(payload);
  }

  Map<String, Object?> toMap() => {
    'version': version,
    'kind': kind.name,
    'id': id,
    'sessionId': sessionId,
    'configGeneration': configGeneration,
    'networkGeneration': networkGeneration,
    'method': method,
    if (error == null) 'payload': payload else 'error': error!.toMap(),
  };
}

class DesktopRuntimeError {
  const DesktopRuntimeError({required this.code, required this.message});
  final String code;
  final String message;
  factory DesktopRuntimeError.fromMap(Map<String, Object?> map) =>
      DesktopRuntimeError(
        code: stringValue(map['code'], 'code'),
        message: stringValue(map['message'], 'message'),
      );
  Map<String, Object?> toMap() => {'code': code, 'message': message};
}

class DesktopCapabilities {
  const DesktopCapabilities({
    this.localProxy = false,
    this.tun = false,
    this.processRouting = false,
    this.systemProxy = false,
  });
  final bool localProxy;
  final bool tun;
  final bool processRouting;
  final bool systemProxy;
  factory DesktopCapabilities.fromMap(Map<String, Object?> map) =>
      DesktopCapabilities(
        localProxy: map['localProxy'] == true,
        tun: map['tun'] == true,
        processRouting: map['processRouting'] == true,
        systemProxy: map['systemProxy'] == true,
      );
  bool supports(String name) => switch (name) {
    'localProxy' => localProxy,
    'tun' => tun,
    'processRouting' => processRouting,
    'systemProxy' => systemProxy,
    _ => false,
  };
  Map<String, Object?> toMap() => {
    'localProxy': localProxy,
    'tun': tun,
    'processRouting': processRouting,
    'systemProxy': systemProxy,
  };
}

class DesktopRuntimeSnapshot {
  const DesktopRuntimeSnapshot({
    required this.sessionId,
    required this.configGeneration,
    required this.networkGeneration,
    required this.phase,
    required this.modes,
    required this.selectedTag,
    required this.coreVersion,
    required this.daemonApiVersion,
    required this.serviceVersion,
    required this.capabilities,
    this.error,
  });
  final String sessionId;
  final int configGeneration;
  final int networkGeneration;
  final DesktopRuntimePhase phase;
  final DesktopModePreferences modes;
  final String selectedTag;
  final String coreVersion;
  final int daemonApiVersion;
  final String serviceVersion;
  final DesktopCapabilities capabilities;
  final DesktopRuntimeError? error;
  factory DesktopRuntimeSnapshot.fromMap(
    Map<String, Object?> map,
  ) => DesktopRuntimeSnapshot(
    sessionId: stringValue(map['sessionId'], 'sessionId'),
    configGeneration: integerValue(map['configGeneration'], 'configGeneration'),
    networkGeneration: integerValue(
      map['networkGeneration'],
      'networkGeneration',
    ),
    phase: enumValue(DesktopRuntimePhase.values, map['phase'], 'phase'),
    modes: DesktopModePreferences.fromMap(objectMap(map['modes'])),
    selectedTag: stringValue(map['selectedTag'], 'selectedTag'),
    coreVersion: stringValue(map['coreVersion'], 'coreVersion'),
    daemonApiVersion: integerValue(map['daemonApiVersion'], 'daemonApiVersion'),
    serviceVersion: stringValue(map['serviceVersion'], 'serviceVersion'),
    capabilities: DesktopCapabilities.fromMap(objectMap(map['capabilities'])),
    error: map['error'] == null
        ? null
        : DesktopRuntimeError.fromMap(objectMap(map['error'])),
  );
  Map<String, Object?> toMap() => {
    'sessionId': sessionId,
    'configGeneration': configGeneration,
    'networkGeneration': networkGeneration,
    'phase': phase.name,
    'modes': modes.toMap(),
    'selectedTag': selectedTag,
    'coreVersion': coreVersion,
    'daemonApiVersion': daemonApiVersion,
    'serviceVersion': serviceVersion,
    'capabilities': capabilities.toMap(),
    if (error != null) 'error': error!.toMap(),
  };
}

class DesktopLaunchContext {
  const DesktopLaunchContext({
    required this.installationId,
    required this.distribution,
    required this.dataRoot,
    required this.startedAtLogin,
    required this.minimized,
    required this.ownerPid,
  });
  final String installationId;
  final DesktopDistribution distribution;

  /// Final absolute user root resolved by the native launcher. Dart must not
  /// append data/user again (portable: data/user; installed: Etonify/user).
  final String dataRoot;
  final bool startedAtLogin;
  final bool minimized;
  final int ownerPid;
  factory DesktopLaunchContext.fromMap(Map<String, Object?> map) =>
      DesktopLaunchContext(
        installationId: stringValue(map['installationId'], 'installationId'),
        distribution: enumValue(
          DesktopDistribution.values,
          map['distribution'],
          'distribution',
        ),
        dataRoot: stringValue(map['dataRoot'], 'dataRoot'),
        startedAtLogin: booleanValue(map['startedAtLogin'], 'startedAtLogin'),
        minimized: booleanValue(map['minimized'], 'minimized'),
        ownerPid: integerValue(map['ownerPid'], 'ownerPid'),
      );
  Map<String, Object?> toMap() => {
    'installationId': installationId,
    'distribution': distribution.name,
    'dataRoot': dataRoot,
    'startedAtLogin': startedAtLogin,
    'minimized': minimized,
    'ownerPid': ownerPid,
  };
}

Map<String, Object?> objectMap(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected JSON object');
  }
  return Map<String, Object?>.from(value);
}

String stringValue(Object? value, String name) {
  if (value is! String) throw FormatException('Expected string $name');
  return value;
}

int integerValue(Object? value, String name) {
  if (value is! int || value < 0 || value > 9223372036854775807) {
    throw FormatException('Expected nonnegative int64 $name');
  }
  return value;
}

bool booleanValue(Object? value, String name) {
  if (value is! bool) throw FormatException('Expected boolean $name');
  return value;
}

T enumValue<T extends Enum>(List<T> values, Object? value, String name) {
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw FormatException('Invalid $name');
}
