import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_launch_connection_policy.dart';

void main() {
  test('auto-connect only starts an idle configured VPN on launch', () {
    expect(
      shouldAutoConnectOnLaunch(
        enabled: true,
        onboardingCompleted: true,
        legalAccepted: true,
        hasActiveProfile: true,
        vpnInboundEnabled: true,
        runtimeActive: false,
      ),
      isTrue,
    );
    for (final disabled in [
      (
        enabled: false,
        onboarding: true,
        legal: true,
        profile: true,
        vpn: true,
        active: false,
      ),
      (
        enabled: true,
        onboarding: false,
        legal: true,
        profile: true,
        vpn: true,
        active: false,
      ),
      (
        enabled: true,
        onboarding: true,
        legal: false,
        profile: true,
        vpn: true,
        active: false,
      ),
      (
        enabled: true,
        onboarding: true,
        legal: true,
        profile: false,
        vpn: true,
        active: false,
      ),
      (
        enabled: true,
        onboarding: true,
        legal: true,
        profile: true,
        vpn: false,
        active: false,
      ),
      (
        enabled: true,
        onboarding: true,
        legal: true,
        profile: true,
        vpn: true,
        active: true,
      ),
    ]) {
      expect(
        shouldAutoConnectOnLaunch(
          enabled: disabled.enabled,
          onboardingCompleted: disabled.onboarding,
          legalAccepted: disabled.legal,
          hasActiveProfile: disabled.profile,
          vpnInboundEnabled: disabled.vpn,
          runtimeActive: disabled.active,
        ),
        isFalse,
      );
    }
  });
}
