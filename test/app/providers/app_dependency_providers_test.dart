import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';

void main() {
  test('application singletons remain stable inside a provider container', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      identical(
        container.read(singboxRuntimeProvider),
        container.read(singboxRuntimeProvider),
      ),
      isTrue,
    );
    expect(
      identical(
        container.read(appUpdateServiceProvider),
        container.read(appUpdateServiceProvider),
      ),
      isTrue,
    );
    expect(
      identical(
        container.read(russiaRouteDataServiceProvider),
        container.read(russiaRouteDataServiceProvider),
      ),
      isTrue,
    );
  });

  test('mutable controllers are scoped to their provider container', () {
    final first = ProviderContainer();
    final second = ProviderContainer();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    final firstSettings = first.read(appSettingsControllerProvider);
    final secondSettings = second.read(appSettingsControllerProvider);

    expect(firstSettings, isA<AppSettingsController>());
    expect(identical(firstSettings, secondSettings), isFalse);
    firstSettings.setLocale('ru');
    expect(firstSettings.localeCode, 'ru');
    expect(secondSettings.localeCode, 'system');

    expect(
      identical(
        first.read(subscriptionRuntimeControllerProvider),
        second.read(subscriptionRuntimeControllerProvider),
      ),
      isFalse,
    );
  });
}
