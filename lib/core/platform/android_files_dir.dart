import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart';

/// Provides access to the Android application files directory via JNI synchronously.
class AndroidFilesDir {
  AndroidFilesDir._();

  static String? _cachedPath;

  /// Returns the absolute path of the Android application's `filesDir`.
  ///
  /// Caches the path after first retrieval to avoid repetitive JNI method lookups
  /// and local reference allocations.
  static String get path {
    final cached = _cachedPath;
    if (cached != null) {
      return cached;
    }
    if (!Platform.isAndroid) {
      throw UnsupportedError('AndroidFilesDir is only supported on Android.');
    }

    final context = androidApplicationContext;
    final contextClass = context.jClass;
    final getFilesDir = contextClass.instanceMethodId(
      'getFilesDir',
      '()Ljava/io/File;',
    );
    final filesDir = getFilesDir.call(context, JObject.type, []);
    final fileClass = filesDir.jClass;
    final getAbsolutePath = fileClass.instanceMethodId(
      'getAbsolutePath',
      '()Ljava/lang/String;',
    );
    final resolvedPath = getAbsolutePath
        .call(filesDir, JString.type, [])
        .toDartString(releaseOriginal: true);

    fileClass.release();
    filesDir.release();
    contextClass.release();
    context.release();

    _cachedPath = resolvedPath;
    return resolvedPath;
  }

  /// Injects or resets a mock path for testing environments where Android JNI
  /// is not available.
  @visibleForTesting
  static void setMockPathForTesting(String? mockPath) {
    _cachedPath = mockPath;
  }
}
