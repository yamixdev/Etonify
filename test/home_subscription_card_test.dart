import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/home/home_subscription_card.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    for (final rtl in [false, true]) {
      testWidgets(
        'expiry aligns to trailing usage edge scale=$textScale rtl=$rtl',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: Directionality(
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: 393,
                        child: HomeSubscriptionCard(
                          profile: const AppProfileSummary(
                            id: 'test',
                            name: 'Profile',
                            consumed: 1234,
                            total: 102400,
                            remainingDays: 45,
                            outboundsCount: 3,
                            sourceLabel: '',
                          ),
                          margin: EdgeInsets.zero,
                          showRefreshAction: true,
                          onRefresh: () async {},
                          onTap: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final progress = tester.getRect(find.byType(LinearProgressIndicator));
          final expiry = tester.getRect(find.textContaining('45'));
          expect(
            rtl ? expiry.left : expiry.right,
            closeTo(rtl ? progress.left : progress.right, 1),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
