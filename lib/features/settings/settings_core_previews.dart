import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:meow_client/features/settings/settings_core_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/core_settings.dart';

@Preview(name: 'Core settings · dark', group: 'Settings', size: Size(392, 852))
@Preview(
  name: 'Core settings · narrow',
  group: 'Settings',
  size: Size(320, 800),
)
Widget coreSettingsPreview() => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData.dark(useMaterial3: true),
  home: SettingsCorePage(
    settings: const CoreSettings(),
    vpnInboundEnabled: true,
    noticeAcknowledged: true,
    onAcknowledgeNotice: () async {},
    onApply: (_) async => true,
  ),
);
