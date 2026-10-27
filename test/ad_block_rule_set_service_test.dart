import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';

late Directory _fixtureDirectory;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('safe domain compilation', () {
    for (final rule in [
      r'||scdn.co/audio/$media,redirect=noop-1s.mp4,domain=open.spotify.com',
      r'||soundcloud.com/audio-ad$1p,xhr',
      r'||spclient.wg.spotify.com/ad-logic/',
      r'||shared.example^$third-party',
      r'||shared.example^$dnstype=AAAA',
      r'||shared.example^$client=127.0.0.1',
      r'@@||shared.example^$domain=music.example',
      r'|https://shared.example/banner.js|',
      r'||ad*.shared.example^',
      r'||shared.example:443^',
    ]) {
      test('does not broaden scoped rule $rule', () async {
        final status = await _compileFixture('$rule\n||control.example^');
        expect(status.blockedDomainCount, 1);
        expect(status.allowedDomainCount, 0);
        expect(
          await _srsMatches(status.blockRuleSetPath!, 'shared.example'),
          isFalse,
        );
        expect(await _srsMatches(status.blockRuleSetPath!, 'scdn.co'), isFalse);
        expect(
          await _srsMatches(status.blockRuleSetPath!, 'soundcloud.com'),
          isFalse,
        );
      });
    }

    test('hosts and plain domains do not block their subdomains', () async {
      final status = await _compileFixture(
        '0.0.0.0 exact.example\nplain.example\n||suffix.example^',
      );
      expect(
        await _srsMatches(status.blockRuleSetPath!, 'exact.example'),
        isTrue,
      );
      expect(
        await _srsMatches(status.blockRuleSetPath!, 'music.exact.example'),
        isFalse,
      );
      expect(
        await _srsMatches(status.blockRuleSetPath!, 'plain.example'),
        isTrue,
      );
      expect(
        await _srsMatches(status.blockRuleSetPath!, 'music.plain.example'),
        isFalse,
      );
      expect(
        await _srsMatches(status.blockRuleSetPath!, 'music.suffix.example'),
        isTrue,
      );
      expect(
        await _srsMatches(status.blockRuleSetPath!, 'suffix.example.evil'),
        isFalse,
      );
    });

    test('important block overrides a broader ordinary exception', () async {
      final status = await _compileFixture(r'''
||shared.example^
@@||shared.example^
||ads.shared.example^$important
''');
      expect(await _isBlocked(status, 'ads.shared.example'), isTrue);
      expect(await _isBlocked(status, 'music.shared.example'), isFalse);
    });

    test('important exception overrides important block', () async {
      final status = await _compileFixture(r'''
||shared.example^$important
@@||music.shared.example^$important
''');
      expect(await _isBlocked(status, 'music.shared.example'), isFalse);
      expect(await _isBlocked(status, 'ads.shared.example'), isTrue);
    });

    test('important block survives an exception on the same domain', () async {
      final status = await _compileFixture(r'''
||ads.example^$important
@@||ads.example^
''');
      expect(await _isBlocked(status, 'ads.example'), isTrue);
    });

    test(
      'local sing-box accepts compiled priority and exception rules',
      () async {
        final status = await _compileFixture(r'''
||shared.example^
@@||music.shared.example^
||ads.shared.example^$important
@@||safe.ads.shared.example^$important
''');
        Future<bool> matches(String file, String domain) async {
          final result = await Process.run('etonify-core/sing-box.exe', [
            'rule-set',
            'match',
            '--format',
            'binary',
            file,
            domain,
          ]);
          expect(
            result.exitCode,
            0,
            reason: '${result.stdout} ${result.stderr}',
          );
          return '${result.stdout}${result.stderr}'.contains('match rules.');
        }

        for (final (domain, blocked) in [
          ('ads.shared.example', true),
          ('music.shared.example', false),
          ('safe.ads.shared.example', false),
        ]) {
          final actual =
              await matches(status.blockRuleSetPath!, domain) &&
              !await matches(status.allowRuleSetPath!, domain);
          expect(actual, blocked, reason: domain);
        }
      },
      skip:
          !Platform.isWindows ||
          !File('etonify-core/sing-box.exe').existsSync(),
    );
  });

  group('badfilter cancellation', () {
    for (final reversed in [false, true]) {
      test('cancels a block independently of order ($reversed)', () async {
        final lines = [
          r'||cancelled.example^',
          r'||cancelled.example^$badfilter',
        ];
        final status = await _compileFixture(
          (reversed ? lines.reversed : lines).join('\n'),
        );
        expect(status.blockedDomainCount, 0);
        expect(status.allowedDomainCount, 0);
        expect(
          ZLibDecoder().convert(
            File(status.blockRuleSetPath!).readAsBytesSync().sublist(4),
          ),
          [0],
        );
      });

      test('cancels an exception independently of order ($reversed)', () async {
        final lines = [
          r'||cancelled.example^',
          r'@@||cancelled.example^',
          r'@@||cancelled.example^$badfilter',
        ];
        final status = await _compileFixture(
          (reversed ? lines.reversed : lines).join('\n'),
        );
        expect(status.blockedDomainCount, 1);
        expect(status.allowedDomainCount, 0);
      });
    }

    test('matches the entire rule rather than removing its domain', () async {
      final status = await _compileFixture(r'''
||shared.example^
||shared.example^$important
||shared.example^$badfilter
||other.example^
||other.example^$important,badfilter
@@||exception.example^
||exception.example^$badfilter
''');
      expect(status.blockedDomainCount, 2);
      expect(status.allowedDomainCount, 1);
    });

    test('recognizes badfilter anywhere in the modifier list', () async {
      final status = await _compileFixture(r'''
||first.example^$important
||first.example^$badfilter,important
||last.example^$important
||last.example^$important,badfilter
||middle.example^$important,dnstype=A
||middle.example^$important,badfilter,dnstype=A
''');
      expect(status.blockedDomainCount, 0);
      expect(status.allowedDomainCount, 0);
    });

    test('does not cancel hosts rules or unrelated modifier values', () async {
      final status = await _compileFixture(r'''
0.0.0.0 hosts.example
0.0.0.0 hosts.example$badfilter
||ordinary.example^
||ordinary.example^$client=badfilter
''');
      expect(status.blockedDomainCount, 2);
    });
  });

  group('filter installation', () {
    for (final count in [null, 'invalid', -1, 0]) {
      test(
        'damaged exception count falls back instead of discarding exceptions: $count',
        () async {
          final old = await _compileFixture(
            '||old.example^\n@@||music.old.example^',
          );
          final updated = await _downloadFixture(
            '||new.example^\n@@||music.new.example^',
          );
          final manifest = File(
            '${File(updated.blockRuleSetPath!).parent.parent.path}/adguard_dns_meta.json',
          );
          final metadata =
              jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
          metadata['allowedDomainCount'] = count;
          await manifest.writeAsString(jsonEncode(metadata));
          final reloaded = await _inFixture(
            AdBlockRuleSetService.instance.loadStatus,
          );
          expect(reloaded.blockRuleSetPath, old.blockRuleSetPath);
          expect(await _isBlocked(reloaded, 'music.old.example'), isFalse);
        },
      );
    }

    test(
      'delete requested during download remains deleted after it completes',
      () async {
        await _compileFixture('||old.example^');
        final release = Completer<void>();
        final started = Completer<void>();
        final download = _downloadFixture(
          '||new.example^',
          gate: release.future,
          onRequest: () => started.complete(),
        );
        await started.future;
        final deletion = _inFixture(
          AdBlockRuleSetService.instance.deleteRuleSet,
        );
        release.complete();
        await download;
        await deletion;
        expect(
          (await _inFixture(
            AdBlockRuleSetService.instance.loadStatus,
          )).available,
          isFalse,
        );
      },
    );

    test(
      'cleanup retains current previous and in-use generations only',
      () async {
        final first = await _compileFixture('||first.example^');
        final second = await _downloadFixture('||second.example^');
        final third = await _downloadFixture('||third.example^');
        await _inFixture(
          () => AdBlockRuleSetService.instance.cleanupSupersededGenerations(
            protectedRuleSetPaths: [first.blockRuleSetPath!],
          ),
        );
        expect(File(first.blockRuleSetPath!).existsSync(), isTrue);
        expect(File(second.blockRuleSetPath!).existsSync(), isTrue);
        expect(File(third.blockRuleSetPath!).existsSync(), isTrue);
        final fourth = await _downloadFixture('||fourth.example^');
        await _inFixture(
          () => AdBlockRuleSetService.instance.cleanupSupersededGenerations(
            protectedRuleSetPaths: [fourth.blockRuleSetPath!],
          ),
        );
        expect(File(first.blockRuleSetPath!).existsSync(), isFalse);
        expect(File(second.blockRuleSetPath!).existsSync(), isFalse);
        expect(File(third.blockRuleSetPath!).existsSync(), isTrue);
        expect(File(fourth.blockRuleSetPath!).existsSync(), isTrue);
      },
    );

    test(
      'new generation does not modify the files used by the previous one',
      () async {
        final old = await _compileFixture(
          '||old.example^\n@@||music.old.example^',
        );
        final oldBytes = await File(old.blockRuleSetPath!).readAsBytes();
        final updated = await _downloadFixture(
          '||new.example^\n@@||music.new.example^',
        );
        expect(updated.blockRuleSetPath, isNot(old.blockRuleSetPath));
        expect(await File(old.blockRuleSetPath!).readAsBytes(), oldBytes);
        expect(await _isBlocked(old, 'old.example'), isTrue);
        expect(await _isBlocked(updated, 'new.example'), isTrue);
      },
    );

    test(
      'failed exception write preserves the complete last working generation',
      () async {
        final old = await _compileFixture(
          '||old.example^\n@@||music.old.example^',
        );
        final oldBlock = await File(old.blockRuleSetPath!).readAsBytes();
        final oldAllow = await File(old.allowRuleSetPath!).readAsBytes();
        await expectLater(
          IOOverrides.runWithIOOverrides(
            () => _downloadFixture('||new.example^\n@@||music.new.example^'),
            _FailAllowWriteOverrides(),
          ),
          throwsA(isA<FileSystemException>()),
        );
        final reloaded = await _inFixture(
          AdBlockRuleSetService.instance.loadStatus,
        );
        expect(reloaded.available, isTrue);
        expect(reloaded.blockRuleSetPath, old.blockRuleSetPath);
        expect(await File(reloaded.blockRuleSetPath!).readAsBytes(), oldBlock);
        expect(await File(reloaded.allowRuleSetPath!).readAsBytes(), oldAllow);
      },
    );

    test(
      'corrupt current generation falls back to the complete previous one',
      () async {
        final old = await _compileFixture(
          '||old.example^\n@@||music.old.example^',
        );
        final updated = await _downloadFixture(
          '||new.example^\n@@||music.new.example^',
        );
        await File(updated.allowRuleSetPath!).writeAsBytes([1, 2, 3]);
        final reloaded = await _inFixture(
          AdBlockRuleSetService.instance.loadStatus,
        );
        expect(reloaded.available, isTrue);
        expect(reloaded.blockRuleSetPath, old.blockRuleSetPath);
        expect(await _isBlocked(reloaded, 'old.example'), isTrue);
        expect(await _isBlocked(reloaded, 'music.old.example'), isFalse);
      },
    );

    for (final content in ['', '<!DOCTYPE html><html>Access denied</html>']) {
      test(
        'invalid download does not replace the working filter: $content',
        () async {
          final old = await _compileFixture('||old.example^');
          await expectLater(_downloadFixture(content), throwsFormatException);
          final reloaded = await _inFixture(
            AdBlockRuleSetService.instance.loadStatus,
          );
          expect(reloaded.blockRuleSetPath, old.blockRuleSetPath);
          expect(await _isBlocked(reloaded, 'old.example'), isTrue);
        },
      );
    }
  });

  test('adblock byte progress is bounded', () {
    expect(
      const AdBlockUpdateProgress(
        stage: AdBlockUpdateStage.downloading,
        completedBytes: 25,
        totalBytes: 100,
      ).fraction,
      0.25,
    );
    expect(
      const AdBlockUpdateProgress(
        stage: AdBlockUpdateStage.downloading,
        completedBytes: 125,
        totalBytes: 100,
      ).fraction,
      1,
    );
    expect(
      const AdBlockUpdateProgress(
        stage: AdBlockUpdateStage.connecting,
      ).fraction,
      isNull,
    );
  });

  test('adblock ETA is derived only from measurable downloads', () {
    expect(
      const AdBlockUpdateProgress(
        stage: AdBlockUpdateStage.downloading,
        completedBytes: 250,
        totalBytes: 1000,
        elapsedMilliseconds: 1000,
      ).estimatedSecondsRemaining,
      3,
    );
    expect(
      const AdBlockUpdateProgress(
        stage: AdBlockUpdateStage.compiling,
        completedBytes: 1000,
        totalBytes: 1000,
        elapsedMilliseconds: 1000,
      ).estimatedSecondsRemaining,
      isNull,
    );
  });
}

