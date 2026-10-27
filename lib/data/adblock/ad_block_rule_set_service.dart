import 'dart:convert';
import 'dart:io';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:meow_client/core/network/vpn_aware_remote_download.dart';
import 'package:meow_client/core/platform/android_files_dir.dart';

enum AdBlockUpdateStage {
  connecting,
  retryingWithoutVpn,
  downloading,
  compiling,
  activating,
  complete,
}

class AdBlockUpdateProgress {
  const AdBlockUpdateProgress({
    required this.stage,
    this.completedBytes = 0,
    this.totalBytes = 0,
    this.elapsedMilliseconds = 0,
  });

  final AdBlockUpdateStage stage;
  final int completedBytes;
  final int totalBytes;
  final int elapsedMilliseconds;

  double? get fraction => totalBytes > 0
      ? (completedBytes / totalBytes).clamp(0, 1).toDouble()
      : null;

  int? get estimatedSecondsRemaining {
    if (totalBytes <= 0 ||
        completedBytes <= 0 ||
        completedBytes >= totalBytes ||
        elapsedMilliseconds <= 0) {
      return null;
    }
    final bytesPerMillisecond = completedBytes / elapsedMilliseconds;
    if (!bytesPerMillisecond.isFinite || bytesPerMillisecond <= 0) {
      return null;
    }
    return ((totalBytes - completedBytes) / bytesPerMillisecond / 1000).ceil();
  }
}

class AdBlockRuleSetStatus {
  const AdBlockRuleSetStatus({
    required this.available,
    required this.providerName,
    required this.sourceUrl,
    this.blockRuleSetPath,
    this.allowRuleSetPath,
    this.downloadedAtMillis,
    this.blockedDomainCount = 0,
    this.allowedDomainCount = 0,
    this.sourceBytes = 0,
    this.ruleSetBytes = 0,
  });

  const AdBlockRuleSetStatus.unavailable()
    : available = false,
      providerName = AdBlockRuleSetService.providerName,
      sourceUrl = AdBlockRuleSetService.sourceUrl,
      blockRuleSetPath = null,
      allowRuleSetPath = null,
      downloadedAtMillis = null,
      blockedDomainCount = 0,
      allowedDomainCount = 0,
      sourceBytes = 0,
      ruleSetBytes = 0;

  final bool available;
  final String providerName;
  final String sourceUrl;
  final String? blockRuleSetPath;
  final String? allowRuleSetPath;
  final int? downloadedAtMillis;
  final int blockedDomainCount;
  final int allowedDomainCount;
  final int sourceBytes;
  final int ruleSetBytes;

  DateTime? get downloadedAt => downloadedAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(downloadedAtMillis!);
}

class AdBlockRuleSetService {
  AdBlockRuleSetService._();

  static final AdBlockRuleSetService instance = AdBlockRuleSetService._();

  static const providerName = 'AdGuard DNS Filter';
  static const sourceUrl =
      'https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt';
  static const _maxSourceBytes = 16 * 1024 * 1024;

  Future<AdBlockRuleSetStatus>? _downloadInFlight;
  Future<void> _mutationTail = Future.value();
  Future<void>? _generationCleanupInFlight;
  int _generationSequence = 0;
  final ValueNotifier<AdBlockUpdateProgress?> progress = ValueNotifier(null);

  bool get isUpdating => _downloadInFlight != null;
  Future<void>? get generationCleanupInFlight => _generationCleanupInFlight;

  void _emitProgress(
    AdBlockUpdateStage stage, {
    int completedBytes = 0,
    int totalBytes = 0,
    int elapsedMilliseconds = 0,
  }) {
    progress.value = AdBlockUpdateProgress(
      stage: stage,
      completedBytes: completedBytes,
      totalBytes: totalBytes,
      elapsedMilliseconds: elapsedMilliseconds,
    );
  }

  Future<AdBlockRuleSetStatus> loadStatus() async {
    final paths = await _storagePaths();
    final installed = await _loadInstallation(paths);
    return installed?.status ?? const AdBlockRuleSetStatus.unavailable();
  }

