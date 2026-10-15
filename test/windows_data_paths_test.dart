import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';
import 'package:meow_client/main.dart' as entry;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('portable disclosure is acknowledged once before continuing', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      entry.WindowsStorageStartup(
        onAcknowledged: () async {
          saved = true;
        },
        child: const MaterialApp(home: Text('Application ready')),
      ),
    );
    expect(find.textContaining('copy of the complete folder'), findsOneWidget);
    expect(find.text('Application ready'), findsNothing);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(find.text('Application ready'), findsOneWidget);
    expect(find.textContaining('copy of the complete folder'), findsNothing);
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('etonify/windows_storage'),
          (call) async => null,
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('etonify/windows_storage'),
          null,
        ),
  );
  test(
    'final portable root is not appended twice and CWD marker is ignored',
    () async {
      final temp = await Directory.systemTemp.createTemp('Тест папка Etonify ');
      addTearDown(() => temp.delete(recursive: true));
      final root = '${temp.path}/data/user';
      final paths = await AppDataPaths.resolve(
        DesktopLaunchContext(
          installationId: 'test',
          distribution: DesktopDistribution.portable,
          dataRoot: root,
          startedAtLogin: false,
          minimized: false,
          ownerPid: 1,
        ),
      );
      expect(paths.userRoot, Directory(root).absolute.path);
      expect(paths.hiveRoot, '${paths.userRoot}${Platform.pathSeparator}hive');
      expect(
        paths.stagingRoot,
        '${paths.userRoot}${Platform.pathSeparator}staging',
      );
      expect(
        paths.ruleSetRoot,
        '${paths.userRoot}${Platform.pathSeparator}rule-sets',
      );
      expect(await Directory(paths.hiveRoot).exists(), isTrue);
    },
  );
  test('relative root fails rather than falling back to CWD', () async {
    await expectLater(
      AppDataPaths.resolve(
        const DesktopLaunchContext(
          installationId: 'test',
          distribution: DesktopDistribution.installed,
          dataRoot: 'data/user',
          startedAtLogin: false,
          minimized: false,
          ownerPid: 1,
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
  test('a file or detached root fails explicitly', () async {
    final temp = await Directory.systemTemp.createTemp('etonify-blocked-');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/blocked').writeAsString('not a directory');
    await expectLater(
      AppDataPaths.resolve(
        DesktopLaunchContext(
          installationId: 'test',
          distribution: DesktopDistribution.portable,
          dataRoot: '${temp.path}/blocked/user',
          startedAtLogin: false,
          minimized: false,
          ownerPid: 1,
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
  test(
    'confirmed legacy Hive requires migration without hiding its source',
    () async {
      final temp = await Directory.systemTemp.createTemp('etonify-legacy-');
      addTearDown(() => temp.delete(recursive: true));
      final paths = await AppDataPaths.resolve(
        DesktopLaunchContext(
          installationId: 'test',
          distribution: DesktopDistribution.installed,
          dataRoot: '${temp.path}/new',
          startedAtLogin: false,
          minimized: false,
          ownerPid: 1,
        ),
      );
      final legacy = Directory('${temp.path}/Documents/meow_hive');
      await legacy.create(recursive: true);
      final source = File('${legacy.path}/app_state_secure_v1.hive');
      await source.writeAsBytes([1, 2, 3]);
      await expectLater(
        paths.ensureNoUnmigratedLegacyData(legacy.path),
        throwsA(isA<LegacyWindowsStorageException>()),
      );
      expect(await source.readAsBytes(), [1, 2, 3]);
      await File(
        '${paths.hiveRoot}/app_state_secure_v1.hive',
      ).writeAsBytes([4, 5, 6]);
      await paths.ensureNoUnmigratedLegacyData(legacy.path);
      expect(await source.readAsBytes(), [1, 2, 3]);
    },
  );
  test('empty legacy directory is not a prior database', () async {
    final temp = await Directory.systemTemp.createTemp('etonify-empty-legacy-');
    addTearDown(() => temp.delete(recursive: true));
    final paths = await AppDataPaths.resolve(
      DesktopLaunchContext(
        installationId: 'test',
        distribution: DesktopDistribution.installed,
        dataRoot: '${temp.path}/new',
        startedAtLogin: false,
        minimized: false,
        ownerPid: 1,
      ),
    );
    final legacy = await Directory(
      '${temp.path}/Documents/meow_hive',
    ).create(recursive: true);
    await paths.ensureNoUnmigratedLegacyData(legacy.path);
  });
}
