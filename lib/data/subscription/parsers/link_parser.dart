import 'dart:convert';

/// Parses individual proxy URI links and converts to sing-box outbound format.
///
/// Supported schemes: vless, vmess, trojan, ss, ssr, socks/socks4/socks5,
/// http/https proxy URIs, naive+https/naive+quic, hysteria2/hy2,
/// hysteria/hy, tuic, anytls.
///
/// Each method returns a sing-box outbound JSON map with an extra `_name` key
/// holding the human-readable name (extracted from fragment / JSON).
class LinkParser {
  LinkParser._();

  static final RegExp _naiveSchemePattern = RegExp(
    r'^naive\+(?:https|quic)://',
    caseSensitive: false,
  );
  static final RegExp _httpHeaderLineBreakPattern = RegExp(r'\r?\n');
  static final RegExp _authorityTerminatorPattern = RegExp(r'[/?#]');
  static final RegExp _uppercasePattern = RegExp(r'[A-Z]');

  // ───────────────────────────── public API ─────────────────────────────

  /// Try to parse [line] as a proxy link.
  /// Returns a sing-box outbound config map or `null` if not recognised.
  static Map<String, dynamic>? tryParse(String line) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) return null;

    try {
      if (line.startsWith('vless://')) return _parseVless(line);
      if (line.startsWith('vmess://')) return _parseVmess(line);
      if (line.startsWith('trojan://')) return _parseTrojan(line);
      if (line.startsWith('ss://') && !line.startsWith('ssr://')) {
        return _parseSS(line);
      }
      if (line.startsWith('ssr://')) return _parseSSR(line);
      if (_isSocksScheme(line)) return _parseSocks(line);
      if (_isNaiveScheme(line)) return _parseNaive(line);
      if (line.startsWith('http://') || line.startsWith('https://')) {
        return _parseHttpProxy(line);
      }
      if (line.startsWith('hysteria2://') || line.startsWith('hy2://')) {
        return _parseHysteria2(line);
      }
      if (line.startsWith('hysteria://') || line.startsWith('hy://')) {
        return _parseHysteria(line);
      }
      if (line.startsWith('tuic://')) return _parseTuic(line);
      if (line.startsWith('anytls://')) return _parseAnytls(line);
    } catch (_) {
      return null;
    }
    return null;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ VLESS ━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _parseVless(String raw) {
    final name = _fragment(raw);
    final uri = Uri.parse(raw);
    final p = uri.queryParameters;
    final port = _portOr(raw, 443);

    final result = <String, dynamic>{
      'type': 'vless',
      'tag': '',
      'server': uri.host,
      'server_port': port,
      'uuid': Uri.decodeComponent(uri.userInfo),
    };

    _putIfPresent(result, 'flow', p['flow']);
    _putIfPresent(result, 'encryption', p['encryption']);
    _putIfPresent(
      result,
      'packet_encoding',
      p['packet_encoding'] ?? p['packetEncoding'],
    );

    final transport = _buildTransport(p);
    if (transport != null) result['transport'] = transport;

    final tls = _buildTls(p);
    if (tls != null) {
      if (transport?['type'] == 'xhttp' && !tls.containsKey('alpn')) {
        tls['alpn'] = const ['h2', 'http/1.1'];
      }
      result['tls'] = tls;
    }

    result['_name'] = name.isNotEmpty ? name : '${uri.host}:$port';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ VMess ━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _parseVmess(String raw) {
    final b64 = raw.substring('vmess://'.length).split('#').first;
    final decoded = _decodeBase64(b64);
    if (decoded == null) return null;

    final Map<String, dynamic> v;
    try {
      v = jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    final server = _str(v['add']);
    final rawPort = v['port'];
    final port = !v.containsKey('port')
        ? 443
        : _validatedPort(
            rawPort is String
                ? int.tryParse(rawPort.trim())
                : rawPort is num &&
                      rawPort.isFinite &&
                      rawPort == rawPort.truncateToDouble()
                ? rawPort.toInt()
                : null,
          );
    final uuid = _str(v['id']);
    final aid = _toInt(v['aid']);
    final security = _str(v['scy'], 'auto');
    final vmName = _str(v['ps']);
    final net = _str(v['net'], 'tcp');
    final tlsField = _str(v['tls']);
    final sni = _str(v['sni']);
    final host = _str(v['host']);
    final path = _str(v['path']);
    final fp = _str(v['fp']);
    final alpn = _str(v['alpn']);
    final headerType = _str(v['type'], 'none');

    if (server.isEmpty || uuid.isEmpty) return null;

    final result = <String, dynamic>{
      'type': 'vmess',
      'tag': '',
      'server': server,
      'server_port': port,
      'uuid': uuid,
      'security': security,
      'alter_id': aid,
    };

    // TLS
    if (tlsField == 'tls') {
      final tls = <String, dynamic>{'enabled': true};
      if (sni.isNotEmpty) tls['server_name'] = sni;
      if (alpn.isNotEmpty) tls['alpn'] = alpn.split(',');
      if (fp.isNotEmpty) {
        tls['utls'] = {'enabled': true, 'fingerprint': fp};
      }
      result['tls'] = tls;
    }

    // Transport
    final transport = _buildTransport({
      'type': net,
      'host': host,
      'path': path,
      'headerType': headerType,
    });
    if (transport != null) result['transport'] = transport;

    result['_name'] = vmName.isNotEmpty ? vmName : '$server:$port';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ Trojan ━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _parseTrojan(String raw) {
    final name = _fragment(raw);
    final uri = Uri.parse(raw);
    final p = uri.queryParameters;
    final port = _portOr(raw, 443);

    final result = <String, dynamic>{
      'type': 'trojan',
      'tag': '',
      'server': uri.host,
      'server_port': port,
      'password': Uri.decodeComponent(uri.userInfo),
    };

    // Trojan defaults to TLS
    final security = (p['security'] ?? 'tls').toLowerCase();
    if (security != 'none') {
      final tls = _buildTls(p, defaultEnabled: true);
      if (tls != null) result['tls'] = tls;
    }

    final transport = _buildTransport(p);
    if (transport != null) result['transport'] = transport;

    result['_name'] = name.isNotEmpty ? name : '${uri.host}:$port';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ Shadowsocks (SIP002 + legacy) ━━━━━━━━━━━

  static Map<String, dynamic>? _parseSS(String raw) {
    final name = _fragment(raw);
    String body = raw.substring('ss://'.length);
    final hashIdx = body.lastIndexOf('#');
    if (hashIdx >= 0) body = body.substring(0, hashIdx);

    String? server;
    int? port;
    String? method;
    String? password;
    String? plugin;
    String? pluginOpts;

    if (body.contains('@')) {
      // ── SIP002: base64(method:password)@host:port?plugin=… ──
      final atIdx = body.indexOf('@');
      final userInfo = body.substring(0, atIdx);
      final rest = body.substring(atIdx + 1);

      final qIdx = rest.indexOf('?');
      final hostPort = qIdx >= 0 ? rest.substring(0, qIdx) : rest;
      final query = qIdx >= 0 ? rest.substring(qIdx + 1) : null;

      _parseHostPort(hostPort, (h, p) {
        server = h;
        port = p;
      });

      final decoded = _decodeBase64(userInfo);
      if (decoded != null && decoded.contains(':')) {
        final i = decoded.indexOf(':');
        method = decoded.substring(0, i);
        password = decoded.substring(i + 1);
      } else {
        // Some providers don't base64-encode it
        final i = userInfo.indexOf(':');
        if (i > 0) {
          method = Uri.decodeComponent(userInfo.substring(0, i));
          password = Uri.decodeComponent(userInfo.substring(i + 1));
        }
      }

      if (query != null) {
        final qp = Uri.splitQueryString(query);
        final rawPlugin = qp['plugin'] ?? '';
        if (rawPlugin.isNotEmpty) {
          if (rawPlugin.contains(';')) {
            final parts = rawPlugin.split(';');
            plugin = parts.first;
            pluginOpts = parts.sublist(1).join(';');
          } else {
            plugin = rawPlugin;
            pluginOpts = qp['plugin-opts'];
          }
        }
      }
    } else {
      // ── Legacy: base64(method:password@host:port) ──
      final decoded = _decodeBase64(body);
      if (decoded == null) return null;
      final atIdx = decoded.lastIndexOf('@');
      if (atIdx < 0) return null;

      final methodPass = decoded.substring(0, atIdx);
      final hostPort = decoded.substring(atIdx + 1);

      final colonIdx = methodPass.indexOf(':');
      if (colonIdx < 0) return null;
      method = methodPass.substring(0, colonIdx);
      password = methodPass.substring(colonIdx + 1);

      _parseHostPort(hostPort, (h, p) {
        server = h;
        port = p;
      });
    }

    if (server == null || port == null || method == null || password == null) {
      return null;
    }

    final result = <String, dynamic>{
      'type': 'shadowsocks',
      'tag': '',
      'server': server,
      'server_port': port,
      'method': method,
      'password': password,
    };

    _putIfPresent(result, 'plugin', plugin);
    _putIfPresent(result, 'plugin_opts', pluginOpts);

    result['_name'] = name.isNotEmpty ? name : '$server:$port';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ ShadowsocksR ━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _parseSSR(String raw) {
    String body = raw.substring('ssr://'.length);
    final hashIdx = body.lastIndexOf('#');
    if (hashIdx >= 0) body = body.substring(0, hashIdx);

    final decoded = _decodeBase64(body);
    if (decoded == null) return null;

    // server:port:protocol:method:obfs:base64pass/?params
    final qIdx = decoded.indexOf('/?');
    final main = qIdx >= 0 ? decoded.substring(0, qIdx) : decoded;
    final query = qIdx >= 0 ? decoded.substring(qIdx + 2) : null;

    final parts = main.split(':');
    if (parts.length < 6) return null;

    final base64pass = parts.last;
    final obfs = parts[parts.length - 2];
    final method = parts[parts.length - 3];
    final protocol = parts[parts.length - 4];
    final port = int.tryParse(parts[parts.length - 5]);
    final server = parts.sublist(0, parts.length - 5).join(':');
    final password = _decodeBase64(base64pass) ?? '';

    String? obfsParam;
    String? protoParam;
    String? remarks;

    if (query != null) {
      final qp = Uri.splitQueryString(query);
      obfsParam = _decodeBase64(qp['obfsparam'] ?? '');
      protoParam = _decodeBase64(qp['protoparam'] ?? '');
      remarks = _decodeBase64(qp['remarks'] ?? '');
    }

    final result = <String, dynamic>{
      'type': 'shadowsocksr',
      'tag': '',
      'server': server,
      'server_port': port ?? 0,
      'method': method,
      'password': password,
    };

    _putIfPresent(result, 'obfs', obfs);
    _putIfPresent(result, 'obfs_param', obfsParam);
    _putIfPresent(result, 'protocol', protocol);
    _putIfPresent(result, 'protocol_param', protoParam);

    final name = remarks ?? '';
    result['_name'] = name.isNotEmpty ? name : '$server:$port';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ NaiveProxy ━━━━━━━━━━━━━━━━━━━━━━━

  static bool _isNaiveScheme(String raw) {
    final lower = raw.toLowerCase();
    return lower.startsWith('naive+https://') ||
        lower.startsWith('naive+quic://');
  }

  static Map<String, dynamic>? _parseNaive(String raw) {
    final name = _fragment(raw);
    final isQuic = raw.toLowerCase().startsWith('naive+quic://');
    final uri = Uri.parse(
      raw.replaceFirst(_naiveSchemePattern, isQuic ? 'https://' : 'https://'),
    );
    final explicitPort = _explicitPort(raw);
    if (uri.host.isEmpty) return null;
    final port = explicitPort ?? 443;

    final tls = <String, dynamic>{'enabled': true};
    final result = <String, dynamic>{
      'type': 'naive',
      'tag': '',
      'server': uri.host,
      'server_port': port,
      'tls': tls,
    };

    if (isQuic) {
      result['quic'] = true;
    }

    final p = uri.queryParameters;
    _putIfPresent(tls, 'server_name', p['sni'] ?? p['peer']);
    _putIfPresent(
      result,
      'quic_congestion_control',
      p['quic_congestion_control'],
    );
    final extraHeaders = _parseHttpHeaders(p['extra-headers']);
    if (extraHeaders.isNotEmpty) {
      result['extra_headers'] = extraHeaders;
    }
    _addUriCredentials(result, uri);

    result['_name'] = name.isNotEmpty ? name : '${uri.host}:$port';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ SOCKS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static bool _isSocksScheme(String raw) {
    final lower = raw.toLowerCase();
    return lower.startsWith('socks://') ||
        lower.startsWith('socks4://') ||
        lower.startsWith('socks4a://') ||
        lower.startsWith('socks5://') ||
        lower.startsWith('socks5h://');
  }

  static Map<String, dynamic>? _parseSocks(String raw) {
    final name = _fragment(raw);
    final uri = Uri.parse(raw);
    if (uri.host.isEmpty || !uri.hasPort) return null;

    final scheme = uri.scheme.toLowerCase();
    final result = <String, dynamic>{
      'type': 'socks',
      'tag': '',
      'server': uri.host,
      'server_port': uri.port,
      'version': scheme.startsWith('socks4') ? '4' : '5',
    };

    _addUriCredentials(result, uri);
    result['_name'] = name.isNotEmpty ? name : '${uri.host}:${uri.port}';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ HTTP proxy ━━━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _parseHttpProxy(String raw) {
    final name = _fragment(raw);
    final uri = Uri.parse(raw);
    if (uri.host.isEmpty) return null;

    final explicitPort = _explicitPort(raw);

    // Avoid treating ordinary web URLs as proxy links. Proxy subscriptions
    // normally include an explicit port, and authenticated proxies may rely on
    // the default scheme port.
    if (explicitPort == null && uri.userInfo.isEmpty) return null;

    final isHttps = uri.scheme.toLowerCase() == 'https';
    final result = <String, dynamic>{
      'type': 'http',
      'tag': '',
      'server': uri.host,
      'server_port': explicitPort ?? (isHttps ? 443 : 80),
    };

    if (isHttps) {
      result['tls'] = {'enabled': true};
    }

    _addUriCredentials(result, uri);
    result['_name'] = name.isNotEmpty
        ? name
        : '${uri.host}:${result['server_port']}';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ Hysteria2 ━━━━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _parseHysteria2(String raw) {
    raw = raw.replaceFirst('hy2://', 'hysteria2://');
    final name = _fragment(raw);
    final uri = Uri.parse(raw);
    final p = uri.queryParameters;
    final port = _portOr(raw, 443);

    final result = <String, dynamic>{
      'type': 'hysteria2',
      'tag': '',
      'server': uri.host,
      'server_port': port,
    };

    if (uri.userInfo.isNotEmpty) {
      result['password'] = Uri.decodeComponent(uri.userInfo);
    }

    // TLS (always on for hy2)
    final tls = <String, dynamic>{'enabled': true};
    _putIfPresent(tls, 'server_name', p['sni'] ?? p['peer']);
    if ((p['insecure'] ?? p['allowInsecure'] ?? '0') == '1') {
      tls['insecure'] = true;
    }
    final alpn = p['alpn'] ?? '';
    if (alpn.isNotEmpty) tls['alpn'] = alpn.split(',');
    result['tls'] = tls;

    // Obfs
    final obfsType = p['obfs'] ?? '';
    if (obfsType.isNotEmpty) {
      result['obfs'] = <String, dynamic>{
        'type': obfsType,
        'password': p['obfs-password'] ?? '',
      };
    }

    result['_name'] = name.isNotEmpty ? name : '${uri.host}:$port';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ Hysteria (v1) ━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _parseHysteria(String raw) {
    raw = raw.replaceFirst('hy://', 'hysteria://');
    final name = _fragment(raw);
    final uri = Uri.parse(raw);
    final p = uri.queryParameters;
    final port = _portOr(raw, 443);

    final result = <String, dynamic>{
      'type': 'hysteria',
      'tag': '',
      'server': uri.host,
      'server_port': port,
    };

    _putIfPresent(result, 'auth_string', p['auth']);

    final up = int.tryParse(p['upmbps'] ?? '');
    final down = int.tryParse(p['downmbps'] ?? '');
    if (up != null) result['up_mbps'] = up;
    if (down != null) result['down_mbps'] = down;

    // Obfs string (v1 style)
    final obfsParam = p['obfsParam'] ?? p['obfs-password'] ?? '';
    if (obfsParam.isNotEmpty) result['obfs'] = obfsParam;

    // TLS
    final tls = <String, dynamic>{'enabled': true};
    _putIfPresent(tls, 'server_name', p['peer'] ?? p['sni']);
    if ((p['insecure'] ?? '0') == '1') tls['insecure'] = true;
    final alpn = p['alpn'] ?? '';
    if (alpn.isNotEmpty) tls['alpn'] = alpn.split(',');
    result['tls'] = tls;

    result['_name'] = name.isNotEmpty ? name : '${uri.host}:$port';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ TUIC ━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _parseTuic(String raw) {
    final name = _fragment(raw);
    final uri = Uri.parse(raw);
    final p = uri.queryParameters;

    String uuid = '';
    String password = '';
    if (uri.userInfo.contains(':')) {
      final i = uri.userInfo.indexOf(':');
      uuid = Uri.decodeComponent(uri.userInfo.substring(0, i));
      password = Uri.decodeComponent(uri.userInfo.substring(i + 1));
    } else {
      uuid = Uri.decodeComponent(uri.userInfo);
    }
    final port = _portOr(raw, 443);

    final result = <String, dynamic>{
      'type': 'tuic',
      'tag': '',
      'server': uri.host,
      'server_port': port,
      'uuid': uuid,
      'password': password,
    };

    _putIfPresent(
      result,
      'congestion_control',
      p['congestion_control'] ?? p['congestion'],
    );
    _putIfPresent(result, 'udp_relay_mode', p['udp_relay_mode']);

    // TLS
    final tls = <String, dynamic>{'enabled': true};
    _putIfPresent(tls, 'server_name', p['sni']);
    if ((p['allow_insecure'] ?? p['allowInsecure'] ?? '0') == '1') {
      tls['insecure'] = true;
    }
    final alpn = p['alpn'] ?? '';
    if (alpn.isNotEmpty) tls['alpn'] = alpn.split(',');
    result['tls'] = tls;

    result['_name'] = name.isNotEmpty ? name : '${uri.host}:$port';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━ AnyTLS ━━━━━━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic>? _parseAnytls(String raw) {
    final name = _fragment(raw);
    final uri = Uri.parse(raw);
    final p = uri.queryParameters;
    final port = _portOr(raw, 443);

    final result = <String, dynamic>{
      'type': 'anytls',
      'tag': '',
      'server': uri.host,
      'server_port': port,
      'password': Uri.decodeComponent(uri.userInfo),
    };

    // TLS (always on)
    final tls = <String, dynamic>{'enabled': true};
    _putIfPresent(tls, 'server_name', p['sni'] ?? p['peer']);
    if ((p['insecure'] ?? p['allowInsecure'] ?? '0') == '1') {
      tls['insecure'] = true;
    }
    final alpn = p['alpn'] ?? '';
    if (alpn.isNotEmpty) tls['alpn'] = alpn.split(',');
    final fp = p['fp'] ?? '';
    if (fp.isNotEmpty) {
      tls['utls'] = {'enabled': true, 'fingerprint': fp};
    }
    result['tls'] = tls;

    result['_name'] = name.isNotEmpty ? name : '${uri.host}:$port';
    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━ TLS helper ━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Builds TLS options from common query parameters (security, sni, fp, etc.)
  static Map<String, dynamic>? _buildTls(
    Map<String, String> p, {
    bool defaultEnabled = false,
  }) {
    final security = (p['security'] ?? '').toLowerCase();
    if (security == 'none' && !defaultEnabled) return null;

    final isReality = security == 'reality';
    final isTls = security == 'tls' || defaultEnabled || isReality;
    if (!isTls) return null;

    final tls = <String, dynamic>{'enabled': true};

    _putIfPresent(tls, 'server_name', p['sni'] ?? p['peer']);

    if ((p['insecure'] ?? p['allowInsecure'] ?? '') == '1') {
      tls['insecure'] = true;
    }

    final alpn = p['alpn'] ?? '';
    if (alpn.isNotEmpty) tls['alpn'] = alpn.split(',');

    final fp = p['fp'] ?? '';
    if (fp.isNotEmpty) {
      tls['utls'] = {'enabled': true, 'fingerprint': fp};
    }

    if (isReality) {
      final reality = <String, dynamic>{'enabled': true};
      _putIfPresent(reality, 'public_key', p['pbk']);
      _putIfPresent(reality, 'short_id', p['sid']);
      _putIfPresent(reality, 'spider_x', p['spx'] ?? p['spiderX']);
      tls['reality'] = reality;
    }

    return tls;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━ Transport helper ━━━━━━━━━━━━━━━━━━━━

  /// Builds V2Ray transport options from common query parameters.
  static Map<String, dynamic>? _buildTransport(Map<String, String> p) {
    final type = (p['type'] ?? p['net'] ?? 'tcp').toLowerCase();
    final host = p['host'] ?? '';
    final path = p['path'] ?? '';
    final serviceName = p['serviceName'] ?? '';
    final headerType = p['headerType'] ?? '';

    switch (type) {
      case 'ws':
        final t = <String, dynamic>{'type': 'ws'};
        if (path.isNotEmpty) t['path'] = path;
        if (host.isNotEmpty) t['headers'] = {'Host': host};
        final ed = p['ed'] ?? '';
        if (ed.isNotEmpty) {
          t['max_early_data'] = int.tryParse(ed) ?? 0;
          t['early_data_header_name'] = 'Sec-WebSocket-Protocol';
        }
        return t;

      case 'grpc':
        final t = <String, dynamic>{'type': 'grpc'};
        final sn = serviceName.isNotEmpty ? serviceName : path;
        if (sn.isNotEmpty) t['service_name'] = sn;
        return t;

      case 'h2':
        final t = <String, dynamic>{'type': 'http'};
        if (host.isNotEmpty) t['host'] = host.split(',');
        if (path.isNotEmpty) t['path'] = path;
        return t;

      case 'httpupgrade':
        final t = <String, dynamic>{'type': 'httpupgrade'};
        if (host.isNotEmpty) t['host'] = host;
        if (path.isNotEmpty) t['path'] = path;
        return t;

      case 'xhttp':
      case 'splithttp':
        final t = <String, dynamic>{'type': 'xhttp'};
        if (host.isNotEmpty) t['host'] = host;
        if (path.isNotEmpty) t['path'] = path;
        final mode = p['mode'] ?? '';
        if (mode.isNotEmpty) t['mode'] = mode;
        _mergeExtraJson(t, p['extra'], skipKeys: const {'type'});
        return t;

      case 'kcp':
      case 'mkcp':
        final t = <String, dynamic>{'type': 'mkcp'};
        final seed = p['seed'] ?? '';
        if (seed.isNotEmpty) t['seed'] = seed;
        final ht = headerType.isNotEmpty ? headerType : (p['headerType'] ?? '');
        if (ht.isNotEmpty && ht != 'none') t['header_type'] = ht;
        return t;

      case 'tcp':
        // tcp with headerType=http → sing-box "http" transport
        if (headerType == 'http') {
          final t = <String, dynamic>{'type': 'http'};
          if (host.isNotEmpty) t['host'] = host.split(',');
          if (path.isNotEmpty) t['path'] = path;
          return t;
        }
        return null; // raw tcp, no transport needed

      case 'quic':
        return <String, dynamic>{'type': 'quic'};

      default:
        return null;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━ Utility ━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Extracts URL fragment (after #), URL-decoded.
  static String _fragment(String raw) {
    final idx = raw.lastIndexOf('#');
    if (idx < 0) return '';
    try {
      return Uri.decodeComponent(raw.substring(idx + 1));
    } catch (_) {
      return raw.substring(idx + 1);
    }
  }

  /// Decodes URL-safe or standard base64 with optional padding fix.
  static String? _decodeBase64(String input) {
    if (input.isEmpty) return null;
    try {
      String s = input.replaceAll('-', '+').replaceAll('_', '/');
      switch (s.length % 4) {
        case 2:
          s += '==';
        case 3:
          s += '=';
      }
      return utf8.decode(base64Decode(s));
    } catch (_) {
      return null;
    }
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static int _portOr(String raw, [int defaultPort = 443]) {
    // Uri normalizes an explicit :0 away for custom schemes. Inspect the
    // original authority so invalid input cannot become a missing port.
    final port = _explicitPortText(raw);
    return port == null ? defaultPort : _validatedPort(int.tryParse(port));
  }

  static int _validatedPort(int? port) {
    if (port == null || port < 1 || port > 65535) {
      throw const FormatException(
        'Proxy port must be an integer from 1 to 65535.',
      );
    }
    return port;
  }

  static String _str(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    return v.toString();
  }

  static void _putIfPresent(Map<String, dynamic> map, String key, String? v) {
    if (v != null && v.isNotEmpty) map[key] = v;
  }

  static void _addUriCredentials(Map<String, dynamic> result, Uri uri) {
    if (uri.userInfo.isEmpty) return;

    final separator = uri.userInfo.indexOf(':');
    if (separator < 0) {
      final decoded = Uri.decodeComponent(uri.userInfo);
      final base64Credentials = _decodeBase64(decoded);
      final base64Separator = base64Credentials?.indexOf(':') ?? -1;
      if (base64Credentials != null && base64Separator >= 0) {
        final username = base64Credentials.substring(0, base64Separator);
        final password = base64Credentials.substring(base64Separator + 1);
        if (username.isNotEmpty) result['username'] = username;
        if (password.isNotEmpty) result['password'] = password;
        return;
      }
      result['username'] = decoded;
      return;
    }

    final username = Uri.decodeComponent(uri.userInfo.substring(0, separator));
    final password = Uri.decodeComponent(uri.userInfo.substring(separator + 1));
    if (username.isNotEmpty) result['username'] = username;
    if (password.isNotEmpty) result['password'] = password;
  }

  static Map<String, String> _parseHttpHeaders(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return const {};

    final headers = <String, String>{};
    for (final line in value.split(_httpHeaderLineBreakPattern)) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final name = line.substring(0, separator).trim();
      final headerValue = line.substring(separator + 1).trim();
      if (name.isNotEmpty && headerValue.isNotEmpty) {
        headers[name] = headerValue;
      }
    }
    return headers;
  }

  static int? _explicitPort(String raw) {
    final port = _explicitPortText(raw);
    return port == null ? null : int.tryParse(port);
  }

  static String? _explicitPortText(String raw) {
    final schemeEnd = raw.indexOf('://');
    if (schemeEnd < 0) return null;

    var authority = raw.substring(schemeEnd + 3);
    final end = authority.indexOf(_authorityTerminatorPattern);
    if (end >= 0) {
      authority = authority.substring(0, end);
    }

    final at = authority.lastIndexOf('@');
    if (at >= 0) {
      authority = authority.substring(at + 1);
    }

    if (authority.startsWith('[')) {
      final close = authority.indexOf(']');
      if (close < 0) return null;
      final rest = authority.substring(close + 1);
      if (!rest.startsWith(':')) return null;
      return rest.substring(1);
    }

    final colon = authority.lastIndexOf(':');
    if (colon < 0) return null;
    return authority.substring(colon + 1);
  }

  static dynamic _parseJsonValue(String? input) {
    final raw = (input ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }

    for (final candidate in [raw, _decodeBase64(raw)]) {
      if (candidate == null || candidate.isEmpty) {
        continue;
      }
      try {
        return jsonDecode(candidate);
      } catch (_) {}
    }
    return null;
  }

  static void _mergeExtraJson(
    Map<String, dynamic> target,
    String? extra, {
    Set<String> skipKeys = const {},
  }) {
    final parsed = _parseJsonValue(extra);
    if (parsed is! Map) {
      return;
    }

    for (final entry in parsed.entries) {
      final key = _camelToSnake(entry.key.toString());
      if (skipKeys.contains(key)) {
        continue;
      }
      target[key] = entry.value;
    }
  }

  /// Converts camelCase to snake_case (e.g. xPaddingBytes → x_padding_bytes).
  static String _camelToSnake(String input) {
    return input.replaceAllMapped(
      _uppercasePattern,
      (m) => '_${m.group(0)!.toLowerCase()}',
    );
  }

  /// Parses host:port (supports [IPv6]:port) and calls [cb].
  static void _parseHostPort(
    String input,
    void Function(String host, int port) cb,
  ) {
    if (input.startsWith('[')) {
      // IPv6
      final closeBracket = input.indexOf(']');
      if (closeBracket < 0) return;
      final host = input.substring(1, closeBracket);
      final rest = input.substring(closeBracket + 1);
      if (rest.startsWith(':')) {
        final port = int.tryParse(rest.substring(1));
        if (port != null) cb(host, port);
      }
    } else {
      final colonIdx = input.lastIndexOf(':');
      if (colonIdx < 0) return;
      final host = input.substring(0, colonIdx);
      final port = int.tryParse(input.substring(colonIdx + 1));
      if (port != null) cb(host, port);
    }
  }
}
