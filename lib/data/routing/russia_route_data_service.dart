import 'dart:convert';
import 'dart:io';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:meow_client/core/network/vpn_aware_remote_download.dart';
import 'package:meow_client/core/platform/android_files_dir.dart';

final RegExp _domainListWhitespaceRegExp = RegExp(r'\s');
final RegExp _validDomainRegExp = RegExp(r'^[a-z0-9.\-_]+$');
final RegExp _compiledGenerationPattern = RegExp(
  r'^domain-list-compiled-v\d+-\d+$',
);
final RegExp _compiledDirectoryPattern = RegExp(
  r'^domain-list-compiled-[a-zA-Z0-9-]+$',
);
final RegExp _runetGenerationPattern = RegExp(r'^runetfreedom-\d+$');

bool _sameStoragePath(String first, String second) => Platform.isWindows
    ? first.replaceAll('\\', '/').toLowerCase() ==
          second.replaceAll('\\', '/').toLowerCase()
    : first == second;

@visibleForTesting
bool shouldRebuildRussiaRouteDomainLists({
  required bool currentDataAvailable,
  required bool downloadedContentChanged,
  required bool compiledFilesAvailable,
}) {
  return !currentDataAvailable ||
      downloadedContentChanged ||
      !compiledFilesAvailable;
}

@visibleForTesting
String? normalizeRussiaRouteDomainForTest(String value) =>
    _normalizeDomainValue(value);

@visibleForTesting
Future<Map<String, Uint8List>> extractRussiaRouteArchiveForTest(
  Uint8List bytes,
) async => (await _prepareRoutePackageArchiveInBackground(bytes)).files;

DateTime? parseRussiaRouteVersionTimestamp(String value) {
  final match = RegExp(r'\d{12}').firstMatch(value.trim());
  if (match == null) return null;
  final digits = match.group(0)!;
  final year = int.parse(digits.substring(0, 4));
  final month = int.parse(digits.substring(4, 6));
  final day = int.parse(digits.substring(6, 8));
  final hour = int.parse(digits.substring(8, 10));
  final minute = int.parse(digits.substring(10, 12));
  final parsed = DateTime(year, month, day, hour, minute);
  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day ||
      parsed.hour != hour ||
      parsed.minute != minute) {
    return null;
  }
  return parsed;
}

enum RussiaRouteBundle { runetFreedom, curatedDirect, ai, social }

class RussiaRouteBundleStatus {
  const RussiaRouteBundleStatus({
    required this.available,
    this.updatedAtMillis,
    this.lastUpdateCheckAtMillis,
    this.updateFailed = false,
    this.revision,
  });

  final bool available;
  final int? updatedAtMillis;
  final int? lastUpdateCheckAtMillis;
  final bool updateFailed;
  final String? revision;

  DateTime? get updatedAt => _timestamp(updatedAtMillis);
  DateTime? get lastUpdateCheckAt => _timestamp(lastUpdateCheckAtMillis);

  bool get needsDailyUpdate {
    final lastCheck = lastUpdateCheckAt;
    return !available ||
        lastCheck == null ||
        DateTime.now().difference(lastCheck) >= const Duration(hours: 24);
  }
}

DateTime? _timestamp(int? millis) => millis == null || millis <= 0
    ? null
    : DateTime.fromMillisecondsSinceEpoch(millis);

class RussiaRouteDataStatus {
  const RussiaRouteDataStatus({
    required this.available,
    required this.sourceName,
    required this.versionTag,
    this.sourceKind = RussiaRouteDataService.sourceKindBundled,
    this.releaseTag,
    this.packageSha256,
    this.assetSizeBytes,
    this.verifiedAtMillis,
    this.verifiedFiles = const <String>[],
    this.geositeRuBlockedPath,
    this.geositeRuAvailableOnlyInsidePath,
    this.geositeCategoryRuPath,
    this.geoipRuBlockedPath,
    this.geoipRuWhitelistPath,
    this.geoipRuPath,
    this.curatedDirectServicesPath,
    this.aiServicesPath,
    this.socialServicesPath,
    this.installedAtMillis,
    this.lastUpdateCheckAtMillis,
    this.domainListCommunityUpdatedAtMillis,
    this.domainListCommunityCategoryCount = 0,
    this.domainListCommunityDomainCount = 0,
    this.domainListCommunityCompilerVersion = 0,
    this.domainListCommunityCompiledDirectory,
    this.domainListCommunityMetadata =
        const <String, RussiaRouteCategoryMetadata>{},
    this.bundles = const {},
  });

  const RussiaRouteDataStatus.unavailable()
    : available = false,
      sourceName = RussiaRouteDataService.sourceName,
      versionTag = RussiaRouteDataService.bundledTag,
      sourceKind = RussiaRouteDataService.sourceKindBundled,
      releaseTag = null,
      packageSha256 = null,
      assetSizeBytes = null,
      verifiedAtMillis = null,
      verifiedFiles = const <String>[],
      geositeRuBlockedPath = null,
      geositeRuAvailableOnlyInsidePath = null,
      geositeCategoryRuPath = null,
      geoipRuBlockedPath = null,
      geoipRuWhitelistPath = null,
      geoipRuPath = null,
      curatedDirectServicesPath = null,
      aiServicesPath = null,
      socialServicesPath = null,
      installedAtMillis = null,
      lastUpdateCheckAtMillis = null,
      domainListCommunityUpdatedAtMillis = null,
      domainListCommunityCategoryCount = 0,
      domainListCommunityDomainCount = 0,
      domainListCommunityCompilerVersion = 0,
      domainListCommunityCompiledDirectory = null,
      domainListCommunityMetadata =
          const <String, RussiaRouteCategoryMetadata>{},
      bundles = const {};

  final bool available;
  final String sourceName;
  final String versionTag;
  final String sourceKind;
  final String? releaseTag;
  final String? packageSha256;
  final int? assetSizeBytes;
  final int? verifiedAtMillis;
  final List<String> verifiedFiles;
  final String? geositeRuBlockedPath;
  final String? geositeRuAvailableOnlyInsidePath;
  final String? geositeCategoryRuPath;
  final String? geoipRuBlockedPath;
  final String? geoipRuWhitelistPath;
  final String? geoipRuPath;
  final String? curatedDirectServicesPath;
  final String? aiServicesPath;
  final String? socialServicesPath;
  final int? installedAtMillis;
  final int? lastUpdateCheckAtMillis;
  final int? domainListCommunityUpdatedAtMillis;
  final int domainListCommunityCategoryCount;
  final int domainListCommunityDomainCount;
  final int domainListCommunityCompilerVersion;
  final String? domainListCommunityCompiledDirectory;
  final Map<String, RussiaRouteCategoryMetadata> domainListCommunityMetadata;
  final Map<RussiaRouteBundle, RussiaRouteBundleStatus> bundles;

  RussiaRouteBundleStatus bundleStatus(RussiaRouteBundle bundle) =>
      bundles[bundle] ??
      RussiaRouteBundleStatus(
        available: switch (bundle) {
          RussiaRouteBundle.runetFreedom => available,
          RussiaRouteBundle.curatedDirect => curatedDirectServicesPath != null,
          RussiaRouteBundle.ai => aiServicesPath != null,
          RussiaRouteBundle.social => socialServicesPath != null,
        },
        updatedAtMillis: bundle == RussiaRouteBundle.runetFreedom
            ? installedAtMillis
            : domainListCommunityUpdatedAtMillis,
        lastUpdateCheckAtMillis: bundle == RussiaRouteBundle.runetFreedom
            ? lastUpdateCheckAtMillis
            : null,
        revision: switch (bundle) {
          RussiaRouteBundle.runetFreedom =>
            geositeRuBlockedPath ?? packageSha256,
          RussiaRouteBundle.curatedDirect => curatedDirectServicesPath,
          RussiaRouteBundle.ai => aiServicesPath,
          RussiaRouteBundle.social => socialServicesPath,
        },
      );

  DateTime? get installedAt => installedAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(installedAtMillis!);

  DateTime? get verifiedAt => verifiedAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(verifiedAtMillis!);

  DateTime? get domainListCommunityUpdatedAt =>
      domainListCommunityUpdatedAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          domainListCommunityUpdatedAtMillis!,
        );

  DateTime? get lastUpdateCheckAt => lastUpdateCheckAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastUpdateCheckAtMillis!);

  bool get needsDailyUpdate =>
      bundleStatus(RussiaRouteBundle.runetFreedom).needsDailyUpdate;
}

class RussiaRouteDataFile {
  const RussiaRouteDataFile({required this.name, required this.sizeBytes});

  final String name;
  final int sizeBytes;

  bool get isGeoIp => name.startsWith('geoip-');
}

class RussiaRouteCategoryMetadata {
  const RussiaRouteCategoryMetadata({
    this.etag,
    this.lastModified,
    this.updatedAtMillis,
  });

  final String? etag;
  final String? lastModified;
  final int? updatedAtMillis;

  Map<String, Object?> toJson() => {
    if (etag != null && etag!.isNotEmpty) 'etag': etag,
    if (lastModified != null && lastModified!.isNotEmpty)
      'lastModified': lastModified,
    if (updatedAtMillis != null) 'updatedAtMillis': updatedAtMillis,
  };

  static RussiaRouteCategoryMetadata fromJson(Object? value) {
    if (value is! Map) {
      return const RussiaRouteCategoryMetadata();
    }
    return RussiaRouteCategoryMetadata(
      etag: value['etag']?.toString(),
      lastModified: value['lastModified']?.toString(),
      updatedAtMillis: int.tryParse(value['updatedAtMillis']?.toString() ?? ''),
    );
  }
}

class RussiaRouteUpdateCheck {
  const RussiaRouteUpdateCheck({
    required this.status,
    required this.latestTag,
    required this.updateAvailable,
  });

  final RussiaRouteDataStatus status;
  final String latestTag;
  final bool updateAvailable;
}

enum RussiaRouteUpdateStage {
  checking,
  retryingWithoutVpn,
  downloadingPackage,
  verifyingPackage,
  extractingPackage,
  downloadingCategories,
  compiling,
  activating,
  complete,
}

