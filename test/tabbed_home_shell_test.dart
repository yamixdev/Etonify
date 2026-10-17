import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/home/tabbed_home_shell.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
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
