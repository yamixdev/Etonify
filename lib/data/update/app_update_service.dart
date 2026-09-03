import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:meow_client/core/network/vpn_aware_remote_download.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/local/hive_storage_diagnostics.dart';
import 'package:meow_client/data/update/app_update_channel.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';
import 'package:path_provider/path_provider.dart';

enum AppUpdateStatus {
  unknown,
  checking,
  upToDate,
  currentVersionNewer,
  noReleaseAvailable,
  updateAvailable,
  unsupportedAndroid,
  downloading,
  downloaded,
  error,
}

enum AppUpdateVersionRelation { remoteNewer, same, currentNewer }

class AppUpdateAsset {
  const AppUpdateAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    this.digestSha256,
  });

  final String name;
  final String downloadUrl;
  final int sizeBytes;
  final String? digestSha256;

  AppUpdateAsset copyWith({int? sizeBytes, String? digestSha256}) =>
      AppUpdateAsset(
        name: name,
        downloadUrl: downloadUrl,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        digestSha256: digestSha256 ?? this.digestSha256,
      );

  Map<String, Object?> toMap() => {
    'name': name,
    'downloadUrl': downloadUrl,
    'sizeBytes': sizeBytes,
    'digestSha256': digestSha256,
  };

  static AppUpdateAsset? fromMap(Object? value) {
    if (value is! Map) return null;
    final name = value['name']?.toString().trim() ?? '';
    final downloadUrl = value['downloadUrl']?.toString().trim() ?? '';
    if (name.isEmpty || downloadUrl.isEmpty) return null;
    return AppUpdateAsset(
      name: name,
      downloadUrl: downloadUrl,
      sizeBytes: int.tryParse(value['sizeBytes']?.toString() ?? '') ?? 0,
      digestSha256: AppUpdateService.normalizeSha256Digest(
        value['digestSha256'],
      ),
    );
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    this.buildNumber,
    required this.tagName,
    required this.title,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.asset,
    this.minimumAndroidSdk,
    this.packageName,
    this.channel = AppUpdateChannel.stable,
    this.isPrerelease = false,
    this.releaseLabel,
  });

  final String version;
  final int? buildNumber;
  final String tagName;
  final String title;
  final String body;
  final String htmlUrl;
  final DateTime? publishedAt;
  final AppUpdateAsset asset;
  final int? minimumAndroidSdk;
  final String? packageName;
  final AppUpdateChannel channel;
  final bool isPrerelease;
  final String? releaseLabel;

  String get displayVersion {
    final label = releaseLabel?.trim() ?? '';
    return label.isEmpty ? version : label;
  }

  String get technicalVersion =>
      buildNumber == null ? version : '$version+$buildNumber';

  Map<String, Object?> toMap() => {
    'version': version,
    'buildNumber': buildNumber,
    'tagName': tagName,
    'title': title,
    'body': body,
    'htmlUrl': htmlUrl,
    'publishedAtMillis': publishedAt?.millisecondsSinceEpoch,
    'asset': asset.toMap(),
    'minimumAndroidSdk': minimumAndroidSdk,
    'packageName': packageName,
    'channel': channel.name,
    'isPrerelease': isPrerelease,
    'releaseLabel': releaseLabel,
  };

  static AppUpdateInfo? fromMap(Object? value) {
    if (value is! Map) return null;
    final asset = AppUpdateAsset.fromMap(value['asset']);
    if (asset == null) return null;
    final version = value['version']?.toString().trim() ?? '';
    final tagName = value['tagName']?.toString().trim() ?? '';
    if (version.isEmpty || tagName.isEmpty) return null;
    final publishedAtMillis = int.tryParse(
      value['publishedAtMillis']?.toString() ?? '',
    );
    return AppUpdateInfo(
      version: version,
      buildNumber:
          AppUpdateService.parseBuildNumber(value['buildNumber']) ??
          AppUpdateService.extractBuildNumber(
            value['version']?.toString() ?? '',
          ),
      tagName: tagName,
      title: value['title']?.toString().trim() ?? 'v$version',
      body: value['body']?.toString() ?? '',
      htmlUrl: value['htmlUrl']?.toString().trim() ?? '',
      publishedAt: publishedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(publishedAtMillis),
      asset: asset,
      minimumAndroidSdk: AppUpdateService.parsePositiveInt(
        value['minimumAndroidSdk'],
      ),
      packageName: value['packageName']?.toString().trim(),
      channel: switch (value['channel']?.toString()) {
        'beta' => AppUpdateChannel.beta,
        _ => AppUpdateChannel.stable,
      },
      isPrerelease: value['isPrerelease'] == true,
      releaseLabel: value['releaseLabel']?.toString().trim(),
    );
  }
}

class AppUpdateManifest {
  const AppUpdateManifest({
    required this.version,
    required this.buildNumber,
    required this.minimumAndroidSdk,
    required this.packageName,
    required this.assets,
  });

  final String version;
  final int? buildNumber;
  final int? minimumAndroidSdk;
  final String packageName;
  final Map<String, ({int sizeBytes, String? sha256})> assets;

