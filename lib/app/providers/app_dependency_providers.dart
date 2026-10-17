import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/app/app_bootstrap_controller.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/subscription_runtime_controller.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';
import 'package:meow_client/platform/windows/desktop_runtime_client.dart';

/// Long-lived application dependencies.
///
/// Keeping their construction here gives feature providers one stable place
/// to obtain dependencies and lets tests override them without reaching into
/// the root widget state.
final desktopRuntimeClientProvider = Provider<DesktopRuntimeClient>(
  (ref) => SingboxRuntime.instance.windowsClient,
  name: 'desktopRuntimeClientProvider',
);

final singboxRuntimeProvider = Provider<SingboxRuntime>((ref) {
  final runtime = SingboxRuntime.instance;
  final settings = ref.read(appSettingsControllerProvider);
  runtime.bindWindowsRuntime(
    client: ref.read(desktopRuntimeClientProvider),
    modes: () => settings.windowsModes,
  );
  return runtime;
}, name: 'singboxRuntimeProvider');

final appUpdateServiceProvider = Provider<AppUpdateService>(
  (ref) => AppUpdateService.instance,
  name: 'appUpdateServiceProvider',
);

final adBlockRuleSetServiceProvider = Provider<AdBlockRuleSetService>(
  (ref) => AdBlockRuleSetService.instance,
  name: 'adBlockRuleSetServiceProvider',
);

final russiaRouteDataServiceProvider = Provider<RussiaRouteDataService>(
  (ref) => RussiaRouteDataService.instance,
  name: 'russiaRouteDataServiceProvider',
);

final appSettingsControllerProvider = Provider<AppSettingsController>(
  (ref) => AppSettingsController(),
  name: 'appSettingsControllerProvider',
);

final appBootstrapControllerProvider =
    Provider.family<AppBootstrapController, String>((ref, fallbackVersion) {
      final runtime = ref.read(singboxRuntimeProvider);
      return AppBootstrapController(
        fallbackClientVersionLabel: fallbackVersion,
        loadAppVersionInfo: runtime.getAppVersionInfo,
        loadCoreCapabilities: runtime.getCoreCapabilities,
      );
    });

final subscriptionRuntimeControllerProvider =
    Provider<SubscriptionRuntimeController>(
      (ref) => SubscriptionRuntimeController(),
      name: 'subscriptionRuntimeControllerProvider',
    );
