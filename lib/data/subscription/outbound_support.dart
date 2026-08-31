const String wireGuardOutboundType = 'wireguard';
const String wireGuardUnsupportedSinceVersion = '0.3.1';

String outboundTypeOf(Map<String, dynamic> config) =>
    config['type']?.toString().trim().toLowerCase() ?? '';

bool isWireGuardOutboundConfig(Map<String, dynamic> config) =>
    outboundTypeOf(config) == wireGuardOutboundType;

bool isSupportedOutboundConfig(Map<String, dynamic> config) =>
    !isWireGuardOutboundConfig(config);
