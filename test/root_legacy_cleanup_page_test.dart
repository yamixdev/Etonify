import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/settings/settings_root_mode_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/platform/android/root_mode_client.dart';
import 'root_mode_client_test.dart' show RootTransportFake;

void main() {
  testWidgets('legacy removal requests root only after confirmation', (
    tester,
  ) async {
    final transport = RootTransportFake();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsRootModePage(
          client: RootModeClient(transport: transport),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('root-remove')));
    await tester.pumpAndSettle();
    expect(transport.calls.map((call) => call.$1), ['snapshot']);
    await tester.tap(find.byKey(const ValueKey('root-remove-confirm')));
    await tester.pumpAndSettle();
    expect(transport.calls.map((call) => call.$1), ['snapshot', 'remove']);
    await tester.pumpWidget(const SizedBox());
    await transport.close();
  });

  testWidgets(
    'legacy cleanup cannot install, enable, update or authorize on open',
    (tester) async {
      final transport = RootTransportFake();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsRootModePage(
            client: RootModeClient(transport: transport),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(transport.calls.map((call) => call.$1), ['snapshot']);
      expect(find.byKey(const ValueKey('root-install')), findsNothing);
      expect(find.byKey(const ValueKey('root-check-update')), findsNothing);
      expect(find.byKey(const ValueKey('root-enabled')), findsNothing);
      expect(find.byKey(const ValueKey('root-check')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await transport.close();
    },
  );
}
