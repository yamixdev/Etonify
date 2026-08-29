import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/features/settings/routing_rule_files_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('route files use compact metadata and readable version', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const status = RussiaRouteDataStatus(
      available: true,
      sourceName: RussiaRouteDataService.sourceName,
      sourceKind: RussiaRouteDataService.sourceKindLive,
      versionTag: '202608261635',
      releaseTag: '202608261635',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: RoutingRuleFilesPage(
          currentStatus: status,
          onRefresh: () async => status,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Источник'), findsOneWidget);
    expect(find.text('runetfreedom'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    expect(find.text('Версия'), findsOneWidget);
    expect(find.text('26.08.2026 16:35'), findsOneWidget);
    expect(find.text('Общий размер'), findsOneWidget);
    expect(find.text('0 B'), findsOneWidget);
    expect(find.text('Сейчас в приоритете Россия'), findsOneWidget);
    expect(
      find.text(
        'Набор пока содержит правила для российских сетей и сервисов. '
        'География будет расширяться в следующих обновлениях.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.verified_rounded), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