  Future<_InstalledAdBlock?> _loadInstallation(_AdBlockStoragePaths paths) =>
      Isolate.run(
        () =>
            _readAdBlockInstallation(paths, paths.metadataPath) ??
            _readAdBlockInstallation(paths, paths.previousMetadataPath),
      );

  Future<T> _mutate<T>(Future<T> Function() action) {
    final future = _mutationTail.then((_) => action());
    _mutationTail = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return future;
  }

  Future<AdBlockRuleSetStatus> downloadLatest() async {
    final inFlight = _downloadInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _mutate(_downloadLatest);
    _downloadInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_downloadInFlight, future)) {
        _downloadInFlight = null;
        progress.value = null;
      }
    }
  }

  Future<AdBlockRuleSetStatus> _downloadLatest() async {
    final paths = await _storagePaths();
    await Directory(paths.directoryPath).create(recursive: true);
    final previous = await _loadInstallation(paths);

    final stopwatch = Stopwatch()..start();
    _emitProgress(AdBlockUpdateStage.connecting);
    final sourceBytes = await _downloadSourceBytes(stopwatch);
    _emitProgress(
      AdBlockUpdateStage.compiling,
      completedBytes: sourceBytes.length,
      totalBytes: sourceBytes.length,
      elapsedMilliseconds: stopwatch.elapsedMilliseconds,
    );
    final compiled = await Isolate.run(
      () => _compileAdBlockArtifacts(Uint8List.fromList(sourceBytes)),
    );
    final blockBytes = compiled['blockBytes']! as Uint8List;
    final allowBytes = compiled['allowBytes'] as Uint8List?;
    final blockedDomainCount = compiled['blockedDomainCount']! as int;
    final allowedDomainCount = compiled['allowedDomainCount']! as int;
    final downloadedAtMillis = DateTime.now().millisecondsSinceEpoch;

    _emitProgress(
      AdBlockUpdateStage.activating,
      completedBytes: sourceBytes.length,
      totalBytes: sourceBytes.length,
      elapsedMilliseconds: stopwatch.elapsedMilliseconds,
    );
    final generation =
        'generation-${DateTime.now().microsecondsSinceEpoch}-${_generationSequence++}';
    final generationDirectory = Directory('${paths.directoryPath}/$generation');
    final blockPath = '${generationDirectory.path}/adguard_dns_block.srs';
    final allowPath = '${generationDirectory.path}/adguard_dns_allow.srs';
    final metadata = <String, Object?>{
      'formatVersion': 2,
      'generation': generation,
      'providerName': providerName,
      'sourceUrl': sourceUrl,
      'downloadedAtMillis': downloadedAtMillis,
      'blockedDomainCount': blockedDomainCount,
      'allowedDomainCount': allowedDomainCount,
      'sourceBytes': sourceBytes.length,
      'ruleSetBytes': blockBytes.length + (allowBytes?.length ?? 0),
      'blockSha256': crypto.sha256.convert(blockBytes).toString(),
      if (allowBytes != null)
        'allowSha256': crypto.sha256.convert(allowBytes).toString(),
    };
    var published = false;
    try {
      await _writeAtomically(blockPath, blockBytes);
      if (allowBytes != null) await _writeAtomically(allowPath, allowBytes);
      if (previous != null) {
        await _writeAtomically(
          paths.previousMetadataPath,
          utf8.encode(jsonEncode(previous.metadata)),
        );
      }
      await _writeAtomically(
        paths.metadataPath,
        utf8.encode(jsonEncode(metadata)),
      );
      published = true;
    } finally {
      if (!published && await generationDirectory.exists()) {
        await generationDirectory.delete(recursive: true);
      }
    }

    _emitProgress(
      AdBlockUpdateStage.complete,
      completedBytes: sourceBytes.length,
      totalBytes: sourceBytes.length,
      elapsedMilliseconds: stopwatch.elapsedMilliseconds,
    );

    return AdBlockRuleSetStatus(
      available: true,
      providerName: providerName,
      sourceUrl: sourceUrl,
      blockRuleSetPath: blockPath,
      allowRuleSetPath: allowBytes == null ? null : allowPath,
      downloadedAtMillis: downloadedAtMillis,
      blockedDomainCount: blockedDomainCount,
      allowedDomainCount: allowedDomainCount,
      sourceBytes: sourceBytes.length,
      ruleSetBytes: blockBytes.length + (allowBytes?.length ?? 0),
    );
  }

  Future<AdBlockRuleSetStatus> deleteRuleSet() => _mutate(() async {
    final paths = await _storagePaths();
    final disabled = utf8.encode(
      jsonEncode({'formatVersion': 2, 'disabled': true}),
    );
    await _writeAtomically(paths.previousMetadataPath, disabled);
    await _writeAtomically(paths.metadataPath, disabled);
    return const AdBlockRuleSetStatus.unavailable();
  });

  Future<void> cleanupSupersededGenerations({
    required Iterable<String> protectedRuleSetPaths,
  }) {
    if (isUpdating) return Future.value();
    final protected = protectedRuleSetPaths.toSet();
    final future = _mutate(() async {
      final paths = await _storagePaths();
      await _cleanupAdBlockGenerationsInBackground(paths, protected);
    });
    _generationCleanupInFlight = future;
    return future.whenComplete(() {
      if (identical(_generationCleanupInFlight, future)) {
        _generationCleanupInFlight = null;
      }
    });
  }

  Future<List<int>> _downloadSourceBytes(Stopwatch stopwatch) async {
    final uri = Uri.parse(sourceUrl);
    var lastProgressAt = -1;
    _emitProgress(
      AdBlockUpdateStage.downloading,
      elapsedMilliseconds: stopwatch.elapsedMilliseconds,
    );
    final result = await VpnAwareRemoteDownloader.instance.fetchBytes(
      uri: uri,
      maximumBytes: _maxSourceBytes,
      headers: const <String, String>{'Accept': 'text/plain,*/*'},
      onRouteAttempt: (route, isFallback) {
        if (isFallback && route == RemoteDownloadRoute.underlying) {
          _emitProgress(
            AdBlockUpdateStage.retryingWithoutVpn,
            elapsedMilliseconds: stopwatch.elapsedMilliseconds,
          );
        }
      },
      onProgress: (completed, total) {
        final elapsed = stopwatch.elapsedMilliseconds;
        if (elapsed - lastProgressAt < 250 &&
            (total <= 0 || completed < total)) {
          return;
        }
        lastProgressAt = elapsed;
        _emitProgress(
          AdBlockUpdateStage.downloading,
          completedBytes: completed,
          totalBytes: total,
          elapsedMilliseconds: elapsed,
        );
      },
    );
    final bytes = result.bytes ?? Uint8List(0);
    _emitProgress(
      AdBlockUpdateStage.downloading,
      completedBytes: bytes.length,
      totalBytes: bytes.length,
      elapsedMilliseconds: stopwatch.elapsedMilliseconds,
    );
    return bytes;
  }

  Future<void> _writeAtomically(String path, List<int> bytes) async {
    final target = File(path);
    await target.parent.create(recursive: true);
    final temp = File('$path.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<_AdBlockStoragePaths> _storagePaths() async {
    final baseDirPath = Platform.isAndroid
        ? await AndroidFilesDir.ensureInitialized()
        : Platform.isWindows
        ? AppDataPaths.current.ruleSetRoot
        : Directory.systemTemp.path;
    final base = Directory('$baseDirPath/adblock');
    return _AdBlockStoragePaths(
      directoryPath: base.path,
      blockRuleSetPath: '${base.path}/adguard_dns_block.srs',
      allowRuleSetPath: '${base.path}/adguard_dns_allow.srs',
      metadataPath: '${base.path}/adguard_dns_meta.json',
    );
  }
}

