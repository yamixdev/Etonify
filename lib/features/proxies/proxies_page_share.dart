part of 'proxies_page.dart';

String _prettyJson(Map<String, dynamic> value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}

Map<String, dynamic> _singboxOutboundJson(Outbound outbound) {
  final config = Map<String, dynamic>.from(outbound.config);
  config.remove('_name');
  config['tag'] = outbound.name.isNotEmpty ? outbound.name : outbound.tag;
  return config;
}

String? _outboundShareLink(Outbound outbound) {
  final config = outbound.config;
  final type = (config['type'] as String? ?? '').toLowerCase();
  return switch (type) {
    'vless' => _vlessShareLink(outbound),
    'vmess' => _vmessShareLink(outbound),
    'trojan' => _trojanShareLink(outbound),
    'shadowsocks' => _shadowsocksShareLink(outbound),
    'shadowsocksr' => _shadowsocksrShareLink(outbound),
    'socks' => _socksShareLink(outbound),
    'http' => _httpShareLink(outbound),
    'hysteria2' => _hysteria2ShareLink(outbound),
    'hysteria' => _hysteriaShareLink(outbound),
    'tuic' => _tuicShareLink(outbound),
    'anytls' => _anytlsShareLink(outbound),
    'naive' => _naiveShareLink(outbound),
    _ => null,
  };
}

String? _vlessShareLink(Outbound outbound) {
  final c = outbound.config;
  final uuid = _stringValue(c['uuid']);
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  if (uuid.isEmpty || server.isEmpty || port == null) return null;
  final query = <String, String>{};
  _putQuery(query, 'encryption', _stringValue(c['encryption']));
  _putQuery(query, 'flow', _stringValue(c['flow']));
  _putQuery(query, 'packetEncoding', _stringValue(c['packet_encoding']));
  _appendTlsQuery(query, c['tls']);
  _appendTransportQuery(query, c['transport']);
  return _uriWithQuery(
    scheme: 'vless',
    userInfo: uuid,
    server: server,
    port: port,
    query: query,
    name: outbound.name,
  );
}

String? _trojanShareLink(Outbound outbound) {
  final c = outbound.config;
  final password = _stringValue(c['password']);
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  if (password.isEmpty || server.isEmpty || port == null) return null;
  final query = <String, String>{};
  _appendTlsQuery(query, c['tls'], defaultSecurity: 'tls');
  _appendTransportQuery(query, c['transport']);
  return _uriWithQuery(
    scheme: 'trojan',
    userInfo: password,
    server: server,
    port: port,
    query: query,
    name: outbound.name,
  );
}

String? _shadowsocksShareLink(Outbound outbound) {
  final c = outbound.config;
  final method = _stringValue(c['method']);
  final password = _stringValue(c['password']);
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  if (method.isEmpty || password.isEmpty || server.isEmpty || port == null) {
    return null;
  }
  final userInfo = base64Url
      .encode(utf8.encode('$method:$password'))
      .replaceAll('=', '');
  return _uriWithQuery(
    scheme: 'ss',
    userInfo: userInfo,
    server: server,
    port: port,
    query: const {},
    name: outbound.name,
  );
}

String? _vmessShareLink(Outbound outbound) {
  final c = outbound.config;
  final uuid = _stringValue(c['uuid']);
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  if (uuid.isEmpty || server.isEmpty || port == null) return null;
  final tls = c['tls'] is Map
      ? Map<String, dynamic>.from(c['tls'] as Map)
      : null;
  final transport = c['transport'] is Map
      ? Map<String, dynamic>.from(c['transport'] as Map)
      : null;
  final payload = <String, dynamic>{
    'v': '2',
    'ps': outbound.name,
    'add': server,
    'port': '$port',
    'id': uuid,
    'aid': '${_intValue(c['alter_id']) ?? 0}',
    'scy': _stringValue(c['security'], fallback: 'auto'),
    'net': _stringValue(transport?['type'], fallback: 'tcp'),
    'type': _stringValue(
      transport?['headers'] is Map
          ? (transport!['headers'] as Map)['type']
          : null,
      fallback: 'none',
    ),
    'host': _transportHost(transport),
    'path': _stringValue(transport?['path']),
    'tls': tls?['enabled'] == true ? 'tls' : '',
    'sni': _stringValue(tls?['server_name']),
    'fp': _stringValue(
      tls?['utls'] is Map ? (tls!['utls'] as Map)['fingerprint'] : null,
    ),
  };
  final encoded = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return 'vmess://$encoded';
}

