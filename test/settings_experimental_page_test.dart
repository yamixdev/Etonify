import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/features/settings/settings_experimental_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

Widget _experimentalSettingsApp({
  required ProviderContainer container,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: SettingsExperimentalPage(),
    ),
  );
}

void main() {
  testWidgets(
    'experimental settings owns the soft core memory limit and warning',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AppSettingsController()
        ..memoryLimitEnabled = true
        ..memoryLimitWarningDismissed = false;
      final commands = AppSettingsCommands();
      final container = ProviderContainer(
        overrides: [
          appSettingsControllerProvider.overrideWithValue(controller),
          appSettingsCommandsProvider.overrideWithValue(commands),
        ],
      );
      addTearDown(container.dispose);

      bool? selected;
      bool? observedWarningDismissed;
      commands.bindExperimentalHandlers(
        setExperimentalTcpFastOpen: (_) {},
        setExperimentalTcpMultiPath: (_) {},
        setExperimentalInterruptExistingConnections: (_) {},
        setExperimentalUrlTestStrictTolerance: (_) {},
        setExperimentalFakeIpEnabled: (_) {},
        setTlsFragmentationMode: (_) {},
        setMemoryLimitEnabled: (value, {warningDismissed = false}) {
          selected = value;
          observedWarningDismissed = warningDismissed;
          container
              .read(appSettingsProvider.notifier)
              .mutate(
                (c) => c.setMemoryLimitEnabled(
                  value,
                  warningDismissed: warningDismissed,
                ),
              );
        },
      );

      await tester.pumpWidget(
        _experimentalSettingsApp(container: container),
      );

      await tester.ensureVisible(find.text('Soft core memory limit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Soft core memory limit'));
      await tester.pumpAndSettle();

      expect(find.text('Disable the soft core limit?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Disable'));
      await tester.pumpAndSettle();

      expect(selected, isFalse);
      expect(observedWarningDismissed, isTrue);
      expect(
        container.read(appSettingsProvider).controller.memoryLimitEnabled,
        isFalse,
      );
      expect(
        container
            .read(appSettingsProvider)
            .controller
            .memoryLimitWarningDismissed,
        isTrue,
      );
    },
  );
}