class RussiaRouteUpdateProgress {
  const RussiaRouteUpdateProgress({
    required this.stage,
    this.completedBytes = 0,
    this.totalBytes = 0,
    this.completedItems = 0,
    this.totalItems = 0,
    this.isRetryingWithoutVpn = false,
  });

  final RussiaRouteUpdateStage stage;
  final int completedBytes;
  final int totalBytes;
  final int completedItems;
  final int totalItems;
  final bool isRetryingWithoutVpn;

  double? get fraction {
    if (totalBytes > 0) {
      return (completedBytes / totalBytes).clamp(0, 1).toDouble();
    }
    if (totalItems > 0) {
      return (completedItems / totalItems).clamp(0, 1).toDouble();
    }
    return null;
  }

  RussiaRouteUpdateProgress copyWith({
    RussiaRouteUpdateStage? stage,
    int? completedBytes,
    int? totalBytes,
    int? completedItems,
    int? totalItems,
    bool? isRetryingWithoutVpn,
  }) {
    return RussiaRouteUpdateProgress(
      stage: stage ?? this.stage,
      completedBytes: completedBytes ?? this.completedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      completedItems: completedItems ?? this.completedItems,
      totalItems: totalItems ?? this.totalItems,
      isRetryingWithoutVpn: isRetryingWithoutVpn ?? this.isRetryingWithoutVpn,
    );
  }
}

abstract interface class RussiaRouteUpdateActivity {
  bool get isUpdating;
  ValueListenable<RussiaRouteUpdateProgress?> get progress;
}

class RussiaRouteDataService implements RussiaRouteUpdateActivity {
  RussiaRouteDataService._();

  static final RussiaRouteDataService instance = RussiaRouteDataService._();

  static const sourceName = 'runetfreedom + domain-list-community';
  static const sourceRepositoryUrl =
      'https://github.com/runetfreedom/russia-v2ray-rules-dat';
  static const sourceKindLive = 'live';
  static const sourceKindBundled = 'bundled';
  static const bundledTag = 'bundled-202608291020';
  static const livePackageName = 'runetfreedom sing-box.zip';
  static const _latestReleaseUrl =
      'https://api.github.com/repos/runetfreedom/russia-v2ray-rules-dat/releases/latest';
  static const _maxSingboxZipBytes = 80 * 1024 * 1024;
  static const domainListCommunitySourceName = 'v2fly/domain-list-community';
  static const _domainListCommunityRawBaseUrl =
      'https://raw.githubusercontent.com/v2fly/domain-list-community/master/data';
  static const _maxDomainListCategoryBytes = 2 * 1024 * 1024;
  static const _domainListCommunityCompilerVersion = 2;
  static const allBundles = {
    RussiaRouteBundle.runetFreedom,
    RussiaRouteBundle.curatedDirect,
    RussiaRouteBundle.ai,
    RussiaRouteBundle.social,
  };
  static const _domainListFileNames = <RussiaRouteBundle, String>{
    RussiaRouteBundle.curatedDirect: 'ru-direct-services.srs',
    RussiaRouteBundle.ai: 'ai-services.srs',
    RussiaRouteBundle.social: 'social-services.srs',
  };

  static const _assetGeositeRuBlocked =
      'assets/route_data/russia/geosite-ru-blocked.srs';
  static const _assetGeositeRuAvailableOnlyInside =
      'assets/route_data/russia/geosite-ru-available-only-inside.srs';
  static const _assetGeositeCategoryRu =
      'assets/route_data/russia/geosite-category-ru.srs';
  static const _assetGeoipRuBlocked =
      'assets/route_data/russia/geoip-ru-blocked.srs';
  static const _assetGeoipRuWhitelist =
      'assets/route_data/russia/geoip-ru-whitelist.srs';
  static const _assetGeoipRu = 'assets/route_data/russia/geoip-ru.srs';
  static const _releaseZipEntries = <String, String>{
    'rule-set-geosite/geosite-ru-blocked.srs': 'geositeRuBlocked',
    'rule-set-geosite/geosite-ru-available-only-inside.srs':
        'geositeRuAvailableOnlyInside',
    'rule-set-geosite/geosite-category-ru.srs': 'geositeCategoryRu',
    'rule-set-geoip/geoip-ru-blocked.srs': 'geoipRuBlocked',
    'rule-set-geoip/geoip-ru-whitelist.srs': 'geoipRuWhitelist',
    'rule-set-geoip/geoip-ru.srs': 'geoipRu',
  };
  static const _curatedDirectServicesCategories = <String>[
    'category-gov-ru',
    'vk',
    'yandex',
    'sber',
    'mailru-group',
    'tbank-ru',
    'avito',
    'ozon',
    'wildberries',
    'x5',
    'rutube',
  ];
  static const _aiServicesCategories = <String>['category-ai-!cn'];
  static const _additionalSocialCategory = 'category-social-media-!cn';
  static const _socialServicesCategories = <String>[
    _additionalSocialCategory,
    'discord',
    'github',
    'google',
    'meta',
    'openai',
    'spotify',
    'telegram',
    'tiktok',
    'vk',
    'whatsapp',
  ];

  Future<RussiaRouteDataStatus>? _updateInFlight;
  Set<RussiaRouteBundle> _updatingBundles = const {};
  bool _isForcedUpdate = false;
  bool _isBundledOnly = false;
  Future<RussiaRouteDataStatus>? _domainListMigrationInFlight;
  Future<void>? _cleanupInFlight;
  int _metadataWrites = 0;

  Future<void>? get generationCleanupInFlight => _cleanupInFlight;

  Future<void> waitForGenerationCleanup() async {
    while (_cleanupInFlight != null) {
      await _cleanupInFlight;
    }
  }

  @override
  final ValueNotifier<RussiaRouteUpdateProgress?> progress = ValueNotifier(
    null,
  );

  @override
  bool get isUpdating => _updateInFlight != null;

  void _emitProgress(
    RussiaRouteUpdateStage stage, {
    int completedBytes = 0,
    int totalBytes = 0,
    int completedItems = 0,
    int totalItems = 0,
    bool? isRetryingWithoutVpn,
  }) {
    final isDownloading =
        stage == RussiaRouteUpdateStage.downloadingPackage ||
        stage == RussiaRouteUpdateStage.downloadingCategories ||
        stage == RussiaRouteUpdateStage.checking;
    final retrying =
        isRetryingWithoutVpn ??
        (isDownloading
            ? (progress.value?.isRetryingWithoutVpn ?? false)
            : false);

    progress.value = RussiaRouteUpdateProgress(
      stage: stage,
      completedBytes: completedBytes,
      totalBytes: totalBytes,
      completedItems: completedItems,
      totalItems: totalItems,
      isRetryingWithoutVpn: retrying,
    );
  }