  static AppUpdateManifest? fromJson(Object? value) {
    if (value is! Map) return null;
    final version = AppUpdateService.normalizeVersion(
      value['version']?.toString() ?? '',
    );
    final packageName = value['packageName']?.toString().trim() ?? '';
    final rawAssets = value['assets'];
    if (version.isEmpty || packageName.isEmpty || rawAssets is! Iterable) {
      return null;
    }
    final assets = <String, ({int sizeBytes, String? sha256})>{};
    for (final raw in rawAssets) {
      if (raw is! Map) continue;
      final name = raw['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      assets[name] = (
        sizeBytes: int.tryParse(raw['sizeBytes']?.toString() ?? '') ?? 0,
        sha256: AppUpdateService.normalizeSha256Digest(raw['sha256']),
      );
    }
    return AppUpdateManifest(
      version: version,
      buildNumber: AppUpdateService.parseBuildNumber(value['buildNumber']),
      minimumAndroidSdk: AppUpdateService.parsePositiveInt(value['minSdk']),
      packageName: packageName,
      assets: Map.unmodifiable(assets),
    );
  }
}

class AppUpdateMetadata {
  const AppUpdateMetadata({
    this.lastCheckAtMillis,
    this.lastStatus = AppUpdateStatus.unknown,
    this.lastError,
    this.latestInfo,
    this.downloadedUpdatePath,
    this.channel = AppUpdateChannel.stable,
  });

  final int? lastCheckAtMillis;
  final AppUpdateStatus lastStatus;
  final String? lastError;
  final AppUpdateInfo? latestInfo;
  final String? downloadedUpdatePath;
  final AppUpdateChannel channel;

  DateTime? get lastCheckAt => lastCheckAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastCheckAtMillis!);

  bool get isDue {
    final last = lastCheckAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= AppUpdateService.checkInterval;
  }

  Map<String, Object?> toMap() => {
    'lastCheckAtMillis': lastCheckAtMillis,
    'lastStatus': lastStatus.name,
    'lastError': lastError,
    'latestInfo': latestInfo?.toMap(),
    'downloadedUpdatePath': downloadedUpdatePath,
    'channel': channel.name,
  };

  static AppUpdateMetadata fromMap(Map<dynamic, dynamic> map) {
    final statusName = map['lastStatus']?.toString();
    final status = AppUpdateStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => AppUpdateStatus.unknown,
    );
    return AppUpdateMetadata(
      lastCheckAtMillis: int.tryParse(
        map['lastCheckAtMillis']?.toString() ?? '',
      ),
      lastStatus: status,
      lastError: map['lastError']?.toString(),
      latestInfo: AppUpdateInfo.fromMap(map['latestInfo']),
      downloadedUpdatePath: map['downloadedUpdatePath']?.toString(),
      channel: switch (map['channel']?.toString()) {
        'beta' => AppUpdateChannel.beta,
        _ => AppUpdateChannel.stable,
      },
    );
  }
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.status,
    required this.checkedAt,
    this.info,
    this.error,
    this.fromCache = false,
    this.downloadedFilePath,
  });

  final AppUpdateStatus status;
  final DateTime checkedAt;
  final AppUpdateInfo? info;
  final String? error;
  final bool fromCache;
  final String? downloadedFilePath;
}

class AppUpdateDownloadProgress {
  const AppUpdateDownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.bytesPerSecond,
    required this.done,
    this.filePath,
    this.stage = AppUpdateDownloadStage.downloading,
  });

  final int downloadedBytes;
  final int totalBytes;
  final double bytesPerSecond;
  final bool done;
  final String? filePath;
  final AppUpdateDownloadStage stage;

  double? get fraction =>
      totalBytes <= 0 ? null : (downloadedBytes / totalBytes).clamp(0.0, 1.0);

  int? get etaSeconds {
    if (bytesPerSecond <= 1 || totalBytes <= 0) return null;
    final remaining = totalBytes - downloadedBytes;
    if (remaining <= 0) return 0;
    return (remaining / bytesPerSecond).ceil();
  }
}

enum AppUpdateDownloadStage {
  cleaning,
  retryingWithoutVpn,
  downloading,
  verifying,
  ready,
}

class AppUpdateVerificationResult {
  const AppUpdateVerificationResult({
    required this.ok,
    this.expectedSha256,
    this.actualSha256,
    this.error,
  });

  final bool ok;
  final String? expectedSha256;
  final String? actualSha256;
  final String? error;

  bool get checksumAvailable =>
      expectedSha256 != null && expectedSha256!.isNotEmpty;
}

class AppUpdateCleanupResult {
  const AppUpdateCleanupResult({
    required this.deletedFiles,
    required this.metadataChanged,
    required this.installedAtLeastLatest,
  });

  final int deletedFiles;
  final bool metadataChanged;
  final bool installedAtLeastLatest;

  bool get changed => deletedFiles > 0 || metadataChanged;
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();
  static const checkInterval = Duration(hours: 24);
  static const repositoryOwner = 'yamixdev';
  static const repositoryName = 'Etonify';
  static const _metadataBoxName = 'app_update_state';
  static const _latestReleaseUrl =
      'https://api.github.com/repos/$repositoryOwner/$repositoryName/releases/latest';
  static const _releasesUrl =
      'https://api.github.com/repos/$repositoryOwner/$repositoryName/releases?per_page=100';
  static const _assetTokens = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
  static const _manifestAssetName = 'etonify-update.json';
  static const _maxReleaseMetadataBytes = 1024 * 1024;
  static const _maxUpdateApkBytes = 512 * 1024 * 1024;
  final Map<AppUpdateChannel, Future<AppUpdateCheckResult>> _checksInFlight =
      <AppUpdateChannel, Future<AppUpdateCheckResult>>{};

