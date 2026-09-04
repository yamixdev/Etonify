import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/features/settings/settings_dns_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

class _DnsSettingsHarness extends StatefulWidget {
  const _DnsSettingsHarness({super.key});

  @override
  State<_DnsSettingsHarness> createState() => _DnsSettingsHarnessState();
}

class _DnsSettingsHarnessState extends State<_DnsSettingsHarness> {
  int trafficTick = 0;

  void rebuildForTrafficTick() {
    setState(() => trafficTick++);
  }

  @override
  Widget build(BuildContext context) {
    final _ = trafficTick;
    return const SettingsDnsPage();
  }
}

Widget _dnsSettingsApp({
  required GlobalKey<_DnsSettingsHarnessState> harnessKey,
  required ProviderContainer container,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: _DnsSettingsHarness(key: harnessKey),
    ),
  );
}

Finder _directResolverField() {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == '1.1.1.1',
    description: 'direct DNS resolver field',
  );
}

void main() {
  testWidgets(
    'DNS draft survives parent rebuild and commits only when editing finishes',
    (tester) async {
      final harnessKey = GlobalKey<_DnsSettingsHarnessState>();
      final controller = AppSettingsController()
        ..dnsDirectPreset = 'custom'
        ..dnsDirectResolver = 'udp://1.1.1.1'
        ..dnsProxyPreset = 'device'
        ..dnsProxyResolver = 'device://network';
      final commands = AppSettingsCommands();
      final container = ProviderContainer(
        overrides: [
          appSettingsControllerProvider.overrideWithValue(controller),
          appSettingsCommandsProvider.overrideWithValue(commands),
        ],
      );
      addTearDown(container.dispose);

      int directResolverChanges = 0;
      commands.bindDnsHandlers(
        setDnsDirectPreset: (value) {
          container
              .read(appSettingsProvider.notifier)
              .mutate((c) => c.setDnsDirectPreset(value));
        },
        setDnsDirectResolver: (value) {
          directResolverChanges++;
          container
              .read(appSettingsProvider.notifier)
              .mutate((c) => c.setDnsDirectResolver(value));
        },
        setDnsProxyPreset: (value) {
          container
              .read(appSettingsProvider.notifier)
              .mutate((c) => c.setDnsProxyPreset(value));
        },
        setDnsProxyResolver: (value) {
          container
              .read(appSettingsProvider.notifier)
              .mutate((c) => c.setDnsProxyResolver(value));
        },
        setDnsPreferIpv6: (value) {
          container
              .read(appSettingsProvider.notifier)
              .mutate((c) => c.setDnsPreferIpv6(value));
        },
        setDnsSecureOnly: (value) {
          container
              .read(appSettingsProvider.notifier)
              .mutate((c) => c.setDnsSecureOnly(value));
        },
        setDnsDirectThroughProxy: (value) {
          container
              .read(appSettingsProvider.notifier)
              .mutate((c) => c.setDnsDirectThroughProxy(value));
        },
      );

      await tester.pumpWidget(
        _dnsSettingsApp(harnessKey: harnessKey, container: container),
      );

      final field = _directResolverField();
      expect(field, findsOneWidget);

      await tester.tap(field);
      await tester.enterText(field, '8.8.8.8');
      harnessKey.currentState!.rebuildForTrafficTick();
      await tester.pump();

      expect(tester.widget<TextField>(field).controller!.text, '8.8.8.8');
      expect(directResolverChanges, 0);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(
        container.read(appSettingsProvider).controller.dnsDirectResolver,
        'udp://8.8.8.8',
      );
      expect(directResolverChanges, 1);

      await tester.tap(field);
      await tester.enterText(field, '9.9.9.9');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(
        container.read(appSettingsProvider).controller.dnsDirectResolver,
        'udp://9.9.9.9',
      );
      expect(directResolverChanges, 2);
    },
  );

  testWidgets('secure DNS hides plaintext resolver presets', (tester) async {
    final harnessKey = GlobalKey<_DnsSettingsHarnessState>();
    final controller = AppSettingsController()
      ..dnsDirectPreset = 'cloudflare'
      ..dnsDirectResolver = 'udp://1.1.1.1'
      ..dnsProxyPreset = 'cloudflare'
      ..dnsProxyResolver = 'udp://1.1.1.1';
    final commands = AppSettingsCommands();
    final container = ProviderContainer(
      overrides: [
        appSettingsControllerProvider.overrideWithValue(controller),
        appSettingsCommandsProvider.overrideWithValue(commands),
      ],
    );
    addTearDown(container.dispose);

    commands.bindDnsHandlers(
      setDnsDirectPreset: (value) {
        container
            .read(appSettingsProvider.notifier)
            .mutate((c) => c.setDnsDirectPreset(value));
      },
      setDnsDirectResolver: (value) {
        container
            .read(appSettingsProvider.notifier)
            .mutate((c) => c.setDnsDirectResolver(value));
      },
      setDnsProxyPreset: (value) {
        container
            .read(appSettingsProvider.notifier)
            .mutate((c) => c.setDnsProxyPreset(value));
      },
      setDnsProxyResolver: (value) {
        container
            .read(appSettingsProvider.notifier)
            .mutate((c) => c.setDnsProxyResolver(value));
      },
      setDnsPreferIpv6: (value) {
        container
            .read(appSettingsProvider.notifier)
            .mutate((c) => c.setDnsPreferIpv6(value));
      },
      setDnsSecureOnly: (value) {
        container
            .read(appSettingsProvider.notifier)
            .mutate((c) => c.setDnsSecureOnly(value));
      },
      setDnsDirectThroughProxy: (value) {
        container
            .read(appSettingsProvider.notifier)
            .mutate((c) => c.setDnsDirectThroughProxy(value));
      },
    );

    await tester.pumpWidget(
      _dnsSettingsApp(harnessKey: harnessKey, container: container),
    );

    final secureOnly = find.text('Encrypted DNS only');
    await tester.ensureVisible(secureOnly);
    await tester.tap(secureOnly);
    await tester.pumpAndSettle();
    expect(
      container.read(appSettingsProvider).controller.dnsSecureOnly,
      isTrue,
    );

    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bolt_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Cloudflare DoT'), findsOneWidget);
    expect(find.text('Cloudflare 1.1.1.1'), findsNothing);
    expect(find.text('Device network'), findsNothing);
  });
}
