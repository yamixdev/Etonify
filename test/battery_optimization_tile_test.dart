import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/settings/battery_optimization_tile.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('opens settings only on tap without querying exemption', (
    tester,
  ) async {
    final calls = <String>[];
    const channel = MethodChannel('meow_client/battery_optimization');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'getStatus' ? 'restricted' : true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: BatteryOptimizationTile()),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(calls, ['openSettings']);
    expect(find.byType(Switch), findsNothing);
  });
}
