import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/app/app_root_shell.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('applies the root app configuration around its home content', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      AppRootShell(
        navigatorKey: navigatorKey,
        lightTheme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        locale: const Locale('ru'),
        progressiveBlurEnabled: false,
        hapticEnabled: true,
        home: const Scaffold(body: Text('root-home')),
        onDynamicColorSchemesChanged: (_, _) {},
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Etonify');
    expect(app.navigatorKey, same(navigatorKey));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.locale, const Locale('ru'));
    expect(app.supportedLocales, AppLocalizations.supportedLocales);
    expect(find.text('root-home'), findsOneWidget);
  });

  testWidgets('uses Russian from the system locale and English as fallback', (
    tester,
  ) async {
    // The behavior is covered through MaterialApp's callback below. Keeping
    // it in a widget test prevents a root-shell change from silently dropping
    // the English fallback used by the first launch screen.
    await tester.pumpWidget(
      AppRootShell(
        navigatorKey: GlobalKey<NavigatorState>(),
        lightTheme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.system,
        locale: null,
        progressiveBlurEnabled: false,
        hapticEnabled: false,
        home: const Placeholder(),
        onDynamicColorSchemesChanged: (_, _) {},
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.localeResolutionCallback!(const Locale('ru'), app.supportedLocales),
      const Locale('ru'),
    );
    expect(
      app.localeResolutionCallback!(const Locale('de'), app.supportedLocales),
      const Locale('en'),
    );
  });
}