Future<bool> _isBlocked(AdBlockRuleSetStatus status, String domain) async =>
    await _srsMatches(status.blockRuleSetPath!, domain) &&
    (status.allowRuleSetPath == null ||
        !await _srsMatches(status.allowRuleSetPath!, domain));

Future<bool> _srsMatches(String path, String domain) async {
  final bytes = await File(path).readAsBytes();
  expect(bytes.take(4), [0x53, 0x52, 0x53, 2]);
  final body = ZLibDecoder().convert(bytes.sublist(4));
  var offset = 0;
  int byte() => body[offset++];
  int varint() {
    var value = 0;
    var shift = 0;
    while (true) {
      final current = byte();
      value |= (current & 0x7f) << shift;
      if (current < 128) return value;
      shift += 7;
    }
  }

  List<int> bitmap() {
    final count = varint();
    return List.generate(count, (_) {
      var word = 0;
      for (var index = 0; index < 8; index++) {
        word = (word << 8) | byte();
      }
      return word;
    });
  }

  bool matcher() {
    expect(byte(), 0);
    final leaves = bitmap();
    final labelsBitmap = bitmap();
    final labelCount = varint();
    final labels = body.sublist(offset, offset + labelCount);
    offset += labelCount;
    bool bit(List<int> words, int index) =>
        (words[index >> 6] & (1 << (index & 63))) != 0;
    final queue = <String>[''];
    var label = 0;
    var position = 0;
    var matched = false;
    for (var node = 0; node < queue.length; node++) {
      final key = queue[node];
      if (bit(leaves, node)) {
        final value = String.fromCharCodes(key.codeUnits.reversed);
        if (value.startsWith('\n')) {
          final suffix = value.substring(1);
          matched |= domain == suffix || domain.endsWith('.$suffix');
        } else {
          matched |= domain == value;
        }
      }
      while (!bit(labelsBitmap, position++)) {
        queue.add('$key${String.fromCharCode(labels[label++])}');
      }
    }
    return matched;
  }

  bool rule() {
    final type = byte();
    if (type == 0) {
      expect(byte(), 2);
      final matched = matcher();
      expect(byte(), 0xff);
      return byte() == 1 ? !matched : matched;
    }
    expect(type, 1);
    final mode = byte();
    final count = varint();
    final results = List.generate(count, (_) => rule());
    final matched = mode == 0 ? results.every((x) => x) : results.any((x) => x);
    return byte() == 1 ? !matched : matched;
  }

  final count = varint();
  final results = List.generate(count, (_) => rule());
  expect(offset, body.length);
  return results.any((x) => x);
}

