import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/coordinators/deep_link_import_coordinator.dart';
import 'package:meow_client/app/deep_link_import.dart';
import 'package:meow_client/app/widgets/deep_link_import_sheet.dart';
import 'package:meow_client/data/subscription/subscription_fetcher.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  group('DeepLinkImportCoordinator', () {
    late bool mounted;
    late bool ready;
    late bool onboardingCompleted;
    late bool legalAccepted;
    late List<String> snackBars;
    late StreamController<DeepLinkImportRequest> streamController;
    late DeepLinkImportCoordinator coordinator;

    setUp(() {
      mounted = true;
      ready = true;
      onboardingCompleted = true;
      legalAccepted = true;
      snackBars = <String>[];
      streamController = StreamController<DeepLinkImportRequest>.broadcast();

      coordinator = DeepLinkImportCoordinator(
        importStream: streamController.stream,
        initialRequestProvider: () async => null,
        host: DeepLinkImportHost(
          isMounted: () => mounted,
          isReady: () => ready,
          isOnboardingCompleted: () => onboardingCompleted,
          isLegalAccepted: () => legalAccepted,
          getNavigatorContext: () => null,
          showSnackBar: (msg) => snackBars.add(msg),
          runSubscriptionOperationWithWarning:
              (future, {required slowMessage, required timeoutMessage}) =>
                  future,
          getSubscriptionOperationTimeout: () => const Duration(seconds: 5),
          getAllowUntrustedSubscriptionCertificates: () => false,
          onSubscriptionRouteAttempt: (route, isFallback) {},
          reloadSubscriptions: () async {},
          offerLikelyHwidFix: (sub) async {},
          userFacingSubscriptionError: (err, l10n) => err.toString(),
        ),
      );
    });

    tearDown(() async {
      coordinator.dispose();
      await streamController.close();
    });

    test('enqueue blocks import if legal not accepted', () {
      legalAccepted = false;
      coordinator.enqueue(
        const DeepLinkImportRequest(url: 'https://example.com/sub'),
      );

      expect(coordinator.hasPendingImport, isFalse);
      expect(snackBars, isNotEmpty);
      expect(
        snackBars.first,
        'Accept Terms and Privacy Policy before importing subscriptions.',
      );
    });

    test('enqueue sets pending import if not ready', () {
      ready = false;
      coordinator.enqueue(
        const DeepLinkImportRequest(url: 'https://example.com/sub'),
      );

      expect(coordinator.hasPendingImport, isTrue);
      expect(coordinator.pendingImport?.url, 'https://example.com/sub');
    });

    test('enqueue sets pending import if onboarding not completed', () {
      onboardingCompleted = false;
      coordinator.enqueue(
        const DeepLinkImportRequest(url: 'https://example.com/sub'),
      );

      expect(coordinator.hasPendingImport, isTrue);
    });

    test('start listens to stream and enqueues events', () async {
      await coordinator.start();

      ready = false; // keep in queue
      streamController.add(
        const DeepLinkImportRequest(url: 'https://example.com/sub2'),
      );
      await pumpEventQueue();

      expect(coordinator.hasPendingImport, isTrue);
      expect(coordinator.pendingImport?.url, 'https://example.com/sub2');
    });

    test('dispose cancels subscription and clears pending', () {
      ready = false;
      coordinator.enqueue(
        const DeepLinkImportRequest(url: 'https://example.com/sub'),
      );
      expect(coordinator.hasPendingImport, isTrue);

      coordinator.dispose();
      expect(coordinator.hasPendingImport, isFalse);
    });

    testWidgets(
      'does not show sheet and notifies if subscription is already added',
      (tester) async {
        late BuildContext navigatorContext;
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  navigatorContext = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final existing = const Subscription(
          id: 'flagman-1',
          name: 'Flagman',
          url: 'https://link.flagman.click/sub/f13cZEvb8zKdeYsJqqwrvWbEt',
        );

        final widgetCoordinator = DeepLinkImportCoordinator(
          importStream: streamController.stream,
          initialRequestProvider: () async => null,
          host: DeepLinkImportHost(
            isMounted: () => true,
            isReady: () => true,
            isOnboardingCompleted: () => true,
            isLegalAccepted: () => true,
            getNavigatorContext: () => navigatorContext,
            showSnackBar: (msg) => snackBars.add(msg),
            runSubscriptionOperationWithWarning:
                (future, {required slowMessage, required timeoutMessage}) =>
                    future,
            getSubscriptionOperationTimeout: () => const Duration(seconds: 5),
            getAllowUntrustedSubscriptionCertificates: () => false,
            onSubscriptionRouteAttempt: (route, isFallback) {},
            reloadSubscriptions: () async {},
            offerLikelyHwidFix: (sub) async {},
            userFacingSubscriptionError: (err, l10n) => err.toString(),
            getExistingSubscriptions: () => [existing],
          ),
        );

        widgetCoordinator.enqueue(
          const DeepLinkImportRequest(
            url: 'https://link.flagman.click/sub/f13cZEvb8zKdeYsJqqwrvWbEt',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DeepLinkImportSheet), findsNothing);
        expect(snackBars, contains('Subscription "Flagman" is already added'));
        widgetCoordinator.dispose();
      },
    );

    testWidgets(
      'auto-imports with HWID without prompt when sendHwidToProviders is true',
      (tester) async {
        SubscriptionFetcher.configureHwidSharing(true);
        late BuildContext navigatorContext;
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  navigatorContext = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        bool operationCalled = false;
        final createdSub = const Subscription(
          id: 'new-1',
          name: 'New Provider',
          url: 'https://example.com/sub/new',
        );

        final widgetCoordinator = DeepLinkImportCoordinator(
          importStream: streamController.stream,
          initialRequestProvider: () async => null,
          host: DeepLinkImportHost(
            isMounted: () => true,
            isReady: () => true,
            isOnboardingCompleted: () => true,
            isLegalAccepted: () => true,
            getNavigatorContext: () => navigatorContext,
            showSnackBar: (msg) => snackBars.add(msg),
            runSubscriptionOperationWithWarning:
                (future, {required slowMessage, required timeoutMessage}) =>
                    future,
            importSubscription:
                ({
                  required url,
                  customName,
                  requestInfo,
                  operationTimeout,
                  allowInsecureTls = false,
                  onRouteAttempt,
                }) async {
                  operationCalled = true;
                  return SubscriptionImportResult(subscription: createdSub);
                },
            getSubscriptionOperationTimeout: () => const Duration(seconds: 5),
            getAllowUntrustedSubscriptionCertificates: () => false,
            onSubscriptionRouteAttempt: (route, isFallback) {},
            reloadSubscriptions: () async {},
            offerLikelyHwidFix: (sub) async {},
            userFacingSubscriptionError: (err, l10n) => err.toString(),
            getExistingSubscriptions: () => [],
          ),
        );

        widgetCoordinator.enqueue(
          const DeepLinkImportRequest(url: 'https://example.com/sub/new'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DeepLinkImportSheet), findsNothing);
        expect(operationCalled, isTrue);
        expect(snackBars, contains('Subscription "New Provider" imported'));
        widgetCoordinator.dispose();
      },
    );

    testWidgets('shows sheet when sendHwidToProviders is false', (
      tester,
    ) async {
      SubscriptionFetcher.configureHwidSharing(false);
      late BuildContext navigatorContext;
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                navigatorContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final widgetCoordinator = DeepLinkImportCoordinator(
        importStream: streamController.stream,
        initialRequestProvider: () async => null,
        host: DeepLinkImportHost(
          isMounted: () => true,
          isReady: () => true,
          isOnboardingCompleted: () => true,
          isLegalAccepted: () => true,
          getNavigatorContext: () => navigatorContext,
          showSnackBar: (msg) => snackBars.add(msg),
          runSubscriptionOperationWithWarning:
              (future, {required slowMessage, required timeoutMessage}) =>
                  future,
          getSubscriptionOperationTimeout: () => const Duration(seconds: 5),
          getAllowUntrustedSubscriptionCertificates: () => false,
          onSubscriptionRouteAttempt: (route, isFallback) {},
          reloadSubscriptions: () async {},
          offerLikelyHwidFix: (sub) async {},
          userFacingSubscriptionError: (err, l10n) => err.toString(),
          getExistingSubscriptions: () => [],
        ),
      );

      widgetCoordinator.enqueue(
        const DeepLinkImportRequest(url: 'https://example.com/sub/new2'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeepLinkImportSheet), findsOneWidget);
      widgetCoordinator.dispose();
    });
  });
}
