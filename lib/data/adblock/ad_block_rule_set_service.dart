import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

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
  final ValueNotifier<AdBlockUpdateProgress?> progress = ValueNotifier(null);

  bool get isUpdating => _downloadInFlight != null;

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
    final metadataFile = File(paths.metadataPath);
    final blockFile = File(paths.blockRuleSetPath);
    final allowFile = File(paths.allowRuleSetPath);
    if (!metadataFile.existsSync() || !blockFile.existsSync()) {
      return const AdBlockRuleSetStatus.unavailable();
    }
    try {
      final metadata =
          jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
      return AdBlockRuleSetStatus(
        available: true,
        providerName: metadata['providerName']?.toString() ?? providerName,
        sourceUrl: metadata['sourceUrl']?.toString() ?? sourceUrl,
        blockRuleSetPath: blockFile.path,
        allowRuleSetPath: allowFile.existsSync() ? allowFile.path : null,
        downloadedAtMillis: int.tryParse(
          metadata['downloadedAtMillis']?.toString() ?? '',
        ),
        blockedDomainCount:
            int.tryParse(metadata['blockedDomainCount']?.toString() ?? '') ?? 0,
        allowedDomainCount:
            int.tryParse(metadata['allowedDomainCount']?.toString() ?? '') ?? 0,
        sourceBytes:
            int.tryParse(metadata['sourceBytes']?.toString() ?? '') ?? 0,
        ruleSetBytes:
            int.tryParse(metadata['ruleSetBytes']?.toString() ?? '') ?? 0,
      );
    } catch (_) {
      return const AdBlockRuleSetStatus.unavailable();
    }
  }

  Future<AdBlockRuleSetStatus> downloadLatest() async {
    final inFlight = _downloadInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _downloadLatest();
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
    await _writeAtomically(paths.blockRuleSetPath, blockBytes);
    if (allowBytes != null) {
      await _writeAtomically(paths.allowRuleSetPath, allowBytes);
    } else {
      final allowFile = File(paths.allowRuleSetPath);
      if (allowFile.existsSync()) {
        await allowFile.delete();
      }
    }
    await _writeAtomically(
      paths.metadataPath,
      utf8.encode(
        jsonEncode({
          'providerName': providerName,
          'sourceUrl': sourceUrl,
          'downloadedAtMillis': downloadedAtMillis,
          'blockedDomainCount': blockedDomainCount,
          'allowedDomainCount': allowedDomainCount,
          'sourceBytes': sourceBytes.length,
          'ruleSetBytes': blockBytes.length + (allowBytes?.length ?? 0),
        }),
      ),
    );

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
      blockRuleSetPath: paths.blockRuleSetPath,
      allowRuleSetPath: paths.allowRuleSetPath,
      downloadedAtMillis: downloadedAtMillis,
      blockedDomainCount: blockedDomainCount,
      allowedDomainCount: allowedDomainCount,
      sourceBytes: sourceBytes.length,
      ruleSetBytes: blockBytes.length + (allowBytes?.length ?? 0),
    );
  }

  Future<AdBlockRuleSetStatus> deleteRuleSet() async {
    final paths = await _storagePaths();
    for (final path in [
      paths.blockRuleSetPath,
      paths.allowRuleSetPath,
      paths.metadataPath,
    ]) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    return const AdBlockRuleSetStatus.unavailable();
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
    await temp.writeAsBytes(bytes, flush: true);
    try {
      await temp.rename(path);
      return;
    } on FileSystemException {
      await temp.copy(path);
      await temp.delete();
    }
  }

  Future<_AdBlockStoragePaths> _storagePaths() async {
    final baseDirPath = Platform.isAndroid
        ? await AndroidFilesDir.ensureInitialized()
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
}

