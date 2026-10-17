import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app.dart';
import 'package:meow_client/app/app_bootstrap_controller.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';
import 'package:meow_client/platform/windows/desktop_runtime_client.dart';

void main() {
  testWidgets(
    'home opens before core and migration keeps edits made meanwhile',
    (tester) async {
      final core = Completer<LibboxCapabilities>();
      var requests = 0;
      final controller = _DeferredBootstrap(
        loadCore: () {
          requests++;
          return core.future;
        },
      );
      final initial = AppSettingsController()
          .toState(
            onboardingCompleted: true,
            acceptedLegalVersion: '0.2.1',
            acceptedLegalAtMillis: 1,
            activeProfileId: '',
            selectedProxyTag: '',
          )
          .copyWith(
            localeCode: 'en',
            autoCheckNoticeAcknowledged: true,
            hwidDefaultNoticeShown: true,
            splitRoutingSchemaVersion: 1,
            coreConfigSchemaVersion: 1,
          );
      final store = MemoryAppSettingsStore(initial);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appBootstrapControllerProvider.overrideWith(
              (ref, version) => controller,
            ),
            desktopRuntimeClientProvider.overrideWithValue(
              DesktopRuntimeClient.unavailable(),
            ),
          ],
          child: MeowClient(store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Etonify'), findsOneWidget);
      expect(requests, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MeowClient)),
      );
      container
          .read(appSettingsProvider.notifier)
          .hydrate(
            initial.copyWith(
              hapticEnabled: false,
              dnsDirectResolver: '9.9.9.9',
            ),
          );
      core.complete(_capabilities);
      await tester.pumpAndSettle();
      final settings = container.read(appSettingsControllerProvider);
      expect(settings.hapticEnabled, isFalse);
      expect(settings.dnsDirectResolver, 'udp://9.9.9.9');
      expect(settings.coreConfigSchemaVersion, 1);
      expect((await store.loadState()).coreConfigSchemaVersion, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

class _DeferredBootstrap extends AppBootstrapController {
  _DeferredBootstrap({required Future<LibboxCapabilities> Function() loadCore})
    : super(
        fallbackClientVersionLabel: '0.3.9',
        loadCoreCapabilities: loadCore,
        loadAppVersionInfo: () async => const AppVersionInfo(
          packageName: 'com.etonify.meow_client',
          versionName: '0.3.9',
          versionCode: 39,
        ),
      );

  @override
  Future<AppBootstrapResult> load({
    AppSettingsStore? providedStore,
    bool deferCoreCapabilities = false,
  }) => super.load(providedStore: providedStore, deferCoreCapabilities: true);
}

const _capabilities = LibboxCapabilities(
  apiVersion: 2,
  coreVersion: '1.15.0-alpha.3-etonify.1',
  supportsTargetedUrlTest: false,
  supportsGroupUrlTestSessions: false,
  supportsStructuredProbeErrors: false,
  supportsOutboundExternalInfo: false,
  supportsMixedRoutingOutbound: false,
  supportsUrlTestTimeout: false,
  supportsUrlTestConcurrency: false,
  supportsUrlTestDeadline: false,
  supportsUrlTestForce: false,
  supportsUrlTestUnavailableCheckInterval: false,
  supportsUrlTestMethod: false,
  supportsUrlTestInterruptDelayThreshold: false,
  urlTestCompletionModel: UrlTestCompletionModel.groupEvents,
  supportsConfigCheck: true,
  supportsCloseConnections: true,
  supportsRealitySpiderX: false,
  tunStacks: {'native', 'system'},
);
