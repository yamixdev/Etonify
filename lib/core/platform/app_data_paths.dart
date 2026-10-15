import 'dart:io';
import 'package:flutter/services.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';

/// Windows user data only. Release/update staging must never use these roots.
class AppDataPaths {
  AppDataPaths._(this.userRoot)
    : hiveRoot = _join(userRoot, 'hive'),
      logRoot = _join(userRoot, 'logs'),
      ruleSetRoot = _join(userRoot, 'rule-sets'),
      stagingRoot = _join(userRoot, 'staging');
  static const channel = MethodChannel('etonify/windows_storage');
  static AppDataPaths? _current;
  static AppDataPaths get current =>
      _current ?? (throw StateError('Windows storage is not initialized.'));
  final String userRoot;
  final String hiveRoot;
  final String logRoot;
  final String ruleSetRoot;
  final String stagingRoot;
  static String _join(String root, String child) =>
      '$root${Platform.pathSeparator}$child';

  /// Do not hide unsupported old-location data with an empty installation.
  /// A new-root database is still authenticated by bootstrap after this check.
  Future<void> ensureNoUnmigratedLegacyData(String? legacyHiveRoot) async {
    if (legacyHiveRoot == null || legacyHiveRoot == hiveRoot) return;
    const names = [
      'app_state',
      'app_state_secure_v1',
      'subscriptions',
      'subscription_payloads',
      'subscriptions_secure_v1',
      'subscription_payloads_secure_v1',
    ];
    Future<bool> hasDatabase(String directory) async {
      for (final name in names) {
        final file = File(_join(directory, '$name.hive'));
        if (await file.exists() && await file.length() > 0) return true;
      }
      return false;
    }

    if (!await hasDatabase(hiveRoot) && await hasDatabase(legacyHiveRoot)) {
      throw const LegacyWindowsStorageException();
    }
  }

  static Future<AppDataPaths> resolve(DesktopLaunchContext launch) async {
    final root = launch.dataRoot;
    final absolute = Platform.isWindows
        ? RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(root)
        : root.startsWith('/');
    if (!absolute ||
        root.split(RegExp(r'[\\/]')).any((p) => p == '..' || p == '.')) {
      throw FileSystemException(
        'Expected a final absolute user data root.',
        root,
      );
    }
    // Native validation includes all ancestors, volume availability and reparse
    // attributes, which Dart's link API cannot reliably detect for junctions.
    if (Platform.isWindows) {
      await channel.invokeMethod<void>('validateRoot', {'root': root});
    }
    final paths = AppDataPaths._(Directory(root).absolute.path);
    for (final path in [
      paths.userRoot,
      paths.hiveRoot,
      paths.logRoot,
      paths.ruleSetRoot,
      paths.stagingRoot,
    ]) {
      if (await FileSystemEntity.type(path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw FileSystemException(
          'Linked user storage is not supported.',
          path,
        );
      }
      await Directory(path).create(recursive: true);
      if (Platform.isWindows) {
        await channel.invokeMethod<void>('validateRoot', {'root': path});
        if (path == paths.userRoot) {
          await channel.invokeMethod<void>('configureRootPermissions', {
            'root': path,
            'portable': launch.distribution == DesktopDistribution.portable,
          });
        }
      }
    }
    // Detect read-only/detached media before opening a database. No fallback.
    final probe = File(
      _join(
        paths.stagingRoot,
        '.write-probe-$pid-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await probe.writeAsBytes([0], flush: true);
    await probe.delete();
    _current = paths;
    return paths;
  }
}

class LegacyWindowsStorageException implements Exception {
  const LegacyWindowsStorageException();
  static const message =
      'Etonify found data from an earlier Windows setup. '
      'The original Documents/meow_hive folder was kept unchanged. '
      'Automatic migration is not available; do not delete the original folder.';
  @override
  String toString() => message;
}
