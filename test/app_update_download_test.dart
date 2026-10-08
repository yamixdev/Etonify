import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/update/app_update_channel.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/features/settings/settings_update_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _UpdatePaths extends PathProviderPlatform {
  _UpdatePaths(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

class _RealHttp extends HttpOverrides {}

class _DownloadServer {
  _DownloadServer(this.server) {
    server.listen((request) async {
      requests++;
      request.response.contentLength = 4;
      request.response.add([1, 2]);
      await request.response.flush();
      if (!started.isCompleted) started.complete();
      await release.future;
      request.response.add([3, 4]);
      await request.response.close();
    });
  }

  final HttpServer server;
  final started = Completer<void>();
  final release = Completer<void>();
  int requests = 0;

  AppUpdateInfo get info => AppUpdateInfo(
    version: '0.4.0',
    tagName: 'v0.4.0',
    title: 'Test',
    body: '',
    htmlUrl: 'https://example.com',
    publishedAt: null,
    asset: AppUpdateAsset(
      name: 'test.apk',
      downloadUrl: 'http://127.0.0.1:${server.port}/test.apk',
      sizeBytes: 4,
    ),
  );

  void finish() {
    if (!release.isCompleted) release.complete();
  }
}

Future<Object?> _outcome(Future<void> operation) async {
  try {
    await operation;
    return null;
  } catch (error) {
    return error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform oldPaths;
  HttpOverrides? oldHttp;
  late _DownloadServer server;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('etonify-update-download-');
    oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _UpdatePaths(root.path);
    oldHttp = HttpOverrides.current;
    HttpOverrides.global = _RealHttp();
  });
  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = oldPaths;
    HttpOverrides.global = oldHttp;
    await root.delete(recursive: true);
  });
  setUp(() async {
    await AppUpdateService.instance.cleanupOldDownloads();
    server = _DownloadServer(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
  });
  tearDown(() async {
    server.finish();
    await server.server.close(force: true);
  });

  test(
    'concurrent downloads share one writer and both receive ready',
    () async {
      final firstProgress = <AppUpdateDownloadProgress>[];
      final secondProgress = <AppUpdateDownloadProgress>[];
      final first = _outcome(
        AppUpdateService.instance.downloadUpdate(
          server.info,
          onProgress: firstProgress.add,
        ),
      );
      await server.started.future;
      final second = _outcome(
        AppUpdateService.instance.downloadUpdate(
          server.info,
          onProgress: secondProgress.add,
        ),
      );
      expect(secondProgress, isNotEmpty);
      expect(secondProgress.first, same(firstProgress.last));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      server.finish();
      final outcomes = await Future.wait([first, second]);

      expect(server.requests, 1);
      expect(outcomes, [null, null]);
      expect(firstProgress.last.done, isTrue);
      expect(secondProgress.last.filePath, firstProgress.last.filePath);
      expect(await File(firstProgress.last.filePath!).readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
    },
  );

  test('cache cleanup preserves the active partial installer', () async {
    final download = _outcome(
      AppUpdateService.instance.downloadUpdate(server.info, onProgress: (_) {}),
    );
    await server.started.future;
    // The transport writes an attempt file, then atomically promotes it to
    // this service-owned path. Cleanup must preserve both phases of its slot.
    final partial = File('${root.path}/updates/test.apk.part');
    await partial.writeAsBytes([1, 2]);
    await AppUpdateService.instance.cleanupOldDownloads();
    final preserved = partial.existsSync();
    server.finish();
    final outcome = await download;

    expect(preserved, isTrue);
    expect(outcome, isNull);
  });

  test('deleting cached installers is rejected during download', () async {
    final download = _outcome(
      AppUpdateService.instance.downloadUpdate(server.info, onProgress: (_) {}),
    );
    await server.started.future;
    final deletion = _outcome(
      AppUpdateService.instance
          .deleteCachedInstallers(currentVersion: '0.3.0')
          .then<void>((_) {}),
    );
    final deletionOutcome = await deletion;
    server.finish();
    await download;

    expect(deletionOutcome, isA<StateError>());
  });

  test(
    'channel checks and installed cleanup do not disturb a download',
    () async {
      final operation = AppUpdateService.instance.startDownload(server.info);
      await server.started.future;
      final check = await AppUpdateService.instance.checkForUpdates(
        currentVersion: '0.5.0',
        manual: true,
        channel: AppUpdateChannel.beta,
      );
      final cleanup = await AppUpdateService.instance
          .cleanupInstalledUpdateArtifacts(currentVersion: '0.5.0');
      server.finish();
      await operation.completed;

      expect(check.status, AppUpdateStatus.downloading);
      expect(check.info, same(operation.info));
      expect(cleanup.changed, isFalse);
      expect(await File(operation.progress.filePath!).readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
    },
  );

  test('a conflicting asset cannot replace the active operation', () async {
    final operation = AppUpdateService.instance.startDownload(server.info);
    await server.started.future;
    final other = AppUpdateInfo(
      version: '0.5.0',
      tagName: 'v0.5.0',
      title: 'Other',
      body: '',
      htmlUrl: '',
      publishedAt: null,
      asset: server.info.asset,
    );
    expect(
      () => AppUpdateService.instance.startDownload(other),
      throwsStateError,
    );
    expect(AppUpdateService.instance.activeDownload, same(operation));
    server.finish();
    await operation.completed;
    expect(server.requests, 1);
  });

  test('a failed download releases its slot for a retry', () async {
    final info = server.info;
    final invalid = AppUpdateInfo(
      version: info.version,
      tagName: info.tagName,
      title: info.title,
      body: info.body,
      htmlUrl: info.htmlUrl,
      publishedAt: info.publishedAt,
      asset: info.asset.copyWith(digestSha256: '0' * 64),
    );
    final failed = AppUpdateService.instance.startDownload(invalid);
    final failure = _outcome(failed.completed);
    await server.started.future;
    server.finish();
    expect(await failure, isA<FormatException>());
    expect(AppUpdateService.instance.activeDownload, isNull);
    final retry = AppUpdateService.instance.startDownload(info);
    await retry.completed;
    expect(server.requests, 2);
    expect(await File(retry.progress.filePath!).readAsBytes(), [1, 2, 3, 4]);
  });

  test('concurrent installer launches share one platform call', () async {
    final released = Completer<void>();
    var launches = 0;
    Future<void> launch() {
      launches++;
      return released.future;
    }

    final service = AppUpdateService.instance;
    final first = _outcome(
      Future<void>.sync(() => service.launchInstaller(launch)),
    );
    final second = _outcome(
      Future<void>.sync(() => service.launchInstaller(launch)),
    );
    await Future<void>.delayed(Duration.zero);
    released.complete();
    final outcomes = await Future.wait([first, second]);
    expect(launches, 1);
    expect(outcomes, [null, null]);
  });

  test('installer launch failure releases its slot for a retry', () async {
    final service = AppUpdateService.instance;
    final failure = await _outcome(
      Future<void>.sync(
        () => service.launchInstaller(
          () => Future<void>.error(StateError('platform launch failed')),
        ),
      ),
    );
    var launched = false;
    final retry = await _outcome(
      Future<void>.sync(
        () => service.launchInstaller(() async {
          launched = true;
        }),
      ),
    );
    expect(failure, isA<StateError>());
    expect(launched, isTrue);
    expect(retry, isNull);
  });

  testWidgets('reopened update page attaches to the active download', (
    tester,
  ) async {
    late Future<void> download;
    await tester.runAsync(() async {
      download = AppUpdateService.instance.downloadUpdate(
        server.info,
        onProgress: (_) {},
      );
      await server.started.future;
    });
    Widget page(Key key) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: SettingsUpdatePage(
        key: key,
        currentVersion: '0.3.0',
        installMode: AppUpdateInstallMode.auto,
      ),
    );
    await tester.pumpWidget(page(const ValueKey('first')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page(const ValueKey('reopened')));
    await tester.pump();
    final menu = tester.widget<UpdateOverflowMenu>(
      find.byType(UpdateOverflowMenu),
    );
    final menuDisabled = !menu.enabled;
    server.finish();
    await tester.runAsync(() => download);
    await tester.pump();
    await tester.runAsync(() async {});
    await tester.pump();

    expect(menuDisabled, isTrue);
    expect(server.requests, 1);
    expect(find.text('Install APK'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'double install taps reserve permission flow before verification',
    (tester) async {
      late Future<void> download;
      await tester.runAsync(() async {
        download = AppUpdateService.instance.downloadUpdate(
          server.info,
          onProgress: (_) {},
        );
        await server.started.future;
      });
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SettingsUpdatePage(currentVersion: '0.3.0'),
        ),
      );
      server.finish();
      await tester.runAsync(() => download);
      await tester.pump();
      await tester.pump();
      final installButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Install APK'),
          matching: find.byType(FilledButton),
        ),
      );
      // Invoke the still-rendered callback twice, before the next frame disables
      // the button. Windows then exposes the permission dialog boundary.
      installButton.onPressed!();
      installButton.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final dialogs = find
          .byType(AlertDialog, skipOffstage: false)
          .evaluate()
          .length;
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final retryButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Install APK'),
          matching: find.byType(FilledButton),
        ),
      );
      retryButton.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final retryDialogs = find.byType(AlertDialog).evaluate().length;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(dialogs, 1);
      expect(retryDialogs, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
