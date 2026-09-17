import 'package:yaml/yaml.dart';
import 'cert_pin_utils.dart';

/// Parses Clash / Clash Meta YAML configs into sing-box outbound JSON maps.
class ClashParser {
  ClashParser._();

  /// Returns `true` if [content] looks like a Clash config.
  static bool canParse(String content) {
    // Quick heuristic: contains "proxies:" at the start of a line
    return RegExp(r'^proxies\s*:', multiLine: true).hasMatch(content);
  }

  /// Parses the YAML [content] and returns a list of sing-box outbound maps.
  /// Each map has an extra `_name` key.
  static List<Map<String, dynamic>> parse(String content) {
    final doc = loadYaml(content);
    if (doc is! YamlMap) return [];

    final proxies = doc['proxies'];
    if (proxies is! YamlList) return [];

    final results = <Map<String, dynamic>>[];
    for (final proxy in proxies) {
      if (proxy is! YamlMap) continue;
      final converted = _convertProxy(proxy);
      if (converted != null) results.add(converted);
    }
    return results;
  }

  // ─────────────────────── dispatcher ───────────────────────

  static Map<String, dynamic>? _convertProxy(YamlMap proxy) {
    final type = _s(proxy['type']);
    switch (type) {
      case 'vmess':
        return _vmess(proxy);
      case 'vless':
        return _vless(proxy);
      case 'trojan':
        return _trojan(proxy);
      case 'ss':
        return _shadowsocks(proxy);
      case 'ssr':
        return _shadowsocksr(proxy);
      case 'hysteria2':
        return _hysteria2(proxy);
      case 'hysteria':
        return _hysteria(proxy);
      case 'tuic':
        return _tuic(proxy);
      case 'wireguard':
        return _wireguard(proxy);
      case 'anytls':
        return _anytls(proxy);
      default:
        return null;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━ VMess ━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic> _vmess(YamlMap p) {
    final r = _base(p, 'vmess');
    r['uuid'] = _s(p['uuid']);
    r['alter_id'] = _i(p['alterId']);
    r['security'] = _s(p['cipher'], 'auto');

    _addTls(r, p);
    _addTransport(r, p);
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━━━━ VLESS ━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic> _vless(YamlMap p) {
    final r = _base(p, 'vless');
    r['uuid'] = _s(p['uuid']);
    final flow = _s(p['flow']);
    if (flow.isNotEmpty) r['flow'] = flow;

    _addTls(r, p);
    _addTransport(r, p);
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━━━━ Trojan ━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic> _trojan(YamlMap p) {
    final r = _base(p, 'trojan');
    r['password'] = _s(p['password']);

    // Trojan defaults to TLS on
    _addTls(r, p, defaultEnabled: true);
    _addTransport(r, p);
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━━━━ Shadowsocks ━━━━━━━━━━━━━━━━

  static Map<String, dynamic> _shadowsocks(YamlMap p) {
    final r = _base(p, 'shadowsocks');
    r['method'] = _s(p['cipher']);
    r['password'] = _s(p['password']);

    final plugin = _s(p['plugin']);
    if (plugin.isNotEmpty) {
      r['plugin'] = plugin;
      // plugin-opts can be a map
      final opts = p['plugin-opts'];
      if (opts is YamlMap) {
        r['plugin_opts'] = _pluginOptsToString(opts);
      } else {
        final s = _s(p['plugin-opts']);
        if (s.isNotEmpty) r['plugin_opts'] = s;
      }
    }
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━━━━ ShadowsocksR ━━━━━━━━━━━━━━━

  static Map<String, dynamic> _shadowsocksr(YamlMap p) {
    final r = _base(p, 'shadowsocksr');
    r['method'] = _s(p['cipher']);
    r['password'] = _s(p['password']);

    final obfs = _s(p['obfs']);
    if (obfs.isNotEmpty) r['obfs'] = obfs;
    final obfsParam = _s(p['obfs-param']);
    if (obfsParam.isNotEmpty) r['obfs_param'] = obfsParam;
    final proto = _s(p['protocol']);
    if (proto.isNotEmpty) r['protocol'] = proto;
    final protoParam = _s(p['protocol-param']);
    if (protoParam.isNotEmpty) r['protocol_param'] = protoParam;

    return r;
  }

  // ━━━━━━━━━━━━━━━━━━━━━ Hysteria2 ━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic> _hysteria2(YamlMap p) {
    final r = _base(p, 'hysteria2');
    final pw = _s(p['password']);
    if (pw.isNotEmpty) r['password'] = pw;

    _addTls(r, p, defaultEnabled: true);

    final obfsType = _s(p['obfs']);
    final obfsPw = _s(p['obfs-password']);
    if (obfsType.isNotEmpty) {
      r['obfs'] = <String, dynamic>{'type': obfsType, 'password': obfsPw};
    }
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━━━━ Hysteria ━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic> _hysteria(YamlMap p) {
    final r = _base(p, 'hysteria');
    final auth = _s(p['auth-str'] ?? p['auth_str']);
    if (auth.isNotEmpty) r['auth_string'] = auth;

    final up = _i(p['up']);
    final down = _i(p['down']);
    if (up > 0) r['up_mbps'] = up;
    if (down > 0) r['down_mbps'] = down;

    final obfs = _s(p['obfs']);
    if (obfs.isNotEmpty) r['obfs'] = obfs;

    _addTls(r, p, defaultEnabled: true);
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━━━━ TUIC ━━━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic> _tuic(YamlMap p) {
    final r = _base(p, 'tuic');
    r['uuid'] = _s(p['uuid']);
    r['password'] = _s(p['password']);

    final cc = _s(p['congestion-controller'] ?? p['congestion_control']);
    if (cc.isNotEmpty) r['congestion_control'] = cc;
    final relay = _s(p['udp-relay-mode'] ?? p['udp_relay_mode']);
    if (relay.isNotEmpty) r['udp_relay_mode'] = relay;

    _addTls(r, p, defaultEnabled: true);
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━━━━ WireGuard ━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic> _wireguard(YamlMap p) {
    final name = _s(p['name']);
    final r = <String, dynamic>{
      'type': 'wireguard',
      'tag': '',
      '_name': name.isNotEmpty ? name : 'WireGuard',
    };

    final privateKey = _s(p['private-key'] ?? p['private_key']);
    if (privateKey.isNotEmpty) r['private_key'] = privateKey;

    // Addresses
    final addrs = <String>[];
    if (p['ip'] != null) addrs.add(_s(p['ip']));
    if (p['ipv6'] != null) addrs.add(_s(p['ipv6']));
    if (addrs.isNotEmpty) r['address'] = addrs;

    final mtu = _i(p['mtu']);
    if (mtu > 0) r['mtu'] = mtu;

    // Peer
    final peer = <String, dynamic>{};
    final server = _s(p['server']);
    final port = _i(p['port']);
    if (server.isNotEmpty) peer['address'] = server;
    if (port > 0) peer['port'] = port;

    final pubKey = _s(p['public-key'] ?? p['public_key']);
    if (pubKey.isNotEmpty) peer['public_key'] = pubKey;
    final psk = _s(p['pre-shared-key'] ?? p['pre_shared_key']);
    if (psk.isNotEmpty) peer['pre_shared_key'] = psk;

    final reserved = p['reserved'];
    if (reserved is YamlList) {
      peer['reserved'] = reserved.map((e) => _i(e)).toList();
    }

    peer['allowed_ips'] = ['0.0.0.0/0', '::/0'];
    r['peers'] = [peer];

    return r;
  }

  // ━━━━━━━━━━━━━━━━━━━━━ AnyTLS ━━━━━━━━━━━━━━━━━━━━

  static Map<String, dynamic> _anytls(YamlMap p) {
    final r = _base(p, 'anytls');
    r['password'] = _s(p['password']);
    _addTls(r, p, defaultEnabled: true);
    return r;
  }

  // ━━━━━━━━━━━━━━━━━━━━━ Shared helpers ━━━━━━━━━━━━━━

  static Map<String, dynamic> _base(YamlMap p, String type) {
    final name = _s(p['name']);
    return <String, dynamic>{
      'type': type,
      'tag': '',
      'server': _s(p['server']),
      'server_port': _i(p['port']),
      '_name': name.isNotEmpty ? name : '${_s(p['server'])}:${_i(p['port'])}',
    };
  }

  /// Adds TLS options to [r] from Clash proxy map [p].
  static void _addTls(
    Map<String, dynamic> r,
    YamlMap p, {
    bool defaultEnabled = false,
  }) {
    final tlsFlag = p['tls'];
    final isEnabled = (tlsFlag == true) || defaultEnabled;
    if (!isEnabled) return;

    final tls = <String, dynamic>{'enabled': true};

    final sni = _s(p['servername'] ?? p['sni']);
    if (sni.isNotEmpty) tls['server_name'] = sni;

    if (p['skip-cert-verify'] == true) tls['insecure'] = true;

    final alpn = p['alpn'];
    if (alpn is YamlList) {
      tls['alpn'] = alpn.map((e) => e.toString()).toList();
    }

    final fp = _s(p['client-fingerprint']);
    if (fp.isNotEmpty) {
      tls['utls'] = {'enabled': true, 'fingerprint': fp};
    }

    final rawCertPin = p['pinned-peer-cert-sha256'] ??
        p['pinnedPeerCertSha256'] ??
        p['certificate-sha256'] ??
        p['certificate_sha256'];
    var pins = normalizeCertPins(rawCertPin);
    if (pins.isEmpty) {
      final fpVal = _s(p['fingerprint']).trim();
      if (fpVal.isNotEmpty) {
        pins = normalizeCertPins(fpVal);
      }
    }
    if (pins.isNotEmpty) {
      tls['certificate_sha256'] = pins;
    }

    // Reality
    final realityOpts = p['reality-opts'];
    if (realityOpts is YamlMap) {
      final reality = <String, dynamic>{'enabled': true};
      final pbk = _s(realityOpts['public-key']);
      if (pbk.isNotEmpty) reality['public_key'] = pbk;
      final sid = _s(realityOpts['short-id']);
      if (sid.isNotEmpty) reality['short_id'] = sid;
      tls['reality'] = reality;
    }

    r['tls'] = tls;
  }

  /// Adds V2Ray transport options to [r] from Clash proxy map [p].
  static void _addTransport(Map<String, dynamic> r, YamlMap p) {
    final net = _s(p['network']);
    if (net.isEmpty || net == 'tcp') {
      // Check for http-opts on tcp → sing-box "http" transport
      final httpOpts = p['http-opts'];
      if (httpOpts is YamlMap) {
        final t = <String, dynamic>{'type': 'http'};
        final hosts = httpOpts['host'];
        if (hosts is YamlList) {
          t['host'] = hosts.map((e) => e.toString()).toList();
        }
        final path = _s(httpOpts['path']);
        if (path.isNotEmpty) t['path'] = path;
        r['transport'] = t;
      }
      return;
    }

    switch (net) {
      case 'ws':
        final opts = p['ws-opts'] is YamlMap ? p['ws-opts'] as YamlMap : null;
        final t = <String, dynamic>{'type': 'ws'};
        if (opts != null) {
          final path = _s(opts['path']);
          if (path.isNotEmpty) t['path'] = path;
          final headers = opts['headers'];
          if (headers is YamlMap) {
            t['headers'] = _yamlMapToMap(headers);
          }
          final ed = _i(opts['max-early-data']);
          if (ed > 0) {
            t['max_early_data'] = ed;
            final edh = _s(opts['early-data-header-name']);
            if (edh.isNotEmpty) t['early_data_header_name'] = edh;
          }
        }
        r['transport'] = t;

      case 'grpc':
        final opts = p['grpc-opts'] is YamlMap
            ? p['grpc-opts'] as YamlMap
            : null;
        final t = <String, dynamic>{'type': 'grpc'};
        if (opts != null) {
          final sn = _s(opts['grpc-service-name'] ??
              opts['grpcServiceName'] ??
              opts['service-name'] ??
              opts['serviceName']);
          if (sn.isNotEmpty) t['service_name'] = sn;
        }
        r['transport'] = t;

      case 'h2':
        final opts = p['h2-opts'] is YamlMap ? p['h2-opts'] as YamlMap : null;
        final t = <String, dynamic>{'type': 'http'};
        if (opts != null) {
          final hosts = opts['host'];
          if (hosts is YamlList) {
            t['host'] = hosts.map((e) => e.toString()).toList();
          }
          final path = _s(opts['path']);
          if (path.isNotEmpty) t['path'] = path;
        }
        r['transport'] = t;

      case 'httpupgrade':
        final opts = p['httpupgrade-opts'] is YamlMap
            ? p['httpupgrade-opts'] as YamlMap
            : null;
        final t = <String, dynamic>{'type': 'httpupgrade'};
        if (opts != null) {
          final host = _s(opts['host']);
          if (host.isNotEmpty) t['host'] = host;
          final path = _s(opts['path']);
          if (path.isNotEmpty) t['path'] = path;
        }
        r['transport'] = t;

      case 'xhttp':
      case 'splithttp':
        final opts = p['xhttp-opts'] is YamlMap
            ? p['xhttp-opts'] as YamlMap
            : p['splithttp-opts'] is YamlMap
            ? p['splithttp-opts'] as YamlMap
            : null;
        final t = <String, dynamic>{'type': 'xhttp'};
        if (opts != null) {
          final host = _s(opts['host']);
          if (host.isNotEmpty) t['host'] = host;
          final path = _s(opts['path']);
          if (path.isNotEmpty) t['path'] = path;
          final mode = _s(opts['mode']);
          if (mode.isNotEmpty) t['mode'] = mode;
          final headers = opts['headers'];
          if (headers is YamlMap) {
            t['headers'] = _yamlMapToMap(headers);
          }
          // xmux
          final xmux = opts['xmux'];
          if (xmux is YamlMap) {
            t['xmux'] = _yamlMapToMap(xmux);
          }
        }
        r['transport'] = t;

      case 'kcp':
      case 'mkcp':
        final opts = p['kcp-opts'] is YamlMap
            ? p['kcp-opts'] as YamlMap
            : p['mkcp-opts'] is YamlMap
            ? p['mkcp-opts'] as YamlMap
            : null;
        final t = <String, dynamic>{'type': 'mkcp'};
        if (opts != null) {
          final seed = _s(opts['seed']);
          if (seed.isNotEmpty) t['seed'] = seed;
          final ht = _s(opts['header-type'] ?? opts['header_type']);
          if (ht.isNotEmpty && ht != 'none') t['header_type'] = ht;
        }
        r['transport'] = t;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━ Utility ━━━━━━━━━━━━━━━━━━━━

  static String _s(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    return v.toString();
  }

  static int _i(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static Map<String, dynamic> _yamlMapToMap(YamlMap m) {
    return m.map((k, v) => MapEntry(k.toString(), v));
  }

  /// Converts Clash plugin-opts map to key=value string format.
  static String _pluginOptsToString(YamlMap opts) {
    return opts.entries.map((e) => '${e.key}=${e.value}').join(';');
  }
}
