import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/core/lowest_proxy_groups.dart';
import 'package:meow_client/data/local/hive_storage_diagnostics.dart';
import 'package:meow_client/data/local/secure_hive_storage.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/models/subscription.dart';

import 'location_aliases.dart';
import 'outbound_schema.dart';
import 'subscription_failure.dart';
import 'subscription_fetcher.dart';
import 'subscription_parser.dart';

class SubscriptionImportResult {
  const SubscriptionImportResult({required this.subscription, this.warning});

  final Subscription subscription;
  final Object? warning;

  bool get hasWarning => warning != null;
}

/// Hive-based persistent store for subscriptions.
///
/// Subscription metadata and heavy payload are stored separately so list UIs
/// can load fast without decoding large outbound collections.
class SubscriptionStore {
  static const _lagomWhitelistDetourTag = 'whitelist';
  static const _lagomWhitelistProxySourceTag = 'proxy-whitelist';
  static const _defaultRemoteOperationTimeout = Duration(seconds: 30);

  SubscriptionStore._();

  static const _metaBoxName = 'subscriptions_secure_v1';
  static const _payloadBoxName = 'subscription_payloads_secure_v1';
  static const _legacyMetaBoxName = 'subscriptions';
  static const _legacyPayloadBoxName = 'subscription_payloads';
  static const _legacySummaryBoxName = 'subscription_summaries';
  static const _storageSchemaVersionKey = '__etonify_storage_schema_version__';
  static const _storageSchemaVersion = 2;
  static const _localFileImportScheme = 'meow-file';
  static Box<dynamic>? _metaBox;
  static Box<dynamic>? _payloadBox;
  static Future<void>? _payloadInitialization;
  static bool _payloadMigrationRequired = false;
  static final Map<String, Future<void>> _subscriptionWriteLocks =
      <String, Future<void>>{};
  static final Map<String, Future<Subscription>> _refreshesInFlight =
      <String, Future<Subscription>>{};

  // ─────────────────── Lifecycle ───────────────────

  /// Opens subscription storage.
  ///
  /// Most callers need both boxes and keep the default [openPayload] value.
  /// Startup uses [initForBootstrap] instead: it opens only compact metadata,
  /// allowing the first screen to appear before encrypted multi-megabyte
  /// subscription payloads are mapped into Hive.
  static Future<void> init({bool openPayload = true}) async {
    if (_metaBox == null) {
      await _openMetadataBox();
    }
    if (openPayload || _payloadMigrationRequired) {
      await ensurePayloadReady();
    }
  }

  /// Prepares only the small metadata box for the application bootstrap.
  static Future<void> initForBootstrap() => init(openPayload: false);

  /// Opens the heavy encrypted payload box exactly once.
  ///
  /// All runtime/config callers await this before reading proxy definitions.
  /// Multiple requests share one future, so a quick tap on Connect while the
  /// post-frame warm-up is running cannot race the Hive open operation.
  static Future<void> ensurePayloadReady() {
    if (_payloadBox != null) {
      return Future<void>.value();
    }
    final pending = _payloadInitialization;
    if (pending != null) {
      return pending;
    }
    late final Future<void> initialization;
    initialization = () async {
      try {
        if (_metaBox == null) {
          await _openMetadataBox();
        }
        if (_payloadBox != null) {
          return;
        }
        final totalStopwatch = Stopwatch()..start();
        final payloadStopwatch = Stopwatch()..start();
        _payloadBox = Hive.isBoxOpen(_payloadBoxName)
            ? Hive.box(_payloadBoxName)
            : await Hive.openBox(
                _payloadBoxName,
                encryptionCipher: SecureHiveStorage.cipher,
              );
        payloadStopwatch.stop();
        await _runStorageMigrations();
        _payloadMigrationRequired = false;
        totalStopwatch.stop();
        await HiveStorageDiagnostics.logBoxOnce(
          label: _payloadBoxName,
          box: _payloadBox!,
          openElapsed: payloadStopwatch.elapsed,
        );
        AppLogStore.info(
          'storage metrics',
          'subscriptionPayloadStorageReadyMs='
              '${totalStopwatch.elapsedMilliseconds}',
        );
      } catch (error, stackTrace) {
        AppLogStore.error(
          'subscription storage',
          'Failed to initialize Hive subscription payloads: '
              '$error\n$stackTrace',
        );
        rethrow;
      } finally {
        if (identical(_payloadInitialization, initialization) &&
            _payloadBox == null) {
          _payloadInitialization = null;
        }
      }
    }();
    _payloadInitialization = initialization;
    return initialization;
  }

  static Future<void> _openMetadataBox() async {
    final totalStopwatch = Stopwatch()..start();
    try {
      await SecureHiveStorage.init();
      final metaStopwatch = Stopwatch()..start();
      _metaBox = Hive.isBoxOpen(_metaBoxName)
          ? Hive.box(_metaBoxName)
          : await Hive.openBox(
              _metaBoxName,
              encryptionCipher: SecureHiveStorage.cipher,
            );
      metaStopwatch.stop();
      totalStopwatch.stop();
      await HiveStorageDiagnostics.logBoxOnce(
        label: _metaBoxName,
        box: _metaBox!,
        openElapsed: metaStopwatch.elapsed,
      );
      AppLogStore.info(
        'storage metrics',
        'subscriptionMetadataStorageReadyMs='
            '${totalStopwatch.elapsedMilliseconds}',
      );
      // Storage schema upgrades move data between the metadata and payload
      // boxes. The bootstrap decides to complete that one-time migration
      // atomically instead of rendering an incomplete legacy profile list.
      final storedVersion =
          (_metaStore.get(_storageSchemaVersionKey) as num?)?.toInt() ?? 0;
      _payloadMigrationRequired = storedVersion < _storageSchemaVersion;
    } catch (error, stackTrace) {
      AppLogStore.error(
        'subscription storage',
        'Failed to initialize Hive subscription metadata: '
            '$error\n$stackTrace',
      );
      rethrow;
    }
  }

  static Future<void> _runStorageMigrations() async {
    final storedVersion =
        (_metaStore.get(_storageSchemaVersionKey) as num?)?.toInt() ?? 0;
    if (storedVersion >= _storageSchemaVersion) {
      return;
    }
    await _migratePlaintextBox(_legacyMetaBoxName, _metaStore);
    await _migratePlaintextBox(_legacyPayloadBoxName, _payloadStore);
    await _migrateLegacyData();
    // Do not rewrite or compact every legacy payload during app startup.
    // Readers accept both formats and each payload is compressed the next time
    // that subscription is saved or refreshed. A bulk rewrite here can keep
    // the bootstrap screen visible for close to a minute on large profiles.
    await _cleanupLegacySummaryBox();
    await _metaStore.put(_storageSchemaVersionKey, _storageSchemaVersion);
    await _metaStore.flush();
  }

  static Future<void> _migratePlaintextBox(
    String legacyName,
    Box<dynamic> secureBox,
  ) async {
    if (!await Hive.boxExists(legacyName)) return;

    final legacyBox = Hive.isBoxOpen(legacyName)
        ? Hive.box<dynamic>(legacyName)
        : await Hive.openBox<dynamic>(legacyName);
    try {
      if (legacyBox.isNotEmpty) {
        final legacyValues = Map<dynamic, dynamic>.from(legacyBox.toMap());
        final missingValues = <dynamic, dynamic>{
          for (final entry in legacyValues.entries)
            if (!secureBox.containsKey(entry.key)) entry.key: entry.value,
        };
        if (missingValues.isNotEmpty) {
          await secureBox.putAll(missingValues);
          await secureBox.flush();
        }
        if (legacyValues.keys.any((key) => !secureBox.containsKey(key))) {
          throw StateError('Encrypted subscription migration was incomplete.');
        }
      }
    } finally {
      await legacyBox.close();
    }

    // Keep plaintext until the authenticated encrypted copy is durable.
    await Hive.deleteBoxFromDisk(legacyName);
  }

  static Box<dynamic> get _metaStore {
    assert(_metaBox != null, 'SubscriptionStore.init() must be called first');
    return _metaBox!;
  }

  static Box<dynamic> get _payloadStore {
    if (_payloadBox == null) {
      throw StateError(
        'SubscriptionStore.ensurePayloadReady() must be awaited first',
      );
    }
    return _payloadBox!;
  }

  static Future<T> _withSubscriptionWriteLock<T>(
    String id,
    Future<T> Function() action,
  ) async {
    final previous = _subscriptionWriteLocks[id] ?? Future<void>.value();
    late final Future<T> next;
    late final Future<void> queued;
    next = previous
        .catchError((_) {
          // Keep the per-subscription queue alive even if the previous write
          // failed. The next writer must still see the latest committed payload.
        })
        .then((_) => action());
    queued = next.then<void>((_) {}, onError: (_) {});
    _subscriptionWriteLocks[id] = queued;
    try {
      return await next;
    } finally {
      if (identical(_subscriptionWriteLocks[id], queued)) {
        unawaited(_subscriptionWriteLocks.remove(id));
      }
    }
  }

