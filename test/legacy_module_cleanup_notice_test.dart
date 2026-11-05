import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/platform/android/legacy_module_cleanup_client.dart';
import 'package:meow_client/widgets/legacy_module_cleanup_notice.dart';
import 'legacy_module_cleanup_client_test.dart'
    show RootTransportFake, statusMap;

void main() {
  for (final accept in [false, true]) {
    testWidgets(
      'legacy prompt acknowledges once and requests cleanup only on accept=$accept',
      (tester) async {
        final transport = RootTransportFake()
          ..response = {...statusMap(), 'promptPending': true};
        transport.handler = (method) async => {
          ...statusMap(module: method == 'remove' ? 'notInstalled' : 'ready'),
          'promptPending': method == 'snapshot',
        };
        final client = LegacyModuleCleanupClient(transport: transport);
        Widget app(bool enabled) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LegacyModuleCleanupNotice(
            enabled: enabled,
            client: client,
            child: const Scaffold(body: Text('Home')),
          ),
        );
        await tester.pumpWidget(app(false));
        await tester.pumpAndSettle();
        expect(transport.calls, isEmpty);
        await tester.pumpWidget(app(true));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(transport.calls.map((c) => c.$1), ['snapshot']);
        await tester.tap(
          find.byKey(
            ValueKey(
              accept ? 'legacy-cleanup-confirm' : 'legacy-cleanup-later',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          transport.calls.map((c) => c.$1),
          accept
              ? ['snapshot', 'acknowledgePrompt', 'remove']
              : ['snapshot', 'acknowledgePrompt'],
        );
        await tester.pumpWidget(app(false));
        await tester.pumpWidget(app(true));
        await tester.pumpAndSettle();
        expect(transport.calls.where((c) => c.$1 == 'snapshot'), hasLength(1));
        await tester.pumpWidget(const SizedBox());
        await transport.close();
      },
    );
  }
  testWidgets('clean installation never shows a removal prompt', (
    tester,
  ) async {
    final transport = RootTransportFake()
      ..response = {
        ...statusMap(module: 'notInstalled'),
        'promptPending': false,
      };
    await tester.pumpWidget(
      MaterialApp(
        home: LegacyModuleCleanupNotice(
          client: LegacyModuleCleanupClient(transport: transport),
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(transport.calls.map((c) => c.$1), ['snapshot']);
    await tester.pumpWidget(const SizedBox());
    await transport.close();
  });
}
