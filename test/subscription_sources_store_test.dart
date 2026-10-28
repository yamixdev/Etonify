import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/data/backup/etonify_backup_service.dart';
import 'dart:convert';
import 'support/windows_storage_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late HttpServer server;
  var secondFails = false;
  var firstNode = 'first.test';
  Completer<void>? started;
  Completer<void>? release;
  String node(String host) =>
      'vless://11111111-1111-4111-8111-111111111111@$host:443?security=tls&type=tcp#Same';
  setUpAll(() async {
    HttpOverrides.global = null;
    directory = await Directory.systemTemp.createTemp('sources');
    await bootstrapWindowsStorageFixture(directory);
    Hive.init(directory.path);
    await SubscriptionStore.init();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/two' && started != null) {
        started!.complete();
        await release!.future;
      }
      if (request.uri.path == '/two' && secondFails) {
        request.response.statusCode = 503;
      } else {
        request.response.write(
          node(request.uri.path == '/two' ? 'second.test' : firstNode),
        );
      }
      await request.response.close();
    });
  });
  tearDownAll(() async {
    await server.close(force: true);
    await Hive.close();
    await directory.delete(recursive: true);
  });
  String url(String path) => 'http://127.0.0.1:${server.port}/$path';

  test(
    'legacy profile gains sources and refresh replaces only its own servers',
    () async {
      final first = (await SubscriptionStore.addFromUrl(
        url('one'),
      )).subscription;
      final oldTag = first.outbounds.single.tag;
      final added = (await SubscriptionStore.addFromUrl(
        url('two'),
        targetProfileId: first.id,
      )).subscription;
      expect(added.sources.length, 2);
      expect(added.outbounds.length, 2);
      expect(added.outbounds.map((o) => o.tag).toSet().length, 2);
      expect(added.outbounds.map((o) => o.tag), contains(oldTag));
      final restored = Subscription.fromMap(added.toMap());
      expect(restored.sources[1].snapshot.outbounds.length, 1);
      firstNode = 'replaced.test';
      secondFails = true;
      final updated = await SubscriptionStore.refresh(first.id);
      expect(updated.outbounds.length, 2);
      expect(
        updated.outbounds.map((o) => o.config['server']),
        containsAll(['replaced.test', 'second.test']),
      );
      expect(updated.sources[1].lastError, isNotNull);
      expect(updated.sources.first.lastError, isNull);
      secondFails = false;
      final again = await SubscriptionStore.refresh(first.id);
      expect(again.outbounds.length, 2);
      expect(again.sources[1].lastError, isNull);
      await expectLater(
        SubscriptionStore.addFromUrl(url('two'), targetProfileId: first.id),
        throwsStateError,
      );
      expect((await SubscriptionStore.get(first.id))!.sources.length, 2);
    },
  );

  test(
    'manual servers survive remote refresh and disabling a source is reversible',
    () async {
      final first = (await SubscriptionStore.addFromUrl(
        url('one'),
      )).subscription;
      final added = (await SubscriptionStore.addFromContent(
        node('manual.test'),
        targetProfileId: first.id,
      )).subscription;
      final localId = added.sources.last.id;
      expect((await SubscriptionStore.refresh(first.id)).outbounds.length, 2);
      expect(
        (await SubscriptionStore.setSourceEnabled(
          first.id,
          localId,
          false,
        )).outbounds.length,
        1,
      );
      expect(
        (await SubscriptionStore.setSourceEnabled(
          first.id,
          localId,
          true,
        )).outbounds.length,
        2,
      );
      expect(
        (await SubscriptionStore.removeSource(
          first.id,
          localId,
        )).outbounds.length,
        1,
      );
      await expectLater(
        SubscriptionStore.removeSource(first.id, 'primary'),
        throwsStateError,
      );
    },
  );

  test('reparse and encrypted backup retain every source payload', () async {
    final first = (await SubscriptionStore.addFromUrl(url('one'))).subscription;
    final added = (await SubscriptionStore.addFromContent(
      node('manual.test'),
      targetProfileId: first.id,
    )).subscription;
    final reparsed = await SubscriptionStore.reparseFromRaw(first.id);
    expect(reparsed.outbounds.length, 2);
    const service = EtonifyBackupService();
    final export = service.buildProfileExport(
      subscriptions: [reparsed],
      clientVersion: '0.3.11',
      encryption: EtonifyProfileEncryption.encrypted,
      password: 'test-password',
    );
    final restored = service
        .parseProfileExport(
          bytes: utf8.encode(export),
          currentClientVersion: '0.3.11',
          password: 'test-password',
        )
        .subscriptions
        .single;
    expect(restored.sources.length, 2);
    expect(
      restored.sources.last.snapshot.rawContent,
      added.sources.last.snapshot.rawContent,
    );
    expect(
      restored.sources.last.snapshot.outbounds.single.config['server'],
      'manual.test',
    );
  });

  test(
    'primary request edits update source metadata and survive refresh',
    () async {
      final first = (await SubscriptionStore.addFromUrl(
        url('one'),
      )).subscription;
      await SubscriptionStore.addFromContent(
        node('manual.test'),
        targetProfileId: first.id,
      );
      await SubscriptionStore.updateMetadata(
        first.id,
        (p) => p.copyWith(
          url: url('three'),
          info: (p.info ?? const SubscriptionInfo()).copyWith(
            customUserAgent: 'source-agent',
          ),
        ),
      );
      final before = (await SubscriptionStore.get(first.id))!;
      expect(before.sources.first.url, url('three'));
      expect(
        before.sources.first.snapshot.info!.customUserAgent,
        'source-agent',
      );
      final updated = await SubscriptionStore.refreshSource(
        first.id,
        'primary',
      );
      expect(updated.url, url('three'));
      expect(updated.info!.customUserAgent, 'source-agent');
      expect(updated.outbounds.length, 2);
    },
  );

  test('late response never restores a removed source', () async {
    final first = (await SubscriptionStore.addFromUrl(url('one'))).subscription;
    final added = (await SubscriptionStore.addFromUrl(
      url('two'),
      targetProfileId: first.id,
    )).subscription;
    started = Completer<void>();
    release = Completer<void>();
    final refresh = SubscriptionStore.refreshSource(
      first.id,
      added.sources.last.id,
    );
    final failed = expectLater(refresh, throwsStateError);
    await started!.future;
    await SubscriptionStore.removeSource(first.id, added.sources.last.id);
    release!.complete();
    await failed;
    started = null;
    release = null;
    final remaining = (await SubscriptionStore.get(first.id))!;
    expect(remaining.sources.length, 1);
    expect(remaining.outbounds.length, 1);
  });
}
