import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test(
    'reopens subscription boxes after Hive closes them externally',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final tempDir = await Directory.systemTemp.createTemp(
        'meow-client-hive-reopen-',
      );
      addTearDown(() async {
        await SubscriptionStore.close();
        await Hive.close();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      Hive.init(tempDir.path);

      await SubscriptionStore.init();
      await SubscriptionStore.save(
        const Subscription(
          id: 'reopen-profile',
          name: 'Reopen profile',
          url: 'file:///reopen.txt',
          rawContent: 'vless://uuid@example.com:443#Node',
          outbounds: [
            Outbound(
              tag: 'node-1',
              name: 'Node 1',
              config: {'type': 'vless', 'server': 'example.com'},
            ),
          ],
        ),
      );

      await Hive.close();
      await SubscriptionStore.init();

      final restored = await SubscriptionStore.getInBackground(
        'reopen-profile',
      );
      expect(restored, isNotNull);
      expect(restored!.rawContent, contains('vless://'));
      expect(restored.outbounds.single.tag, 'node-1');
    },
  );
}
