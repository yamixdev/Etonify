import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/backup/etonify_backup_service.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  const service = EtonifyBackupService();

  Subscription sampleSubscription() {
    return const Subscription(
      id: 'sub-1',
      name: 'Demo',
      url: 'https://example.com/sub',
      selectedProxyTag: 'node-1',
      rawContent: 'vless://secret@example.com',
    );
  }

  test('encrypted profile decrypts only with the correct password', () {
    final content = service.buildProfileExport(
      subscriptions: [sampleSubscription()],
      clientVersion: '0.2.0',
      encryption: EtonifyProfileEncryption.encrypted,
      password: 'correct-password',
    );

    expect(
      () => service.parseProfileExport(
        bytes: utf8.encode(content),
        currentClientVersion: '0.2.0',
        password: 'wrong-password',
      ),
      throwsA(isA<EtonifyBackupException>()),
    );

    final parsed = service.parseProfileExport(
      bytes: utf8.encode(content),
      currentClientVersion: '0.2.0',
      password: 'correct-password',
    );

    expect(parsed.encryption, EtonifyProfileEncryption.encrypted);
    expect(parsed.subscriptions.single.id, 'sub-1');
    expect(
      parsed.subscriptions.single.rawContent,
      'vless://secret@example.com',
    );
  });

  test('plain profile imports with plaintext warning metadata', () {
    final content = service.buildProfileExport(
      subscriptions: [sampleSubscription()],
      clientVersion: '0.2.0',
      encryption: EtonifyProfileEncryption.plain,
    );

    final parsed = service.parseProfileExport(
      bytes: utf8.encode(content),
      currentClientVersion: '0.2.0',
    );

    expect(parsed.encryption, EtonifyProfileEncryption.plain);
    expect(parsed.warning.compatibility, ExportCompatibilityStatus.compatible);
    expect(parsed.subscriptions.single.selectedProxyTag, 'node-1');
  });

  test('large backup keeps profiles and their servers separate', () async {
    final first = sampleSubscription().copyWith(
      name: 'First profile',
      rawContent: ''.padRight(9 * 1024 * 1024, 'a'),
      outbounds: const [
        Outbound(
          tag: 'first-1',
          name: 'First one',
          config: {'type': 'vless', 'server': 'first.example'},
        ),
        Outbound(
          tag: 'first-2',
          name: 'First two',
          config: {'type': 'vless', 'server': 'second.example'},
        ),
      ],
    );
    final second = sampleSubscription().copyWith(
      id: 'sub-2',
      url: 'https://example.com/sub-2',
      name: 'Second profile',
      selectedProxyTag: 'second-1',
      rawContent: 'vless://second',
      outbounds: const [
        Outbound(
          tag: 'second-1',
          name: 'Second one',
          config: {'type': 'vless', 'server': 'third.example'},
        ),
      ],
    );

    final bytes = await service.buildProfileExportBytesInBackground(
      subscriptions: [first, second],
      clientVersion: '0.2.2',
      encryption: EtonifyProfileEncryption.plain,
    );
    expect(bytes.length, greaterThan(8 * 1024 * 1024));
    expect(
      service.detectProfileEncryption(bytes),
      EtonifyProfileEncryption.plain,
    );

    final parsed = await service.parseProfileExportInBackground(
      bytes: bytes,
      currentClientVersion: '0.2.2',
    );

    expect(parsed.subscriptions.map((item) => item.name), [
      'First profile',
      'Second profile',
    ]);
    expect(parsed.subscriptions[0].outbounds.map((item) => item.tag), [
      'first-1',
      'first-2',
    ]);
    expect(parsed.subscriptions[1].outbounds.map((item) => item.tag), [
      'second-1',
    ]);
  });

  test('detects encrypted profile before the expensive full decode', () async {
    final bytes = await service.buildProfileExportBytesInBackground(
      subscriptions: [sampleSubscription()],
      clientVersion: '0.3.1',
      encryption: EtonifyProfileEncryption.encrypted,
      password: 'correct-password',
    );

    expect(
      service.detectProfileEncryption(bytes),
      EtonifyProfileEncryption.encrypted,
    );
    expect(service.detectProfileEncryption(utf8.encode('{}')), isNull);
  });

  test('rejects backups that require a newer minimum client version', () {
    final content = service.buildProfileExport(
      subscriptions: [sampleSubscription()],
      clientVersion: '0.3.0',
      encryption: EtonifyProfileEncryption.plain,
    );
    final map = jsonDecode(content) as Map<String, dynamic>;
    map['minClientVersion'] = '0.3.0';

    final parsed = service.parseProfileExport(
      bytes: utf8.encode(jsonEncode(map)),
      currentClientVersion: '0.2.0',
    );

    expect(parsed.warning.compatibility, ExportCompatibilityStatus.unsupported);
  });

  test('rejects unknown top-level sections', () {
    final content = service.buildProfileExport(
      subscriptions: [sampleSubscription()],
      clientVersion: '0.2.0',
      encryption: EtonifyProfileEncryption.plain,
    );
    final map = jsonDecode(content) as Map<String, dynamic>;
    map['unexpected'] = true;

    expect(
      () => service.parseProfileExport(
        bytes: utf8.encode(jsonEncode(map)),
        currentClientVersion: '0.2.0',
      ),
      throwsA(isA<EtonifyBackupException>()),
    );
  });
}
