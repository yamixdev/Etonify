import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';

void main() {
  group('AppVersionInfo', () {
    test('does not expose Android versionCode in display version', () {
      const info = AppVersionInfo(
        packageName: 'com.etonify.meow_client',
        versionName: '0.2.1',
        versionCode: 2005,
      );

      expect(info.displayVersion, '0.2.1');
      expect(info.updateBuildNumber, 5);
    });

    test('uses the current release label when native metadata is empty', () {
      const info = AppVersionInfo(
        packageName: 'com.etonify.meow_client',
        versionName: '',
        versionCode: 2012,
      );

      expect(info.displayVersion, '0.3.3');
      expect(info.updateBuildNumber, 12);
    });
  });

  group('SingboxRuntime Pigeon normalization', () {
    test('accepts installed app maps with Object keys', () {
      final value = <Object?>[
        <Object?, Object?>{
          'packageName': 'com.example.app',
          'label': 'Example',
          'system': false,
        },
      ];

      final normalized = normalizePigeonMapListForTest(value);

      expect(normalized, hasLength(1));
      expect(normalized.single['packageName'], 'com.example.app');
      expect(normalized.single['label'], 'Example');
      expect(normalized.single['system'], false);
    });
  });

  group('SingboxRuntime non-Android guards', () {
    test('prepareVpn returns !requiresVpn on non-Android', () async {
      expect(
        await SingboxRuntime.instance.prepareVpn(requiresVpn: true),
        isFalse,
      );
      expect(
        await SingboxRuntime.instance.prepareVpn(requiresVpn: false),
        isTrue,
      );
    });

    test('vpnPermissionGranted returns true on non-Android', () async {
      expect(await SingboxRuntime.instance.vpnPermissionGranted(), isTrue);
    });

    test('getConfigPath returns null on non-Android', () async {
      expect(await SingboxRuntime.instance.getConfigPath(), isNull);
    });

    test('status returns empty map on non-Android', () async {
      expect(await SingboxRuntime.instance.status(), isEmpty);
    });

    test('fetchUrlViaOutbound throws UnsupportedError on non-Android', () async {
      expect(
        () => SingboxRuntime.instance.fetchUrlViaOutbound(
          outboundTag: 'proxy',
          uri: Uri.parse('https://example.com'),
          headers: const {},
          maxBytes: 1024,
          timeout: const Duration(seconds: 5),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
