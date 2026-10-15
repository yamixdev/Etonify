import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import 'package:pointycastle/export.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'package:meow_client/platform/windows/windows_storage_key.dart';

/// AES-256-GCM encryption for Hive frames.
///
/// Hive's built-in cipher uses CBC and does not authenticate ciphertext. This
/// implementation stores a fresh 96-bit nonce followed by ciphertext and a
/// 128-bit authentication tag for every encrypted value.
class HiveAesGcmCipher implements HiveCipher {
  HiveAesGcmCipher(List<int> key)
    : _key = Uint8List.fromList(key),
      _keyCrc = _calculateKeyCrc(key) {
    if (key.length != 32 || key.any((byte) => byte < 0 || byte > 255)) {
      throw ArgumentError('The AES-256-GCM key must contain exactly 32 bytes.');
    }
  }

  static const _nonceBytes = 12;
  static const _tagBits = 128;
  static const _tagBytes = _tagBits ~/ 8;
  static final Random _random = Random.secure();

  final Uint8List _key;
  final int _keyCrc;

  static int _calculateKeyCrc(List<int> key) {
    final digest = sha256.convert(key).bytes;
    return ByteData.sublistView(Uint8List.fromList(digest)).getUint32(0);
  }

  @override
  int calculateKeyCrc() => _keyCrc;

  @override
  int maxEncryptedSize(Uint8List inp) => inp.length + _nonceBytes + _tagBytes;

  @override
  int encrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    final nonce = Uint8List.fromList(
      List<int>.generate(_nonceBytes, (_) => _random.nextInt(256)),
    );
    final plaintext = Uint8List.sublistView(inp, inpOff, inpOff + inpLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(_key), _tagBits, nonce, Uint8List(0)),
      );
    final ciphertext = cipher.process(plaintext);
    out.setRange(outOff, outOff + _nonceBytes, nonce);
    out.setRange(
      outOff + _nonceBytes,
      outOff + _nonceBytes + ciphertext.length,
      ciphertext,
    );
    return _nonceBytes + ciphertext.length;
  }

  @override
  int decrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    if (inpLength < _nonceBytes + _tagBytes) {
      throw StateError('Encrypted Hive frame is too short.');
    }
    final nonce = Uint8List.sublistView(inp, inpOff, inpOff + _nonceBytes);
    final ciphertext = Uint8List.sublistView(
      inp,
      inpOff + _nonceBytes,
      inpOff + inpLength,
    );
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(_key), _tagBits, nonce, Uint8List(0)),
      );
    final plaintext = cipher.process(ciphertext);
    out.setRange(outOff, outOff + plaintext.length, plaintext);
    return plaintext.length;
  }
}

class SecureHiveStorage {
  SecureHiveStorage._();

  static const _channel = MethodChannel('meow_client/secure_storage');
  static HiveCipher? _cipher;
  static bool _initialized = false;
  static Future<void>? _initialization;
  static String? _windowsKeyFingerprint;

  static HiveCipher? get cipher => _cipher;

  /// Windows bootstrap must complete before any Hive box is opened.
  static Future<void> initWindows(
    AppDataPaths paths, {
    required bool portable,
  }) async {
    final inFlight = _initialization;
    if (inFlight != null) return inFlight;
    final operation = () async {
      final key = await WindowsStorageKey.loadOrCreate(
        paths,
        portable: portable,
      );
      final fingerprint = sha256.convert(key).toString();
      if (_initialized) {
        if (_windowsKeyFingerprint != fingerprint) {
          throw StateError(
            'Storage key changed during this process. Restart after restoring the complete folder.',
          );
        }
        return;
      }
      _cipher = HiveAesGcmCipher(key);
      _windowsKeyFingerprint = fingerprint;
      _initialized = true;
    }();
    _initialization = operation;
    try {
      await operation;
    } finally {
      if (identical(_initialization, operation)) _initialization = null;
    }
  }

  /// Android must never silently fall back to plaintext. Windows is prepared
  /// explicitly by bootstrap; other platforms retain their existing behavior.
  static Future<void> init() async {
    if (_initialized) return;
    final inFlight = _initialization;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final initialization = () async {
      if (Platform.isAndroid) {
        final encoded = await _channel.invokeMethod<String>(
          'getOrCreateHiveDataKey',
        );
        if (encoded == null) {
          throw StateError('Android Keystore returned no Hive data key.');
        }
        final key = base64Decode(encoded);
        _cipher = HiveAesGcmCipher(key);
      } else if (Platform.isWindows) {
        throw StateError('Windows encrypted storage bootstrap is required.');
      }
      _initialized = true;
    }();
    _initialization = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
    }
  }
}
