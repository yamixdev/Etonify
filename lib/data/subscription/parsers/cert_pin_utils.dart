import 'dart:convert';

/// Normalizes raw certificate PIN values into canonical Base64 encoded SHA-256 hashes.
///
/// Supports:
/// - Hex strings with colons: `"28:6A:02:8E:..."`
/// - Hex strings with hyphens or spaces: `"28-6A-02..."` or `"28 6A 02..."`
/// - Plain hex strings: `"286a028e..."` (64 hex characters)
/// - Base64 strings: 32 decoded bytes (padded or unpadded)
/// - Comma-separated or newline-separated values
/// - Lists of the above
List<String> normalizeCertPins(dynamic raw) {
  if (raw == null) return const [];
  final List<String> inputs = [];
  if (raw is List) {
    for (final item in raw) {
      if (item != null) inputs.add(item.toString());
    }
  } else if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.contains(',')) {
      inputs.addAll(
        trimmed.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    } else if (trimmed.contains('\n')) {
      inputs.addAll(
        trimmed.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    } else {
      inputs.add(trimmed);
    }
  } else {
    inputs.add(raw.toString().trim());
  }

  final List<String> results = [];
  for (final input in inputs) {
    final normalized = normalizeSingleCertPin(input);
    if (normalized != null && !results.contains(normalized)) {
      results.add(normalized);
    }
  }
  return results;
}

/// Normalizes a single certificate pin string to Base64 SHA-256.
String? normalizeSingleCertPin(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;

  // Remove common separators in hex fingerprints (colons, spaces, hyphens)
  final cleaned = s.replaceAll(':', '').replaceAll(' ', '').replaceAll('-', '');

  // 1. If it's a 64-character hex string (32 bytes)
  if (cleaned.length == 64 && _isHex(cleaned)) {
    try {
      final bytes = _hexDecode(cleaned);
      if (bytes.length == 32) {
        return base64.encode(bytes);
      }
    } catch (_) {}
  }

  // 2. If it's Base64
  try {
    var b64Str = s;
    final mod = b64Str.length % 4;
    if (mod != 0) {
      b64Str += '=' * (4 - mod);
    }
    final bytes = base64.decode(b64Str);
    if (bytes.length == 32) {
      return base64.encode(bytes);
    }
  } catch (_) {}

  // 3. Fallback: try hex decoding cleaned even if length was somehow different (must still be 32 bytes)
  if (_isHex(cleaned)) {
    try {
      final bytes = _hexDecode(cleaned);
      if (bytes.length == 32) {
        return base64.encode(bytes);
      }
    } catch (_) {}
  }

  return null;
}

bool _isHex(String s) {
  if (s.isEmpty || s.length.isOdd) return false;
  for (var i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    final isDigit = code >= 0x30 && code <= 0x39; // 0-9
    final isLower = code >= 0x61 && code <= 0x66; // a-f
    final isUpper = code >= 0x41 && code <= 0x46; // A-F
    if (!isDigit && !isLower && !isUpper) return false;
  }
  return true;
}

List<int> _hexDecode(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}
