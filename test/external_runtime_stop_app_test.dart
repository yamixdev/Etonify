import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/app/app.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/app/providers/subscription_catalog_provider.dart';
import 'package:meow_client/app/providers/vpn_lifecycle_commands_provider.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/features/home/home_page.dart';
import 'package:meow_client/features/home/traffic_dashboard_page.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

import 'support/windows_storage_fixture.dart';

const _subscription = Subscription(
  id: 'external-stop',
  name: 'Test profile',
  url: '',
  selectedProxyTag: 'test',
  outbounds: [
    Outbound(
      tag: 'test',
      name: 'Test server',
      config: {'type': 'socks', 'server': '192.0.2.1', 'server_port': 1080},
    ),
  ],
);

class _Runtime extends Fake implements SingboxRuntime {
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  var running = true;
  var startCalls = 0;
  var stopCalls = 0;
  var externalStopRevision = 0;
  var stateRevision = 1;
  var runtimeGeneration = 1;
  var prepareCalls = 0;
  Completer<bool>? prepareGate;
  Map<String, dynamic> externalIpInfo = {};
  NetworkInterfaceSnapshot network = const NetworkInterfaceSnapshot(
    available: true,
    interfaceName: 'wlan0',
    interfaceIndex: 1,
    generation: 1,
    reason: 'test',
    updatedAtMillis: 1,
  );

  @override
  Future<Map<String, dynamic>> lookupOutboundExternalInfo({
    required String outboundTag,
  }) async => externalIpInfo;

  Map<String, dynamic> snapshot() => {
    'running': running,
    'mode': running ? 'vpn' : '',
    'runtimeGeneration': running ? runtimeGeneration : 0,
    'externalStopRevision': externalStopRevision,
    'runtimeStateRevision': stateRevision,
    'runtimeIntentFresh': running,
    'activeRuntimeOwner': running,
  };

  void stopFromNotification() {
    running = false;
    externalStopRevision++;
    stateRevision++;
    controller.add({'type': 'state', ...snapshot()});
  }

  @override
  Stream<Map<String, dynamic>> get events => controller.stream;
  @override
  Future<Map<String, dynamic>> status() async => snapshot();
  @override
  Future<AppVersionInfo> getAppVersionInfo() async => const AppVersionInfo(
    packageName: 'test',
    versionName: '0.3.9',
    versionCode: 39,
  );
  @override
  Future<LibboxCapabilities> getCoreCapabilities() async =>
      LibboxCapabilities.parseOrLegacy('''{
        "api_version":4,"core_version":"1.15.0","tun_stacks":["native","system"],
        "supports_url_test_handoff":true,"supports_group_url_test_sessions":true,
        "supports_url_test_concurrency":true,"supports_url_test_timeout":true,
        "supports_url_test_delta_stream":true,"supports_url_test_session_status":true,
        "url_test_completion_model":"session_events"
      }''');
  @override
  Future<bool> prepareVpn({required bool requiresVpn}) async {
    prepareCalls++;
    return prepareGate == null ? false : prepareGate!.future;
  }

  @override
  Future<NetworkInterfaceSnapshot> getNetworkInterfaceState() async => network;
  @override
  Future<void> start({
    required String config,
    required bool useVpn,
    int? expectedExternalStopRevision,
  }) async {
    if (expectedExternalStopRevision != null &&
        expectedExternalStopRevision != externalStopRevision) {
      throw StateError('stale external stop revision');
    }
    startCalls++;
    running = true;
    runtimeGeneration++;
    stateRevision++;
    controller.add({'type': 'state', ...snapshot()});
  }

