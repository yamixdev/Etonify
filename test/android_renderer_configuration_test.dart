import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android deployment enables Impeller', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final enabledImpellerMetadata = RegExp(
      r'''<meta-data(?=[^>]*android:name="io\.flutter\.embedding\.android\.EnableImpeller")(?=[^>]*android:value="true")[^>]*/>''',
      multiLine: true,
    );

    expect(manifest, matches(enabledImpellerMetadata));
  });
}
