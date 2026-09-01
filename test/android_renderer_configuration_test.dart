import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android deployment keeps Impeller disabled to use Skia', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final disabledImpellerMetadata = RegExp(
      r'''<meta-data(?=[^>]*android:name="io\.flutter\.embedding\.android\.EnableImpeller")(?=[^>]*android:value="false")[^>]*/>''',
      multiLine: true,
    );

    expect(manifest, matches(disabledImpellerMetadata));
  });
}