  static DateTime _operationDeadline(Duration? timeout) {
    return DateTime.now().add(timeout ?? _defaultRemoteOperationTimeout);
  }

  static Future<T> _withDeadline<T>(
    Future<T> future,
    DateTime deadline,
    String operationName,
  ) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw TimeoutException('$operationName timed out');
    }
    return future.timeout(
      remaining,
      onTimeout: () =>
          throw TimeoutException('$operationName timed out', remaining),
    );
  }

  static Duration _remainingUntil(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    return remaining <= Duration.zero ? Duration.zero : remaining;
  }

  // ─────────────────── CRUD ───────────────────

  /// Returns all stored subscriptions.
  static List<Subscription> getAll() {
    final indexedResults = <({int index, Subscription subscription})>[];
    var index = 0;
    for (final subscription in getAllMetadata()) {
      indexedResults.add((
        index: index,
        subscription: _withPayload(subscription),
      ));
      index++;
    }
    indexedResults.sort((a, b) {
      final left = a.subscription.sortOrder ?? (1 << 30) + a.index;
      final right = b.subscription.sortOrder ?? (1 << 30) + b.index;
      return left.compareTo(right);
    });
    return indexedResults
        .map((entry) => entry.subscription)
        .toList(growable: false);
  }

  /// Loads all complete subscriptions while decoding large payload JSON away
  /// from the UI isolate. Hive values are copied before the worker starts.
  static Future<List<Subscription>> getAllInBackground() async {
    await ensurePayloadReady();
    final metadataSnapshot = _metadataJsonSnapshot();
    if (metadataSnapshot.isEmpty) {
      return const <Subscription>[];
    }
    final payloadSnapshot = <String, String>{};
    for (final key in _payloadStore.keys) {
      final raw = _payloadStore.get(key);
      if (raw is String) {
        payloadSnapshot[key.toString()] = raw;
      }
    }
    return Isolate.run(() {
      return _decodeMetadataSnapshot(metadataSnapshot)
          .map((metadata) {
            final raw = payloadSnapshot[metadata.id];
            return raw == null ? metadata : _withPayloadFromRaw(metadata, raw);
          })
          .toList(growable: false);
    }, debugName: 'meow-subscriptions-full');
  }

  /// Returns metadata-only subscriptions without loading raw content/outbounds.
  static List<Subscription> getAllMetadata() {
    return _decodeMetadataSnapshot(_metadataJsonSnapshot());
  }

  /// Copies compact metadata strings from Hive and performs JSON/model decoding
  /// outside the UI isolate.
  static Future<List<Subscription>> getAllMetadataInBackground() async {
    final snapshot = _metadataJsonSnapshot();
    if (snapshot.isEmpty) {
      return const <Subscription>[];
    }
    return Isolate.run(
      () => _decodeMetadataSnapshot(snapshot),
      debugName: 'meow-subscription-metadata',
    );
  }

  static List<String> _metadataJsonSnapshot() {
    final values = <String>[];
    for (final key in _metaStore.keys) {
      if (key == _storageSchemaVersionKey) {
        continue;
      }
      final raw = _metaStore.get(key);
      if (raw is String) {
        values.add(raw);
      }
    }
    return values;
  }

  static List<Subscription> _decodeMetadataSnapshot(List<String> snapshot) {
    final indexedResults = <({int index, Subscription subscription})>[];
    for (var index = 0; index < snapshot.length; index++) {
      try {
        final map = jsonDecode(snapshot[index]) as Map<String, dynamic>;
        indexedResults.add((
          index: index,
          subscription: Subscription.fromMetadataMap(map),
        ));
      } catch (_) {
        // Skip corrupt entries.
      }
    }
    indexedResults.sort((a, b) {
      final left = a.subscription.sortOrder ?? (1 << 30) + a.index;
      final right = b.subscription.sortOrder ?? (1 << 30) + b.index;
      return left.compareTo(right);
    });
    return indexedResults
        .map((entry) => entry.subscription)
        .toList(growable: false);
  }

  /// Gets a single subscription by ID, or null.
  static Subscription? get(String id) {
    final raw = _metaStore.get(id);
    if (raw is! String) return null;
    try {
      final metadata = Subscription.fromMetadataMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return _withPayload(metadata);
    } catch (_) {
      return null;
    }
  }

  /// Loads one complete subscription without decoding its payload on the UI
  /// isolate. Hive values are copied before the worker starts.
  static Future<Subscription?> getInBackground(String id) async {
    await ensurePayloadReady();
    final metadataRaw = _metaStore.get(id);
    if (metadataRaw is! String) {
      return null;
    }
    final payloadRaw = _payloadStore.get(id);
    return Isolate.run(() {
      try {
        final metadata = Subscription.fromMetadataMap(
          jsonDecode(metadataRaw) as Map<String, dynamic>,
        );
        return payloadRaw is String
            ? _withPayloadFromRaw(metadata, payloadRaw)
            : metadata;
      } catch (_) {
        return null;
      }
    }, debugName: 'meow-subscription-single');
  }

  /// Hydrates raw content/outbounds for a metadata-only subscription.
  static Subscription withPayload(Subscription metadata) {
    return _withPayload(metadata);
  }

  static String? payloadJsonFor(String id) {
    final snapshot = payloadSnapshotFor(id);
    if (snapshot == null) {
      return null;
    }
    try {
      return _decodeStoredPayload(snapshot);
    } catch (_) {
      return null;
    }
  }

  /// Returns the stored payload representation without decompression.
  ///
  /// Pass this snapshot to a worker isolate and hydrate it there. Calling
  /// [payloadJsonFor] for a multi-megabyte profile on the UI isolate would
  /// undo the startup benefit of compressed storage.
  static String? payloadSnapshotFor(String id) {
    if (_payloadBox == null) {
      return null;
    }
    final raw = _payloadStore.get(id);
    return raw is String ? raw : null;
  }

  static Subscription hydratePayloadJson(Subscription metadata, String raw) {
    return _withPayloadFromRaw(metadata, raw);
  }

  /// Hydrates raw content/outbounds away from the UI isolate.
  static Future<Subscription> withPayloadInBackground(
    Subscription metadata,
  ) async {
    await ensurePayloadReady();
    final raw = _payloadStore.get(metadata.id);
    if (raw is! String) {
      return metadata;
    }
    final metadataMap = metadata.toMetadataMap();
    return Isolate.run(
      () => hydratePayloadJson(Subscription.fromMetadataMap(metadataMap), raw),
      debugName: 'meow-subscription-payload',
    );
  }

  /// Saves (creates or updates) a subscription.
  static Future<void> save(Subscription sub) async {
    await ensurePayloadReady();
    await _withSubscriptionWriteLock(sub.id, () => _saveUnlocked(sub));
  }

  static Future<void> _saveUnlocked(Subscription sub) async {
    final payload = await Isolate.run(
      () => _encodeStoredPayload(jsonEncode(sub.toPayloadMap())),
      debugName: 'meow-encode-subscription-payload',
    );
    await _metaStore.put(sub.id, jsonEncode(sub.toMetadataMap()));
    await _payloadStore.put(sub.id, payload);
  }

  /// Saves only lightweight subscription metadata.
  static Future<void> saveMetadata(Subscription sub) async {
    await _withSubscriptionWriteLock(sub.id, () => _saveMetadataUnlocked(sub));
  }

  /// Persists a proxy selection without letting an older in-memory snapshot
  /// overwrite metadata written by a concurrent subscription refresh.
  static Future<void> saveSelectedProxyMetadata(Subscription sub) async {
    await _withSubscriptionWriteLock(sub.id, () async {
      final raw = _metaStore.get(sub.id);
      if (raw is! String) {
        throw StateError('Subscription metadata not found: ${sub.id}');
      }
      late final Subscription current;
      try {
        current = Subscription.fromMetadataMap(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (error) {
        throw StateError(
          'Subscription metadata is invalid for ${sub.id}: $error',
        );
      }
      await _saveMetadataUnlocked(
        current.copyWith(selectedProxyTag: sub.selectedProxyTag),
      );
    });
  }

  static Future<void> _saveMetadataUnlocked(Subscription sub) async {
    await _metaStore.put(sub.id, jsonEncode(sub.toMetadataMap()));
  }

  static Future<bool> saveLatestPingsInBackground(
    String id,
    Map<String, int> latestPings,
  ) async {
    return saveOutboundRuntimeInfoInBackground(id, latestPings: latestPings);
  }

  static Future<bool> saveOutboundRuntimeInfoInBackground(
    String id, {
    Map<String, int> latestPings = const <String, int>{},
    Map<String, Map<String, String?>> externalInfos =
        const <String, Map<String, String?>>{},
  }) async {
    await ensurePayloadReady();
    var saved = false;
    await _withSubscriptionWriteLock(id, () async {
      saved = await _saveOutboundRuntimeInfoInBackgroundUnlocked(
        id,
        latestPings: latestPings,
        externalInfos: externalInfos,
      );
    });
    return saved;
  }

  static Future<bool> _saveOutboundRuntimeInfoInBackgroundUnlocked(
    String id, {
    required Map<String, int> latestPings,
    required Map<String, Map<String, String?>> externalInfos,
  }) async {
    // Latency belongs to the current runtime session. Persisting it makes an
    // old value look fresh after reconnect or process restart.
    final updates = <String, Map<String, Object?>>{};
    for (final entry in externalInfos.entries) {
      final tag = entry.key.trim();
      if (tag.isEmpty) {
        continue;
      }
      final externalIp = entry.value['external_ip']?.trim();
      final sourceCountry = entry.value['source_country']?.trim().toUpperCase();
      final exitCountry =
          (entry.value['exit_country'] ?? entry.value['country'])
              ?.trim()
              .toUpperCase();
      if ((externalIp == null || externalIp.isEmpty) &&
          (sourceCountry == null || sourceCountry.isEmpty) &&
          (exitCountry == null || exitCountry.isEmpty)) {
        continue;
      }
      final update = updates.putIfAbsent(tag, () => <String, Object?>{});
      if (externalIp != null && externalIp.isNotEmpty) {
        update['external_ip'] = externalIp;
      }
      if (sourceCountry != null && sourceCountry.isNotEmpty) {
        update['source_country'] = sourceCountry;
      }
      if (exitCountry != null && exitCountry.isNotEmpty) {
        update['exit_country'] = exitCountry;
      }
    }
    if (updates.isEmpty) {
      return false;
    }
    final raw = _payloadStore.get(id);
    if (raw is! String || raw.isEmpty) {
      return false;
    }
    final updatedRaw = await Isolate.run(
      () => _rewriteOutboundRuntimeInfoPayload(raw, updates),
      debugName: 'meow-save-outbound-runtime-info',
    );
    if (updatedRaw == null || updatedRaw == raw) {
      return false;
    }
    await _payloadStore.put(id, updatedRaw);
    return true;
  }

  /// Deletes a subscription by ID.
  static Future<void> delete(String id) async {
    await ensurePayloadReady();
    await _metaStore.delete(id);
    await _payloadStore.delete(id);
  }

  static Future<void> deleteMany(Iterable<String> ids) async {
    await ensurePayloadReady();
    await _metaStore.deleteAll(ids);
    await _payloadStore.deleteAll(ids);
  }

  /// Deletes all subscriptions.
  static Future<void> clear() async {
    await ensurePayloadReady();
    await _metaStore.clear();
    await _payloadStore.clear();
  }

  // ─────────────────── High-level operations ───────────────────

  /// Adds a new subscription from a URL.
  ///
  /// 1. Fetches the URL
  /// 2. Parses headers + body
  /// 3. Creates Outbound objects from parsed configs
  /// 4. Saves to store
  ///
  /// Returns the created [Subscription].
  static Future<SubscriptionImportResult> addFromUrl(
    String url, {
    String? customName,
    int autoRefreshMinutes = 360,
    SubscriptionInfo? requestInfo,
    Duration? operationTimeout,
    bool Function()? isCancelled,
    bool allowInsecureTls = false,
    SubscriptionFetchRouteAttemptCallback? onRouteAttempt,
  }) async {
    await ensurePayloadReady();
    final id = SubscriptionFetcher.generateId();
    final deadline = _operationDeadline(operationTimeout);
    _throwIfImportCancelled(isCancelled);
    try {
      final result = await _withDeadline(
        SubscriptionFetcher.fetch(
          url,
          requestInfo: requestInfo,
          operationTimeout: _remainingUntil(deadline),
          allowInsecureTls: allowInsecureTls,
          onRouteAttempt: onRouteAttempt,
        ),
        deadline,
        'subscription import',
      );
      _throwIfImportCancelled(isCancelled);

      final payload = await _withDeadline(
        _buildSubscriptionPayloadAsync(
          result.parseResult,
          providerName: _providerNameHint(
            customName: customName,
            headerTitle: result.headerInfo.title,
          ),
        ),
        deadline,
        'subscription import',
      );
      _throwIfImportCancelled(isCancelled);
      final outbounds = payload.outbounds;
      if (!_hasUsableOutbounds(outbounds)) {
        throw SubscriptionContentException(
          result.parseResult.hasUnsupportedWireGuard
              ? SubscriptionContentFailureKind.wireGuardUnsupported
              : SubscriptionContentFailureKind.noUsableProxies,
        );
      }

      final sub = Subscription(
        id: id,
        name: _pickSubscriptionName(
          customName: customName,
          headerTitle: result.headerInfo.title,
          outbounds: outbounds,
          url: url,
        ),
        url: url,
        selectedProxyTag: _selectedProxyTagForOutbounds(
          outbounds,
          groups: payload.groups,
        ),
        sortOrder: _nextSortOrder(),
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        autoRefreshMinutes: result.headerInfo.updateIntervalHours != null
            ? result.headerInfo.updateIntervalHours! * 60
            : autoRefreshMinutes,
        rawContent: result.rawContent,
        outbounds: outbounds,
        groups: payload.groups,
        urlTestConfig: const UrlTestConfig(),
        info: result.headerInfo.copyWith(
          happCryptoLink:
              requestInfo?.happCryptoLink ?? result.headerInfo.happCryptoLink,
          customUserAgent:
              requestInfo?.customUserAgent ?? result.headerInfo.customUserAgent,
          customRequestHeader:
              requestInfo?.customRequestHeader ??
              result.headerInfo.customRequestHeader,
          requireHwid:
              requestInfo?.requireHwid ?? result.headerInfo.requireHwid,
          customHwid: requestInfo?.customHwid ?? result.headerInfo.customHwid,
        ),
      );

      _logLikelyHwidWarning(sub);
      _throwIfImportCancelled(isCancelled);
      await save(sub);
      if (isCancelled?.call() ?? false) {
        await delete(id);
        throw const SubscriptionImportCancelledException();
      }
      return SubscriptionImportResult(
        subscription: sub,
        warning: result.parseResult.hasUnsupportedWireGuard
            ? const SubscriptionContentException(
                SubscriptionContentFailureKind.wireGuardUnsupported,
              )
            : null,
      );
    } catch (error) {
      if (error is SubscriptionImportCancelledException ||
          (isCancelled?.call() ?? false)) {
        throw const SubscriptionImportCancelledException();
      }
      if (error is TimeoutException) {
        AppLogStore.warning(
          'subscription',
          'Initial subscription import timed out for "$url": $error',
        );
        rethrow;
      }
      final sub = Subscription(
        id: id,
        name: _pickSubscriptionName(
          customName: customName,
          headerTitle: requestInfo?.title,
          outbounds: const [],
          url: url,
        ),
        url: url,
        sortOrder: _nextSortOrder(),
        autoRefreshMinutes: autoRefreshMinutes,
        urlTestConfig: const UrlTestConfig(),
        info: requestInfo,
      );
      _throwIfImportCancelled(isCancelled);
      await save(sub);
      if (isCancelled?.call() ?? false) {
        await delete(id);
        throw const SubscriptionImportCancelledException();
      }
      AppLogStore.warning(
        'subscription',
        'Initial subscription import failed for "$url", '
            'saved placeholder entry instead: $error',
      );
      return SubscriptionImportResult(subscription: sub, warning: error);
    }
  }

  static Future<SubscriptionImportResult> addFromContent(
    String content, {
    String? customName,
    String? sourceName,
    Duration? operationTimeout,
    bool Function()? isCancelled,
  }) async {
    await ensurePayloadReady();
    final deadline = _operationDeadline(operationTimeout);
    _throwIfImportCancelled(isCancelled);
    final parseResult = await _withDeadline(
      SubscriptionParser.parseInBackground(content),
      deadline,
      'subscription file import',
    );
    _throwIfImportCancelled(isCancelled);
    final payload = await _withDeadline(
      _buildSubscriptionPayloadAsync(
        parseResult,
        providerName: _providerNameHint(
          customName: customName,
          headerTitle: sourceName,
        ),
      ),
      deadline,
      'subscription file import',
    );
    _throwIfImportCancelled(isCancelled);
    final outbounds = payload.outbounds;
    if (!_hasUsableOutbounds(outbounds)) {
      throw SubscriptionContentException(
        parseResult.hasUnsupportedWireGuard
            ? SubscriptionContentFailureKind.wireGuardUnsupported
            : SubscriptionContentFailureKind.noUsableProxies,
      );
    }

    final normalizedSourceName = _normalizeName(sourceName) ?? 'subscription';
    final localUrl = _localFileImportUrl(normalizedSourceName);
    final sub = Subscription(
      id: SubscriptionFetcher.generateId(),
      name: _pickSubscriptionName(
        customName: customName,
        headerTitle: null,
        outbounds: outbounds,
        url: localUrl,
      ),
      url: localUrl,
      selectedProxyTag: _selectedProxyTagForOutbounds(
        outbounds,
        groups: payload.groups,
      ),
      sortOrder: _nextSortOrder(),
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      disableAutoUpdate: true,
      rawContent: content,
      outbounds: outbounds,
      groups: payload.groups,
      urlTestConfig: const UrlTestConfig(),
    );

    _throwIfImportCancelled(isCancelled);
    await save(sub);
    if (isCancelled?.call() ?? false) {
      await delete(sub.id);
      throw const SubscriptionImportCancelledException();
    }
    return SubscriptionImportResult(
      subscription: sub,
      warning: parseResult.hasUnsupportedWireGuard
          ? const SubscriptionContentException(
              SubscriptionContentFailureKind.wireGuardUnsupported,
            )
          : null,
    );
  }

  static void _throwIfImportCancelled(bool Function()? isCancelled) {
    if (isCancelled?.call() ?? false) {
      throw const SubscriptionImportCancelledException();
    }
  }

  /// Refreshes an existing subscription (re-fetches from URL).
  ///
  /// Returns the updated [Subscription].
  static Future<Subscription> refresh(
    String id, {
    Duration? operationTimeout,
    bool allowInsecureTls = false,
    SubscriptionFetchRouteAttemptCallback? onRouteAttempt,
  }) {
    final inFlight = _refreshesInFlight[id];
    if (inFlight != null) {
      return inFlight;
    }
    final operation = _refresh(
      id,
      operationTimeout: operationTimeout,
      allowInsecureTls: allowInsecureTls,
      onRouteAttempt: onRouteAttempt,
    );
    _refreshesInFlight[id] = operation;
    return operation.whenComplete(() {
      if (identical(_refreshesInFlight[id], operation)) {
        _refreshesInFlight.remove(id);
      }
    });
  }

  static Future<Subscription> _refresh(
    String id, {
    Duration? operationTimeout,
    required bool allowInsecureTls,
    SubscriptionFetchRouteAttemptCallback? onRouteAttempt,
  }) async {
    await ensurePayloadReady();
    final existingBeforeFetch = get(id);
    if (existingBeforeFetch == null) {
      throw StateError('Subscription $id not found');
    }
    if (isLocalFileImportUrl(existingBeforeFetch.url)) {
      throw StateError('Manual imports cannot be refreshed');
    }

    final deadline = _operationDeadline(operationTimeout);
    final result = await _withDeadline(
      SubscriptionFetcher.fetch(
        existingBeforeFetch.url,
        requestInfo: existingBeforeFetch.info,
        operationTimeout: _remainingUntil(deadline),
        allowInsecureTls: allowInsecureTls,
        onRouteAttempt: onRouteAttempt,
      ),
      deadline,
      'subscription refresh',
    );
    final payload = await _withDeadline(
      _buildSubscriptionPayloadAsync(
        result.parseResult,
        providerName: _providerNameHint(
          customName: existingBeforeFetch.name,
          headerTitle:
              result.headerInfo.title ?? existingBeforeFetch.info?.title,
        ),
      ),
      deadline,
      'subscription refresh',
    );
    final outbounds = payload.outbounds;
    if (!_hasUsableOutbounds(outbounds)) {
      throw SubscriptionContentException(
        result.parseResult.hasUnsupportedWireGuard
            ? SubscriptionContentFailureKind.wireGuardUnsupported
            : SubscriptionContentFailureKind.noUsableProxies,
      );
    }

    return _withSubscriptionWriteLock(id, () async {
      final existing = get(id);
      if (existing == null) {
        throw StateError('Subscription $id not found');
      }
      final existingMovedUrl = existing.info?.newUrl;
      final nextMovedUrl = result.headerInfo.newUrl;
      final preserveMovedIgnore =
          existing.info?.ignoreSubscriptionMoved == true &&
          existingMovedUrl != null &&
          existingMovedUrl.isNotEmpty &&
          existingMovedUrl == nextMovedUrl;

      final preservedOutbounds = _preserveUserState(
        existing.outbounds,
        outbounds,
      );

      final updated = existing.copyWith(
        name: existing.name,
        url: existing.url,
        selectedProxyTag: _selectedProxyTagForOutbounds(
          preservedOutbounds,
          preferredTag: existing.selectedProxyTag,
          groups: payload.groups,
        ),
        sortOrder: existing.sortOrder,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        rawContent: result.rawContent,
        outbounds: preservedOutbounds,
        groups: payload.groups,
        autoRefreshMinutes: result.headerInfo.updateIntervalHours != null
            ? result.headerInfo.updateIntervalHours! * 60
            : existing.autoRefreshMinutes,
        info: result.headerInfo.copyWith(
          happCryptoLink: existing.info?.happCryptoLink,
          ignoreSubscriptionMoved: preserveMovedIgnore,
          customUserAgent: existing.info?.customUserAgent,
          customRequestHeader: existing.info?.customRequestHeader,
          requireHwid: existing.info?.requireHwid ?? false,
          customHwid: existing.info?.customHwid,
        ),
      );

      _logLikelyHwidWarning(updated);
      await _saveUnlocked(updated);
      return updated;
    });
  }

  /// Rebuilds outbounds from saved raw content without fetching the network URL.
  ///
  /// This is useful when parsing rules change and we want to re-interpret the
  /// already stored subscription payload.
  static Future<Subscription> reparseFromRaw(String id) async {
    await ensurePayloadReady();
    final existingBeforeParse = get(id);
    if (existingBeforeParse == null) {
      throw StateError('Subscription $id not found');
    }
    final rawContent = existingBeforeParse.rawContent.trim();
    if (rawContent.isEmpty) {
      throw const SubscriptionContentException(
        SubscriptionContentFailureKind.emptyResponse,
      );
    }

    final parseResult = await SubscriptionParser.parseInBackground(rawContent);
    if (parseResult.outbounds.isEmpty) {
      throw SubscriptionContentException(
        parseResult.hasUnsupportedWireGuard
            ? SubscriptionContentFailureKind.wireGuardUnsupported
            : SubscriptionContentFailureKind.noUsableProxies,
      );
    }

    final payload = await _buildSubscriptionPayloadAsync(
      parseResult,
      providerName: _providerNameHint(
        customName: existingBeforeParse.name,
        headerTitle: existingBeforeParse.info?.title,
      ),
    );
    final reparsedOutbounds = payload.outbounds;
    if (!_hasUsableOutbounds(reparsedOutbounds)) {
      throw const SubscriptionContentException(
        SubscriptionContentFailureKind.noUsableProxies,
      );
    }

    return _withSubscriptionWriteLock(id, () async {
      final existing = get(id);
      if (existing == null) {
        throw StateError('Subscription $id not found');
      }
      final preservedOutbounds = _preserveUserState(
        existing.outbounds,
        reparsedOutbounds,
      );

      final updated = existing.copyWith(
        selectedProxyTag: _selectedProxyTagForOutbounds(
          preservedOutbounds,
          preferredTag: existing.selectedProxyTag,
          groups: payload.groups,
        ),
        outbounds: preservedOutbounds,
        groups: payload.groups,
      );
      await _saveUnlocked(updated);
      return updated;
    });
  }

  static Future<void> moveUp(String id) async {
    final subscriptions = getAllMetadata();
    final index = subscriptions.indexWhere(
      (subscription) => subscription.id == id,
    );
    if (index <= 0) {
      return;
    }
    final reordered = subscriptions.toList(growable: false);
    final previous = reordered[index - 1];
    reordered[index - 1] = reordered[index];
    reordered[index] = previous;
    await _saveOrdered(reordered);
  }

  static Future<void> reorder(List<Subscription> subscriptions) async {
    await _saveOrdered(subscriptions);
  }

  static Future<void> cachePayloadSummaries(
    Map<String, ({int visibleProxyCount, bool hasRawPayload})> summaries,
  ) async {
    if (summaries.isEmpty) {
      return;
    }
    final updates = <dynamic, String>{};
    for (final entry in summaries.entries) {
      final raw = _metaStore.get(entry.key);
      if (raw is! String) {
        continue;
      }
      try {
        final metadata =
            Subscription.fromMetadataMap(
              jsonDecode(raw) as Map<String, dynamic>,
            ).copyWith(
              cachedVisibleProxyCount: entry.value.visibleProxyCount,
              hasRawPayload: entry.value.hasRawPayload,
            );
        updates[entry.key] = jsonEncode(metadata.toMetadataMap());
      } catch (_) {
        // Leave corrupt metadata untouched; getAllMetadata already skips it.
      }
    }
    if (updates.isNotEmpty) {
      await _metaStore.putAll(updates);
    }
  }

  // ─────────────────── Helpers ───────────────────

  static String _selectedProxyTagForOutbounds(
    List<Outbound> outbounds, {
    String? preferredTag,
    List<SubscriptionGroup> groups = const [],
  }) {
    if (outbounds.isEmpty) {
      return '';
    }
    if (outbounds.length == 1) {
      return outbounds.first.tag;
    }
    final normalizedPreferred = normalizeProxySelectionTag(preferredTag ?? '');
    if (normalizedPreferred.isEmpty) {
      return lowestProxyTag;
    }
    if (isLowestProxyTag(normalizedPreferred)) {
      return lowestProxyTag;
    }
    final liveOutboundTags = outbounds
        .where(
          (outbound) =>
              !outbound.info.deleted && outbound.config['_group_only'] != true,
        )
        .map((outbound) => outbound.tag)
        .toSet();
    for (final group in groups) {
      if (group.tag == normalizedPreferred &&
          group.outboundTags.any(liveOutboundTags.contains)) {
        return normalizedPreferred;
      }
    }
    for (final outbound in outbounds) {
      if (outbound.tag == normalizedPreferred && !outbound.info.deleted) {
        return normalizedPreferred;
      }
    }
    return lowestProxyTag;
  }

  static bool _hasUsableOutbounds(List<Outbound> outbounds) {
    return outbounds.any(
      (outbound) =>
          !outbound.info.deleted && outbound.config['_group_only'] != true,
    );
  }

  /// Converts parsed outbound configs into [Outbound] model objects.
  static List<Outbound> _buildOutbounds(
    List<Map<String, dynamic>> parsedConfigs,
  ) {
    final payload = _buildOutboundPayload(parsedConfigs);
    _logBuildWarningEntries(payload.warnings);
    return payload.outbounds
        .map((entry) => Outbound.fromMap(entry))
        .toList(growable: false);
  }

  static Future<({List<Outbound> outbounds, List<SubscriptionGroup> groups})>
  _buildSubscriptionPayloadAsync(
    ParseResult parseResult, {
    String? providerName,
  }) async {
    final normalizedConfigs = parseResult.outbounds
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
    final normalizedGroups = parseResult.groups
        .map((entry) => entry.toMap())
        .toList(growable: false);
    final payload = Map<String, dynamic>.from(
      await compute(_buildSubscriptionPayloadWorker, {
        'outbounds': normalizedConfigs,
        'groups': normalizedGroups,
        'provider_name': ?providerName,
      }),
    );
    _logBuildWarningEntries(payload['warnings'] as List? ?? const []);
    final outbounds = (payload['outbounds'] as List? ?? const [])
        .map(
          (entry) => Outbound.fromMap(Map<String, dynamic>.from(entry as Map)),
        )
        .toList(growable: false);
    final groups = (payload['groups'] as List? ?? const [])
        .map(
          (entry) => SubscriptionGroup.fromMap(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .where((group) => group.outboundTags.isNotEmpty)
        .toList(growable: false);
    return (outbounds: outbounds, groups: groups);
  }

  static ({
    List<Map<String, dynamic>> outbounds,
    List<Map<String, dynamic>> groups,
    List<String> warnings,
  })
  _buildOutboundPayload(
    List<Map<String, dynamic>> parsedConfigs, [
    List<Map<String, dynamic>> parsedGroups = const [],
    String? providerName,
  ]) {
    final lagomProfile = _looksLikeLagomProviderName(providerName);
    final buildConfigs = lagomProfile
        ? _normalizeLagomConfigs(parsedConfigs)
        : parsedConfigs;
    final buildGroups = lagomProfile
        ? _normalizeLagomGroups(buildConfigs, parsedGroups)
        : parsedGroups;
    final outbounds = <Outbound>[];
    final groups = <SubscriptionGroup>[];
    final warnings = <String>[];
    final usedTags = <String>{};
    final sourceScopeToTagToTags = <String, Map<String, List<String>>>{};

    for (var i = 0; i < buildConfigs.length; i++) {
      final config = Map<String, dynamic>.from(buildConfigs[i]);

      // Extract and remove the _name meta field
      final rawName = (config.remove('_name') ?? 'Proxy ${i + 1}') as String;
      final sourceTag = config.remove('_source_tag')?.toString().trim() ?? '';
      final sourceScope =
          config.remove('_source_scope')?.toString().trim() ?? '';
      final detourSourceTag =
          config.remove('_detour_source_tag')?.toString().trim() ?? '';
      config.remove('_source_profile_name');
      final countryOverride = _normalizeCountryCode(
        config.remove('_country_override')?.toString(),
      );
      final parsedName = _extractCountryFromName(rawName);
      final name = parsedName.name;

      final validationError = ParsedOutboundSchema.validate(config);
      if (validationError != null) {
        warnings.add('Skipping outbound "$name": $validationError');
        continue;
      }

      // Generate a unique tag
      final type = (config['type'] ?? 'proxy') as String;
      var tag = '$type-$i';
      // Try to use name-based tag
      final sanitized = _sanitizeTag(name);
      if (sanitized.isNotEmpty &&
          !usedTags.contains(sanitized) &&
          !isReservedProxyTag(sanitized)) {
        tag = sanitized;
      }
      usedTags.add(tag);
      if (sourceTag.isNotEmpty) {
        sourceScopeToTagToTags
            .putIfAbsent(sourceScope, () => <String, List<String>>{})
            .putIfAbsent(sourceTag, () => <String>[])
            .add(tag);
      }
      if (detourSourceTag.isNotEmpty) {
        final resolvedDetourTags =
            sourceScopeToTagToTags[sourceScope]?[detourSourceTag] ??
            const <String>[];
        if (resolvedDetourTags.isNotEmpty) {
          config['detour'] = resolvedDetourTags.last;
        } else {
          warnings.add('Skipping outbound "$name": missing chain detour');
          continue;
        }
      }

      // Set the tag in the config
      config['tag'] = tag;

      outbounds.add(
        Outbound(
          tag: tag,
          name: name,
          config: config,
          info: OutboundInfo(
            country: countryOverride ?? parsedName.countryCode,
          ),
        ),
      );
    }

    for (var i = 0; i < buildGroups.length; i++) {
      final group = ParsedOutboundGroup.fromMap(buildGroups[i]);
      final sourceTagToTags =
          sourceScopeToTagToTags[group.sourceScope] ??
          (group.sourceScope.isEmpty
              ? _mergeSourceTagScopes(sourceScopeToTagToTags.values)
              : const <String, List<String>>{});
      final memberTags = <String>[];
      final seenMembers = <String>{};
      for (final sourceTag in group.sourceOutboundTags) {
        final resolvedTags = sourceTagToTags[sourceTag] ?? const <String>[];
        for (final resolvedTag in resolvedTags) {
          if (seenMembers.add(resolvedTag)) {
            memberTags.add(resolvedTag);
          }
        }
      }
      if (memberTags.isEmpty) {
        continue;
      }

      final rawGroupName = group.name.trim().isNotEmpty
          ? group.name.trim()
          : 'Proxy group ${groups.length + 1}';
      final parsedGroupName = _extractCountryFromName(rawGroupName);
      final groupName = parsedGroupName.name.trim().isNotEmpty
          ? parsedGroupName.name.trim()
          : 'Proxy group ${groups.length + 1}';
      final groupCountry =
          _normalizeCountryCode(group.countryCode) ??
          parsedGroupName.countryCode;
      var tag = _uniqueTag(
        lagomProfile &&
                group.sourceTag.trim().toLowerCase() == _lagomWhitelistDetourTag
            ? _lagomWhitelistDetourTag
            : _groupTagSeed(group.sourceTag, groupName, groups.length),
        usedTags,
      );
      if (isReservedProxyTag(tag)) {
        tag = _uniqueTag('group-${groups.length + 1}', usedTags);
      }
      usedTags.add(tag);
      groups.add(
        SubscriptionGroup(
          tag: tag,
          name: groupName,
          type: group.type.trim().isEmpty ? 'urltest' : group.type.trim(),
          country: groupCountry,
          outboundTags: memberTags,
          urlTestConfig: UrlTestConfig(
            url: group.url,
            method: group.method,
            intervalSeconds: group.intervalSeconds,
            timeoutSeconds: group.timeoutSeconds,
            concurrency: group.concurrency,
            unavailableCheckIntervalSeconds:
                group.unavailableCheckIntervalSeconds,
          ),
        ),
      );
    }

    return (
      outbounds: outbounds
          .map((entry) => entry.toMap())
          .toList(growable: false),
      groups: groups.map((entry) => entry.toMap()).toList(growable: false),
      warnings: warnings,
    );
  }

  static Map<String, List<String>> _mergeSourceTagScopes(
    Iterable<Map<String, List<String>>> scopes,
  ) {
    final merged = <String, List<String>>{};
    for (final scope in scopes) {
      for (final entry in scope.entries) {
        merged.putIfAbsent(entry.key, () => <String>[]).addAll(entry.value);
      }
    }
    return merged;
  }

  static String _groupTagSeed(String sourceTag, String name, int groupIndex) {
    final source = sourceTag.trim().isNotEmpty ? sourceTag : name;
    final sanitized = _sanitizeTag(source);
    return sanitized.isNotEmpty ? 'group-$sanitized' : 'group-$groupIndex';
  }

  static String _uniqueTag(String seed, Set<String> usedTags) {
    final sanitized = _sanitizeTag(seed);
    var tag = sanitized.isEmpty ? 'proxy' : sanitized;
    if (!usedTags.contains(tag)) {
      return tag;
    }
    var suffix = 2;
    while (usedTags.contains('$tag-$suffix')) {
      suffix++;
    }
    return '$tag-$suffix';
  }

  static String _sanitizeTag(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static bool likelyRequiresHwidEnable(Subscription subscription) {
    final info = subscription.info;
    if (info?.requireHwid == true) {
      return false;
    }
    final visibleOutbounds = subscription.outbounds
        .where((outbound) => !outbound.info.deleted)
        .where((outbound) => outbound.config['_group_only'] != true)
        .toList(growable: false);
    if (visibleOutbounds.length != 1) {
      return false;
    }
    final outboundName = visibleOutbounds.first.name.trim().toLowerCase();
    final subscriptionName = subscription.name.trim().toLowerCase();
    final title = info?.title?.trim().toLowerCase() ?? '';
    return _looksLikeHwidMarker(outboundName) ||
        _looksLikeHwidMarker(subscriptionName) ||
        _looksLikeHwidMarker(title);
  }

  static void _logLikelyHwidWarning(Subscription subscription) {
    if (!likelyRequiresHwidEnable(subscription)) {
      return;
    }
    AppLogStore.warning(
      'subscription',
      'Subscription "${subscription.name}" looks like it requires HWID. '
          'Only one outbound was returned and its name/title mentions app or HWID.',
    );
  }

  static bool _looksLikeHwidMarker(String value) {
    if (value.isEmpty) {
      return false;
    }
    if (value.contains('hwid')) {
      return true;
    }
    return RegExp(r'(^|[^a-z])app([^a-z]|$)').hasMatch(value);
  }

  /// Preserves user state only when the provider identity still matches.
  ///
  /// Removed provider keys are dropped from the active payload. Historical
  /// storage should not keep secrets in soft-deleted active outbounds.
  static List<Outbound> _preserveUserState(
    List<Outbound> oldOutbounds,
    List<Outbound> newOutbounds,
  ) {
    final oldByTag = <String, Outbound>{};
    final oldByKey = <String, List<Outbound>>{};
    for (final ob in oldOutbounds) {
      oldByTag[ob.tag] = ob;
      final key = _outboundKey(ob.config);
      oldByKey.putIfAbsent(key, () => <Outbound>[]).add(ob);
    }

    final newKeyCounts = <String, int>{};
    for (final ob in newOutbounds) {
      final key = _outboundKey(ob.config);
      newKeyCounts[key] = (newKeyCounts[key] ?? 0) + 1;
    }

    final merged = newOutbounds
        .map((ob) {
          final key = _outboundKey(ob.config);
          final exactOldOutbound = oldByTag[ob.tag];
          final oldMatches = oldByKey[key] ?? const <Outbound>[];
          final exactOldKeyMatches =
              exactOldOutbound != null &&
              _outboundKey(exactOldOutbound.config) == key;
          final oldOutbound =
              (exactOldKeyMatches ? exactOldOutbound : null) ??
              (oldMatches.length == 1 && newKeyCounts[key] == 1
                  ? oldMatches.single
                  : null);
          final oldInfo = oldOutbound?.info;
          if (oldInfo != null) {
            final canCarryEndpointState =
                oldMatches.length == 1 && newKeyCounts[key] == 1;
            return ob.copyWith(
              info: ob.info.copyWith(
                checked: oldInfo.checked,
                deleted: false,
                externalIp: canCarryEndpointState ? oldInfo.externalIp : null,
                country:
                    ob.info.country ??
                    (canCarryEndpointState ? oldInfo.country : null),
                exitCountry: canCarryEndpointState ? oldInfo.exitCountry : null,
                latestPing: canCarryEndpointState ? oldInfo.latestPing : null,
              ),
            );
          }
          return ob;
        })
        .toList(growable: false);

    return merged;
  }

  @visibleForTesting
  static List<Outbound> preserveUserStateForTest(
    List<Outbound> oldOutbounds,
    List<Outbound> newOutbounds,
  ) => _preserveUserState(oldOutbounds, newOutbounds);

  @visibleForTesting
  static ({String name, String? countryCode}) extractCountryFromNameForTest(
    String rawName,
  ) => _extractCountryFromName(rawName);

  static String? inferCountryCodeFromName(String rawName) =>
      _extractCountryFromName(rawName).countryCode;

  @visibleForTesting
  static List<Outbound> buildOutboundsForTest(
    List<Map<String, dynamic>> parsedConfigs,
  ) => _buildOutbounds(parsedConfigs);

  @visibleForTesting
  static String selectedProxyTagForOutboundsForTest(
    List<Outbound> outbounds, {
    String? preferredTag,
    List<SubscriptionGroup> groups = const [],
  }) => _selectedProxyTagForOutbounds(
    outbounds,
    preferredTag: preferredTag,
    groups: groups,
  );

  @visibleForTesting
  static ({
    List<Map<String, dynamic>> outbounds,
    List<Map<String, dynamic>> groups,
    List<String> warnings,
  })
  buildSubscriptionPayloadForTest(
    ParseResult parseResult, {
    String? providerName,
  }) {
    return _buildOutboundPayload(
      parseResult.outbounds,
      parseResult.groups.map((group) => group.toMap()).toList(growable: false),
      providerName,
    );
  }

  static bool isLocalFileImportUrl(String url) {
    return url.trim().startsWith('$_localFileImportScheme://');
  }

  static String? localFileImportDisplayName(String url) {
    if (!isLocalFileImportUrl(url)) {
      return null;
    }
    final trimmed = url.trim();
    final encoded = trimmed.substring('$_localFileImportScheme://'.length);
    final decoded = Uri.decodeComponent(encoded).trim();
    return decoded.isEmpty ? null : decoded;
  }

  static int _nextSortOrder() {
    final subscriptions = getAllMetadata();
    if (subscriptions.isEmpty) {
      return 0;
    }
    var maxOrder = -1;
    for (final subscription in subscriptions) {
      final order = subscription.sortOrder;
      if (order != null && order > maxOrder) {
        maxOrder = order;
      }
    }
    return maxOrder >= 0 ? maxOrder + 1 : subscriptions.length;
  }

  static Future<void> _saveOrdered(List<Subscription> subscriptions) async {
    final payload = <dynamic, String>{};
    for (var i = 0; i < subscriptions.length; i++) {
      final normalized = subscriptions[i].copyWith(sortOrder: i);
      payload[normalized.id] = jsonEncode(normalized.toMetadataMap());
    }
    await _metaStore.putAll(payload);
  }

  static void _logBuildWarningEntries(List<dynamic> warnings) {
    for (final entry in warnings) {
      final message = entry.toString().trim();
      if (message.isNotEmpty) {
        AppLogStore.warning('subscription', message);
      }
    }
  }

  static Subscription _withPayload(Subscription metadata) {
    if (_payloadBox == null) {
      return metadata;
    }
    final raw = _payloadStore.get(metadata.id);
    if (raw is! String) {
      return metadata;
    }
    return _withPayloadFromRaw(metadata, raw);
  }

  static Subscription _withPayloadFromRaw(Subscription metadata, String raw) {
    try {
      final map = jsonDecode(_decodeStoredPayload(raw)) as Map<String, dynamic>;
      return metadata.copyWith(
        rawContent: map['raw_content'] as String? ?? '',
        outbounds:
            (map['outbounds'] as List?)
                ?.map(
                  (entry) =>
                      Outbound.fromMap(Map<String, dynamic>.from(entry as Map)),
                )
                .toList() ??
            const [],
        groups:
            (map['groups'] as List?)
                ?.map(
                  (entry) => SubscriptionGroup.fromMap(
                    Map<String, dynamic>.from(entry as Map),
                  ),
                )
                .where((group) => group.tag.isNotEmpty)
                .toList() ??
            const [],
      );
    } catch (_) {
      return metadata;
    }
  }

  static Future<void> _migrateLegacyData() async {
    final updatedMetadata = <dynamic, String>{};
    final updatedPayloads = <dynamic, String>{};

    for (final key in _metaStore.keys) {
      final raw = _metaStore.get(key);
      if (raw is! String) {
        continue;
      }
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final hasEmbeddedPayload =
            map.containsKey('raw_content') || map.containsKey('outbounds');
        if (!hasEmbeddedPayload) {
          continue;
        }
        final subscription = Subscription.fromMap(map);
        updatedMetadata[subscription.id] = jsonEncode(
          subscription.toMetadataMap(),
        );
        updatedPayloads[subscription.id] = jsonEncode(
          subscription.toPayloadMap(),
        );
      } catch (_) {
        // Leave corrupt legacy entries untouched so they can still be inspected.
      }
    }

    if (updatedMetadata.isNotEmpty) {
      await _metaStore.putAll(updatedMetadata);
    }
    if (updatedPayloads.isNotEmpty) {
      await _payloadStore.putAll(updatedPayloads);
    }
  }

  static Future<void> _cleanupLegacySummaryBox() async {
    if (Hive.isBoxOpen(_legacySummaryBoxName)) {
      await Hive.box<dynamic>(_legacySummaryBoxName).close();
    }
    if (!await Hive.boxExists(_legacySummaryBoxName)) {
      return;
    }
    // This cache is obsolete. Opening it would decode every legacy summary
    // before clearing it, which is especially expensive for huge profiles.
    await Hive.deleteBoxFromDisk(_legacySummaryBoxName);
  }

  /// Creates a lookup key from outbound config for matching across refreshes.
  static String _outboundKey(Map<String, dynamic> config) {
    final identity = <String, dynamic>{
      for (final key in const <String>[
        'type',
        'server',
        'server_port',
        'uuid',
        'password',
        'username',
        'method',
        'security',
        'flow',
        'network',
        'packet_encoding',
        'plugin',
        'plugin_opts',
        'obfs',
        'obfs-password',
        'tls',
        'transport',
        'multiplex',
      ])
        if (config.containsKey(key))
          key: _stableOutboundIdentityValue(config[key]),
    };
    return jsonEncode(_stableOutboundIdentityValue(identity));
  }

  static dynamic _stableOutboundIdentityValue(dynamic value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      final entries =
          value.entries
              .map((entry) => MapEntry(entry.key.toString(), entry.value))
              .toList(growable: false)
            ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in entries) {
        result[entry.key] = _stableOutboundIdentityValue(entry.value);
      }
      return result;
    }
    if (value is Iterable) {
      return value.map(_stableOutboundIdentityValue).toList(growable: false);
    }
    return value;
  }

  /// Extracts a sensible name from a URL.
  static String _nameFromUrl(String url) {
    if (localFileImportDisplayName(url) case final displayName?) {
      return displayName;
    }
    try {
      final uri = SubscriptionFetcher.parseRequestUri(url);
      return uri.host.isNotEmpty ? uri.host : 'Subscription';
    } catch (_) {
      final match = RegExp(
        r'^[A-Za-z][A-Za-z0-9+.\-]*:\/\/(?:[^\/?#@]+@)?([^\/?#:]+)',
      ).firstMatch(url.trim());
      final host = match?.group(1)?.trim();
      if (host != null && host.isNotEmpty) {
        return host;
      }
      return 'Subscription';
    }
  }

  static String _localFileImportUrl(String sourceName) {
    return '$_localFileImportScheme://${Uri.encodeComponent(sourceName)}';
  }

  static String? _providerNameHint({
    required String? customName,
    required String? headerTitle,
  }) {
    final parts = [?_normalizeName(customName), ?_normalizeName(headerTitle)];
    return parts.isEmpty ? null : parts.join(' ');
  }

  static String _pickSubscriptionName({
    required String? customName,
    required String? headerTitle,
    required List<Outbound> outbounds,
    required String url,
  }) {
    final normalizedCustom = _normalizeName(customName);
    if (normalizedCustom != null) {
      return normalizedCustom;
    }

    final normalizedHeader = _normalizeName(headerTitle);
    if (normalizedHeader != null) {
      return normalizedHeader;
    }

    final outboundName = _nameFromOutbounds(outbounds);
    if (outboundName != null) {
      return outboundName;
    }

    return _nameFromUrl(url);
  }

  static String? _nameFromOutbounds(List<Outbound> outbounds) {
    String? genericFallback;
    for (final outbound in outbounds) {
      final normalized = _normalizeName(outbound.name);
      if (normalized == null) {
        continue;
      }
      if (!_looksGenericName(normalized)) {
        return normalized;
      }
      genericFallback ??= normalized;
    }
    for (final outbound in outbounds) {
      final server = _normalizeName(outbound.server);
      if (server != null) {
        return server;
      }
    }
    if (genericFallback != null) {
      return genericFallback;
    }
    for (final outbound in outbounds) {
      final type = outbound.type.trim();
      if (type.isNotEmpty) {
        return type.toUpperCase();
      }
    }
    return null;
  }

  static String? _normalizeName(String? value) {
    if (value == null) return null;
    final normalized = value.trim().replaceAll(RegExp(r'^"+|"+$'), '');
    if (normalized.isEmpty) return null;
    return normalized;
  }

  static bool _looksGenericName(String value) {
    final normalized = value.trim().toLowerCase();
    return RegExp(
      r'^(proxy|node|server|outbound|profile|subscription)\s*[-_#:]?\s*\d+$',
    ).hasMatch(normalized);
  }

  static bool _looksLikeLagomProviderName(String? value) {
    final normalized = value?.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '',
    );
    return normalized != null && normalized.contains('lagomvpn');
  }

  static List<Map<String, dynamic>> _normalizeLagomConfigs(
    List<Map<String, dynamic>> parsedConfigs,
  ) {
    final results = <Map<String, dynamic>>[];
    final seenWlConfigs = <String>{};
    final nameCounts = <String, int>{};

    for (final rawConfig in parsedConfigs) {
      final config = Map<String, dynamic>.from(rawConfig);
      final sourceTag = config['_source_tag']?.toString().trim() ?? '';
      final type = config['type']?.toString().trim().toLowerCase() ?? '';

      if (sourceTag == 'proxy' && type == 'vless') {
        final profileName = _normalizeLagomProfileName(
          config['_source_profile_name']?.toString(),
        );
        if (profileName != null) {
          final countryCode = _extractCountryFromName(profileName).countryCode;
          if (countryCode != null) {
            config['_country_override'] = countryCode;
          }
        }
        config['_name'] = 'Direct';
        results.add(config);
        final whitelistConfig = Map<String, dynamic>.from(config);
        whitelistConfig['_name'] = 'WL';
        whitelistConfig['_source_tag'] = _lagomWhitelistProxySourceTag;
        whitelistConfig['_group_only'] = true;
        whitelistConfig['detour'] = _lagomWhitelistDetourTag;
        results.add(whitelistConfig);
        continue;
      }

      if (!_isLagomWlSourceTag(sourceTag) || type != 'vless') {
        continue;
      }

      final dedupeKey = _lagomWlDedupeKey(config, sourceTag);
      if (!seenWlConfigs.add(dedupeKey)) {
        continue;
      }

      final baseName = _lagomUnfuckSourceTag(sourceTag);
      final count = (nameCounts[baseName] ?? 0) + 1;
      nameCounts[baseName] = count;
      config['_name'] = count == 1 ? baseName : '$baseName $count';
      config['_country_override'] = 'RU';
      results.add(config);
    }

    return results;
  }

  static String? _normalizeLagomProfileName(String? value) {
    final normalized = _normalizeName(value);
    if (normalized == null) {
      return null;
    }
    return normalized
        .replaceAll(
          RegExp(r'\s*\(\s*Глобальный\s*\)', caseSensitive: false),
          '',
        )
        .trim();
  }

  static List<Map<String, dynamic>> _normalizeLagomGroups(
    List<Map<String, dynamic>> normalizedConfigs,
    List<Map<String, dynamic>> parsedGroups,
  ) {
    final whitelistSourceTags = <String>[];
    final seenWhitelistSourceTags = <String>{};
    final proxyByScope = <String, Map<String, dynamic>>{};
    final proxyWhitelistScopes = <String>{};
    for (final config in normalizedConfigs) {
      final sourceTag = config['_source_tag']?.toString().trim() ?? '';
      final sourceScope = config['_source_scope']?.toString().trim() ?? '';
      if (sourceTag == 'proxy') {
        proxyByScope[sourceScope] = config;
      } else if (sourceTag == _lagomWhitelistProxySourceTag) {
        proxyWhitelistScopes.add(sourceScope);
      } else if (_isLagomWlSourceTag(sourceTag) &&
          seenWhitelistSourceTags.add(sourceTag)) {
        whitelistSourceTags.add(sourceTag);
      }
    }

    ParsedOutboundGroup? urlTestSource;
    for (final parsedGroup in parsedGroups) {
      final group = ParsedOutboundGroup.fromMap(parsedGroup);
      if (group.url?.trim().isNotEmpty == true ||
          group.intervalSeconds != null ||
          group.timeoutSeconds != null) {
        urlTestSource = group;
        break;
      }
    }

    final url = urlTestSource?.url;
    final interval = urlTestSource?.intervalSeconds;
    final timeout = urlTestSource?.timeoutSeconds;

    final groups = <Map<String, dynamic>>[];
    var serverGroupIndex = 0;
    for (final entry in proxyByScope.entries) {
      final sourceScope = entry.key;
      if (!proxyWhitelistScopes.contains(sourceScope)) {
        continue;
      }
      final config = entry.value;
      final name =
          _normalizeLagomProfileName(
            config['_source_profile_name']?.toString(),
          ) ??
          _normalizeLagomProfileName(config['_name']?.toString());
      final group = <String, dynamic>{
        'tag': 'lagom-server-$serverGroupIndex',
        'name': name?.isNotEmpty == true ? name : 'Lagom server',
        'type': 'urltest',
        if (sourceScope.isNotEmpty) 'source_scope': sourceScope,
        'outbounds': ['proxy', _lagomWhitelistProxySourceTag],
        'method': 'setback',
      };
      if (url != null) {
        group['url'] = url;
      }
      if (interval != null) {
        group['interval'] = interval;
      }
      if (timeout != null) {
        group['timeout'] = timeout;
      }
      groups.add(group);
      serverGroupIndex++;
    }

    if (whitelistSourceTags.length >= 2) {
      final group = <String, dynamic>{
        'tag': _lagomWhitelistDetourTag,
        'name': 'Whitelist',
        'type': 'urltest',
        'outbounds': whitelistSourceTags,
        'method': 'lowest',
      };
      if (url != null) {
        group['url'] = url;
      }
      if (interval != null) {
        group['interval'] = interval;
      }
      if (timeout != null) {
        group['timeout'] = timeout;
      }
      groups.add(group);
    }
    return groups;
  }

  static bool _isLagomWlSourceTag(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized.startsWith('WL-') && normalized != 'WL-IN';
  }

  static String _lagomWlDedupeKey(
    Map<String, dynamic> config,
    String sourceTag,
  ) {
    final transport = config['transport'];
    return [
      sourceTag,
      config['server']?.toString() ?? '',
      config['server_port']?.toString() ?? '',
      config['uuid']?.toString() ?? '',
      transport is Map ? transport['type']?.toString() ?? '' : '',
    ].join('\n');
  }

  static String _lagomUnfuckSourceTag(String sourceTag) {
    final aliases = const {
      'vkc': 'vk cloud',
      'ya': 'yandex',
      'con': 'contell',
      'yad': 'yandex',
    };
    final parts = sourceTag
        .trim()
        .toLowerCase()
        .split('-')
        .where((part) => part.isNotEmpty && int.tryParse(part) == null)
        .map((part) => aliases[part] ?? part)
        .expand((part) => part.split(' '))
        .where((part) => part.isNotEmpty)
        .map(_formatLagomNamePart)
        .toList(growable: false);
    return parts.isEmpty ? sourceTag.trim() : parts.join(' ');
  }

  static String _formatLagomNamePart(String part) {
    return switch (part) {
      'wl' => 'WL',
      'vk' => 'VK',
      'cdn' => 'CDN',
      'sel' => 'SEL',
      _ => part.substring(0, 1).toUpperCase() + part.substring(1),
    };
  }

  static ({String name, String? countryCode}) _extractCountryFromName(
    String rawName,
  ) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return (name: trimmed, countryCode: null);
    }

    final match = RegExp(
      r'([\u{1F1E6}-\u{1F1FF}]{2})',
      unicode: true,
    ).firstMatch(trimmed);
    if (match == null) {
      return (
        name: trimmed,
        countryCode: _countryCodeFromLeadingLocation(
          _stripLeadingDecorations(trimmed),
        ),
      );
    }

    final flag = match.group(1)!;
    final start = match.start;
    final end = match.end;
    final remainder = '${trimmed.substring(0, start)} ${trimmed.substring(end)}'
        .trim()
        .replaceAll(RegExp(r'\s{2,}'), ' ');
    final countryCode = _countryCodeFromFlag(flag);
    return (
      name: remainder.isNotEmpty ? remainder : trimmed,
      countryCode: countryCode,
    );
  }

  static String? _normalizeCountryCode(String? countryCode) {
    final normalized = countryCode?.trim().toUpperCase() ?? '';
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  static String _stripLeadingDecorations(String value) {
    var result = value.trim();
    while (result.isNotEmpty) {
      final changed = result
          .replaceFirst(RegExp(r'^[\s\-_.:/|]+'), '')
          .replaceFirst(
            RegExp(r'^[^\u{1F1E6}-\u{1F1FF}A-Za-zА-Яа-яЁё0-9]+', unicode: true),
            '',
          )
          .trimLeft();
      if (changed == result) {
        break;
      }
      result = changed;
    }
    return result;
  }

  static String? _countryCodeFromFlag(String flag) {
    final runes = flag.runes.toList(growable: false);
    if (runes.length != 2) {
      return null;
    }

    final first = runes[0] - 0x1F1E6;
    final second = runes[1] - 0x1F1E6;
    if (first < 0 || first > 25 || second < 0 || second > 25) {
      return null;
    }

    return String.fromCharCodes([65 + first, 65 + second]);
  }

  static String? _countryCodeFromLeadingLocation(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'^[\s\-_.:/|]+'),
      '',
    );
    for (final entry in _locationAliasesByLongestPrefix) {
      final key = entry.key;
      if (normalized == key ||
          normalized.startsWith('$key ') ||
          normalized.startsWith('$key-') ||
          normalized.startsWith('${key}_') ||
          normalized.startsWith('$key.') ||
          normalized.startsWith('$key/') ||
          normalized.startsWith('$key|') ||
          normalized.startsWith('$key:')) {
        return entry.value;
      }
    }
    return null;
  }

  static final List<MapEntry<String, String>> _locationAliasesByLongestPrefix =
      kLocationAliases.entries.toList(growable: false)
        ..sort((a, b) => b.key.length.compareTo(a.key.length));
}

