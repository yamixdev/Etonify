import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Russia route status only needs daily update after 24 hours', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fresh = RussiaRouteDataStatus(
      available: true,
      sourceName: RussiaRouteDataService.sourceName,
      versionTag: RussiaRouteDataService.bundledTag,
      lastUpdateCheckAtMillis: now,
    );
    final stale = RussiaRouteDataStatus(
      available: true,
      sourceName: RussiaRouteDataService.sourceName,
      versionTag: RussiaRouteDataService.bundledTag,
      lastUpdateCheckAtMillis: DateTime.now()
          .subtract(const Duration(hours: 25))
          .millisecondsSinceEpoch,
    );

    expect(fresh.needsDailyUpdate, isFalse);
    expect(stale.needsDailyUpdate, isTrue);
  });

  group('domain-list rebuild policy', () {
    test('keeps installed files when downloaded content is unchanged', () {
      expect(
        shouldRebuildRussiaRouteDomainLists(
          currentDataAvailable: true,
          downloadedContentChanged: false,
          compiledFilesAvailable: true,
        ),
        isFalse,
      );
    });

    test('rebuilds when downloaded content changed', () {
      expect(
        shouldRebuildRussiaRouteDomainLists(
          currentDataAvailable: true,
          downloadedContentChanged: true,
          compiledFilesAvailable: true,
        ),
        isTrue,
      );
    });

    test('rebuilds when compiled output is missing', () {
      expect(
        shouldRebuildRussiaRouteDomainLists(
          currentDataAvailable: true,
          downloadedContentChanged: false,
          compiledFilesAvailable: false,
        ),
        isTrue,
      );
    });

    test('builds files for a fresh installation', () {
      expect(
        shouldRebuildRussiaRouteDomainLists(
          currentDataAvailable: false,
          downloadedContentChanged: false,
          compiledFilesAvailable: false,
        ),
        isTrue,
      );
    });
  });

  test('domain-list normalization keeps domains and rejects invalid rules', () {
    expect(normalizeRussiaRouteDomainForTest('..Example.COM..'), 'example.com');
    expect(
      normalizeRussiaRouteDomainForTest('cdn_service-1.example'),
      'cdn_service-1.example',
    );
    expect(normalizeRussiaRouteDomainForTest('example..com'), isNull);
    expect(normalizeRussiaRouteDomainForTest('regexp:^example'), isNull);
  });

  test('release archive is extracted in a background isolate', () async {
    final archive = base64Decode(
      'UEsDBBQAAAAIAAAAHl2jVcmtCAAAABAAAAAnAAAAcnVsZS1zZXQtZ2Vvc2l0ZS9nZW9zaXRlLXJ1LWJsb2NrZWQuc3JzCw4KZmRAAgBQSwMEFAAAAAgAAAAeXctE2EQHAAAAEAAAADUAAABydWxlLXNldC1nZW9zaXRlL2dlb3NpdGUtcnUtYXZhaWxhYmxlLW9ubHktaW5zaWRlLnNycwsOCmZEBgBQSwMEFAAAAAgAAAAeXTJxmqQIAAAAEAAAACgAAABydWxlLXNldC1nZW9zaXRlL2dlb3NpdGUtY2F0ZWdvcnktcnUuc3JzCw4KZmRCAgBQSwMEFAAAAAgAAAAeXVpgi00IAAAAEAAAACMAAABydWxlLXNldC1nZW9pcC9nZW9pcC1ydS1ibG9ja2VkLnNycwsOCmZkRgIAUEsDBBQAAAAIAAAAHl2BHG+/CAAAABAAAAAlAAAAcnVsZS1zZXQtZ2VvaXAvZ2VvaXAtcnUtd2hpdGVsaXN0LnNycwsOCmZkQQIAUEsDBBQAAAAIAAAAHl3pDX5WCAAAABAAAAAbAAAAcnVsZS1zZXQtZ2VvaXAvZ2VvaXAtcnUuc3JzCw4KZmRFAgBQSwECFAAUAAAACAAAAB5do1XJrQgAAAAQAAAAJwAAAAAAAAAAAAAAgAEAAAAAcnVsZS1zZXQtZ2Vvc2l0ZS9nZW9zaXRlLXJ1LWJsb2NrZWQuc3JzUEsBAhQAFAAAAAgAAAAeXctE2EQHAAAAEAAAADUAAAAAAAAAAAAAAIABTQAAAHJ1bGUtc2V0LWdlb3NpdGUvZ2Vvc2l0ZS1ydS1hdmFpbGFibGUtb25seS1pbnNpZGUuc3JzUEsBAhQAFAAAAAgAAAAeXTJxmqQIAAAAEAAAACgAAAAAAAAAAAAAAIABpwAAAHJ1bGUtc2V0LWdlb3NpdGUvZ2Vvc2l0ZS1jYXRlZ29yeS1ydS5zcnNQSwECFAAUAAAACAAAAB5dWmCLTQgAAAAQAAAAIwAAAAAAAAAAAAAAgAH1AAAAcnVsZS1zZXQtZ2VvaXAvZ2VvaXAtcnUtYmxvY2tlZC5zcnNQSwECFAAUAAAACAAAAB5dgRxvvwgAAAAQAAAAJQAAAAAAAAAAAAAAgAE+AQAAcnVsZS1zZXQtZ2VvaXAvZ2VvaXAtcnUtd2hpdGVsaXN0LnNyc1BLAQIUABQAAAAIAAAAHl3pDX5WCAAAABAAAAAbAAAAAAAAAAAAAACAAYkBAABydWxlLXNldC1nZW9pcC9nZW9pcC1ydS5zcnNQSwUGAAAAAAYABgD7AQAAygEAAAAA',
    );

    final extracted = await extractRussiaRouteArchiveForTest(archive);

    expect(extracted.keys, {
      'geositeRuBlocked',
      'geositeRuAvailableOnlyInside',
      'geositeCategoryRu',
      'geoipRuBlocked',
      'geoipRuWhitelist',
      'geoipRu',
    });
    for (final bytes in extracted.values) {
      expect(bytes.sublist(0, 3), [0x53, 0x52, 0x53]);
    }
  });

  group('route data version timestamp', () {
    test('parses release tags with and without bundled prefix', () {
      expect(
        parseRussiaRouteVersionTimestamp('202608261635'),
        DateTime(2026, 8, 26, 16, 35),
      );
      expect(
        parseRussiaRouteVersionTimestamp('bundled-202608291020'),
        DateTime(2026, 8, 29, 10, 20),
      );
    });

    test('rejects missing and invalid timestamps', () {
      expect(parseRussiaRouteVersionTimestamp('latest'), isNull);
      expect(parseRussiaRouteVersionTimestamp('202613401280'), isNull);
    });
  });

  test(
    'bundled smart routing installs offline and remains due for refresh',
    () async {
      await _withIsolatedRouteStorage(() async {
        final status = await RussiaRouteDataService.instance
            .ensureBundledInstalled();

        expect(status.available, isTrue);
        expect(status.sourceKind, RussiaRouteDataService.sourceKindBundled);
        expect(status.versionTag, RussiaRouteDataService.bundledTag);
        expect(
          status.verifiedAt,
          parseRussiaRouteVersionTimestamp(RussiaRouteDataService.bundledTag),
        );
        expect(status.needsDailyUpdate, isTrue);
        expect(status.verifiedFiles, hasLength(6));
        expect(status.curatedDirectServicesPath, isNull);
        expect(status.aiServicesPath, isNull);
        expect(File(status.geositeRuBlockedPath!).existsSync(), isTrue);
        expect(File(status.geoipRuPath!).existsSync(), isTrue);
      });
    },
  );

  test('bundled installation publishes and clears shared activity', () async {
    await _withIsolatedRouteStorage(() async {
      final service = RussiaRouteDataService.instance;
      final install = service.ensureBundledInstalled();

      expect(service.isUpdating, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(service.progress.value, isNotNull);

      await install;

      expect(service.isUpdating, isFalse);
      expect(service.progress.value, isNull);
    });
  });

  test('corrupt bundled SRS is rejected on the next status load', () async {
    await _withIsolatedRouteStorage(() async {
      final installed = await RussiaRouteDataService.instance
          .ensureBundledInstalled();
      await File(installed.geoipRuPath!).writeAsBytes([1, 2, 3, 4, 5]);

      final reloaded = await RussiaRouteDataService.instance.loadStatus();

      expect(reloaded.available, isFalse);
    });
  });

  test('smart routing progress is bounded for bytes and items', () {
    expect(
      const RussiaRouteUpdateProgress(
        stage: RussiaRouteUpdateStage.downloadingPackage,
        completedBytes: 25,
        totalBytes: 100,
      ).fraction,
      0.25,
    );
    expect(
      const RussiaRouteUpdateProgress(
        stage: RussiaRouteUpdateStage.downloadingCategories,
        completedItems: 12,
        totalItems: 4,
      ).fraction,
      1,
    );
    expect(
      const RussiaRouteUpdateProgress(
        stage: RussiaRouteUpdateStage.verifyingPackage,
      ).fraction,
      isNull,
    );
    expect(
      const RussiaRouteUpdateProgress(
        stage: RussiaRouteUpdateStage.downloadingCategories,
        completedItems: 12,
      ).fraction,
      isNull,
    );
  });
}

Future<T> _withIsolatedRouteStorage<T>(Future<T> Function() action) async {
  final root = await Directory.systemTemp.createTemp('etonify-route-test-');
  try {
    return await IOOverrides.runZoned(
      action,
      getSystemTempDirectory: () => root,
    );
  } finally {
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  }
}
