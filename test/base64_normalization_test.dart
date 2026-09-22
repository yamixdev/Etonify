import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/base64.dart';

void main() {
  group('toStandardBase64', () {
    test('rewrites the URL-safe alphabet without touching length', () {
      expect(toStandardBase64('-_A'), equals('+/A='));
      expect(toStandardBase64('-_' * 8), equals('+/' * 8));
    });

    test('restores the padding a strict decoder requires', () {
      expect(toStandardBase64('Zm9v'), equals('Zm9v'));
      expect(toStandardBase64('Zm9vYm'), equals('Zm9vYm=='));
      expect(toStandardBase64('Zm9vYmFy'), equals('Zm9vYmFy'));
    });

    test('leaves empty and one remainder alone', () {
      expect(toStandardBase64(''), isEmpty);
      expect(toStandardBase64('A'), equals('A'));
    });

    test('makes an unpadded URL-safe payload decodable', () {
      final original = 'ss://example:8443?type=none#настройка';
      final urlSafeUnpadded = base64
          .encode(utf8.encode(original))
          .replaceAll('+', '-')
          .replaceAll('/', '_')
          .replaceAll('=', '');

      expect(
        utf8.decode(base64Decode(toStandardBase64(urlSafeUnpadded))),
        equals(original),
      );
    });
  });
}
