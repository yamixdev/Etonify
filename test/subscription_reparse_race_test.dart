import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/vm/storage_backend_vm.dart';
import 'package:hive_ce/src/box/box_base_impl.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';

import 'support/windows_storage_fixture.dart';

class _ReadObserver extends Fake implements RandomAccessFile {
  _ReadObserver(this.delegate, this.onFirstRead);

  final RandomAccessFile delegate;
  final void Function() onFirstRead;
  bool observed = false;

  @override
  Future<Uint8List> read(int bytes) async {
    final result = await delegate.read(bytes);
    if (!observed) {
      observed = true;
      onFirstRead();
    }
    return result;
  }

  @override
  Future<RandomAccessFile> setPosition(int position) =>
      delegate.setPosition(position);

  @override
  Future<int> readInto(List<int> buffer, [int start = 0, int? end]) =>
      delegate.readInto(buffer, start, end);

  @override
  Future<void> close() => delegate.close();
}

const _oldRaw = 'vless://uuid@old.example:443?security=tls#Old';
const _newRaw = 'vless://uuid@new.example:443?security=tls#New';
const _original = Subscription(
  id: 'reparse-race',
  name: 'Original',
  url: 'https://provider.example/sub',
  rawContent: _oldRaw,
  selectedProxyTag: 'old',
  outbounds: [
    Outbound(
      tag: 'old',
      name: 'Old',
      config: {'type': 'vless', 'server': 'old.example'},
    ),
  ],
);

void main() {
  late Directory directory;
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('etonify-reparse-race-');
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

  test(
    'reparse rejects results when a newer payload is queued after its read',
    () async {
      final box =
          Hive.lazyBox<dynamic>('subscription_payloads_secure_v1')
              as BoxBaseImpl<dynamic>;
      // ignore: invalid_use_of_protected_member
      final backend = box.backend as StorageBackendVm;
      final originalFile = backend.readRaf;
      late Future<void> replacement;
      final observer = _ReadObserver(originalFile, () {
        replacement = SubscriptionStore.save(
          _original.copyWith(
            name: 'Restored',
            rawContent: _newRaw,
            selectedProxyTag: 'new',
            lastUpdated: 12345,
            outbounds: const [
              Outbound(
                tag: 'new',
                name: 'New',
                config: {'type': 'vless', 'server': 'new.example'},
              ),
            ],
          ),
        );
      });
      backend.readRaf = observer;
      try {
        await expectLater(
          SubscriptionStore.reparseFromRaw(_original.id),
          throwsA(isA<StateError>()),
        );
        await replacement;
      } finally {
        if (identical(backend.readRaf, observer)) {
          backend.readRaf = originalFile;
        }
      }
      final saved = (await SubscriptionStore.get(_original.id))!;
      expect(saved.rawContent, _newRaw);
      expect(saved.outbounds.single.config['server'], 'new.example');
      expect(saved.selectedProxyTag, 'new');
      expect(saved.lastUpdated, 12345);
    },
  );

  test('reparse preserves metadata-only edits queued after its read', () async {
    final box =
        Hive.lazyBox<dynamic>('subscription_payloads_secure_v1')
            as BoxBaseImpl<dynamic>;
    // ignore: invalid_use_of_protected_member
    final backend = box.backend as StorageBackendVm;
    final originalFile = backend.readRaf;
    late Future<void> metadataEdit;
    final observer = _ReadObserver(originalFile, () {
      metadataEdit = SubscriptionStore.updateMetadata(
        _original.id,
        (current) => current.copyWith(name: 'Renamed', autoRefreshMinutes: 120),
      );
    });
    backend.readRaf = observer;
    try {
      final updated = await SubscriptionStore.reparseFromRaw(_original.id);
      await metadataEdit;
      expect(updated.name, 'Renamed');
      expect(updated.autoRefreshMinutes, 120);
      expect(updated.rawContent, _oldRaw);
      expect(updated.outbounds.single.config['server'], 'old.example');
    } finally {
      if (identical(backend.readRaf, observer)) {
        backend.readRaf = originalFile;
      }
    }
  });
}