String? _rewriteOutboundRuntimeInfoPayload(
  String raw,
  Map<String, Map<String, Object?>> updatesByTag,
) {
  try {
    final map = jsonDecode(_decodeStoredPayload(raw)) as Map<String, dynamic>;
    final rawOutbounds = map['outbounds'];
    if (rawOutbounds is! List || rawOutbounds.isEmpty) {
      return null;
    }
    var changed = false;
    final outbounds = rawOutbounds
        .map((rawOutbound) {
          if (rawOutbound is! Map) {
            return rawOutbound;
          }
          final outbound = Map<String, dynamic>.from(rawOutbound);
          final tag = outbound['tag']?.toString() ?? '';
          final update = updatesByTag[tag];
          if (update == null || update.isEmpty) {
            return rawOutbound;
          }
          final info = outbound['info'] is Map
              ? Map<String, dynamic>.from(outbound['info'] as Map)
              : <String, dynamic>{};
          var outboundChanged = false;
          final latestPing = update['latest_ping'];
          if (latestPing is int && latestPing > 0) {
            if ((info['latest_ping'] as num?)?.toInt() != latestPing) {
              info['latest_ping'] = latestPing;
              outboundChanged = true;
            }
          }
          final externalIp = update['external_ip'];
          if (externalIp is String && externalIp.isNotEmpty) {
            if (info['external_ip'] != externalIp) {
              info['external_ip'] = externalIp;
              outboundChanged = true;
            }
          }
          final sourceCountry = update['source_country'];
          if (sourceCountry is String && sourceCountry.isNotEmpty) {
            if (info['country'] != sourceCountry) {
              info['country'] = sourceCountry;
              outboundChanged = true;
            }
          }
          final exitCountry = update['exit_country'];
          if (exitCountry is String && exitCountry.isNotEmpty) {
            if (info['exit_country'] != exitCountry) {
              info['exit_country'] = exitCountry;
              outboundChanged = true;
            }
          }
          if (!outboundChanged) {
            return rawOutbound;
          }
          outbound['info'] = info;
          changed = true;
          return outbound;
        })
        .toList(growable: false);
    if (!changed) {
      return null;
    }
    final updated = Map<String, dynamic>.from(map);
    updated['outbounds'] = outbounds;
    return _encodeStoredPayload(jsonEncode(updated));
  } catch (_) {
    return null;
  }
}