class _AdBlockStoragePaths {
  const _AdBlockStoragePaths({
    required this.directoryPath,
    required this.blockRuleSetPath,
    required this.allowRuleSetPath,
    required this.metadataPath,
  });

  final String directoryPath;
  final String blockRuleSetPath;
  final String allowRuleSetPath;
  final String metadataPath;
  String get previousMetadataPath =>
      '$directoryPath/adguard_dns_meta.previous.json';
}

class _InstalledAdBlock {
  const _InstalledAdBlock(this.metadata, this.status);
  final Map<String, dynamic> metadata;
  final AdBlockRuleSetStatus status;
}

_InstalledAdBlock? _readAdBlockInstallation(
  _AdBlockStoragePaths paths,
  String manifestPath,
) {
  try {
    final file = File(manifestPath);
    if (!file.existsSync() || file.lengthSync() > 64 * 1024) return null;
    final metadata =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final formatVersion = metadata['formatVersion'];
    if (formatVersion != null && formatVersion != 2) return null;
    if (metadata['disabled'] == true) {
      return _InstalledAdBlock(
        metadata,
        const AdBlockRuleSetStatus.unavailable(),
      );
    }
    final generation = metadata['generation'];
    if (formatVersion == 2) {
      if (generation is! String) return null;
      for (final key in [
        'blockedDomainCount',
        'allowedDomainCount',
        'sourceBytes',
        'ruleSetBytes',
        'downloadedAtMillis',
      ]) {
        final value = metadata[key];
        if (value is! int || value < 0) return null;
      }
      if (!_isAdBlockHash(metadata['blockSha256'])) return null;
      if ((metadata['allowedDomainCount'] as int) > 0) {
        if (!_isAdBlockHash(metadata['allowSha256'])) return null;
      } else if (metadata['allowSha256'] != null) {
        return null;
      }
    } else if (generation != null) {
      return null;
    }
    if (generation != null &&
        (generation is! String ||
            !_adBlockGenerationPattern.hasMatch(generation))) {
      return null;
    }
    final base = generation == null
        ? paths.directoryPath
        : '${paths.directoryPath}/$generation';
    final block = File('$base/adguard_dns_block.srs');
    final allow = File('$base/adguard_dns_allow.srs');
    final allowCount =
        int.tryParse(metadata['allowedDomainCount']?.toString() ?? '') ?? 0;
    bool valid(File ruleSet, Object? expectedHash) {
      if (!ruleSet.existsSync() || ruleSet.lengthSync() > 32 * 1024 * 1024) {
        return false;
      }
      final bytes = ruleSet.readAsBytesSync();
      if (bytes.length < 6 ||
          bytes[0] != 0x53 ||
          bytes[1] != 0x52 ||
          bytes[2] != 0x53 ||
          bytes[3] != 2) {
        return false;
      }
      if (generation != null && expectedHash is! String) return false;
      return expectedHash == null ||
          crypto.sha256.convert(bytes).toString() == expectedHash;
    }

    if (!valid(block, metadata['blockSha256']) ||
        (allowCount > 0 && !valid(allow, metadata['allowSha256']))) {
      return null;
    }
    return _InstalledAdBlock(
      metadata,
      AdBlockRuleSetStatus(
        available: true,
        providerName:
            metadata['providerName']?.toString() ??
            AdBlockRuleSetService.providerName,
        sourceUrl:
            metadata['sourceUrl']?.toString() ??
            AdBlockRuleSetService.sourceUrl,
        blockRuleSetPath: block.path,
        allowRuleSetPath: allowCount > 0 ? allow.path : null,
        downloadedAtMillis: int.tryParse(
          metadata['downloadedAtMillis']?.toString() ?? '',
        ),
        blockedDomainCount:
            int.tryParse(metadata['blockedDomainCount']?.toString() ?? '') ?? 0,
        allowedDomainCount: allowCount,
        sourceBytes:
            int.tryParse(metadata['sourceBytes']?.toString() ?? '') ?? 0,
        ruleSetBytes:
            int.tryParse(metadata['ruleSetBytes']?.toString() ?? '') ?? 0,
      ),
    );
  } catch (_) {
    return null;
  }
}

