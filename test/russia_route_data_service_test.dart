import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'support/windows_storage_fixture.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'generation cleanup preserves runtime pins and rollback, not newest two alone',
    () async {
      await _withIsolatedRouteStorage(() async {
        final old = await _updateFixture({'category-ai-!cn': 'old.fixture'});
        final obsolete = await _updateFixture({
          'category-ai-!cn': 'obsolete.fixture',
        }, force: true);
        final previous = await _updateFixture({
          'category-ai-!cn': 'previous.fixture',
        }, force: true);
        final current = await _updateFixture({
          'category-ai-!cn': 'current.fixture',
        }, force: true);
        final base = _manifestFile(current).parent;
        final unrelated = Directory(
          '${base.path}/domain-list-compiled-user-data',
        );
        await unrelated.create();
        await File('${unrelated.path}/keep').writeAsString('unrelated');
        final runtimePaths = [old.aiServicesPath!, old.socialServicesPath!];
        await RussiaRouteDataService.instance.cleanupSupersededDomainLists(
          protectedRuleSetPaths: runtimePaths,
        );
        expect(File(old.aiServicesPath!).existsSync(), isTrue);
        expect(File(previous.aiServicesPath!).existsSync(), isTrue);
        expect(File(current.aiServicesPath!).existsSync(), isTrue);
        expect(
          Directory(File(obsolete.aiServicesPath!).parent.path).existsSync(),
          isFalse,
        );
        expect(File('${unrelated.path}/keep').readAsStringSync(), 'unrelated');
      });
    },
  );

  test('cleanup fails closed for unreadable metadata', () async {
    await _withIsolatedRouteStorage(() async {
      final current = await _updateFixture({
        'category-ai-!cn': 'current.fixture',
      });
      final manifest = _manifestFile(current);
      final obsolete = Directory(
        '${manifest.parent.path}/domain-list-compiled-v1-100',
      );
      await obsolete.create();
      await File('${obsolete.path}/keep').writeAsString('intact');
      await manifest.writeAsString('{broken');
      await RussiaRouteDataService.instance.cleanupSupersededDomainLists(
        protectedRuleSetPaths: <String>[],
      );
      expect(File('${obsolete.path}/keep').readAsStringSync(), 'intact');
      expect(File(current.aiServicesPath!).existsSync(), isTrue);
    });
  });

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

  test('cleanup never follows linked generation directories', () async {
    await _withIsolatedRouteStorage(() async {
      final current = await _updateFixture({
        'category-ai-!cn': 'current.fixture',
      });
      final base = _manifestFile(current).parent;
      final outside = Directory('${base.parent.path}/outside');
      await outside.create();
      final marker = File('${outside.path}/keep');
      await marker.writeAsString('external');
      final link = Link('${base.path}/domain-list-compiled-v1-100');
      try {
        await link.create(outside.path);
      } on FileSystemException catch (error) {
        markTestSkipped(
          'Directory links unavailable: ${error.osError?.errorCode}',
        );
        return;
      }
      await RussiaRouteDataService.instance.cleanupSupersededDomainLists(
        protectedRuleSetPaths: <String>[],
      );
      expect(await marker.readAsString(), 'external');
      expect(await link.exists(), isTrue);
    });
  });

  test('corrupt previous metadata does not prevent bundled recovery', () async {
    await _withIsolatedRouteStorage(() async {
      final current = await _updateFixture({
        'category-ai-!cn': 'current.fixture',
      });
      await _manifestFile(current).writeAsString('{broken');
      final recovered = await RussiaRouteDataService.instance
          .ensureBundledInstalled();
      expect(recovered.available, isTrue);
      expect(File(recovered.geositeRuBlockedPath!).existsSync(), isTrue);
    });
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

  test(
    'compiler preserves attributes and selective nested includes in SRS',
    () async {
      await _withIsolatedRouteStorage(() async {
        final status = await _updateFixture({
          'category-ai-!cn': '''
coze.fixture @!cn
domain:trae.fixture @!cn @extra
full:api.dola.fixture @!cn
ads.fixture @ads
ads2.fixture @ads @!cn
include:filtered @!cn @-ads
include:filtered @other
include:nested @!cn
''',
          'filtered': '''
selected.fixture @!cn
excluded.fixture
excluded-ad.fixture @!cn @ads
other.fixture @other
''',
          'nested': 'include:leaf @other\ninclude:category-ai-!cn',
          'leaf': 'nested.fixture @other @!cn\nnot-nested.fixture @!cn',
        });
        expect(await _srsDomains(File(status.aiServicesPath!)), {
          'suffix:coze.fixture',
          'suffix:trae.fixture',
          'exact:api.dola.fixture',
          'suffix:selected.fixture',
          'suffix:other.fixture',
          'suffix:nested.fixture',
        });
      });
    },
  );

  test(
    'status migrates cached sources once without network or a daily update',
    () async {
      await _withIsolatedRouteStorage(() async {
        final installed = await _updateFixture({
          'category-ai-!cn': 'legacy.fixture',
        });
        final manifest = _manifestFile(installed);
        final metadata =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        metadata.remove('domainListCommunityCompilerVersion');
        metadata['lastUpdateCheckAtMillis'] =
            DateTime.now().millisecondsSinceEpoch;
        await manifest.writeAsString(jsonEncode(metadata));
        final source = File(
          '${manifest.parent.path}/domain-list-community/category-ai-!cn.txt',
        );
        await source.writeAsString('coze.fixture @!cn');
        final legacyBytes = await File(installed.aiServicesPath!).readAsBytes();
        final service = RussiaRouteDataService.instance;
        final migrated = await HttpOverrides.runZoned(
          () => service.loadStatus(),
          createHttpClient: (_) =>
              throw StateError('Migration must stay offline'),
        );
        expect(await _srsDomains(File(migrated.aiServicesPath!)), {
          'suffix:coze.fixture',
        });
        expect(migrated.needsDailyUpdate, isFalse);
        expect(
          await File(installed.aiServicesPath!).readAsBytes(),
          legacyBytes,
        );

        final migratedFile = File(migrated.aiServicesPath!);
        final sentinel = DateTime(2020);
        await migratedFile.setLastModified(sentinel);
        final reloaded = await service.loadStatus();
        expect(reloaded.aiServicesPath, migrated.aiServicesPath);
        expect(await migratedFile.lastModified(), sentinel);
      });
    },
  );

  test(
    'failed cached migration preserves installed data and retries after repair',
    () async {
      await _withIsolatedRouteStorage(() async {
        final installed = await _updateFixture({
          'category-ai-!cn': 'working.fixture',
        });
        final manifest = _manifestFile(installed);
        final metadata =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        metadata.remove('domainListCommunityCompilerVersion');
        await manifest.writeAsString(jsonEncode(metadata));
        final before = await manifest.readAsString();
        final source = File(
          '${manifest.parent.path}/domain-list-community/category-ai-!cn.txt',
        );
        await source.writeAsString('include:missing-fixture');

        final failed = await RussiaRouteDataService.instance.loadStatus();
        expect(failed.available, isTrue);
        expect(await _srsDomains(File(failed.aiServicesPath!)), {
          'suffix:working.fixture',
        });
        expect(await manifest.readAsString(), before);

        await source.writeAsString('repaired.fixture @!cn');
        final repaired = await RussiaRouteDataService.instance.loadStatus();
        expect(await _srsDomains(File(repaired.aiServicesPath!)), {
          'suffix:repaired.fixture',
        });
      });
    },
  );

  test(
    '304 update recompiles an old compiler version and then reuses SRS',
    () async {
      await _withIsolatedRouteStorage(() async {
        final installed = await _updateFixture({
          'category-ai-!cn': 'old.fixture',
        });
        final manifest = _manifestFile(installed);
        final metadata =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        metadata.remove('domainListCommunityCompilerVersion');
        await manifest.writeAsString(jsonEncode(metadata));
        await File(
          '${manifest.parent.path}/domain-list-community/category-ai-!cn.txt',
        ).writeAsString('updated.fixture @!cn');
        Future<RussiaRouteDataStatus> updateNotModified() =>
            HttpOverrides.runZoned(
              () => RussiaRouteDataService.instance.ensureUpdated(),
              createHttpClient: (_) =>
                  _RouteFixtureHttpClient({}, notModified: true),
            );

        final updated = await updateNotModified();
        expect(await _srsDomains(File(updated.aiServicesPath!)), {
          'suffix:updated.fixture',
        });
        expect(updated.aiServicesPath, isNot(installed.aiServicesPath));
        final file = File(updated.aiServicesPath!);
        final sentinel = DateTime(2020);
        await file.setLastModified(sentinel);
        final unchanged = await updateNotModified();
        expect(unchanged.aiServicesPath, updated.aiServicesPath);
        expect(await file.lastModified(), sentinel);
      });
    },
  );

  test(
    'fresh data still migrates through ensureUpdated without network',
    () async {
      await _withIsolatedRouteStorage(() async {
        final installed = await _updateFixture({
          'category-ai-!cn': 'old.fixture',
        });
        final manifest = _manifestFile(installed);
        final metadata =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        metadata.remove('domainListCommunityCompilerVersion');
        metadata['lastUpdateCheckAtMillis'] =
            DateTime.now().millisecondsSinceEpoch;
        await manifest.writeAsString(jsonEncode(metadata));
        await File(
          '${manifest.parent.path}/domain-list-community/category-ai-!cn.txt',
        ).writeAsString('fresh.fixture @!cn');
        final updated = await HttpOverrides.runZoned(
          () => RussiaRouteDataService.instance.ensureUpdated(),
          createHttpClient: (_) =>
              throw StateError('Fresh cached migration must stay offline'),
        );
        expect(await _srsDomains(File(updated.aiServicesPath!)), {
          'suffix:fresh.fixture',
        });
      });
    },
  );

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

  test('smart routing progress tracks isRetryingWithoutVpn and copyWith', () {
    const initial = RussiaRouteUpdateProgress(
      stage: RussiaRouteUpdateStage.downloadingPackage,
      completedBytes: 10,
      totalBytes: 50,
    );
    expect(initial.isRetryingWithoutVpn, isFalse);

    final retrying = initial.copyWith(isRetryingWithoutVpn: true);
    expect(retrying.isRetryingWithoutVpn, isTrue);
    expect(retrying.stage, RussiaRouteUpdateStage.downloadingPackage);
    expect(retrying.completedBytes, 10);
    expect(retrying.totalBytes, 50);

    final extracting = retrying.copyWith(
      stage: RussiaRouteUpdateStage.extractingPackage,
      isRetryingWithoutVpn: false,
    );
    expect(extracting.stage, RussiaRouteUpdateStage.extractingPackage);
    expect(extracting.isRetryingWithoutVpn, isFalse);
  });
}

File _manifestFile(RussiaRouteDataStatus status) => File(
  '${File(status.geositeRuBlockedPath!).parent.parent.path}/manifest.json',
);

Future<RussiaRouteDataStatus> _updateFixture(
  Map<String, String> categories, {
  bool force = false,
}) async {
  final installed = await RussiaRouteDataService.instance
      .ensureBundledInstalled();
  if (force) {
    final manifest = _manifestFile(installed);
    final metadata =
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    metadata['lastUpdateCheckAtMillis'] = 0;
    await manifest.writeAsString(jsonEncode(metadata));
  }
  return HttpOverrides.runZoned(
    () => RussiaRouteDataService.instance.ensureUpdated(),
    createHttpClient: (_) => _RouteFixtureHttpClient(categories),
  );
}

class _RouteFixtureHttpClient implements HttpClient {
  _RouteFixtureHttpClient(this.categories, {this.notModified = false});
  final Map<String, String> categories;
  final bool notModified;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (url.host == 'api.github.com') {
      return _RouteFixtureRequest('', HttpStatus.notFound);
    }
    if (url.host != 'raw.githubusercontent.com' ||
        !url.path.startsWith('/v2fly/domain-list-community/master/data/')) {
      throw StateError('Unexpected fixture request: $url');
    }
    return _RouteFixtureRequest(
      categories[url.pathSegments.last] ?? 'base.fixture',
      notModified ? HttpStatus.notModified : HttpStatus.ok,
    );
  }

  @override
  void close({bool force = false}) {}
  @override
  set connectionTimeout(Duration? value) {}
  @override
  set idleTimeout(Duration value) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RouteFixtureRequest implements HttpClientRequest {
  _RouteFixtureRequest(this.content, this.status);
  final String content;
  final int status;
  @override
  final _RouteFixtureHeaders headers = _RouteFixtureHeaders();
  @override
  set followRedirects(bool value) {}
  @override
  Future<HttpClientResponse> close() async {
    if (status == HttpStatus.notModified &&
        headers.values['If-None-Match'] != '"fixture"') {
      throw StateError('304 fixture requires a conditional request');
    }
    return _RouteFixtureResponse(
      status == HttpStatus.notModified ? [] : utf8.encode(content),
      status,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RouteFixtureResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _RouteFixtureResponse(this.bytes, this.statusCode);
  final List<int> bytes;
  @override
  final int statusCode;
  @override
  int get contentLength => bytes.length;
  @override
  final HttpHeaders headers = _RouteFixtureHeaders();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RouteFixtureHeaders implements HttpHeaders {
  final values = <String, Object>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  void forEach(void Function(String, List<String>) action) =>
      action('etag', ['"fixture"']);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Set<String>> _srsDomains(File file) async {
  final bytes = await file.readAsBytes();
  expect(bytes.take(4), [0x53, 0x52, 0x53, 2]);
  final body = Uint8List.fromList(ZLibDecoder().convert(bytes.sublist(4)));
  var offset = 0;
  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final value = body[offset++];
      result |= (value & 0x7f) << shift;
      if (value < 128) return result;
      shift += 7;
    }
  }

  final rules = readVarint();
  if (rules == 0) return {};
  expect(rules, 1);
  expect(body[offset++], 0);
  expect(body[offset++], 2);
  expect(body[offset++], 0);
  List<int> readBitmap() {
    final length = readVarint();
    final view = ByteData.sublistView(body);
    return List.generate(length, (_) {
      final word = view.getUint64(offset);
      offset += 8;
      return word;
    });
  }

  final leaves = readBitmap();
  final bitmap = readBitmap();
  final labelCount = readVarint();
  final labels = body.sublist(offset, offset + labelCount);
  bool bit(List<int> words, int index) =>
      (words[index >> 6] & (1 << (index & 63))) != 0;
  final queue = <String>[''];
  final result = <String>{};
  var label = 0;
  var bitmapIndex = 0;
  for (var node = 0; node < queue.length; node++) {
    final key = queue[node];
    if (bit(leaves, node)) {
      final domain = String.fromCharCodes(key.codeUnits.reversed);
      result.add(
        domain.startsWith('\n')
            ? 'suffix:${domain.substring(1)}'
            : 'exact:$domain',
      );
    }
    while (!bit(bitmap, bitmapIndex++)) {
      queue.add('$key${String.fromCharCode(labels[label++])}');
    }
  }
  return result;
}

Future<T> _withIsolatedRouteStorage<T>(Future<T> Function() action) async {
  final root = await Directory.systemTemp.createTemp('etonify-route-test-');
  await bootstrapWindowsStorageFixture(root);
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
