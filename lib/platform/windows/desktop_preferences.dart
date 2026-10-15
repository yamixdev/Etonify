enum ProcessRoutingMode { allExceptSelected, onlySelected }

enum ProxyListStyle { compact, comfortable }

/// Desired Windows modes, independent from Android VPN settings.
class DesktopModePreferences {
  const DesktopModePreferences({
    this.tunEnabled = false,
    this.systemProxyEnabled = false,
    this.launchAtLogin = false,
    this.launchMinimized = true,
    this.connectOnLaunch = false,
    this.processRoutingMode = ProcessRoutingMode.allExceptSelected,
    this.processPaths = const [],
    this.unknown = const {},
  });

  static const defaults = DesktopModePreferences();
  static const _keys = {
    'tunEnabled',
    'systemProxyEnabled',
    'launchAtLogin',
    'launchMinimized',
    'connectOnLaunch',
    'processRoutingMode',
    'processPaths',
  };
  final bool tunEnabled;
  final bool systemProxyEnabled;
  final bool launchAtLogin;
  final bool launchMinimized;
  final bool connectOnLaunch;
  final ProcessRoutingMode processRoutingMode;
  final List<String> processPaths;
  final Map<String, Object?> unknown;

  factory DesktopModePreferences.fromMap(Map<String, Object?> map) =>
      DesktopModePreferences(
        tunEnabled: _bool(map, 'tunEnabled', false),
        systemProxyEnabled: _bool(map, 'systemProxyEnabled', false),
        launchAtLogin: _bool(map, 'launchAtLogin', false),
        launchMinimized: _bool(map, 'launchMinimized', true),
        connectOnLaunch: _bool(map, 'connectOnLaunch', false),
        processRoutingMode: map['processRoutingMode'] == 'onlySelected'
            ? ProcessRoutingMode.onlySelected
            : ProcessRoutingMode.allExceptSelected,
        processPaths: List<String>.unmodifiable(
          map['processPaths'] is List
              ? (map['processPaths'] as List).whereType<String>()
              : <String>[],
        ),
        unknown: Map<String, Object?>.unmodifiable({
          for (final entry in map.entries)
            if (!_keys.contains(entry.key)) entry.key: entry.value,
        }),
      );

  Map<String, Object?> toMap() => {
    ...unknown,
    'tunEnabled': tunEnabled,
    'systemProxyEnabled': systemProxyEnabled,
    'launchAtLogin': launchAtLogin,
    'launchMinimized': launchMinimized,
    'connectOnLaunch': connectOnLaunch,
    'processRoutingMode': processRoutingMode.name,
    'processPaths': List<String>.of(processPaths),
  };

  DesktopModePreferences copyWith({
    bool? tunEnabled,
    bool? systemProxyEnabled,
    bool? launchAtLogin,
    bool? launchMinimized,
    bool? connectOnLaunch,
    ProcessRoutingMode? processRoutingMode,
    List<String>? processPaths,
  }) => DesktopModePreferences.fromMap({
    ...toMap(),
    'tunEnabled': tunEnabled ?? this.tunEnabled,
    'systemProxyEnabled': systemProxyEnabled ?? this.systemProxyEnabled,
    'launchAtLogin': launchAtLogin ?? this.launchAtLogin,
    'launchMinimized': launchMinimized ?? this.launchMinimized,
    'connectOnLaunch': connectOnLaunch ?? this.connectOnLaunch,
    'processRoutingMode': (processRoutingMode ?? this.processRoutingMode).name,
    'processPaths': processPaths ?? this.processPaths,
  });
}

class DesktopPresentationPreferences {
  const DesktopPresentationPreferences({
    this.proxyListStyle = ProxyListStyle.compact,
    this.unknown = const {},
  });
  static const defaults = DesktopPresentationPreferences();
  final ProxyListStyle proxyListStyle;
  final Map<String, Object?> unknown;

  factory DesktopPresentationPreferences.fromMap(Map<String, Object?> map) =>
      DesktopPresentationPreferences(
        proxyListStyle: map['proxyListStyle'] == 'comfortable'
            ? ProxyListStyle.comfortable
            : ProxyListStyle.compact,
        unknown: Map<String, Object?>.unmodifiable({
          for (final entry in map.entries)
            if (entry.key != 'proxyListStyle') entry.key: entry.value,
        }),
      );
  Map<String, Object?> toMap() => {
    ...unknown,
    'proxyListStyle': proxyListStyle.name,
  };
  DesktopPresentationPreferences copyWith({ProxyListStyle? proxyListStyle}) =>
      DesktopPresentationPreferences.fromMap({
        ...toMap(),
        'proxyListStyle': (proxyListStyle ?? this.proxyListStyle).name,
      });
}

bool _bool(Map<String, Object?> map, String key, bool fallback) =>
    map[key] is bool ? map[key] as bool : fallback;
