import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('subscription storage migrates and removes plaintext boxes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'etonify-hive-migration-',
    );
    addTearDown(() async {
      await Hive.close();
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    Hive.init(directory.path);

    const subscription = Subscription(
      id: 'legacy-subscription',
      name: 'Legacy',
      url: 'https://example.com/sub?token=private',
      rawContent: 'vless://private-credential@example.com',
      outbounds: <Outbound>[
        Outbound(
          tag: 'node',
          name: 'Node',
          config: <String, dynamic>{
            'type': 'vless',
            'tag': 'node',
            'uuid': '00000000-0000-4000-8000-000000000001',
          },
        ),
      ],
    );
    final metadata = await Hive.openBox<dynamic>('subscriptions');
    final payloads = await Hive.openBox<dynamic>('subscription_payloads');
    final summaries = await Hive.openBox<dynamic>('subscription_summaries');
    await metadata.put(
      subscription.id,
      jsonEncode(subscription.toMetadataMap()),
    );
    await payloads.put(
      subscription.id,
      jsonEncode(subscription.toPayloadMap()),
    );
    await summaries.put(subscription.id, subscription.name);
    await metadata.close();
    await payloads.close();
    await summaries.close();

    await SubscriptionStore.init();

    final migrated = SubscriptionStore.get(subscription.id);
    expect(migrated?.url, subscription.url);
    expect(migrated?.rawContent, subscription.rawContent);
    expect(migrated?.outbounds.single.config['uuid'], isNotEmpty);
    final storedPayload = Hive.box<dynamic>(
      'subscription_payloads_secure_v1',
    ).get(subscription.id);
    expect(storedPayload, isA<String>());
    // Startup must not rewrite and compact every legacy payload. The mixed
    // raw/compressed reader keeps this entry usable until its next save.
    expect(storedPayload as String, isNot(startsWith('gzip-base64-v1:')));
    expect(
      jsonDecode(SubscriptionStore.payloadJsonFor(subscription.id)!)
          as Map<String, dynamic>,
      containsPair('raw_content', subscription.rawContent),
    );
    expect(await Hive.boxExists('subscriptions'), isFalse);
    expect(await Hive.boxExists('subscription_payloads'), isFalse);
    expect(await Hive.boxExists('subscription_summaries'), isFalse);
    expect(await Hive.boxExists('subscriptions_secure_v1'), isTrue);
    expect(await Hive.boxExists('subscription_payloads_secure_v1'), isTrue);
  });
}
