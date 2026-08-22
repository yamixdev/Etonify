import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/network/vpn_aware_remote_download.dart';

void main() {
  test('Android tries the VPN app route before the physical network', () {
    expect(
      remoteDownloadRouteOrderForTest(android: true),
      const <RemoteDownloadRoute>[
        RemoteDownloadRoute.app,
        RemoteDownloadRoute.underlying,
      ],
    );
    expect(
      remoteDownloadRouteOrderForTest(android: false),
      const <RemoteDownloadRoute>[RemoteDownloadRoute.app],
    );
  });

  test('physical network is used only after the app route fails', () async {
    final attempted = <RemoteDownloadRoute>[];

    final result = await runRemoteDownloadRouteAttemptsForTest<String>(
      routes: const <RemoteDownloadRoute>[
        RemoteDownloadRoute.app,
        RemoteDownloadRoute.underlying,
      ],
      attempt: (route) async {
        attempted.add(route);
        if (route == RemoteDownloadRoute.app) {
          throw const FormatException('tunnel unavailable');
        }
        return 'physical network';
      },
    );

    expect(result, 'physical network');
    expect(attempted, const <RemoteDownloadRoute>[
      RemoteDownloadRoute.app,
      RemoteDownloadRoute.underlying,
    ]);
  });

  test('successful VPN route does not touch the physical network', () async {
    final attempted = <RemoteDownloadRoute>[];

    final result = await runRemoteDownloadRouteAttemptsForTest<String>(
      routes: const <RemoteDownloadRoute>[
        RemoteDownloadRoute.app,
        RemoteDownloadRoute.underlying,
      ],
      attempt: (route) async {
        attempted.add(route);
        return 'tunnel';
      },
    );

    expect(result, 'tunnel');
    expect(attempted, const <RemoteDownloadRoute>[RemoteDownloadRoute.app]);
  });

  test('VPN settle readiness requires a stable VPN interface', () {
    const running = <String, dynamic>{
      'running': true,
      'mode': 'vpn',
      'nativeRecoveryPending': false,
    };

    expect(
      vpnRemoteRouteReadyForTest(status: running, interfaceAvailable: true),
      isTrue,
    );
    expect(
      vpnRemoteRouteReadyForTest(status: running, interfaceAvailable: false),
      isFalse,
    );
    expect(
      vpnRemoteRouteReadyForTest(
        status: running,
        interfaceAvailable: true,
        interfaceSettled: false,
      ),
      isFalse,
    );
    expect(
      vpnRemoteRouteReadyForTest(
        status: <String, dynamic>{...running, 'nativeRecoveryPending': true},
        interfaceAvailable: true,
      ),
      isFalse,
    );
    expect(
      vpnRemoteRouteReadyForTest(
        status: <String, dynamic>{...running, 'mode': 'proxy'},
        interfaceAvailable: true,
      ),
      isFalse,
    );
  });
}
