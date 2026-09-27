import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meow_client/app/dynamic_color_scheme_adapter.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/app_scroll_effects.dart';
import 'package:meow_client/widgets/app_visual_effects.dart';

typedef DynamicColorSchemesChanged =
    void Function(ColorScheme? light, ColorScheme? dark);

/// Owns the framework-level application composition.
///
/// Runtime state stays in [MeowClient], while this widget keeps theme,
/// localization and system-bar setup out of the VPN state object.
class AppRootShell extends StatelessWidget {
  const AppRootShell({
    super.key,
    required this.navigatorKey,
    required this.lightTheme,
    required this.darkTheme,
    required this.themeMode,
    required this.locale,
    required this.progressiveBlurEnabled,
    required this.hapticEnabled,
    required this.home,
    required this.onDynamicColorSchemesChanged,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode themeMode;
  final Locale? locale;
  final bool progressiveBlurEnabled;
  final bool hapticEnabled;
  final Widget home;
  final DynamicColorSchemesChanged onDynamicColorSchemesChanged;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        onDynamicColorSchemesChanged(
          lightDynamic == null ? null : toFlutterColorScheme(lightDynamic),
          darkDynamic == null ? null : toFlutterColorScheme(darkDynamic),
        );
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Etonify',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          localeResolutionCallback: (locale, supportedLocales) {
            if (this.locale != null) {
              return this.locale;
            }
            if (locale?.languageCode.toLowerCase() == 'ru') {
              return const Locale('ru');
            }
            return const Locale('en');
          },
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            final overlayStyle = SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
              statusBarIconBrightness: brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarIconBrightness: brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: brightness == Brightness.dark
                  ? Brightness.dark
                  : Brightness.light,
            );
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyle,
              child: AppVisualEffects(
                progressiveBlurEnabled: progressiveBlurEnabled,
                hapticEnabled: hapticEnabled,
                child: AppScrollEffects(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          home: home,
        );
      },
    );
  }
}
