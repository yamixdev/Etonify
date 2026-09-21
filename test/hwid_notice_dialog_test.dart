import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app.dart';
import 'package:meow_client/data/local/app_settings_store.dart';

void main() {
  testWidgets('HWID notice dialog shows on launch when ready and not yet acknowledged', (
    tester,
  ) async {
    final base = await MemoryAppSettingsStore().loadState();
    final store = MemoryAppSettingsStore(
      base.copyWith(
        onboardingCompleted: true,
        acceptedLegalVersion: '0.2.1',
        acceptedLegalAtMillis: 1,
        hwidDefaultNoticeShown: false,
        sendHwidToProviders: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MeowClient(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('HWID sending'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // Auto-check notice dialog appears sequentially after HWID notice
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Automatic server check'), findsOneWidget);
    expect(find.byKey(const ValueKey('auto-check-notice-ok')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('auto-check-notice-ok')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final updated = await store.loadState();
    expect(updated.hwidDefaultNoticeShown, isTrue);
    expect(updated.autoCheckNoticeAcknowledged, isTrue);
    expect(updated.sendHwidToProviders, isTrue);
  });

  testWidgets('HWID notice dialog shows in Russian when Russian locale is active', (
    tester,
  ) async {
    final base = await MemoryAppSettingsStore().loadState();
    final store = MemoryAppSettingsStore(
      base.copyWith(
        onboardingCompleted: true,
        acceptedLegalVersion: '0.2.1',
        acceptedLegalAtMillis: 1,
        localeCode: 'ru',
        hwidDefaultNoticeShown: false,
        sendHwidToProviders: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MeowClient(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Отправка HWID'), findsOneWidget);
    expect(find.text('Понятно'), findsOneWidget);

    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();

    // Auto-check notice dialog appears sequentially in Russian
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Автоматическая проверка'), findsOneWidget);
    expect(find.byKey(const ValueKey('auto-check-notice-ok')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('auto-check-notice-ok')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final updated = await store.loadState();
    expect(updated.hwidDefaultNoticeShown, isTrue);
    expect(updated.autoCheckNoticeAcknowledged, isTrue);
  });

  testWidgets('Auto-check notice dialog shows directly when HWID was already acknowledged', (
    tester,
  ) async {
    final base = await MemoryAppSettingsStore().loadState();
    final store = MemoryAppSettingsStore(
      base.copyWith(
        onboardingCompleted: true,
        acceptedLegalVersion: '0.2.1',
        acceptedLegalAtMillis: 1,
        hwidDefaultNoticeShown: true,
        autoCheckNoticeAcknowledged: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MeowClient(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Automatic server check'), findsOneWidget);
    expect(find.byKey(const ValueKey('auto-check-notice-ok')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('auto-check-notice-ok')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final updated = await store.loadState();
    expect(updated.autoCheckNoticeAcknowledged, isTrue);
  });

  testWidgets('HWID and auto-check notice dialogs do NOT show during onboarding or legal consent', (
    tester,
  ) async {
    final base = await MemoryAppSettingsStore().loadState();
    final store = MemoryAppSettingsStore(
      base.copyWith(
        onboardingCompleted: false,
        acceptedLegalVersion: '',
        hwidDefaultNoticeShown: false,
        autoCheckNoticeAcknowledged: false,
        sendHwidToProviders: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MeowClient(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Etonify'), findsOneWidget);
  });
}
