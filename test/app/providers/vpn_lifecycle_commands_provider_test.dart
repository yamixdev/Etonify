import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/providers/vpn_lifecycle_commands_provider.dart';

void main() {
  test(
    'commands are unavailable until the application binds its runtime',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final commands = container.read(vpnLifecycleCommandsProvider);
      expect(await commands.toggle(source: 'test'), isFalse);
      expect(await commands.stop(reason: 'test'), isFalse);
      expect(commands.bound, isFalse);
    },
  );

  test(
    'bound commands delegate without introducing another lifecycle queue',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final calls = <String>[];

      final commands = container.read(vpnLifecycleCommandsProvider);
      commands.bind(
        toggle: (source) async => calls.add('toggle:$source'),
        stop: (reason, allowQueuedRestart) async {
          calls.add('stop:$reason:$allowQueuedRestart');
          return true;
        },
      );

      expect(await commands.toggle(source: ' home '), isTrue);
      expect(
        await commands.stop(
          reason: ' notification ',
          allowQueuedRestart: false,
        ),
        isTrue,
      );
      expect(calls, ['toggle:home', 'stop:notification:false']);
      expect(commands.bound, isTrue);

      commands.unbind();
      expect(await commands.toggle(source: 'late'), isFalse);
      expect(commands.bound, isFalse);
    },
  );
}
