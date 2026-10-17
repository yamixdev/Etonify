import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/home/tabbed_home_shell.dart';
import 'package:meow_client/features/settings/settings_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'last settings entry scrolls above floating navigation and remains clickable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var aboutOpened = false;
      void noop() {}
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MediaQuery(
            data: const MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: 24),
            ),
            child: TabbedHomeShell(
              homeBuilder: (_, open) => const SizedBox(),
              proxiesBuilder: (_, active, back, request) => const SizedBox(),
              settingsBuilder: (_) => SettingsPage(
                onOpenGeneral: noop,
                onOpenDns: noop,
                onOpenSubscriptions: noop,
                onOpenInbound: noop,
                onOpenRouting: noop,
                onOpenSecurity: noop,
                onImportBackup: noop,
                onExportSettings: noop,
                onExportEncryptedProfile: noop,
                onExportPlainProfile: noop,
                onResetSettings: noop,
                onOpenExperimental: noop,
                onOpenLogs: noop,
                onOpenAbout: () => aboutOpened = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('settings-tab')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('settings-destinations')),
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();
      final about = find.text('About');
      expect(
        tester.getRect(about).bottom,
        lessThan(tester.getRect(find.byType(NavigationBar)).top),
      );
      await tester.tap(about);
      expect(aboutOpened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('three destinations fit narrow Russian layout with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: TabbedHomeShell(
            homeBuilder: (_, open) => const Text('Дом'),
            proxiesBuilder: (_, active, back, request) => const Text('Список'),
            settingsBuilder: (_) => const Text('Параметры'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in ['home-tab', 'proxies-tab', 'settings-tab']) {
      final target = find.byKey(ValueKey(tab));
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Параметры'), findsOneWidget);
  });

  testWidgets('settings is a retained third tab and Back returns home', (
    tester,
  ) async {
    var settingsBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: TabbedHomeShell(
          homeBuilder: (_, open) => const Text('Home content'),
          proxiesBuilder: (_, active, back, request) =>
              const Text('Proxy content'),
          settingsBuilder: (_) {
            settingsBuilds++;
            return const TextField(key: ValueKey('settings-field'));
          },
        ),
      ),
    );
    expect(settingsBuilds, 0);
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('settings-field')),
      'saved',
    );
    await tester.tap(find.byKey(const ValueKey('home-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.pumpAndSettle();
    expect(find.text('saved'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home content'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-field')), findsNothing);
  });

  testWidgets(
    'navigation floats over content within safe edges and hides for keyboard',
    (tester) async {
      Future<void> pump({double keyboard = 0, bool reduced = false}) async {
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(800, 600),
                viewPadding: const EdgeInsets.only(bottom: 24),
                viewInsets: EdgeInsets.only(bottom: keyboard),
                disableAnimations: reduced,
              ),
              child: TabbedHomeShell(
                homeBuilder: (_, open) =>
                    const SizedBox.expand(key: ValueKey('full-content')),
                proxiesBuilder: (_, active, back, request) => const SizedBox(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump();
      final bar = tester.getRect(find.byType(NavigationBar));
      expect(bar.left, greaterThan(0));
      expect(bar.right, lessThan(800));
      expect(bar.bottom, lessThanOrEqualTo(576));
      expect(
        tester.getRect(find.byKey(const ValueKey('full-content'))).bottom,
        600,
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      await pump(reduced: true);
      expect(find.byType(BackdropFilter), findsNothing);
      await pump(keyboard: 280);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets(
    'tabs mount proxies lazily and retain scroll across tab changes',
    (tester) async {
      var mounts = 0;
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: TabbedHomeShell(
            homeBuilder: (context, open) => TextButton(
              onPressed: () => open(null),
              child: const Text('Current server'),
            ),
            proxiesBuilder: (context, active, back, request) {
              mounts++;
              return ListView.builder(
                key: const PageStorageKey('servers'),
                itemCount: 300,
                itemBuilder: (_, i) =>
                    SizedBox(height: 64, child: Text('Server $i')),
              );
            },
          ),
        ),
      );
      expect(mounts, 0);
      await tester.tap(find.text('Current server'));
      await tester.pumpAndSettle();
      final list = find.byType(ListView);
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      final offset = position.pixels;
      expect(offset, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('home-tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('proxies-tab')));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        offset,
      );
    },
  );

  testWidgets(
    'current auto group creates a distinct browser request each time',
    (tester) async {
      ({int serial, String? groupTag})? request;
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: TabbedHomeShell(
            homeBuilder: (context, open) => TextButton(
              onPressed: () => open('Auto'),
              child: const Text('Open Auto'),
            ),
            proxiesBuilder: (context, active, back, value) {
              request = value;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.tap(find.text('Open Auto'));
      await tester.pumpAndSettle();
      expect(request?.groupTag, 'Auto');
      final serial = request!.serial;
      await tester.tap(find.byKey(const ValueKey('home-tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Auto'));
      await tester.pumpAndSettle();
      expect(request?.groupTag, 'Auto');
      expect(request!.serial, greaterThan(serial));
    },
  );
}