String? _shadowsocksrShareLink(Outbound outbound) {
  final c = outbound.config;
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  final protocol = _stringValue(c['protocol'], fallback: 'origin');
  final method = _stringValue(c['method']);
  final obfs = _stringValue(c['obfs'], fallback: 'plain');
  final password = _stringValue(c['password']);
  if (server.isEmpty || port == null || method.isEmpty || password.isEmpty) {
    return null;
  }
  final query = <String, String>{};
  _putQuery(query, 'obfsparam', _base64UrlNoPad(_stringValue(c['obfs_param'])));
  _putQuery(
    query,
    'protoparam',
    _base64UrlNoPad(_stringValue(c['protocol_param'])),
  );
  _putQuery(query, 'remarks', _base64UrlNoPad(outbound.name));
  final main =
      '$server:$port:$protocol:$method:$obfs:${_base64UrlNoPad(password)}/?'
      '${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';
  return 'ssr://${_base64UrlNoPad(main)}';
}

String? _socksShareLink(Outbound outbound) {
  final c = outbound.config;
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  if (server.isEmpty || port == null) return null;
  final version = _stringValue(c['version'], fallback: '5');
  final scheme = version == '4' ? 'socks4' : 'socks5';
  return _uriWithQuery(
    scheme: scheme,
    userInfo: _credentialsUserInfo(c),
    server: server,
    port: port,
    query: const {},
    name: outbound.name,
  );
}

String? _httpShareLink(Outbound outbound) {
  final c = outbound.config;
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  if (server.isEmpty || port == null) return null;
  final tls = c['tls'] is Map
      ? Map<String, dynamic>.from(c['tls'] as Map)
      : null;
  return _uriWithQuery(
    scheme: tls?['enabled'] == true ? 'https' : 'http',
    userInfo: _credentialsUserInfo(c),
    server: server,
    port: port,
    query: const {},
    name: outbound.name,
  );
}

String? _naiveShareLink(Outbound outbound) {
  final c = outbound.config;
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  if (server.isEmpty || port == null) return null;
  final query = <String, String>{};
  final tls = c['tls'] is Map
      ? Map<String, dynamic>.from(c['tls'] as Map)
      : null;
  _putQuery(query, 'sni', _stringValue(tls?['server_name']));
  _putQuery(
    query,
    'quic_congestion_control',
    _stringValue(c['quic_congestion_control']),
  );
  final extraHeaders = _encodedHeaders(c['extra_headers']);
  _putQuery(query, 'extra-headers', extraHeaders);
  return _naiveUriWithQuery(
    scheme: c['quic'] == true ? 'naive+quic' : 'naive+https',
    userInfo: _credentialsUserInfo(c),
    server: server,
    port: port,
    query: query,
    name: outbound.name,
  );
}

String? _hysteria2ShareLink(Outbound outbound) {
  final c = outbound.config;
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  if (server.isEmpty || port == null) return null;
  final query = <String, String>{};
  _appendHyTlsQuery(query, c['tls']);
  final obfs = c['obfs'] is Map
      ? Map<String, dynamic>.from(c['obfs'] as Map)
      : null;
  _putQuery(query, 'obfs', _stringValue(obfs?['type']));
  _putQuery(query, 'obfs-password', _stringValue(obfs?['password']));
  return _uriWithQuery(
    scheme: 'hysteria2',
    userInfo: _stringValue(c['password']),
    server: server,
    port: port,
    query: query,
    name: outbound.name,
  );
}

String? _hysteriaShareLink(Outbound outbound) {
  final c = outbound.config;
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  if (server.isEmpty || port == null) return null;
  final query = <String, String>{};
  _putQuery(query, 'auth', _stringValue(c['auth_string']));
  _putQuery(query, 'upmbps', _stringValue(c['up_mbps']));
  _putQuery(query, 'downmbps', _stringValue(c['down_mbps']));
  _putQuery(query, 'obfsParam', _stringValue(c['obfs']));
  _appendHyTlsQuery(query, c['tls']);
  return _uriWithQuery(
    scheme: 'hysteria',
    userInfo: '',
    server: server,
    port: port,
    query: query,
    name: outbound.name,
  );
}

String? _tuicShareLink(Outbound outbound) {
  final c = outbound.config;
  final uuid = _stringValue(c['uuid']);
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  if (uuid.isEmpty || server.isEmpty || port == null) return null;
  final password = _stringValue(c['password']);
  final query = <String, String>{};
  _putQuery(query, 'congestion_control', _stringValue(c['congestion_control']));
  _putQuery(query, 'udp_relay_mode', _stringValue(c['udp_relay_mode']));
  _appendHyTlsQuery(query, c['tls'], insecureKey: 'allow_insecure');
  return _uriWithQuery(
    scheme: 'tuic',
    userInfo: password.isEmpty ? uuid : '$uuid:$password',
    server: server,
    port: port,
    query: query,
    name: outbound.name,
  );
}

