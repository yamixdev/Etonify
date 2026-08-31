import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release workflow uses updater-compatible tags and APK names', () {
    final workflow = File(
      '.github/workflows/android-release.yml',
    ).readAsStringSync();

    expect(workflow, contains(r'raw="${raw#v}"'));
    expect(workflow, contains(r'TAG_NAME=${raw}'));
    expect(workflow, contains(r'RELEASE_TITLE=v${raw}'));
    expect(workflow, contains(r'etonify-v${RELEASE_VERSION}-universal.apk'));
    expect(workflow, contains(r'etonify-v${RELEASE_VERSION}-arm64-v8a.apk'));
    expect(workflow, contains(r'etonify-v${RELEASE_VERSION}-armeabi-v7a.apk'));
    expect(workflow, contains('--target-platform android-arm,android-arm64'));
    expect(workflow, isNot(contains('x86')));
    expect(workflow, contains('--draft'));
    expect(
      workflow,
      contains(
        'uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1',
      ),
    );
    expect(
      workflow,
      contains(
        'uses: actions/setup-java@dd06d9cba3e5552c54d9f8ea23572deb30010f7c # v6.0.0',
      ),
    );
    expect(workflow, contains('python3 scripts/verify_libbox.py'));
    expect(workflow, isNot(contains('uses: actions/checkout@v4')));
    expect(workflow, isNot(contains('uses: actions/setup-java@v4')));
  });

  test('Flutter workflows use the release SDK version', () {
    for (final path in const [
      '.github/workflows/ci.yml',
      '.github/workflows/codeql.yml',
      '.github/workflows/android-release.yml',
    ]) {
      final workflow = File(path).readAsStringSync();
      expect(workflow, contains('FLUTTER_VERSION: "3.47.2"'), reason: path);
      expect(workflow, isNot(contains('3.47.0')), reason: path);
    }
  });

  test('Debug-signed beta release workflow is removed', () {
    expect(
      File('.github/workflows/android-beta-apk.yml').existsSync(),
      isFalse,
    );
  });
}