  Future<Box<dynamic>> _openBox() async {
    await HiveAppSettingsStore.initHive();
    final stopwatch = Stopwatch()..start();
    final box = Hive.isBoxOpen(_metadataBoxName)
        ? Hive.box<dynamic>(_metadataBoxName)
        : await Hive.openBox<dynamic>(_metadataBoxName);
    stopwatch.stop();
    await HiveStorageDiagnostics.logBoxOnce(
      label: _metadataBoxName,
      box: box,
      openElapsed: stopwatch.elapsed,
    );
    return box;
  }

  Future<AppUpdateMetadata> loadMetadata() async {
    final box = await _openBox();
    return AppUpdateMetadata.fromMap(box.toMap());
  }

  Future<void> _saveMetadata(AppUpdateMetadata metadata) async {
    final box = await _openBox();
    await box.putAll(metadata.toMap());
    await box.flush();
  }

  Future<AppUpdateCheckResult> checkForUpdates({
    required String currentVersion,
    int? currentBuildNumber,
    bool manual = false,
    AppUpdateChannel channel = AppUpdateChannel.stable,
  }) {
    final inFlight = _checksInFlight[channel];
    if (inFlight != null) return inFlight;
    final operation = _checkForUpdates(
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
      manual: manual,
      channel: channel,
    );
    _checksInFlight[channel] = operation;
    return operation.whenComplete(() {
      if (identical(_checksInFlight[channel], operation)) {
        _checksInFlight.remove(channel);
      }
    });
  }

  Future<AppUpdateCheckResult> _checkForUpdates({
    required String currentVersion,
    int? currentBuildNumber,
    required bool manual,
    required AppUpdateChannel channel,
  }) async {
    final metadata = await loadMetadata();
    final metadataMatchesChannel = metadata.channel == channel;
    final cachedInfoMissingDigest =
        metadataMatchesChannel &&
        metadata.latestInfo != null &&
        metadata.latestInfo!.asset.digestSha256 == null;
    if (!manual &&
        metadataMatchesChannel &&
        !metadata.isDue &&
        !cachedInfoMissingDigest) {
      final cached = await _cachedCheckResultFor(
        metadata,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        channel: channel,
      );
      if (cached != null) {
        return cached;
      }
    }

    final checkedAt = DateTime.now();
    try {
      final release = await _fetchRelease(channel);
      if (release == null) {
        await _deleteCachedUpdateFiles();
        await _saveMetadata(
          AppUpdateMetadata(
            lastCheckAtMillis: checkedAt.millisecondsSinceEpoch,
            lastStatus: AppUpdateStatus.noReleaseAvailable,
            channel: channel,
          ),
        );
        return AppUpdateCheckResult(
          status: AppUpdateStatus.noReleaseAvailable,
          checkedAt: checkedAt,
        );
      }
      final manifest = await _fetchReleaseManifest(release['assets']);
      var assets = _parseAssets(release['assets']);
      if (manifest != null) {
        assets = assets
            .map((asset) {
              final metadata = manifest.assets[asset.name];
              return metadata == null
                  ? asset
                  : asset.copyWith(
                      sizeBytes: metadata.sizeBytes > 0
                          ? metadata.sizeBytes
                          : asset.sizeBytes,
                      digestSha256: metadata.sha256,
                    );
            })
            .toList(growable: false);
      }
      final supportedAbis = await _supportedAbis();
      final asset = selectAssetForAbis(assets, supportedAbis);
      if (asset == null) {
        throw const FormatException('No compatible APK asset found.');
      }
      final tagName = release['tag_name']?.toString().trim() ?? '';
      final title = release['name']?.toString().trim().isNotEmpty == true
          ? release['name'].toString().trim()
          : '';
      final body = release['body']?.toString() ?? '';
      final version = normalizeVersion(tagName).isNotEmpty
          ? normalizeVersion(tagName)
          : normalizeVersion('$title\n$body\n${asset.name}');
      if (version.isEmpty) {
        throw const FormatException('Release tag does not contain a version.');
      }
      final info = AppUpdateInfo(
        version: manifest?.version ?? version,
        buildNumber:
            manifest?.buildNumber ??
            extractBuildNumber('$tagName\n$title\n$body\n${asset.name}'),
        tagName: tagName,
        title: title.isNotEmpty ? title : 'v$version',
        body: body,
        htmlUrl: release['html_url']?.toString().trim() ?? '',
        publishedAt: DateTime.tryParse(
          release['published_at']?.toString() ?? '',
        ),
        asset: asset,
        minimumAndroidSdk: manifest?.minimumAndroidSdk,
        packageName: manifest?.packageName,
        channel: channel,
        isPrerelease: release['prerelease'] == true,
        releaseLabel: releaseVersionLabel(tagName, fallback: version),
      );
      final versionRelation = compareVersions(
        info.version,
        currentVersion,
        remoteBuildNumber: info.buildNumber,
        currentBuildNumber: currentBuildNumber,
      );
      final deviceSdk = await _androidSdkInt();
      final remoteIsNewer =
          versionRelation == AppUpdateVersionRelation.remoteNewer;
      final unsupportedAndroid =
          remoteIsNewer &&
          info.minimumAndroidSdk != null &&
          deviceSdk != null &&
          deviceSdk < info.minimumAndroidSdk!;
      var status = unsupportedAndroid
          ? AppUpdateStatus.unsupportedAndroid
          : remoteIsNewer
          ? AppUpdateStatus.updateAvailable
          : versionRelation == AppUpdateVersionRelation.currentNewer
          ? AppUpdateStatus.currentVersionNewer
          : AppUpdateStatus.upToDate;
      final downloadedFilePath = status == AppUpdateStatus.updateAvailable
          ? await _validDownloadedPathFor(info, metadata.downloadedUpdatePath)
          : null;
      if (downloadedFilePath != null) {
        status = AppUpdateStatus.downloaded;
      } else if (!remoteIsNewer) {
        await _deleteCachedUpdateFiles();
      }
      await _saveMetadata(
        AppUpdateMetadata(
          lastCheckAtMillis: checkedAt.millisecondsSinceEpoch,
          lastStatus: status,
          latestInfo: info,
          downloadedUpdatePath: downloadedFilePath,
          channel: channel,
        ),
      );
      return AppUpdateCheckResult(
        status: status,
        checkedAt: checkedAt,
        info: info,
        downloadedFilePath: downloadedFilePath,
      );
    } catch (error) {
      final message = error.toString();
      AppLogStore.warning('updates', 'GitHub update check failed: $message');
      final cached = await _cachedCheckResultFor(
        metadata,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        checkedAt: checkedAt,
        error: message,
        channel: channel,
      );
      if (cached != null) {
        return cached;
      }
      await _saveMetadata(
        AppUpdateMetadata(
          lastCheckAtMillis: checkedAt.millisecondsSinceEpoch,
          lastStatus: AppUpdateStatus.error,
          lastError: message,
          latestInfo: metadataMatchesChannel ? metadata.latestInfo : null,
          downloadedUpdatePath: null,
          channel: channel,
        ),
      );
      return AppUpdateCheckResult(
        status: AppUpdateStatus.error,
        checkedAt: checkedAt,
        info: metadataMatchesChannel ? metadata.latestInfo : null,
        error: message,
      );
    }
  }

