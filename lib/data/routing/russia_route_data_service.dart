import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart';
import 'package:meow_client/core/network/remote_download_timeout.dart';

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
    this.domainListCommunityMetadata =
        const <String, RussiaRouteCategoryMetadata>{},
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
      domainListCommunityMetadata =
          const <String, RussiaRouteCategoryMetadata>{};

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
  final Map<String, RussiaRouteCategoryMetadata> domainListCommunityMetadata;

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

  bool get needsDailyUpdate {
    final lastCheck = lastUpdateCheckAt;
    if (lastCheck == null) {
      return true;
    }
    return DateTime.now().difference(lastCheck) >= const Duration(hours: 24);
  }
}

class RussiaRouteDataFile {
  const RussiaRouteDataFile({
    required this.name,
    required this.sizeBytes,
    required this.updatedAt,
  });

  final String name;
  final int sizeBytes;
  final DateTime updatedAt;

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
  });

  final RussiaRouteUpdateStage stage;
  final int completedBytes;
  final int totalBytes;
  final int completedItems;
  final int totalItems;

  double? get fraction {
    if (totalBytes > 0) {
      return (completedBytes / totalBytes).clamp(0, 1).toDouble();
    }
    if (totalItems > 0) {
      return (completedItems / totalItems).clamp(0, 1).toDouble();
    }
    return null;
  }
}

class RussiaRouteDataService {
  RussiaRouteDataService._();

  static final RussiaRouteDataService instance = RussiaRouteDataService._();

