import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/features/legal/legal_consent_page.dart';
import 'package:meow_client/l10n/app_localizations.dart';
import 'package:meow_client/theme/app_theme.dart';

@Preview(name: 'Disclaimer · dark', size: Size(390, 844))
Widget legalDarkPreview() => legalPreviewApp(Brightness.dark);

@Preview(name: 'Disclaimer · light', size: Size(390, 844))
Widget legalLightPreview() => legalPreviewApp(Brightness.light);

Widget legalPreviewApp(Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('ru'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  theme: buildAppTheme(brightness, seedColor: const Color(0xff8b4c14)),
  home: LegalConsentPage(
    requiredVersion: '0.2.1',
    onAccept: acceptLegalPreview,
  ),
);

void acceptLegalPreview() {}
