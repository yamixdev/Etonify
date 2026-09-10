import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:meow_client/models/subscription.dart';
import 'subscription_fetcher.dart';
import 'subscription_store.dart';
import 'subscription_failure.dart';
import 'subscription_refresh_report.dart';

class SubscriptionBackgroundUpdates {
  static const _channel = MethodChannel('meow_client/subscription_refresh');
  static int _configurationGeneration = 0;
  static Future<void> invalidatePlan() async {
    ++_configurationGeneration;
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('configure', '{"profiles":[]}');
    }
  }

  static Future<void> configure(List<Subscription> profiles) async {
    if (!Platform.isAndroid) return;
    final generation = ++_configurationGeneration;
    final enabled = await SubscriptionRefreshReports.backgroundEnabled();
    final backoff = await SubscriptionRefreshReports.backoffUntil();
    final plans = <Map<String, Object?>>[];
    if (enabled) {
      for (final p in profiles) {
        if (p.disableAutoUpdate ||
            p.autoRefreshMinutes <= 0 ||
            Uri.tryParse(p.url)?.scheme != 'https') {
          continue;
        }
        var dueAt = p.lastUpdated + p.autoRefreshMinutes * 60000;
        if ((backoff[p.id] ?? 0) > dueAt) dueAt = backoff[p.id]!;
        plans.add({
          'id': p.id,
          'url': p.url,
          'token': SubscriptionStore.backgroundRevision(p),
          'headers': await SubscriptionFetcher.backgroundRequestHeaders(p.info),
          'dueAt': dueAt,
        });
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
    if (!Platform.isAndroid) return [];
    final pending =
        jsonDecode(await _channel.invokeMethod<String>('pending') ?? '[]')
            as List;
    final entries = <SubscriptionRefreshEntry>[];
    for (final item in pending) {
      final id = item['id'] as String;
      final token = item['token'] as String;
      final profiles = await SubscriptionStore.getAllMetadataInBackground();
      final profile = profiles.where((p) => p.id == id).firstOrNull;
      if (profile == null ||
          SubscriptionStore.backgroundRevision(profile) != token) {
        await _ack(id, token);
        continue;
      }
      final encoded = await _channel.invokeMethod<String>('read', id);
      if (encoded == null) continue;
      final result = jsonDecode(encoded) as Map;
      if (result['token'] != token) continue;
      SubscriptionFailure? failure;
      if (result['failure'] != null) {
        failure = SubscriptionFailure(
          SubscriptionFailureKind.values.firstWhere(
            (k) => k.name == result['failure'],
            orElse: () => SubscriptionFailureKind.unknown,
          ),
          httpStatus: result['httpStatus'] as int?,
        );
      } else {
        try {
          await SubscriptionStore.applyBackgroundDownload(
            id,
            revision: token,
            bytes: base64Decode(result['body'] as String),
            headers: Map<String, String>.from(result['headers'] as Map),
          );
        } catch (error) {
          failure = classifySubscriptionFailure(error);
        }
      }
      final entry = SubscriptionRefreshEntry(
        id: id,
        name: profile.name,
        time: result['time'] as int,
        failure: failure,
        background: true,
      );
      await SubscriptionRefreshReports.save([entry]);
      entries.add(entry);
      await _ack(id, token);
    }
    return entries;
  }

  static Future<void> _ack(String id, String token) => _channel
      .invokeMethod<void>('ack', jsonEncode({'id': id, 'token': token}));
}