  @override
  Future<void> startPrepared({
    required bool useVpn,
    int? expectedExternalStopRevision,
  }) => start(
    config: '',
    useVpn: useVpn,
    expectedExternalStopRevision: expectedExternalStopRevision,
  );
  @override
  Future<void> stop({String reason = 'unspecified'}) async {
    stopCalls++;
    running = false;
    stateRevision++;
    controller.add({'type': 'state', ...snapshot()});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getRuntimeFlags) {
      return Future.value(const RuntimeFlags());
    }
    if (invocation.memberName == #getCoreVersion) {
      return Future<String?>.value('1.15.0');
    }
    if (invocation.memberName == #getConfigPath) {
      return Future<String?>.value(null);
    }
    if ([
      #querySelectedOutbounds,
      #lookupOutboundExternalInfo,
      #getPerformanceSnapshot,
      #getPlatformDeviceInfo,
      #getSubscriptionRequestDeviceInfo,
      #prepareStartupUrlTest,
    ].contains(invocation.memberName)) {
      return Future.value(<String, dynamic>{});
    }
    if ([
      #vpnPermissionGranted,
      #ensureNotificationPermission,
    ].contains(invocation.memberName)) {
      return Future.value(true);
    }
    return Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Runtime runtime;
  setUp(() async {
    runtime = _Runtime();
    for (final name in [
      'meow_client/deep_links',
      'meow_client/deep_link_events',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
    directory = await Directory.systemTemp.createTemp('etonify-external-stop-');
    await bootstrapWindowsStorageFixture(directory);
    Hive.init(directory.path);
    await SubscriptionStore.init();
    await SubscriptionStore.save(_subscription);
  });
  tearDown(() async {
    await runtime.controller.close();
    await SubscriptionStore.close();
    await Hive.close();
    await directory.delete(recursive: true);
    for (final name in [
      'meow_client/deep_links',
      'meow_client/deep_link_events',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  for (final queryOnly in [false, true]) {
    testWidgets(
      queryOnly
          ? 'open server details clear the exit IP on query-only network handover'
          : 'open server details clear the confirmed exit IP immediately on network loss',
      (tester) async {
        runtime.externalIpInfo = {'ip': '203.0.113.7', 'countryCode': 'SE'};
        final state = AppSettingsController()
            .toState(
              onboardingCompleted: true,
              acceptedLegalVersion: '0.2.1',
              acceptedLegalAtMillis: 1,
              activeProfileId: _subscription.id,
              selectedProxyTag: 'test',
            )
            .copyWith(
              localeCode: 'en',
              autoConnectOnLaunch: false,
              autoCheckServers: false,
              autoCheckNoticeAcknowledged: true,
              hwidDefaultNoticeShown: true,
            );
        final container = ProviderContainer(
          overrides: [singboxRuntimeProvider.overrideWithValue(runtime)],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 16));
          container.dispose();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MeowClient(store: MemoryAppSettingsStore(state)),
          ),
        );
        await tester.pumpAndSettle();
        container
            .read(subscriptionCatalogProvider.notifier)
            .replace(
              subscriptions: [_subscription],
              activeProfileId: _subscription.id,
              selectedProxyTag: 'test',
            );
        await tester.pumpAndSettle();
        runtime.stateRevision++;
        runtime.controller.add({'type': 'state', ...runtime.snapshot()});
        await tester.pump();
        runtime.controller.add({
          'type': 'network',
          'reason': 'default_interface',
          'networkGeneration': 1,
          'interfaceName': 'wlan0',
          'interfaceIndex': 1,
        });
        await tester.pump();
        runtime.controller.add({
          'type': 'groups',
          'runtimeGeneration': 1,
          'networkGeneration': 1,
          'groups': [
            {
              'tag': 'select',
              'selected': 'test',
              'items': [
                {'tag': 'test', 'type': 'socks'},
              ],
            },
          ],
        });
        await tester.pump();
        tester
            .widget<HomePage>(find.byType(HomePage))
            .actions
            .refreshActiveProxyIp!();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<HomePage>(find.byType(HomePage))
              .state
              .serverConnectionInfo
              .exitIp,
          '203.0.113.7',
          reason: AppLogStore.entries.value
              .map((e) => '${e.title}: ${e.message}')
              .join('\n'),
        );
        tester
            .widget<HomePage>(find.byType(HomePage))
            .actions
            .openServerInfo!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final page = tester.widget<TrafficDashboardPage>(
          find.byType(TrafficDashboardPage),
        );
        final source = page.serverConnectionListenable!;
        final oldKey = source.value.key;
        expect(source.value.exitIp, '203.0.113.7');
        runtime.network = NetworkInterfaceSnapshot(
          available: queryOnly,
          interfaceName: queryOnly ? 'rmnet_data0' : '',
          interfaceIndex: queryOnly ? 2 : 0,
          generation: 2,
          reason: 'no_default_interface',
          updatedAtMillis: 2,
        );
        if (queryOnly) {
          tester
              .widget<HomePage>(find.byType(HomePage))
              .actions
              .refreshActiveProxyIp!();
        } else {
          runtime.controller.add({
            'type': 'network',
            'reason': 'no_default_interface',
            'networkGeneration': 2,
            'interfaceName': '',
            'interfaceIndex': 0,
          });
        }
        await tester.pump();
        await tester.pump();
        if (queryOnly) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
        }
        expect(source.value.exitIp, isEmpty);
        expect(source.value.key, isNot(oldKey));
        expect(source.value.connected, isTrue);
      },
    );
  }

  for (final replayStoppedState in [false, true]) {
    testWidgets(
      replayStoppedState
          ? 'late stopped snapshot does not reset a newer manual connection'
          : 'notification stop routes the next single Connect to preparation, not Stop',
      (tester) async {
        final state = AppSettingsController()
            .toState(
              onboardingCompleted: true,
              acceptedLegalVersion: '0.2.1',
              acceptedLegalAtMillis: 1,
              activeProfileId: _subscription.id,
              selectedProxyTag: 'test',
            )
            .copyWith(
              localeCode: 'en',
              autoConnectOnLaunch: false,
              autoCheckServers: false,
              autoCheckNoticeAcknowledged: true,
              hwidDefaultNoticeShown: true,
            );
        final container = ProviderContainer(
          overrides: [singboxRuntimeProvider.overrideWithValue(runtime)],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 16));
          container.dispose();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MeowClient(store: MemoryAppSettingsStore(state)),
          ),
        );
        await tester.pumpAndSettle();
        container
            .read(subscriptionCatalogProvider.notifier)
            .replace(
              subscriptions: [_subscription],
              activeProfileId: _subscription.id,
              selectedProxyTag: 'test',
            );
        await tester.pumpAndSettle();
        expect(
          tester.widget<HomePage>(find.byType(HomePage)).state.connected,
          isTrue,
        );
        runtime.stopFromNotification();
        await tester.pumpAndSettle();
        expect(
          tester.widget<HomePage>(find.byType(HomePage)).state.connected,
          isFalse,
        );
        final stoppedSnapshot = runtime.snapshot();
        if (replayStoppedState) runtime.prepareGate = Completer<bool>();
        final toggling = container
            .read(vpnLifecycleCommandsProvider)
            .toggle(source: 'test.single_connect');
        if (replayStoppedState) {
          await tester.pump();
          await tester.pump();
          expect(runtime.prepareCalls, 1);
          expect(
            tester.widget<HomePage>(find.byType(HomePage)).state.connecting,
            isTrue,
          );
          runtime.controller.add({'type': 'state', ...stoppedSnapshot});
          await tester.pump();
          expect(
            tester.widget<HomePage>(find.byType(HomePage)).state.connecting,
            isTrue,
          );
          runtime.prepareGate!.complete(false);
        }
        await toggling;
        await tester.pumpAndSettle();
        expect(
          runtime.stopCalls,
          0,
          reason: 'first Connect must not issue a redundant Stop',
        );
        expect(
          runtime.prepareCalls,
          1,
          reason: AppLogStore.entries.value
              .map((entry) => '${entry.title}: ${entry.message}')
              .join('\n'),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<HomePage>(find.byType(HomePage)).state.connected,
          isFalse,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 16));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
