/// Parses WireGuard `.conf` files into a sing-box WireGuard endpoint.
///
/// Example input:
/// ```ini
/// [Interface]
/// PrivateKey = abcdef…
/// Address = 10.0.0.2/32, fd00::2/128
/// DNS = 1.1.1.1
/// MTU = 1280
///
/// [Peer]
/// PublicKey = ghijkl…
/// PresharedKey = mnopqr…
/// AllowedIPs = 0.0.0.0/0, ::/0
/// Endpoint = server.example.com:51820
/// PersistentKeepalive = 25
/// ```
class WireGuardConfigParser {
  WireGuardConfigParser._();

  /// Returns `true` if [content] looks like a WireGuard .conf file.
  static bool canParse(String content) {
    return RegExp(
          r'^\s*\[\s*Interface\s*\]\s*$',
          caseSensitive: false,
          multiLine: true,
        ).hasMatch(content) &&
        RegExp(
          r'^\s*\[\s*Peer\s*\]\s*$',
          caseSensitive: false,
          multiLine: true,
        ).hasMatch(content);
  }

  /// Parses a WireGuard config into a single sing-box outbound map.
  /// Returns a list with 0 or 1 element.
  static List<Map<String, dynamic>> parse(String content) {
    final sections = _parseSections(content);
    final iface = _firstSection(sections, 'interface');
    if (iface == null) return [];

    final result = <String, dynamic>{'type': 'wireguard', 'tag': ''};

    // Interface → private_key, address, mtu
    final privateKey = iface.values['PrivateKey'] ?? '';
    if (privateKey.isNotEmpty) result['private_key'] = privateKey;

    final address = iface.values['Address'] ?? '';
    if (address.isNotEmpty) {
      result['address'] = address
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final mtu = int.tryParse(iface.values['MTU'] ?? '');
    if (mtu != null && mtu > 0) result['mtu'] = mtu;

    // Peers
    final peers = <Map<String, dynamic>>[];
    for (final section in sections) {
      if (section.name.toLowerCase() != 'peer') continue;
      final p = section.values;
      final peer = <String, dynamic>{};

      // Endpoint → address + port
      final endpoint = p['Endpoint'] ?? '';
      if (endpoint.isNotEmpty) {
        _parseEndpoint(endpoint, (host, port) {
          peer['address'] = host;
          peer['port'] = port;
        });
      }

      final publicKey = p['PublicKey'] ?? '';
      if (publicKey.isNotEmpty) peer['public_key'] = publicKey;

      final psk = p['PresharedKey'] ?? '';
      if (psk.isNotEmpty) peer['pre_shared_key'] = psk;

      final allowedIPs = p['AllowedIPs'] ?? '';
      if (allowedIPs.isNotEmpty) {
        peer['allowed_ips'] = allowedIPs
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        peer['allowed_ips'] = ['0.0.0.0/0', '::/0'];
      }

      final keepalive = int.tryParse(p['PersistentKeepalive'] ?? '');
      if (keepalive != null && keepalive >= 0 && keepalive <= 65535) {
        // sing-box expects an integer number of seconds, not a Go duration.
        peer['persistent_keepalive_interval'] = keepalive;
      }

      peers.add(peer);
    }

    if (peers.isEmpty) return [];
    result['peers'] = peers;

    // Build name from first peer endpoint
    final firstPeer = peers.first;
    final addr = firstPeer['address'] ?? 'WireGuard';
    final port = firstPeer['port'] ?? '';
    result['_name'] = port != '' ? '$addr:$port' : addr.toString();

    return [result];
  }

  // ─────────────────── INI parser ───────────────────

  /// Parses INI-style sections without merging repeated [Peer] blocks.
  static List<_WireGuardIniSection> _parseSections(String content) {
    final result = <_WireGuardIniSection>[];
    _WireGuardIniSection? currentSection;

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('#') ||
          trimmed.startsWith(';')) {
        continue;
      }

      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        currentSection = _WireGuardIniSection(
          trimmed.substring(1, trimmed.length - 1).trim(),
        );
        result.add(currentSection);
        continue;
      }

      if (currentSection != null) {
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx > 0) {
          final key = trimmed.substring(0, eqIdx).trim();
          final value = trimmed.substring(eqIdx + 1).trim();
          currentSection.values[key] = value;
        }
      }
    }
    return result;
  }

  static _WireGuardIniSection? _firstSection(
    List<_WireGuardIniSection> sections,
    String name,
  ) {
    for (final section in sections) {
      if (section.name.toLowerCase() == name) return section;
    }
    return null;
  }

  static void _parseEndpoint(
    String endpoint,
    void Function(String host, int port) cb,
  ) {
    if (endpoint.startsWith('[')) {
      // IPv6: [host]:port
      final closeBracket = endpoint.indexOf(']');
      if (closeBracket < 0) return;
      final host = endpoint.substring(1, closeBracket);
      final rest = endpoint.substring(closeBracket + 1);
      if (rest.startsWith(':')) {
        final port = int.tryParse(rest.substring(1));
        if (port != null) cb(host, port);
      }
    } else {
      final colonIdx = endpoint.lastIndexOf(':');
      if (colonIdx < 0) return;
      final host = endpoint.substring(0, colonIdx);
      final port = int.tryParse(endpoint.substring(colonIdx + 1));
      if (port != null) cb(host, port);
    }
  }
}

class _WireGuardIniSection {
  _WireGuardIniSection(this.name);

  final String name;
  final Map<String, String> values = <String, String>{};
}
