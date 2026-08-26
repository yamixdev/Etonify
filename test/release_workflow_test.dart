import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android release workflow uses updater-compatible tags and APK names',
    () {
      final workflow = File(
        '.github/workflows/android-release.yml',
      ).readAsStringSync();

      expect(workflow, contains(r'raw="${raw#v}"'));
      expect(workflow, contains(r'TAG_NAME=${raw}'));
      expect(workflow, contains(r'RELEASE_TITLE=v${raw}'));
      expect(workflow, contains(r'etonify-v${RELEASE_VERSION}-universal.apk'));
      expect(workflow, contains(r'etonify-v${RELEASE_VERSION}-arm64-v8a.apk'));
      expect(
        workflow,
        contains(r'etonify-v${RELEASE_VERSION}-armeabi-v7a.apk'),
      );
      expect(workflow, contains('--target-platform android-arm,android-arm64'));
      expect(workflow, isNot(contains('x86')));
      expect(workflow, contains('--draft'));
      expect(workflow, contains('uses: actions/checkout@v7.0.1'));
      expect(workflow, contains('uses: actions/setup-java@v5.6.0'));
      expect(workflow, contains('python3 scripts/verify_libbox.py'));
      expect(workflow, isNot(contains('uses: actions/checkout@v4')));
      expect(workflow, isNot(contains('uses: actions/setup-java@v4')));
    },
  );

  test('Android beta workflow publishes only ARM and ARM-universal APKs', () {
    final workflow = File(
      '.github/workflows/android-beta-apk.yml',
    ).readAsStringSync();

    expect(workflow, contains('--target-platform android-arm,android-arm64'));
    expect(workflow, contains('internal-debug-signed-universal.apk'));
    expect(workflow, contains('internal-debug-signed-arm64-v8a.apk'));
    expect(workflow, contains('internal-debug-signed-armeabi-v7a.apk'));
    expect(workflow, isNot(contains('x86')));
  });
}
