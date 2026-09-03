import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/widgets/app_notice.dart';

void main() {
  testWidgets('notice is visible above a modal bottom sheet', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );

    unawaited(
      showModalBottomSheet<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const SizedBox(
          height: 300,
          child: Center(child: Text('Profiles sheet')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    AppNotice.show(navigatorKey.currentContext!, 'Import failed');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Profiles sheet'), findsOneWidget);
    expect(find.text('Import failed'), findsOneWidget);
    AppNotice.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('notice action is preserved', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var invoked = false;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );

    AppNotice.show(
      navigatorKey.currentContext!,
      'Update available',
      actionLabel: 'Open',
      onAction: () => invoked = true,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(invoked, isTrue);
  });

  testWidgets('notice can be dismissed by swiping either direction', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );

    AppNotice.show(navigatorKey.currentContext!, 'Swipe left');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.drag(find.text('Swipe left'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Swipe left'), findsNothing);

    AppNotice.show(navigatorKey.currentContext!, 'Swipe right');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.drag(find.text('Swipe right'), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Swipe right'), findsNothing);
  });
}
