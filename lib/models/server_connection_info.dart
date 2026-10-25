import 'package:flutter/foundation.dart';

@immutable
class ServerConnectionInfo {
  const ServerConnectionInfo({
    this.key = '',
    this.outboundTag = '',
    this.selectedProxyTag = '',
    this.presentedChildTag = '',
    this.presentedEndpoint = '',
    this.connected = false,
    this.name = '',
    this.countryCode = '',
    this.exitIp = '',
    this.ipChecking = false,
    this.endpointHost = '',
    this.endpointPort = 0,
    this.protocol = '',
    this.transport = '',
    this.security = '',
  });

  final String key;
  final String outboundTag;
  final String selectedProxyTag;
  final String presentedChildTag;
  final String presentedEndpoint;
  final bool connected;
  final String name;
  final String countryCode;
  final String exitIp;
  final bool ipChecking;
  final String endpointHost;
  final int endpointPort;
  final String protocol;
  final String transport;
  final String security;

  @override
  bool operator ==(Object other) =>
      other is ServerConnectionInfo &&
      other.key == key &&
      other.outboundTag == outboundTag &&
      other.selectedProxyTag == selectedProxyTag &&
      other.presentedChildTag == presentedChildTag &&
      other.presentedEndpoint == presentedEndpoint &&
      other.connected == connected &&
      other.name == name &&
      other.countryCode == countryCode &&
      other.exitIp == exitIp &&
      other.ipChecking == ipChecking &&
      other.endpointHost == endpointHost &&
      other.endpointPort == endpointPort &&
      other.protocol == protocol &&
      other.transport == transport &&
      other.security == security;

  @override
  int get hashCode => Object.hash(
    key,
    outboundTag,
    selectedProxyTag,
    presentedChildTag,
    presentedEndpoint,
    connected,
    name,
    countryCode,
    exitIp,
    ipChecking,
    endpointHost,
    endpointPort,
    protocol,
    transport,
    security,
  );
}

String networkAddressText(String address, {required bool hidden}) {
  if (!hidden || address.isEmpty) return address;
  final parts = address.split('.');
  if (parts.length == 4 && parts.every((part) => int.tryParse(part) != null)) {
    return '${parts[0]}.${parts[1]}.*.*';
  }
  return '••••';
}