  Future<RussiaRouteDataStatus> loadStatus() async {
    await waitForGenerationCleanup();
    final current = await _loadStatus();
    final pending = _domainListMigrationInFlight;
    if (pending != null) return pending;
    if (current.domainListCommunityCategoryCount == 0 ||
        current.domainListCommunityCompilerVersion >=
            _domainListCommunityCompilerVersion ||
        _updateInFlight != null) {
      return current;
    }
    final future = _migrateCachedDomainLists(current);
    _domainListMigrationInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_domainListMigrationInFlight, future)) {
        _domainListMigrationInFlight = null;
      }
    }
  }

  Future<Map<String, dynamic>> _readMetadata(
    _RussiaRouteStoragePaths paths,
  ) async {
    final file = File(paths.metadataPath);
    try {
      String contents;
      try {
        contents = await file.readAsString();
      } on FileSystemException {
        contents = await File('${file.path}.bak').readAsString();
      }
      final metadata = jsonDecode(contents);
      return metadata is Map<String, dynamic> ? metadata : {};
    } on FileSystemException {
      return {};
    } on FormatException {
      return {};
    }
  }

  static Map<String, dynamic> _bundleMetadata(
    Map<String, dynamic> metadata,
    RussiaRouteBundle bundle,
  ) {
    final bundles = metadata['bundles'];
    final value = bundles is Map ? bundles[bundle.name] : null;
    return value is Map<String, dynamic> ? value : {};
  }

  static void _setBundleMetadata(
    Map<String, dynamic> metadata,
    RussiaRouteBundle bundle,
    Map<String, dynamic> value,
  ) {
    final bundles = metadata['bundles'];
    metadata['bundles'] = {
      if (bundles is Map<String, dynamic>) ...bundles,
      bundle.name: value,
    };
  }

  static int? _metadataTimestamp(Map<String, dynamic> metadata, String field) =>
      int.tryParse(metadata[field]?.toString() ?? '');

  String? _compiledPath(
    _RussiaRouteStoragePaths paths,
    Map<String, dynamic> metadata,
    RussiaRouteBundle bundle,
  ) {
    final bundleMetadata = _bundleMetadata(metadata, bundle);
    final directory = bundleMetadata.containsKey('directory')
        ? bundleMetadata['directory']
        : metadata['domainListCommunityCompiledDirectory'];
    if (directory != null &&
        (directory is! String ||
            !_compiledDirectoryPattern.hasMatch(directory))) {
      return null;
    }
    final base = directory == null
        ? '${paths.baseDirectoryPath}/rule-set-geosite'
        : '${paths.baseDirectoryPath}/$directory';
    final file = File('$base/${_domainListFileNames[bundle]}');
    return _hasUsableRuleSet(file) ? file.path : null;
  }

  Future<RussiaRouteDataStatus> _loadStatus() async {
    final paths = await _storagePaths();
    final metadata = await _readMetadata(paths);
    if (metadata.isEmpty) return const RussiaRouteDataStatus.unavailable();

    final runet = _bundleMetadata(metadata, RussiaRouteBundle.runetFreedom);
    final runetDirectory = runet['directory'];
    final validRunetDirectory =
        runetDirectory == null ||
        runetDirectory is String &&
            _runetGenerationPattern.hasMatch(runetDirectory);
    final runetBase = runetDirectory == null
        ? paths.baseDirectoryPath
        : '${paths.baseDirectoryPath}/$runetDirectory';
    final runetFiles = {
      for (final entry in _releaseZipEntries.entries)
        entry.value: File('$runetBase/${entry.key}'),
    };
    final runetAvailable =
        validRunetDirectory && runetFiles.values.every(_hasUsableRuleSet);
    final compiled = {
      for (final bundle in _domainListFileNames.keys)
        bundle: _compiledPath(paths, metadata, bundle),
    };
    final checkedAt = _metadataTimestamp(metadata, 'lastUpdateCheckAtMillis');
    final domainListsUpdatedAt = _metadataTimestamp(
      metadata,
      'domainListCommunityUpdatedAtMillis',
    );
    final installedAt = _metadataTimestamp(metadata, 'installedAtMillis');
    final packageSha256 = metadata['packageSha256']?.toString();
    final statuses = <RussiaRouteBundle, RussiaRouteBundleStatus>{
      RussiaRouteBundle.runetFreedom: RussiaRouteBundleStatus(
        available: runetAvailable,
        updatedAtMillis: runetAvailable
            ? _metadataTimestamp(runet, 'updatedAtMillis') ?? installedAt
            : null,
        lastUpdateCheckAtMillis: checkedAt,
        updateFailed: runet['updateFailed'] == true,
        revision: runetAvailable ? runetFiles['geositeRuBlocked']?.path : null,
      ),
      for (final entry in compiled.entries)
        entry.key: _compiledBundleStatus(
          _bundleMetadata(metadata, entry.key),
          path: entry.value,
          legacyUpdatedAt: domainListsUpdatedAt,
          legacyCheckedAt: checkedAt,
        ),
    };
    String? runetPath(String key) =>
        runetAvailable ? runetFiles[key]!.path : null;

    return RussiaRouteDataStatus(
      available: runetAvailable,
      sourceName: metadata['sourceName']?.toString() ?? sourceName,
      versionTag: metadata['versionTag']?.toString() ?? bundledTag,
      sourceKind: metadata['sourceKind']?.toString() ?? sourceKindBundled,
      releaseTag: metadata['releaseTag']?.toString(),
      packageSha256: packageSha256,
      assetSizeBytes: _metadataTimestamp(metadata, 'assetSizeBytes'),
      verifiedAtMillis: _metadataTimestamp(metadata, 'verifiedAtMillis'),
      verifiedFiles: _stringListFromJson(metadata['verifiedFiles']),
      geositeRuBlockedPath: runetPath('geositeRuBlocked'),
      geositeRuAvailableOnlyInsidePath: runetPath(
        'geositeRuAvailableOnlyInside',
      ),
      geositeCategoryRuPath: runetPath('geositeCategoryRu'),
      geoipRuBlockedPath: runetPath('geoipRuBlocked'),
      geoipRuWhitelistPath: runetPath('geoipRuWhitelist'),
      geoipRuPath: runetPath('geoipRu'),
      curatedDirectServicesPath: compiled[RussiaRouteBundle.curatedDirect],
      aiServicesPath: compiled[RussiaRouteBundle.ai],
      socialServicesPath: compiled[RussiaRouteBundle.social],
      installedAtMillis: installedAt,
      lastUpdateCheckAtMillis: checkedAt,
      domainListCommunityUpdatedAtMillis: domainListsUpdatedAt,
      domainListCommunityCategoryCount:
          _metadataTimestamp(metadata, 'domainListCommunityCategoryCount') ?? 0,
      domainListCommunityDomainCount:
          _metadataTimestamp(metadata, 'domainListCommunityDomainCount') ?? 0,
      domainListCommunityCompilerVersion:
          _metadataTimestamp(metadata, 'domainListCommunityCompilerVersion') ??
          0,
      domainListCommunityCompiledDirectory:
          metadata['domainListCommunityCompiledDirectory']?.toString(),
      domainListCommunityMetadata: _categoryMetadataFromJson(
        metadata['domainListCommunityMetadata'],
      ),
      bundles: Map.unmodifiable(statuses),
    );
  }

  RussiaRouteBundleStatus _compiledBundleStatus(
    Map<String, dynamic> metadata, {
    required String? path,
    required int? legacyUpdatedAt,
    required int? legacyCheckedAt,
  }) {
    return RussiaRouteBundleStatus(
      available: path != null,
      updatedAtMillis: path == null
          ? null
          : _metadataTimestamp(metadata, 'updatedAtMillis') ?? legacyUpdatedAt,
      lastUpdateCheckAtMillis:
          _metadataTimestamp(metadata, 'lastUpdateCheckAtMillis') ??
          (metadata.isEmpty && path != null ? legacyCheckedAt : null),
      updateFailed: metadata['updateFailed'] == true,
      revision: path == null ? null : metadata['revision']?.toString() ?? path,
    );
  }

  Future<RussiaRouteDataStatus> _migrateCachedDomainLists(
    RussiaRouteDataStatus current,
  ) async {
    try {
      final paths = await _storagePaths();
      final metadata = await _readMetadata(paths);
      final categoryFiles = await compute(
        _readCachedDomainListCommunityCategories,
        paths.domainListCommunitySourceDirectoryPath,
        debugLabel: 'route-cached-sources-read',
      );
      final artifacts = await compute(
        _compileDomainListCommunityArtifacts,
        categoryFiles,
        debugLabel: 'route-services-compile',
      );
      final directory = _newCompiledDirectory();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in _domainListFileNames.entries) {
        final artifact = artifacts[entry.value]!;
        if (artifact.domainCount == 0) return current;
        await _writeAtomically(
          '${paths.baseDirectoryPath}/$directory/${entry.value}',
          artifact.ruleSetBytes,
        );
        _recordCompiledBundle(
          metadata,
          entry.key,
          directory: directory,
          now: now,
          checkedRemotely: false,
          useExistingFile: false,
          domainCount: artifact.domainCount,
        );
      }
      metadata['domainListCommunityCategoryCount'] = categoryFiles.length;
      await _writeMetadata(paths, metadata);
      return await _loadStatus();
    } catch (_) {
      return current;
    }
  }

  String _newCompiledDirectory() =>
      'domain-list-compiled-v$_domainListCommunityCompilerVersion-'
      '${DateTime.now().microsecondsSinceEpoch}';

  void _recordCompiledBundle(
    Map<String, dynamic> metadata,
    RussiaRouteBundle bundle, {
    required String? directory,
    required int now,
    bool checkedRemotely = true,
    required bool useExistingFile,
    required int domainCount,
    String? sourceRevision,
  }) {
    // Capture old shared or flat paths before moving a single group's pointer.
    for (final item in _domainListFileNames.keys) {
      final previous = _bundleMetadata(metadata, item);
      if (!previous.containsKey('directory')) {
        _setBundleMetadata(metadata, item, {
          ...previous,
          'directory': metadata['domainListCommunityCompiledDirectory'],
          'updatedAtMillis': metadata['domainListCommunityUpdatedAtMillis'],
          'lastUpdateCheckAtMillis': metadata['lastUpdateCheckAtMillis'],
        });
      }
    }
    final previous = _bundleMetadata(metadata, bundle);
    final previousDirectory = previous['directory'];
    _setBundleMetadata(metadata, bundle, {
      ...previous,
      'directory': directory,
      'previousDirectory': directory == previousDirectory
          ? previous['previousDirectory']
          : previousDirectory,
      if (!useExistingFile) 'updatedAtMillis': now,
      if (checkedRemotely) 'lastUpdateCheckAtMillis': now,
      if (checkedRemotely) 'updateFailed': false,
      'compilerVersion': _domainListCommunityCompilerVersion,
      'domainCount': domainCount,
      'sourceRevision': ?sourceRevision,
    });
    if (!useExistingFile) {
      final oldActive = metadata['domainListCommunityCompiledDirectory'];
      if (directory != oldActive && oldActive is String) {
        metadata['domainListCommunityPreviousCompiledDirectory'] = oldActive;
      }
      metadata['domainListCommunityCompiledDirectory'] = directory;
      metadata['domainListCommunityUpdatedAtMillis'] = now;
    }
    metadata['domainListCommunityCompilerVersion'] =
        _domainListCommunityCompilerVersion;
    metadata['domainListCommunityDomainCount'] = _domainListFileNames.keys.fold(
      0,
      (total, item) =>
          total +
          (_metadataTimestamp(_bundleMetadata(metadata, item), 'domainCount') ??
              0),
    );
  }

  Future<void> cleanupSupersededDomainLists({
    required Iterable<String> protectedRuleSetPaths,
  }) {
    final pending = _cleanupInFlight;
    if (pending != null) return pending;
    if (_updateInFlight != null ||
        _domainListMigrationInFlight != null ||
        _metadataWrites > 0) {
      return Future.value();
    }
    final future = _cleanupSupersededDomainLists(protectedRuleSetPaths.toSet());
    _cleanupInFlight = future;
    return future.whenComplete(() {
      if (identical(_cleanupInFlight, future)) _cleanupInFlight = null;
    });
  }

  Future<void> _cleanupSupersededDomainLists(
    Set<String> protectedRuleSetPaths,
  ) async {
    try {
      final paths = await _storagePaths();
      final base = Directory(paths.baseDirectoryPath).absolute;
      if (await FileSystemEntity.type(base.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        return;
      }
      final canonicalBase = await base.resolveSymbolicLinks();
      if (!_sameStoragePath(canonicalBase, base.path)) return;
      final metadataFile = File(paths.metadataPath);
      if (await FileSystemEntity.type(metadataFile.path, followLinks: false) !=
          FileSystemEntityType.file) {
        return;
      }
      final metadata = jsonDecode(await metadataFile.readAsString());
      if (metadata is! Map<String, dynamic>) return;
      final protected = <String>{};
      bool protect(Object? name, RegExp pattern) {
        if (name == null) return true;
        if (name is! String || !pattern.hasMatch(name)) return false;
        protected.add(name);
        return true;
      }

      if (!protect(
            metadata['domainListCommunityCompiledDirectory'],
            _compiledGenerationPattern,
          ) ||
          !protect(
            metadata['domainListCommunityPreviousCompiledDirectory'],
            _compiledGenerationPattern,
          )) {
        return;
      }
      for (final bundle in RussiaRouteBundle.values) {
        final info = _bundleMetadata(metadata, bundle);
        final pattern = bundle == RussiaRouteBundle.runetFreedom
            ? _runetGenerationPattern
            : _compiledGenerationPattern;
        if (!protect(info['directory'], pattern) ||
            !protect(info['previousDirectory'], pattern)) {
          return;
        }
      }
      if (protected.isEmpty) return;
      for (final path in protectedRuleSetPaths) {
        final parent = Directory(
          await File(path).absolute.parent.resolveSymbolicLinks(),
        );
        final generation = _sameStoragePath(parent.parent.path, base.path)
            ? parent
            : parent.parent;
        if (_sameStoragePath(generation.parent.path, base.path)) {
          protected.add(
            generation.uri.pathSegments.where((s) => s.isNotEmpty).last,
          );
        }
      }
      await for (final directory in base.list(followLinks: false)) {
        if (directory is! Directory) continue;
        final name = directory.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if ((!_compiledGenerationPattern.hasMatch(name) &&
                !_runetGenerationPattern.hasMatch(name)) ||
            protected.contains(name)) {
          continue;
        }
        if (!_sameStoragePath(directory.absolute.parent.path, base.path) ||
            await FileSystemEntity.type(directory.path, followLinks: false) !=
                FileSystemEntityType.directory ||
            !_sameStoragePath(
              await directory.resolveSymbolicLinks(),
              directory.absolute.path,
            )) {
          continue;
        }
        var containsLink = false;
        await for (final entry in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entry is Link) {
            containsLink = true;
            break;
          }
        }
        if (!containsLink) await directory.delete(recursive: true);
      }
    } on FileSystemException {
      return;
    } on FormatException {
      return;
    }
  }

  Future<List<RussiaRouteDataFile>> listInstalledFiles() async {
    final status = await loadStatus();
    final candidates = {
      'geosite-ru-blocked.srs': status.geositeRuBlockedPath,
      'geosite-ru-available-only-inside.srs':
          status.geositeRuAvailableOnlyInsidePath,
      'geosite-category-ru.srs': status.geositeCategoryRuPath,
      'geoip-ru-blocked.srs': status.geoipRuBlockedPath,
      'geoip-ru-whitelist.srs': status.geoipRuWhitelistPath,
      'geoip-ru.srs': status.geoipRuPath,
      'ru-direct-services.srs': status.curatedDirectServicesPath,
      'ai-services.srs': status.aiServicesPath,
      'social-services.srs': status.socialServicesPath,
    };
    final installed = <RussiaRouteDataFile>[];
    for (final entry in candidates.entries) {
      final path = entry.value;
      if (path == null) continue;
      try {
        final stat = await File(path).stat();
        if (stat.type == FileSystemEntityType.file && stat.size > 4) {
          installed.add(
            RussiaRouteDataFile(name: entry.key, sizeBytes: stat.size),
          );
        }
      } on FileSystemException {
        // The file can disappear between checking status and reading its size.
      }
    }
    return installed;
  }

  bool _hasUsableRuleSet(File file) {
    RandomAccessFile? reader;
    try {
      if (!file.existsSync() || file.lengthSync() <= 4) {
        return false;
      }
      reader = file.openSync();
      final magic = reader.readSync(_srsMagicBytes.length);
      return magic.length == _srsMagicBytes.length &&
          magic[0] == _srsMagicBytes[0] &&
          magic[1] == _srsMagicBytes[1] &&
          magic[2] == _srsMagicBytes[2];
    } on FileSystemException {
      return false;
    } finally {
      reader?.closeSync();
    }
  }

  Future<RussiaRouteDataStatus> ensureBundledInstalled() => _runUpdate(
    bundles: const {RussiaRouteBundle.runetFreedom},
    force: false,
    bundledOnly: true,
    update: () async {
      _emitProgress(RussiaRouteUpdateStage.checking);
      final current = await _loadStatus();
      if (current.available) {
        _emitProgress(RussiaRouteUpdateStage.complete);
        return current;
      }
      final paths = await _storagePaths();
      final metadata = await _readMetadata(paths);
      await _installBundledFallback(paths, metadata);
      final result = await _loadStatus();
      _emitProgress(RussiaRouteUpdateStage.complete);
      return result;
    },
  );

  Future<void> _installBundledFallback(
    _RussiaRouteStoragePaths paths,
    Map<String, dynamic> metadata,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final package = await _installBundledRoutePackage(
      paths,
      checkedAtMillis: now,
    );
    final next = Map<String, dynamic>.from(metadata);
    _setBundleMetadata(next, RussiaRouteBundle.runetFreedom, {
      'updatedAtMillis': now,
    });
    _recordRunetPackage(next, package, installedAt: now, checkedAt: 0);
    _emitProgress(RussiaRouteUpdateStage.activating);
    await _writeMetadata(paths, next);
    metadata.addAll(next);
  }

  Future<RussiaRouteDataStatus> deleteInstalled() => _runUpdate(
    bundles: const {},
    force: true,
    bundledOnly: true,
    update: () async {
      final paths = await _storagePaths();
      final base = Directory(paths.baseDirectoryPath);
      if (base.existsSync()) await base.delete(recursive: true);
      return const RussiaRouteDataStatus.unavailable();
    },
  );

  Future<RussiaRouteUpdateCheck> checkForUpdate() async {
    final latest = await _fetchLatestRunetFreedomRelease();
    var updateAvailable = true;
    final status = await _runUpdate(
      bundles: const {},
      force: false,
      bundledOnly: true,
      update: () async {
        final current = await _loadStatus();
        updateAvailable =
            !current.available ||
            current.sourceKind != sourceKindLive ||
            current.releaseTag != latest.tagName;
        if (updateAvailable) return current;
        final paths = await _storagePaths();
        final metadata = await _readMetadata(paths);
        metadata['lastUpdateCheckAtMillis'] =
            DateTime.now().millisecondsSinceEpoch;
        _setBundleMetadata(metadata, RussiaRouteBundle.runetFreedom, {
          ..._bundleMetadata(metadata, RussiaRouteBundle.runetFreedom),
          'updateFailed': false,
        });
        await _writeMetadata(paths, metadata);
        return _loadStatus();
      },
    );
    return RussiaRouteUpdateCheck(
      status: status,
      latestTag: latest.tagName,
      updateAvailable: updateAvailable,
    );
  }

  Future<RussiaRouteDataStatus> ensureUpdated({
    bool force = false,
    Set<RussiaRouteBundle> bundles = allBundles,
  }) {
    final requested = Set<RussiaRouteBundle>.unmodifiable(bundles);
    return _runUpdate(
      bundles: requested,
      force: force,
      bundledOnly: false,
      update: () => _ensureUpdated(force: force, bundles: requested),
    );
  }

  Future<RussiaRouteDataStatus> _runUpdate({
    required Set<RussiaRouteBundle> bundles,
    required bool force,
    required bool bundledOnly,
    required Future<RussiaRouteDataStatus> Function() update,
  }) async {
    while (true) {
      while (_cleanupInFlight != null) {
        await _cleanupInFlight;
      }
      final migration = _domainListMigrationInFlight;
      if (migration != null) {
        await migration;
        continue;
      }
      final pending = _updateInFlight;
      if (pending != null) {
        if (bundles.isNotEmpty &&
            _updatingBundles.containsAll(bundles) &&
            (bundledOnly || !_isBundledOnly) &&
            (!force || _isForcedUpdate)) {
          return pending;
        }
        try {
          await pending;
        } catch (_) {
          // The requested operation gets its own attempt.
        }
        continue;
      }
      // Schedule after registering the operation so progress listeners see it.
      final future = Future<RussiaRouteDataStatus>.microtask(update);
      _updateInFlight = future;
      _updatingBundles = bundles;
      _isForcedUpdate = force;
      _isBundledOnly = bundledOnly;
      try {
        return await future;
      } finally {
        _updateInFlight = null;
        _updatingBundles = const {};
        progress.value = null;
      }
    }
  }

  Future<RussiaRouteDataStatus> _ensureUpdated({
    required bool force,
    required Set<RussiaRouteBundle> bundles,
  }) async {
    _emitProgress(RussiaRouteUpdateStage.checking);
    var status = await _loadStatus();
    final needsCompilerMigration =
        status.domainListCommunityCategoryCount > 0 &&
        status.domainListCommunityCompilerVersion <
            _domainListCommunityCompilerVersion;
    if (!force &&
        needsCompilerMigration &&
        bundles.any(_domainListFileNames.containsKey)) {
      status = await _migrateCachedDomainLists(status);
    }

    final paths = await _storagePaths();
    final metadata = await _readMetadata(paths);
    final compiledDirectory = _newCompiledDirectory();
    final downloadedCategories = <String, _DownloadedCategory>{};

    for (final bundle in RussiaRouteBundle.values) {
      if (!bundles.contains(bundle)) continue;
      final bundleStatus = status.bundleStatus(bundle);
      final compilerOutdated =
          _domainListFileNames.containsKey(bundle) &&
          status.domainListCommunityCompilerVersion <
              _domainListCommunityCompilerVersion;
      if (!force && !bundleStatus.needsDailyUpdate && !compilerOutdated) {
        continue;
      }

      final next = Map<String, dynamic>.from(metadata);
      try {
        if (bundle == RussiaRouteBundle.runetFreedom) {
          await _refreshRunetPackage(paths, next, status, force: force);
        } else {
          await _refreshCompiledBundle(
            paths,
            next,
            bundle,
            directory: compiledDirectory,
            force: force,
            downloadedCategories: downloadedCategories,
          );
        }
        _emitProgress(RussiaRouteUpdateStage.activating);
        await _writeMetadata(paths, next);
        metadata.addAll(next);
      } catch (error) {
        debugPrint('Routing rules update failed for ${bundle.name}: $error');
        try {
          if (bundle == RussiaRouteBundle.runetFreedom && !status.available) {
            await _installBundledFallback(paths, metadata);
          }
          _setBundleMetadata(metadata, bundle, {
            ..._bundleMetadata(metadata, bundle),
            'updateFailed': true,
          });
          await _writeMetadata(paths, metadata);
        } catch (fallbackError) {
          debugPrint('Could not save routing update status: $fallbackError');
        }
      }
    }
    final result = await _loadStatus();
    _emitProgress(RussiaRouteUpdateStage.complete);
    return result;
  }

  Future<void> _refreshRunetPackage(
    _RussiaRouteStoragePaths paths,
    Map<String, dynamic> metadata,
    RussiaRouteDataStatus current, {
    required bool force,
  }) async {
    _emitProgress(RussiaRouteUpdateStage.checking, isRetryingWithoutVpn: false);
    final release = await _fetchLatestRunetFreedomRelease();
    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = _bundleMetadata(metadata, RussiaRouteBundle.runetFreedom);
    if (!force &&
        current.available &&
        current.sourceKind == sourceKindLive &&
        current.releaseTag == release.tagName) {
      _setBundleMetadata(metadata, RussiaRouteBundle.runetFreedom, {
        ...previous,
        'updateFailed': false,
      });
      metadata['lastUpdateCheckAtMillis'] = now;
      return;
    }

    final bytes = await _downloadBytes(
      release.assetUrl,
      maxBytes: _maxSingboxZipBytes,
      expectedBytes: release.assetSizeBytes,
      onProgress: (completed, total) => _emitProgress(
        RussiaRouteUpdateStage.downloadingPackage,
        completedBytes: completed,
        totalBytes: total,
      ),
    );
    _emitProgress(RussiaRouteUpdateStage.extractingPackage);
    final prepared = await _prepareRoutePackageArchiveInBackground(bytes);
    _validateRoutePackageFiles(prepared.files);
    final unchanged =
        current.available &&
        await _installedPackageMatches(current, prepared.files);

    if (!unchanged) {
      final directory = 'runetfreedom-${DateTime.now().microsecondsSinceEpoch}';
      await _writeRoutePackage(
        '${paths.baseDirectoryPath}/$directory',
        prepared.files,
      );
      _setBundleMetadata(metadata, RussiaRouteBundle.runetFreedom, {
        'directory': directory,
        'previousDirectory': previous['directory'],
        'updatedAtMillis': now,
        'updateFailed': false,
      });
    } else {
      _setBundleMetadata(metadata, RussiaRouteBundle.runetFreedom, {
        ...previous,
        'updateFailed': false,
      });
    }
    _recordRunetPackage(
      metadata,
      _InstalledRoutePackageInfo(
        sourceKind: sourceKindLive,
        versionTag: release.tagName,
        releaseTag: release.tagName,
        packageSha256: prepared.sha256,
        assetSizeBytes: release.assetSizeBytes ?? bytes.length,
        verifiedAtMillis: now,
        verifiedFiles: prepared.files.keys.toList()..sort(),
      ),
      installedAt: current.available ? current.installedAtMillis ?? now : now,
      checkedAt: now,
    );
  }

  Future<bool> _installedPackageMatches(
    RussiaRouteDataStatus current,
    Map<String, Uint8List> files,
  ) async {
    final installed = {
      'geositeRuBlocked': current.geositeRuBlockedPath,
      'geositeRuAvailableOnlyInside': current.geositeRuAvailableOnlyInsidePath,
      'geositeCategoryRu': current.geositeCategoryRuPath,
      'geoipRuBlocked': current.geoipRuBlockedPath,
      'geoipRuWhitelist': current.geoipRuWhitelistPath,
      'geoipRu': current.geoipRuPath,
    };
    for (final entry in installed.entries) {
      if (entry.value == null ||
          !await _fileMatches(File(entry.value!), files[entry.key]!)) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _fileMatches(File file, List<int> bytes) async {
    try {
      return await file.length() == bytes.length &&
          listEquals(await file.readAsBytes(), bytes);
    } on FileSystemException {
      return false;
    }
  }

  void _recordRunetPackage(
    Map<String, dynamic> metadata,
    _InstalledRoutePackageInfo package, {
    required int installedAt,
    required int checkedAt,
  }) {
    metadata.addAll({
      'sourceName': sourceName,
      'sourceKind': package.sourceKind,
      'versionTag': package.versionTag,
      'releaseTag': package.releaseTag,
      'packageSha256': package.packageSha256,
      'assetSizeBytes': package.assetSizeBytes,
      'verifiedAtMillis': package.verifiedAtMillis,
      'verifiedFiles': package.verifiedFiles,
      'installedAtMillis': installedAt,
      'lastUpdateCheckAtMillis': checkedAt,
    });
  }

  Future<void> _refreshCompiledBundle(
    _RussiaRouteStoragePaths paths,
    Map<String, dynamic> metadata,
    RussiaRouteBundle bundle, {
    required String directory,
    required bool force,
    required Map<String, _DownloadedCategory> downloadedCategories,
  }) async {
    final downloaded = await _downloadDomainListCommunityCategories(
      bundle: bundle,
      sourceDirectoryPath: paths.domainListCommunitySourceDirectoryPath,
      previousMetadata: _categoryMetadataFromJson(
        metadata['domainListCommunityMetadata'],
      ),
      downloadedCategories: downloadedCategories,
      force: force,
    );
    final previous = _bundleMetadata(metadata, bundle);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existingPath = _compiledPath(paths, metadata, bundle);
    final categories = downloaded.categoryFiles;
    final sortedKeys = categories.keys.toList()..sort();
    final sourceRevision = crypto.sha256
        .convert(
          utf8.encode(
            jsonEncode({for (final key in sortedKeys) key: categories[key]}),
          ),
        )
        .toString();
    final currentCompiler =
        metadata['domainListCommunityCompilerVersion'] ==
            _domainListCommunityCompilerVersion &&
        (previous['compilerVersion'] ?? _domainListCommunityCompilerVersion) ==
            _domainListCommunityCompilerVersion;
    final shouldRebuild =
        !currentCompiler ||
        shouldRebuildRussiaRouteDomainLists(
          currentDataAvailable: previous['sourceRevision'] != null,
          downloadedContentChanged:
              previous['sourceRevision'] != sourceRevision,
          compiledFilesAvailable: existingPath != null,
        );
    if (!shouldRebuild) {
      _setBundleMetadata(metadata, bundle, {
        ...previous,
        'lastUpdateCheckAtMillis': now,
        'updateFailed': false,
      });
    } else {
      _emitProgress(RussiaRouteUpdateStage.compiling);
      final artifact = await compute(_compileBundleArtifact, (
        bundle: bundle,
        categories: categories,
      ), debugLabel: 'route-services-compile');
      if (artifact.domainCount == 0) {
        throw FormatException(
          'Routing list ${bundle.name} contains no usable entries',
        );
      }
      final existingDirectory = previous.containsKey('directory')
          ? previous['directory']
          : metadata['domainListCommunityCompiledDirectory'];
      final unchanged =
          existingPath != null &&
          currentCompiler &&
          await _fileMatches(File(existingPath), artifact.ruleSetBytes);
      if (!unchanged) {
        await _writeAtomically(
          '${paths.baseDirectoryPath}/$directory/${_domainListFileNames[bundle]}',
          artifact.ruleSetBytes,
        );
      }
      _recordCompiledBundle(
        metadata,
        bundle,
        directory: unchanged ? existingDirectory as String? : directory,
        now: now,
        useExistingFile: unchanged,
        domainCount: artifact.domainCount,
        sourceRevision: sourceRevision,
      );
    }

    final categoryMetadata = _categoryMetadataFromJson(
      metadata['domainListCommunityMetadata'],
    );
    for (final entry in downloaded.metadata.entries) {
      final cacheFile = _categoryCacheFile(
        paths.domainListCommunitySourceDirectoryPath,
        entry.key,
      );
      final content = utf8.encode(categories[entry.key]!);
      if (!await _fileMatches(cacheFile, content)) {
        await _writeAtomically(cacheFile.path, content);
      }
    }
    final combined = {...categoryMetadata, ...downloaded.metadata};
    metadata['domainListCommunityCategoryCount'] = combined.length;
    metadata['domainListCommunityMetadata'] = {
      for (final entry in combined.entries) entry.key: entry.value.toJson(),
    };
  }

  Future<void> _writeMetadata(
    _RussiaRouteStoragePaths paths,
    Map<String, dynamic> metadata,
  ) async {
    _metadataWrites++;
    try {
      await _writeAtomically(
        paths.metadataPath,
        utf8.encode(jsonEncode(metadata)),
      );
    } finally {
      _metadataWrites--;
    }
  }

  Future<_InstalledRoutePackageInfo> _installBundledRoutePackage(
    _RussiaRouteStoragePaths paths, {
    required int checkedAtMillis,
  }) async {
    final files = <String, Uint8List>{
      'geositeRuBlocked': await _loadBundledAsset(_assetGeositeRuBlocked),
      'geositeRuAvailableOnlyInside': await _loadBundledAsset(
        _assetGeositeRuAvailableOnlyInside,
      ),
      'geositeCategoryRu': await _loadBundledAsset(_assetGeositeCategoryRu),
      'geoipRuBlocked': await _loadBundledAsset(_assetGeoipRuBlocked),
      'geoipRuWhitelist': await _loadBundledAsset(_assetGeoipRuWhitelist),
      'geoipRu': await _loadBundledAsset(_assetGeoipRu),
    };
    await _writeRoutePackage(paths.baseDirectoryPath, files);
    final bundledTimestamp = parseRussiaRouteVersionTimestamp(bundledTag);
    return _InstalledRoutePackageInfo(
      sourceKind: sourceKindBundled,
      versionTag: bundledTag,
      releaseTag: bundledTag,
      verifiedAtMillis:
          bundledTimestamp?.millisecondsSinceEpoch ?? checkedAtMillis,
      verifiedFiles: files.keys.toList()..sort(),
    );
  }

  Future<_RunetFreedomReleaseAsset> _fetchLatestRunetFreedomRelease() async {
    final bytes = await _downloadBytes(
      Uri.parse(_latestReleaseUrl),
      maxBytes: 1024 * 1024,
      accept: 'application/vnd.github+json',
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Invalid runetfreedom release response');
    }
    final tagName = decoded['tag_name']?.toString().trim() ?? '';
    if (tagName.isEmpty) {
      throw const FormatException('runetfreedom release tag is empty');
    }
    final assets = decoded['assets'];
    if (assets is! List) {
      throw const FormatException('runetfreedom release assets are missing');
    }
    for (final asset in assets) {
      if (asset is! Map) {
        continue;
      }
      final name = asset['name']?.toString().trim() ?? '';
      if (name != 'sing-box.zip') {
        continue;
      }
      final url = Uri.tryParse(
        asset['browser_download_url']?.toString().trim() ?? '',
      );
      if (url == null || !url.hasScheme) {
        throw const FormatException('runetfreedom sing-box.zip URL is invalid');
      }
      return _RunetFreedomReleaseAsset(
        tagName: tagName,
        assetUrl: url,
        assetSizeBytes: int.tryParse(asset['size']?.toString() ?? ''),
      );
    }
    throw const FormatException('runetfreedom sing-box.zip asset not found');
  }

  Future<Uint8List> _downloadBytes(
    Uri uri, {
    required int maxBytes,
    String accept = 'application/octet-stream,*/*',
    int? expectedBytes,
    void Function(int completed, int total)? onProgress,
  }) async {
    final result = await VpnAwareRemoteDownloader.instance.fetchBytes(
      uri: uri,
      maximumBytes: maxBytes,
      headers: <String, String>{
        'User-Agent': 'EtonifyRouteData/1',
        'Accept': accept,
      },
      onRouteAttempt: (route, isFallback) {
        if (isFallback && route == RemoteDownloadRoute.underlying) {
          final current = progress.value;
          if (current != null) {
            progress.value = current.copyWith(isRetryingWithoutVpn: true);
          } else {
            _emitProgress(
              RussiaRouteUpdateStage.downloadingPackage,
              isRetryingWithoutVpn: true,
            );
          }
        }
      },
      onProgress: (completed, total) {
        onProgress?.call(completed, total > 0 ? total : expectedBytes ?? 0);
      },
    );
    return result.bytes ?? Uint8List(0);
  }

  static Map<String, Uint8List> _extractRequiredRuleSetsFromZip(
    Uint8List zipBytes,
  ) {
    final extracted = <String, Uint8List>{};
    final view = ByteData.sublistView(zipBytes);
    final eocdOffset = _findZipEndOfCentralDirectory(zipBytes);
    if (eocdOffset < 0) {
      throw const FormatException('Invalid runetfreedom zip: EOCD not found');
    }
    final entryCount = view.getUint16(eocdOffset + 10, Endian.little);
    var offset = view.getUint32(eocdOffset + 16, Endian.little);
    for (var i = 0; i < entryCount; i++) {
      if (offset + 46 > zipBytes.length ||
          view.getUint32(offset, Endian.little) != 0x02014b50) {
        throw const FormatException('Invalid runetfreedom zip central header');
      }
      final flags = view.getUint16(offset + 8, Endian.little);
      final method = view.getUint16(offset + 10, Endian.little);
      final compressedSize = view.getUint32(offset + 20, Endian.little);
      final uncompressedSize = view.getUint32(offset + 24, Endian.little);
      final nameLength = view.getUint16(offset + 28, Endian.little);
      final extraLength = view.getUint16(offset + 30, Endian.little);
      final commentLength = view.getUint16(offset + 32, Endian.little);
      final localHeaderOffset = view.getUint32(offset + 42, Endian.little);
      final nameStart = offset + 46;
      final nameEnd = nameStart + nameLength;
      if (nameEnd > zipBytes.length) {
        throw const FormatException('Invalid runetfreedom zip entry name');
      }
      final entryName = utf8
          .decode(zipBytes.sublist(nameStart, nameEnd), allowMalformed: false)
          .replaceAll('\\', '/');
      final targetKey = _releaseZipEntries[entryName];
      if (targetKey != null) {
        extracted[targetKey] = _readZipEntry(
          zipBytes,
          view,
          localHeaderOffset: localHeaderOffset,
          flags: flags,
          method: method,
          compressedSize: compressedSize,
          uncompressedSize: uncompressedSize,
        );
      }
      offset = nameEnd + extraLength + commentLength;
    }
    final missing = _releaseZipEntries.values
        .where((key) => !extracted.containsKey(key))
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw FormatException(
        'runetfreedom sing-box.zip missing files: ${missing.join(", ")}',
      );
    }
    _validateRoutePackageFiles(extracted);
    return extracted;
  }

  static int _findZipEndOfCentralDirectory(Uint8List bytes) {
    final view = ByteData.sublistView(bytes);
    final minOffset = bytes.length > 0xFFFF + 22
        ? bytes.length - 0xFFFF - 22
        : 0;
    for (var offset = bytes.length - 22; offset >= minOffset; offset--) {
      if (view.getUint32(offset, Endian.little) == 0x06054b50) {
        return offset;
      }
    }
    return -1;
  }

  static Uint8List _readZipEntry(
    Uint8List zipBytes,
    ByteData view, {
    required int localHeaderOffset,
    required int flags,
    required int method,
    required int compressedSize,
    required int uncompressedSize,
  }) {
    if ((flags & 0x1) != 0) {
      throw const FormatException('Encrypted route data zip is unsupported');
    }
    if (localHeaderOffset + 30 > zipBytes.length ||
        view.getUint32(localHeaderOffset, Endian.little) != 0x04034b50) {
      throw const FormatException('Invalid runetfreedom zip local header');
    }
    final localNameLength = view.getUint16(
      localHeaderOffset + 26,
      Endian.little,
    );
    final localExtraLength = view.getUint16(
      localHeaderOffset + 28,
      Endian.little,
    );
    final dataStart =
        localHeaderOffset + 30 + localNameLength + localExtraLength;
    final dataEnd = dataStart + compressedSize;
    if (dataStart < 0 || dataEnd > zipBytes.length) {
      throw const FormatException('Invalid runetfreedom zip entry data');
    }
    final compressed = zipBytes.sublist(dataStart, dataEnd);
    final decoded = switch (method) {
      0 => compressed,
      8 => Uint8List.fromList(ZLibDecoder(raw: true).convert(compressed)),
      _ => throw FormatException('Unsupported route data zip method: $method'),
    };
    if (decoded.length != uncompressedSize) {
      throw const FormatException('Invalid runetfreedom zip entry size');
    }
    return decoded;
  }

  Future<Uint8List> _loadBundledAsset(String asset) async {
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<void> _writeRoutePackage(
    String directory,
    Map<String, Uint8List> files,
  ) async {
    _validateRoutePackageFiles(files);
    for (final entry in _releaseZipEntries.entries) {
      await _writeAtomically('$directory/${entry.key}', files[entry.value]!);
    }
  }

  static void _validateRoutePackageFiles(Map<String, Uint8List> files) {
    for (final key in _releaseZipEntries.values) {
      final bytes = files[key];
      if (bytes == null || bytes.length <= 4) {
        throw FormatException('Route rule-set is missing or empty: $key');
      }
      if (bytes.length < 4 ||
          bytes[0] != _srsMagicBytes[0] ||
          bytes[1] != _srsMagicBytes[1] ||
          bytes[2] != _srsMagicBytes[2]) {
        throw FormatException('Route rule-set is not SRS: $key');
      }
    }
  }

  Future<_DownloadedDomainListCommunity>
  _downloadDomainListCommunityCategories({
    required RussiaRouteBundle bundle,
    required String sourceDirectoryPath,
    required Map<String, RussiaRouteCategoryMetadata> previousMetadata,
    required Map<String, _DownloadedCategory> downloadedCategories,
    required bool force,
  }) async {
    final categoryFiles = <String, String>{};
    final metadata = <String, RussiaRouteCategoryMetadata>{};
    final pending = [..._rootCategoriesFor(bundle)];
    _emitProgress(
      RussiaRouteUpdateStage.downloadingCategories,
      isRetryingWithoutVpn: false,
    );
    while (pending.isNotEmpty) {
      final category = pending.removeLast();
      if (categoryFiles.containsKey(category)) continue;
      final downloaded = downloadedCategories[category] ??=
          await _downloadDomainListCommunityCategory(
            category: category,
            sourceDirectoryPath: sourceDirectoryPath,
            previousMetadata: previousMetadata[category],
            force: force,
          );
      final content = downloaded.content;
      categoryFiles[category] = content;
      metadata[category] = downloaded.metadata;
      pending.addAll(_extractIncludedCategories(content));
      _emitProgress(
        RussiaRouteUpdateStage.downloadingCategories,
        completedItems: categoryFiles.length,
      );
    }
    return _DownloadedDomainListCommunity(
      categoryFiles: categoryFiles,
      metadata: metadata,
    );
  }

  static List<String> _rootCategoriesFor(RussiaRouteBundle bundle) =>
      switch (bundle) {
        RussiaRouteBundle.curatedDirect => _curatedDirectServicesCategories,
        RussiaRouteBundle.ai => _aiServicesCategories,
        RussiaRouteBundle.social => _socialServicesCategories,
        RussiaRouteBundle.runetFreedom => throw ArgumentError.value(bundle),
      };

  File _categoryCacheFile(String sourceDirectoryPath, String category) =>
      File('$sourceDirectoryPath/${Uri.encodeComponent(category)}.txt');

  Future<_DownloadedCategory> _downloadDomainListCommunityCategory({
    required String category,
    required String sourceDirectoryPath,
    required RussiaRouteCategoryMetadata? previousMetadata,
    required bool force,
  }) async {
    final uri = Uri.parse('$_domainListCommunityRawBaseUrl/$category');
    final cacheFile = _categoryCacheFile(sourceDirectoryPath, category);
    final headers = <String, String>{'Accept': 'text/plain,*/*'};
    if (!force && cacheFile.existsSync()) {
      final etag = previousMetadata?.etag;
      if (etag != null && etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
      }
      final lastModified = previousMetadata?.lastModified;
      if (lastModified != null && lastModified.isNotEmpty) {
        headers['If-Modified-Since'] = lastModified;
      }
    }
    final response = await VpnAwareRemoteDownloader.instance.fetchBytes(
      uri: uri,
      maximumBytes: _maxDomainListCategoryBytes,
      headers: headers,
      acceptedStatusCodes: const <int>{HttpStatus.ok, HttpStatus.notModified},
      onRouteAttempt: (route, isFallback) {
        if (isFallback && route == RemoteDownloadRoute.underlying) {
          final current = progress.value;
          if (current != null) {
            progress.value = current.copyWith(isRetryingWithoutVpn: true);
          } else {
            _emitProgress(
              RussiaRouteUpdateStage.downloadingCategories,
              isRetryingWithoutVpn: true,
            );
          }
        }
      },
    );
    if (response.statusCode == HttpStatus.notModified) {
      return _DownloadedCategory(
        content: await cacheFile.readAsString(),
        metadata: previousMetadata ?? const RussiaRouteCategoryMetadata(),
      );
    }
    final bytes = response.bytes ?? Uint8List(0);
    final content = utf8.decode(bytes, allowMalformed: true);
    final previousContent = cacheFile.existsSync()
        ? await cacheFile.readAsString()
        : null;
    final changed = previousContent != content;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    return _DownloadedCategory(
      content: content,
      metadata: RussiaRouteCategoryMetadata(
        etag: response.headers[HttpHeaders.etagHeader],
        lastModified: response.headers[HttpHeaders.lastModifiedHeader],
        updatedAtMillis: changed
            ? nowMillis
            : previousMetadata?.updatedAtMillis ?? nowMillis,
      ),
    );
  }

  List<String> _extractIncludedCategories(String content) {
    final includes = <String>[];
    final seen = <String>{};
    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.split('#').first.trim();
      if (!line.startsWith('include:')) {
        continue;
      }
      final include = _parseIncludedCategory(line);
      if (include.isNotEmpty && seen.add(include)) {
        includes.add(include);
      }
    }
    return includes;
  }

  Future<void> _writeAtomically(String path, List<int> bytes) async {
    final target = File(path);
    await target.parent.create(recursive: true);
    final temp = File('$path.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    try {
      await temp.rename(path);
      return;
    } on FileSystemException {
      final backup = File('$path.bak');
      if (target.existsSync()) {
        if (backup.existsSync()) await backup.delete();
        await target.rename(backup.path);
      }
      try {
        await temp.rename(path);
      } catch (_) {
        if (!target.existsSync() && backup.existsSync()) {
          await backup.rename(path);
        }
        rethrow;
      }
      try {
        if (backup.existsSync()) await backup.delete();
      } on FileSystemException {
        // The new file is already active. A later write can remove the backup.
      }
    }
  }

  Future<_RussiaRouteStoragePaths> _storagePaths() async {
    final baseDirPath = Platform.isAndroid
        ? await AndroidFilesDir.ensureInitialized()
        : Platform.isWindows
        ? AppDataPaths.current.ruleSetRoot
        : Directory.systemTemp.path;
    final base = Directory('$baseDirPath/route-data/russia-v2ray-rules-dat');
    return _RussiaRouteStoragePaths(
      baseDirectoryPath: base.path,
      domainListCommunitySourceDirectoryPath:
          '${base.path}/domain-list-community',
      metadataPath: '${base.path}/manifest.json',
    );
  }
}

