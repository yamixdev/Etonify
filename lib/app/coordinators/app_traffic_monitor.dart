import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meow_client/app/traffic_status_reducer.dart';
import 'package:meow_client/models/app_view_models.dart';

/// Host interface supplying the application context required by [AppTrafficMonitor].
class AppTrafficMonitorHost {
  const AppTrafficMonitorHost({
    required this.isMounted,
    required this.isForegroundLifecycleActive,
    required this.isConnected,
    required this.isConnecting,
    required this.isHideServerIp,
    required this.getConnectedSince,
    required this.getActiveProfile,
    required this.getActiveProxy,
  });

  final bool Function() isMounted;
  final bool Function() isForegroundLifecycleActive;
  final bool Function() isConnected;
  final bool Function() isConnecting;
  final bool Function() isHideServerIp;
  final DateTime? Function() getConnectedSince;
  final AppProfileSummary? Function() getActiveProfile;
  final AppProxySummary? Function() getActiveProxy;
}

/// Manages runtime traffic metrics, throttled UI updates, rolling graph samples,
/// and live dashboard snapshots.
class AppTrafficMonitor {
  AppTrafficMonitor({
    required this.host,
    Duration uiUpdateInterval = const Duration(seconds: 1),
    TrafficStatusReducer trafficStatusReducer = const TrafficStatusReducer(),
  })  : _uiUpdateInterval = uiUpdateInterval,
        _trafficStatusReducer = trafficStatusReducer;

  final AppTrafficMonitorHost host;
  final Duration _uiUpdateInterval;
  final TrafficStatusReducer _trafficStatusReducer;

