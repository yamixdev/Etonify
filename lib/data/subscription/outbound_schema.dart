import 'dart:convert';

/// Shared sing-box outbound sanitization and validation used by
/// subscription import flows.
class ParsedOutboundSchema {
  ParsedOutboundSchema._();

  static const Set<String> _validXhttpModes = {
    'packet-up',
    'stream-up',
    'stream-one',
  };

  static const Set<String> _validV2RayPacketEncodings = {
    '',
    'packetaddr',
    'xudp',
  };

  static const Set<String> _validVlessFlows = {'', 'xtls-rprx-vision'};

  static const Set<String> _validUtlsFingerprints = {
    '',
    'chrome',
    'chrome_psk',
    'chrome_psk_shuffle',
    'chrome_padding_psk_shuffle',
    'chrome_pq',
    'chrome_pq_psk',
    'firefox',
    'edge',
    'safari',
    '360',
    'qq',
    'ios',
    'android',
    'random',
    'randomized',
  };

  static const Set<String> _validHysteria2ObfsTypes = {'salamander'};

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static const Set<String> _knownOutboundTypes = {
    'vless',
    'vmess',
    'trojan',
    'shadowsocks',
    'shadowsocksr',
    'socks',
    'http',
    'hysteria',
    'hysteria2',
    'tuic',
    'anytls',
    'naive',
  };

  static const Set<String> _baseOutboundKeys = {
    '_name',
    '_source_tag',
    '_source_scope',
    '_source_profile_name',
    '_detour_source_tag',
    '_country_override',
    '_group_only',
    'type',
    'tag',
    'detour',
    'bind_interface',
    'inet4_bind_address',
    'inet6_bind_address',
    'bind_address_no_port',
    'protect_path',
    'routing_mark',
    'reuse_addr',
    'netns',
    'connect_timeout',
    'tcp_fast_open',
    'tcp_multi_path',
    'disable_tcp_keep_alive',
    'tcp_keep_alive',
    'tcp_keep_alive_interval',
    'udp_fragment',
    'domain_resolver',
    'network_strategy',
    'network_type',
    'fallback_network_type',
    'fallback_delay',
    'domain_strategy',
    'server',
    'server_port',
    'network',
    'tls',
    'multiplex',
    'transport',
  };

  static const Set<String> _tlsKeys = {
    'enabled',
    'disable_sni',
    'server_name',
    'insecure',
    'alpn',
    'min_version',
    'max_version',
    'cipher_suites',
    'curve_preferences',
    'certificate',
    'certificate_path',
    'certificate_public_key_sha256',
    'client_certificate',
    'client_certificate_path',
    'client_key',
    'client_key_path',
    'fragment',
    'fragment_fallback_delay',
    'record_fragment',
    'kernel_tx',
    'kernel_rx',
    'ech',
    'utls',
    'reality',
  };

  static const Set<String> _tlsEchKeys = {
    'enabled',
    'config',
    'config_path',
    'query_server_name',
    'pq_signature_schemes_enabled',
    'dynamic_record_sizing_disabled',
  };

  static const Set<String> _tlsUtlsKeys = {'enabled', 'fingerprint'};

  static const Set<String> _tlsRealityKeys = {
    'enabled',
    'public_key',
    'short_id',
    'spider_x',
  };

  static const Set<String> _multiplexKeys = {
    'enabled',
    'protocol',
    'max_connections',
    'min_streams',
    'max_streams',
    'padding',
    'brutal',
  };

  static const Set<String> _brutalKeys = {'enabled', 'up_mbps', 'down_mbps'};

  static const Set<String> _udpOverTcpKeys = {'enabled', 'version'};

  static const Set<String> _domainResolverKeys = {
    'server',
    'strategy',
    'disable_cache',
    'disable_optimistic_cache',
    'rewrite_ttl',
    'client_subnet',
  };

  static const Set<String> _wireGuardPeerKeys = {
    'address',
    'port',
    'public_key',
    'pre_shared_key',
    'allowed_ips',
    'persistent_keepalive_interval',
    'reserved',
  };

  static const Set<String> _rangeConfigKeys = {'from', 'to'};

  static const Set<String> _xhttpXmuxKeys = {
    'max_concurrency',
    'max_connections',
    'c_max_reuse_times',
    'h_max_request_times',
    'h_max_reusable_secs',
    'h_keep_alive_period',
  };

  static const Set<String> _transportKeysHttp = {
    'type',
    'host',
    'path',
    'method',
    'headers',
    'idle_timeout',
    'ping_timeout',
  };

  static const Set<String> _transportKeysWs = {
    'type',
    'path',
    'headers',
    'max_early_data',
    'early_data_header_name',
  };

  static const Set<String> _transportKeysGrpc = {
    'type',
    'service_name',
    'idle_timeout',
    'ping_timeout',
    'permit_without_stream',
  };

