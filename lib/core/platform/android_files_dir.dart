import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Provides access to the Android application files directory.
class AndroidFilesDir {
  AndroidFilesDir._();

  static String? _cachedPath;

  /// Returns the absolute path of the Android application's `filesDir`.
  ///
  /// Caches the path after first retrieval to avoid repetitive lookups.
  /// Requires [ensureInitialized] to have been called on Android, or a mock path
  /// injected via [setMockPathForTesting] or [initialize].
  static String get path {
    final cached = _cachedPath;
    if (cached != null) {
      return cached;
    }
    if (!Platform.isAndroid) {
      throw UnsupportedError('AndroidFilesDir is only supported on Android.');
    }
    throw StateError(
      'AndroidFilesDir has not been initialized. '
      'Call await AndroidFilesDir.ensureInitialized() before accessing path.',
    );
  }

  /// Explicitly sets the cached path.
  static void initialize(String filesDirPath) {
    _cachedPath = filesDirPath;
  }

  /// Resolves and caches the Android application's `filesDir` asynchronously.
  static Future<String> ensureInitialized() async {
    final cached = _cachedPath;
    if (cached != null) {
      return cached;
    }
    if (!Platform.isAndroid) {
      throw UnsupportedError('AndroidFilesDir is only supported on Android.');
    }
    final dir = await getApplicationSupportDirectory();
    _cachedPath = dir.path;
    return dir.path;
  }

  /// Injects or resets a mock path for testing environments where platform
  /// channels are not available.
  @visibleForTesting
  static void setMockPathForTesting(String? mockPath) {
    _cachedPath = mockPath;
  }
}