  Future<AppUpdateCheckResult?> _cachedCheckResultFor(
    AppUpdateMetadata metadata, {
    required String currentVersion,
    int? currentBuildNumber,
    DateTime? checkedAt,
    String? error,
    required AppUpdateChannel channel,
  }) async {
    if (metadata.channel != channel) {
      return null;
    }
    final info = metadata.latestInfo;
    if (info == null) {
      return null;
    }
    final versionRelation = compareVersions(
      info.version,
      currentVersion,
      remoteBuildNumber: info.buildNumber,
      currentBuildNumber: currentBuildNumber,
    );
    if (versionRelation != AppUpdateVersionRelation.remoteNewer) {
      final deleted = await _deleteCachedUpdateFiles();
      final status = versionRelation == AppUpdateVersionRelation.currentNewer
          ? AppUpdateStatus.currentVersionNewer
          : AppUpdateStatus.upToDate;
      await _saveMetadata(
        AppUpdateMetadata(
          lastCheckAtMillis:
              checkedAt?.millisecondsSinceEpoch ?? metadata.lastCheckAtMillis,
          lastStatus: status,
          lastError: error,
          latestInfo: info,
          downloadedUpdatePath: null,
          channel: channel,
        ),
      );
      if (deleted > 0) {
        AppLogStore.info(
          'updates',
          'removed stale cached update files count=$deleted '
              'installed=$currentVersion latest=${info.technicalVersion}',
        );
      }
      return AppUpdateCheckResult(
        status: status,
        checkedAt: checkedAt ?? metadata.lastCheckAt ?? DateTime.now(),
        info: info,
        error: error,
      );
    }

    final deviceSdk = await _androidSdkInt();
    if (info.minimumAndroidSdk != null &&
        deviceSdk != null &&
        deviceSdk < info.minimumAndroidSdk!) {
      await _deleteCachedUpdateFiles();
      return AppUpdateCheckResult(
        status: AppUpdateStatus.unsupportedAndroid,
        checkedAt: checkedAt ?? metadata.lastCheckAt ?? DateTime.now(),
        info: info,
        error: error ?? metadata.lastError,
        fromCache: checkedAt == null,
      );
    }

    final downloadedFilePath = await _validDownloadedPathFor(
      info,
      metadata.downloadedUpdatePath,
    );
    final status = downloadedFilePath != null
        ? AppUpdateStatus.downloaded
        : metadata.lastStatus == AppUpdateStatus.downloaded
        ? AppUpdateStatus.updateAvailable
        : metadata.lastStatus;
    return AppUpdateCheckResult(
      status: status,
      checkedAt: checkedAt ?? metadata.lastCheckAt ?? DateTime.now(),
      info: info,
      error: error ?? metadata.lastError,
      fromCache: checkedAt == null,
      downloadedFilePath: downloadedFilePath,
    );
  }

