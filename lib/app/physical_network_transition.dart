/// An Android Network survives the probe-to-VPN runtime switch. Its handle
/// distinguishes a real reconnection even when both networks use `wlan0`.
String physicalNetworkKey({
  required int networkHandle,
  required String interfaceName,
  required int interfaceIndex,
}) {
  if (interfaceName.isEmpty || interfaceIndex <= 0) return '';
  return '${networkHandle > 0 ? networkHandle : 'unknown'}:$interfaceName:$interfaceIndex';
}

bool physicalNetworkChanged(String previousKey, String nextKey) =>
    previousKey.isNotEmpty && previousKey != nextKey;