Future<AdBlockRuleSetStatus> _compileFixture(String content) async {
  final directory = await Directory.systemTemp.createTemp('adblock-fixture-');
  _fixtureDirectory = directory;
  addTearDown(() => directory.delete(recursive: true));
  const channel = MethodChannel('etonify/windows_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async => null);
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  await AppDataPaths.resolve(
    DesktopLaunchContext(
      installationId: 'adblock-fixture',
      distribution: DesktopDistribution.portable,
      dataRoot: directory.path,
      startedAtLogin: false,
      minimized: false,
      ownerPid: 1,
    ),
  );
  return _downloadFixture(content);
}

Future<T> _inFixture<T>(Future<T> Function() action) => IOOverrides.runZoned(
  action,
  getSystemTempDirectory: () => _fixtureDirectory,
);

Future<AdBlockRuleSetStatus> _downloadFixture(
  String content, {
  Future<void>? gate,
  void Function()? onRequest,
}) => _inFixture(
  () => HttpOverrides.runZoned(
    () => AdBlockRuleSetService.instance.downloadLatest(),
    createHttpClient: (_) => _FixtureHttpClient(
      utf8.encode(content),
      gate: gate,
      onRequest: onRequest,
    ),
  ),
);

final class _FailAllowWriteOverrides extends IOOverrides {
  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path.contains('adguard_dns_allow.srs')
        ? _FailingWriteFile(file)
        : file;
  }
}

