import 'package:material_ui/material_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

export 'package:meow_client/l10n/generated/app_localizations.dart';

const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
