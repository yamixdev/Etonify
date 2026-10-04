import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/features/settings/settings_logs_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/logging/app_log_store.dart';

Widget _logsApp({
  String singBoxLogLevel = 'warning',
  ValueChanged<String>? onSingBoxLogLevelChanged,
}) {
  final controller = AppSettingsController()..singBoxLogLevel = singBoxLogLevel;
  final commands = AppSettingsCommands();
  final container = ProviderContainer(
    overrides: [
      appSettingsControllerProvider.overrideWithValue(controller),
      appSettingsCommandsProvider.overrideWithValue(commands),
    ],
  );
  commands.bindLogsHandlers(
    setSingBoxLogLevel: (value) {
      container.read(appSettingsProvider.notifier).mutate((c) {
        return c.setSingBoxLogLevel(value);
      });
      onSingBoxLogLevelChanged?.call(value);
    },
  );

  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      locale: Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: SettingsLogsPage(),
    ),
  );
}

void main() {
  setUp(() {
    AppLogStore.clear();
  });

  testWidgets('renders logs page with empty notice when no logs exist', (
    tester,
  ) async {
    await tester.pumpWidget(_logsApp());
    await tester.pumpAndSettle();

    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('No logs yet'), findsOneWidget);
    expect(find.byTooltip('Jump to latest entries'), findsNothing);
  });

  testWidgets('jumps to the latest log without following new entries', (
    tester,
  ) async {
    for (var index = 0; index < 60; index++) {
      AppLogStore.info('entry-$index', 'Log message $index');
    }
    await tester.pumpWidget(_logsApp());
    await tester.pumpAndSettle();

    final jump = find.byTooltip('Jump to latest entries');
    expect(jump, findsOneWidget);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, 0);
    await tester.tap(jump);
    await tester.pumpAndSettle();
    expect(
      scrollable.position.pixels,
      closeTo(scrollable.position.maxScrollExtent, 1),
    );
    expect(find.text('Log message 59'), findsOneWidget);

    scrollable.position.jumpTo(400);
    await tester.pumpAndSettle();
    final previousOffset = scrollable.position.pixels;
    AppLogStore.info('entry-new', 'New log must not move the viewport');
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, previousOffset);
    await tester.tap(jump);
    await tester.pumpAndSettle();
    expect(find.text('New log must not move the viewport'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('jump action handles logs being cleared before a tap', (
    tester,
  ) async {
    AppLogStore.info('test', 'Short log');
    await tester.pumpWidget(_logsApp());
    await tester.pumpAndSettle();
    final jump = find.byTooltip('Jump to latest entries');
    expect(jump, findsOneWidget);
    AppLogStore.clear();
    await tester.pumpAndSettle();
    expect(jump, findsNothing);
    expect(find.text('No logs yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders logs entries and can open details', (tester) async {
    AppLogStore.info('test-tag', 'Sample log message here');

    await tester.pumpWidget(_logsApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('test-tag'), findsOneWidget);
    expect(find.textContaining('Sample log message here'), findsOneWidget);
  });

  testWidgets('can pick a new sing-box log level from menu', (tester) async {
    final changedLevels = <String>[];
    await tester.pumpWidget(
      _logsApp(
        singBoxLogLevel: 'warn',
        onSingBoxLogLevelChanged: changedLevels.add,
      ),
    );
    await tester.pumpAndSettle();

    // Open popup menu
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    // Tap Sing-box log level menu item
    await tester.tap(find.text('sing-box log level'));
    await tester.pumpAndSettle();

    // Select 'DEBUG' from bottom sheet
    await tester.tap(find.text('DEBUG'));
    await tester.pumpAndSettle();

    expect(changedLevels, ['debug']);
  });
}
