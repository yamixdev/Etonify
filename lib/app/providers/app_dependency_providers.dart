import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/subscription_runtime_controller.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

/// Long-lived application dependencies.
///
/// Keeping their construction here gives feature providers one stable place
/// to obtain dependencies and lets tests override them without reaching into
/// the root widget state.
final singboxRuntimeProvider = Provider<SingboxRuntime>(
  (ref) => SingboxRuntime.instance,
  name: 'singboxRuntimeProvider',
);

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

final subscriptionRuntimeControllerProvider =
    Provider<SubscriptionRuntimeController>(
      (ref) => SubscriptionRuntimeController(),
      name: 'subscriptionRuntimeControllerProvider',
    );