  Future<AppUpdateCleanupResult> cleanupInstalledUpdateArtifacts({
    required String currentVersion,
    int? currentBuildNumber,
  }) async {
    final metadata = await loadMetadata();
    final info = metadata.latestInfo;
    final installedAtLeastLatest =
        info == null ||
        !isRemoteVersionNewer(
          info.version,
          currentVersion,
          remoteBuildNumber: info.buildNumber,
          currentBuildNumber: currentBuildNumber,
        );
    if (!installedAtLeastLatest) {
      final downloadedFilePath = await _validDownloadedPathFor(
        info,
        metadata.downloadedUpdatePath,
      );
      final deleted = await cleanupOldDownloads(keepPath: downloadedFilePath);
      return AppUpdateCleanupResult(
        deletedFiles: deleted,
        metadataChanged: false,
        installedAtLeastLatest: false,
      );
    }

    final deleted = await _deleteCachedUpdateFiles();
    final nextStatus = info == null
        ? AppUpdateStatus.unknown
        : compareVersions(
                info.version,
                currentVersion,
                remoteBuildNumber: info.buildNumber,
                currentBuildNumber: currentBuildNumber,
              ) ==
              AppUpdateVersionRelation.currentNewer
        ? AppUpdateStatus.currentVersionNewer
        : AppUpdateStatus.upToDate;
    final metadataChanged =
        metadata.lastStatus != nextStatus ||
        metadata.downloadedUpdatePath != null ||
        metadata.lastError != null;
    if (metadataChanged) {
      await _saveMetadata(
        AppUpdateMetadata(
          lastCheckAtMillis: metadata.lastCheckAtMillis,
          lastStatus: nextStatus,
          latestInfo: info,
          channel: metadata.channel,
        ),
      );
    }
    return AppUpdateCleanupResult(
      deletedFiles: deleted,
      metadataChanged: metadataChanged,
      installedAtLeastLatest: true,
    );
  }