  static const sourceName = 'runetfreedom + domain-list-community';
  static const sourceKindLive = 'live';
  static const sourceKindBundled = 'bundled';
  static const bundledTag = 'bundled-20260327';
  static const livePackageName = 'runetfreedom sing-box.zip';
  static const _latestReleaseUrl =
      'https://api.github.com/repos/runetfreedom/russia-v2ray-rules-dat/releases/latest';
  static const _maxSingboxZipBytes = 80 * 1024 * 1024;
  static const _connectTimeout = remoteDownloadIdleTimeout;
  static const _responseTimeout = remoteDownloadIdleTimeout;
  static const domainListCommunitySourceName = 'v2fly/domain-list-community';
  static const _domainListCommunityRawBaseUrl =
      'https://raw.githubusercontent.com/v2fly/domain-list-community/master/data';
  static const _maxDomainListCategoryBytes = 2 * 1024 * 1024;

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
  static const _socialServicesCategories = <String>[
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
  final ValueNotifier<RussiaRouteUpdateProgress?> progress = ValueNotifier(
    null,
  );

  bool get isUpdating => _updateInFlight != null;

  void _emitProgress(
    RussiaRouteUpdateStage stage, {
    int completedBytes = 0,
    int totalBytes = 0,
    int completedItems = 0,
    int totalItems = 0,
  }) {
    progress.value = RussiaRouteUpdateProgress(
      stage: stage,
      completedBytes: completedBytes,
      totalBytes: totalBytes,
      completedItems: completedItems,
      totalItems: totalItems,
    );
  }

  Future<RussiaRouteDataStatus> loadStatus() async {
    final paths = await _storagePaths();
    final metadataFile = File(paths.metadataPath);
    final geositeBlockedFile = File(paths.geositeRuBlockedPath);
    final geositeAvailableOnlyInsideFile = File(
      paths.geositeRuAvailableOnlyInsidePath,
    );
    final geositeCategoryRuFile = File(paths.geositeCategoryRuPath);
    final geoipBlockedFile = File(paths.geoipRuBlockedPath);
    final geoipWhitelistFile = File(paths.geoipRuWhitelistPath);
    final geoipRuFile = File(paths.geoipRuPath);
    final curatedDirectServicesFile = File(paths.curatedDirectServicesPath);
    final aiServicesFile = File(paths.aiServicesPath);
    final socialServicesFile = File(paths.socialServicesPath);
    if (!metadataFile.existsSync() ||
        !_hasUsableRuleSet(geositeBlockedFile) ||
        !_hasUsableRuleSet(geositeAvailableOnlyInsideFile) ||
        !_hasUsableRuleSet(geositeCategoryRuFile) ||
        !_hasUsableRuleSet(geoipBlockedFile) ||
        !_hasUsableRuleSet(geoipWhitelistFile) ||
        !_hasUsableRuleSet(geoipRuFile)) {
      return const RussiaRouteDataStatus.unavailable();
    }
    try {
      final metadata =
          jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
      return RussiaRouteDataStatus(
        available: true,
        sourceName: metadata['sourceName']?.toString() ?? sourceName,
        versionTag: metadata['versionTag']?.toString() ?? bundledTag,
        sourceKind: metadata['sourceKind']?.toString() ?? sourceKindBundled,
        releaseTag: metadata['releaseTag']?.toString(),
        packageSha256: metadata['packageSha256']?.toString(),
        assetSizeBytes: int.tryParse(
          metadata['assetSizeBytes']?.toString() ?? '',
        ),
        verifiedAtMillis: int.tryParse(
          metadata['verifiedAtMillis']?.toString() ?? '',
        ),
        verifiedFiles: _stringListFromJson(metadata['verifiedFiles']),
        geositeRuBlockedPath: geositeBlockedFile.path,
        geositeRuAvailableOnlyInsidePath: geositeAvailableOnlyInsideFile.path,
        geositeCategoryRuPath: geositeCategoryRuFile.path,
        geoipRuBlockedPath: geoipBlockedFile.path,
        geoipRuWhitelistPath: geoipWhitelistFile.path,
        geoipRuPath: geoipRuFile.path,
        curatedDirectServicesPath: _hasUsableRuleSet(curatedDirectServicesFile)
            ? curatedDirectServicesFile.path
            : null,
        aiServicesPath: _hasUsableRuleSet(aiServicesFile)
            ? aiServicesFile.path
            : null,
        socialServicesPath: _hasUsableRuleSet(socialServicesFile)
            ? socialServicesFile.path
            : null,
        installedAtMillis: int.tryParse(
          metadata['installedAtMillis']?.toString() ?? '',
        ),
        lastUpdateCheckAtMillis: int.tryParse(
          metadata['lastUpdateCheckAtMillis']?.toString() ?? '',
        ),
        domainListCommunityUpdatedAtMillis: int.tryParse(
          metadata['domainListCommunityUpdatedAtMillis']?.toString() ?? '',
        ),
        domainListCommunityCategoryCount:
            int.tryParse(
              metadata['domainListCommunityCategoryCount']?.toString() ?? '',
            ) ??
            0,
        domainListCommunityDomainCount:
            int.tryParse(
              metadata['domainListCommunityDomainCount']?.toString() ?? '',
            ) ??
            0,
        domainListCommunityMetadata: _categoryMetadataFromJson(
          metadata['domainListCommunityMetadata'],
        ),
      );
    } catch (_) {
      return const RussiaRouteDataStatus.unavailable();
    }
  }

  Future<List<RussiaRouteDataFile>> listInstalledFiles() async {
    final paths = await _storagePaths();
    final candidates = <_RussiaRouteDataFilePath>[
      _RussiaRouteDataFilePath(
        'geosite-ru-blocked.srs',
        paths.geositeRuBlockedPath,
      ),
      _RussiaRouteDataFilePath(
        'geosite-ru-available-only-inside.srs',
        paths.geositeRuAvailableOnlyInsidePath,
      ),
      _RussiaRouteDataFilePath(
        'geosite-category-ru.srs',
        paths.geositeCategoryRuPath,
      ),
      _RussiaRouteDataFilePath(
        'geoip-ru-blocked.srs',
        paths.geoipRuBlockedPath,
      ),
      _RussiaRouteDataFilePath(
        'geoip-ru-whitelist.srs',
        paths.geoipRuWhitelistPath,
      ),
      _RussiaRouteDataFilePath('geoip-ru.srs', paths.geoipRuPath),
      _RussiaRouteDataFilePath(
        'ru-direct-services.srs',
        paths.curatedDirectServicesPath,
      ),
      _RussiaRouteDataFilePath('ai-services.srs', paths.aiServicesPath),
      _RussiaRouteDataFilePath('social-services.srs', paths.socialServicesPath),
    ];
    final installed = <RussiaRouteDataFile>[];
    for (final candidate in candidates) {
      final file = File(candidate.path);
      try {
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file || stat.size <= 4) {
          continue;
        }
        installed.add(
          RussiaRouteDataFile(
            name: candidate.name,
            sizeBytes: stat.size,
            updatedAt: stat.modified,
          ),
        );
      } on FileSystemException {
        // A concurrent atomic update may replace a file between lookup and stat.
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

  Future<RussiaRouteDataStatus> ensureBundledInstalled() async {
    final inFlight = _updateInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _ensureBundledInstalled();
    _updateInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_updateInFlight, future)) {
        _updateInFlight = null;
        progress.value = null;
      }
    }
  }

