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
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/features/proxies/proxy_panel_shell.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

import 'support/windows_storage_fixture.dart';

const _subscription = Subscription(
  id: 'offline-ping',
  name: 'Offline checks',
  url: '',
  selectedProxyTag: 'selected',
  outbounds: [
    Outbound(
      tag: 'selected',
      name: 'Selected server',
      config: {'type': 'socks', 'server': '192.0.2.1', 'server_port': 1080},
    ),
    Outbound(
      tag: 'single',
      name: 'Single server',
      config: {'type': 'socks', 'server': '192.0.2.2', 'server_port': 1080},
    ),
  ],
  groups: [
    SubscriptionGroup(
      tag: 'group',
      name: 'Nested group',
      outboundTags: ['single', 'inner', 'single'],
    ),
    SubscriptionGroup(
      tag: 'inner',
      name: 'Inner group',
      outboundTags: ['selected', 'single'],
    ),
  ],
);

class _ProbeRuntime extends Fake implements SingboxRuntime {
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  final startedConfigs = <String>[];
  final requests = <List<String>>[];
  final probeReady = Completer<void>();
  var vpnStarts = 0;
  var running = false;
  Future<void> close() => controller.close();

  @override
  Stream<Map<String, dynamic>> get events => controller.stream;

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
        "supports_url_test_handoff":true,
        "supports_group_url_test_sessions":true,
        "supports_url_test_concurrency":true,
        "supports_url_test_timeout":true,
        "supports_url_test_delta_stream":true,
        "supports_url_test_session_status":true,
        "url_test_completion_model":"session_events"
      }''');

  @override
  Future<Map<String, dynamic>> status() async => {
    'running': running,
    'mode': running ? 'probe' : '',
    'runtimeGeneration': 1,
  };

  @override
  Future<NetworkInterfaceSnapshot> getNetworkInterfaceState() async =>
      const NetworkInterfaceSnapshot(
        available: true,
        interfaceName: 'wlan0',
        interfaceIndex: 1,
        generation: 1,
        reason: 'test',
        updatedAtMillis: 1,
      );

  @override
  Future<void> startProbe(String config) async {
    startedConfigs.add(config);
    await probeReady.future;
    running = true;
  }

  @override
  Future<void> stopProbe() async => running = false;

  @override
  Future<void> start({
    required String config,
    required bool useVpn,
    int? expectedExternalStopRevision,
  }) async {
    vpnStarts++;
  }

  @override
  Future<void> urlTest({
    required String groupTag,
    String targetOutboundTag = '',
    String priorityOutboundTag = '',
    String excludeOutboundTag = '',
    String url = '',
    int timeoutMillis = 3000,
    int concurrency = 0,
    int deadlineMillis = 10000,
    bool force = true,
    String mode = 'background',
    List<String> includeOutboundTags = const [],
    String logicalSessionId = '',
    int physicalNetworkEpoch = 0,
    int startupLeaseToken = 0,
  }) async {
    requests.add(List.of(includeOutboundTags));
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
    if (invocation.memberName == #querySelectedOutbounds) {
      return Future.value(<String, dynamic>{});
    }
    if (invocation.memberName == #vpnPermissionGranted) {
      return Future.value(true);
    }
    return Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _ProbeRuntime runtime;
  setUp(() async {
    runtime = _ProbeRuntime();
    for (final name in [
      'meow_client/deep_links',
      'meow_client/deep_link_events',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
    directory = await Directory.systemTemp.createTemp('etonify-offline-row-');
    await bootstrapWindowsStorageFixture(directory);
    Hive.init(directory.path);
    await SubscriptionStore.init();
    await SubscriptionStore.save(_subscription);
  });
  tearDown(() async {
    if (!runtime.probeReady.isCompleted) runtime.probeReady.complete();
    if (!runtime.controller.isClosed) await runtime.close();
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

  for (final (tag, expected) in [
    ('single', ['single']),
    ('group', ['single', 'selected']),
  ]) {
    testWidgets(
      'disconnected $tag ping uses one scoped probe without selecting',
      (tester) async {
        final state = AppSettingsController()
            .toState(
              onboardingCompleted: true,
              acceptedLegalVersion: '0.2.1',
              acceptedLegalAtMillis: 1,
              activeProfileId: '',
              selectedProxyTag: '',
            )
            .copyWith(
              homeNavigationMode: HomeNavigationMode.panel,
              localeCode: 'en',
              autoCheckServers: false,
              autoCheckNoticeAcknowledged: true,
              hwidDefaultNoticeShown: true,
            );
        final container = ProviderContainer(
          overrides: [singboxRuntimeProvider.overrideWithValue(runtime)],
        );
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
              selectedProxyTag: 'selected',
            );
        await tester.pump();
        final panel = tester.widget<ProxyPanelShell>(
          find.byType(ProxyPanelShell),
        );
        const metrics = ProxyPanelMetrics(
          bottomInset: 0,
          panelHeight: 700,
          maxPanelHeight: 700,
          viewportHeight: 700,
          viewportLimit: 700,
          progress: 1,
          backdropProgress: 1,
          atMaxExtent: true,
          canFillScreen: true,
          collapseOnAnyDownwardDrag: true,
          dragging: false,
          animating: false,
        );
        final notifier = ValueNotifier(metrics);
        final scroll = ScrollController();
        final page =
            panel.sheetBuilder(
                  tester.element(find.byType(ProxyPanelShell)),
                  metrics,
                  notifier,
                  scroll,
                  ProxyPanelGestures(onHeaderTap: () {}),
                )
                as ProxiesPage;
        expect(page.connected, isFalse);
        final first = page.onProxyUrlTest!(tag);
        await tester.pump();
        final repeated = page.onProxyUrlTest!(tag);
        for (var i = 0; i < 30 && runtime.startedConfigs.isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(
          runtime.startedConfigs,
          hasLength(1),
          reason: AppLogStore.entries.value
              .map((e) => '${e.title}: ${e.message}')
              .join('\n'),
        );
        runtime.probeReady.complete();
        for (var i = 0; i < 20 && runtime.requests.isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          runtime.requests,
          hasLength(1),
          reason: AppLogStore.entries.value
              .map((e) => '${e.title}: ${e.message}')
              .join('\n'),
        );
        expect(runtime.requests.single, unorderedEquals(expected));
        expect(runtime.vpnStarts, 0);
        expect(
          container.read(subscriptionCatalogProvider).selectedProxyTag,
          'selected',
        );
        unawaited(page.onUrlTest());
        await tester.pump();
        var finished = false;
        unawaited(Future.wait([first, repeated]).then((_) => finished = true));
        for (var i = 0; i < 30 && !finished; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(finished, isTrue);
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        notifier.dispose();
        scroll.dispose();
        container.dispose();
        await runtime.close();
      },
    );
  }
}