class _PreparedRoutePackage {
  const _PreparedRoutePackage({required this.files, required this.sha256});

  final Map<String, Uint8List> files;
  final String sha256;
}

_PreparedRoutePackage _prepareRoutePackageArchive(Uint8List bytes) {
  return _PreparedRoutePackage(
    files: RussiaRouteDataService._extractRequiredRuleSetsFromZip(bytes),
    sha256: crypto.sha256.convert(bytes).toString(),
  );
}

Future<_PreparedRoutePackage> _prepareRoutePackageArchiveInBackground(
  Uint8List bytes,
) {
  return compute(
    _prepareRoutePackageArchive,
    bytes,
    debugLabel: 'route-package-extract',
  );
}

class _RussiaRouteStoragePaths {
  const _RussiaRouteStoragePaths({
    required this.baseDirectoryPath,
    required this.domainListCommunitySourceDirectoryPath,
    required this.metadataPath,
  });

  final String baseDirectoryPath;
  final String domainListCommunitySourceDirectoryPath;
  final String metadataPath;
}

class _RunetFreedomReleaseAsset {
  const _RunetFreedomReleaseAsset({
    required this.tagName,
    required this.assetUrl,
    required this.assetSizeBytes,
  });

  final String tagName;
  final Uri assetUrl;
  final int? assetSizeBytes;
}