const _compressedPayloadPrefix = 'gzip-base64-v1:';

bool _isCompressedPayload(String value) =>
    value.startsWith(_compressedPayloadPrefix);

String _encodeStoredPayload(String json) {
  final compressed = gzip.encode(utf8.encode(json));
  final encoded = '$_compressedPayloadPrefix${base64Encode(compressed)}';
  return encoded.length < json.length ? encoded : json;
}

String _decodeStoredPayload(String value) {
  if (!_isCompressedPayload(value)) {
    return value;
  }
  final encoded = value.substring(_compressedPayloadPrefix.length);
  return utf8.decode(gzip.decode(base64Decode(encoded)));
}

Map<String, dynamic> _buildSubscriptionPayloadWorker(
  Map<String, dynamic> input,
) {
  final parsedConfigs = (input['outbounds'] as List? ?? const [])
      .map((entry) => Map<String, dynamic>.from(entry as Map))
      .toList(growable: false);
  final parsedGroups = (input['groups'] as List? ?? const [])
      .map((entry) => Map<String, dynamic>.from(entry as Map))
      .toList(growable: false);
  final providerName = input['provider_name']?.toString();
  final payload = SubscriptionStore._buildOutboundPayload(
    parsedConfigs,
    parsedGroups,
    providerName,
  );
  return {
    'outbounds': payload.outbounds,
    'groups': payload.groups,
    'warnings': payload.warnings,
  };
}