Map<String, Object?> _compileAdBlockArtifacts(Uint8List sourceBytes) {
  final parsed = _parseAdBlockFilter(
    utf8.decode(sourceBytes, allowMalformed: true),
  );
  final blockBytes = _buildSrsRuleSet(parsed.blockedDomains);
  final allowBytes = parsed.allowedDomains.isEmpty
      ? null
      : _buildSrsRuleSet(parsed.allowedDomains);
  return {
    'blockBytes': blockBytes,
    'allowBytes': allowBytes,
    'blockedDomainCount': parsed.blockedDomains.length,
    'allowedDomainCount': parsed.allowedDomains.length,
  };
}

Uint8List _buildSrsRuleSet(List<String> domains) {
  final body = _ByteAccumulator();
  _writeUvarint(body, domains.isEmpty ? 0 : 1);
  if (domains.isNotEmpty) {
    _writeDefaultDomainSuffixRule(body, domains);
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

void _writeDefaultDomainSuffixRule(
  _ByteAccumulator writer,
  List<String> domains,
) {
  writer.writeByte(0);
  writer.writeByte(_ruleItemDomain);
  _buildDomainMatcher(domains).writeTo(writer);
  writer.writeByte(_ruleItemFinal);
  writer.writeByte(0);
}

_ParsedAdBlockFilter _parseAdBlockFilter(String content) {
  final blocked = <String>{};
  final allowed = <String>{};
  for (final rawLine in const LineSplitter().convert(content)) {
    final line = rawLine.trim();
    if (line.isEmpty ||
        line.startsWith('!') ||
        line.startsWith('#') ||
        line.startsWith('[')) {
      continue;
    }
    final isAllowRule = line.startsWith('@@');
    final domain = _extractDomain(line);
    if (domain == null) {
      continue;
    }
    if (isAllowRule) {
      allowed.add(domain);
    } else {
      blocked.add(domain);
    }
  }
  blocked.removeAll(allowed);
  final blockedList = blocked.toList()..sort();
  final allowedList = allowed.toList()..sort();
  return _ParsedAdBlockFilter(
    blockedDomains: blockedList,
    allowedDomains: allowedList,
  );
}

String? _extractDomain(String line) {
  var value = line.trim();
  if (value.startsWith('@@')) {
    value = value.substring(2);
  }
  if (value.contains(r'$badfilter') ||
      value.startsWith('/') ||
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
    return _normalizeDomain(hostsMatch.group(1)!);
  }

  final modifierIndex = value.indexOf(r'$');
  if (modifierIndex >= 0) {
    value = value.substring(0, modifierIndex);
  }
  value = value.trim();
  value = value.replaceFirst(RegExp(r'^\|\|'), '');
  value = value.replaceFirst(RegExp(r'^\|https?://', caseSensitive: false), '');
  value = value.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
  value = value.replaceFirst(RegExp(r'^\|'), '');
  if (value.startsWith('*.')) {
    value = value.substring(2);
  }
  while (value.startsWith('.')) {
    value = value.substring(1);
  }

  var end = value.length;
  for (final token in ['^', '/', '|', '*', '?', ',', '=']) {
    final index = value.indexOf(token);
    if (index >= 0 && index < end) {
      end = index;
    }
  }
  value = value.substring(0, end).trim();
  if (value.isEmpty) {
    return null;
  }

  final portIndex = value.indexOf(':');
  if (portIndex > 0) {
    final maybePort = value.substring(portIndex + 1);
    if (RegExp(r'^\d+$').hasMatch(maybePort)) {
      value = value.substring(0, portIndex);
    }
  }

  return _normalizeDomain(value);
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
  });

  final List<String> blockedDomains;
  final List<String> allowedDomains;
}

const List<int> _srsMagicBytes = <int>[0x53, 0x52, 0x53];
const int _srsVersion2 = 2;
const int _ruleItemDomain = 2;
const int _ruleItemFinal = 0xFF;
_DomainMatcher _buildDomainMatcher(List<String> domains) {
  final domainList = <String>[];
  final seen = <String>{};
  for (final domain in domains) {
    if (domain.isEmpty || !seen.add(domain)) {
      continue;
    }
    domainList.add(_reverseAscii('$_rootLabelMarker$domain'));
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