  static const Set<String> _transportKeysHttpUpgrade = {
    'type',
    'host',
    'path',
    'headers',
  };

  static const Set<String> _transportKeysXhttp = {
    'type',
    'host',
    'path',
    'mode',
    'headers',
    'x_padding_bytes',
    'x_padding_obfs_mode',
    'x_padding_key',
    'x_padding_header',
    'x_padding_placement',
    'x_padding_method',
    'no_grpc_header',
    'no_sse_header',
    'uplink_http_method',
    'uplink_data_placement',
    'uplink_data_key',
    'uplink_chunk_size',
    'session_placement',
    'session_key',
    'seq_placement',
    'seq_key',
    'sc_max_each_post_bytes',
    'sc_min_posts_interval_ms',
    'sc_max_buffered_posts',
    'sc_stream_up_server_secs',
    'xmux',
  };

  static const Set<String> _transportKeysMkcp = {
    'type',
    'mtu',
    'tti',
    'uplink_capacity',
    'downlink_capacity',
    'congestion',
    'write_buffer_size',
    'read_buffer_size',
    'seed',
    'header',
    'masks',
    // Legacy parser shim until mkcp import output is canonicalized upstream.
    'header_type',
  };

  static const Set<String> _transportKeysQuic = {'type'};

  static const Set<String> _kcpHeaderKeys = {'type', 'domain'};

  static const Set<String> _mkcpMaskKeys = {'type', 'password', 'domain'};

  static const Set<String> _typeSpecificKeysVless = {
    'uuid',
    'flow',
    'encryption',
    'packet_encoding',
  };

  static const Set<String> _typeSpecificKeysVmess = {
    'uuid',
    'security',
    'alter_id',
    'global_padding',
    'authenticated_length',
    'packet_encoding',
  };

  static const Set<String> _typeSpecificKeysTrojan = {'password'};

  static const Set<String> _typeSpecificKeysShadowsocks = {
    'method',
    'password',
    'plugin',
    'plugin_opts',
    'udp_over_tcp',
  };

  static const Set<String> _typeSpecificKeysShadowsocksr = {
    'method',
    'password',
    'obfs',
    'obfs_param',
    'protocol',
    'protocol_param',
  };

  static const Set<String> _typeSpecificKeysSocks = {
    'version',
    'username',
    'password',
    'udp_over_tcp',
  };

  static const Set<String> _typeSpecificKeysHttp = {
    'username',
    'password',
    'path',
    'headers',
  };

  static const Set<String> _typeSpecificKeysNaive = {
    'username',
    'password',
    'insecure_concurrency',
    'extra_headers',
    'stream_receive_window',
    'udp_over_tcp',
    'quic',
    'quic_congestion_control',
    'quic_session_receive_window',
  };

  static const Set<String> _typeSpecificKeysHysteria = {
    'server_ports',
    'hop_interval',
    'up',
    'up_mbps',
    'down',
    'down_mbps',
    'obfs',
    'auth',
    'auth_str',
    'recv_window_conn',
    'recv_window',
    'disable_mtu_discovery',
  };

  static const Set<String> _typeSpecificKeysHysteria2 = {
    'server_ports',
    'hop_interval',
    'hop_interval_max',
    'up_mbps',
    'down_mbps',
    'obfs',
    'password',
    'bbr_profile',
    'brutal_debug',
  };

  static const Set<String> _typeSpecificKeysTuic = {
    'uuid',
    'password',
    'congestion_control',
    'udp_relay_mode',
    'udp_over_stream',
    'zero_rtt_handshake',
    'heartbeat',
  };

  static const Set<String> _typeSpecificKeysAnytls = {
    'password',
    'idle_session_check_interval',
    'idle_session_timeout',
    'min_idle_session',
  };

  static const Set<String> _typeSpecificKeysWireguard = {
    'system',
    'name',
    'mtu',
    'address',
    'private_key',
    'listen_port',
    'peers',
    'udp_timeout',
    'workers',
  };

  static Map<String, dynamic>? sanitize(Map<String, dynamic> outbound) {
    final canonical = _canonicalize(outbound);
    final sanitized = _sanitizeOutbound(canonical);
    if (sanitized == null) {
      return null;
    }
    _applyKnownFixups(sanitized);
    final normalized = _deepNormalizeValue(sanitized);
    if (normalized is! Map<String, dynamic>) {
      return null;
    }
    if (validate(normalized) != null) {
      return null;
    }
    return normalized;
  }

