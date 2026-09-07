import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_background_tasks.dart';
import 'package:meow_client/app/runtime_recovery_controller.dart';
import 'package:meow_client/singbox/singbox_config_builder.dart';

void main() {
  test('retry generations reject cancelled and stale callbacks', () async {
    final controller = RuntimeRecoveryController(
      retryDelay: const Duration(milliseconds: 1),
    );
    final callbacks = <int>[];

    final first = controller.scheduleRetry(callbacks.add);
    expect(controller.isCurrent(first, ownerActive: true), isTrue);
    expect(controller.cancelRetry(), isTrue);
    expect(controller.isCurrent(first, ownerActive: true), isFalse);

    final second = controller.scheduleRetry(callbacks.add);
    expect(second, greaterThan(first));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(callbacks, <int>[second]);
    controller.dispose();
  });

  test(
    'invalid outbound is excluded once using cached build mapping',
    () async {
      final controller = RuntimeRecoveryController();
      controller.cacheStartedBuild(_buildResult(tagsByIndex: {4: 'bad-tag'}));

      final recovery = await controller.registerInvalidOutboundError(
        'initialize outbound[4]: invalid Reality public key',
      );

      expect(recovery?.tag, 'bad-tag');
      expect(controller.excludedOutboundTags, contains('bad-tag'));
      expect(
        await controller.registerInvalidOutboundError(
          'initialize outbound[4]: invalid Reality public key',
        ),
        isNull,
      );
    },
  );

  test(
    'mutation input uses cached config and updates it after mutation',
    () async {
      final controller = RuntimeRecoveryController();
      controller.cacheStartedBuild(
        _buildResult(
          tagsByIndex: {1: 'bad-tag'},
          urlTestTags: const ['bad-tag', 'healthy-tag'],
        ),
      );
      expect(controller.lastStartedUrlTestOutboundTags, {
        'bad-tag',
        'healthy-tag',
      });
      await controller.registerInvalidOutboundError(
        'initialize outbound[1]: unsupported transport',
      );

      final input = controller.createMutationInput('config.json');
      expect(input?.tagToRemove, 'bad-tag');
      expect(input?.outputPath, 'config.json');

      controller.applyMutation(
        const ConfigMutationResult(
          config: <String, dynamic>{'outbounds': <Object>[]},
          proxyOutboundTagsByIndex: <int, String>{},
          configPath: 'config.json',
          outboundCount: 0,
          startableProxyCount: 0,
        ),
      );
      expect(controller.createMutationInput('config.json'), isNull);
      expect(controller.lastStartedUrlTestOutboundTags, {'healthy-tag'});
      controller.clearBuildCache();
      expect(controller.lastStartedUrlTestOutboundTags, isEmpty);
    },
  );

  test('startup validation reports skipped outbounds and selected failure', () {
    final controller = RuntimeRecoveryController();
    final validation = controller.validateStartupBuild(
      _buildResult(
        tagsByIndex: const {},
        startableCount: 2,
        invalidOutbounds: const [
          InvalidStartupOutbound(
            tag: 'broken',
            name: 'Broken server',
            reason: 'unsupported option',
          ),
        ],
        selectedProxyInvalid: true,
      ),
      'test',
    );

    expect(validation.canStart, isTrue);
    expect(validation.selectedProxyInvalid, isTrue);
    expect(validation.warning, contains('Broken server'));
  });
}

SingboxConfigBuildResult _buildResult({
  required Map<int, String> tagsByIndex,
  int startableCount = 1,
  List<InvalidStartupOutbound> invalidOutbounds =
      const <InvalidStartupOutbound>[],
  bool selectedProxyInvalid = false,
  List<String> urlTestTags = const <String>[],
}) {
  return SingboxConfigBuildResult(
    plan: SingboxBuildPlan(
      config: const <String, dynamic>{'outbounds': <Object>[]},
      proxyOutboundTagsByIndex: tagsByIndex,
      visibleProxyOutboundCount: startableCount,
      urlTestOutboundTags: urlTestTags,
    ),
    configJson: '',
    configPath: 'config.json',
    configLength: 0,
    configOutboundCount: startableCount,
    configInboundCount: 1,
    configRouteRuleCount: 0,
    invalidOutbounds: invalidOutbounds,
    invalidOutboundCount: invalidOutbounds.length,
    selectedProxyInvalid: selectedProxyInvalid,
    startableOutboundCount: startableCount,
  );
}