class _FailingWriteFile implements File {
  _FailingWriteFile(this.file);
  final File file;
  @override
  String get path => file.path;
  @override
  Directory get parent => file.parent;
  @override
  Future<bool> exists() => file.exists();
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      file.delete(recursive: recursive);
  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => Future.error(FileSystemException('Injected allow write failure', path));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixtureHttpClient implements HttpClient {
  _FixtureHttpClient(this.bytes, {this.gate, this.onRequest});
  final List<int> bytes;
  final Future<void>? gate;
  final void Function()? onRequest;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (url.toString() != AdBlockRuleSetService.sourceUrl) {
      throw StateError('Unexpected fixture request: $url');
    }
    onRequest?.call();
    return _FixtureRequest(bytes, gate);
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

class _FixtureRequest implements HttpClientRequest {
  _FixtureRequest(this.bytes, this.gate);
  final List<int> bytes;
  final Future<void>? gate;

  @override
  final HttpHeaders headers = _FixtureHeaders();

  @override
  set followRedirects(bool value) {}

  @override
  Future<HttpClientResponse> close() async {
    await gate;
    return _FixtureResponse(bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixtureResponse extends Stream<List<int>> implements HttpClientResponse {
  _FixtureResponse(this.bytes);
  final List<int> bytes;

  @override
  int get contentLength => bytes.length;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  final HttpHeaders headers = _FixtureHeaders();

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

class _FixtureHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String, List<String>) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
