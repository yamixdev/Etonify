import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/proxies/proxy_exclusions_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/proxy_exclusion_rules.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

void main() {
  testWidgets('edit a saved condition and select several countries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ProxyExclusionsPage(
          subscription: const Subscription(
            id: 'countries',
            name: 'Countries',
            url: '',
            outbounds: [
              Outbound(
                tag: 'de',
                name: 'Germany',
                config: {'type': 'vless'},
                info: OutboundInfo(country: 'DE'),
              ),
              Outbound(
                tag: 'fi',
                name: 'Finland',
                config: {'type': 'vless'},
                info: OutboundInfo(country: 'FI'),
              ),
            ],
          ),
          rules: ProxyExclusionRules(
            conditions: [
              ProxyExclusionCondition.fromMap({
                'protocol': 'vless',
                'country': 'DE',
              }),
            ],
          ),
        ),
      ),
    );
    final edit = find.byTooltip('Edit condition');
    await tester.tap(edit);
    await tester.pumpAndSettle();
    final germany = find.widgetWithText(FilterChip, 'DE');
    final finland = find.widgetWithText(FilterChip, 'FI');
    expect(tester.widget<FilterChip>(germany).selected, isTrue);
    await tester.tap(finland);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('VLESS + DE'), findsOneWidget);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(finland).selected, isFalse);
    await tester.tap(finland);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('VLESS + DE, FI'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(edit, findsOneWidget);
  });

  for (final markRussia in [false, true]) {
    testWidgets('exclusion rows show honest countries, Russia=$markRussia', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ProxyExclusionsPage(
            subscription: Subscription(
              id: 'flags',
              name: 'flags',
              url: '',
              markAllServersRussia: markRussia,
              outbounds: const [
                Outbound(
                  tag: 'known',
                  name: 'Known',
                  config: {'type': 'vless'},
                  info: OutboundInfo(country: 'DE'),
                ),
                Outbound(
                  tag: 'unknown',
                  name: 'Unknown',
                  config: {'type': 'trojan'},
                ),
              ],
            ),
            rules: ProxyExclusionRules(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final tag in ['known', 'unknown']) {
        final row = find.byKey(ValueKey('proxy-exclusion-$tag'));
        await tester.scrollUntilVisible(
          row,
          180,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        final flag = find.descendant(
          of: row,
          matching: find.byType(CountryFlagBadge),
        );
        expect(flag, findsOneWidget);
        expect(
          tester.widget<CountryFlagBadge>(flag).countryCode,
          markRussia
              ? 'RU'
              : tag == 'known'
              ? 'DE'
              : '',
        );
        final title = find.text(tag == 'known' ? 'Known' : 'Unknown');
        expect(
          tester.getRect(flag).right,
          lessThanOrEqualTo(tester.getRect(title).left),
        );
        if (!markRussia && tag == 'unknown') {
          expect(
            find.descendant(
              of: flag,
              matching: find.byIcon(Icons.public_rounded),
            ),
            findsOneWidget,
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
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
    expect(
      saved!.excludedTagsFor(
        subscription.copyWith(
          outbounds: [
            subscription.outbounds.first.copyWith(tag: 'b'),
            subscription.outbounds.last.copyWith(
              tag: 'renamed',
              name: 'Renamed',
            ),
          ],
        ),
      ),
      {'renamed'},
    );
    expect(saved!.excludedTagsFor(subscription.copyWith(id: 'other')), isEmpty);
  });
}
