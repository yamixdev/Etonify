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
  Locale? locale,
  double textScale = 1,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const SettingsExperimentalPage(),
    ),
  );
}

void main() {
  testWidgets('TLS picker remains usable on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _experimentalSettingsApp(
        container: container,
        locale: const Locale('ru'),
        textScale: 1.6,
      ),
    );
    await tester.ensureVisible(find.text('Фрагментация TLS'));
    await tester.tap(find.text('Фрагментация TLS'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The last choice must remain reachable even when descriptions wrap.
    final context = tester.element(find.byType(SettingsExperimentalPage));
    final label = AppLocalizations.of(context).tlsFragmentationModeFragment;
    final option = find.widgetWithText(ListTile, label);
    final optionLabel = find.descendant(of: option, matching: find.text(label));
    await tester.ensureVisible(optionLabel);
    await tester.pumpAndSettle();
    expect(optionLabel.hitTestable(), findsOneWidget);
    await tester.tap(optionLabel);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('descriptions use the card width below the controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_experimentalSettingsApp(container: container));
    final context = tester.element(find.byType(SettingsExperimentalPage));
    final l10n = AppLocalizations.of(context);
    final title = find.text(l10n.experimentalTcpFastOpenTitle);
    final description = find.text(l10n.experimentalTcpFastOpenSubtitle);
    await tester.ensureVisible(description);
    await tester.pumpAndSettle();
    final titleRect = tester.getRect(title);
    final descriptionRect = tester.getRect(description);
    expect(descriptionRect.top, greaterThan(titleRect.bottom));
    expect(descriptionRect.width, greaterThan(270));
    expect(descriptionRect.left, lessThan(titleRect.left));
    expect(tester.takeException(), isNull);
  });

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

      await tester.pumpWidget(_experimentalSettingsApp(container: container));

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
