import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/network/vpn_aware_remote_download.dart';

void main() {
  test(
    'underlying downloads stage bytes in the private temporary directory',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'etonify-private-download-test-',
      );
      try {
        final file = await createPrivateDownloadTemporaryFile(
          generation: 7,
          temporaryDirectoryProvider: () async => root,
          processIdentifier: 42,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(123456),
        );

        expect(file.parent.absolute.path, root.absolute.path);
        expect(file.path, endsWith('etonify-remote-42-123456-7.tmp'));
        expect(file.existsSync(), isFalse);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('capability cache retries after a failed read', () async {
    final cache = RetryableFutureCache<bool>();
    var reads = 0;

    Future<bool> load() async {
      reads++;
      if (reads == 1) {
        throw StateError('native bridge is not ready');
      }
      return true;
    }

    await expectLater(
      cache.resolve(load: load, timeout: const Duration(seconds: 1)),
      throwsStateError,
    );
    expect(
      await cache.resolve(load: load, timeout: const Duration(seconds: 1)),
      isTrue,
    );
    expect(reads, 2);
  });

  test('capability cache retries after a timed out read', () async {
    final cache = RetryableFutureCache<bool>();
    var reads = 0;

    Future<bool> load() {
      reads++;
      return reads == 1 ? Completer<bool>().future : Future<bool>.value(true);
    }

    await expectLater(
      cache.resolve(load: load, timeout: const Duration(milliseconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
    expect(
      await cache.resolve(load: load, timeout: const Duration(seconds: 1)),
      isTrue,
    );
    expect(reads, 2);
  });

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

  test('supported core uses the selected outbound without an app detour', () {
    expect(
      remoteDownloadRouteOrderForTest(
        android: true,
        vpnActive: true,
        supportsOutboundFetch: true,
      ),
      const <RemoteDownloadRoute>[
        RemoteDownloadRoute.outbound,
        RemoteDownloadRoute.underlying,
      ],
    );
  });

  test('large responses retain a streaming app fallback', () {
    expect(
      remoteDownloadRouteOrderForTest(
        android: true,
        vpnActive: true,
        supportsOutboundFetch: true,
        requiresAppFallback: true,
      ),
      const <RemoteDownloadRoute>[
        RemoteDownloadRoute.outbound,
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

  test('fallback starts only after the previous route terminates', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    var fallbackStarted = false;

    final result = runRemoteDownloadRouteAttemptsForTest<String>(
      routes: const <RemoteDownloadRoute>[
        RemoteDownloadRoute.outbound,
        RemoteDownloadRoute.underlying,
      ],
      attempt: (route) async {
        if (route == RemoteDownloadRoute.outbound) {
          firstStarted.complete();
          await releaseFirst.future;
          throw const FormatException('outbound failed');
        }
        fallbackStarted = true;
        return 'physical';
      },
    );

    await firstStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(fallbackStarted, isFalse);
    releaseFirst.complete();
    expect(await result, 'physical');
    expect(fallbackStarted, isTrue);
  });
}