class _InstalledRoutePackageInfo {
  const _InstalledRoutePackageInfo({
    required this.sourceKind,
    required this.versionTag,
    this.releaseTag,
    this.packageSha256,
    this.assetSizeBytes,
    this.verifiedAtMillis,
    this.verifiedFiles = const <String>[],
  });

  final String sourceKind;
  final String versionTag;
  final String? releaseTag;
  final String? packageSha256;
  final int? assetSizeBytes;
  final int? verifiedAtMillis;
  final List<String> verifiedFiles;
}

class _DownloadedDomainListCommunity {
  const _DownloadedDomainListCommunity({
    required this.categoryFiles,
    required this.metadata,
  });

  final Map<String, String> categoryFiles;
  final Map<String, RussiaRouteCategoryMetadata> metadata;
}

class _DownloadedCategory {
  const _DownloadedCategory({required this.content, required this.metadata});

  final String content;
  final RussiaRouteCategoryMetadata metadata;
}

Map<String, RussiaRouteCategoryMetadata> _categoryMetadataFromJson(
  Object? value,
) {
  if (value is! Map) {
    return const <String, RussiaRouteCategoryMetadata>{};
  }
  return {
    for (final entry in value.entries)
      entry.key.toString(): RussiaRouteCategoryMetadata.fromJson(entry.value),
  };
}

