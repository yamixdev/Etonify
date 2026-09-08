import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/models/core_settings.dart';
import 'package:meow_client/singbox/libbox_capabilities.dart';

void main() {
  late Directory directory;
  late String cache;
  late String output;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('config-cache-test-');
    cache = '${directory.path}/cache.json';
    output = '${directory.path}/candidate.json';
  });
  tearDown(() => directory.deleteSync(recursive: true));

  test(
    'reuses a disk entry even after the previous candidate was moved',
    () async {
      final first = await buildOrReuseSingboxConfigInBackground(
        _input(output: output),
        cachePath: cache,
      );
      expect(first.reusedConfig, isFalse);
      final json = File(output).readAsStringSync();
      File(output).renameSync('${directory.path}/active.json');
      final second = await buildOrReuseSingboxConfigInBackground(
        _input(output: output),
        cachePath: cache,
      );
      expect(second.reusedConfig, isTrue);
      expect(File(output).readAsStringSync(), json);
      expect(
        second.plan.proxyOutboundTagsByIndex,
        first.plan.proxyOutboundTagsByIndex,
      );
      expect(second.plan.urlTestOutboundTags, first.plan.urlTestOutboundTags);
      expect(second.invalidOutboundCount, first.invalidOutboundCount);
    },
  );

  test(
    'core settings invalidate the config and reach background builder',
    () async {
      final defaults = _input(output: output);
      final changed = _input(
        output: output,
        coreSettings: const CoreSettings(connectTimeoutSeconds: 17),
      );
      final first = await buildOrReuseSingboxConfigInBackground(
        defaults,
        cachePath: cache,
      );
      final second = await buildOrReuseSingboxConfigInBackground(
        changed,
        cachePath: cache,
      );
      expect(first.reusedConfig, isFalse);
      expect(second.reusedConfig, isFalse);
      final proxies = (second.plan.config['outbounds'] as List).where(
        (o) => o['server'] != null,
      );
      expect(proxies, isNotEmpty);
      for (final proxy in proxies) {
        expect(proxy['connect_timeout'], '17s');
      }
      expect(
        (await buildOrReuseSingboxConfigInBackground(
          changed,
          cachePath: cache,
        )).reusedConfig,
        isTrue,
      );
    },
  );

  test(
    'server, settings, subscription content and capabilities invalidate',
    () async {
      final inputs = [
        _input(output: output),
        _input(output: output, selected: 'second'),
        _input(output: output, selected: 'second', mtu: 1400),
        _input(
          output: output,
          selected: 'second',
          mtu: 1400,
          subscription: _subscription(2, port: 8443),
        ),
        _input(
          output: output,
          selected: 'second',
          mtu: 1400,
          subscription: _subscription(2, port: 8443),
          capabilities: LibboxCapabilities.incompatible,
        ),
      ];
      final keys = <String>{};
      for (final input in inputs) {
        keys.add(await singboxConfigFingerprintInBackground(input));
      }
      expect(keys, hasLength(inputs.length));
      for (final input in inputs.take(4)) {
        final result = await buildOrReuseSingboxConfigInBackground(
          input,
          cachePath: cache,
        );
        expect(result.reusedConfig, isFalse);
        expect(
          (await buildOrReuseSingboxConfigInBackground(
            input,
            cachePath: cache,
          )).reusedConfig,
          isTrue,
        );
      }
    },
  );

  test('same path, size and mtime but changed rule bytes invalidate', () async {
    final rule = File('${directory.path}/rules.srs')..writeAsStringSync('abcd');
    final modified = rule.lastModifiedSync();
    final input = _input(output: output, rule: rule.path);
    final first = await buildOrReuseSingboxConfigInBackground(
      input,
      cachePath: cache,
    );
    rule.writeAsStringSync('efgh');
    rule.setLastModifiedSync(modified);
    final second = await buildOrReuseSingboxConfigInBackground(
      input,
      cachePath: cache,
    );
    expect(second.reusedConfig, isFalse);
    expect(second.inputFingerprint, isNot(first.inputFingerprint));
    rule.deleteSync();
    expect(
      await singboxConfigFingerprintInBackground(input),
      isNot(second.inputFingerprint),
    );
  });

  test(
    'corrupt or tampered cache is replaced, without orphan temp files',
    () async {
      final input = _input(output: output);
      await buildOrReuseSingboxConfigInBackground(input, cachePath: cache);
      final envelope =
          jsonDecode(File(cache).readAsStringSync()) as Map<String, dynamic>;
      envelope['payload'] = (envelope['payload'] as String).replaceAll(
        'example.com',
        'attacker.net',
      );
      File(cache).writeAsStringSync(jsonEncode(envelope));
      expect(
        (await buildOrReuseSingboxConfigInBackground(
          input,
          cachePath: cache,
        )).reusedConfig,
        isFalse,
      );
      File(cache).writeAsStringSync('{partial');
      expect(
        (await buildOrReuseSingboxConfigInBackground(
          input,
          cachePath: cache,
        )).reusedConfig,
        isFalse,
      );
      expect(
        directory.listSync().where((file) => file.path.contains('.tmp.')),
        isEmpty,
      );
      expect(
        jsonDecode(File(output).readAsStringSync()),
        isA<Map<String, dynamic>>(),
      );
    },
  );

  test(
    'large cached result preserves trimmed and full result contracts',
    () async {
      final subscription = _subscription(150);
      final coldWatch = Stopwatch()..start();
      final first = await buildOrReuseSingboxConfigInBackground(
        _input(output: output, subscription: subscription, returnConfig: false),
        cachePath: cache,
      );
      coldWatch.stop();
      final warmWatch = Stopwatch()..start();
      final second = await buildOrReuseSingboxConfigInBackground(
        _input(output: output, subscription: subscription, returnConfig: false),
        cachePath: cache,
      );
      warmWatch.stop();
      expect(first.configJson, isEmpty);
      expect(second.configJson, isEmpty);
      expect(second.plan.config, isEmpty);
      expect(second.reusedConfig, isTrue);
      expect(second.configOutboundCount, first.configOutboundCount);
      final full = await buildOrReuseSingboxConfigInBackground(
        _input(output: output, subscription: subscription),
        cachePath: cache,
      );
      expect(full.reusedConfig, isTrue);
      expect(full.configJson, File(output).readAsStringSync());
      expect(full.plan.config, isNotEmpty);
      // Diagnostic only: timing is deliberately not a flaky test assertion.
      // ignore: avoid_print
      print(
        '150 outbounds: cold=${coldWatch.elapsedMilliseconds}ms warm=${warmWatch.elapsedMilliseconds}ms',
      );
    },
  );

  test('in-place outbound mutation invalidates the fingerprint', () async {
    final subscription = _subscription(2);
    final input = _input(output: output, subscription: subscription);
    final key = await singboxConfigFingerprintInBackground(input);
    subscription.outbounds.first.config['server_port'] = 9443;
    expect(await singboxConfigFingerprintInBackground(input), isNot(key));
  });

  test(
    'invalid selected server allows only the generated lowest fallback',
    () async {
      final subscription = _subscription(2);
      subscription.outbounds.first.config['type'] = 'vless';
      subscription.outbounds.first.config['uuid'] = '';
      final build = await buildOrReuseSingboxConfigInBackground(
        _input(output: output, subscription: subscription),
        cachePath: cache,
      );
      expect(build.selectedProxyInvalid, isTrue);
      expect(
        build.fallbackInputFingerprint,
        isNotNull,
        reason: build.configJson,
      );
      expect(
        build.fallbackInputFingerprint,
        await singboxConfigFingerprintInBackground(
          _input(
            output: output,
            subscription: subscription,
            selected: 'lowest',
          ),
        ),
      );
      expect(
        build.fallbackInputFingerprint,
        isNot(
          await singboxConfigFingerprintInBackground(
            _input(
              output: output,
              subscription: subscription,
              selected: 'second',
            ),
          ),
        ),
      );
    },
  );

  test(
    'cache fingerprint explicitly covers every input and capability field',
    () {
      final source = File(
        'lib/app/app_background_tasks.dart',
      ).readAsStringSync();
      final inputSource = source
          .split('class SingboxConfigBuildInput {')[1]
          .split('class SingboxConfigBuildResult')[0];
      final cacheSource = File(
        'lib/app/singbox_config_cache.dart',
      ).readAsStringSync();
      final fields = RegExp(r'final [\w<>? ,]+ (\w+);');
      for (final match in fields.allMatches(inputSource)) {
        final field = match[1]!;
        if (field == 'returnConfig' || field == 'outputConfigPath') continue;
        expect(
          cacheSource,
          contains("'$field':"),
          reason: 'Missing input: $field',
        );
      }
      final capabilities = File(
        'lib/singbox/libbox_capabilities.dart',
      ).readAsStringSync();
      for (final match in fields.allMatches(capabilities)) {
        final field = match[1]!;
        expect(
          cacheSource,
          contains("'$field':"),
          reason: 'Missing capability: $field',
        );
      }
    },
  );
}