String? _anytlsShareLink(Outbound outbound) {
  final c = outbound.config;
  final password = _stringValue(c['password']);
  final server = _stringValue(c['server']);
  final port = _intValue(c['server_port']);
  if (password.isEmpty || server.isEmpty || port == null) return null;
  final query = <String, String>{};
  _appendHyTlsQuery(query, c['tls']);
  return _uriWithQuery(
    scheme: 'anytls',
    userInfo: password,
    server: server,
    port: port,
    query: query,
    name: outbound.name,
  );
}

String _credentialsUserInfo(Map<String, dynamic> config) {
  final username = _stringValue(config['username']);
  final password = _stringValue(config['password']);
  if (username.isEmpty) return '';
  if (password.isEmpty) return username;
  return '$username:$password';
}

String _encodedHeaders(Object? rawHeaders) {
  if (rawHeaders is! Map) return '';
  final lines = <String>[];
  for (final entry in rawHeaders.entries) {
    final key = entry.key.toString().trim();
    final value = entry.value?.toString().trim() ?? '';
    if (key.isNotEmpty && value.isNotEmpty) {
      lines.add('$key: $value');
    }
  }
  return lines.join('\r\n');
}

void _appendTlsQuery(
  Map<String, String> query,
  Object? rawTls, {
  String defaultSecurity = '',
}) {
  if (rawTls is! Map || rawTls['enabled'] != true) {
    if (defaultSecurity.isNotEmpty) {
      _putQuery(query, 'security', defaultSecurity);
    }
    return;
  }
  final tls = Map<String, dynamic>.from(rawTls);
  final reality = tls['reality'] is Map
      ? Map<String, dynamic>.from(tls['reality'] as Map)
      : null;
  _putQuery(query, 'security', reality?['enabled'] == true ? 'reality' : 'tls');
  _putQuery(query, 'sni', _stringValue(tls['server_name']));
  _putQuery(
    query,
    'fp',
    _stringValue(
      tls['utls'] is Map ? (tls['utls'] as Map)['fingerprint'] : null,
    ),
  );
  if (reality?['enabled'] == true) {
    _putQuery(query, 'pbk', _stringValue(reality?['public_key']));
    _putQuery(query, 'sid', _stringValue(reality?['short_id']));
    _putQuery(query, 'spx', _stringValue(reality?['spider_x']));
  }
}

void _appendHyTlsQuery(
  Map<String, String> query,
  Object? rawTls, {
  String insecureKey = 'insecure',
}) {
  if (rawTls is! Map) return;
  final tls = Map<String, dynamic>.from(rawTls);
  _putQuery(query, 'sni', _stringValue(tls['server_name']));
  if (tls['insecure'] == true) {
    _putQuery(query, insecureKey, '1');
  }
  final reality = tls['reality'];
  final isReality = reality is Map && reality['enabled'] == true;
  if (!isReality && tls['alpn'] is List) {
    _putQuery(query, 'alpn', (tls['alpn'] as List).join(','));
  }
  _putQuery(
    query,
    'fp',
    _stringValue(
      tls['utls'] is Map ? (tls['utls'] as Map)['fingerprint'] : null,
    ),
  );
}

void _appendTransportQuery(Map<String, String> query, Object? rawTransport) {
  if (rawTransport is! Map) return;
  final transport = Map<String, dynamic>.from(rawTransport);
  _putQuery(query, 'type', _stringValue(transport['type']));
  _putQuery(query, 'path', _stringValue(transport['path']));
  _putQuery(query, 'host', _transportHost(transport));
  _putQuery(query, 'mode', _stringValue(transport['mode']));
  _putQuery(query, 'serviceName', _stringValue(transport['service_name']));
  if (transport['extra'] != null) {
    _putQuery(query, 'extra', jsonEncode(transport['extra']));
  }
}

String _transportHost(Map<String, dynamic>? transport) {
  if (transport == null) return '';
  final headers = transport['headers'];
  if (headers is Map) {
    return _stringValue(headers['Host'] ?? headers['host']);
  }
  return _stringValue(transport['host']);
}

