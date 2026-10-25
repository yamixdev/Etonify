import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:meow_client/features/home/home_current_proxy_card.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/server_connection_info.dart';
import 'package:meow_client/theme/app_theme.dart';

@Preview(name: 'Home · exit IP', size: Size(360, 180))
Widget homeServerIpPreview() => _serverPreview();

@Preview(name: 'Home · group exit IP', size: Size(360, 180))
Widget homeServerGroupIpPreview() => _serverPreview(group: true);

Widget _serverPreview({bool group = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('ru'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: buildAppTheme(Brightness.dark, seedColor: const Color(0xff8b4c14)),
  home: Scaffold(
    body: Center(
      child: HomeCurrentProxyCard(
        proxy: AppProxySummary(
          tag: 'example',
          displayName: group ? '⚡ ⭐ LTE Авто — Швеция' : 'Швеция',
          isGroup: group,
          childCount: group ? 5 : 0,
          countryCode: 'SE',
          type: 'vless',
          server: 'node.example',
          port: 443,
          detailText: '',
          ip: '',
          latency: 42,
          latencyFresh: true,
          latencyChecking: false,
          latencyUnavailable: false,
          latencyError: null,
          protocolLabel: 'VLESS · REALITY',
          endpointLabel: 'node.example:443',
        ),
        connectionInfo: const ServerConnectionInfo(
          connected: true,
          outboundTag: 'example',
          exitIp: '203.0.113.7',
        ),
        onTap: _noop,
        onOpenInfo: _noop,
        onOpenGroup: group ? _noop : null,
      ),
    ),
  ),
);

void _noop() {}
