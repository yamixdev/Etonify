import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:pointycastle/export.dart';

enum EtonifyProfileEncryption { encrypted, plain }

enum ExportCompatibilityStatus { compatible, newerClient, unsupported }

class EtonifyBackupException implements Exception {
  const EtonifyBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EtonifyImportWarning {
  const EtonifyImportWarning({
    required this.compatibility,
    required this.createdByVersion,
    required this.minClientVersion,
  });

  final ExportCompatibilityStatus compatibility;
  final String createdByVersion;
  final String minClientVersion;

  bool get requiresConfirmation =>
      compatibility == ExportCompatibilityStatus.newerClient;
}

class EtonifyProfileImportResult {
  const EtonifyProfileImportResult({
    required this.warning,
    required this.subscriptions,
    required this.encryption,
  });

  final EtonifyImportWarning warning;
  final List<Subscription> subscriptions;
  final EtonifyProfileEncryption encryption;
}

class EtonifySettingsImportResult {
  const EtonifySettingsImportResult({
    required this.warning,
    required this.settings,
  });

  final EtonifyImportWarning warning;
  final Map<String, dynamic> settings;
}

class EtonifyBackupService {
  const EtonifyBackupService();

  static const settingsMagic = 'ETONIFY_SETTINGS';
  static const profileMagic = 'ETONIFY_PROFILE';
  static const formatVersion = 1;
  static const minClientVersion = AppSettingsStore.exportMinClientVersion;
  // Large multi-profile exports can legitimately exceed 8 MiB. Keep a hard
  // ceiling to avoid decoding arbitrary files into several times their size.
  static const maxImportBytes = 32 * 1024 * 1024;
  static const _kdfIterations = 180000;
  static const _saltBytes = 16;
  static const _nonceBytes = 12;
  static const _keyBytes = 32;
  static const _tagBits = 128;

