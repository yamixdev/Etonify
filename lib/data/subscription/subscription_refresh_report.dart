import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/local/secure_hive_storage.dart';
import 'package:meow_client/data/subscription/subscription_failure.dart';

class SubscriptionRefreshEntry {
  const SubscriptionRefreshEntry({
    required this.id,
    required this.name,
    required this.time,
    this.failure,
    this.background = false,
  });

  final String id;
  final String name;
  final int time;
  final SubscriptionFailure? failure;
  final bool background;
  bool get succeeded => failure == null;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'time': time,
    'kind': failure?.kind.name,
    'httpStatus': failure?.httpStatus,
    'background': background,
  };

  factory SubscriptionRefreshEntry.fromMap(Map<dynamic, dynamic> map) {
    final kind = map['kind'];
    return SubscriptionRefreshEntry(
      id: map['id'] as String,
      name: map['name'] as String,
      time: map['time'] as int,
      background: map['background'] == true,
      failure: kind == null
          ? null
          : SubscriptionFailure(
              SubscriptionFailureKind.values.firstWhere(
                (v) => v.name == kind,
                orElse: () => SubscriptionFailureKind.unknown,
              ),
              httpStatus: map['httpStatus'] as int?,
            ),
    );
  }
}

/// Stores only classified errors, never URLs, response bodies or credentials.
class SubscriptionRefreshReports {
  static Future<Box<dynamic>>? _opening;
  static Future<Box<dynamic>> _box() => _opening ??= () async {
    try {
      await SecureHiveStorage.init();
      return await Hive.openBox<dynamic>(
        'subscription_refresh_reports_v1',
        encryptionCipher: SecureHiveStorage.cipher,
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }();

  static Future<bool> backgroundEnabled() async =>
      (await _box()).get('background', defaultValue: false) == true;
  static Future<void> setBackgroundEnabled(bool value) async =>
      (await _box()).put('background', value);

  static Future<List<SubscriptionRefreshEntry>> latest() async =>
      ((await _box()).get('latest', defaultValue: <dynamic>[]) as List)
          .map((e) => SubscriptionRefreshEntry.fromMap(e as Map))
          .toList();

  static Future<void> save(List<SubscriptionRefreshEntry> entries) async {
    if (entries.isEmpty) return;
    final box = await _box();
    final attempts = Map<String, dynamic>.from(
      box.get('attempts', defaultValue: <String, dynamic>{}) as Map,
    );
    for (final entry in entries) {
      final previous = attempts[entry.id] as Map?;
      final failures = entry.succeeded
          ? 0
          : ((previous?['failures'] as int?) ?? 0) + 1;
      final minutes = switch (failures) {
        0 => 0,
        1 => 15,
        2 => 60,
        3 => 180,
        _ => 360,
      };
      attempts[entry.id] = {
        'failures': failures,
        'until': entry.time + minutes * 60000,
      };
    }
    await box.put('attempts', attempts);
    // Keep unread results if the app was backgrounded during a foreground run.
    final previous = box.get('unread', defaultValue: false) == true
        ? await latest()
        : <SubscriptionRefreshEntry>[];
    final merged = {
      for (final e in [...previous, ...entries]) e.id: e,
    };
    await box.put('latest', merged.values.map((e) => e.toMap()).toList());
    await box.put('unread', true);
    await box.flush();
  }

  static Future<bool> unread() async =>
      (await _box()).get('unread', defaultValue: false) == true;
  static Future<void> markRead() async => (await _box()).put('unread', false);
  static Future<Map<String, int>> backoffUntil() async {
    final attempts =
        (await _box()).get('attempts', defaultValue: <String, dynamic>{})
            as Map;
    return {
      for (final e in attempts.entries)
        if ((e.value as Map)['failures'] != 0)
          e.key as String: (e.value as Map)['until'] as int,
    };
  }
}
