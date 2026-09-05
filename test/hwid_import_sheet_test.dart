import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/deep_link_import.dart';
import 'package:meow_client/app/widgets/deep_link_import_sheet.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  for (final enabled in [false, true]) {
    testWidgets('Happ import HWID question with global consent=$enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: DeepLinkImportSheet(
                request: DeepLinkImportRequest.fromPayload({
                  'url': 'https://example.com/sub',
                  'scheme': 'happ',
                })!,
                preview: const DeepLinkImportPreview(
                  sourceUrl: 'happ://add/https://example.com/sub',
                  resolvedUrl: 'https://example.com/sub',
                  requestInfo: SubscriptionInfo(requireHwid: true),
                ),
                hwidSharingEnabled: enabled,
                copy: DeepLinkImportCopy.fromContext(context),
                l10n: AppLocalizations.of(context),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DeepLinkImportSheet)),
      );
      expect(
        find.text(l10n.deepLinkImportHappSendHwidAction),
        enabled ? findsNothing : findsOneWidget,
      );
      expect(
        find.text(l10n.deepLinkImportHappWithoutHwidAction),
        enabled ? findsNothing : findsOneWidget,
      );
      expect(
        find.text(l10n.deepLinkImportAction),
        enabled ? findsOneWidget : findsNothing,
      );
      expect(find.text(l10n.cancel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