  Future<Map<String, dynamic>?> _fetchRelease(AppUpdateChannel channel) async {
    final uri = Uri.parse(
      channel == AppUpdateChannel.stable ? _latestReleaseUrl : _releasesUrl,
    );
    final result = await VpnAwareRemoteDownloader.instance.fetchBytes(
      uri: uri,
      maximumBytes: _maxReleaseMetadataBytes,
      headers: const <String, String>{
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Etonify-Android-Updater',
      },
    );
    final decoded = jsonDecode(
      utf8.decode(result.bytes ?? const <int>[], allowMalformed: false),
    );
    if (channel == AppUpdateChannel.stable) {
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('GitHub response is not an object.');
      }
      return selectReleaseForChannel(decoded, channel);
    }
    if (decoded is! Iterable) {
      throw const FormatException('GitHub response is not a release list.');
    }
    return selectReleaseForChannel(decoded, channel);
  }

  Future<AppUpdateManifest?> _fetchReleaseManifest(Object? rawAssets) async {
    if (rawAssets is! Iterable) return null;
    Map<dynamic, dynamic>? manifestAsset;
    for (final raw in rawAssets) {
      if (raw is Map<dynamic, dynamic> &&
          raw['name']?.toString() == _manifestAssetName) {
        manifestAsset = raw;
        break;
      }
    }
    final url = Uri.tryParse(
      manifestAsset?['browser_download_url']?.toString().trim() ?? '',
    );
    if (url == null || !url.hasScheme) return null;
    try {
      final result = await VpnAwareRemoteDownloader.instance.fetchBytes(
        uri: url,
        maximumBytes: 256 * 1024,
        headers: const <String, String>{
          'Accept': 'application/json',
          'User-Agent': 'Etonify-Android-Updater',
        },
      );
      return AppUpdateManifest.fromJson(
        jsonDecode(utf8.decode(result.bytes ?? const <int>[])),
      );
    } catch (error) {
      AppLogStore.warning('updates', 'Update manifest unavailable: $error');
      return null;
    }
  }

  Future<List<String>> _supportedAbis() async {
    try {
      final info = await SingboxRuntime.instance.getPlatformDeviceInfo();
      final raw = info['supportedAbis'];
      if (raw is Iterable) {
        return raw
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
      }
      final abi = info['abi']?.toString().trim();
      if (abi != null && abi.isNotEmpty) {
        return [abi];
      }
    } catch (_) {}
    return const <String>[];
  }

  Future<int?> _androidSdkInt() async {
    try {
      final info = await SingboxRuntime.instance.getPlatformDeviceInfo();
      return parsePositiveInt(info['sdkInt']);
    } catch (_) {
      return null;
    }
  }

  Future<void> downloadUpdate(
    AppUpdateInfo info, {
    required void Function(AppUpdateDownloadProgress progress) onProgress,
  }) async {
    final directory = await _updatesDirectory();
    final fileName = sanitizeAssetFileName(info.asset.name);
    final target = File('${directory.path}${Platform.pathSeparator}$fileName');
    onProgress(
      const AppUpdateDownloadProgress(
        downloadedBytes: 0,
        totalBytes: 0,
        bytesPerSecond: 0,
        done: false,
        stage: AppUpdateDownloadStage.cleaning,
      ),
    );
    final existingPath = await _validDownloadedPathFor(info, target.path);
    if (existingPath != null) {
      await cleanupOldDownloads(keepPath: existingPath);
      await _saveMetadata(
        AppUpdateMetadata(
          lastCheckAtMillis: DateTime.now().millisecondsSinceEpoch,
          lastStatus: AppUpdateStatus.downloaded,
          latestInfo: info,
          downloadedUpdatePath: existingPath,
          channel: info.channel,
        ),
      );
      onProgress(
        AppUpdateDownloadProgress(
          downloadedBytes: await File(existingPath).length(),
          totalBytes: info.asset.sizeBytes,
          bytesPerSecond: 0,
          done: true,
          filePath: existingPath,
          stage: AppUpdateDownloadStage.ready,
        ),
      );
      return;
    }
    await cleanupOldDownloads(keepPath: target.path);
    final temp = File('${target.path}.part');
    if (target.existsSync()) {
      await target.delete();
    }
    if (temp.existsSync()) {
      await temp.delete();
    }
    final startedAt = DateTime.now();
    var downloaded = 0;
    var totalBytes = info.asset.sizeBytes;
    var lastEmitAt = startedAt;
    try {
      final uri = Uri.parse(info.asset.downloadUrl);
      final result = await VpnAwareRemoteDownloader.instance.downloadToFile(
        uri: uri,
        destinationPath: temp.path,
        maximumBytes: _maxUpdateApkBytes,
        headers: const <String, String>{
          'User-Agent': 'Etonify-Android-Updater',
        },
        onRouteAttempt: (route, isFallback) {
          if (isFallback && route == RemoteDownloadRoute.underlying) {
            onProgress(
              AppUpdateDownloadProgress(
                downloadedBytes: downloaded,
                totalBytes: totalBytes,
                bytesPerSecond: 0,
                done: false,
                stage: AppUpdateDownloadStage.retryingWithoutVpn,
              ),
            );
          }
        },
        onProgress: (completed, total) {
          downloaded = completed;
          if (total > 0) {
            totalBytes = total;
          }
          final now = DateTime.now();
          if (now.difference(lastEmitAt) >= const Duration(milliseconds: 250)) {
            lastEmitAt = now;
            onProgress(
              AppUpdateDownloadProgress(
                downloadedBytes: downloaded,
                totalBytes: totalBytes,
                bytesPerSecond: _speed(downloaded, startedAt, now),
                done: false,
              ),
            );
          }
        },
      );
      downloaded = result.downloadedBytes;
      if (totalBytes <= 0) {
        totalBytes = downloaded;
      }
      if (target.existsSync()) {
        await target.delete();
      }
      await temp.rename(target.path);
      onProgress(
        AppUpdateDownloadProgress(
          downloadedBytes: downloaded,
          totalBytes: totalBytes,
          bytesPerSecond: _speed(downloaded, startedAt, DateTime.now()),
          done: false,
          stage: AppUpdateDownloadStage.verifying,
        ),
      );
      final verification = await verifyDownloadedApk(info, target.path);
      if (!verification.ok) {
        if (target.existsSync()) {
          await target.delete();
        }
        throw FormatException(
          verification.error ?? 'Downloaded APK checksum mismatch.',
        );
      }
      final compatibility = await verifyDownloadedApkCompatibility(
        info,
        target.path,
      );
      if (!compatibility.ok) {
        if (target.existsSync()) await target.delete();
        throw FormatException(
          compatibility.error ?? 'Downloaded APK is incompatible.',
        );
      }
      await _saveMetadata(
        AppUpdateMetadata(
          lastCheckAtMillis: DateTime.now().millisecondsSinceEpoch,
          lastStatus: AppUpdateStatus.downloaded,
          latestInfo: info,
          downloadedUpdatePath: target.path,
          channel: info.channel,
        ),
      );
      onProgress(
        AppUpdateDownloadProgress(
          downloadedBytes: downloaded,
          totalBytes: totalBytes,
          bytesPerSecond: _speed(downloaded, startedAt, DateTime.now()),
          done: true,
          filePath: target.path,
          stage: AppUpdateDownloadStage.ready,
        ),
      );
      await cleanupOldDownloads(keepPath: target.path);
    } finally {
      if (temp.existsSync()) {
        await temp.delete();
      }
    }
  }

  static double _speed(int bytes, DateTime startedAt, DateTime now) {
    final seconds = now.difference(startedAt).inMilliseconds / 1000;
    if (seconds <= 0) return 0;
    return bytes / seconds;
  }

  Future<Directory> _updatesDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}updates');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  Future<int> cleanupOldDownloads({String? keepPath}) {
    return _deleteCachedUpdateFiles(keepPath: keepPath);
  }

  Future<int> _deleteCachedUpdateFiles({String? keepPath}) async {
    final directory = await _updatesDirectory();
    final keep = keepPath?.trim();
    var deleted = 0;
    if (!directory.existsSync()) return deleted;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last.toLowerCase();
      // This directory belongs exclusively to the updater. Do not depend on
      // a release asset naming convention: older or manually renamed assets
      // must not survive forever as stale installer files.
      final matches = name.endsWith('.apk') || name.endsWith('.apk.part');
      if (!matches) continue;
      if (keep != null && entity.path == keep) continue;
      try {
        await entity.delete();
        deleted++;
      } catch (error) {
        AppLogStore.warning(
          'updates',
          'Failed to delete cached update APK: $error',
        );
      }
    }
    return deleted;
  }

  Future<int> deleteCachedInstallers({
    required String currentVersion,
    int? currentBuildNumber,
  }) async {
    final deleted = await _deleteCachedUpdateFiles();
    final metadata = await loadMetadata();
    final info = metadata.latestInfo;
    final relation = info == null
        ? AppUpdateVersionRelation.same
        : compareVersions(
            info.version,
            currentVersion,
            remoteBuildNumber: info.buildNumber,
            currentBuildNumber: currentBuildNumber,
          );
    final status = info == null
        ? AppUpdateStatus.unknown
        : switch (relation) {
            AppUpdateVersionRelation.remoteNewer =>
              AppUpdateStatus.updateAvailable,
            AppUpdateVersionRelation.currentNewer =>
              AppUpdateStatus.currentVersionNewer,
            AppUpdateVersionRelation.same => AppUpdateStatus.upToDate,
          };
    await _saveMetadata(
      AppUpdateMetadata(
        lastCheckAtMillis: metadata.lastCheckAtMillis,
        lastStatus: status,
        lastError: metadata.lastError,
        latestInfo: info,
        channel: metadata.channel,
      ),
    );
    return deleted;
  }

  Future<String?> _validDownloadedPathFor(
    AppUpdateInfo? info,
    String? path,
  ) async {
    if (info == null) return null;
    final normalizedPath = path?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) return null;
    final file = File(normalizedPath);
    if (!file.existsSync()) return null;
    if (!file.path.toLowerCase().endsWith('.apk')) return null;
    final expectedName = sanitizeAssetFileName(info.asset.name).toLowerCase();
    final actualName = file.uri.pathSegments.last.toLowerCase();
    if (actualName != expectedName) return null;
    final length = await file.length();
    if (length <= 0) return null;
    if (info.asset.sizeBytes > 0 && length != info.asset.sizeBytes) {
      return null;
    }
    final verification = await verifyDownloadedApk(info, file.path);
    if (!verification.ok) {
      return null;
    }
    final compatibility = await verifyDownloadedApkCompatibility(
      info,
      file.path,
    );
    if (!compatibility.ok) {
      return null;
    }
    return file.path;
  }

  Future<AppUpdateVerificationResult> verifyDownloadedApk(
    AppUpdateInfo info,
    String path,
  ) async {
    final expected = info.asset.digestSha256;
    if (expected == null || expected.isEmpty) {
      return const AppUpdateVerificationResult(ok: true);
    }
    final file = File(path);
    if (!file.existsSync()) {
      return AppUpdateVerificationResult(
        ok: false,
        expectedSha256: expected,
        error: 'Downloaded APK file is missing.',
      );
    }
    try {
      final actual = await sha256File(file);
      final ok = actual == expected;
      return AppUpdateVerificationResult(
        ok: ok,
        expectedSha256: expected,
        actualSha256: actual,
        error: ok ? null : 'Downloaded APK checksum mismatch.',
      );
    } catch (error) {
      return AppUpdateVerificationResult(
        ok: false,
        expectedSha256: expected,
        error: error.toString(),
      );
    }
  }

  Future<AppUpdateVerificationResult> verifyDownloadedApkCompatibility(
    AppUpdateInfo info,
    String path,
  ) async {
    if (!Platform.isAndroid) {
      return const AppUpdateVerificationResult(ok: true);
    }
    try {
      final archive = await SingboxRuntime.instance.inspectDownloadedApk(path);
      if (archive['valid'] != true) {
        return const AppUpdateVerificationResult(
          ok: false,
          error: 'Android could not read the downloaded APK.',
        );
      }
      final packageName = archive['packageName']?.toString().trim() ?? '';
      final installedPackage =
          archive['installedPackageName']?.toString().trim() ?? '';
      final expectedPackage = info.packageName?.trim().isNotEmpty == true
          ? info.packageName!.trim()
          : installedPackage;
      if (expectedPackage.isNotEmpty && packageName != expectedPackage) {
        return AppUpdateVerificationResult(
          ok: false,
          error: 'Downloaded APK has a different package name: $packageName.',
        );
      }
      final minSdk = parsePositiveInt(archive['minSdk']);
      final deviceSdk = parsePositiveInt(archive['deviceSdk']);
      if (minSdk != null && deviceSdk != null && minSdk > deviceSdk) {
        return AppUpdateVerificationResult(
          ok: false,
          error:
              'This update requires Android SDK $minSdk, device has $deviceSdk.',
        );
      }
      final archiveCertificates = _stringSet(
        archive['signingCertificateSha256'],
      );
      final installedCertificates = _stringSet(
        archive['installedCertificateSha256'],
      );
      if (archiveCertificates.isEmpty ||
          installedCertificates.isEmpty ||
          archiveCertificates.intersection(installedCertificates).isEmpty) {
        return const AppUpdateVerificationResult(
          ok: false,
          error: 'Downloaded APK signature does not match installed Etonify.',
        );
      }
      return const AppUpdateVerificationResult(ok: true);
    } catch (error) {
      return AppUpdateVerificationResult(ok: false, error: error.toString());
    }
  }

  static Set<String> _stringSet(Object? value) {
    if (value is! Iterable) return const <String>{};
    return value
        .map((item) => normalizeSha256Digest(item))
        .whereType<String>()
        .toSet();
  }

  @visibleForTesting
  static Future<String> sha256File(File file) async {
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }

  static List<AppUpdateAsset> _parseAssets(Object? value) {
    if (value is! Iterable) return const <AppUpdateAsset>[];
    final result = <AppUpdateAsset>[];
    for (final item in value) {
      if (item is! Map) continue;
      final name = item['name']?.toString().trim() ?? '';
      final url = item['browser_download_url']?.toString().trim() ?? '';
      if (name.isEmpty || url.isEmpty || !name.toLowerCase().endsWith('.apk')) {
        continue;
      }
      result.add(
        AppUpdateAsset(
          name: name,
          downloadUrl: url,
          sizeBytes: int.tryParse(item['size']?.toString() ?? '') ?? 0,
          digestSha256: normalizeSha256Digest(item['digest']),
        ),
      );
    }
    return result;
  }

  @visibleForTesting
  static AppUpdateAsset? selectAssetForAbis(
    List<AppUpdateAsset> assets,
    List<String> supportedAbis,
  ) {
    final normalizedAbis = supportedAbis
        .map((value) => value.toLowerCase().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final abiPriority = normalizedAbis
        .where(_assetTokens.contains)
        .toList(growable: false);
    for (final abi in abiPriority) {
      final match = assets.firstWhereOrNull(
        (asset) => asset.name.toLowerCase().contains(abi),
      );
      if (match != null) return match;
    }
    return assets.firstWhereOrNull(
      (asset) => asset.name.toLowerCase().contains('universal'),
    );
  }

  static String normalizeVersion(String value) {
    final trimmed = value.trim();
    final match = RegExp(r'v?(\d+(?:\.\d+){1,3})').firstMatch(trimmed);
    return match?.group(1) ?? '';
  }

  @visibleForTesting
  static String releaseVersionLabel(
    String tagName, {
    required String fallback,
  }) {
    final normalizedTag = tagName.trim().replaceFirst(
      RegExp(r'^v(?=\d)', caseSensitive: false),
      '',
    );
    return normalizedTag.isEmpty ? fallback : normalizedTag;
  }

  static bool isPrereleaseVersion(String value) {
    return RegExp(
      r'(?:^|[.\-_])(alpha|beta|rc|preview|pre|dev)(?:[.\-_\d]|$)',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  @visibleForTesting
  static Map<String, dynamic>? selectReleaseForChannel(
    Object? releases,
    AppUpdateChannel channel,
  ) {
    if (releases is Map) {
      final normalized = Map<String, dynamic>.from(releases);
      if (normalized['draft'] == true) return null;
      final prerelease = normalized['prerelease'] == true;
      return prerelease == channel.acceptsPrereleases ? normalized : null;
    }
    if (releases is! Iterable) return null;
    for (final raw in releases) {
      if (raw is! Map || raw['draft'] == true) continue;
      final prerelease = raw['prerelease'] == true;
      if (prerelease != channel.acceptsPrereleases) continue;
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  @visibleForTesting
  static int? extractBuildNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final versionBuild = RegExp(
      r'\b\d+(?:\.\d+){1,3}\+(\d+)\b',
    ).firstMatch(trimmed);
    final fromVersion = parseBuildNumber(versionBuild?.group(1));
    if (fromVersion != null) return fromVersion;
    final buildLabel = RegExp(
      r'\b(?:build|versionCode|version_code)\s*[:=#]?\s*(\d+)\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    return parseBuildNumber(buildLabel?.group(1));
  }

  @visibleForTesting
  static int? parseBuildNumber(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    return parsed == null || parsed <= 0 ? null : parsed;
  }

  @visibleForTesting
  static int? parsePositiveInt(Object? value) {
    final parsed = int.tryParse(value?.toString().trim() ?? '');
    return parsed == null || parsed < 0 ? null : parsed;
  }

  @visibleForTesting
  static String? normalizeSha256Digest(Object? value) {
    final raw = value?.toString().trim().toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'(?:sha256:)?([a-f0-9]{64})').firstMatch(raw);
    return match?.group(1);
  }

  @visibleForTesting
  static bool isRemoteVersionNewer(
    String remoteVersion,
    String currentVersion, {
    int? remoteBuildNumber,
    int? currentBuildNumber,
  }) =>
      compareVersions(
        remoteVersion,
        currentVersion,
        remoteBuildNumber: remoteBuildNumber,
        currentBuildNumber: currentBuildNumber,
      ) ==
      AppUpdateVersionRelation.remoteNewer;

  @visibleForTesting
  static AppUpdateVersionRelation compareVersions(
    String remoteVersion,
    String currentVersion, {
    int? remoteBuildNumber,
    int? currentBuildNumber,
  }) {
    final remote = _versionParts(normalizeVersion(remoteVersion));
    final current = _versionParts(normalizeVersion(currentVersion));
    for (var i = 0; i < max(remote.length, current.length); i++) {
      final r = i < remote.length ? remote[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (r > c) return AppUpdateVersionRelation.remoteNewer;
      if (r < c) return AppUpdateVersionRelation.currentNewer;
    }
    final remoteBuild =
        parseBuildNumber(remoteBuildNumber) ??
        extractBuildNumber(remoteVersion);
    final currentBuild =
        parseBuildNumber(currentBuildNumber) ??
        extractBuildNumber(currentVersion);
    if (remoteBuild != null && currentBuild != null) {
      if (remoteBuild > currentBuild) {
        return AppUpdateVersionRelation.remoteNewer;
      }
      if (remoteBuild < currentBuild) {
        return AppUpdateVersionRelation.currentNewer;
      }
    }
    return AppUpdateVersionRelation.same;
  }

  static List<int> _versionParts(String version) => version
      .split('.')
      .map((value) => int.tryParse(value) ?? 0)
      .toList(growable: false);

  @visibleForTesting
  static String sanitizeAssetFileName(String name) {
    final sanitized = name
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    if (sanitized.isEmpty || !sanitized.toLowerCase().endsWith('.apk')) {
      return 'etonify-update.apk';
    }
    return sanitized;
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T value) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}
