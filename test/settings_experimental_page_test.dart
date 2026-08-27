import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_experimental_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

Widget _experimentalSettingsApp({
  required void Function(bool value, {bool warningDismissed})
  onMemoryLimitChanged,
}) {
  return MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: SettingsExperimentalPage(
      currentTcpFastOpen: false,
      currentTcpMultiPath: false,
      currentInterruptExistingConnections: true,
      currentUrlTestStrictTolerance: false,
      currentFakeIpEnabled: false,
      fakeIpAvailable: true,
      currentTlsFragmentationMode: TlsFragmentationMode.disabled,
      currentMemoryLimitEnabled: true,
      currentMemoryLimitWarningDismissed: false,
      onTcpFastOpenChanged: (_) {},
      onTcpMultiPathChanged: (_) {},
      onInterruptExistingConnectionsChanged: (_) {},
      onUrlTestStrictToleranceChanged: (_) {},
      onFakeIpEnabledChanged: (_) {},
      onTlsFragmentationModeChanged: (_) {},
      onMemoryLimitChanged: onMemoryLimitChanged,
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

      bool? selected;
      bool? observedWarningDismissed;
      await tester.pumpWidget(
        _experimentalSettingsApp(
          onMemoryLimitChanged: (value, {warningDismissed = false}) {
            selected = value;
            observedWarningDismissed = warningDismissed;
          },
        ),
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
    },
  );
}
