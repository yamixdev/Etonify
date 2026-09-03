import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/platform/android_files_dir.dart';

void main() {
  tearDown(() {
    AndroidFilesDir.setMockPathForTesting(null);
  });

  group('AndroidFilesDir', () {
    test('returns mocked path when set', () {
      AndroidFilesDir.setMockPathForTesting('/data/user/0/test.package/files');
      expect(AndroidFilesDir.path, equals('/data/user/0/test.package/files'));
    });

    test('retains cached mock path across multiple calls', () {
      AndroidFilesDir.setMockPathForTesting('/mock/files');
      expect(AndroidFilesDir.path, equals('/mock/files'));
      expect(AndroidFilesDir.path, equals('/mock/files'));
    });

    test('throws UnsupportedError on non-Android platform without mock', () {
      if (!Platform.isAndroid) {
        AndroidFilesDir.setMockPathForTesting(null);
        expect(() => AndroidFilesDir.path, throwsUnsupportedError);
      }
    });
  });
}
