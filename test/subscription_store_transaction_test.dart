import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/vm/storage_backend_vm.dart';
import 'package:hive_ce/src/box/box_base_impl.dart';
import 'package:meow_client/data/local/secure_hive_storage.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';

class _FailingFlushFile extends Fake implements RandomAccessFile {
  _FailingFlushFile(
    this.delegate, {
    required this.persistent,
    this.failAfter = 1,
  });
  final RandomAccessFile delegate;
  bool persistent;
  final int failAfter;
  int flushCalls = 0;

  @override
  Future<RandomAccessFile> flush() async {
    flushCalls++;
    if (flushCalls >= failAfter && (persistent || flushCalls == failAfter)) {
      throw const FileSystemException('Injected flush failure');
    }
    return delegate.flush();
  }

  @override
  Future<RandomAccessFile> writeFrom(
    List<int> buffer, [
    int start = 0,
    int? end,
  ]) => delegate.writeFrom(buffer, start, end);
  @override
  Future<RandomAccessFile> setPosition(int position) =>
      delegate.setPosition(position);
  @override
  Future<RandomAccessFile> truncate(int length) => delegate.truncate(length);
  @override
  Future<int> length() => delegate.length();
  @override
  Future<void> close() => delegate.close();
}

const _original = Subscription(
  id: 'transaction',
  name: 'Original',
  url: 'https://provider.example/sub',
  rawContent: 'old',
  selectedProxyTag: 'old',
  outbounds: [
    Outbound(
      tag: 'old',
      name: 'Old',
      config: {'type': 'vless', 'server': 'old.example'},
    ),
  ],
);
const _updated = Subscription(
  id: 'transaction',
  name: 'Updated',
  url: 'https://provider.example/sub',
  rawContent: 'new',
  selectedProxyTag: 'new',
  outbounds: [
    Outbound(
      tag: 'new',
      name: 'New',
      config: {'type': 'vless', 'server': 'new.example'},
    ),
  ],
);

