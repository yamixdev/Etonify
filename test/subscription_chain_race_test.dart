import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/app/app.dart';
import 'package:meow_client/app/providers/subscription_catalog_provider.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/features/proxies/proxies_page.dart';
import 'package:meow_client/features/proxies/proxy_panel_shell.dart';
import 'package:meow_client/models/subscription.dart';

import 'support/windows_storage_fixture.dart';

const _chain = SubscriptionProxyChain(
  tag: 'chain',
  name: 'Original chain',
  targetTag: 'target',
  detourTag: 'entry',
);
const _original = Subscription(
  id: 'chain-race',
  name: 'Original',
  url: 'https://provider.example/sub',
  selectedProxyTag: 'chain',
  rawContent: 'old payload',
  proxyChains: [_chain],
  outbounds: [
    Outbound(
      tag: 'entry',
      name: 'Entry',
      config: {'type': 'socks', 'server': 'entry.example', 'server_port': 1080},
    ),
    Outbound(
      tag: 'entry-next',
      name: 'Next',
      config: {'type': 'socks', 'server': 'next.example', 'server_port': 1080},
    ),
    Outbound(
      tag: 'target',
      name: 'Target',
      config: {
        'type': 'socks',
        'server': 'target.example',
        'server_port': 1080,
      },
    ),
  ],
);
const _metrics = ProxyPanelMetrics(
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

void main() {
  late Directory directory;
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('meow_client/deep_links'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('meow_client/deep_link_events'),
          (_) async => null,
        );
    directory = await Directory.systemTemp.createTemp('etonify-chain-race-');
    await bootstrapWindowsStorageFixture(directory);
    Hive.init(directory.path);
    await SubscriptionStore.init();
    await SubscriptionStore.save(_original);
  });
  tearDown(() async {
    await SubscriptionStore.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final operation in ['rename', 'remove', 'detour']) {
    for (final removed in [false, true]) {
      testWidgets(
        '$operation edits latest chain metadata after ${removed ? 'chain removal' : 'payload replacement'}',
        (tester) async {
          final container = ProviderContainer();
          final store = MemoryAppSettingsStore();
          final initial = await store.loadState();
          await store.saveState(
            initial.copyWith(
              onboardingCompleted: true,
              acceptedLegalVersion: '0.2.1',
              autoCheckNoticeAcknowledged: true,
            ),
          );
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MeowClient(store: store),
            ),
          );
          await tester.pumpAndSettle();
          container
              .read(subscriptionCatalogProvider.notifier)
              .replace(
                subscriptions: [_original],
                activeProfileId: _original.id,
                selectedProxyTag: 'chain',
              );
          await tester.pump();
          final panel = tester.widget<ProxyPanelShell>(
            find.byType(ProxyPanelShell),
          );
          final notifier = ValueNotifier(_metrics);
          final scroll = ScrollController();
          final page =
              panel.sheetBuilder(
                    tester.element(find.byType(ProxyPanelShell)),
                    _metrics,
                    notifier,
                    scroll,
                    ProxyPanelGestures(onHeaderTap: () {}),
                  )
                  as ProxiesPage;
          await tester.runAsync(() async {
            await SubscriptionStore.save(
              _original.copyWith(
                name: 'Latest',
                rawContent: 'new payload',
                lastUpdated: 12345,
                selectedProxyTag: 'entry-next',
                proxyChains: removed
                    ? []
                    : [_chain.copyWith(name: 'Latest chain')],
                info: const SubscriptionInfo(title: 'Latest title'),
              ),
            );
          });
          final revision = SubscriptionStore.getMetadata(
            _original.id,
          )!.payloadRevision;
          await tester.runAsync(() async {
            switch (operation) {
              case 'rename':
                await page.onRenameProxyChain!('chain', 'Renamed');
              case 'remove':
                await page.onRemoveProxyChain!('chain');
              case 'detour':
                await page.onChangeProxyChainDetour!('chain', 'entry-next');
            }
            await Future<void>.delayed(const Duration(seconds: 1));
          });
          await tester.runAsync(() async {
            final saved = (await SubscriptionStore.get(_original.id))!;
            expect(saved.rawContent, 'new payload');
            expect(saved.payloadRevision, revision);
            expect(saved.name, 'Latest');
            expect(saved.info?.title, 'Latest title');
            expect(saved.lastUpdated, 12345);
            expect(saved.selectedProxyTag, 'entry-next');
            if (removed || operation == 'remove') {
              expect(saved.proxyChains, isEmpty);
            } else {
              expect(
                saved.proxyChains.single.name,
                operation == 'rename' ? 'Renamed' : 'Latest chain',
              );
              expect(
                saved.proxyChains.single.detourTag,
                operation == 'detour' ? 'entry-next' : 'entry',
              );
            }
          });
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          container.dispose();
          scroll.dispose();
          notifier.dispose();
        },
      );
    }
  }
}