  static String? validate(Map<String, dynamic> config) {
    final type = _normalizedType(config['type']);
    if (!_knownOutboundTypes.contains(type)) {
      return 'unsupported outbound type: ${type.isEmpty ? 'unknown' : type}';
    }
    if (type == 'shadowsocksr') {
      return 'unsupported outbound type: shadowsocksr';
    }

    if (_requiresServer(type)) {
      final server = (config['server'] as String?)?.trim() ?? '';
      final serverPort = _intValue(config['server_port']);
      if (server.isEmpty) {
        return 'missing server';
      }
      if (serverPort == null || serverPort <= 0) {
        return 'missing server_port';
      }
    }

    if (type == 'vless' || type == 'vmess' || type == 'tuic') {
      final uuid = (config['uuid'] as String?)?.trim() ?? '';
      if (uuid.isEmpty) {
        return 'missing uuid';
      }
      if (type == 'tuic' && !_isValidUuid(uuid)) {
        return 'invalid tuic uuid: $uuid';
      }
    }

    if (type == 'vless' && config.containsKey('packet_encoding')) {
      final packetEncoding = config['packet_encoding'];
      if (packetEncoding is! String) {
        return 'invalid vless packet_encoding: $packetEncoding';
      }
      final normalizedPacketEncoding = packetEncoding.trim().toLowerCase();
      if (!_validV2RayPacketEncodings.contains(normalizedPacketEncoding)) {
        return 'invalid vless packet_encoding: $packetEncoding';
      }
    }

    if (type == 'vmess' && config.containsKey('packet_encoding')) {
      final packetEncoding = config['packet_encoding'];
      if (packetEncoding is! String) {
        return 'invalid vmess packet_encoding: $packetEncoding';
      }
      final normalizedPacketEncoding = packetEncoding.trim().toLowerCase();
      if (!_validV2RayPacketEncodings.contains(normalizedPacketEncoding)) {
        return 'invalid vmess packet_encoding: $packetEncoding';
      }
    }

    if (type == 'vless' && config.containsKey('flow')) {
      final flow = config['flow'];
      if (flow is! String) {
        return 'invalid vless flow: $flow';
      }
      final normalizedFlow = flow.trim();
      if (!_validVlessFlows.contains(normalizedFlow)) {
        return 'unsupported vless flow: $flow';
      }
    }

    if (type == 'vless' && config.containsKey('encryption')) {
      final encryption = config['encryption'];
      if (encryption is! String || !_isValidVlessEncryption(encryption)) {
        return 'invalid vless encryption: $encryption';
      }
    }

    if (type == 'tuic' &&
        config['udp_over_stream'] == true &&
        ((config['udp_relay_mode'] as String?)?.trim().isNotEmpty ?? false)) {
      return 'udp_over_stream is conflict with udp_relay_mode';
    }

    if (type == 'trojan' || type == 'anytls') {
      final password = (config['password'] as String?)?.trim() ?? '';
      if (password.isEmpty) {
        return 'missing password';
      }
    }

    if (type == 'shadowsocks') {
      final method = (config['method'] as String?)?.trim().toLowerCase() ?? '';
      if (method.isEmpty) {
        return 'missing shadowsocks method';
      }
      if (method == 'auto' || method == 'chacha20-poly1305') {
        return 'unsupported shadowsocks method: $method';
      }
    }

    if (type == 'hysteria2') {
      final tls = config['tls'];
      if (tls is! Map || tls['enabled'] != true) {
        return 'missing hysteria2 tls';
      }
      final obfs = config['obfs'];
      if (obfs is Map) {
        final obfsType = (obfs['type'] as String?)?.trim().toLowerCase() ?? '';
        final password = (obfs['password'] as String?)?.trim() ?? '';
        if (password.isEmpty) {
          return 'missing hysteria2 obfs password';
        }
        if (!_validHysteria2ObfsTypes.contains(obfsType)) {
          return 'unknown hysteria2 obfs type: $obfsType';
        }
      }
    }

    if (type == 'naive') {
      final tls = config['tls'];
      if (tls is! Map || tls['enabled'] != true) {
        return 'missing naive tls';
      }
    }

    if (type == 'wireguard') {
      final privateKey = (config['private_key'] as String?)?.trim() ?? '';
      final address = config['address'];
      if (privateKey.isEmpty) {
        return 'missing wireguard private_key';
      }
      if (!_isValidBase64Key(privateKey, 32)) {
        return 'invalid wireguard private_key';
      }
      if (address is! List || address.isEmpty) {
        return 'missing wireguard address';
      }
      final peers = config['peers'];
      if (peers is! List || peers.isEmpty) {
        return 'missing wireguard peers';
      }
      for (var i = 0; i < peers.length; i++) {
        final peer = peers[i];
        if (peer is! Map) {
          return 'invalid wireguard peer $i';
        }
        final peerAddress = peer['address']?.toString().trim() ?? '';
        if (peerAddress.isEmpty) {
          return 'missing wireguard peer $i address';
        }
        final peerPort = _intValue(peer['port']);
        if (peerPort == null || peerPort <= 0 || peerPort > 65535) {
          return 'invalid wireguard peer $i port';
        }
        final publicKey = (peer['public_key'] as String?)?.trim() ?? '';
        if (publicKey.isEmpty) {
          return 'missing wireguard peer $i public_key';
        }
        if (!_isValidBase64Key(publicKey, 32)) {
          return 'invalid wireguard peer $i public_key';
        }
        final preSharedKey = (peer['pre_shared_key'] as String?)?.trim() ?? '';
        if (preSharedKey.isNotEmpty && !_isValidBase64Key(preSharedKey, 32)) {
          return 'invalid wireguard peer $i pre_shared_key';
        }
        final allowedIps = peer['allowed_ips'];
        if (allowedIps is! List || allowedIps.isEmpty) {
          return 'missing wireguard peer $i allowed_ips';
        }
        final keepalive = peer['persistent_keepalive_interval'];
        if (keepalive != null) {
          final keepaliveSeconds = _wireGuardKeepaliveSeconds(keepalive);
          if (keepaliveSeconds == null ||
              keepaliveSeconds < 0 ||
              keepaliveSeconds > 65535) {
            return 'invalid wireguard peer $i persistent_keepalive_interval';
          }
        }
        final reserved = peer['reserved'];
        if (reserved is List && !_isValidWireGuardReserved(reserved)) {
          return 'invalid wireguard peer $i reserved';
        }
      }
    }

    final transport = config['transport'];
    if (transport is Map) {
      final transportType = _normalizedType(transport['type']);
      if (!_knownTransportTypes.contains(transportType)) {
        return 'unsupported transport type: ${transportType.isEmpty ? 'unknown' : transportType}';
      }
      final transportValidationError = _validateTransport(
        transportType,
        transport,
      );
      if (transportValidationError != null) {
        return transportValidationError;
      }
    } else if (config.containsKey('transport') && transport != null) {
      return 'invalid transport: $transport';
    }

    final tls = config['tls'];
    if (tls is Map) {
      final reality = tls['reality'];
      if (reality is Map && reality['enabled'] == true) {
        final publicKey = (reality['public_key'] as String?)?.trim();
        if (publicKey == null || publicKey.isEmpty) {
          return 'missing reality public_key';
        }
        if (!isValidRealityPublicKey(publicKey)) {
          return 'invalid reality public_key';
        }
        final shortId = reality['short_id'];
        if (shortId != null && _normalizeRealityShortIdValue(shortId) == null) {
          return 'invalid reality short_id';
        }
        final utls = tls['utls'];
        if (utls is! Map || utls['enabled'] != true) {
          return 'missing reality utls';
        }
        final fingerprint =
            (utls['fingerprint'] as String?)?.trim().toLowerCase() ?? '';
        if (!_validUtlsFingerprints.contains(fingerprint)) {
          return 'unknown utls fingerprint: ${utls['fingerprint']}';
        }
      }
    }

    return null;
  }