List<String> _stringListFromJson(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((entry) => entry.toString().trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

Map<String, String> _readCachedDomainListCommunityCategories(String directory) {
  final files = <String, String>{};
  final pending = <String>[
    ...RussiaRouteDataService._curatedDirectServicesCategories,
    ...RussiaRouteDataService._aiServicesCategories,
    ...RussiaRouteDataService._socialServicesCategories,
  ];
  while (pending.isNotEmpty) {
    final category = pending.removeLast();
    if (files.containsKey(category)) continue;
    final file = File('$directory/${Uri.encodeComponent(category)}.txt');
    if (category == RussiaRouteDataService._additionalSocialCategory &&
        !file.existsSync()) {
      continue;
    }
    final content = file.readAsStringSync();
    files[category] = content;
    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.split('#').first.trim();
      if (line.startsWith('include:')) {
        pending.add(_parseIncludedCategory(line));
      }
    }
  }
  return files;
}

Map<String, _CompiledRuleSetArtifact> _compileDomainListCommunityArtifacts(
  Map<String, String> categoryFiles,
) => {
  'ru-direct-services.srs': _compileCuratedDirectServicesArtifact(
    categoryFiles,
  ),
  'ai-services.srs': _compileAiServicesArtifact(categoryFiles),
  'social-services.srs': _compileSocialServicesArtifact(categoryFiles),
};

_CompiledRuleSetArtifact _compileBundleArtifact(
  ({RussiaRouteBundle bundle, Map<String, String> categories}) inputs,
) => switch (inputs.bundle) {
  RussiaRouteBundle.curatedDirect => _compileCuratedDirectServicesArtifact(
    inputs.categories,
  ),
  RussiaRouteBundle.ai => _compileAiServicesArtifact(inputs.categories),
  RussiaRouteBundle.social => _compileSocialServicesArtifact(inputs.categories),
  RussiaRouteBundle.runetFreedom => throw ArgumentError.value(inputs.bundle),
};

_CompiledRuleSetArtifact _compileCuratedDirectServicesArtifact(
  Map<String, String> categoryFiles,
) {
  return _compileDomainListCommunityArtifact(
    categoryFiles,
    RussiaRouteDataService._curatedDirectServicesCategories,
  );
}

_CompiledRuleSetArtifact _compileAiServicesArtifact(
  Map<String, String> categoryFiles,
) {
  return _compileDomainListCommunityArtifact(
    categoryFiles,
    RussiaRouteDataService._aiServicesCategories,
  );
}

_CompiledRuleSetArtifact _compileSocialServicesArtifact(
  Map<String, String> categoryFiles,
) {
  return _compileDomainListCommunityArtifact(
    categoryFiles,
    RussiaRouteDataService._socialServicesCategories
        .where(
          (category) =>
              category != RussiaRouteDataService._additionalSocialCategory ||
              categoryFiles.containsKey(category),
        )
        .toList(),
  );
}

_CompiledRuleSetArtifact _compileDomainListCommunityArtifact(
  Map<String, String> categoryFiles,
  List<String> rootCategories,
) {
  final exactDomains = <String>{};
  final suffixDomains = <String>{};
  final keywords = <String>{};
  final visiting = <String>{};
  List<(_NormalizedRuleDomain, Set<String>)> loadCategory(String category) {
    if (!visiting.add(category)) {
      return [];
    }
    final content = categoryFiles[category];
    if (content == null) {
      throw FormatException('Missing domain-list category: $category');
    }
    final rules = <(_NormalizedRuleDomain, Set<String>)>[];
    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.split('#').first.trim();
      if (line.isEmpty) {
        continue;
      }
      final tokens = line.split(RegExp(r'\s+'));
      final value = tokens.first;
      final attributes = tokens
          .skip(1)
          .where((token) => token.startsWith('@'))
          .map((token) => token.substring(1))
          .toSet();
      if (value.startsWith('include:')) {
        final included = loadCategory(_parseIncludedCategory(value));
        rules.addAll(
          included.where(
            (rule) => attributes.every(
              (attribute) => attribute.startsWith('-')
                  ? !rule.$2.contains(attribute.substring(1))
                  : rule.$2.contains(attribute),
            ),
          ),
        );
        continue;
      }
      if (attributes.contains('ads') ||
          value.startsWith('regexp:') ||
          value.startsWith('geosite:') ||
          value.startsWith('ext:')) {
        continue;
      }
      final normalized = _normalizeServiceDomainLine(value);
      if (normalized == null) {
        continue;
      }
      rules.add((normalized, attributes));
    }
    visiting.remove(category);
    return rules;
  }

  for (final category in rootCategories) {
    for (final rule in loadCategory(category)) {
      final normalized = rule.$1;
      switch (normalized.type) {
        case _RuleDomainType.exact:
          exactDomains.add(normalized.value);
        case _RuleDomainType.suffix:
          suffixDomains.add(normalized.value);
        case _RuleDomainType.keyword:
          keywords.add(normalized.value);
      }
    }
  }

  final exactList = exactDomains.toList()..sort();
  final suffixList = suffixDomains.toList()..sort();
  final keywordList = keywords.toList()..sort();
  return _CompiledRuleSetArtifact(
    ruleSetBytes: _buildSrsRuleSet(
      domains: exactList,
      domainSuffixes: suffixList,
      domainKeywords: keywordList,
    ),
    domainCount: exactList.length + suffixList.length + keywordList.length,
  );
}

