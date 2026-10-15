import 'dart:convert';
import 'desktop_contract.dart';
import 'desktop_preferences.dart';
import 'windows_process_rules.dart';

class WindowsConfigPolicy {
  static Map<String, Object?> apply(
    Map<String, Object?> config,
    DesktopModePreferences modes,
  ) {
    // Runtime receives a detached policy copy, never mutating cached/shared data.
    final result = objectMap(jsonDecode(jsonEncode(config)));
    final inbounds = (result['inbounds'] as List? ?? [])
        .map(objectMap)
        .toList();
    final tun = inbounds.where((v) => v['type'] == 'tun').firstOrNull;
    final mixed = inbounds.where((v) => v['type'] == 'mixed').firstOrNull;
    result['inbounds'] = [
      if (modes.tunEnabled)
        {
          ...?tun,
          'type': 'tun',
          'tag': 'tun-in',
          if (tun?['address'] == null) 'address': ['172.19.0.1/30'],
          'auto_route': true,
          if (tun?['mtu'] == null) 'mtu': 1500,
        },
      {
        ...?mixed,
        'type': 'mixed',
        'tag': 'mixed-in',
        'listen': '127.0.0.1',
        'listen_port': mixed?['listen_port'] ?? 1080,
        'set_system_proxy': false,
      },
    ];
    for (final inbound
        in (result['inbounds'] as List).cast<Map<String, Object?>>()) {
      inbound.remove('include_package');
      inbound.remove('exclude_package');
    }
    final route = objectMap(result['route'] ?? <String, Object?>{});
    final rules = (route['rules'] as List? ?? []).map(objectMap).toList();
    final processRules = WindowsProcessRules.build(modes);
    // Concrete DNS, sniff, leak protection and local bypass retain precedence.
    // Exact process policy then outranks domain/IP presets, including catch-all.
    var index = 0;
    while (index < rules.length && _isInfrastructure(rules[index])) {
      index++;
    }
    rules.insertAll(index, processRules);
    route['rules'] = rules;
    route['auto_detect_interface'] = true;
    result['route'] = route;
    return result;
  }

  static bool _isInfrastructure(Map<String, Object?> rule) {
    if (rule.length == 1 && rule['action'] == 'sniff') return true;
    if (rule.length == 2 &&
        rule['ip_is_private'] == true &&
        rule['outbound'] == 'direct') {
      return true;
    }
    if (rule['action'] == 'reject') {
      return (rule.length == 2 && rule['protocol'] == 'stun') ||
          (rule.length == 5 &&
              rule['inbound'] == 'tun-in' &&
              rule['network'] == 'icmp' &&
              rule['ip_cidr'] == '172.19.0.2/32' &&
              rule['method'] == 'drop');
    }
    if (rule['action'] != 'hijack-dns') return false;
    if (rule.length == 2 && (rule['protocol'] == 'dns' || rule['port'] == 53)) {
      return true;
    }
    final conditions = rule['rules'];
    return rule.length == 4 &&
        rule['type'] == 'logical' &&
        rule['mode'] == 'or' &&
        conditions is List &&
        conditions.isNotEmpty &&
        conditions.every(
          (condition) =>
              condition is Map &&
              condition.length == 1 &&
              (condition['protocol'] == 'dns' || condition['port'] == 53),
        );
  }
}
