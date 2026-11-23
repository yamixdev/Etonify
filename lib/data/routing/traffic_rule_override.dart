import 'dart:io';

enum TrafficRuleMatchType { domain, domainSuffix, ipCidr }

enum TrafficRuleAction { direct, vpn }

class TrafficRuleOverride {
  const TrafficRuleOverride._(this.matchType, this.value, this.action);

  final TrafficRuleMatchType matchType;
  final String value;
  final TrafficRuleAction action;

  static final _domainLabel = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
  static final _ipLiteral = RegExp(r'^[a-fA-F0-9:.]+$');
  static final _prefixLength = RegExp(r'^\d{1,3}$');

  static TrafficRuleOverride? tryParse({
    required TrafficRuleMatchType matchType,
    required String value,
    required TrafficRuleAction action,
  }) {
    final normalized = switch (matchType) {
      TrafficRuleMatchType.domain => _normalizeDomain(value),
      TrafficRuleMatchType.domainSuffix => _normalizeDomain(
        value,
        suffix: true,
      ),
      TrafficRuleMatchType.ipCidr => _normalizeCidr(value),
    };
    return normalized == null
        ? null
        : TrafficRuleOverride._(matchType, normalized, action);
  }

  static TrafficRuleOverride? tryFromJson(Object? json) {
    if (json case {
      'matchType': String type,
      'value': String value,
      'action': String action,
    }) {
      final matchType = switch (type) {
        'domain' => TrafficRuleMatchType.domain,
        'domainSuffix' => TrafficRuleMatchType.domainSuffix,
        'ipCidr' => TrafficRuleMatchType.ipCidr,
        _ => null,
      };
      final route = switch (action) {
        'direct' => TrafficRuleAction.direct,
        'vpn' => TrafficRuleAction.vpn,
        _ => null,
      };
      if (matchType != null && route != null) {
        return tryParse(matchType: matchType, value: value, action: route);
      }
    }
    return null;
  }

  Map<String, String> toJson() => {
    'matchType': matchType.name,
    'value': value,
    'action': action.name,
  };

  static String? _normalizeDomain(String value, {bool suffix = false}) {
    var domain = value.trim().toLowerCase();
    if (suffix && domain.startsWith('*.')) {
      domain = domain.substring(2);
    } else if (suffix && domain.startsWith('.')) {
      domain = domain.substring(1);
    }
    if (domain.endsWith('.')) domain = domain.substring(0, domain.length - 1);
    if (domain.length > 253 ||
        !domain.split('.').every(_domainLabel.hasMatch) ||
        InternetAddress.tryParse(domain) != null) {
      return null;
    }
    return domain;
  }

  static String? _normalizeCidr(String value) {
    final parts = value.trim().split('/');
    if (parts.length > 2 || !_ipLiteral.hasMatch(parts.first)) return null;
    final address = InternetAddress.tryParse(parts.first);
    if (address == null) return null;
    final bytes = address.rawAddress;
    final addressBits = bytes.length * 8;
    var prefixLength = addressBits;
    if (parts.length == 2) {
      if (!_prefixLength.hasMatch(parts.last)) return null;
      prefixLength = int.parse(parts.last);
      if (prefixLength > addressBits) return null;
    }
    for (var index = prefixLength ~/ 8; index < bytes.length; index++) {
      final bitsToKeep = prefixLength - index * 8;
      bytes[index] = bitsToKeep > 0
          ? bytes[index] & (0xff << (8 - bitsToKeep))
          : 0;
    }
    final network = InternetAddress.fromRawAddress(bytes, type: address.type);
    return '${network.address}/$prefixLength';
  }

  @override
  bool operator ==(Object other) =>
      other is TrafficRuleOverride &&
      other.matchType == matchType &&
      other.value == value &&
      other.action == action;

  @override
  int get hashCode => Object.hash(matchType, value, action);
}