String _parseIncludedCategory(String line) {
  final include = line.substring('include:'.length).trim();
  final separator = include.indexOf(_domainListWhitespaceRegExp);
  return separator < 0 ? include : include.substring(0, separator);
}

_NormalizedRuleDomain? _normalizeServiceDomainLine(String line) {
  var value = line.trim();
  if (value.isEmpty) {
    return null;
  }
  if (value.startsWith('keyword:')) {
    final keyword = value.substring('keyword:'.length).trim().toLowerCase();
    return keyword.isEmpty || !_validDomainRegExp.hasMatch(keyword)
        ? null
        : _NormalizedRuleDomain(_RuleDomainType.keyword, keyword);
  }
  if (value.startsWith('full:')) {
    value = value.substring('full:'.length).trim();
    final normalized = _normalizeDomainValue(value);
    return normalized == null
        ? null
        : _NormalizedRuleDomain(_RuleDomainType.exact, normalized);
  }
  if (value.startsWith('domain:')) {
    value = value.substring('domain:'.length).trim();
    final normalized = _normalizeDomainValue(value);
    return normalized == null
        ? null
        : _NormalizedRuleDomain(_RuleDomainType.suffix, normalized);
  }
  final normalized = _normalizeDomainValue(value);
  return normalized == null
      ? null
      : _NormalizedRuleDomain(_RuleDomainType.suffix, normalized);
}

