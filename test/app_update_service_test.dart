import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/update/app_update_channel.dart';
import 'package:meow_client/data/update/app_update_service.dart';

void main() {
  group('AppUpdateService', () {
    const assets = [
      AppUpdateAsset(
        name: 'etonify-v0.1.0-universal.apk',
        downloadUrl: 'https://example.com/universal.apk',
        sizeBytes: 100,
      ),
      AppUpdateAsset(
        name: 'etonify-v0.1.0-arm64-v8a.apk',
        downloadUrl: 'https://example.com/arm64.apk',
        sizeBytes: 50,
      ),
      AppUpdateAsset(
        name: 'etonify-v0.1.0-x86_64.apk',
        downloadUrl: 'https://example.com/x86_64.apk',
        sizeBytes: 60,
      ),
    ];

    test('selects the current ABI before universal', () {
      final selected = AppUpdateService.selectAssetForAbis(assets, const [
        'arm64-v8a',
        'armeabi-v7a',
      ]);

      expect(selected?.name, 'etonify-v0.1.0-arm64-v8a.apk');
    });

    test('falls back to universal for unknown ABI', () {
      final selected = AppUpdateService.selectAssetForAbis(assets, const [
        'x86',
      ]);

      expect(selected?.name, 'etonify-v0.1.0-universal.apk');
    });

    test('normalizes version with and without v prefix', () {
      expect(AppUpdateService.normalizeVersion('v0.1.0'), '0.1.0');
      expect(AppUpdateService.normalizeVersion('0.1.0'), '0.1.0');
      expect(AppUpdateService.normalizeVersion('0.1.0+7'), '0.1.0');
      expect(AppUpdateService.extractBuildNumber('0.1.0+7'), 7);
      expect(
        AppUpdateService.extractBuildNumber(
          'Версия проекта обновлена до 0.2.0+4',
        ),
        4,
      );
    });

    test('compares versions', () {
      expect(AppUpdateService.isRemoteVersionNewer('0.1.1', '0.1.0'), isTrue);
      expect(AppUpdateService.isRemoteVersionNewer('0.1.0', '0.1.0'), isFalse);
      expect(AppUpdateService.isRemoteVersionNewer('0.1.0', '0.1.1'), isFalse);
      expect(
        AppUpdateService.isRemoteVersionNewer(
          '0.2.0',
          '0.2.0',
          remoteBuildNumber: 4,
          currentBuildNumber: 3,
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isRemoteVersionNewer(
          '0.2.0',
          '0.2.0',
          remoteBuildNumber: 4,
          currentBuildNumber: 4,
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isRemoteVersionNewer('0.2.0+4', '0.2.0+3'),
        isTrue,
      );
      expect(
        AppUpdateService.compareVersions(
          '0.3.0',
          '0.3.0-beta.5',
          remoteBuildNumber: 20,
          currentBuildNumber: 18,
        ),
        AppUpdateVersionRelation.remoteNewer,
      );
      expect(
        AppUpdateService.compareVersions(
          '0.3.0',
          '0.3.0-beta.5',
          remoteBuildNumber: 18,
          currentBuildNumber: 20,
        ),
        AppUpdateVersionRelation.currentNewer,
      );
    });

    test('selects only releases belonging to the chosen channel', () {
      final releases = <Map<String, Object?>>[
        {'tag_name': 'v0.4.0', 'draft': true, 'prerelease': false},
        {'tag_name': 'v0.3.1-beta.2', 'draft': false, 'prerelease': true},
        {'tag_name': 'v0.3.0', 'draft': false, 'prerelease': false},
      ];

      expect(
        AppUpdateService.selectReleaseForChannel(
          releases,
          AppUpdateChannel.stable,
        )?['tag_name'],
        'v0.3.0',
      );
      expect(
        AppUpdateService.selectReleaseForChannel(
          releases,
          AppUpdateChannel.beta,
        )?['tag_name'],
        'v0.3.1-beta.2',
      );
      expect(
        AppUpdateService.selectReleaseForChannel(const <Map<String, Object?>>[
          {'tag_name': 'v0.3.0', 'prerelease': false},
        ], AppUpdateChannel.beta),
        isNull,
      );
    });

    test('recognizes alpha, beta, and RC build labels', () {
      expect(AppUpdateService.isPrereleaseVersion('0.3.0-alpha.1'), isTrue);
      expect(AppUpdateService.isPrereleaseVersion('0.3.0-beta.5'), isTrue);
      expect(AppUpdateService.isPrereleaseVersion('0.3.0-rc.1'), isTrue);
      expect(AppUpdateService.isPrereleaseVersion('0.3.0'), isFalse);
      expect(
        AppUpdateService.releaseVersionLabel('v0.3.0-rc.1', fallback: '0.3.0'),
        '0.3.0-rc.1',
      );
    });

    test('keeps user-facing update version without build code', () {
      const info = AppUpdateInfo(
        version: '0.2.1',
        buildNumber: 5,
        tagName: '0.2.1',
        title: '0.2.1',
        body: '',
        htmlUrl: 'https://example.com/release',
        publishedAt: null,
        asset: AppUpdateAsset(
          name: 'etonify-v0.2.1-arm64-v8a.apk',
          downloadUrl: 'https://example.com/app.apk',
          sizeBytes: 100,
        ),
      );

      expect(info.displayVersion, '0.2.1');
      expect(info.technicalVersion, '0.2.1+5');
    });

    test('persists prerelease channel metadata', () {
      const info = AppUpdateInfo(
        version: '0.3.0',
        buildNumber: 19,
        tagName: 'v0.3.0-rc.1',
        title: 'Etonify 0.3.0 RC 1',
        body: '',
        htmlUrl: 'https://example.com/release',
        publishedAt: null,
        asset: AppUpdateAsset(
          name: 'etonify-v0.3.0-rc.1-arm64-v8a.apk',
          downloadUrl: 'https://example.com/app.apk',
          sizeBytes: 100,
        ),
        channel: AppUpdateChannel.beta,
        isPrerelease: true,
        releaseLabel: '0.3.0-rc.1',
      );

      final restored = AppUpdateInfo.fromMap(info.toMap());

      expect(restored, isNotNull);
      expect(restored!.channel, AppUpdateChannel.beta);
      expect(restored.isPrerelease, isTrue);
      expect(restored.displayVersion, '0.3.0-rc.1');
    });

    test('sanitizes APK asset file names', () {
      expect(
        AppUpdateService.sanitizeAssetFileName('etonify v0.1.0 arm64-v8a.apk'),
        'etonify-v0.1.0-arm64-v8a.apk',
      );
      expect(
        AppUpdateService.sanitizeAssetFileName('not-an-apk.zip'),
        'etonify-update.apk',
      );
    });

    test('parses release manifest compatibility and integrity metadata', () {
      final sha256 = List.filled(32, 'ab').join();
      final manifest = AppUpdateManifest.fromJson({
        'version': 'v0.2.1+5',
        'buildNumber': 5,
        'minSdk': 24,
        'packageName': 'com.etonify.meow_client',
        'assets': [
          {
            'name': 'etonify-v0.2.1-arm64-v8a.apk',
            'sizeBytes': 123456,
            'sha256': sha256,
          },
        ],
      });

      expect(manifest, isNotNull);
      expect(manifest!.version, '0.2.1');
      expect(manifest.buildNumber, 5);
      expect(manifest.minimumAndroidSdk, 24);
      expect(manifest.packageName, 'com.etonify.meow_client');
      expect(
        manifest.assets['etonify-v0.2.1-arm64-v8a.apk']?.sizeBytes,
        123456,
      );
      expect(manifest.assets['etonify-v0.2.1-arm64-v8a.apk']?.sha256, sha256);
    });

    test('rejects a manifest without version, package, or asset list', () {
      expect(AppUpdateManifest.fromJson(null), isNull);
      expect(
        AppUpdateManifest.fromJson({
          'version': '0.2.1',
          'packageName': '',
          'assets': const <dynamic>[],
        }),
        isNull,
      );
      expect(
        AppUpdateManifest.fromJson({
          'version': '',
          'packageName': 'com.etonify.meow_client',
          'assets': const <dynamic>[],
        }),
        isNull,
      );
    });
  });
}