Subscription _subscription(int count, {int port = 443}) => Subscription(
  id: 'test',
  name: 'test',
  url: 'https://example.com/sub',
  outbounds: List.generate(
    count,
    (i) => Outbound(
      tag: i == 0
          ? 'first'
          : i == 1
          ? 'second'
          : 'proxy-$i',
      name: 'Proxy $i',
      config: {
        'type': 'trojan',
        'server': 'example.com',
        'server_port': port,
        'password': 'test',
        'tls': {'enabled': true},
      },
    ),
  ),
);

SingboxConfigBuildInput _input({
  CoreSettings coreSettings = const CoreSettings(),
  required String output,
  String selected = 'first',
  int mtu = 1500,
  String? rule,
  Subscription? subscription,
  bool returnConfig = true,
  LibboxCapabilities capabilities = LibboxCapabilities.bundledLegacy,
}) => SingboxConfigBuildInput(
  coreSettings: coreSettings,
  activeSubscription: subscription ?? _subscription(2),
  selectedProxyTag: selected,
  excludedOutboundTags: <String>{},
  vpnInboundEnabled: true,
  vpnMtu: mtu,
  vpnStrictRoute: false,
  vpnTunImplementation: TunImplementationPreference.mixed,
  proxyInboundEnabled: false,
  proxyMixedListen: '127.0.0.1',
  proxyMixedPort: 2080,
  dnsDirectResolver: 'local',
  dnsProxyResolver: 'https://dns.google/dns-query',
  dnsPreferIpv6: false,
  urlTestUrl: defaultUrlTestUrl,
  urlTestIntervalSeconds: 300,
  urlTestTimeoutSeconds: 5,
  urlTestConcurrency: 4,
  urlTestUnavailableCheckIntervalSeconds: 60,
  blockLeaks: true,
  adBlockEnabled: false,
  adBlockBlockRuleSetPath: rule,
  adBlockAllowRuleSetPath: null,
  useRussiaRouteData: false,
  russiaGeositeRuBlockedPath: null,
  russiaGeositeRuAvailableOnlyInsidePath: null,
  russiaGeositeCategoryRuPath: null,
  russiaGeoipRuBlockedPath: null,
  russiaGeoipRuWhitelistPath: null,
  russiaGeoipRuPath: null,
  russiaCuratedDirectServicesPath: null,
  russiaAiServicesPath: null,
  russiaSocialServicesPath: null,
  bypassLocalNetwork: true,
  splitRoutingMode: SplitRoutingMode.disabled,
  splitRoutingPackages: <String>[],
  logLevel: 'info',
  tcpFastOpenEnabled: false,
  tcpMultiPathEnabled: false,
  tlsFragmentationMode: TlsFragmentationMode.disabled,
  interruptExistingConnections: false,
  urlTestStrictTolerance: false,
  markAllServersRussia: false,
  capabilities: capabilities,
  outputConfigPath: output,
  returnConfig: returnConfig,
);
