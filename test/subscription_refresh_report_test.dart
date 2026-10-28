import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/windows_storage_fixture.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_refresh_report.dart';
import 'package:meow_client/data/subscription/subscription_failure.dart';
import 'package:meow_client/features/subscriptions/subscription_refresh_report_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('etonify-report-test');
    await bootstrapWindowsStorageFixture(directory);
    Hive.init(directory.path);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'persisted report merges unread batches without storing raw errors',
    () async {
      await SubscriptionRefreshReports.save([
        const SubscriptionRefreshEntry(id: 'one', name: 'First', time: 1000),
      ]);
      await SubscriptionRefreshReports.save([
        const SubscriptionRefreshEntry(
          id: 'two',
          name: 'Second',
          time: 2000,
          background: true,
          failure: SubscriptionFailure(
            SubscriptionFailureKind.httpStatus,
            httpStatus: 502,
          ),
        ),
      ]);
      final entries = await SubscriptionRefreshReports.latest();
      expect(entries, hasLength(2));
      expect(entries.last.failure?.httpStatus, 502);
      expect(entries.last.background, isTrue);
      expect(await SubscriptionRefreshReports.unread(), isTrue);
      expect(
        (await SubscriptionRefreshReports.backoffUntil())['two'],
        2000 + 15 * 60000,
      );
      expect(jsonEncode(entries.last.toMap()), isNot(contains('http://')));
      await SubscriptionRefreshReports.markRead();
      await SubscriptionRefreshReports.save([
        const SubscriptionRefreshEntry(id: 'two', name: 'Second', time: 3000),
      ]);
      expect(await SubscriptionRefreshReports.latest(), hasLength(1));
      expect(
        (await SubscriptionRefreshReports.backoffUntil()).containsKey('two'),
        isFalse,
      );
    },
  );

  testWidgets('report displays each profile and readable HTTP error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SubscriptionRefreshReportPage(
          entries: const [
            SubscriptionRefreshEntry(id: 'a', name: 'Profile A', time: 1000),
            SubscriptionRefreshEntry(
              id: 'b',
              name: 'Profile B',
              time: 2000,
              failure: SubscriptionFailure(
                SubscriptionFailureKind.httpStatus,
                httpStatus: 502,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Profile A'), findsOneWidget);
    expect(find.text('Profile B'), findsOneWidget);
    expect(find.textContaining('502'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'source reports merge and back off independently within one profile',
    () async {
      await SubscriptionRefreshReports.markRead();
      SubscriptionRefreshEntry entry(
        String source,
        int time, {
        bool fail = true,
      }) => SubscriptionRefreshEntry.fromMap({
        'id': 'combined',
        'sourceId': source,
        'name': 'Source $source',
        'time': time,
        'kind': fail ? 'timeout' : null,
      });
      await SubscriptionRefreshReports.save([
        entry('one', 1000),
        entry('two', 2000),
      ]);
      final entries = await SubscriptionRefreshReports.latest();
      expect(entries, hasLength(2));
      expect(entries.first.toMap()['sourceId'], 'one');
      final backoff = await SubscriptionRefreshReports.backoffUntil();
      expect(backoff[jsonEncode(['combined', 'one'])], 1000 + 15 * 60000);
      expect(backoff[jsonEncode(['combined', 'two'])], 2000 + 15 * 60000);
      await SubscriptionRefreshReports.save([entry('one', 3000, fail: false)]);
      final remaining = await SubscriptionRefreshReports.backoffUntil();
      expect(remaining.containsKey(jsonEncode(['combined', 'one'])), isFalse);
      expect(remaining[jsonEncode(['combined', 'two'])], 2000 + 15 * 60000);
      expect(await SubscriptionRefreshReports.latest(), hasLength(2));
    },
  );
}
