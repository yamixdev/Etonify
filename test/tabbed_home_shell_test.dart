import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/home/tabbed_home_shell.dart';
import 'package:meow_client/features/settings/settings_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/floating_navigation_insets.dart';

void main() {
  for (final style in BottomNavigationStyle.values) {
    testWidgets('navigation blends with page background ${style.name}', (
      tester,
    ) async {
      final theme = ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xff1b1c1d),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: TabbedHomeShell(
            bottomNavigationStyle: style,
            homeBuilder: (_, open) => const Text('Home body'),
            proxiesBuilder: (_, active, back, request) =>
                const Text('Proxies body'),
            settingsBuilder: (_) => const Text('Settings body'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester.widget<Material>(
        find
            .ancestor(of: _navigation(style), matching: find.byType(Material))
            .first,
      );
      final rendered = Color.alphaBlend(
        surface.color!,
        theme.scaffoldBackgroundColor,
      );
      expect(
        (rendered.computeLuminance() -
                theme.scaffoldBackgroundColor.computeLuminance())
            .abs(),
        lessThan(.007),
      );
      if (style == BottomNavigationStyle.docked) {
        expect(surface.color, theme.scaffoldBackgroundColor);
        final decorations = tester.widgetList<DecoratedBox>(
          find.ancestor(
            of: _navigation(style),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          decorations.where(
            (widget) =>
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).border != null,
          ),
          isEmpty,
        );
      }
    });
  }

  testWidgets(
    'tab content fades promptly and interrupts without losing state',
    (tester) async {
      await tester.pumpWidget(_scrubApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('proxies-tab')));
      await tester.pump();
      final content = find.byKey(const ValueKey('home-tab-content-transition'));
      expect(content, findsOneWidget);
      expect(tester.widget<FadeTransition>(content).opacity.value, lessThan(1));
      expect(find.text('Proxies body').hitTestable(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.byKey(const ValueKey('settings-tab')));
      await tester.pump();
      expect(find.text('Settings body').hitTestable(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.widget<FadeTransition>(content).opacity.value, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'docked surface spans landscape while destinations avoid unsafe edges',
    (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _scrubApp(
          style: BottomNavigationStyle.docked,
          safeLeft: 44,
          safeRight: 24,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(NavigationBar)),
        const Rect.fromLTWH(44, 340, 732, 60),
      );
      expect(
        tester.getRect(
          find
              .ancestor(
                of: find.byType(NavigationBar),
                matching: find.byType(Material),
              )
              .first,
        ),
        const Rect.fromLTWH(0, 340, 800, 60),
      );
    },
  );
  testWidgets('docked navigation is flush and reserves its safe inset once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _scrubApp(
        style: BottomNavigationStyle.docked,
        safeTop: 32,
        safeBottom: 24,
      ),
    );
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(NavigationBar));
    expect(bar, const Rect.fromLTWH(0, 766, 393, 60));
    expect(find.byType(BackdropFilter), findsNothing);
    final material = tester
        .widgetList<Material>(
          find.ancestor(
            of: find.byType(NavigationBar),
            matching: find.byType(Material),
          ),
        )
        .first;
    expect(material.color?.a, 1);
    expect(
      tester.getRect(
        find
            .ancestor(
              of: find.byType(NavigationBar),
              matching: find.byType(Material),
            )
            .first,
      ),
      const Rect.fromLTWH(0, 766, 393, 84),
    );
    expect(
      FloatingNavigationInsets.of(tester.element(find.text('Home body'))),
      0,
    );
    expect(find.byKey(const ValueKey('settings-tab')), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.bottomNavigationBar, isNotNull);
    for (final key in ['home-tab', 'proxies-tab']) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  for (final rtl in [false, true]) {
    testWidgets('docked scrub commits rectangular outer corner rtl=$rtl', (
      tester,
    ) async {
      await tester.pumpWidget(
        _scrubApp(style: BottomNavigationStyle.docked, rtl: rtl),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('home-tab'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final bar = tester.getRect(find.byType(NavigationBar));
      await gesture.moveTo(
        Offset(rtl ? bar.left + 1 : bar.right - 1, bar.top + 1),
      );
      await tester.pump();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(find.text('Home body'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Proxies body'), findsOneWidget);
    });
  }

  testWidgets('docked scrub cancels outside the bar and hides for keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(_scrubApp(style: BottomNavigationStyle.docked));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('home-tab'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('proxies-tab'))),
    );
    await tester.pump();
    final bar = tester.getRect(find.byType(NavigationBar));
    await gesture.moveTo(Offset(bar.center.dx, bar.top - 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Home body'), findsOneWidget);
    await tester.pumpWidget(
      _scrubApp(style: BottomNavigationStyle.docked, keyboard: 280),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
  });
  testWidgets('a same-tab group request cancels an older held selection', (
    tester,
  ) async {
    late ValueChanged<String?> open;
    ({int serial, String? groupTag})? request;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: TabbedHomeShell(
          homeBuilder: (_, callback) {
            open = callback;
            return const Text('Home body');
          },
          proxiesBuilder: (_, active, back, value) {
            request = value;
            return const Text('Proxies body');
          },
          settingsBuilder: (_) => const Text('Settings body'),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('proxies-tab')));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('proxies-tab'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('settings-tab'))),
    );
    await tester.pump();
    open('Auto');
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(request?.groupTag, 'Auto');
    expect(find.text('Proxies body'), findsOneWidget);
  });

  testWidgets(
    'an external navigation request cancels an older held selection',
    (tester) async {
      late ValueChanged<String?> open;
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: TabbedHomeShell(
            homeBuilder: (_, callback) {
              open = callback;
              return const Text('Home body');
            },
            proxiesBuilder: (_, active, back, request) =>
                const Text('Proxies body'),
            settingsBuilder: (_) => const Text('Settings body'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('home-tab'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('settings-tab'))),
      );
      await tester.pump();
      open(null);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Proxies body'), findsOneWidget);
    },
  );

  testWidgets(
    'floating navigation is compact without shrinking touch targets',
    (tester) async {
      tester.view.physicalSize = const Size(393, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_scrubApp(safeTop: 32, safeBottom: 24));
      await tester.pumpAndSettle();
      final bar = tester.getRect(_navigation(BottomNavigationStyle.floating));
      expect(bar.height, inInclusiveRange(52, 56));
      expect(bar.width, lessThanOrEqualTo(300));
      expect(bar.center.dx, closeTo(196.5, .1));
      expect(bar.bottom, 818);
      for (final key in ['home-tab', 'proxies-tab', 'settings-tab']) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      final home = tester.getRect(find.byKey(const ValueKey('home-tab')));
      final proxies = tester.getRect(find.byKey(const ValueKey('proxies-tab')));
      expect(home.width, greaterThan(proxies.width));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Proxies'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      final icon = tester.getCenter(find.byIcon(Icons.home_rounded));
      final label = tester.getCenter(find.text('Home'));
      expect(icon.dy, closeTo(label.dy, 1));
    },
  );

  for (final rtl in [false, true]) {
    testWidgets('floating pill hugs and centers each visible label rtl=$rtl', (
      tester,
    ) async {
      await tester.pumpWidget(_scrubApp(rtl: rtl));
      await tester.pumpAndSettle();
      final bar = tester.getRect(_navigation(BottomNavigationStyle.floating));
      final widths = <double>[];
      for (final (key, label, icon) in [
        ('home-tab', 'Home', Icons.home_rounded),
        ('proxies-tab', 'Proxies', Icons.dns_rounded),
        ('settings-tab', 'Settings', Icons.settings_rounded),
      ]) {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        final pill = tester.getRect(
          find.byKey(const ValueKey('floating-navigation-indicator')),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: label.length),
        );
        final text = boxes
            .map((box) => box.toRect())
            .reduce((a, b) => a.expandToInclude(b));
        final textRect = text.shift(paragraph.localToGlobal(Offset.zero));
        final content = textRect.expandToInclude(
          tester.getRect(find.byIcon(icon)),
        );
        expect(content.left - pill.left, closeTo(12, .5));
        expect(pill.right - content.right, closeTo(12, .5));
        expect(content.center.dx, closeTo(pill.center.dx, .5));
        expect(
          tester.getRect(_navigation(BottomNavigationStyle.floating)),
          bar,
        );
        widths.add(pill.width);
      }
      expect(widths.last, greaterThan(widths.first + 20));
      expect(tester.takeException(), isNull);
    });
  }

  for (final rtl in [false, true]) {
    testWidgets('scrub follows expanded target bounds rtl=$rtl', (
      tester,
    ) async {
      await tester.pumpWidget(_scrubApp(rtl: rtl));
      await tester.pumpAndSettle();
      final home = tester.getRect(find.byKey(const ValueKey('home-tab')));
      final gesture = await tester.startGesture(home.center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        Offset(rtl ? home.left + 6 : home.right - 6, home.center.dy),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Home body'), findsOneWidget);
    });
  }

  for (final rtl in [false, true]) {
    testWidgets('scrub resolves moving item bounds rtl=$rtl', (tester) async {
      await tester.pumpWidget(_scrubApp(rtl: rtl));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('home-tab'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('proxies-tab'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 35));
      final home = tester.getRect(find.byKey(const ValueKey('home-tab')));
      await gesture.moveTo(
        Offset(rtl ? home.left + 2 : home.right - 2, home.center.dy),
      );
      await tester.pump();
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('home-tab')))
            .properties
            .selected,
        isTrue,
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.text('Home body'), findsOneWidget);
    });
  }

  testWidgets('focused floating destination has a visible perimeter', (
    tester,
  ) async {
    await tester.pumpWidget(_scrubApp());
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final homeSemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('home-tab')),
    );
    expect(homeSemantics.properties.focused, isTrue);
    final decorations = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('home-tab')),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      decorations.where((widget) {
        final decoration = widget.decoration;
        return decoration is ShapeDecoration &&
            decoration.shape is OutlinedBorder &&
            (decoration.shape as OutlinedBorder).side.width >= 2 &&
            (decoration.shape as OutlinedBorder).side.color.a > 0;
      }),
      isNotEmpty,
    );
  });

  testWidgets(
    'floating indicator follows selection without moving in reduced motion',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_scrubApp(reduced: true));
      await tester.pumpAndSettle();
      for (final tab in ['home-tab', 'proxies-tab', 'settings-tab']) {
        final target = find.byKey(ValueKey(tab));
        expect(
          tester.getSemantics(target).getSemanticsData().label,
          isNotEmpty,
        );
        await tester.tap(target);
        await tester.pump();
        expect(tester.widget<Semantics>(target).properties.selected, isTrue);
        final indicator = tester.getRect(
          find.byKey(const ValueKey('floating-navigation-indicator')),
        );
        final bounds = tester.getRect(target);
        expect(indicator.center.dx, closeTo(bounds.center.dx, .1));
        expect(indicator.width, closeTo(bounds.width - 8, .1));
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  for (final destination in [1, 2]) {
    testWidgets(
      'hold and scrub previews then commits destination $destination once',
      (tester) async {
        var requested = 0;
        await tester.pumpWidget(_scrubApp(onRequested: () => requested++));
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('home-tab'))),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveTo(
          tester.getCenter(
            find.byKey(
              ValueKey(destination == 1 ? 'proxies-tab' : 'settings-tab'),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester
              .widget<Semantics>(
                find.byKey(
                  ValueKey(destination == 1 ? 'proxies-tab' : 'settings-tab'),
                ),
              )
              .properties
              .selected,
          isTrue,
        );
        expect(find.text('Home body'), findsOneWidget);
        expect(requested, 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          find.text(destination == 1 ? 'Proxies body' : 'Settings body'),
          findsOneWidget,
        );
        expect(requested, destination == 1 ? 1 : 0);
      },
    );
  }

  for (final cancelPointer in [false, true]) {
    testWidgets(
      'scrub cancellation does not navigate pointerCancel=$cancelPointer',
      (tester) async {
        var requested = 0;
        await tester.pumpWidget(_scrubApp(onRequested: () => requested++));
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('home-tab'))),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveTo(
          tester.getCenter(find.byKey(const ValueKey('proxies-tab'))),
        );
        await tester.pump();
        expect(
          tester
              .widget<Semantics>(find.byKey(const ValueKey('proxies-tab')))
              .properties
              .selected,
          isTrue,
        );
        if (cancelPointer) {
          await gesture.cancel();
        } else {
          final bar = tester.getRect(
            _navigation(BottomNavigationStyle.floating),
          );
          await gesture.moveTo(Offset(bar.center.dx, bar.top - 30));
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Semantics>(find.byKey(const ValueKey('home-tab')))
              .properties
              .selected,
          isTrue,
        );
        expect(find.text('Home body'), findsOneWidget);
        expect(requested, 0);
      },
    );
  }

  testWidgets('scrubbing follows visual destinations in RTL', (tester) async {
    await tester.pumpWidget(_scrubApp(rtl: true));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('home-tab'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('settings-tab'))),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Settings body'), findsOneWidget);
  });

  testWidgets('switching from settings to docked returns home safely', (
    tester,
  ) async {
    await tester.pumpWidget(_scrubApp());
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Settings body'), findsOneWidget);
    await tester.pumpWidget(_scrubApp(style: BottomNavigationStyle.docked));
    await tester.pumpAndSettle();
    expect(find.text('Home body'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-tab')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_scrubApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Settings body'), findsOneWidget);
  });

  for (final style in BottomNavigationStyle.values) {
    testWidgets('keyboard can select proxy destination ${style.name}', (
      tester,
    ) async {
      await tester.pumpWidget(_scrubApp(style: style));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Proxies body'), findsOneWidget);
    });

    testWidgets(
      'accessible navigation keeps tap selection without scrubbing ${style.name}',
      (tester) async {
        await tester.pumpWidget(_scrubApp(style: style, accessible: true));
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('home-tab'))),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveTo(
          tester.getCenter(find.byKey(const ValueKey('proxies-tab'))),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.text('Home body'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
        await tester.tap(find.byKey(const ValueKey('proxies-tab')));
        await tester.pumpAndSettle();
        expect(find.text('Proxies body'), findsOneWidget);
      },
    );

    if (style == BottomNavigationStyle.floating) {
      testWidgets(
        'last settings entry scrolls above ${style.name} navigation and remains clickable',
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
                  padding: EdgeInsets.only(top: 32, bottom: 24),
                  viewPadding: EdgeInsets.only(top: 32, bottom: 24),
                ),
                child: TabbedHomeShell(
                  bottomNavigationStyle: style,
                  homeBuilder: (_, open) => const SizedBox(),
                  proxiesBuilder: (_, active, back, request) =>
                      const SizedBox(),
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
            lessThan(tester.getRect(_navigation(style)).top),
          );
          await tester.tap(about);
          expect(aboutOpened, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'destinations fit narrow Russian layout with large text ${style.name}',
      (tester) async {
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
                bottomNavigationStyle: style,
                homeBuilder: (_, open) => const Text('Дом'),
                proxiesBuilder: (_, active, back, request) =>
                    const Text('Список'),
                settingsBuilder: (_) => const Text('Параметры'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final tab in [
          'home-tab',
          'proxies-tab',
          if (style == BottomNavigationStyle.floating) 'settings-tab',
        ]) {
          final target = find.byKey(ValueKey(tab));
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(
          find.text(
            style == BottomNavigationStyle.floating ? 'Параметры' : 'Список',
          ),
          findsOneWidget,
        );
      },
    );

    if (style == BottomNavigationStyle.floating) {
      testWidgets(
        'settings is a retained third tab and Back returns home ${style.name}',
        (tester) async {
          var settingsBuilds = 0;
          await tester.pumpWidget(
            MaterialApp(
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: TabbedHomeShell(
                bottomNavigationStyle: style,
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
        },
      );
    }

    testWidgets(
      'navigation respects safe edges and hides for keyboard ${style.name}',
      (tester) async {
        Future<void> pump({double keyboard = 0, bool reduced = false}) async {
          await tester.pumpWidget(
            MaterialApp(
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(800, 600),
                  padding: EdgeInsets.only(
                    top: 32,
                    bottom: keyboard > 0 ? 0 : 24,
                  ),
                  viewPadding: const EdgeInsets.only(top: 32, bottom: 24),
                  viewInsets: EdgeInsets.only(bottom: keyboard),
                  disableAnimations: reduced,
                ),
                child: TabbedHomeShell(
                  bottomNavigationStyle: style,
                  homeBuilder: (_, open) =>
                      const SizedBox.expand(key: ValueKey('full-content')),
                  proxiesBuilder: (_, active, back, request) =>
                      const SizedBox(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pump();
        final bar = tester.getRect(_navigation(style));
        expect(
          bar.left,
          style == BottomNavigationStyle.floating ? greaterThan(0) : 0,
        );
        expect(
          bar.right,
          style == BottomNavigationStyle.floating ? lessThan(800) : 800,
        );
        expect(bar.bottom, lessThanOrEqualTo(576));
        expect(
          tester.getRect(find.byKey(const ValueKey('full-content'))).bottom,
          style == BottomNavigationStyle.floating ? 600 : 516,
        );
        expect(
          find.byType(BackdropFilter),
          style == BottomNavigationStyle.floating
              ? findsOneWidget
              : findsNothing,
        );
        await pump(reduced: true);
        expect(find.byType(BackdropFilter), findsNothing);
        await pump(keyboard: 280);
        expect(_navigation(style), findsNothing);
      },
    );

    testWidgets(
      'tabs mount proxies lazily and retain scroll across tab changes ${style.name}',
      (tester) async {
        var mounts = 0;
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: TabbedHomeShell(
              bottomNavigationStyle: style,
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
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .pixels,
          offset,
        );
      },
    );

    testWidgets(
      'current auto group creates a distinct browser request each time ${style.name}',
      (tester) async {
        ({int serial, String? groupTag})? request;
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: TabbedHomeShell(
              bottomNavigationStyle: style,
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
}

Finder _navigation(BottomNavigationStyle style) =>
    style == BottomNavigationStyle.floating
    ? find.byKey(const ValueKey('floating-bottom-navigation'))
    : find.byType(NavigationBar);

Widget _scrubApp({
  VoidCallback? onRequested,
  bool rtl = false,
  BottomNavigationStyle style = BottomNavigationStyle.floating,
  double safeBottom = 0,
  double safeTop = 0,
  double safeLeft = 0,
  double safeRight = 0,
  double keyboard = 0,
  bool accessible = false,
  bool reduced = false,
}) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: child!,
  ),
  home: MediaQuery(
    data: MediaQueryData(
      accessibleNavigation: accessible,
      disableAnimations: reduced,
      padding: EdgeInsets.fromLTRB(
        safeLeft,
        safeTop,
        safeRight,
        keyboard > 0 ? 0 : safeBottom,
      ),
      viewPadding: EdgeInsets.only(
        top: safeTop,
        bottom: safeBottom,
        left: safeLeft,
        right: safeRight,
      ),
      viewInsets: EdgeInsets.only(bottom: keyboard),
    ),
    child: TabbedHomeShell(
      bottomNavigationStyle: style,
      homeBuilder: (_, open) => const Text('Home body'),
      proxiesBuilder: (_, active, back, request) => const Text('Proxies body'),
      settingsBuilder: (_) => const Text('Settings body'),
      onProxiesRequested: onRequested,
    ),
  ),
);