  Timer? _trafficUiUpdateTimer;
  Map<String, dynamic>? _pendingTrafficStatusEvent;
  DateTime _lastTrafficUiUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);

  int _downlinkBytesPerSecond = 0;
  int _uplinkBytesPerSecond = 0;
  int _uplinkTotalBytes = 0;
  int _downlinkTotalBytes = 0;
  bool _trafficAvailable = false;

  List<TrafficSample> _trafficSamples = const <TrafficSample>[];
  bool _trafficDashboardOpen = false;

  final ValueNotifier<TrafficDashboardSnapshot> _trafficDashboardSnapshot =
      ValueNotifier<TrafficDashboardSnapshot>(TrafficDashboardSnapshot.empty);
  final ValueNotifier<TrafficUiSnapshot> _trafficUiSnapshot =
      ValueNotifier<TrafficUiSnapshot>(TrafficUiSnapshot.zero);

  int get downlinkBytesPerSecond => _downlinkBytesPerSecond;
  int get uplinkBytesPerSecond => _uplinkBytesPerSecond;
  int get uplinkTotalBytes => _uplinkTotalBytes;
  int get downlinkTotalBytes => _downlinkTotalBytes;
  bool get trafficAvailable => _trafficAvailable;
  List<TrafficSample> get trafficSamples => _trafficSamples;
  int get samplesCount => _trafficSamples.length;
  bool get isTrafficDashboardOpen => _trafficDashboardOpen;

  ValueNotifier<TrafficDashboardSnapshot> get trafficDashboardSnapshotNotifier =>
      _trafficDashboardSnapshot;
  ValueNotifier<TrafficUiSnapshot> get trafficUiSnapshotNotifier =>
      _trafficUiSnapshot;

  RuntimeTrafficStatus get currentStatus => RuntimeTrafficStatus(
        uplinkBytesPerSecond: _uplinkBytesPerSecond,
        downlinkBytesPerSecond: _downlinkBytesPerSecond,
        uplinkTotalBytes: _uplinkTotalBytes,
        downlinkTotalBytes: _downlinkTotalBytes,
        available: _trafficAvailable,
      );

  RuntimeTrafficStatus reduceRuntimeEvent(RuntimeTrafficEvent event) {
    return _trafficStatusReducer
        .reduce(current: currentStatus, event: event)
        .status;
  }

  RuntimeTrafficStatus reduceRuntimeStatus(Map<String, dynamic> status) {
    return reduceRuntimeEvent(RuntimeTrafficEvent.fromMap(status));
  }

  void applyStatus(RuntimeTrafficStatus status) {
    _uplinkBytesPerSecond = status.uplinkBytesPerSecond;
    _downlinkBytesPerSecond = status.downlinkBytesPerSecond;
    _uplinkTotalBytes = status.uplinkTotalBytes;
    _downlinkTotalBytes = status.downlinkTotalBytes;
    _trafficAvailable = status.available;
  }

  void recordTrafficSample(DateTime now) {
    final connected = host.isConnected();
    if (!_trafficDashboardOpen || !connected || !_trafficAvailable) {
      return;
    }
    final cutoff = now.subtract(const Duration(minutes: 5));
    final next = <TrafficSample>[
      for (final sample in _trafficSamples)
        if (!sample.timestamp.isBefore(cutoff)) sample,
      TrafficSample(
        timestamp: now,
        downlinkBps: _downlinkBytesPerSecond,
        uplinkBps: _uplinkBytesPerSecond,
        totalBytes: _uplinkTotalBytes + _downlinkTotalBytes,
      ),
    ];
    if (next.length > 180) {
      _trafficSamples = List<TrafficSample>.unmodifiable(
        next.skip(next.length - 180),
      );
    } else {
      _trafficSamples = List<TrafficSample>.unmodifiable(next);
    }
  }

  void reset() {
    _uplinkBytesPerSecond = 0;
    _downlinkBytesPerSecond = 0;
    _uplinkTotalBytes = 0;
    _downlinkTotalBytes = 0;
    _trafficAvailable = false;
    _trafficSamples = const <TrafficSample>[];
  }

  TrafficDashboardSnapshot currentTrafficDashboardSnapshot() {
    final connected = host.isConnected();
    final connecting = host.isConnecting();
    final hideServerIp = host.isHideServerIp();
    final connectedSince = host.getConnectedSince();
    final activeProfile = host.getActiveProfile();
    final activeProxy = host.getActiveProxy();

    return TrafficDashboardSnapshot(
      connected: connected,
      connecting: connecting,
      trafficAvailable: _trafficAvailable,
      hideServerIp: hideServerIp,
      downlinkBps:
          connected && _trafficAvailable ? _downlinkBytesPerSecond : 0,
      uplinkBps:
          connected && _trafficAvailable ? _uplinkBytesPerSecond : 0,
      uplinkTotalBytes:
          connected && _trafficAvailable ? _uplinkTotalBytes : 0,
      downlinkTotalBytes:
          connected && _trafficAvailable ? _downlinkTotalBytes : 0,
      connectedSince: connected ? connectedSince : null,
      activeProfile: activeProfile,
      activeProxy: activeProxy,
      samples: _trafficSamples,
    );
  }

  void publish({bool force = false}) {
    final connected = host.isConnected();
    final trafficUiSnapshot = TrafficUiSnapshot(
      speedBytesPerSecond: connected && _trafficAvailable
          ? _downlinkBytesPerSecond.toDouble()
          : 0,
      trafficBytes: connected && _trafficAvailable
          ? (_uplinkTotalBytes + _downlinkTotalBytes).toDouble()
          : 0,
    );
    if (_trafficUiSnapshot.value != trafficUiSnapshot) {
      _trafficUiSnapshot.value = trafficUiSnapshot;
    }
    if (!_trafficDashboardOpen && !force) {
      return;
    }
    final snapshot = currentTrafficDashboardSnapshot();
    if (_trafficDashboardSnapshot.value != snapshot) {
      _trafficDashboardSnapshot.value = snapshot;
    }
  }

  void handleTrafficStatusEvent(Map<String, dynamic> event) {
    if (!host.isMounted() || !host.isForegroundLifecycleActive()) {
      return;
    }
    _pendingTrafficStatusEvent = event;
    final now = DateTime.now();
    final elapsed = now.difference(_lastTrafficUiUpdateAt);
    if (elapsed >= _uiUpdateInterval) {
      flushPendingTrafficStatusEvent();
      return;
    }
    _trafficUiUpdateTimer ??= Timer(_uiUpdateInterval - elapsed, () {
      _trafficUiUpdateTimer = null;
      flushPendingTrafficStatusEvent();
    });
  }

  void flushPendingTrafficStatusEvent() {
    final event = _pendingTrafficStatusEvent;
    if (event == null) {
      return;
    }
    _pendingTrafficStatusEvent = null;
    _applyTrafficStatusEvent(event);
  }

  void _applyTrafficStatusEvent(Map<String, dynamic> event) {
    if (!host.isMounted()) return;
    final now = DateTime.now();
    final current = currentStatus;
    final next = _trafficStatusReducer
        .reduce(current: current, event: RuntimeTrafficEvent.fromMap(event))
        .status;
    if (current == next) {
      // The graph needs a time sample even while traffic is idle; otherwise a
      // flat connection leaves its last point frozen until another packet is
      // transferred. The dashboard is the only consumer, so this stays idle
      // when it is closed.
      recordTrafficSample(now);
      publish();
      return;
    }
    _lastTrafficUiUpdateAt = now;
    applyStatus(next);
    recordTrafficSample(now);
    publish();
  }

  void openDashboard() {
    _trafficDashboardOpen = true;
    publish(force: true);
  }

  void closeDashboard() {
    _trafficDashboardOpen = false;
    _trafficSamples = const <TrafficSample>[];
    _trafficDashboardSnapshot.value = TrafficDashboardSnapshot.empty;
  }

  void handleMemoryPressure({required bool connected}) {
    var trafficDashboardChanged = false;
    if (!connected) {
      reset();
      trafficDashboardChanged = true;
    } else if (_trafficSamples.length > 60) {
      _trafficSamples = List<TrafficSample>.unmodifiable(
        _trafficSamples.skip(_trafficSamples.length - 60),
      );
      trafficDashboardChanged = true;
    }
    if (trafficDashboardChanged) {
      publish(force: true);
    }
  }

  void suspendForegroundWork() {
    _trafficUiUpdateTimer?.cancel();
    _trafficUiUpdateTimer = null;
    _pendingTrafficStatusEvent = null;
  }

  void dispose() {
    _trafficUiUpdateTimer?.cancel();
    _trafficUiUpdateTimer = null;
    _trafficDashboardSnapshot.dispose();
    _trafficUiSnapshot.dispose();
  }
}
