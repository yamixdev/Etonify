import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/proxies/proxy_exclusions_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/proxy_exclusion_rules.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  testWidgets('search, toggle and apply preserve absent stored tags', (
    tester,
  ) async {
    ProxyExclusionRules? saved;
    const subscription = Subscription(
      id: 'one',
      name: 'one',
      url: '',
      outbounds: [
        Outbound(tag: 'a', name: 'Alpha', config: {'type': 'vless'}),
        Outbound(tag: 'b', name: 'Beta', config: {'type': 'trojan'}),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () async {
                saved = await Navigator.of(context).push<ProxyExclusionRules>(
                  MaterialPageRoute(
                    builder: (_) => ProxyExclusionsPage(
                      subscription: subscription,
                      rules: ProxyExclusionRules(excludedTags: {'absent'}),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Beta');
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('proxy-exclusion-b')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('proxy-exclusions-apply')));
    await tester.pumpAndSettle();
    expect(saved!.excludedTags, {'absent', 'b'});
  });
}
