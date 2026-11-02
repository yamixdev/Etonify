import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/settings/settings_root_mode_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/platform/android/root_mode_client.dart';

import 'root_mode_client_test.dart' show RootTransportFake, statusMap;

Widget rootApp(
  RootTransportFake transport, {
  double scale = 1,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: SettingsRootModePage(client: RootModeClient(transport: transport)),
);

Future<void> reveal(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  for (final entry in <String, String>{
    'runtime_busy': 'Stop the current connection before changing Root Mode.',
    'su_not_found': 'Superuser access is unavailable',
    'root_command_timeout':
        'The root command timed out. Check your superuser manager and try again.',
    'release_discovery_failed':
        'The published module release is unavailable. Try again later.',
    'module_release_unavailable':
        'The published module release is unavailable. Try again later.',
    'download_http_error':
        'The module could not be downloaded. Check your connection and try again.',
    'healthcheck_failed':
        'The module could not start correctly. Reinstall it or keep using VPN mode.',
    'module_healthcheck_failed':
        'The module could not start correctly. Reinstall it or keep using VPN mode.',
    'activation_failed':
        'The module could not start correctly. Reinstall it or keep using VPN mode.',
    'module_activation_failed':
        'The module could not start correctly. Reinstall it or keep using VPN mode.',
    'module_cleanup_failed':
        'Safe cleanup could not finish. Root Mode was not activated. Keep using VPN mode and share the diagnostic code with the developer.',
    'module_cleanup_work_dir_denied':
        'The module cannot access its private working directory. Keep using VPN mode and share the diagnostic code with the developer.',
    'module_cleanup_lock_denied':
        'The module could not access its runtime lock. Root Mode was not activated.',
    'module_cleanup_journal_denied':
        'Previous session data could not be verified. Cleanup was stopped to avoid changing unrelated network settings.',
    'module_cleanup_cleanup_failed':
        'Safe cleanup could not finish. Root Mode was not activated. Keep using VPN mode and share the diagnostic code with the developer.',
    'integrity_failed':
        'Module verification failed. It will not be installed or started.',
    'module_integrity_failed':
        'Module verification failed. It will not be installed or started.',
    'unknown_safe_code':
        'The operation could not be completed. Try again or use VPN mode.',
  }.entries) {
    testWidgets('failure ${entry.key} gives specific guidance and safe code', (
      tester,
    ) async {
      final transport = RootTransportFake()
        ..response = {...statusMap(), 'reason': entry.key};
      await tester.pumpWidget(rootApp(transport));
      await tester.pumpAndSettle();
      await reveal(tester, 'root-reason');
      expect(find.text(entry.value), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SelectableText && widget.data == entry.key,
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await transport.close();
    });
  }

  testWidgets('installation explanation stays behind explicit disclosure', (
    tester,
  ) async {
    final transport = RootTransportFake();
    await tester.pumpWidget(rootApp(transport));
    await tester.pumpAndSettle();
    expect(find.textContaining('Magisk'), findsNothing);
    await reveal(tester, 'root-info');
    await tester.tap(find.byKey(const ValueKey('root-info')));
    await tester.pumpAndSettle();
    expect(find.textContaining('not a Magisk ZIP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await transport.close();
  });

  testWidgets(
    'own pending install remains cancellable without duplicate requests',
    (tester) async {
      final transport = RootTransportFake();
      final install = Completer<Object?>();
      final cancel = Completer<Object?>();
      final downloading = {
        ...statusMap(module: 'downloading', busy: true),
        'progress': .3,
      };
      await tester.pumpWidget(rootApp(transport));
      await tester.pumpAndSettle();
      transport.handler = (method) =>
          method == 'cancel' ? cancel.future : install.future;
      await reveal(tester, 'root-install');
      await tester.tap(find.byKey(const ValueKey('root-install')));
      await tester.pump();
      transport.controller.add(downloading);
      await tester.pump();
      await reveal(tester, 'root-cancel');
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('root-cancel')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('root-cancel')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('root-cancel')));
      expect(
        transport.calls.where((call) => call.$1 == 'cancel'),
        hasLength(1),
      );
      final stopped = {...statusMap(), 'reason': 'operation_cancelled'};
      transport.controller.add(stopped);
      install.complete(stopped);
      await tester.pump();
      cancel.complete(downloading);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('root-cancel')), findsNothing);
      expect(find.text('Operation cancelled.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('root-install')))
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      await transport.close();
    },
  );

  for (final available in [true, false]) {
    testWidgets(
      'update check displays ${available ? 'new version' : 'up to date'}',
      (tester) async {
        final transport = RootTransportFake();
        await tester.pumpWidget(rootApp(transport));
        await tester.pumpAndSettle();
        transport.response = {
          ...statusMap(),
          'updateAvailable': available,
          'availableModuleVersion': available ? '2.0.0' : '1.2.3',
        };
        await reveal(tester, 'root-check-update');
        await tester.tap(find.byKey(const ValueKey('root-check-update')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            available
                ? 'Module version 2.0.0 is available'
                : 'The module is up to date',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await transport.close();
      },
    );
  }

  testWidgets('failed update check does not report that module is up to date', (
    tester,
  ) async {
    final transport = RootTransportFake();
    await tester.pumpWidget(rootApp(transport));
    await tester.pumpAndSettle();
    transport.response = {
      ...statusMap(),
      'reason': 'release_discovery_failed',
      'updateAvailable': false,
      'availableModuleVersion': null,
    };
    await reveal(tester, 'root-check-update');
    await tester.tap(find.byKey(const ValueKey('root-check-update')));
    await tester.pumpAndSettle();
    expect(find.text('The module is up to date'), findsNothing);
    expect(find.byKey(const ValueKey('root-reason')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await transport.close();
  });

  testWidgets('covered route stops native events until page is visible again', (
    tester,
  ) async {
    final transport = RootTransportFake();
    await tester.pumpWidget(rootApp(transport));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SettingsRootModePage));
    final route = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Other page')),
    );
    unawaited(Navigator.of(context).push(route));
    await tester.pumpAndSettle();
    expect(transport.controller.hasListener, isFalse);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(transport.controller.hasListener, isTrue);
    expect(transport.calls, [('snapshot', null)]);
    await tester.pumpWidget(const SizedBox());
    await transport.close();
  });

  testWidgets(
    'switch sends explicit native enable request only after readiness',
    (tester) async {
      final transport = RootTransportFake();
      await tester.pumpWidget(rootApp(transport));
      await tester.pumpAndSettle();
      await reveal(tester, 'root-enabled');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(transport.calls.last.$1, 'setEnabled');
      expect(transport.calls.last.$2, {'enabled': true});
      transport.controller.add(statusMap(root: 'denied', enabled: true));
      await tester.pumpAndSettle();
      final tile = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('root-enabled')),
      );
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNotNull);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(transport.calls.last.$1, 'setEnabled');
      expect(transport.calls.last.$2, {'enabled': false});
      await tester.pumpWidget(const SizedBox());
      await transport.controller.close();
    },
  );

  testWidgets('late initial snapshot cannot overwrite a newer event', (
    tester,
  ) async {
    final transport = RootTransportFake();
    final snapshot = Completer<Object?>();
    transport.handler = (_) => snapshot.future;
    await tester.pumpWidget(rootApp(transport));
    transport.controller.add(statusMap());
    await tester.pumpAndSettle();
    snapshot.complete(statusMap(root: 'unknown', module: 'notInstalled'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('root-enabled')))
          .onChanged,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    await transport.controller.close();
  });

  testWidgets('pending native operation can finish after disposal safely', (
    tester,
  ) async {
    final transport = RootTransportFake();
    await tester.pumpWidget(rootApp(transport));
    await tester.pumpAndSettle();
    final operation = Completer<Object?>();
    transport.handler = (_) => operation.future;
    await reveal(tester, 'root-check');
    await tester.tap(find.byKey(const ValueKey('root-check')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    operation.complete(statusMap());
    await tester.pump();
    expect(tester.takeException(), isNull);
    await transport.controller.close();
  });

  testWidgets('open only snapshots and never requests root or downloads', (
    tester,
  ) async {
    final transport = RootTransportFake()
      ..response = statusMap(root: 'unknown', module: 'notInstalled');
    await tester.pumpWidget(rootApp(transport));
    await tester.pumpAndSettle();
    expect(transport.calls, [('snapshot', null)]);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('root-enabled')))
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('root-install')))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    await transport.controller.close();
  });

  testWidgets('busy state immediately blocks all repeated operations', (
    tester,
  ) async {
    final transport = RootTransportFake();
    final operation = Completer<Object?>();
    await tester.pumpWidget(rootApp(transport));
    await tester.pumpAndSettle();
    transport.handler = (_) => operation.future;
    await reveal(tester, 'root-install');
    await tester.tap(find.byKey(const ValueKey('root-install')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('root-install')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('root-enabled')))
          .onChanged,
      isNull,
    );
    operation.complete({
      ...statusMap(),
      'busy': true,
      'moduleState': 'downloading',
      'progress': .4,
    });
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('root-progress')),
          )
          .value,
      .4,
    );
    await tester.pumpWidget(const SizedBox());
    await transport.controller.close();
  });

  testWidgets('remove requires explicit confirmation', (tester) async {
    final transport = RootTransportFake();
    await tester.pumpWidget(rootApp(transport));
    await tester.pumpAndSettle();
    await reveal(tester, 'root-remove');
    await tester.tap(find.byKey(const ValueKey('root-remove')));
    await tester.pumpAndSettle();
    expect(transport.calls.where((call) => call.$1 == 'remove'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('root-remove-confirm')));
    await tester.pumpAndSettle();
    expect(transport.calls.where((call) => call.$1 == 'remove'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await transport.controller.close();
  });

  testWidgets(
    'live status updates enable switch and disposal cancels listener',
    (tester) async {
      final transport = RootTransportFake()
        ..response = statusMap(root: 'unknown', module: 'notInstalled');
      await tester.pumpWidget(rootApp(transport));
      await tester.pumpAndSettle();
      transport.controller.add(statusMap());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const ValueKey('root-enabled')))
            .onChanged,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      expect(transport.controller.hasListener, isFalse);
      transport.controller.add(statusMap(enabled: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await transport.controller.close();
    },
  );

  testWidgets(
    'paused page stops listening and resume refreshes without authorization',
    (tester) async {
      final transport = RootTransportFake();
      await tester.pumpWidget(rootApp(transport));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(transport.controller.hasListener, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(transport.controller.hasListener, isTrue);
      expect(transport.calls, [('snapshot', null), ('snapshot', null)]);
      await tester.pumpWidget(const SizedBox());
      await transport.controller.close();
    },
  );

  for (final language in ['en', 'ru']) {
    testWidgets(
      'narrow $language screen with large font stays scrollable without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final transport = RootTransportFake();
        await tester.pumpWidget(
          rootApp(transport, scale: 2, locale: Locale(language)),
        );
        await tester.pumpAndSettle();
        await reveal(tester, 'root-remove');
        expect(tester.takeException(), isNull);
        await reveal(tester, 'root-info');
        await tester.tap(find.byKey(const ValueKey('root-info')));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await transport.controller.close();
      },
    );
  }
}
