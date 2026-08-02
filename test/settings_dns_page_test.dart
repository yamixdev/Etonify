import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_dns_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

class _DnsSettingsHarness extends StatefulWidget {
  const _DnsSettingsHarness({super.key});

  @override
  State<_DnsSettingsHarness> createState() => _DnsSettingsHarnessState();
}

class _DnsSettingsHarnessState extends State<_DnsSettingsHarness> {
  String directResolver = 'udp://1.1.1.1';
  int directResolverChanges = 0;
  int trafficTick = 0;

  void rebuildForTrafficTick() {
    setState(() => trafficTick++);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDnsPage(
      currentDirectPreset: 'custom',
      currentDirectResolver: directResolver,
      currentProxyPreset: 'device',
      currentProxyResolver: 'device://network',
      currentPreferIpv6: false,
      onDirectPresetChanged: (_) {},
      onDirectResolverChanged: (value) {
        setState(() {
          directResolver = normalizeDnsResolverInput(value);
          directResolverChanges++;
        });
      },
      onProxyPresetChanged: (_) {},
      onProxyResolverChanged: (_) {},
      onPreferIpv6Changed: (_) {},
    );
  }
}

Widget _dnsSettingsApp(GlobalKey<_DnsSettingsHarnessState> harnessKey) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: _DnsSettingsHarness(key: harnessKey),
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
      await tester.pumpWidget(_dnsSettingsApp(harnessKey));

      final field = _directResolverField();
      expect(field, findsOneWidget);

      await tester.tap(field);
      await tester.enterText(field, '8.8.8.8');
      harnessKey.currentState!.rebuildForTrafficTick();
      await tester.pump();

      expect(tester.widget<TextField>(field).controller!.text, '8.8.8.8');
      expect(harnessKey.currentState!.directResolverChanges, 0);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(harnessKey.currentState!.directResolver, 'udp://8.8.8.8');
      expect(harnessKey.currentState!.directResolverChanges, 1);

      await tester.tap(field);
      await tester.enterText(field, '9.9.9.9');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(harnessKey.currentState!.directResolver, 'udp://9.9.9.9');
      expect(harnessKey.currentState!.directResolverChanges, 2);
    },
  );
}
