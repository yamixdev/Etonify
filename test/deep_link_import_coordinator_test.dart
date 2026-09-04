import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/coordinators/deep_link_import_coordinator.dart';
import 'package:meow_client/app/deep_link_import.dart';

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
          runSubscriptionOperationWithWarning: (future,
                  {required slowMessage, required timeoutMessage}) =>
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
  });
}
