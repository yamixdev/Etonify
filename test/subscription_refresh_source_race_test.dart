import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/data/subscription/subscription_fetcher.dart';
import 'package:meow_client/models/subscription.dart';

class _HttpOverrides extends HttpOverrides {}

void main() {
  late Directory directory;
  late HttpServer server;
  HttpOverrides? previous;
  late bool previousHwid;
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    previous = HttpOverrides.current;
    previousHwid = SubscriptionFetcher.sendHwidToProviders;
    HttpOverrides.global = _HttpOverrides();
    directory = await Directory.systemTemp.createTemp('etonify-source-race-');
    Hive.init(directory.path);
    await SubscriptionStore.init();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    await SubscriptionStore.save(
      Subscription(
        id: 'race',
        name: 'Race',
        url: 'http://127.0.0.1:${server.port}/old',
        rawContent: 'original',
        outbounds: const [
          Outbound(
            tag: 'original',
            name: 'Original',
            config: {'type': 'vless', 'server': 'original.example'},
          ),
        ],
      ),
    );
  });
  tearDown(() async {
    await server.close(force: true);
    await SubscriptionStore.close();
    await Hive.close();
    HttpOverrides.global = previous;
    SubscriptionFetcher.configureHwidSharing(previousHwid);
    await directory.delete(recursive: true);
  });

  for (final changeUrl in [true, false]) {
    test(
      'refresh rejects a response after ${changeUrl ? 'source URL' : 'request headers'} change',
      () async {
        final received = Completer<void>();
        final release = Completer<void>();
        server.listen((request) async {
          received.complete();
          await release.future;
          request.response.write(
            'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@old-provider.example:443?encryption=none&security=tls#Old',
          );
          await request.response.close();
        });
        final refresh = SubscriptionStore.refresh('race');
        final rejected = expectLater(refresh, throwsA(isA<StateError>()));
        await received.future;
        await SubscriptionStore.updateMetadata(
          'race',
          (current) => changeUrl
              ? current.copyWith(
                  url: 'https://new-provider.example/sub',
                  lastUpdated: 0,
                )
              : current.copyWith(
                  info: const SubscriptionInfo(
                    customRequestHeader: 'Authorization: new-token',
                  ),
                ),
        );
        release.complete();
        await rejected;
        final saved = (await SubscriptionStore.get('race'))!;
        expect(saved.rawContent, 'original');
        expect(saved.outbounds.single.tag, 'original');
        if (changeUrl) {
          expect(saved.url, 'https://new-provider.example/sub');
        } else {
          expect(saved.info?.customRequestHeader, 'Authorization: new-token');
        }
      },
    );
  }

  test(
    'new source starts a new refresh instead of joining the obsolete request',
    () async {
      final oldReceived = Completer<void>();
      final releaseOld = Completer<void>();
      final paths = <String>[];
      server.listen((request) async {
        paths.add(request.uri.path);
        if (request.uri.path == '/old') {
          oldReceived.complete();
          await releaseOld.future;
        }
        request.response.write(
          'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@${request.uri.path == '/old' ? 'old' : 'new'}.example:443?encryption=none&security=tls#Node',
        );
        await request.response.close();
      });
      final obsolete = SubscriptionStore.refresh('race');
      final rejected = expectLater(obsolete, throwsA(isA<StateError>()));
      await oldReceived.future;
      await SubscriptionStore.updateMetadata(
        'race',
        (current) =>
            current.copyWith(url: 'http://127.0.0.1:${server.port}/new'),
      );
      final updated = await SubscriptionStore.refresh('race');
      expect(updated.outbounds.single.config['server'], 'new.example');
      releaseOld.complete();
      await rejected;
      expect(paths, ['/old', '/new']);
      expect(
        (await SubscriptionStore.get(
          'race',
        ))!.outbounds.single.config['server'],
        'new.example',
      );
    },
  );

  test(
    'refresh preserves unrelated metadata edits made during the request',
    () async {
      final received = Completer<void>();
      final release = Completer<void>();
      server.listen((request) async {
        received.complete();
        await release.future;
        request.response.write(
          'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@new.example:443?encryption=none&security=tls#Node',
        );
        await request.response.close();
      });
      final refresh = SubscriptionStore.refresh('race');
      await received.future;
      await SubscriptionStore.updateMetadata(
        'race',
        (current) => current.copyWith(name: 'Renamed', autoRefreshMinutes: 120),
      );
      release.complete();
      final updated = await refresh;
      expect(updated.name, 'Renamed');
      expect(updated.autoRefreshMinutes, 120);
      expect(updated.outbounds.single.config['server'], 'new.example');
    },
  );

  test(
    'different TLS policies do not share or overwrite refresh responses',
    () async {
      final received = Completer<void>();
      final release = Completer<void>();
      var requests = 0;
      server.listen((request) async {
        final old = requests++ == 0;
        if (old) {
          received.complete();
          await release.future;
        }
        request.response.write(
          'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@${old ? 'insecure' : 'verified'}.example:443?encryption=none&security=tls#Node',
        );
        await request.response.close();
      });
      final old = SubscriptionStore.refresh('race', allowInsecureTls: true);
      final rejected = expectLater(old, throwsA(isA<StateError>()));
      await received.future;
      final newRequest = SubscriptionStore.refresh('race');
      release.complete();
      final verified = await newRequest;
      expect(verified.outbounds.single.config['server'], 'verified.example');
      await rejected;
      expect(requests, 2);
      expect(
        (await SubscriptionStore.get(
          'race',
        ))!.outbounds.single.config['server'],
        'verified.example',
      );
    },
  );

  test('a deleted and restored profile cannot receive its old refresh', () async {
    final received = Completer<void>();
    final release = Completer<void>();
    server.listen((request) async {
      received.complete();
      await release.future;
      request.response.write(
        'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@obsolete.example:443?encryption=none&security=tls#Node',
      );
      await request.response.close();
    });
    final old = SubscriptionStore.refresh('race');
    final rejected = expectLater(old, throwsA(isA<StateError>()));
    await received.future;
    final profile = (await SubscriptionStore.get('race'))!;
    await SubscriptionStore.delete('race');
    await SubscriptionStore.save(profile.copyWith(name: 'Restored'));
    release.complete();
    await rejected;
    final restored = (await SubscriptionStore.get('race'))!;
    expect(restored.name, 'Restored');
    expect(restored.rawContent, 'original');
  });

  test(
    'background response cannot replace a restored different payload',
    () async {
      final original = (await SubscriptionStore.get('race'))!;
      final revision = SubscriptionStore.backgroundRevision(original);
      await SubscriptionStore.delete('race');
      await SubscriptionStore.save(
        original.copyWith(
          rawContent: 'restored',
          outbounds: const [
            Outbound(
              tag: 'restored',
              name: 'Restored',
              config: {'type': 'vless', 'server': 'restored.example'},
            ),
          ],
        ),
      );
      await expectLater(
        SubscriptionStore.applyBackgroundDownload(
          'race',
          revision: revision,
          bytes: utf8.encode(
            'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@obsolete.example:443?encryption=none&security=tls#Node',
          ),
          headers: const {},
        ),
        throwsA(isA<StateError>()),
      );
      expect((await SubscriptionStore.get('race'))!.rawContent, 'restored');
    },
  );

  test(
    'a refresh from before storage reopen cannot overwrite a newer result',
    () async {
      final received = Completer<void>();
      final release = Completer<void>();
      var requests = 0;
      server.listen((request) async {
        final old = requests++ == 0;
        if (old) {
          received.complete();
          await release.future;
        }
        request.response.write(
          'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@${old ? 'old' : 'new'}.example:443?encryption=none&security=tls#Node',
        );
        await request.response.close();
      });
      final old = SubscriptionStore.refresh('race');
      final rejected = expectLater(old, throwsA(isA<StateError>()));
      await received.future;
      await SubscriptionStore.close();
      await SubscriptionStore.init();
      await SubscriptionStore.refresh('race');
      release.complete();
      await rejected;
      expect(
        (await SubscriptionStore.get(
          'race',
        ))!.outbounds.single.config['server'],
        'new.example',
      );
    },
  );

  test('refresh rejects a response after global HWID policy changes', () async {
    final received = Completer<void>();
    final release = Completer<void>();
    server.listen((request) async {
      received.complete();
      await release.future;
      request.response.write(
        'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@new.example:443?encryption=none&security=tls#Node',
      );
      await request.response.close();
    });
    final refresh = SubscriptionStore.refresh('race');
    final rejected = expectLater(refresh, throwsA(isA<StateError>()));
    await received.future;
    SubscriptionFetcher.configureHwidSharing(!previousHwid);
    release.complete();
    await rejected;
    expect((await SubscriptionStore.get('race'))!.rawContent, 'original');
  });
}
