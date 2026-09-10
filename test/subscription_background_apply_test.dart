import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/data/subscription/subscription_fetcher.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp(
      'etonify-background-test',
    );
    Hive.init(directory.path);
    await SubscriptionStore.init();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  const profile = Subscription(
    id: 'p',
    name: 'My profile',
    url: 'https://provider.test/private',
    lastUpdated: 1,
    selectedProxyTag: 'old',
  );
  final body = utf8.encode(
    'vless://11111111-1111-4111-8111-111111111111@server.test:443?security=tls&type=tcp#New',
  );

  test(
    'background payload uses normal parser and preserves profile name',
    () async {
      await SubscriptionStore.save(profile);
      final updated = await SubscriptionStore.applyBackgroundDownload(
        'p',
        revision: SubscriptionStore.backgroundRevision(profile),
        bytes: body,
        headers: const {'profile-title': 'Provider title'},
      );
      expect(updated.name, 'My profile');
      expect(updated.outbounds, isNotEmpty);
      expect(updated.lastUpdated, greaterThan(1));
    },
  );
  test('stale result cannot overwrite a newer profile', () async {
    await SubscriptionStore.save(profile.copyWith(lastUpdated: 2));
    await expectLater(
      SubscriptionStore.applyBackgroundDownload(
        'p',
        revision: SubscriptionStore.backgroundRevision(profile),
        bytes: body,
        headers: const {},
      ),
      throwsStateError,
    );
    expect(SubscriptionStore.get('p')!.lastUpdated, 2);
  });
  test('HWID opt-out invalidates a staged download revision', () {
    SubscriptionFetcher.configureHwidSharing(true);
    final before = SubscriptionStore.backgroundRevision(profile);
    SubscriptionFetcher.configureHwidSharing(false);
    expect(SubscriptionStore.backgroundRevision(profile), isNot(before));
  });
}
