import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('meow-client-hive-test-');
    Hive.init(tempDir.path);
    await SubscriptionStore.init();
  });

  setUp(() async {
    await SubscriptionStore.clear();
  });

  tearDownAll(() async {
    await SubscriptionStore.clear();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('concurrent delete and saveMetadata does not resurrect subscription', () async {
    final sub = Subscription(
      id: 'sub-race-1',
      name: 'Test Sub 1',
      url: 'https://example.com/sub',
      selectedProxyTag: 'proxy-1',
      outbounds: const [
        Outbound(
          tag: 'proxy-1',
          name: 'Proxy 1',
          config: <String, dynamic>{
            'type': 'vless',
            'server': '1.2.3.4',
            'server_port': 443,
          },
        ),
      ],
      rawContent: 'test-raw-content',
    );
    await SubscriptionStore.save(sub);
    expect(SubscriptionStore.get('sub-race-1'), isNotNull);

    // Launch concurrent delete and saveMetadata operations
    final deleteFuture = SubscriptionStore.delete('sub-race-1');
    final saveMetaFuture = SubscriptionStore.saveMetadata(
      sub.copyWith(name: 'Updated Concurrently'),
    );

    await Future.wait([deleteFuture, saveMetaFuture]);

    // Subscription must remain deleted (not resurrected by saveMetadata)
    expect(SubscriptionStore.get('sub-race-1'), isNull);
    expect(
      SubscriptionStore.getAllMetadata().any((s) => s.id == 'sub-race-1'),
      isFalse,
    );
  });

  test(
    'concurrent delete and saveOutboundRuntimeInfoInBackground does not resurrect payload',
    () async {
      final sub = Subscription(
        id: 'sub-race-2',
        name: 'Test Sub 2',
        url: 'https://example.com/sub',
        selectedProxyTag: 'proxy-1',
        outbounds: const [
          Outbound(
            tag: 'proxy-1',
            name: 'Proxy 1',
            config: <String, dynamic>{
              'type': 'vless',
              'server': '1.2.3.4',
              'server_port': 443,
            },
          ),
        ],
        rawContent: 'test-raw-content',
      );
      await SubscriptionStore.save(sub);
      expect(SubscriptionStore.get('sub-race-2'), isNotNull);

      final deleteFuture = SubscriptionStore.delete('sub-race-2');
      final saveRuntimeFuture =
          SubscriptionStore.saveOutboundRuntimeInfoInBackground(
            'sub-race-2',
            externalInfos: {
              'proxy-1': {
                'exit_country': 'US',
                'external_ip': '8.8.8.8',
              },
            },
          );

      await Future.wait([deleteFuture, saveRuntimeFuture]);

      expect(SubscriptionStore.get('sub-race-2'), isNull);
      expect(SubscriptionStore.payloadSnapshotFor('sub-race-2'), isNull);
    },
  );

  test('deleteMany and clear cleanly purge all subscriptions under lock', () async {
    final subA = Subscription(
      id: 'sub-a',
      name: 'Sub A',
      url: 'https://example.com/a',
      selectedProxyTag: 'proxy-a',
      outbounds: const [],
      rawContent: 'raw-a',
    );
    final subB = Subscription(
      id: 'sub-b',
      name: 'Sub B',
      url: 'https://example.com/b',
      selectedProxyTag: 'proxy-b',
      outbounds: const [],
      rawContent: 'raw-b',
    );
    await SubscriptionStore.save(subA);
    await SubscriptionStore.save(subB);

    expect(SubscriptionStore.getAllMetadata().length, 2);

    await SubscriptionStore.deleteMany(['sub-a']);
    expect(SubscriptionStore.get('sub-a'), isNull);
    expect(SubscriptionStore.get('sub-b'), isNotNull);

    await SubscriptionStore.clear();
    expect(SubscriptionStore.getAllMetadata(), isEmpty);
  });
}
