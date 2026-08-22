import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/network/vpn_aware_remote_download.dart';

void main() {
  test(
    'Android keeps the system route before physical fallback when Etonify VPN is off',
    () {
      expect(
        remoteDownloadRouteOrderForTest(android: true, vpnActive: false),
        const <RemoteDownloadRoute>[
          RemoteDownloadRoute.app,
          RemoteDownloadRoute.underlying,
        ],
      );
    },
  );

  test('VPN-off system route failure uses physical fallback', () async {
    final attempted = <RemoteDownloadRoute>[];

    await expectLater(
      runRemoteDownloadRouteAttemptsForTest<void>(
        routes: remoteDownloadRouteOrderForTest(
          android: true,
          vpnActive: false,
        ),
        attempt: (route) async {
          attempted.add(route);
          throw const FormatException('network route unavailable');
        },
      ),
      throwsA(isA<FormatException>()),
    );

    expect(attempted, const <RemoteDownloadRoute>[
      RemoteDownloadRoute.app,
      RemoteDownloadRoute.underlying,
    ]);
  });

  test('Android tries the VPN route before physical fallback when active', () {
    expect(
      remoteDownloadRouteOrderForTest(android: true, vpnActive: true),
      const <RemoteDownloadRoute>[
        RemoteDownloadRoute.app,
        RemoteDownloadRoute.underlying,
      ],
    );
  });

  test('unknown Android VPN state preserves tunnel-first routing', () {
    expect(
      remoteDownloadRouteOrderForTest(android: true, vpnActive: null),
      const <RemoteDownloadRoute>[
        RemoteDownloadRoute.app,
        RemoteDownloadRoute.underlying,
      ],
    );
  });

  test('non-Android platforms use their regular network route', () {
    expect(
      remoteDownloadRouteOrderForTest(android: false, vpnActive: false),
      const <RemoteDownloadRoute>[RemoteDownloadRoute.app],
    );
  });

  test('physical network is used only after the app route fails', () async {
    final attempted = <RemoteDownloadRoute>[];
    final notifications = <(RemoteDownloadRoute, bool)>[];

    final result = await runRemoteDownloadRouteAttemptsForTest<String>(
      routes: const <RemoteDownloadRoute>[
        RemoteDownloadRoute.app,
        RemoteDownloadRoute.underlying,
      ],
      onAttempt: (route, isFallback) {
        notifications.add((route, isFallback));
      },
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
    expect(notifications, const <(RemoteDownloadRoute, bool)>[
      (RemoteDownloadRoute.app, false),
      (RemoteDownloadRoute.underlying, true),
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
