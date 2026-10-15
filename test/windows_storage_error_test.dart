import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app.dart';
import 'package:meow_client/features/home/home_page.dart';
import 'package:hive_ce/hive.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/models/subscription.dart';
import 'support/windows_storage_fixture.dart';
import 'package:meow_client/logging/app_log_store.dart';

void main() {
  Future<void> pumpUntil(WidgetTester tester, bool Function() completed) async {
    for (var i = 0; i < 200 && !completed(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(
      completed(),
      isTrue,
      reason: 'Expected storage state did not settle',
    );
  }

  bool recoveryReady(WidgetTester tester) {
    final retry = find.widgetWithText(FilledButton, 'Retry');
    return find.text('Unable to open user data').evaluate().length == 1 &&
        retry.evaluate().length == 1 &&
        tester.widget<FilledButton>(retry).onPressed != null;
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('meow_client/deep_links'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('meow_client/deep_link_events'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('meow_client/singbox_events'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('meow_client/deep_links'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('meow_client/deep_link_events'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('meow_client/singbox_events'),
          null,
        );
  });
  void registerDeferredCase() {
    for (final keyMutation in ['remove', 'replace']) {
      testWidgets(
        'corrupt deferred active payload shows storage recovery and preserves its bytes ($keyMutation key on Retry)',
        (tester) async {
          late Directory directory;
          late File payloadFile;
          late List<int> corrupted;
          late List<int> originalPayload;
          late File keyFile;
          late List<int> originalKey;
          await tester.runAsync(() async {
            directory = await Directory.systemTemp.createTemp(
              'etonify-deferred-corruption-',
            );
            await bootstrapWindowsStorageFixture(directory);
            Hive.init(AppDataPaths.current.hiveRoot);
            await HiveAppSettingsStore.initHive();
            await SubscriptionStore.init();
            await SubscriptionStore.save(
              const Subscription(
                id: 'corrupt-profile',
                name: 'Private profile',
                url: 'file:///profile.txt',
                rawContent: 'private fixture',
                selectedProxyTag: 'node-1',
                outbounds: [
                  Outbound(
                    tag: 'node-1',
                    name: 'Node',
                    config: {
                      'type': 'vless',
                      'server': 'example.com',
                      'server_port': 443,
                      'uuid': '00000000-0000-4000-8000-000000000001',
                    },
                  ),
                ],
              ),
            );
            final settings = await HiveAppSettingsStore.open();
            await settings.saveState(
              (await settings.loadState()).copyWith(
                onboardingCompleted: true,
                acceptedLegalVersion: '0.2.1',
                acceptedLegalAtMillis: 1,
                activeProfileId: 'corrupt-profile',
                selectedProxyTag: 'node-1',
              ),
            );
            await settings.close();
            await SubscriptionStore.close();
            await Hive.close();
            payloadFile = File(
              '${AppDataPaths.current.hiveRoot}/subscription_payloads_secure_v1.hive',
            );
            originalPayload = await payloadFile.readAsBytes();
            corrupted = List<int>.from(originalPayload);
            corrupted[corrupted.length - 1] ^= 1;
            await payloadFile.writeAsBytes(corrupted, flush: true);
            keyFile = File('${AppDataPaths.current.userRoot}/storage.key');
            originalKey = await keyFile.readAsBytes();
          });
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            Future<void> drainIo(Future<void> closing) async {
              var done = false;
              Object? failure;
              unawaited(
                closing.then<void>(
                  (_) => done = true,
                  onError: (Object error) {
                    failure = error;
                    done = true;
                  },
                ),
              );
              for (var i = 0; i < 200 && !done; i++) {
                await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 10)),
                );
                await tester.pump();
              }
              expect(
                done,
                isTrue,
                reason:
                    'Widget-created Hive close must finish before removing fixture',
              );
              if (failure != null) throw failure!;
            }

            await drainIo(SubscriptionStore.close());
            await drainIo(Hive.close());
            await tester.runAsync(() async {
              await directory.delete(recursive: true);
            });
          });
          await tester.pumpWidget(const ProviderScope(child: MeowClient()));
          // Lose focus before durable bootstrap completes. The actual deferred
          // storage path still runs; unrelated automatic update work does not.
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          addTearDown(
            () => tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            ),
          );
          await pumpUntil(tester, () => recoveryReady(tester));
          expect(
            find.text('Unable to open user data'),
            findsOneWidget,
            reason: AppLogStore.entries.value
                .map((e) => '${e.title}: ${e.message}')
                .join('\n'),
          );
          expect(find.text('Retry'), findsOneWidget);
          expect(find.byType(HomePage), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            expect(await payloadFile.readAsBytes(), corrupted);
            await payloadFile.writeAsBytes(originalPayload, flush: true);
            if (keyMutation == 'remove') {
              await keyFile.delete();
            } else {
              final replacement = List<int>.from(originalKey);
              replacement[0] ^= 1;
              await keyFile.writeAsBytes(replacement, flush: true);
            }
          });
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          final retryButton = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Retry'),
          );
          expect(retryButton.onPressed, isNotNull);
          retryButton.onPressed!();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          await tester.pump();
          await pumpUntil(tester, () => recoveryReady(tester));
          expect(
            find.text('Unable to open user data'),
            findsOneWidget,
            reason:
                'Retry must re-read the $keyMutation key, not reuse a cached cipher',
          );
          expect(find.byType(HomePage), findsNothing);
          expect(Hive.isBoxOpen(AppSettingsStore.boxName), isFalse);
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            expect(await payloadFile.readAsBytes(), originalPayload);
            if (keyMutation == 'remove') {
              expect(await keyFile.exists(), isFalse);
            } else {
              final replacement = List<int>.from(originalKey)..[0] ^= 1;
              expect(await keyFile.readAsBytes(), replacement);
            }
          });
          await tester.pumpWidget(const SizedBox.shrink());
        },
        skip: !Platform.isWindows,
      );
    }
  }

  testWidgets(
    'Windows storage failure shows recovery rather than an empty ready app',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MeowClient()));
      await pumpUntil(tester, () => recoveryReady(tester));
      expect(find.text('Unable to open user data'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(tester.takeException(), isNull);
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Retry'))
          .onPressed!();
      await tester.pump();
      await pumpUntil(tester, () => recoveryReady(tester));
      expect(find.text('Unable to open user data'), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !Platform.isWindows,
  );
  registerDeferredCase();
}