  static String? _validateTransport(String type, Map transport) {
    if (const {
      'http',
      'ws',
      'httpupgrade',
      'xhttp',
      'splithttp',
    }.contains(type)) {
      final path = transport['path'];
      if (path != null) {
        if (path is! String) {
          return 'invalid $type path: $path';
        }
        final pathError = _invalidUrlEscape(path);
        if (pathError != null) {
          return 'invalid $type path: $pathError';
        }
      }
    }

    if (type == 'mkcp') {
      final masks = transport['masks'];
      if (masks is List) {
        for (var i = 0; i < masks.length; i++) {
          final mask = masks[i];
          if (mask is! Map) {
            return 'invalid mkcp mask $i';
          }
          final maskType =
              (mask['type'] as String?)?.trim().toLowerCase() ?? '';
          if (!_validMkcpMaskTypes.contains(maskType)) {
            return 'unknown mkcp mask type: $maskType';
          }
        }
      }
    }

    return null;
  }

  static const Set<String> _validMkcpMaskTypes = {
    '',
    'original',
    'aes128gcm',
    'srtp',
    'utp',
    'wechat-video',
    'dtls',
    'wireguard',
    'dns',
    'salamander',
  };

  static String? _invalidUrlEscape(String value) {
    for (var i = 0; i < value.length; i++) {
      final code = value.codeUnitAt(i);
      if (code < 0x20 || code == 0x7f) {
        return 'invalid URL control character';
      }
      if (code != 0x25) {
        continue;
      }
      final end = i + 3 <= value.length ? i + 3 : value.length;
      final escape = value.substring(i, end);
      if (i + 2 >= value.length ||
          !_isHexDigit(value.codeUnitAt(i + 1)) ||
          !_isHexDigit(value.codeUnitAt(i + 2))) {
        return 'invalid URL escape "$escape"';
      }
      i += 2;
    }
    return null;
  }

  static bool _isHexDigit(int code) {
    return (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x46) ||
        (code >= 0x61 && code <= 0x66);
  }

