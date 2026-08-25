import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/settings/settings_update_page.dart';

void main() {
  testWidgets('update menu exposes check and channel actions', (tester) async {
    var checkCalls = 0;
    var channelCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              UpdateOverflowMenu(
                enabled: true,
                checkLabel: 'Check now',
                channelLabel: 'Update channel',
                currentChannelLabel: 'Stable',
                onCheck: () => checkCalls++,
                onChangeChannel: () => channelCalls++,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('update-overflow-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Check now'), findsOneWidget);
    expect(find.text('Update channel'), findsOneWidget);
    expect(find.text('Stable'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('update-menu-channel')));
    await tester.pumpAndSettle();

    expect(checkCalls, 0);
    expect(channelCalls, 1);
  });

  testWidgets('check menu item triggers only a manual check', (tester) async {
    var checkCalls = 0;
    var channelCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              UpdateOverflowMenu(
                enabled: true,
                checkLabel: 'Check now',
                channelLabel: 'Update channel',
                currentChannelLabel: 'Beta',
                onCheck: () => checkCalls++,
                onChangeChannel: () => channelCalls++,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('update-overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('update-menu-check')));
    await tester.pumpAndSettle();

    expect(checkCalls, 1);
    expect(channelCalls, 0);
  });
}