final _adBlockGenerationPattern = RegExp(r'^generation-\d+-\d+$');
final _adBlockHashPattern = RegExp(r'^[a-f0-9]{64}$');
bool _isAdBlockHash(Object? value) =>
    value is String && _adBlockHashPattern.hasMatch(value);

Future<void> _cleanupAdBlockGenerationsInBackground(
  _AdBlockStoragePaths paths,
  Set<String> protectedPaths,
) => Isolate.run(() => _cleanupAdBlockGenerations(paths, protectedPaths));

void _cleanupAdBlockGenerations(
  _AdBlockStoragePaths paths,
  Set<String> protectedPaths,
) {
  final current = _readAdBlockInstallation(paths, paths.metadataPath);
  if (current == null) return;
  final previous = _readAdBlockInstallation(paths, paths.previousMetadataPath);
  if (File(paths.previousMetadataPath).existsSync() && previous == null) return;
  String normalize(String value) {
    final normalized = Directory(
      value,
    ).absolute.uri.normalizePath().toFilePath();
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  final retained = <String>{
    if (current.metadata['generation'] case final String generation)
      normalize('${paths.directoryPath}/$generation'),
    if (previous?.metadata['generation'] case final String generation)
      normalize('${paths.directoryPath}/$generation'),
    for (final file in protectedPaths) normalize(File(file).parent.path),
  };
  final root = Directory(paths.directoryPath);
  if (!root.existsSync()) return;
  for (final entry in root.listSync(followLinks: false)) {
    if (entry is! Directory ||
        !_adBlockGenerationPattern.hasMatch(
          entry.uri.pathSegments.where((part) => part.isNotEmpty).last,
        )) {
      continue;
    }
    if (retained.contains(normalize(entry.path))) continue;
    entry.deleteSync(recursive: true);
  }
}

Map<String, Object?> _compileAdBlockArtifacts(Uint8List sourceBytes) {
  final content = utf8.decode(sourceBytes).replaceFirst('\ufeff', '').trim();
  if (content.isEmpty || content.startsWith('<')) {
    throw const FormatException('AdBlock download is not a filter list');
  }
  final parsed = _parseAdBlockFilter(content);
  if (parsed.recognizedRuleCount == 0) {
    throw const FormatException(
      'AdBlock list contains no supported domain rules',
    );
  }
  final blocked = {...parsed.blockedDomains, ...parsed.importantBlockedDomains};
  final allowed = {...parsed.allowedDomains, ...parsed.importantAllowedDomains};
  final blockBytes = _buildSrsRuleSet(_sortedDomains(blocked));
  final allowBytes = allowed.isEmpty ? null : _buildAllowRuleSet(parsed);
  return {
    'blockBytes': blockBytes,
    'allowBytes': allowBytes,
    'blockedDomainCount': blocked.length,
    'allowedDomainCount': allowed.length,
  };
}

Uint8List _buildSrsRuleSet(List<_AdBlockDomain> domains) {
  final body = _ByteAccumulator();
  _writeUvarint(body, domains.isEmpty ? 0 : 1);
  if (domains.isNotEmpty) {
    _writeDomainRule(body, domains);
  }
  return _wrapSrsBody(body);
}

Uint8List _buildAllowRuleSet(_ParsedAdBlockFilter parsed) {
  if (parsed.importantBlockedDomains.isEmpty) {
    return _buildSrsRuleSet(
      _sortedDomains({
        ...parsed.allowedDomains,
        ...parsed.importantAllowedDomains,
      }),
    );
  }
  final body = _ByteAccumulator();
  _writeUvarint(
    body,
    (parsed.allowedDomains.isEmpty ? 0 : 1) +
        (parsed.importantAllowedDomains.isEmpty ? 0 : 1),
  );
  if (parsed.allowedDomains.isNotEmpty) {
    body.writeByte(1);
    body.writeByte(0);
    _writeUvarint(body, 2);
    _writeDomainRule(body, parsed.allowedDomains);
    _writeDomainRule(body, parsed.importantBlockedDomains, invert: true);
    body.writeByte(0);
  }
  if (parsed.importantAllowedDomains.isNotEmpty) {
    _writeDomainRule(body, parsed.importantAllowedDomains);
  }
  return _wrapSrsBody(body);
}

Uint8List _wrapSrsBody(_ByteAccumulator body) {
  final compressedBody = Uint8List.fromList(
    ZLibEncoder(level: 9).convert(body.toBytes()),
  );
  final result = _ByteAccumulator();
  result.writeBytes(_srsMagicBytes);
  result.writeByte(_srsVersion2);
  result.writeBytes(compressedBody);
  return result.toBytes();
}

void _writeDomainRule(
  _ByteAccumulator writer,
  List<_AdBlockDomain> domains, {
  bool invert = false,
}) {
  writer.writeByte(0);
  writer.writeByte(_ruleItemDomain);
  _buildDomainMatcher(domains).writeTo(writer);
  writer.writeByte(_ruleItemFinal);
  writer.writeByte(invert ? 1 : 0);
}

_ParsedAdBlockFilter _parseAdBlockFilter(String content) {
  final blocked = <_AdBlockDomain>{};
  final allowed = <_AdBlockDomain>{};
  final importantBlocked = <_AdBlockDomain>{};
  final importantAllowed = <_AdBlockDomain>{};
  final rules = <({String pattern, Set<String> modifiers, bool allow})>[];
  final disabledRules = <String>{};
  var recognizedRuleCount = 0;
  for (final rawLine in const LineSplitter().convert(
    content.replaceFirst('\ufeff', ''),
  )) {
    final line = rawLine.trim();
    if (line.isEmpty ||
        line.startsWith('!') ||
        line.startsWith('#') ||
        line.startsWith('[')) {
      continue;
    }
    final modifierIndex = line.indexOf(r'$');
    final pattern = modifierIndex < 0 ? line : line.substring(0, modifierIndex);
    final modifiers = modifierIndex < 0
        ? <String>{}
        : line.substring(modifierIndex + 1).split(',').toSet();
    if (modifiers.remove('badfilter')) {
      if (!RegExp(
        r'^(?:0\.0\.0\.0|127\.0\.0\.1|::|::1)\s+',
      ).hasMatch(pattern)) {
        disabledRules.add(_adBlockRuleKey(pattern, modifiers));
      }
      continue;
    }
    rules.add((
      pattern: pattern,
      modifiers: modifiers,
      allow: line.startsWith('@@'),
    ));
  }
  for (final rule in rules) {
    if (rule.modifiers.any((modifier) => modifier != 'important')) {
      continue;
    }
    final domain = _extractDomain(rule.pattern);
    if (domain == null) {
      continue;
    }
    recognizedRuleCount++;
    if (disabledRules.contains(_adBlockRuleKey(rule.pattern, rule.modifiers))) {
      continue;
    }
    if (rule.modifiers.contains('important')) {
      (rule.allow ? importantAllowed : importantBlocked).add(domain);
    } else {
      (rule.allow ? allowed : blocked).add(domain);
    }
  }
  blocked.removeAll(allowed);
  blocked.removeAll(importantAllowed);
  importantBlocked.removeAll(importantAllowed);
  return _ParsedAdBlockFilter(
    blockedDomains: _sortedDomains(blocked),
    allowedDomains: _sortedDomains(allowed),
    importantBlockedDomains: _sortedDomains(importantBlocked),
    importantAllowedDomains: _sortedDomains(importantAllowed),
    recognizedRuleCount: recognizedRuleCount,
  );
}

String _adBlockRuleKey(String pattern, Set<String> modifiers) {
  final sorted = modifiers.toList()..sort();
  return '$pattern\$${sorted.join(',')}';
}

List<_AdBlockDomain> _sortedDomains(Iterable<_AdBlockDomain> domains) =>
    domains.toSet().toList()..sort((a, b) {
      final order = a.name.compareTo(b.name);
      return order != 0
          ? order
          : (a.suffix ? 1 : 0).compareTo(b.suffix ? 1 : 0);
    });

_AdBlockDomain? _extractDomain(String line) {
  var value = line.trim();
  if (value.startsWith('@@')) {
    value = value.substring(2);
  }
  if (value.startsWith('/') ||
      value.contains('##') ||
      value.contains('#@#') ||
      value.contains('#?#')) {
    return null;
  }

  final hostsMatch = RegExp(
    r'^(?:0\.0\.0\.0|127\.0\.0\.1|::|::1)\s+([A-Za-z0-9.\-_]+)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (hostsMatch != null) {
    final domain = _normalizeDomain(hostsMatch.group(1)!);
    return domain == null ? null : (name: domain, suffix: false);
  }
  final suffix = value.startsWith('||') && value.endsWith('^');
  if (suffix) {
    value = value.substring(2, value.length - 1);
  } else if (value.startsWith('|') &&
      value.endsWith('|') &&
      !value.startsWith('||')) {
    value = value.substring(1, value.length - 1);
  }
  final domain = _normalizeDomain(value);
  return domain == null ? null : (name: domain, suffix: suffix);
}

String? _normalizeDomain(String value) {
  var domain = value.trim().toLowerCase();
  if (domain.isEmpty) {
    return null;
  }
  while (domain.startsWith('.')) {
    domain = domain.substring(1);
  }
  while (domain.endsWith('.')) {
    domain = domain.substring(0, domain.length - 1);
  }
  if (domain.isEmpty ||
      !domain.contains('.') ||
      domain.contains('..') ||
      domain.contains(':') ||
      RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(domain) ||
      !RegExp(r'^[a-z0-9.\-]+$').hasMatch(domain)) {
    return null;
  }
  for (final label in domain.split('.')) {
    if (label.isEmpty ||
        label.length > 63 ||
        label.startsWith('-') ||
        label.endsWith('-')) {
      return null;
    }
  }
  return domain;
}

class _ParsedAdBlockFilter {
  const _ParsedAdBlockFilter({
    required this.blockedDomains,
    required this.allowedDomains,
    required this.importantBlockedDomains,
    required this.importantAllowedDomains,
    required this.recognizedRuleCount,
  });

  final List<_AdBlockDomain> blockedDomains;
  final List<_AdBlockDomain> allowedDomains;
  final List<_AdBlockDomain> importantBlockedDomains;
  final List<_AdBlockDomain> importantAllowedDomains;
  final int recognizedRuleCount;
}

typedef _AdBlockDomain = ({String name, bool suffix});

const List<int> _srsMagicBytes = <int>[0x53, 0x52, 0x53];
const int _srsVersion2 = 2;
const int _ruleItemDomain = 2;
const int _ruleItemFinal = 0xFF;
_DomainMatcher _buildDomainMatcher(List<_AdBlockDomain> domains) {
  final domainList = <String>[];
  final seen = <_AdBlockDomain>{};
  for (final domain in domains) {
    if (!seen.add(domain)) {
      continue;
    }
    domainList.add(
      _reverseAscii('${domain.suffix ? _rootLabelMarker : ''}${domain.name}'),
    );
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
  final codes = value.codeUnits.reversed.toList(growable: false);
  return String.fromCharCodes(codes);
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

  void writeByte(int value) {
    _builder.addByte(value & 0xFF);
  }

  void writeBytes(List<int> values) {
    if (values.isEmpty) {
      return;
    }
    _builder.add(values);
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

class _DomainMatcher {
  const _DomainMatcher(this.set);

  final _SuccinctSet set;

  void writeTo(_ByteAccumulator writer) {
    set.writeTo(writer);
  }
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

const String _rootLabelMarker = '\n';
