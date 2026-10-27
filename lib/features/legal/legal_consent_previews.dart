import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:meow_client/features/legal/legal_consent_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/theme/app_theme.dart';

@Preview(name: 'Disclaimer · dark', size: Size(390, 844))
Widget legalDarkPreview() => legalPreviewApp(Brightness.dark);

@Preview(name: 'Disclaimer · light', size: Size(390, 844))
Widget legalLightPreview() => legalPreviewApp(Brightness.light);

Widget legalPreviewApp(Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('ru'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: buildAppTheme(brightness, seedColor: const Color(0xff8b4c14)),
  home: LegalConsentPage(
    requiredVersion: '0.2.1',
    onAccept: acceptLegalPreview,
  ),
);

void acceptLegalPreview() {}
