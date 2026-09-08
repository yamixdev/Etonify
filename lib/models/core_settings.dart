import 'dart:convert';

enum CoreNetworkStrategy { defaults, hybrid, fallback }

enum CoreNetworkType { defaults, wifi, cellular, ethernet }

enum CoreKeepAlive { defaults, disabled, manual }

enum CoreUdpFragment { defaults, enabled, disabled }

enum CoreNatBehavior {
  defaults,
  endpointIndependent,
  addressDependent,
  addressAndPortDependent;

  String get wireName => switch (this) {
    defaults => '',
    endpointIndependent => 'endpoint_independent',
    addressDependent => 'address_dependent',
    addressAndPortDependent => 'address_and_port_dependent',
  };
}

enum CoreMuxMode { auto, disabled, manual }

enum CoreMuxProtocol { h2mux, smux, yamux }

/// Local, per-outbound override. Auto never probes or guesses server support.
class CoreMuxSettings {
  const CoreMuxSettings({
    this.mode = CoreMuxMode.auto,
    this.protocol = CoreMuxProtocol.h2mux,
    this.maxStreams = 8,
    this.padding = false,
  });

  final CoreMuxMode mode;
  final CoreMuxProtocol protocol;
  final int maxStreams;
  final bool padding;

  Map<String, dynamic> toMap() => {
    'mode': mode.name,
    'protocol': protocol.name,
    'maxStreams': maxStreams,
    'padding': padding,
  };

  factory CoreMuxSettings.fromMap(Map<dynamic, dynamic> map) => CoreMuxSettings(
    mode: _enumValue(CoreMuxMode.values, map['mode']),
    protocol: _enumValue(CoreMuxProtocol.values, map['protocol']),
    maxStreams: _number(map['maxStreams'], 1, 128, 8),
    padding: map['padding'] == true,
  );

  static String key(String profileId, String tag) =>
      jsonEncode([profileId, tag]);

  static bool supports(Map<String, dynamic> outbound) =>
      const {
        'vless',
        'vmess',
        'trojan',
        'shadowsocks',
      }.contains(outbound['type']) &&
      (outbound['flow']?.toString().isEmpty ?? true) &&
      !(outbound['transport'] is Map &&
          const {'xhttp', 'splithttp'}.contains(outbound['transport']['type']));

  Map<String, dynamic> get config => mode == CoreMuxMode.disabled
      ? {'enabled': false}
      : {
          'enabled': true,
          'protocol': protocol.name,
          // One limit policy only: max_streams conflicts with the other two.
          'max_streams': maxStreams,
          'padding': padding,
        };
}

/// Zero durations/limits mean inherit. Default settings do not change a config.
class CoreSettings {
  const CoreSettings({
    this.networkStrategy = CoreNetworkStrategy.defaults,
    this.networkType = CoreNetworkType.defaults,
    this.fallbackNetworkType = CoreNetworkType.defaults,
    this.fallbackDelayMs = 0,
    this.connectTimeoutSeconds = 0,
    this.keepAlive = CoreKeepAlive.defaults,
    this.keepAliveSeconds = 300,
    this.keepAliveIntervalSeconds = 75,
    this.udpFragment = CoreUdpFragment.defaults,
    this.udpMapping = CoreNatBehavior.defaults,
    this.udpFiltering = CoreNatBehavior.defaults,
    this.udpNatMax = 0,
    this.udpTimeoutSeconds = 0,
    this.tlsHandshakeTimeoutSeconds = 0,
    this.multiplex = const {},
  });

  final CoreNetworkStrategy networkStrategy;
  final CoreNetworkType networkType;
  final CoreNetworkType fallbackNetworkType;
  final int fallbackDelayMs;
  final int connectTimeoutSeconds;
  final CoreKeepAlive keepAlive;
  final int keepAliveSeconds;
  final int keepAliveIntervalSeconds;
  final CoreUdpFragment udpFragment;
  final CoreNatBehavior udpMapping;
  final CoreNatBehavior udpFiltering;
  final int udpNatMax;
  final int udpTimeoutSeconds;
  final int tlsHandshakeTimeoutSeconds;
  final Map<String, CoreMuxSettings> multiplex;

