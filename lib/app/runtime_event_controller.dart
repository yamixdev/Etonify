import 'dart:async';

import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/singbox/singbox_api.g.dart' as pigeon;

class RuntimeStateEvent {
  const RuntimeStateEvent({
    required this.running,
    this.error,
    this.raw = const <String, dynamic>{},
  });

  final bool running;
  final String? error;
  final Map<String, dynamic> raw;

  bool get hasError => error != null && error!.isNotEmpty;
}

class RuntimeGroupsEvent {
  const RuntimeGroupsEvent({
    required this.groups,
    required this.runtimeGeneration,
  });

  final List<dynamic> groups;
  final int runtimeGeneration;
}

typedef RuntimeStateHandler = void Function(RuntimeStateEvent event);

/// A full snapshot replaces its predecessor; never queue thousands of rows
/// for every event received while the active profile is still hydrating.
class PendingRuntimeGroups {
  RuntimeGroupsEvent? _latest;

  void remember(RuntimeGroupsEvent event) {
    if (event.runtimeGeneration <= 0) return;
    if (_latest != null &&
        event.runtimeGeneration < _latest!.runtimeGeneration) {
      return;
    }
    _latest = event;
  }

  RuntimeGroupsEvent? take(int generation) {
    final latest = _latest;
    _latest = null;
    return latest?.runtimeGeneration == generation ? latest : null;
  }

  void clear() => _latest = null;
}

typedef RuntimeRawEventHandler = void Function(Map<String, dynamic> event);
typedef RuntimeGroupsHandler = void Function(RuntimeGroupsEvent event);
typedef RuntimeLogFilter = bool Function(String level);
typedef RuntimeLogIssueHandler = void Function(String reason, String message);

class RuntimeEventController {
  RuntimeEventController({
    required Stream<Map<String, dynamic>> events,
    required RuntimeStateHandler onState,
    required RuntimeRawEventHandler onStatus,
    required RuntimeRawEventHandler onNetwork,
    required RuntimeGroupsHandler onGroups,
    required RuntimeLogFilter shouldRecordLog,
    RuntimeLogIssueHandler? onRuntimeLogIssue,
    DateTime Function()? now,
  }) : _events = events,
       _onState = onState,
       _onStatus = onStatus,
       _onNetwork = onNetwork,
       _onGroups = onGroups,
       _shouldRecordLog = shouldRecordLog,
       _onRuntimeLogIssue = onRuntimeLogIssue,
       _now = now ?? DateTime.now;

  static final RegExp _interfaceDialFailurePattern = RegExp(
    r'\bdial\s+(?:ccmni|wlan|rmnet|swlan|eth|usb|ap)\w*\s*\(\d+\).*?\b(?:network is unreachable|no route to host)\b',
    caseSensitive: false,
  );

  final Stream<Map<String, dynamic>> _events;
  final RuntimeStateHandler _onState;
  final RuntimeRawEventHandler _onStatus;
  final RuntimeRawEventHandler _onNetwork;
  final RuntimeGroupsHandler _onGroups;
  final RuntimeLogFilter _shouldRecordLog;
  final RuntimeLogIssueHandler? _onRuntimeLogIssue;
  final DateTime Function() _now;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  void start() {
    _subscription?.cancel();
    _subscription = _events.listen(dispatch);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void dispatch(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    switch (type) {
      case pigeon.runtimeEventState:
        _onState(
          RuntimeStateEvent(
            running: event['running'] == true,
            error: event['error']?.toString(),
            raw: event,
          ),
        );
        break;
      case pigeon.runtimeEventStatus:
        _onStatus(event);
        break;
      case pigeon.runtimeEventNetwork:
        _onNetwork(event);
        break;
      case pigeon.runtimeEventGroups:
        _onGroups(
          RuntimeGroupsEvent(
            groups: (event['groups'] as List?) ?? const [],
            runtimeGeneration:
                (event['runtimeGeneration'] as num?)?.toInt() ?? 0,
          ),
        );
        break;
      case pigeon.runtimeEventNativeLog:
        _recordNativeLog(event);
        break;
      case pigeon.runtimeEventLogs:
        _recordLogBatch(event);
        break;
      case pigeon.runtimeEventLogLevel:
        break;
      default:
        break;
    }
  }

  void _recordNativeLog(Map<String, dynamic> event) {
    final level = (event['level']?.toString() ?? 'info').toLowerCase();
    final message = event['message']?.toString() ?? '';
    if (message.isEmpty) {
      return;
    }
    _emitRuntimeLogIssueIfNeeded(message);
    final normalizedLevel = _normalizeNativeLevel(level);
    final effectiveLevel = AppLogStore.inferLevel(message) ?? normalizedLevel;
    if (!_shouldRecordLog(effectiveLevel)) {
      return;
    }
    AppLogStore.ingest(
      'sing-box',
      message,
      fallbackLevel: _fallbackLogLevel(effectiveLevel),
      trustFallbackLevel: true,
    );
  }

  void _recordLogBatch(Map<String, dynamic> event) {
    final logs = (event['logs'] as List?) ?? const [];
    final batch = <AppLogEntry>[];
    for (final entry in logs) {
      if (entry is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(entry);
      final level = (map['level'] as num?)?.toInt() ?? 0;
      final message = map['message']?.toString() ?? '';
      if (message.isEmpty) {
        continue;
      }
      _emitRuntimeLogIssueIfNeeded(message);
      final fallbackLevel = _fallbackBatchLogLevel(level);
      final effectiveLevel = AppLogStore.inferLevel(message) ?? fallbackLevel;
      if (!_shouldRecordLog(effectiveLevel)) {
        continue;
      }
      batch.add(
        AppLogEntry(
          timestamp: _now(),
          level: effectiveLevel,
          title: 'sing-box',
          message: AppLogStore.normalizeMessage(message),
        ),
      );
    }
    AppLogStore.appendBatch(batch);
  }

  void _emitRuntimeLogIssueIfNeeded(String message) {
    final reason = _runtimeLogIssueReason(message);
    if (reason == null) {
      return;
    }
    _onRuntimeLogIssue?.call(reason, message);
  }

  String? _runtimeLogIssueReason(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('no available network interface')) {
      return 'core_no_available_interface';
    }
    if (lower.contains('no usable network interface') ||
        lower.contains('error=no_interface')) {
      return 'core_no_usable_interface';
    }
    if (_interfaceDialFailurePattern.hasMatch(message)) {
      return 'core_interface_dial_failure';
    }
    return null;
  }

  String _normalizeNativeLevel(String level) {
    return switch (level) {
      'warn' => 'warning',
      'trace' => 'debug',
      _ => level,
    };
  }

  String _fallbackLogLevel(String effectiveLevel) {
    return switch (effectiveLevel) {
      'error' => 'error',
      'debug' => 'debug',
      'warning' => 'warning',
      _ => 'info',
    };
  }

  String _fallbackBatchLogLevel(int level) {
    return switch (level) {
      >= 4 => 'error',
      3 => 'warning',
      2 => 'info',
      _ => 'debug',
    };
  }
}
