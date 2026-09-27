import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/automatic_url_test_policy.dart';
import 'package:meow_client/data/local/app_settings_store.dart';

void main() {
  group('Auto check servers settings and policy tests', () {
    test('default setting is false in store', () {
      final store = _InMemorySettingsStore();
      final defaultState = store.mapState(const <String, dynamic>{});
      expect(defaultState.autoCheckServers, isFalse);
      expect(defaultState.autoCheckNoticeAcknowledged, isFalse);
    });

    test('setting autoCheckServers roundtrips through store serialization', () {
      final store = _InMemorySettingsStore();
      final state = store
          .mapState(const <String, dynamic>{})
          .copyWith(autoCheckServers: true, autoCheckNoticeAcknowledged: true);
      final mapped = store.stateToMap(state);
      expect(mapped['auto_check_servers'], '1');
      expect(mapped['auto_check_notice_acknowledged'], '1');

      final restored = store.mapState(mapped);
      expect(restored.autoCheckServers, isTrue);
      expect(restored.autoCheckNoticeAcknowledged, isTrue);
    });

    test('rehydrating AppSettingsController preserves autoCheckServers', () {
      final controller = AppSettingsController();
      expect(controller.autoCheckServers, isFalse);

      final change = controller.setAutoCheckServers(true);
      expect(change.changed, isTrue);
      expect(controller.autoCheckServers, isTrue);

      final state = controller.toState(
        onboardingCompleted: true,
        acceptedLegalVersion: '1.0',
        acceptedLegalAtMillis: 1000,
        activeProfileId: 'profile-1',
        selectedProxyTag: 'proxy-1',
      );
      expect(state.autoCheckServers, isTrue);

      final recreatedController = AppSettingsController()..applyState(state);
      expect(recreatedController.autoCheckServers, isTrue);
    });

    test('policy selects full scope when autoCheckServers is enabled', () {
      final fullScope = automaticUrlTestScope(
        reason: 'runtime_diagnostics_ready',
        autoCheckServers: true,
        supportsTargeted: true,
        selectedTag: 'server-1',
      );
      expect(fullScope, AutomaticUrlTestScope.full);

      final periodicScope = automaticUrlTestScope(
        reason: 'periodic',
        autoCheckServers: true,
        supportsTargeted: true,
        selectedTag: 'server-1',
      );
      expect(periodicScope, AutomaticUrlTestScope.full);

      final selectionScope = automaticUrlTestScope(
        reason: 'selection',
        autoCheckServers: true,
        supportsTargeted: true,
        selectedTag: 'server-1',
      );
      expect(selectionScope, AutomaticUrlTestScope.selected);
    });

    test(
      'policy selects targeted/none scope when autoCheckServers is disabled',
      () {
        final readyScope = automaticUrlTestScope(
          reason: 'runtime_diagnostics_ready',
          autoCheckServers: false,
          supportsTargeted: true,
          selectedTag: 'server-1',
        );
        expect(readyScope, AutomaticUrlTestScope.selected);

        final periodicScope = automaticUrlTestScope(
          reason: 'periodic',
          autoCheckServers: false,
          supportsTargeted: true,
          selectedTag: 'server-1',
        );
        expect(periodicScope, AutomaticUrlTestScope.none);

        final selectionScope = automaticUrlTestScope(
          reason: 'selection',
          autoCheckServers: false,
          supportsTargeted: true,
          selectedTag: 'server-1',
        );
        expect(selectionScope, AutomaticUrlTestScope.selected);
      },
    );
  });
}

final class _InMemorySettingsStore extends AppSettingsStore {
  @override
  Future<void> close() async {}

  @override
  Future<AppSettingsState> loadState() async => mapState(const {});

  @override
  Future<void> saveState(AppSettingsState state) async {}
}
