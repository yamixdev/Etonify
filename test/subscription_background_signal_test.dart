import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/subscription/subscription_background_updates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native download wakes live client and detached client is ignored',
    () async {
      var deliveries = 0;
      SubscriptionBackgroundUpdates.listen();
      SubscriptionBackgroundUpdates.onDownloadReady = () => deliveries++;
      Future<void> send(String method) async {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'meow_client/subscription_refresh',
              const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
              (_) {},
            );
      }

      await send('downloadReady');
      expect(deliveries, 1);
      await send('other');
      expect(deliveries, 1);
      SubscriptionBackgroundUpdates.onDownloadReady = null;
      await send('downloadReady');
      expect(deliveries, 1);
    },
  );
}