String? _normalizeDomainValue(String value) {
  var normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  while (normalized.startsWith('.')) {
    normalized = normalized.substring(1);
  }
  while (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.isEmpty ||
      normalized.contains('..') ||
      normalized.contains(':') ||
      normalized.contains('/') ||
      normalized.contains('*') ||
      !_validDomainRegExp.hasMatch(normalized)) {
    return null;
  }
  return normalized;
}

Uint8List _buildSrsRuleSet({
  required List<String> domains,
  required List<String> domainSuffixes,
  required List<String> domainKeywords,
}) {
  final body = _ByteAccumulator();
  _writeUvarint(
    body,
    (domains.isNotEmpty ||
            domainSuffixes.isNotEmpty ||
            domainKeywords.isNotEmpty)
        ? 1
        : 0,
  );
  if (domains.isNotEmpty ||
      domainSuffixes.isNotEmpty ||
      domainKeywords.isNotEmpty) {
    _writeDefaultDomainRule(
      body,
      domains: domains,
      domainSuffixes: domainSuffixes,
      domainKeywords: domainKeywords,
    );
  }
  final compressedBody = Uint8List.fromList(
    ZLibEncoder(level: 9).convert(body.toBytes()),
  );
  final result = _ByteAccumulator();
  result.writeBytes(_srsMagicBytes);
  result.writeByte(_srsVersion2);
  result.writeBytes(compressedBody);
  return result.toBytes();
}

void _writeDefaultDomainRule(
  _ByteAccumulator writer, {
  required List<String> domains,
  required List<String> domainSuffixes,
  required List<String> domainKeywords,
}) {
  writer.writeByte(0);
  if (domains.isNotEmpty || domainSuffixes.isNotEmpty) {
    writer.writeByte(_ruleItemDomain);
    _buildDomainMatcher(
      domains: domains,
      domainSuffixes: domainSuffixes,
    ).writeTo(writer);
  }
  if (domainKeywords.isNotEmpty) {
    writer.writeByte(_ruleItemDomainKeyword);
    _writeUvarint(writer, domainKeywords.length);
    for (final keyword in domainKeywords) {
      final bytes = utf8.encode(keyword);
      _writeUvarint(writer, bytes.length);
      writer.writeBytes(bytes);
    }
  }
  writer.writeByte(_ruleItemFinal);
  writer.writeByte(0);
}

_DomainMatcher _buildDomainMatcher({
  required List<String> domains,
  required List<String> domainSuffixes,
}) {
  final domainList = <String>[];
  final seen = <String>{};

  for (final domain in domainSuffixes) {
    if (domain.isEmpty || !seen.add('s:$domain')) {
      continue;
    }
    domainList.add(_reverseAscii('$_rootLabelMarker$domain'));
  }
  for (final domain in domains) {
    if (domain.isEmpty || !seen.add('d:$domain')) {
      continue;
    }
    domainList.add(_reverseAscii(domain));
  }

  domainList.sort();
  return _DomainMatcher(_buildSuccinctSet(domainList));
}

_SuccinctSet _buildSuccinctSet(List<String> keys) {
  final leaves = <int>[];
  final labelBitmap = <int>[];
  final labels = <int>[];
  var labelIndex = 0;
  final queue = <_QueueEntry>[_QueueEntry(0, keys.length, 0)];

  for (var i = 0; i < queue.length; i++) {
    final entry = queue[i];
    if (entry.start >= entry.end) {
      continue;
    }
    var start = entry.start;
    if (entry.column == keys[start].length) {
      start++;
      _setBit(leaves, i, 1);
    }
    for (var j = start; j < entry.end;) {
      final from = j;
      final currentByte = keys[from].codeUnitAt(entry.column);
      while (j < entry.end && keys[j].codeUnitAt(entry.column) == currentByte) {
        j++;
      }
      queue.add(_QueueEntry(from, j, entry.column + 1));
      labels.add(currentByte);
      _setBit(labelBitmap, labelIndex, 0);
      labelIndex++;
    }
    _setBit(labelBitmap, labelIndex, 1);
    labelIndex++;
  }

  return _SuccinctSet(
    leaves: leaves,
    labelBitmap: labelBitmap,
    labels: Uint8List.fromList(labels),
  );
}

String _reverseAscii(String value) {
  return String.fromCharCodes(value.codeUnits.reversed);
}

void _setBit(List<int> bitmap, int index, int value) {
  final wordIndex = index >> 6;
  while (wordIndex >= bitmap.length) {
    bitmap.add(0);
  }
  bitmap[wordIndex] |= value << (index & 63);
}

void _writeUvarint(_ByteAccumulator writer, int value) {
  var current = value;
  while (current >= 0x80) {
    writer.writeByte((current & 0xFF) | 0x80);
    current >>= 7;
  }
  writer.writeByte(current & 0xFF);
}

class _ByteAccumulator {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  void writeByte(int value) => _builder.addByte(value & 0xFF);

  void writeBytes(List<int> values) {
    if (values.isNotEmpty) {
      _builder.add(values);
    }
  }

  void writeUint64List(List<int> values) {
    _writeUvarint(this, values.length);
    if (values.isEmpty) {
      return;
    }
    final data = ByteData(values.length * 8);
    for (var i = 0; i < values.length; i++) {
      data.setUint64(i * 8, values[i], Endian.big);
    }
    writeBytes(data.buffer.asUint8List());
  }

  void writeByteList(Uint8List values) {
    _writeUvarint(this, values.length);
    writeBytes(values);
  }

  Uint8List toBytes() => _builder.takeBytes();
}

class _CompiledRuleSetArtifact {
  const _CompiledRuleSetArtifact({
    required this.ruleSetBytes,
    required this.domainCount,
  });

  final Uint8List ruleSetBytes;
  final int domainCount;
}

class _DomainMatcher {
  const _DomainMatcher(this.set);

  final _SuccinctSet set;

  void writeTo(_ByteAccumulator writer) => set.writeTo(writer);
}

class _SuccinctSet {
  const _SuccinctSet({
    required this.leaves,
    required this.labelBitmap,
    required this.labels,
  });

  final List<int> leaves;
  final List<int> labelBitmap;
  final Uint8List labels;

  void writeTo(_ByteAccumulator writer) {
    writer.writeByte(0);
    writer.writeUint64List(leaves);
    writer.writeUint64List(labelBitmap);
    writer.writeByteList(labels);
  }
}

class _QueueEntry {
  const _QueueEntry(this.start, this.end, this.column);

  final int start;
  final int end;
  final int column;
}

class _NormalizedRuleDomain {
  const _NormalizedRuleDomain(this.type, this.value);

  final _RuleDomainType type;
  final String value;
}

enum _RuleDomainType { exact, suffix, keyword }

const List<int> _srsMagicBytes = <int>[0x53, 0x52, 0x53];
const int _srsVersion2 = 2;
const int _ruleItemDomain = 2;
const int _ruleItemDomainKeyword = 3;
const int _ruleItemFinal = 0xFF;
const String _rootLabelMarker = '\n';