  Map<String, dynamic> toMap() => {
    'networkStrategy': networkStrategy.name,
    'networkType': networkType.name,
    'fallbackNetworkType': fallbackNetworkType.name,
    'fallbackDelayMs': fallbackDelayMs,
    'connectTimeoutSeconds': connectTimeoutSeconds,
    'keepAlive': keepAlive.name,
    'keepAliveSeconds': keepAliveSeconds,
    'keepAliveIntervalSeconds': keepAliveIntervalSeconds,
    'udpFragment': udpFragment.name,
    'udpMapping': udpMapping.name,
    'udpFiltering': udpFiltering.name,
    'udpNatMax': udpNatMax,
    'udpTimeoutSeconds': udpTimeoutSeconds,
    'tlsHandshakeTimeoutSeconds': tlsHandshakeTimeoutSeconds,
    'multiplex': {
      for (final key in multiplex.keys.toList()..sort())
        key: multiplex[key]!.toMap(),
    },
  };

  factory CoreSettings.fromMap(Map<dynamic, dynamic> map) => CoreSettings(
    networkStrategy: _enumValue(
      CoreNetworkStrategy.values,
      map['networkStrategy'],
    ),
    networkType: _enumValue(CoreNetworkType.values, map['networkType']),
    fallbackNetworkType: _enumValue(
      CoreNetworkType.values,
      map['fallbackNetworkType'],
    ),
    fallbackDelayMs: _number(map['fallbackDelayMs'], 0, 30000, 0),
    connectTimeoutSeconds: _number(map['connectTimeoutSeconds'], 0, 300, 0),
    keepAlive: _enumValue(CoreKeepAlive.values, map['keepAlive']),
    keepAliveSeconds: _number(map['keepAliveSeconds'], 1, 3600, 300),
    keepAliveIntervalSeconds: _number(
      map['keepAliveIntervalSeconds'],
      1,
      3600,
      75,
    ),
    udpFragment: _enumValue(CoreUdpFragment.values, map['udpFragment']),
    udpMapping: _enumValue(CoreNatBehavior.values, map['udpMapping']),
    udpFiltering: _enumValue(CoreNatBehavior.values, map['udpFiltering']),
    udpNatMax: _number(map['udpNatMax'], 0, 65536, 0),
    udpTimeoutSeconds: _number(map['udpTimeoutSeconds'], 0, 3600, 0),
    tlsHandshakeTimeoutSeconds: _number(
      map['tlsHandshakeTimeoutSeconds'],
      0,
      300,
      0,
    ),
    multiplex: Map.unmodifiable({
      if (map['multiplex'] is Map)
        for (final entry in (map['multiplex'] as Map).entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: CoreMuxSettings.fromMap(entry.value as Map),
    }),
  );

  static CoreSettings decode(Object? value) {
    if (value is! String) return const CoreSettings();
    try {
      final decoded = jsonDecode(value);
      return decoded is Map
          ? CoreSettings.fromMap(decoded)
          : const CoreSettings();
    } on FormatException {
      return const CoreSettings();
    }
  }

  CoreSettings withValue(String key, Object value) =>
      CoreSettings.fromMap({...toMap(), key: value});

  CoreSettings withMux(String profileId, String tag, CoreMuxSettings value) {
    final values = Map<String, dynamic>.from(toMap()['multiplex'] as Map);
    final key = CoreMuxSettings.key(profileId, tag);
    if (value.mode == CoreMuxMode.auto) {
      values.remove(key);
    } else {
      values[key] = value.toMap();
    }
    return withValue('multiplex', values);
  }

  @override
  bool operator ==(Object other) =>
      other is CoreSettings && jsonEncode(toMap()) == jsonEncode(other.toMap());
  @override
  int get hashCode => jsonEncode(toMap()).hashCode;
}

T _enumValue<T extends Enum>(List<T> values, Object? value) => values
    .firstWhere((entry) => entry.name == value, orElse: () => values.first);

int _number(Object? value, int min, int max, int fallback) =>
    value is int && value >= min && value <= max ? value : fallback;