  Future<RussiaRouteDataStatus> _ensureBundledInstalled() async {
    _emitProgress(RussiaRouteUpdateStage.checking);
    final current = await loadStatus();
    if (current.available) {
      _emitProgress(RussiaRouteUpdateStage.complete);
      return current;
    }
    final paths = await _storagePaths();
    await Directory(paths.baseDirectoryPath).create(recursive: true);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final packageInfo = await _installBundledRoutePackage(
      paths,
      checkedAtMillis: nowMillis,
    );
    _emitProgress(RussiaRouteUpdateStage.activating);
    await _writeMetadata(
      paths,
      packageInfo: packageInfo.copyWith(
        installedAtMillis: nowMillis,
        // The bundled package is immediately usable, but a live refresh is
        // still due as soon as the app has network access.
        lastUpdateCheckAtMillis: 0,
      ),
      installedAtMillis: nowMillis,
      lastUpdateCheckAtMillis: 0,
      domainListCommunityUpdatedAtMillis: nowMillis,
      domainListCommunityCategoryCount: 0,
      domainListCommunityDomainCount: 0,
      domainListCommunityMetadata: const {},
    );
    final status = await loadStatus();
    _emitProgress(RussiaRouteUpdateStage.complete);
    return status;
  }

  Future<RussiaRouteDataStatus> deleteInstalled() async {
    final paths = await _storagePaths();
    final base = Directory(paths.baseDirectoryPath);
    if (base.existsSync()) {
      await base.delete(recursive: true);
    }
    return const RussiaRouteDataStatus.unavailable();
  }

  Future<RussiaRouteUpdateCheck> checkForUpdate() async {
    final current = await loadStatus();
    final latest = await _fetchLatestRunetFreedomRelease();
    final updateAvailable =
        !current.available ||
        current.sourceKind != sourceKindLive ||
        current.releaseTag != latest.tagName;
    if (updateAvailable || !current.available) {
      return RussiaRouteUpdateCheck(
        status: current,
        latestTag: latest.tagName,
        updateAvailable: true,
      );
    }

    final paths = await _storagePaths();
    final checkedAtMillis = DateTime.now().millisecondsSinceEpoch;
    final installedAtMillis = current.installedAtMillis ?? checkedAtMillis;
    await _writeMetadata(
      paths,
      packageInfo: _InstalledRoutePackageInfo.fromStatus(current).copyWith(
        installedAtMillis: installedAtMillis,
        lastUpdateCheckAtMillis: checkedAtMillis,
      ),
      installedAtMillis: installedAtMillis,
      lastUpdateCheckAtMillis: checkedAtMillis,
      domainListCommunityUpdatedAtMillis:
          current.domainListCommunityUpdatedAtMillis ?? checkedAtMillis,
      domainListCommunityCategoryCount:
          current.domainListCommunityCategoryCount,
      domainListCommunityDomainCount: current.domainListCommunityDomainCount,
      domainListCommunityMetadata: current.domainListCommunityMetadata,
    );
    return RussiaRouteUpdateCheck(
      status: await loadStatus(),
      latestTag: latest.tagName,
      updateAvailable: false,
    );
  }

