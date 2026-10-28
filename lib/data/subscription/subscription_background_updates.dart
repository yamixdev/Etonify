import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/data/subscription/subscription_fetcher.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/data/subscription/subscription_failure.dart';
import 'package:meow_client/data/subscription/subscription_refresh_report.dart';

class SubscriptionBackgroundUpdates {
  static const _channel = MethodChannel('meow_client/subscription_refresh');
  static int _configurationGeneration = 0;
  static void Function()? onDownloadReady;

  static void listen() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'downloadReady') onDownloadReady?.call();
    });
  }

  static Future<void> invalidatePlan() async {
    ++_configurationGeneration;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _channel.invokeMethod<void>('configure', '{"profiles":[]}');
    }
  }

  static Future<void> configure(List<Subscription> profiles) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final generation = ++_configurationGeneration;
    final enabled = await SubscriptionRefreshReports.backgroundEnabled();
    final backoff = await SubscriptionRefreshReports.backoffUntil();
    final plans = <Map<String, Object?>>[];
    if (enabled) {
      for (final p in profiles) {
        if (p.disableAutoUpdate || p.autoRefreshMinutes <= 0) {
          continue;
        }
        for (final source in p.effectiveSources) {
          if (!source.enabled || Uri.tryParse(source.url)?.scheme != 'https') {
            continue;
          }
          final id = jsonEncode([p.id, source.id]);
          var dueAt = source.lastUpdated + p.autoRefreshMinutes * 60000;
          final until =
              backoff[id] ?? (p.sources.isEmpty ? backoff[p.id] : null) ?? 0;
          if (until > dueAt) dueAt = until;
          plans.add({
            'id': id,
            'url': source.url,
            'token': SubscriptionStore.backgroundSourceRevision(p, source.id),
            'headers': await SubscriptionFetcher.backgroundRequestHeaders(
              source.snapshot.info,
            ),
            'dueAt': dueAt,
            'intervalMillis': p.autoRefreshMinutes * 60000,
          });
        }
      }
    }
    if (generation != _configurationGeneration) return;
    await _channel.invokeMethod<void>(
      'configure',
      jsonEncode({'profiles': plans}),
    );
  }

  /// Acknowledges only after a durable report is written. Revision checks keep
  /// stale background content from overwriting manual edits or a newer fetch.
  static Future<List<SubscriptionRefreshEntry>> applyPending() async {
    if (defaultTargetPlatform != TargetPlatform.android) return [];
    final pending =
        jsonDecode(await _channel.invokeMethod<String>('pending') ?? '[]')
            as List;
    final entries = <SubscriptionRefreshEntry>[];
    for (final item in pending) {
      final id = item['id'] as String;
      final target = _target(id);
      final token = item['token'] as String;
      final profiles = await SubscriptionStore.getAllMetadataInBackground();
      final profile = profiles.where((p) => p.id == target.$1).firstOrNull;
      final source = profile?.effectiveSources
          .where((s) => s.id == (target.$2 ?? 'primary'))
          .firstOrNull;
      if (profile == null ||
          source == null ||
          !source.enabled ||
          (target.$2 == null
                  ? SubscriptionStore.backgroundRevision(profile)
                  : SubscriptionStore.backgroundSourceRevision(
                      profile,
                      source.id,
                    )) !=
              token) {
        await _ack(id, token);
        continue;
      }
      final encoded = await _channel.invokeMethod<String>('read', id);
      if (encoded == null) continue;
      final result = jsonDecode(encoded) as Map;
      if (result['token'] != token) continue;
      final payload = result['pendingSuccess'] as Map? ?? result;
      SubscriptionFailure? failure;
      if (payload['failure'] != null) {
        failure = SubscriptionFailure(
          SubscriptionFailureKind.values.firstWhere(
            (k) => k.name == payload['failure'],
            orElse: () => SubscriptionFailureKind.unknown,
          ),
          httpStatus: payload['httpStatus'] as int?,
        );
      } else {
        try {
          final bytes = base64Decode(payload['body'] as String);
          final headers = Map<String, String>.from(payload['headers'] as Map);
          if (target.$2 == null) {
            await SubscriptionStore.applyBackgroundDownload(
              profile.id,
              revision: token,
              bytes: bytes,
              headers: headers,
            );
          } else {
            await SubscriptionStore.applyBackgroundSourceDownload(
              profile.id,
              source.id,
              revision: token,
              bytes: bytes,
              headers: headers,
            );
          }
        } catch (error) {
          if (!await _isCurrent(profile.id, target.$2, token)) {
            await _ack(id, token);
            continue;
          }
          failure = classifySubscriptionFailure(error);
        }
      }
      if (failure != null) {
        try {
          await SubscriptionStore.recordSourceFailure(
            profile.id,
            source.id,
            failure,
            expectedRevision: target.$2 == null
                ? SubscriptionStore.backgroundSourceRevision(profile, source.id)
                : token,
          );
        } catch (_) {
          if (await _isCurrent(profile.id, target.$2, token)) rethrow;
          await _ack(id, token);
          continue;
        }
      }
      final entry = SubscriptionRefreshEntry(
        id: profile.id,
        sourceId: target.$2,
        name: target.$2 == null
            ? profile.name
            : '${profile.name} · ${source.name}',
        time: payload['time'] as int,
        failure: failure,
        background: true,
      );
      await SubscriptionRefreshReports.save([entry]);
      entries.add(entry);
      await _ack(id, token, attemptTime: result['time'] as int);
    }
    return entries;
  }

  static Future<bool> _isCurrent(
    String profileId,
    String? sourceId,
    String token,
  ) async {
    final profiles = await SubscriptionStore.getAllMetadataInBackground();
    final profile = profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return false;
    final source = profile.effectiveSources
        .where((s) => s.id == (sourceId ?? 'primary'))
        .firstOrNull;
    if (source == null || !source.enabled) return false;
    return (sourceId == null
            ? SubscriptionStore.backgroundRevision(profile)
            : SubscriptionStore.backgroundSourceRevision(profile, source.id)) ==
        token;
  }

  static (String, String?) _target(String id) {
    try {
      final decoded = jsonDecode(id);
      if (decoded is List &&
          decoded.length == 2 &&
          decoded[0] is String &&
          decoded[1] is String) {
        return (decoded[0] as String, decoded[1] as String);
      }
    } on FormatException {
      // Older native plans used the profile id directly.
    }
    return (id, null);
  }

  static Future<void> _ack(String id, String token, {int? attemptTime}) =>
      _channel.invokeMethod<void>(
        'ack',
        jsonEncode({'id': id, 'token': token, 'time': ?attemptTime}),
      );
}
