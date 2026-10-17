import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

Future<AdBlockRuleSetStatus> _compileFixture(String content) async {
  final directory = await Directory.systemTemp.createTemp('adblock-fixture-');
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
  return HttpOverrides.runZoned(
    () => AdBlockRuleSetService.instance.downloadLatest(),
    createHttpClient: (_) => _FixtureHttpClient(utf8.encode(content)),
  );
}

class _FixtureHttpClient implements HttpClient {
  _FixtureHttpClient(this.bytes);
  final List<int> bytes;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (url.toString() != AdBlockRuleSetService.sourceUrl) {
      throw StateError('Unexpected fixture request: $url');
    }
    return _FixtureRequest(bytes);
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
  _FixtureRequest(this.bytes);
  final List<int> bytes;

  @override
  final HttpHeaders headers = _FixtureHeaders();

  @override
  set followRedirects(bool value) {}

  @override
  Future<HttpClientResponse> close() async => _FixtureResponse(bytes);

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