String _uriWithQuery({
  required String scheme,
  required String userInfo,
  required String server,
  required int port,
  required Map<String, String> query,
  required String name,
}) {
  final encodedQuery = query.entries
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');
  final fragment = name.trim().isEmpty ? '' : '#${Uri.encodeComponent(name)}';
  final encodedUserInfo = _encodeUserInfo(userInfo);
  final auth = encodedUserInfo.isEmpty
      ? '$server:$port'
      : '$encodedUserInfo@$server:$port';
  return '$scheme://$auth${encodedQuery.isEmpty ? '' : '?$encodedQuery'}$fragment';
}

String _naiveUriWithQuery({
  required String scheme,
  required String userInfo,
  required String server,
  required int port,
  required Map<String, String> query,
  required String name,
}) {
  final encodedQuery = query.entries
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');
  final fragment = name.trim().isEmpty ? '' : '#${Uri.encodeComponent(name)}';
  final encodedUserInfo = _encodeUserInfo(userInfo);
  final authority = port == 443 ? server : '$server:$port';
  final auth = encodedUserInfo.isEmpty
      ? authority
      : '$encodedUserInfo@$authority';
  return '$scheme://$auth${encodedQuery.isEmpty ? '' : '?$encodedQuery'}$fragment';
}

String _encodeUserInfo(String userInfo) {
  if (userInfo.isEmpty) return '';
  final separator = userInfo.indexOf(':');
  if (separator < 0) {
    return Uri.encodeComponent(userInfo);
  }
  return '${Uri.encodeComponent(userInfo.substring(0, separator))}:'
      '${Uri.encodeComponent(userInfo.substring(separator + 1))}';
}

void _putQuery(Map<String, String> query, String key, String value) {
  if (value.trim().isNotEmpty) {
    query[key] = value.trim();
  }
}

String _base64UrlNoPad(String value) {
  if (value.isEmpty) return '';
  return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
}

String _stringValue(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

class _ProxyShareSheet extends StatelessWidget {
  const _ProxyShareSheet({required this.proxy, required this.outbound});

  final AppProxySummary proxy;
  final Outbound outbound;

  Future<void> _copy(
    BuildContext context, {
    required String value,
    required String label,
  }) async {
    final navigator = Navigator.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    final message = _copiedText(context, label);
    AppNotice.show(context, message, tone: AppNoticeTone.success);
    navigator.pop();
  }

  String _copiedText(BuildContext context, String label) {
    return AppLocalizations.of(context).copiedToClipboard(label);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = appSystemNavigationBarInset(context);
    final shareLink = _outboundShareLink(outbound);
    final singboxJson = _prettyJson(_singboxOutboundJson(outbound));
    final l10n = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .42,
      minChildSize: .22,
      maxChildSize: .74,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset + 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: .34,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.shareProxyTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    _ProxyShareSummary(proxy: proxy),
                    const SizedBox(height: 12),
                    Material(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ProxyShareActionTile(
                            label: l10n.shareProxyLinkLabel,
                            icon: FluentIcons.clipboard_link_24_regular,
                            enabled: shareLink != null,
                            onTap: shareLink == null
                                ? null
                                : () => _copy(
                                    context,
                                    value: shareLink,
                                    label: l10n.shareProxyLinkLabel,
                                  ),
                          ),
                          Divider(
                            height: 1,
                            indent: 56,
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: .28,
                            ),
                          ),
                          _ProxyShareActionTile(
                            label: l10n.shareSingboxOutboundLabel,
                            icon: FluentIcons.clipboard_code_24_regular,
                            onTap: () => _copy(
                              context,
                              value: singboxJson,
                              label: l10n.shareSingboxOutboundLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProxyShareSummary extends StatelessWidget {
  const _ProxyShareSummary({required this.proxy});

  final AppProxySummary proxy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final latencyText = proxy.latencyChecking
        ? '... ms'
        : proxy.latencyUnavailable
        ? '—'
        : proxy.latency == null
        ? '—'
        : '${proxy.latency} ms';

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            CountryFlagBadge(countryCode: proxy.countryCode, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localizedProxyTitle(l10n, proxy),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _localizedProxySubtitle(l10n, proxy),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              latencyText,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProxyShareActionTile extends StatelessWidget {
  const _ProxyShareActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      leading: Icon(icon),
      title: Text(label),
      subtitle: enabled
          ? null
          : Text(AppLocalizations.of(context).unavailableForThisType),
      trailing: const Icon(FluentIcons.copy_24_regular),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textColor: theme.colorScheme.onSurface,
      iconColor: theme.colorScheme.onSurfaceVariant,
    );
  }
}