void main() {
  late Directory directory;
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('etonify-transaction-');
    Hive.init(directory.path);
    await SubscriptionStore.init();
    await SubscriptionStore.save(_original);
  });
  tearDown(() async {
    await SubscriptionStore.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'interrupting payload storage cannot leave new metadata with old servers',
    () async {
      final payload = Hive.lazyBox<dynamic>('subscription_payloads_secure_v1');
      final watcher = Hive.box<dynamic>('subscriptions_secure_v1')
          .watch(key: _original.id)
          .listen((event) {
            final value =
                jsonDecode(event.value as String) as Map<String, dynamic>;
            if (value['name'] == 'Updated') unawaited(payload.close());
          });
      try {
        await SubscriptionStore.save(_updated);
      } catch (_) {
        /* Reopen checks the durable state after failure. */
      }
      await watcher.cancel();
      await SubscriptionStore.close();
      await SubscriptionStore.init();
      final restored = (await SubscriptionStore.loadProfileSnapshotInBackground(
        _original.id,
      ))!;
      expect(restored.rawContent, restored.name == 'Updated' ? 'new' : 'old');
      expect(restored.outbounds.single.tag, restored.selectedProxyTag);
    },
  );

  test(
    'metadata write failure restores the previous payload after reopening',
    () async {
      final metadata = Hive.box<dynamic>('subscriptions_secure_v1');
      final before = SubscriptionStore.getMetadata(_original.id)!;
      final watcher = Hive.lazyBox<dynamic>('subscription_payloads_secure_v1')
          .watch(key: _original.id)
          .listen((_) {
            unawaited(metadata.close());
          });
      Object? error;
      try {
        await SubscriptionStore.save(_updated);
      } catch (failure) {
        error = failure;
      }
      await watcher.cancel();
      await SubscriptionStore.close();
      await SubscriptionStore.init();
      final restored = (await SubscriptionStore.loadProfileSnapshotInBackground(
        _original.id,
      ))!;
      expect(error, isNotNull);
      expect(restored.name, 'Original');
      expect(restored.rawContent, 'old');
      expect(restored.selectedProxyTag, 'old');
      expect(restored.payloadRevision, before.payloadRevision);
    },
  );

  test(
    'initialization reopens an unavailable journal without closing metadata',
    () async {
      await Hive.lazyBox<dynamic>(
        'subscription_write_journal_secure_v1',
      ).close();
      await SubscriptionStore.init();
      await SubscriptionStore.save(_updated);
      expect((await SubscriptionStore.get(_original.id))!.rawContent, 'new');
    },
  );

  test('initialization retries after journal opening fails', () async {
    await SubscriptionStore.close();
    final conflictingBox = await Hive.openBox<dynamic>(
      'subscription_write_journal_secure_v1',
      encryptionCipher: SecureHiveStorage.cipher,
    );
    await expectLater(SubscriptionStore.init(), throwsA(isA<HiveError>()));
    await conflictingBox.close();
    await SubscriptionStore.init();
    expect((await SubscriptionStore.get(_original.id))!.rawContent, 'old');
    await SubscriptionStore.save(_updated);
    expect((await SubscriptionStore.get(_original.id))!.rawContent, 'new');
  });

  for (final persistent in [false, true]) {
    test(
      'journal survives ${persistent ? 'persistent' : 'one-time'} metadata flush failure',
      () async {
        // Hive exposes writeRaf as a testing hook. Inject only fsync failures;
        // serialization, writes, box commits and recovery remain real Hive code.
        final box =
            Hive.box<dynamic>('subscriptions_secure_v1')
                as BoxBaseImpl<dynamic>;
        // ignore: invalid_use_of_protected_member
        final backend = box.backend as StorageBackendVm;
        final originalFile = backend.writeRaf;
        final failingFile = _FailingFlushFile(
          originalFile,
          persistent: persistent,
        );
        backend.writeRaf = failingFile;
        await expectLater(
          SubscriptionStore.save(_updated),
          throwsA(isA<FileSystemException>()),
        );
        expect(failingFile.flushCalls, 2);
        final journal = Hive.lazyBox<dynamic>(
          'subscription_write_journal_secure_v1',
        );
        expect(journal.containsKey(_original.id), persistent);
        backend.writeRaf = originalFile;
        final recovered = (await SubscriptionStore.get(_original.id))!;
        expect(recovered.name, 'Updated');
        expect(recovered.rawContent, 'new');
        expect(journal.containsKey(_original.id), isFalse);
        await SubscriptionStore.close();
        await SubscriptionStore.init();
        expect(
          (await SubscriptionStore.get(_original.id))!.outbounds.single.tag,
          'new',
        );
      },
    );
  }

  for (final persistent in [false, true]) {
    test(
      'journal cleanup failure protects committed profile before later runtime writes ($persistent)',
      () async {
        final journal = Hive.lazyBox<dynamic>(
          'subscription_write_journal_secure_v1',
        );
        // Keep compaction from replacing the instrumented file during delete.
        for (var i = 0; i < 4; i++) {
          await journal.put('sentinel-$i', {
            'oldMetadata': null,
            'oldPayload': null,
            'newRevision': 'sentinel',
          });
        }
        final box = journal as BoxBaseImpl<dynamic>;
        // ignore: invalid_use_of_protected_member
        final backend = box.backend as StorageBackendVm;
        final originalFile = backend.writeRaf;
        final failingFile = _FailingFlushFile(
          originalFile,
          persistent: persistent,
          failAfter: 2,
        );
        backend.writeRaf = failingFile;
        await SubscriptionStore.save(_updated);
        expect(failingFile.flushCalls, 2);
        final runtimeWrite =
            SubscriptionStore.saveOutboundRuntimeInfoInBackground(
              _updated.id,
              latestPings: const {'new': 42},
              expectedOutboundKeys: {
                'new': SubscriptionStore.outboundIdentityKey(
                  _updated.outbounds.single.config,
                ),
              },
            );
        if (persistent) {
          await expectLater(runtimeWrite, throwsA(isA<FileSystemException>()));
        } else {
          expect(await runtimeWrite, isTrue);
        }
        expect(failingFile.flushCalls, greaterThanOrEqualTo(3));
        backend.writeRaf = originalFile;
        final committed = (await SubscriptionStore.get(_updated.id))!;
        expect(committed.name, 'Updated');
        expect(committed.rawContent, 'new');
        expect(
          committed.outbounds.single.info.latestPing,
          persistent ? isNot(42) : 42,
        );
        if (persistent) {
          await SubscriptionStore.saveOutboundRuntimeInfoInBackground(
            _updated.id,
            latestPings: const {'new': 42},
            expectedOutboundKeys: {
              'new': SubscriptionStore.outboundIdentityKey(
                _updated.outbounds.single.config,
              ),
            },
          );
        }
        await SubscriptionStore.close();
        await SubscriptionStore.init();
        final reopened = (await SubscriptionStore.get(_updated.id))!;
        expect(reopened.name, 'Updated');
        expect(reopened.outbounds.single.info.latestPing, 42);
      },
    );
  }

  for (final failMetadata in [true, false]) {
    test(
      'deletion flushes metadata before removing payload ($failMetadata)',
      () async {
        final metadata = Hive.box<dynamic>('subscriptions_secure_v1');
        final payload = Hive.lazyBox<dynamic>(
          'subscription_payloads_secure_v1',
        );
        final metadataBox = metadata as BoxBaseImpl<dynamic>;
        final payloadBox = payload as BoxBaseImpl<dynamic>;
        // ignore: invalid_use_of_protected_member
        final metadataBackend = metadataBox.backend as StorageBackendVm;
        // ignore: invalid_use_of_protected_member
        final payloadBackend = payloadBox.backend as StorageBackendVm;
        final originalMetadataFile = metadataBackend.writeRaf;
        final originalPayloadFile = payloadBackend.writeRaf;
        final metadataFile = _FailingFlushFile(
          originalMetadataFile,
          persistent: failMetadata,
          failAfter: failMetadata ? 1 : 99,
        );
        final payloadFile = _FailingFlushFile(
          originalPayloadFile,
          persistent: true,
        );
        metadataBackend.writeRaf = metadataFile;
        payloadBackend.writeRaf = payloadFile;
        await expectLater(
          SubscriptionStore.delete(_original.id),
          throwsA(isA<FileSystemException>()),
        );
        expect(metadataFile.flushCalls, 1);
        expect(payload.containsKey(_original.id), failMetadata);
        expect(payloadFile.flushCalls, failMetadata ? 0 : 1);
        metadataBackend.writeRaf = originalMetadataFile;
        payloadBackend.writeRaf = originalPayloadFile;
        await SubscriptionStore.delete(_original.id);
        await SubscriptionStore.close();
        await SubscriptionStore.init();
        expect(await SubscriptionStore.get(_original.id), isNull);
        expect(
          Hive.lazyBox<dynamic>(
            'subscription_payloads_secure_v1',
          ).containsKey(_original.id),
          isFalse,
        );
      },
    );
  }

  for (final background in [false, true]) {
    test(
      'reader waits for a complete profile during ${background ? 'background' : 'foreground'} save',
      () async {
        Future<Subscription?>? reading;
        final watcher = Hive.lazyBox<dynamic>('subscription_payloads_secure_v1')
            .watch(key: _original.id)
            .listen((_) {
              reading ??= background
                  ? SubscriptionStore.getInBackground(_original.id)
                  : SubscriptionStore.get(_original.id);
            });
        await SubscriptionStore.save(_updated);
        final snapshot = (await reading!)!;
        await watcher.cancel();
        expect(snapshot.name, 'Updated');
        expect(snapshot.rawContent, 'new');
        expect(snapshot.selectedProxyTag, snapshot.outbounds.single.tag);
      },
    );
  }

  test(
    'reordering a stale snapshot preserves the current payload revision and metadata',
    () async {
      final stale = SubscriptionStore.getAllMetadata();
      await SubscriptionStore.save(_updated);
      final current = SubscriptionStore.getMetadata(_original.id)!;
      await SubscriptionStore.reorder(stale);
      final reordered = (await SubscriptionStore.get(_original.id))!;
      expect(reordered.name, 'Updated');
      expect(reordered.payloadRevision, current.payloadRevision);
      expect(reordered.rawContent, 'new');
      expect(reordered.selectedProxyTag, reordered.outbounds.single.tag);
      expect(reordered.sortOrder, 0);
    },
  );

  for (final state in [
    'payloadOnly',
    'committed',
    'missingPayload',
    'corruptMetadata',
    'deleted',
    'initialImport',
  ]) {
    test('reopens a journal left at $state', () async {
      final metadata = Hive.box<dynamic>('subscriptions_secure_v1');
      final payload = Hive.lazyBox<dynamic>('subscription_payloads_secure_v1');
      final journal = Hive.lazyBox<dynamic>(
        'subscription_write_journal_secure_v1',
      );
      final oldMetadata = metadata.get(_original.id);
      final oldPayload = await payload.get(_original.id);
      await SubscriptionStore.save(_updated);
      final newMetadata = metadata.get(_updated.id);
      final newPayload = await payload.get(_updated.id);
      final newRevision = SubscriptionStore.getMetadata(
        _updated.id,
      )!.payloadRevision;
      await journal.put(_original.id, {
        'oldMetadata': state == 'initialImport' ? null : oldMetadata,
        'oldPayload': state == 'initialImport' ? null : oldPayload,
        'newRevision': newRevision,
      });
      if (state == 'payloadOnly') await metadata.put(_original.id, oldMetadata);
      if (state == 'corruptMetadata') {
        await metadata.put(_original.id, '{invalid');
      }
      if (state == 'missingPayload') {
        await metadata.put(_original.id, newMetadata);
        await payload.delete(_original.id);
      } else {
        await payload.put(_original.id, newPayload);
      }
      if (state == 'deleted' || state == 'initialImport') {
        await metadata.delete(_original.id);
      }
      await metadata.flush();
      await payload.flush();
      await journal.flush();
      await SubscriptionStore.close();
      await SubscriptionStore.init();
      final snapshot = await SubscriptionStore.get(_original.id);
      if (state == 'deleted' || state == 'initialImport') {
        expect(snapshot, isNull);
        expect(
          await Hive.lazyBox<dynamic>(
            'subscription_payloads_secure_v1',
          ).get(_original.id),
          isNull,
        );
      } else {
        expect(snapshot!.name, state == 'committed' ? 'Updated' : 'Original');
        expect(snapshot.rawContent, state == 'committed' ? 'new' : 'old');
        expect(snapshot.selectedProxyTag, snapshot.outbounds.single.tag);
      }
      expect(
        Hive.lazyBox<dynamic>('subscription_write_journal_secure_v1').isEmpty,
        isTrue,
      );
    });
  }
}
