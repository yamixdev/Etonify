import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/physical_network_transition.dart';

void main() {
  test('probe to VPN on the same Android network keeps measurements', () {
    final probe = physicalNetworkKey(
      networkHandle: 101,
      interfaceName: 'wlan0',
      interfaceIndex: 12,
    );
    final vpn = physicalNetworkKey(
      networkHandle: 101,
      interfaceName: 'wlan0',
      interfaceIndex: 12,
    );

    expect(physicalNetworkChanged(probe, vpn), isFalse);
  });

  test('a new Android network on the same interface expires old pings', () {
    final oldWifi = physicalNetworkKey(
      networkHandle: 101,
      interfaceName: 'wlan0',
      interfaceIndex: 12,
    );
    final newWifi = physicalNetworkKey(
      networkHandle: 202,
      interfaceName: 'wlan0',
      interfaceIndex: 12,
    );

    expect(physicalNetworkChanged(oldWifi, newWifi), isTrue);
  });

  test('Wi-Fi to cellular expires old pings', () {
    final wifi = physicalNetworkKey(
      networkHandle: 101,
      interfaceName: 'wlan0',
      interfaceIndex: 12,
    );
    final cellular = physicalNetworkKey(
      networkHandle: 303,
      interfaceName: 'rmnet_data0',
      interfaceIndex: 18,
    );

    expect(physicalNetworkChanged(wifi, cellular), isTrue);
  });
}