  String buildSettingsExport({
    required AppSettingsStore store,
    required AppSettingsState state,
    required String clientVersion,
  }) {
    final envelope = <String, dynamic>{
      'magic': settingsMagic,
      'formatVersion': formatVersion,
      'minClientVersion': minClientVersion,
      'createdByVersion': _normalizeVersion(clientVersion),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'settings': store.stateToSafeExportMap(state),
    };
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  EtonifySettingsImportResult parseSettingsExport({
    required List<int> bytes,
    required String currentClientVersion,
  }) {
    final envelope = _decodeEnvelope(bytes, expectedMagic: settingsMagic);
    final settings = envelope['settings'];
    if (settings is! Map) {
      throw const EtonifyBackupException('Settings section is missing.');
    }
    return EtonifySettingsImportResult(
      warning: _compatibility(envelope, currentClientVersion),
      settings: Map<String, dynamic>.from(settings),
    );
  }

  String buildProfileExport({
    required List<Subscription> subscriptions,
    required String clientVersion,
    required EtonifyProfileEncryption encryption,
    String? password,
  }) {
    final profile = <String, dynamic>{
      'subscriptions': subscriptions
          .map((subscription) => subscription.toMap())
          .toList(growable: false),
    };
    final envelope = <String, dynamic>{
      'magic': profileMagic,
      'formatVersion': formatVersion,
      'minClientVersion': minClientVersion,
      'createdByVersion': _normalizeVersion(clientVersion),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'encryption': encryption.name,
    };
    if (encryption == EtonifyProfileEncryption.encrypted) {
      final normalizedPassword = password?.trim() ?? '';
      if (normalizedPassword.length < 8) {
        throw const EtonifyBackupException(
          'Password must contain at least 8 characters.',
        );
      }
      final salt = _randomBytes(_saltBytes);
      final nonce = _randomBytes(_nonceBytes);
      final key = _deriveKey(normalizedPassword, salt);
      final plaintext = utf8.encode(jsonEncode(profile));
      final ciphertext = _aesGcmEncrypt(
        key: key,
        nonce: nonce,
        plaintext: Uint8List.fromList(plaintext),
      );
      envelope
        ..['kdf'] = {
          'name': 'PBKDF2-HMAC-SHA256',
          'iterations': _kdfIterations,
          'salt': base64Encode(salt),
        }
        ..['cipher'] = {
          'name': 'AES-256-GCM',
          'nonce': base64Encode(nonce),
          'tagBits': _tagBits,
        }
        ..['payload'] = base64Encode(ciphertext);
    } else {
      envelope['profile'] = profile;
    }
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Serializes and encrypts large profile exports away from the UI isolate.
  Future<String> buildProfileExportInBackground({
    required List<Subscription> subscriptions,
    required String clientVersion,
    required EtonifyProfileEncryption encryption,
    String? password,
  }) {
    return Isolate.run(
      () => const EtonifyBackupService().buildProfileExport(
        subscriptions: subscriptions,
        clientVersion: clientVersion,
        encryption: encryption,
        password: password,
      ),
      debugName: 'etonify-profile-export',
    );
  }

  /// Produces the final bytes in the worker isolate so the UI isolate never
  /// holds both a multi-megabyte JSON string and its UTF-8 copy.
  Future<Uint8List> buildProfileExportBytesInBackground({
    required List<Subscription> subscriptions,
    required String clientVersion,
    required EtonifyProfileEncryption encryption,
    String? password,
  }) async {
    final transferable = await Isolate.run(() {
      final content = const EtonifyBackupService().buildProfileExport(
        subscriptions: subscriptions,
        clientVersion: clientVersion,
        encryption: encryption,
        password: password,
      );
      return TransferableTypedData.fromList([utf8.encode(content)]);
    }, debugName: 'etonify-profile-export-bytes');
    return transferable.materialize().asUint8List();
  }

  /// Reads the encryption marker from the bounded envelope header.
  ///
  /// This lets the UI ask for a password before starting the expensive full
  /// JSON decode instead of decoding a large encrypted backup twice.
  EtonifyProfileEncryption? detectProfileEncryption(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxImportBytes) return null;
    final head = utf8.decode(
      bytes.take(4096).toList(growable: false),
      allowMalformed: true,
    );
    final match = RegExp(
      r'"encryption"\s*:\s*"(encrypted|plain)"',
    ).firstMatch(head);
    return switch (match?.group(1)) {
      'encrypted' => EtonifyProfileEncryption.encrypted,
      'plain' => EtonifyProfileEncryption.plain,
      _ => null,
    };
  }

  EtonifyProfileImportResult parseProfileExport({
    required List<int> bytes,
    required String currentClientVersion,
    String? password,
  }) {
    final envelope = _decodeEnvelope(bytes, expectedMagic: profileMagic);
    final encryption = switch (envelope['encryption']?.toString()) {
      'encrypted' => EtonifyProfileEncryption.encrypted,
      'plain' => EtonifyProfileEncryption.plain,
      _ => throw const EtonifyBackupException(
        'Unknown profile encryption mode.',
      ),
    };
    final profile = encryption == EtonifyProfileEncryption.encrypted
        ? _decryptProfile(envelope, password)
        : envelope['profile'];
    if (profile is! Map) {
      throw const EtonifyBackupException('Profile section is missing.');
    }
    final rawSubscriptions = profile['subscriptions'];
    if (rawSubscriptions is! List) {
      throw const EtonifyBackupException('Subscriptions section is missing.');
    }
    final subscriptions = rawSubscriptions
        .map((entry) {
          if (entry is! Map) {
            throw const EtonifyBackupException('Invalid subscription entry.');
          }
          return Subscription.fromMap(Map<String, dynamic>.from(entry));
        })
        .where((subscription) {
          return subscription.id.trim().isNotEmpty ||
              subscription.url.trim().isNotEmpty;
        })
        .toList(growable: false);
    return EtonifyProfileImportResult(
      warning: _compatibility(envelope, currentClientVersion),
      subscriptions: subscriptions,
      encryption: encryption,
    );
  }

  /// Decodes, decrypts and reconstructs profiles away from the UI isolate.
  Future<EtonifyProfileImportResult> parseProfileExportInBackground({
    required List<int> bytes,
    required String currentClientVersion,
    String? password,
  }) {
    final transferable = TransferableTypedData.fromList([
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    ]);
    return Isolate.run(
      () => const EtonifyBackupService().parseProfileExport(
        bytes: transferable.materialize().asUint8List(),
        currentClientVersion: currentClientVersion,
        password: password,
      ),
      debugName: 'etonify-profile-import',
    );
  }

  Map<String, dynamic> _decodeEnvelope(
    List<int> bytes, {
    required String expectedMagic,
  }) {
    if (bytes.isEmpty) {
      throw const EtonifyBackupException('File is empty.');
    }
    if (bytes.length > maxImportBytes) {
      throw const EtonifyBackupException('File is too large.');
    }
    final head = utf8.decode(bytes.take(128).toList(), allowMalformed: true);
    if (head.trimLeft().startsWith('<')) {
      throw const EtonifyBackupException('HTML is not a valid Etonify file.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const EtonifyBackupException('Invalid Etonify file.');
    }
    final envelope = Map<String, dynamic>.from(decoded);
    final allowed = expectedMagic == settingsMagic
        ? const {
            'magic',
            'formatVersion',
            'minClientVersion',
            'createdByVersion',
            'createdAt',
            'settings',
          }
        : const {
            'magic',
            'formatVersion',
            'minClientVersion',
            'createdByVersion',
            'createdAt',
            'encryption',
            'kdf',
            'cipher',
            'payload',
            'profile',
          };
    final unknown = envelope.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw EtonifyBackupException(
        'Unknown top-level section: ${unknown.first}.',
      );
    }
    if (envelope['magic'] != expectedMagic) {
      throw const EtonifyBackupException('This is not an Etonify file.');
    }
    if (envelope['formatVersion'] != formatVersion) {
      throw const EtonifyBackupException('Unsupported Etonify file version.');
    }
    return envelope;
  }

  EtonifyImportWarning _compatibility(
    Map<String, dynamic> envelope,
    String currentClientVersion,
  ) {
    final createdBy = envelope['createdByVersion']?.toString() ?? '';
    final minVersion = envelope['minClientVersion']?.toString() ?? '';
    if (minVersion.isEmpty ||
        _compareVersions(minVersion, minClientVersion) < 0 ||
        _compareVersions(currentClientVersion, minVersion) < 0) {
      return EtonifyImportWarning(
        compatibility: ExportCompatibilityStatus.unsupported,
        createdByVersion: createdBy,
        minClientVersion: minVersion,
      );
    }
    return EtonifyImportWarning(
      compatibility: _compareVersions(createdBy, currentClientVersion) > 0
          ? ExportCompatibilityStatus.newerClient
          : ExportCompatibilityStatus.compatible,
      createdByVersion: createdBy,
      minClientVersion: minVersion,
    );
  }

  Map<String, dynamic> _decryptProfile(
    Map<String, dynamic> envelope,
    String? password,
  ) {
    final normalizedPassword = password?.trim() ?? '';
    if (normalizedPassword.isEmpty) {
      throw const EtonifyBackupException('Password is required.');
    }
    final kdf = envelope['kdf'];
    final cipher = envelope['cipher'];
    if (kdf is! Map || cipher is! Map) {
      throw const EtonifyBackupException('Encryption metadata is missing.');
    }
    try {
      final salt = base64Decode(kdf['salt']?.toString() ?? '');
      final nonce = base64Decode(cipher['nonce']?.toString() ?? '');
      final payload = base64Decode(envelope['payload']?.toString() ?? '');
      final key = _deriveKey(normalizedPassword, Uint8List.fromList(salt));
      final plaintext = _aesGcmDecrypt(
        key: key,
        nonce: Uint8List.fromList(nonce),
        ciphertext: Uint8List.fromList(payload),
      );
      final decoded = jsonDecode(utf8.decode(plaintext));
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      throw const EtonifyBackupException('Wrong password or damaged file.');
    }
    throw const EtonifyBackupException('Invalid encrypted profile.');
  }

  Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _kdfIterations, _keyBytes));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List _aesGcmEncrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List plaintext,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), _tagBits, nonce, Uint8List(0)),
      );
    return cipher.process(plaintext);
  }

  Uint8List _aesGcmDecrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List ciphertext,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), _tagBits, nonce, Uint8List(0)),
      );
    return cipher.process(ciphertext);
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

String _normalizeVersion(String value) {
  final normalized = value.trim().replaceFirst(RegExp(r'^v'), '');
  return normalized.split('+').first;
}

int _compareVersions(String left, String right) {
  final a = _normalizeVersion(left).split('.').map(int.tryParse).toList();
  final b = _normalizeVersion(right).split('.').map(int.tryParse).toList();
  for (var i = 0; i < 3; i++) {
    final av = i < a.length ? a[i] ?? 0 : 0;
    final bv = i < b.length ? b[i] ?? 0 : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}
