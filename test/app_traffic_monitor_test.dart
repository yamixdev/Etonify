import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/coordinators/app_traffic_monitor.dart';
import 'package:meow_client/app/traffic_status_reducer.dart';
import 'package:meow_client/models/app_view_models.dart';

void main() {
  group('AppTrafficMonitor', () {
    late bool mounted;
    late bool foregroundActive;
    late bool connected;
    late bool connecting;
    late bool hideServerIp;
    late DateTime? connectedSince;
    late AppProfileSummary? activeProfile;
    late AppProxySummary? activeProxy;
    late AppTrafficMonitor monitor;

    setUp(() {
      mounted = true;
      foregroundActive = true;
      connected = true;
      connecting = false;
      hideServerIp = false;
      connectedSince = DateTime(2026, 1, 1, 12);
      activeProfile = const AppProfileSummary(
        id: 'p1',
        name: 'Profile 1',
        consumed: 0,
        total: 0,
        remainingDays: null,
        outboundsCount: 1,
        sourceLabel: 'src',
      );
      activeProxy = const AppProxySummary(
        tag: 'proxy1',
        displayName: 'Proxy 1',
        countryCode: 'US',
        type: 'vmess',
        server: '1.2.3.4',
        port: 443,
        detailText: 'details',
        ip: '1.2.3.4',
        latency: 50,
        latencyFresh: true,
        latencyChecking: false,
        latencyUnavailable: false,
        latencyError: null,
        protocolLabel: 'VMess',
        endpointLabel: '1.2.3.4:443',
      );

      monitor = AppTrafficMonitor(
        host: AppTrafficMonitorHost(
          isMounted: () => mounted,
          isForegroundLifecycleActive: () => foregroundActive,
          isConnected: () => connected,
          isConnecting: () => connecting,
          isHideServerIp: () => hideServerIp,
          getConnectedSince: () => connectedSince,
          getActiveProfile: () => activeProfile,
          getActiveProxy: () => activeProxy,
        ),
      );
    });

    tearDown(() {
      monitor.dispose();
    });

    test('initial state is zero and empty', () {
      expect(monitor.downlinkBytesPerSecond, 0);
      expect(monitor.uplinkBytesPerSecond, 0);
      expect(monitor.downlinkTotalBytes, 0);
      expect(monitor.uplinkTotalBytes, 0);
      expect(monitor.trafficAvailable, isFalse);
      expect(monitor.trafficSamples, isEmpty);
      expect(monitor.samplesCount, 0);
      expect(monitor.isTrafficDashboardOpen, isFalse);
      expect(monitor.trafficUiSnapshotNotifier.value, TrafficUiSnapshot.zero);
      expect(
        monitor.trafficDashboardSnapshotNotifier.value,
        TrafficDashboardSnapshot.empty,
      );
    });

    test('applyStatus updates traffic counters and publishes snapshot', () {
      monitor.applyStatus(
        const RuntimeTrafficStatus(
          uplinkBytesPerSecond: 1024,
          downlinkBytesPerSecond: 2048,
          uplinkTotalBytes: 5000,
          downlinkTotalBytes: 10000,
          available: true,
        ),
      );

      expect(monitor.uplinkBytesPerSecond, 1024);
      expect(monitor.downlinkBytesPerSecond, 2048);
      expect(monitor.uplinkTotalBytes, 5000);
      expect(monitor.downlinkTotalBytes, 10000);
      expect(monitor.trafficAvailable, isTrue);

      monitor.publish();
      expect(
        monitor.trafficUiSnapshotNotifier.value,
        const TrafficUiSnapshot(
          speedBytesPerSecond: 2048,
          trafficBytes: 15000,
        ),
      );
    });

    test('recordTrafficSample records when dashboard is open and connected', () {
      monitor.openDashboard();
      expect(monitor.isTrafficDashboardOpen, isTrue);

      monitor.applyStatus(
        const RuntimeTrafficStatus(
          uplinkBytesPerSecond: 500,
          downlinkBytesPerSecond: 1500,
          uplinkTotalBytes: 2000,
          downlinkTotalBytes: 4000,
          available: true,
        ),
      );

      final now = DateTime(2026, 1, 1, 12, 10);
      monitor.recordTrafficSample(now);

      expect(monitor.samplesCount, 1);
      expect(monitor.trafficSamples.first.downlinkBps, 1500);
      expect(monitor.trafficSamples.first.uplinkBps, 500);
      expect(monitor.trafficSamples.first.totalBytes, 6000);

      monitor.closeDashboard();
      expect(monitor.isTrafficDashboardOpen, isFalse);
      expect(monitor.samplesCount, 0);
      expect(
        monitor.trafficDashboardSnapshotNotifier.value,
        TrafficDashboardSnapshot.empty,
      );
    });

    test('recordTrafficSample prunes old samples beyond 5 minutes and caps at 180', () {
      monitor.openDashboard();
      monitor.applyStatus(
        const RuntimeTrafficStatus(
          uplinkBytesPerSecond: 10,
          downlinkBytesPerSecond: 20,
          uplinkTotalBytes: 100,
          downlinkTotalBytes: 200,
          available: true,
        ),
      );

      final baseTime = DateTime(2026, 1, 1, 12, 0);
      // Add 200 samples 1 second apart
      for (var i = 0; i < 200; i++) {
        monitor.recordTrafficSample(baseTime.add(Duration(seconds: i)));
      }

      // Max capped at 180
      expect(monitor.samplesCount, 180);

      // Now add a sample 6 minutes later: old samples (> 5 mins before) should be pruned
      final later = baseTime.add(const Duration(minutes: 6));
      monitor.recordTrafficSample(later);

      // Cutoff is 6 mins - 5 mins = 1 min = 60s.
      // Samples from baseTime+0s to baseTime+59s are before cutoff, so they are pruned.
      expect(monitor.samplesCount, lessThan(180));
      expect(monitor.trafficSamples.last.timestamp, later);
    });

    test('handleMemoryPressure trims samples or resets if disconnected', () {
      monitor.openDashboard();
      monitor.applyStatus(
        const RuntimeTrafficStatus(
          uplinkBytesPerSecond: 10,
          downlinkBytesPerSecond: 20,
          uplinkTotalBytes: 100,
          downlinkTotalBytes: 200,
          available: true,
        ),
      );

      final now = DateTime(2026, 1, 1, 12, 0);
      for (var i = 0; i < 100; i++) {
        monitor.recordTrafficSample(now.add(Duration(seconds: i)));
      }
      expect(monitor.samplesCount, 100);

      // Memory pressure while connected: trim to 60
      monitor.handleMemoryPressure(connected: true);
      expect(monitor.samplesCount, 60);

      // Memory pressure while disconnected: reset everything
      connected = false;
      monitor.handleMemoryPressure(connected: false);
      expect(monitor.samplesCount, 0);
      expect(monitor.trafficAvailable, isFalse);
    });

    test('handleTrafficStatusEvent flushes immediately if elapsed >= interval', () {
      final event = {
        'uplink': 100,
        'downlink': 200,
        'uplinkTotal': 1000,
        'downlinkTotal': 2000,
        'trafficAvailable': true,
      };

      monitor.handleTrafficStatusEvent(event);
      expect(monitor.uplinkBytesPerSecond, 100);
      expect(monitor.downlinkBytesPerSecond, 200);
      expect(monitor.uplinkTotalBytes, 1000);
      expect(monitor.downlinkTotalBytes, 2000);
      expect(monitor.trafficAvailable, isTrue);
    });

    test('suspendForegroundWork cancels timers and pending events', () {
      monitor.suspendForegroundWork();
      expect(monitor.isTrafficDashboardOpen, isFalse);
    });
  });
}
