import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/release_notes_card.dart';
import 'package:meow_client/widgets/release_image_loader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'release_image_loader_test.dart' show pixel, imageUri;

void main() {
  testWidgets('full-page notes omit duplicate heading and retain long notes', (
    tester,
  ) async {
    final longBody = List.generate(
      80,
      (index) => 'Release item $index',
    ).join('\n\n');
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReleaseNotesCard(
              body: longBody,
              showHeading: false,
              useCard: false,
              limitBody: false,
            ),
          ),
        ),
      ),
    );
    expect(find.text("What's new"), findsNothing);
    expect(find.textContaining('Release item 79'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets(
    'GitHub photo loads inline and expands inside client, unsafe images stay blocked',
    (tester) async {
      final loader = ReleaseImageLoader(
        clientFactory: () => MockClient(
          (_) async => http.Response.bytes(
            pixel,
            200,
            headers: {'content-type': 'image/png'},
          ),
        ),
      );
      final image = await tester.runAsync(() => loader.load(imageUri));
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReleaseNotesCard(
                body:
                    'Photo <img src="$imageUri" alt="secure" />\n\n'
                    '![insecure](http://example.com/image.png)',
                allowImages: true,
                imageLoader: loader,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(image!.bytes),
          tester.element(find.byType(ReleaseNotesCard)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('release-image-preview')),
        findsOneWidget,
      );
      expect(find.text('[insecure]'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('release-image-preview')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .any((image) => image.image is NetworkImage),
        isFalse,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    },
  );
  testWidgets('renders common GitHub markdown without exposing its markers', (
    tester,
  ) async {
    final openedUris = <Uri>[];
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
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReleaseNotesCard(
              body: '''
## Исправления
> Важно: **не удаляйте** профиль.
- Открыт [репозиторий ядра](https://github.com/yamixdev/etonify-core/tree/etonify-dev).
1. `timeout` теперь ~~серый~~ красный.
Автоссылка: https://example.com/docs.
```text
closeAll()
```
''',
              onOpenLink: openedUris.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final renderedText = <String>[
      ...tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText()),
      ...tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? ''),
    ].join('\n');

    expect(renderedText, contains('Исправления'));
    expect(renderedText, contains('Важно: не удаляйте профиль.'));
    expect(renderedText, contains('репозиторий ядра'));
    expect(renderedText, contains('timeout теперь серый красный.'));
    expect(renderedText, contains('https://example.com/docs'));
    expect(find.text('closeAll()', findRichText: true), findsOneWidget);
    expect(renderedText, isNot(contains('**')));
    expect(renderedText, isNot(contains('~~')));
    expect(renderedText, isNot(contains('[репозиторий ядра]')));
    expect(renderedText, isNot(contains('```')));
    expect(find.text('1.'), findsOneWidget);

    final linkRecognizers = _textSpans(
      tester,
    ).map((span) => span.recognizer).whereType<TapGestureRecognizer>().toList();
    expect(linkRecognizers, hasLength(2));
    for (final recognizer in linkRecognizers) {
      recognizer.onTap?.call();
    }

    expect(
      openedUris,
      contains(
        Uri.parse('https://github.com/yamixdev/etonify-core/tree/etonify-dev'),
      ),
    );
    expect(openedUris, contains(Uri.parse('https://example.com/docs')));
  });

  testWidgets('keeps parsed markdown when an unchanged parent rebuilds', (
    tester,
  ) async {
    late StateSetter rebuild;
    var revision = 0;
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
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Column(
                  children: [
                    Text('revision $revision'),
                    const ReleaseNotesCard(
                      body: '[Etonify](https://github.com/yamixdev/Etonify)',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final before = _linkRecognizers(tester).single;
    rebuild(() => revision++);
    await tester.pump();
    final after = _linkRecognizers(tester).single;

    expect(find.text('revision 1'), findsOneWidget);
    expect(identical(after, before), isTrue);
  });
}

Iterable<TapGestureRecognizer> _linkRecognizers(WidgetTester tester) =>
    _textSpans(
      tester,
    ).map((span) => span.recognizer).whereType<TapGestureRecognizer>();

Iterable<TextSpan> _textSpans(WidgetTester tester) sync* {
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    yield* _walkSpan(widget.text);
  }
  for (final widget in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  )) {
    final span = widget.textSpan;
    if (span != null) {
      yield* _walkSpan(span);
    }
  }
}

Iterable<TextSpan> _walkSpan(InlineSpan span) sync* {
  if (span is! TextSpan) {
    return;
  }
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _walkSpan(child);
  }
}
