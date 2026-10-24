import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/subscription/subscription_fetcher.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/features/subscriptions/subscriptions_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';

import 'support/windows_storage_fixture.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  late Directory directory;
  late HttpServer server;
  HttpOverrides? oldOverrides;
  late bool oldHwidSharing;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    oldOverrides = HttpOverrides.current;
    oldHwidSharing = SubscriptionFetcher.sendHwidToProviders;
    SubscriptionFetcher.configureHwidSharing(false);
    HttpOverrides.global = _RealHttpOverrides();
    directory = await Directory.systemTemp.createTemp('subscription-async-ui-');
    await bootstrapWindowsStorageFixture(directory);
    Hive.init(directory.path);
    await SubscriptionStore.init();
    SubscriptionFetcher.configureAppVersion('0.3.9');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    await SubscriptionStore.save(
      Subscription(
        id: 'profile',
        name: 'Profile',
        url: 'http://127.0.0.1:${server.port}/subscription',
        cachedVisibleProxyCount: 1,
        rawContent: 'original',
        outbounds: const [
          Outbound(
            tag: 'original',
            name: 'Original',
            config: {'type': 'vless'},
          ),
        ],
      ),
    );
  });

  tearDown(() async {
    await server.close(force: true);
    await SubscriptionStore.close();
    await Hive.close();
    HttpOverrides.global = oldOverrides;
    SubscriptionFetcher.configureHwidSharing(oldHwidSharing);
    await directory.delete(recursive: true);
  });

  for (final accept in [true, false]) {
    _testWidgets(
      'moved ${accept ? 'accept' : 'ignore'} preserves a concurrent refreshed payload and info',
      (tester) async {
        server.listen((request) async {
          request.response.headers.set('new-url', 'https://moved.example/sub');
          request.response.write(_response);
          await request.response.close();
        });
        await _openAndRefresh(tester);
        await _until(
          tester,
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
        );
        final original = (await _store(
          tester,
          SubscriptionStore.get('profile'),
        ))!;
        await _store(
          tester,
          SubscriptionStore.save(
            original.copyWith(
              name: 'Fresh profile',
              lastUpdated: 456789,
              rawContent: 'fresh payload',
              outbounds: const [
                Outbound(
                  tag: 'fresh',
                  name: 'Fresh',
                  config: {'type': 'vless'},
                ),
              ],
              info: original.info!.copyWith(
                download: 999,
                requireHwid: true,
                customUserAgent: 'Fresh UA',
              ),
            ),
          ),
        );
        final revision = SubscriptionStore.getMetadata(
          'profile',
        )!.payloadRevision;
        final dialog = find.byType(AlertDialog);
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.byType(accept ? FilledButton : TextButton),
          ),
        );
        await _until(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
        await _drain(tester);
        final saved = (await _store(tester, SubscriptionStore.get('profile')))!;
        expect(saved.rawContent, 'fresh payload');
        expect(saved.outbounds.single.tag, 'fresh');
        expect(saved.lastUpdated, 456789);
        expect(saved.name, 'Fresh profile');
        expect(saved.info?.download, 999);
        expect(saved.info?.requireHwid, isTrue);
        expect(saved.info?.customUserAgent, 'Fresh UA');
        expect(saved.payloadRevision, revision);
        expect(saved.info?.ignoreSubscriptionMoved, !accept);
        expect(
          saved.info?.newUrl,
          accept ? isNull : 'https://moved.example/sub',
        );
        expect(saved.url, accept ? 'https://moved.example/sub' : original.url);
      },
    );
  }

  for (final change in ['delete', 'source', 'move', 'dismiss']) {
    _testWidgets('moved dialog $change cannot apply a stale decision', (
      tester,
    ) async {
      server.listen((request) async {
        request.response.headers.set('new-url', 'https://moved.example/sub');
        request.response.write(_response);
        await request.response.close();
      });
      await _openAndRefresh(tester);
      await _until(
        tester,
        () => find.byType(AlertDialog).evaluate().isNotEmpty,
      );
      if (change == 'delete') {
        await _store(tester, SubscriptionStore.delete('profile'));
      } else if (change == 'source' || change == 'move') {
        await _store(
          tester,
          SubscriptionStore.updateMetadata(
            'profile',
            (current) => change == 'source'
                ? current.copyWith(url: 'https://different.example/sub')
                : current.copyWith(
                    info: current.info!.copyWith(
                      newUrl: 'https://different.example/moved',
                    ),
                  ),
          ),
        );
      }
      if (change == 'dismiss') {
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      } else {
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
      }
      await _drain(tester);
      final saved = await _store(tester, SubscriptionStore.get('profile'));
      if (change == 'delete') {
        expect(saved, isNull);
      } else {
        expect(
          saved!.url,
          change == 'source'
              ? 'https://different.example/sub'
              : 'http://127.0.0.1:${server.port}/subscription',
        );
        expect(
          saved.info?.newUrl,
          change == 'move'
              ? 'https://different.example/moved'
              : 'https://moved.example/sub',
        );
        expect(saved.info?.ignoreSubscriptionMoved, isFalse);
      }
    });
  }

  for (final fail in [false, true]) {
    _testWidgets(
      'refresh ${fail ? 'failure' : 'success'} after page disposal has no UI exception',
      (tester) async {
        final received = Completer<void>();
        final release = Completer<void>();
        server.listen((request) async {
          received.complete();
          await release.future;
          if (fail) {
            request.response.statusCode = 403;
          } else {
            request.response.headers.set(
              'new-url',
              'https://moved.example/sub',
            );
            request.response.write(_response);
          }
          await request.response.close();
        });
        await _openAndRefresh(tester);
        await _until(tester, () => received.isCompleted);
        await tester.pumpWidget(const SizedBox.shrink());
        release.complete();
        await _drain(tester);
        expect(tester.takeException(), isNull);
        final saved = (await _store(tester, SubscriptionStore.get('profile')))!;
        expect(saved.rawContent, fail ? 'original' : _response);
      },
    );
  }

  _testWidgets(
    'HWID refresh handles the latest moved URL once without restoring the first payload',
    (tester) async {
      var requests = 0;
      server.listen((request) async {
        final first = requests++ == 0;
        request.response.headers.set(
          'new-url',
          first ? 'https://obsolete.example/sub' : 'https://latest.example/sub',
        );
        request.response.write(
          first
              ? _response.replaceFirst('#Node', '#Enable-HWID')
              : _response.replaceFirst('server.example', 'fresh.example'),
        );
        await request.response.close();
      });
      await _openAndRefresh(tester);
      await _until(
        tester,
        () => find.byType(AlertDialog).evaluate().isNotEmpty,
      );
      await _store(
        tester,
        SubscriptionStore.updateMetadata(
          'profile',
          (current) => current.copyWith(
            info: current.info!.copyWith(customHwid: 'fixture-id-12345'),
          ),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await _until(
        tester,
        () => find
            .textContaining('https://latest.example/sub')
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        ),
      );
      await _drain(tester);
      expect(find.byType(AlertDialog), findsNothing);
      final saved = (await _store(tester, SubscriptionStore.get('profile')))!;
      expect(
        saved.rawContent,
        _response.replaceFirst('server.example', 'fresh.example'),
      );
      expect(saved.info?.requireHwid, isTrue);
      expect(saved.info?.newUrl, 'https://latest.example/sub');
      expect(saved.info?.ignoreSubscriptionMoved, isTrue);
      expect(requests, 2);
    },
  );

  for (final fail in [false, true]) {
    _testWidgets(
      'HWID refresh ${fail ? 'failure' : 'success'} after disposal does not access page UI',
      (tester) async {
        var requests = 0;
        final received = Completer<void>();
        final release = Completer<void>();
        server.listen((request) async {
          if (requests++ == 0) {
            request.response.write(
              _response.replaceFirst('#Node', '#Enable-HWID'),
            );
          } else {
            received.complete();
            await release.future;
            if (fail) {
              request.response.statusCode = 403;
            } else {
              request.response.write(_response);
            }
          }
          await request.response.close();
        });
        await _openAndRefresh(tester);
        await _until(
          tester,
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
        );
        await _store(
          tester,
          SubscriptionStore.updateMetadata(
            'profile',
            (current) => current.copyWith(
              info: current.info!.copyWith(customHwid: 'fixture-id-12345'),
            ),
          ),
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await _until(tester, () => received.isCompleted);
        await tester.pumpWidget(const SizedBox.shrink());
        release.complete();
        await _drain(tester);
        expect(tester.takeException(), isNull);
        final saved = (await _store(tester, SubscriptionStore.get('profile')))!;
        expect(saved.info?.requireHwid, isTrue);
        expect(
          saved.rawContent,
          fail ? _response.replaceFirst('#Node', '#Enable-HWID') : _response,
        );
      },
    );
  }
}

const _response =
    'vless://3a1a58e6-e167-4d9f-8b60-34fee9ee51e9@server.example:443?encryption=none&security=tls#Node';

void _testWidgets(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await _finish(tester);
    }
  });
}

Future<void> _openAndRefresh(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 860));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const Scaffold(
        body: SubscriptionsPage(
          hapticEnabled: false,
          allowUntrustedSubscriptionCertificates: true,
        ),
      ),
    ),
  );
  await _until(tester, () => find.text('Profile').evaluate().isNotEmpty);
  await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
  await tester.pump();
  await tester.tap(find.text('Refresh').last);
  await tester.pump();
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 300 && !condition(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  var closed = false;
  final closing = SubscriptionStore.close().then((_) => closed = true);
  await _until(tester, () => closed);
  await closing;
}

Future<T> _store<T>(WidgetTester tester, Future<T> operation) async {
  var completed = false;
  final result = operation.whenComplete(() => completed = true);
  await _until(tester, () => completed);
  return result;
}