  static bool _isValidUuid(String value) {
    return _uuidPattern.hasMatch(value.trim());
  }

  static bool _isValidBase64Key(String value, int decodedLength) {
    try {
      return base64.decode(value.trim()).length == decodedLength;
    } catch (_) {
      return false;
    }
  }

  static bool _isValidWireGuardReserved(List<dynamic> value) {
    return value.length == 3 &&
        value.every((item) => item is int && item >= 0 && item <= 255);
  }

  static bool _isValidRealityShortId(dynamic value) {
    if (value is! String) {
      return false;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return true;
    }
    if (normalized.length.isOdd || normalized.length > 16) {
      return false;
    }
    for (var i = 0; i < normalized.length; i++) {
      if (!_isHexDigit(normalized.codeUnitAt(i))) {
        return false;
      }
    }
    return true;
  }

  static String? _normalizeRealityShortIdValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      return null;
    }
    for (final candidate in value.split(',')) {
      final normalized = candidate.trim();
      if (normalized.isEmpty) {
        return '';
      }
      if (_isValidRealityShortId(normalized)) {
        return normalized.toLowerCase();
      }
      return null;
    }
    return null;
  }

  static bool _isValidVlessEncryption(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == 'none') {
      return true;
    }

    final parts = normalized.split('.');
    if (parts.length < 4) {
      return false;
    }
    if (parts[0] != 'mlkem768x25519plus') {
      return false;
    }
    if (parts[1] != 'native' && parts[1] != 'xorpub' && parts[1] != 'random') {
      return false;
    }
    if (parts[2] != '0rtt' && parts[2] != '1rtt') {
      return false;
    }
    return _isValidVlessEncryptionKey(parts.sublist(3).join('.'));
  }

  static bool _isValidVlessEncryptionKey(String value) {
    if (value.isEmpty || value.length < 20) {
      return false;
    }
    if (value.contains(RegExp(r'\s'))) {
      return false;
    }
    // Some Happ/Astracat subscriptions use a structured custom-encryption
    // payload with dot-separated tuning fields before the key material.
    // sing-box accepts the value as an opaque VLESS encryption string, so keep
    // obviously structured values instead of dropping the whole outbound.
    if (value.contains('.') && RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(value)) {
      return true;
    }
    final padded = switch (value.length % 4) {
      0 => value,
      2 => '$value==',
      3 => '$value=',
      _ => '',
    };
    if (padded.isEmpty) {
      return false;
    }
    try {
      final decoded = base64Url.decode(padded);
      return decoded.length == 32 || decoded.length == 1184;
    } catch (_) {
      return false;
    }
  }

  static bool isValidRealityPublicKey(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final padded = switch (normalized.length % 4) {
      0 => normalized,
      2 => '$normalized==',
      3 => '$normalized=',
      _ => '',
    };
    if (padded.isEmpty) {
      return false;
    }
    try {
      final decoded = base64Url.decode(padded);
      return decoded.length == 32;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _canonicalize(Map<String, dynamic> outbound) {
    final canonical = Map<String, dynamic>.from(outbound);
    canonical['type'] = _normalizedType(canonical['type']);

    if (canonical['type'] == 'hysteria' &&
        canonical.containsKey('auth_string') &&
        !canonical.containsKey('auth_str')) {
      canonical['auth_str'] = canonical.remove('auth_string');
    }

    final transport = canonical['transport'];
    if (transport is Map) {
      final transportMap = Map<String, dynamic>.from(transport);
      transportMap['type'] = _normalizedType(transportMap['type']);
      if (transportMap['xmux'] is Map) {
        transportMap['xmux'] = _snakeCaseMap(
          Map<String, dynamic>.from(transportMap['xmux'] as Map),
        );
      }
      canonical['transport'] = transportMap;
    }

    return canonical;
  }

  static Map<String, dynamic>? _sanitizeOutbound(
    Map<String, dynamic> outbound,
  ) {
    final type = _normalizedType(outbound['type']);
    if (type.isEmpty) {
      return null;
    }

    final allowedKeys = <String>{
      ..._baseOutboundKeys,
      ...switch (type) {
        'vless' => _typeSpecificKeysVless,
        'vmess' => _typeSpecificKeysVmess,
        'trojan' => _typeSpecificKeysTrojan,
        'shadowsocks' => _typeSpecificKeysShadowsocks,
        'shadowsocksr' => _typeSpecificKeysShadowsocksr,
        'socks' => _typeSpecificKeysSocks,
        'http' => _typeSpecificKeysHttp,
        'hysteria' => _typeSpecificKeysHysteria,
        'hysteria2' => _typeSpecificKeysHysteria2,
        'tuic' => _typeSpecificKeysTuic,
        'anytls' => _typeSpecificKeysAnytls,
        'naive' => _typeSpecificKeysNaive,
        'wireguard' => _typeSpecificKeysWireguard,
        _ => const <String>{},
      },
    };

    final sanitized = <String, dynamic>{};
    for (final entry in outbound.entries) {
      if (allowedKeys.contains(entry.key)) {
        sanitized[entry.key] = entry.value;
      }
    }

    final tls = _sanitizeTls(sanitized['tls']);
    if (tls == null) {
      sanitized.remove('tls');
    } else {
      sanitized['tls'] = tls;
    }

    final transport = _sanitizeTransport(sanitized['transport']);
    if (transport == null) {
      sanitized.remove('transport');
    } else {
      sanitized['transport'] = transport;
    }

    final multiplex = _sanitizeMultiplex(sanitized['multiplex']);
    if (multiplex == null) {
      sanitized.remove('multiplex');
    } else {
      sanitized['multiplex'] = multiplex;
    }

    final udpOverTcp = _sanitizeUdpOverTcp(sanitized['udp_over_tcp']);
    if (udpOverTcp == null) {
      sanitized.remove('udp_over_tcp');
    } else {
      sanitized['udp_over_tcp'] = udpOverTcp;
    }

    final domainResolver = _sanitizeDomainResolver(
      sanitized['domain_resolver'],
    );
    if (domainResolver == null) {
      sanitized.remove('domain_resolver');
    } else {
      sanitized['domain_resolver'] = domainResolver;
    }

    final headers = sanitized['headers'];
    if (headers is Map) {
      final sanitizedHeaders = _sanitizeHeaders(headers);
      if (sanitizedHeaders.isEmpty) {
        sanitized.remove('headers');
      } else {
        sanitized['headers'] = sanitizedHeaders;
      }
    }

    final obfs = _sanitizeObfs(type, sanitized['obfs']);
    if (obfs == null) {
      sanitized.remove('obfs');
    } else {
      sanitized['obfs'] = obfs;
    }

    if (type == 'wireguard') {
      final peers = sanitized['peers'];
      if (peers is List) {
        final sanitizedPeers = peers
            .map((peer) => _sanitizeWireGuardPeer(peer))
            .whereType<Map<String, dynamic>>()
            .map(_normalizeWireGuardPeer)
            .toList(growable: false);
        if (sanitizedPeers.isEmpty) {
          sanitized.remove('peers');
        } else {
          sanitized['peers'] = sanitizedPeers;
        }
      }
    }

    return sanitized;
  }

  static void _applyKnownFixups(Map<String, dynamic> outbound) {
    final transport = outbound['transport'];
    if (transport is Map) {
      final transportType = _normalizedType(transport['type']);
      if (transportType == 'grpc') {
        final tls = outbound['tls'];
        if (tls is Map) {
          tls['alpn'] = const ['h2'];
        }
      }
    }

    if (_usesQuicTransport(outbound)) {
      final tls = outbound['tls'];
      if (tls is Map) {
        // uTLS copies a TCP ClientHello and sing-box deliberately does not
        // support it for QUIC-based outbounds. Keep the subscription's real
        // SNI and ALPN, but never pass an invalid uTLS option to Hysteria,
        // TUIC, Naive QUIC or the V2Ray QUIC transport.
        tls.remove('utls');
      }
    }

    final tls = outbound['tls'];
    if (tls is Map) {
      final reality = tls['reality'];
      if (reality is Map && reality['enabled'] == true) {
        _normalizeRealityShortId(reality);
        final utls = tls['utls'];
        if (utls is Map) {
          utls['enabled'] = true;
          _normalizeUtlsFingerprint(utls);
        } else {
          tls['utls'] = {'enabled': true};
        }
      }
    }
  }

  static void _normalizeUtlsFingerprint(Map utls) {
    final fingerprint = (utls['fingerprint'] as String?)?.trim();
    if (fingerprint == null || fingerprint.isEmpty) {
      return;
    }
    utls['fingerprint'] = fingerprint.toLowerCase();
  }

  static void _normalizeRealityShortId(Map reality) {
    final normalized = _normalizeRealityShortIdValue(reality['short_id']);
    if (normalized == null) {
      return;
    }
    reality['short_id'] = normalized;
  }

  static Map<String, dynamic>? _sanitizeTls(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final tls = _retainAllowedKeys(Map<String, dynamic>.from(value), _tlsKeys);
    final alpn = _sanitizeAlpn(tls['alpn']);
    final ech = _sanitizeNestedMap(tls['ech'], _tlsEchKeys);
    final utls = _sanitizeNestedMap(tls['utls'], _tlsUtlsKeys);
    final reality = _sanitizeNestedMap(tls['reality'], _tlsRealityKeys);

    if (ech == null) {
      tls.remove('ech');
    } else {
      tls['ech'] = ech;
    }

    if (utls == null) {
      tls.remove('utls');
    } else {
      tls['utls'] = utls;
    }

    if (reality == null) {
      tls.remove('reality');
    } else {
      tls['reality'] = reality;
    }

    if (alpn == null) {
      tls.remove('alpn');
    } else {
      tls['alpn'] = alpn;
    }

    return tls.isEmpty ? null : tls;
  }

  /// sing-box expects ALPN as a string list. Imports produced by older clients
  /// sometimes serialize it as a comma-separated string; normalize that form
  /// instead of dropping the server-provided HTTP/2 or HTTP/3 negotiation.
  static List<String>? _sanitizeAlpn(dynamic value) {
    final values = switch (value) {
      String text => text.split(','),
      List items => items.map((item) => item.toString()),
      _ => const <String>[],
    };
    final result = <String>[];
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isEmpty || normalized.length > 255) continue;
      if (!result.contains(normalized)) {
        result.add(normalized);
      }
    }
    return result.isEmpty ? null : result;
  }

  static bool _usesQuicTransport(Map<String, dynamic> outbound) {
    final type = _normalizedType(outbound['type']);
    if (type == 'hysteria' || type == 'hysteria2' || type == 'tuic') {
      return true;
    }
    if (type == 'naive' && outbound['quic'] == true) {
      return true;
    }
    final transport = outbound['transport'];
    return transport is Map && _normalizedType(transport['type']) == 'quic';
  }

  static Map<String, dynamic>? _sanitizeTransport(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final transport = Map<String, dynamic>.from(value);
    final type = _normalizedType(transport['type']);
    if (!_knownTransportTypes.contains(type)) {
      return null;
    }
    transport['type'] = type;

    final sanitized = _retainAllowedKeys(transport, switch (type) {
      'http' => _transportKeysHttp,
      'ws' => _transportKeysWs,
      'grpc' => _transportKeysGrpc,
      'httpupgrade' => _transportKeysHttpUpgrade,
      'xhttp' || 'splithttp' => _transportKeysXhttp,
      'kcp' || 'mkcp' => _transportKeysMkcp,
      'quic' => _transportKeysQuic,
      _ => const <String>{'type'},
    });

    final headers = sanitized['headers'];
    if (headers is Map) {
      final sanitizedHeaders = _sanitizeHeaders(headers);
      if (sanitizedHeaders.isEmpty) {
        sanitized.remove('headers');
      } else {
        sanitized['headers'] = sanitizedHeaders;
      }
    }

    if (type == 'xhttp' || type == 'splithttp') {
      final mode = sanitized['mode']?.toString().trim().toLowerCase() ?? '';
      if (mode.isEmpty || !_validXhttpModes.contains(mode)) {
        sanitized.remove('mode');
      } else {
        sanitized['mode'] = mode;
      }

      final xmux = sanitized['xmux'];
      final sanitizedXmux = _sanitizeXhttpXmux(xmux);
      if (sanitizedXmux == null) {
        sanitized.remove('xmux');
      } else {
        sanitized['xmux'] = sanitizedXmux;
      }

      for (final key in const [
        'x_padding_bytes',
        'sc_max_each_post_bytes',
        'sc_min_posts_interval_ms',
        'sc_stream_up_server_secs',
      ]) {
        final range = _sanitizeRangeConfig(sanitized[key]);
        if (range == null) {
          sanitized.remove(key);
        } else {
          sanitized[key] = range;
        }
      }
    }

    if (type == 'kcp' || type == 'mkcp') {
      final header = _sanitizeNestedMap(sanitized['header'], _kcpHeaderKeys);
      if (header == null) {
        sanitized.remove('header');
      } else {
        sanitized['header'] = header;
      }

      final masks = sanitized['masks'];
      if (masks is List) {
        final sanitizedMasks = masks
            .map((mask) => _sanitizeNestedMap(mask, _mkcpMaskKeys))
            .whereType<Map<String, dynamic>>()
            .where((mask) => mask.isNotEmpty)
            .toList(growable: false);
        if (sanitizedMasks.isEmpty) {
          sanitized.remove('masks');
        } else {
          sanitized['masks'] = sanitizedMasks;
        }
      } else {
        sanitized.remove('masks');
      }
    }

    return sanitized.isEmpty ? null : sanitized;
  }

  static Map<String, dynamic>? _sanitizeMultiplex(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final multiplex = _retainAllowedKeys(
      Map<String, dynamic>.from(value),
      _multiplexKeys,
    );
    final brutal = _sanitizeNestedMap(multiplex['brutal'], _brutalKeys);
    if (brutal == null) {
      multiplex.remove('brutal');
    } else {
      multiplex['brutal'] = brutal;
    }
    return multiplex.isEmpty ? null : multiplex;
  }

  static dynamic _sanitizeUdpOverTcp(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is! Map) {
      return null;
    }
    final udpOverTcp = _retainAllowedKeys(
      Map<String, dynamic>.from(value),
      _udpOverTcpKeys,
    );
    return udpOverTcp.isEmpty ? null : udpOverTcp;
  }

  static dynamic _sanitizeDomainResolver(dynamic value) {
    if (value is String) {
      return value.trim().isEmpty ? null : value.trim();
    }
    if (value is! Map) {
      return null;
    }
    final domainResolver = _retainAllowedKeys(
      Map<String, dynamic>.from(value),
      _domainResolverKeys,
    );
    final server = domainResolver['server']?.toString().trim() ?? '';
    if (server.isEmpty) {
      return null;
    }
    domainResolver['server'] = server;
    return domainResolver;
  }

  static dynamic _sanitizeObfs(String type, dynamic value) {
    if (value == null) {
      return null;
    }
    if (type == 'hysteria2') {
      return _sanitizeNestedMap(value, const {'type', 'password'});
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static Map<String, dynamic>? _sanitizeWireGuardPeer(dynamic value) {
    return _sanitizeNestedMap(value, _wireGuardPeerKeys);
  }

  /// Older Etonify builds wrote WireGuard keepalive as a Go-style duration
  /// (`25s`). The stable sing-box endpoint schema accepts an integer number
  /// of seconds, so preserve existing imports by migrating that one form.
  static Map<String, dynamic> _normalizeWireGuardPeer(
    Map<String, dynamic> peer,
  ) {
    final seconds = _wireGuardKeepaliveSeconds(
      peer['persistent_keepalive_interval'],
    );
    if (seconds == null) return peer;
    return {...peer, 'persistent_keepalive_interval': seconds};
  }

  static Map<String, dynamic>? _sanitizeXhttpXmux(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final xmux = _retainAllowedKeys(
      Map<String, dynamic>.from(value),
      _xhttpXmuxKeys,
    );
    for (final key in const [
      'max_concurrency',
      'max_connections',
      'c_max_reuse_times',
      'h_max_request_times',
      'h_max_reusable_secs',
    ]) {
      final range = _sanitizeRangeConfig(xmux[key]);
      if (range == null) {
        xmux.remove(key);
      } else {
        xmux[key] = range;
      }
    }
    return xmux.isEmpty ? null : xmux;
  }

  static Map<String, dynamic>? _sanitizeRangeConfig(dynamic value) {
    return _sanitizeNestedMap(value, _rangeConfigKeys);
  }

  static Map<String, dynamic>? _sanitizeNestedMap(
    dynamic value,
    Set<String> allowedKeys,
  ) {
    if (value is! Map) {
      return null;
    }
    final sanitized = _retainAllowedKeys(
      Map<String, dynamic>.from(value),
      allowedKeys,
    );
    return sanitized.isEmpty ? null : sanitized;
  }

  static Map<String, dynamic> _retainAllowedKeys(
    Map<String, dynamic> source,
    Set<String> allowedKeys,
  ) {
    final sanitized = <String, dynamic>{};
    for (final entry in source.entries) {
      if (allowedKeys.contains(entry.key)) {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  static Map<String, dynamic> _sanitizeHeaders(Map headers) {
    final sanitized = <String, dynamic>{};
    for (final entry in headers.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          sanitized[key] = trimmed;
        }
        continue;
      }

      if (value is List) {
        final items = value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
        if (items.isNotEmpty) {
          sanitized[key] = items;
        }
        continue;
      }

      if (value != null) {
        sanitized[key] = value;
      }
    }
    return sanitized;
  }

  static dynamic _deepNormalizeValue(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is List) {
      final normalized = value
          .map(_deepNormalizeValue)
          .where((item) => item != null)
          .toList(growable: false);
      return normalized.isEmpty ? null : normalized;
    }
    if (value is Map) {
      final normalized = <String, dynamic>{};
      for (final entry in value.entries) {
        final item = _deepNormalizeValue(entry.value);
        if (item != null) {
          normalized[entry.key.toString()] = item;
        }
      }
      return normalized.isEmpty ? null : normalized;
    }
    return value;
  }

  static bool _requiresServer(String type) {
    return type != 'wireguard';
  }

  static int? _intValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static int? _wireGuardKeepaliveSeconds(dynamic value) {
    final direct = _intValue(value);
    if (direct != null) return direct;
    if (value is! String) return null;
    final match = RegExp(
      r'^(\d+)\s*s$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static String _normalizedType(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  static Map<String, dynamic> _snakeCaseMap(Map<String, dynamic> source) {
    final normalized = <String, dynamic>{};
    for (final entry in source.entries) {
      normalized[_camelToSnake(entry.key)] = entry.value;
    }
    return normalized;
  }

  static String _camelToSnake(String value) {
    return value.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  static const Set<String> _knownTransportTypes = {
    'http',
    'ws',
    'grpc',
    'httpupgrade',
    'xhttp',
    'splithttp',
    'kcp',
    'mkcp',
    'quic',
  };
}