  Future<RussiaRouteDataStatus> ensureUpdated({bool force = false}) async {
    final inFlight = _updateInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _ensureUpdated(force: force);
    _updateInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_updateInFlight, future)) {
        _updateInFlight = null;
        progress.value = null;
      }
    }
  }

  Future<RussiaRouteDataStatus> _ensureUpdated({required bool force}) async {
    _emitProgress(RussiaRouteUpdateStage.checking);
    final current = await loadStatus();
    if (!force && current.available && !current.needsDailyUpdate) {
      return current;
    }
    final paths = await _storagePaths();
    await Directory(paths.baseDirectoryPath).create(recursive: true);
    await Directory(
      paths.domainListCommunitySourceDirectoryPath,
    ).create(recursive: true);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    var packageInfo = _InstalledRoutePackageInfo.fromStatus(current);
    var livePackageCheckSucceeded = false;
    try {
      packageInfo = await _installLiveRoutePackage(paths, current: current);
      livePackageCheckSucceeded = true;
    } catch (_) {
      if (force && current.available) {
        rethrow;
      }
      if (current.available) {
        packageInfo = _InstalledRoutePackageInfo.fromStatus(current);
      } else {
        packageInfo = await _installBundledRoutePackage(
          paths,
          checkedAtMillis: nowMillis,
        );
      }
    }
    final successfulCheckAtMillis = livePackageCheckSucceeded
        ? nowMillis
        : current.lastUpdateCheckAtMillis ?? 0;
    try {
      final downloaded = await _downloadDomainListCommunityCategories(
        sourceDirectoryPath: paths.domainListCommunitySourceDirectoryPath,
        previousMetadata: current.domainListCommunityMetadata,
        force: force,
      );
      final shouldRebuildDomainLists =
          force ||
          !current.available ||
          downloaded.changed ||
          !File(paths.curatedDirectServicesPath).existsSync() ||
          !File(paths.aiServicesPath).existsSync() ||
          !File(paths.socialServicesPath).existsSync();
      var downloadedCategoryCount = current.domainListCommunityCategoryCount;
      var compiledDomainCount = current.domainListCommunityDomainCount;
      var domainListCommunityUpdatedAtMillis =
          current.domainListCommunityUpdatedAtMillis;
      if (shouldRebuildDomainLists) {
        _emitProgress(RussiaRouteUpdateStage.compiling);
        final categoryFiles = downloaded.categoryFiles;
        final compiledCuratedDirectServices = await Isolate.run(
          () => _compileCuratedDirectServicesArtifact(categoryFiles),
        );
        final compiledAiServices = await Isolate.run(
          () => _compileAiServicesArtifact(categoryFiles),
        );
        final compiledSocialServices = await Isolate.run(
          () => _compileSocialServicesArtifact(categoryFiles),
        );
        await _writeAtomically(
          paths.curatedDirectServicesPath,
          compiledCuratedDirectServices.ruleSetBytes,
        );
        await _writeAtomically(
          paths.aiServicesPath,
          compiledAiServices.ruleSetBytes,
        );
        await _writeAtomically(
          paths.socialServicesPath,
          compiledSocialServices.ruleSetBytes,
        );
        downloadedCategoryCount = categoryFiles.length;
        compiledDomainCount =
            compiledCuratedDirectServices.domainCount +
            compiledAiServices.domainCount +
            compiledSocialServices.domainCount;
        domainListCommunityUpdatedAtMillis = nowMillis;
      }
      final installedAtMillis = current.installedAtMillis ?? nowMillis;
      _emitProgress(RussiaRouteUpdateStage.activating);
      await _writeMetadata(
        paths,
        packageInfo: packageInfo.copyWith(
          installedAtMillis: installedAtMillis,
          lastUpdateCheckAtMillis: successfulCheckAtMillis,
        ),
        installedAtMillis: installedAtMillis,
        lastUpdateCheckAtMillis: successfulCheckAtMillis,
        domainListCommunityUpdatedAtMillis:
            domainListCommunityUpdatedAtMillis ?? nowMillis,
        domainListCommunityCategoryCount: downloadedCategoryCount,
        domainListCommunityDomainCount: compiledDomainCount,
        domainListCommunityMetadata: downloaded.metadata,
      );
      final status = RussiaRouteDataStatus(
        available: true,
        sourceName: sourceName,
        versionTag: packageInfo.versionTag,
        sourceKind: packageInfo.sourceKind,
        releaseTag: packageInfo.releaseTag,
        packageSha256: packageInfo.packageSha256,
        assetSizeBytes: packageInfo.assetSizeBytes,
        verifiedAtMillis: packageInfo.verifiedAtMillis,
        verifiedFiles: packageInfo.verifiedFiles,
        geositeRuBlockedPath: paths.geositeRuBlockedPath,
        geositeRuAvailableOnlyInsidePath:
            paths.geositeRuAvailableOnlyInsidePath,
        geositeCategoryRuPath: paths.geositeCategoryRuPath,
        geoipRuBlockedPath: paths.geoipRuBlockedPath,
        geoipRuWhitelistPath: paths.geoipRuWhitelistPath,
        geoipRuPath: paths.geoipRuPath,
        curatedDirectServicesPath: paths.curatedDirectServicesPath,
        aiServicesPath: paths.aiServicesPath,
        socialServicesPath: paths.socialServicesPath,
        installedAtMillis: installedAtMillis,
        lastUpdateCheckAtMillis: successfulCheckAtMillis,
        domainListCommunityUpdatedAtMillis:
            domainListCommunityUpdatedAtMillis ?? nowMillis,
        domainListCommunityCategoryCount: downloadedCategoryCount,
        domainListCommunityDomainCount: compiledDomainCount,
        domainListCommunityMetadata: downloaded.metadata,
      );
      _emitProgress(RussiaRouteUpdateStage.complete);
      return status;
    } catch (_) {
      // The domain-list enrichment is optional. The six verified runetfreedom
      // rule sets already provide the complete smart-routing fallback, so a
      // raw GitHub outage must not make a fresh/offline installation unusable.
      final installedAtMillis = current.installedAtMillis ?? nowMillis;
      await _writeMetadata(
        paths,
        packageInfo: packageInfo.copyWith(
          installedAtMillis: installedAtMillis,
          lastUpdateCheckAtMillis: successfulCheckAtMillis,
        ),
        installedAtMillis: installedAtMillis,
        lastUpdateCheckAtMillis: successfulCheckAtMillis,
        domainListCommunityUpdatedAtMillis:
            current.domainListCommunityUpdatedAtMillis ?? nowMillis,
        domainListCommunityCategoryCount:
            current.domainListCommunityCategoryCount,
        domainListCommunityDomainCount: current.domainListCommunityDomainCount,
        domainListCommunityMetadata: current.domainListCommunityMetadata,
      );
      return loadStatus();
    }
  }

  Future<void> _writeMetadata(
    _RussiaRouteStoragePaths paths, {
    required _InstalledRoutePackageInfo packageInfo,
    required int installedAtMillis,
    required int lastUpdateCheckAtMillis,
    required int domainListCommunityUpdatedAtMillis,
    required int domainListCommunityCategoryCount,
    required int domainListCommunityDomainCount,
    required Map<String, RussiaRouteCategoryMetadata>
    domainListCommunityMetadata,
  }) {
    return _writeAtomically(
      paths.metadataPath,
      utf8.encode(
        jsonEncode({
          'sourceName': sourceName,
          'versionTag': packageInfo.versionTag,
          'sourceKind': packageInfo.sourceKind,
          if (packageInfo.releaseTag != null)
            'releaseTag': packageInfo.releaseTag,
          if (packageInfo.packageSha256 != null)
            'packageSha256': packageInfo.packageSha256,
          if (packageInfo.assetSizeBytes != null)
            'assetSizeBytes': packageInfo.assetSizeBytes,
          if (packageInfo.verifiedAtMillis != null)
            'verifiedAtMillis': packageInfo.verifiedAtMillis,
          'verifiedFiles': packageInfo.verifiedFiles,
          'installedAtMillis': installedAtMillis,
          'lastUpdateCheckAtMillis': lastUpdateCheckAtMillis,
          'domainListCommunityUpdatedAtMillis':
              domainListCommunityUpdatedAtMillis,
          'domainListCommunityCategoryCount': domainListCommunityCategoryCount,
          'domainListCommunityDomainCount': domainListCommunityDomainCount,
          'domainListCommunityMetadata': {
            for (final entry in domainListCommunityMetadata.entries)
              entry.key: entry.value.toJson(),
          },
        }),
      ),
    );
  }

  Future<_InstalledRoutePackageInfo> _installLiveRoutePackage(
    _RussiaRouteStoragePaths paths, {
    required RussiaRouteDataStatus current,
  }) async {
    _emitProgress(RussiaRouteUpdateStage.checking);
    final release = await _fetchLatestRunetFreedomRelease();
    if (current.available &&
        current.sourceKind == sourceKindLive &&
        current.releaseTag == release.tagName) {
      return _InstalledRoutePackageInfo.fromStatus(current).copyWith(
        lastUpdateCheckAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
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
    _emitProgress(RussiaRouteUpdateStage.verifyingPackage);
    crypto.sha256.convert(bytes);
    _emitProgress(RussiaRouteUpdateStage.extractingPackage);
    final extracted = _extractRequiredRuleSetsFromZip(bytes);
    await _writeRoutePackage(paths, extracted);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    return _InstalledRoutePackageInfo(
      sourceKind: sourceKindLive,
      versionTag: release.tagName,
      releaseTag: release.tagName,
      packageSha256: crypto.sha256.convert(bytes).toString(),
      assetSizeBytes: release.assetSizeBytes ?? bytes.length,
      verifiedAtMillis: nowMillis,
      lastUpdateCheckAtMillis: nowMillis,
      verifiedFiles: extracted.keys.toList()..sort(),
    );
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
    await _writeRoutePackage(paths, files);
    return _InstalledRoutePackageInfo(
      sourceKind: sourceKindBundled,
      versionTag: bundledTag,
      releaseTag: bundledTag,
      verifiedAtMillis: checkedAtMillis,
      lastUpdateCheckAtMillis: checkedAtMillis,
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
    final client = HttpClient();
    client.connectionTimeout = _connectTimeout;
    client.idleTimeout = _responseTimeout;
    try {
      final request = await awaitRemoteDownload(
        client.getUrl(uri),
        uri: uri,
        phase: RemoteDownloadTimeoutPhase.connecting,
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'EtonifyRouteData/1');
      request.headers.set(HttpHeaders.acceptHeader, accept);
      final response = await awaitRemoteDownload(
        request.close(),
        uri: uri,
        phase: RemoteDownloadTimeoutPhase.awaitingResponse,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Failed to download route data: HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      final builder = BytesBuilder(copy: false);
      var length = 0;
      final total = response.contentLength > 0
          ? response.contentLength
          : expectedBytes ?? 0;
      await for (final chunk in limitRemoteDownloadIdle(response, uri: uri)) {
        length += chunk.length;
        if (length > maxBytes) {
          throw HttpException('Route data download is too large', uri: uri);
        }
        builder.add(chunk);
        onProgress?.call(length, total);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  Map<String, Uint8List> _extractRequiredRuleSetsFromZip(Uint8List zipBytes) {
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

  int _findZipEndOfCentralDirectory(Uint8List bytes) {
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

  Uint8List _readZipEntry(
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
    _RussiaRouteStoragePaths paths,
    Map<String, Uint8List> files,
  ) async {
    _validateRoutePackageFiles(files);
    await _writeAtomically(
      paths.geositeRuBlockedPath,
      files['geositeRuBlocked']!,
    );
    await _writeAtomically(
      paths.geositeRuAvailableOnlyInsidePath,
      files['geositeRuAvailableOnlyInside']!,
    );
    await _writeAtomically(
      paths.geositeCategoryRuPath,
      files['geositeCategoryRu']!,
    );
    await _writeAtomically(paths.geoipRuBlockedPath, files['geoipRuBlocked']!);
    await _writeAtomically(
      paths.geoipRuWhitelistPath,
      files['geoipRuWhitelist']!,
    );
    await _writeAtomically(paths.geoipRuPath, files['geoipRu']!);
  }

  void _validateRoutePackageFiles(Map<String, Uint8List> files) {
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
    required String sourceDirectoryPath,
    required Map<String, RussiaRouteCategoryMetadata> previousMetadata,
    required bool force,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = _connectTimeout;
    client.idleTimeout = _responseTimeout;
    final categoryFiles = <String, String>{};
    final metadata = <String, RussiaRouteCategoryMetadata>{};
    final pending = <String>[
      ..._curatedDirectServicesCategories,
      ..._aiServicesCategories,
      ..._socialServicesCategories,
    ];
    var changed = false;
    var completed = 0;
    try {
      _emitProgress(
        RussiaRouteUpdateStage.downloadingCategories,
        completedItems: 0,
        totalItems: pending.length,
      );
      while (pending.isNotEmpty) {
        final category = pending.removeLast();
        if (categoryFiles.containsKey(category)) {
          continue;
        }
        final downloaded = await _downloadDomainListCommunityCategory(
          client,
          category: category,
          sourceDirectoryPath: sourceDirectoryPath,
          previousMetadata: previousMetadata[category],
          force: force,
        );
        final content = downloaded.content;
        categoryFiles[category] = content;
        metadata[category] = downloaded.metadata;
        changed = changed || downloaded.changed;
        completed++;
        for (final include in _extractIncludedCategories(content)) {
          if (!categoryFiles.containsKey(include)) {
            pending.add(include);
          }
        }
        _emitProgress(
          RussiaRouteUpdateStage.downloadingCategories,
          completedItems: completed,
          totalItems: completed + pending.length,
        );
      }
      return _DownloadedDomainListCommunity(
        categoryFiles: categoryFiles,
        metadata: metadata,
        changed: changed,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<_DownloadedCategory> _downloadDomainListCommunityCategory(
    HttpClient client, {
    required String category,
    required String sourceDirectoryPath,
    required RussiaRouteCategoryMetadata? previousMetadata,
    required bool force,
  }) async {
    final uri = Uri.parse('$_domainListCommunityRawBaseUrl/$category');
    final cacheFile = File(
      '$sourceDirectoryPath/${Uri.encodeComponent(category)}.txt',
    );
    final request = await awaitRemoteDownload(
      client.getUrl(uri),
      uri: uri,
      phase: RemoteDownloadTimeoutPhase.connecting,
    );
    request.headers.set(HttpHeaders.acceptHeader, 'text/plain,*/*');
    if (!force && cacheFile.existsSync()) {
      final etag = previousMetadata?.etag;
      if (etag != null && etag.isNotEmpty) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
      }
      final lastModified = previousMetadata?.lastModified;
      if (lastModified != null && lastModified.isNotEmpty) {
        request.headers.set(HttpHeaders.ifModifiedSinceHeader, lastModified);
      }
    }
    final response = await awaitRemoteDownload(
      request.close(),
      uri: uri,
      phase: RemoteDownloadTimeoutPhase.awaitingResponse,
    );
    if (response.statusCode == HttpStatus.notModified &&
        cacheFile.existsSync()) {
      return _DownloadedCategory(
        content: await cacheFile.readAsString(),
        metadata: previousMetadata ?? const RussiaRouteCategoryMetadata(),
        changed: false,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed to download route category: HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in limitRemoteDownloadIdle(response, uri: uri)) {
      length += chunk.length;
      if (length > _maxDomainListCategoryBytes) {
        throw HttpException('Route category is too large', uri: uri);
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    final content = utf8.decode(bytes, allowMalformed: true);
    final previousContent = cacheFile.existsSync()
        ? await cacheFile.readAsString()
        : null;
    final changed = previousContent != content;
    await _writeAtomically(cacheFile.path, utf8.encode(content));
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    return _DownloadedCategory(
      content: content,
      metadata: RussiaRouteCategoryMetadata(
        etag: response.headers.value(HttpHeaders.etagHeader),
        lastModified: response.headers.value(HttpHeaders.lastModifiedHeader),
        updatedAtMillis: changed
            ? nowMillis
            : previousMetadata?.updatedAtMillis ?? nowMillis,
      ),
      changed: changed,
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
      if (backup.existsSync()) {
        await backup.delete();
      }
      if (target.existsSync()) {
        await target.rename(backup.path);
      }
      try {
        await temp.rename(path);
        if (backup.existsSync()) {
          await backup.delete();
        }
      } catch (_) {
        if (!target.existsSync() && backup.existsSync()) {
          await backup.rename(path);
        }
        rethrow;
      }
    }
  }

  Future<_RussiaRouteStoragePaths> _storagePaths() async {
    final baseDirPath = Platform.isAndroid
        ? _androidFilesDirPath()
        : Directory.systemTemp.path;
    final base = Directory('$baseDirPath/route-data/russia-v2ray-rules-dat');
    return _RussiaRouteStoragePaths(
      baseDirectoryPath: base.path,
      geositeRuBlockedPath:
          '${base.path}/rule-set-geosite/geosite-ru-blocked.srs',
      geositeRuAvailableOnlyInsidePath:
          '${base.path}/rule-set-geosite/geosite-ru-available-only-inside.srs',
      geositeCategoryRuPath:
          '${base.path}/rule-set-geosite/geosite-category-ru.srs',
      geoipRuBlockedPath: '${base.path}/rule-set-geoip/geoip-ru-blocked.srs',
      geoipRuWhitelistPath:
          '${base.path}/rule-set-geoip/geoip-ru-whitelist.srs',
      geoipRuPath: '${base.path}/rule-set-geoip/geoip-ru.srs',
      curatedDirectServicesPath:
          '${base.path}/rule-set-geosite/ru-direct-services.srs',
      aiServicesPath: '${base.path}/rule-set-geosite/ai-services.srs',
      socialServicesPath: '${base.path}/rule-set-geosite/social-services.srs',
      domainListCommunitySourceDirectoryPath:
          '${base.path}/domain-list-community',
      metadataPath: '${base.path}/manifest.json',
    );
  }

  String _androidFilesDirPath() {
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
    final path = getAbsolutePath
        .call(filesDir, JString.type, [])
        .toDartString(releaseOriginal: true);

    fileClass.release();
    filesDir.release();
    contextClass.release();
    context.release();

    return path;
  }
}

class _RussiaRouteDataFilePath {
  const _RussiaRouteDataFilePath(this.name, this.path);

  final String name;
  final String path;
}

class _RussiaRouteStoragePaths {
  const _RussiaRouteStoragePaths({
    required this.baseDirectoryPath,
    required this.geositeRuBlockedPath,
    required this.geositeRuAvailableOnlyInsidePath,
    required this.geositeCategoryRuPath,
    required this.geoipRuBlockedPath,
    required this.geoipRuWhitelistPath,
    required this.geoipRuPath,
    required this.curatedDirectServicesPath,
    required this.aiServicesPath,
    required this.socialServicesPath,
    required this.domainListCommunitySourceDirectoryPath,
    required this.metadataPath,
  });

  final String baseDirectoryPath;
  final String geositeRuBlockedPath;
  final String geositeRuAvailableOnlyInsidePath;
  final String geositeCategoryRuPath;
  final String geoipRuBlockedPath;
  final String geoipRuWhitelistPath;
  final String geoipRuPath;
  final String curatedDirectServicesPath;
  final String aiServicesPath;
  final String socialServicesPath;
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
    this.installedAtMillis,
    this.lastUpdateCheckAtMillis,
    this.verifiedFiles = const <String>[],
  });

  final String sourceKind;
  final String versionTag;
  final String? releaseTag;
  final String? packageSha256;
  final int? assetSizeBytes;
  final int? verifiedAtMillis;
  final int? installedAtMillis;
  final int? lastUpdateCheckAtMillis;
  final List<String> verifiedFiles;

  static _InstalledRoutePackageInfo fromStatus(RussiaRouteDataStatus status) {
    return _InstalledRoutePackageInfo(
      sourceKind: status.sourceKind,
      versionTag: status.versionTag,
      releaseTag: status.releaseTag,
      packageSha256: status.packageSha256,
      assetSizeBytes: status.assetSizeBytes,
      verifiedAtMillis: status.verifiedAtMillis,
      installedAtMillis: status.installedAtMillis,
      lastUpdateCheckAtMillis: status.lastUpdateCheckAtMillis,
      verifiedFiles: status.verifiedFiles,
    );
  }

  _InstalledRoutePackageInfo copyWith({
    String? sourceKind,
    String? versionTag,
    String? releaseTag,
    String? packageSha256,
    int? assetSizeBytes,
    int? verifiedAtMillis,
    int? installedAtMillis,
    int? lastUpdateCheckAtMillis,
    List<String>? verifiedFiles,
  }) {
    return _InstalledRoutePackageInfo(
      sourceKind: sourceKind ?? this.sourceKind,
      versionTag: versionTag ?? this.versionTag,
      releaseTag: releaseTag ?? this.releaseTag,
      packageSha256: packageSha256 ?? this.packageSha256,
      assetSizeBytes: assetSizeBytes ?? this.assetSizeBytes,
      verifiedAtMillis: verifiedAtMillis ?? this.verifiedAtMillis,
      installedAtMillis: installedAtMillis ?? this.installedAtMillis,
      lastUpdateCheckAtMillis:
          lastUpdateCheckAtMillis ?? this.lastUpdateCheckAtMillis,
      verifiedFiles: verifiedFiles ?? this.verifiedFiles,
    );
  }
}

class _DownloadedDomainListCommunity {
  const _DownloadedDomainListCommunity({
    required this.categoryFiles,
    required this.metadata,
    required this.changed,
  });

  final Map<String, String> categoryFiles;
  final Map<String, RussiaRouteCategoryMetadata> metadata;
  final bool changed;
}

class _DownloadedCategory {
  const _DownloadedCategory({
    required this.content,
    required this.metadata,
    required this.changed,
  });

  final String content;
  final RussiaRouteCategoryMetadata metadata;
  final bool changed;
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
    RussiaRouteDataService._socialServicesCategories,
  );
}

_CompiledRuleSetArtifact _compileDomainListCommunityArtifact(
  Map<String, String> categoryFiles,
  List<String> rootCategories,
) {
  final exactDomains = <String>{};
  final suffixDomains = <String>{};
  final visiting = <String>{};
  final visited = <String>{};

  void loadCategory(String category) {
    if (!visiting.add(category) || visited.contains(category)) {
      return;
    }
    final content = categoryFiles[category];
    if (content == null) {
      visiting.remove(category);
      return;
    }
    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.split('#').first.trim();
      if (line.isEmpty || line.contains('@ads') || line.contains('@!cn')) {
        continue;
      }
      if (line.startsWith('include:')) {
        loadCategory(_parseIncludedCategory(line));
        continue;
      }
      if (line.startsWith('regexp:') ||
          line.startsWith('keyword:') ||
          line.startsWith('geosite:') ||
          line.startsWith('ext:')) {
        continue;
      }
      final normalized = _normalizeServiceDomainLine(line);
      if (normalized == null) {
        continue;
      }
      switch (normalized.type) {
        case _RuleDomainType.exact:
          exactDomains.add(normalized.value);
        case _RuleDomainType.suffix:
          suffixDomains.add(normalized.value);
      }
    }
    visiting.remove(category);
    visited.add(category);
  }

  for (final category in rootCategories) {
    loadCategory(category);
  }

  final exactList = exactDomains.toList()..sort();
  final suffixList = suffixDomains.toList()..sort();
  return _CompiledRuleSetArtifact(
    ruleSetBytes: _buildSrsRuleSet(
      domains: exactList,
      domainSuffixes: suffixList,
    ),
    domainCount: exactList.length + suffixList.length,
  );
}

String _parseIncludedCategory(String line) {
  final include = line.substring('include:'.length).trim();
  final separator = include.indexOf(RegExp(r'\s'));
  return separator < 0 ? include : include.substring(0, separator);
}

_NormalizedRuleDomain? _normalizeServiceDomainLine(String line) {
  var value = line.trim();
  if (value.isEmpty) {
    return null;
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
        : _NormalizedRuleDomain(_RuleDomainType.exact, normalized);
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
      !RegExp(r'^[a-z0-9.\-_]+$').hasMatch(normalized)) {
    return null;
  }
  return normalized;
}

Uint8List _buildSrsRuleSet({
  required List<String> domains,
  required List<String> domainSuffixes,
}) {
  final body = _ByteAccumulator();
  _writeUvarint(
    body,
    (domains.isNotEmpty || domainSuffixes.isNotEmpty) ? 1 : 0,
  );
  if (domains.isNotEmpty || domainSuffixes.isNotEmpty) {
    _writeDefaultDomainRule(
      body,
      domains: domains,
      domainSuffixes: domainSuffixes,
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
}) {
  writer.writeByte(0);
  writer.writeByte(_ruleItemDomain);
  _buildDomainMatcher(
    domains: domains,
    domainSuffixes: domainSuffixes,
  ).writeTo(writer);
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

enum _RuleDomainType { exact, suffix }

const List<int> _srsMagicBytes = <int>[0x53, 0x52, 0x53];
const int _srsVersion2 = 2;
const int _ruleItemDomain = 2;
const int _ruleItemFinal = 0xFF;
const String _rootLabelMarker = '\n';
