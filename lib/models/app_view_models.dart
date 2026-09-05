import 'package:flutter/foundation.dart';

@immutable
class TrafficUiSnapshot {
  const TrafficUiSnapshot({
    required this.speedBytesPerSecond,
    required this.trafficBytes,
  });

  static const zero = TrafficUiSnapshot(
    speedBytesPerSecond: 0,
    trafficBytes: 0,
  );

  final double speedBytesPerSecond;
  final double trafficBytes;

  @override
  bool operator ==(Object other) {
    return other is TrafficUiSnapshot &&
        other.speedBytesPerSecond == speedBytesPerSecond &&
        other.trafficBytes == trafficBytes;
  }

  @override
  int get hashCode => Object.hash(speedBytesPerSecond, trafficBytes);
}

class AppProfileSummary {
  const AppProfileSummary({
    required this.id,
    required this.name,
    required this.consumed,
    required this.total,
    required this.remainingDays,
    required this.outboundsCount,
    required this.sourceLabel,
  });

  final String id;
  final String name;
  final double consumed;
  final double total;
  final int? remainingDays;
  final int outboundsCount;
  final String sourceLabel;

  bool get hasUsage => total > 0;

  double get ratio => total <= 0 ? 0 : (consumed / total).clamp(0, 1);

  @override
  bool operator ==(Object other) {
    return other is AppProfileSummary &&
        other.id == id &&
        other.name == name &&
        other.consumed == consumed &&
        other.total == total &&
        other.remainingDays == remainingDays &&
        other.outboundsCount == outboundsCount &&
        other.sourceLabel == sourceLabel;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    consumed,
    total,
    remainingDays,
    outboundsCount,
    sourceLabel,
  );
}

class AppProxySummary {
  const AppProxySummary({
    required this.tag,
    required this.displayName,
    required this.countryCode,
    required this.type,
    required this.server,
    required this.port,
    required this.detailText,
    required this.ip,
    this.ipChecking = false,
    required this.latency,
    required this.latencyFresh,
    required this.latencyChecking,
    required this.latencyUnavailable,
    required this.latencyError,
    required this.protocolLabel,
    required this.endpointLabel,
    this.isGroup = false,
    this.membersSelectable = true,
    this.parentGroupTag,
    this.childTags = const [],
    this.childCount = 0,
    this.selectedChildTag,
    this.selectedChildName,
    this.highlighted = false,
  });

  final String tag;
  final String displayName;
  final String countryCode;
  final String type;
  final String server;
  final int port;
  final String detailText;
  final String ip;
  final bool ipChecking;
  final int? latency;
  final bool latencyFresh;
  final bool latencyChecking;
  final bool latencyUnavailable;
  final String? latencyError;
  final String protocolLabel;
  final String endpointLabel;
  final bool isGroup;
  final bool membersSelectable;
  final String? parentGroupTag;
  final List<String> childTags;
  final int childCount;
  final String? selectedChildTag;
  final String? selectedChildName;
  final bool highlighted;

  bool get isGroupChild => parentGroupTag != null && parentGroupTag!.isNotEmpty;

  AppProxySummary copyWith({
    String? tag,
    String? displayName,
    String? countryCode,
    String? type,
    String? server,
    int? port,
    String? detailText,
    String? ip,
    bool? ipChecking,
    int? latency,
    bool clearLatency = false,
    bool? latencyFresh,
    bool? latencyChecking,
    bool? latencyUnavailable,
    String? latencyError,
    bool clearLatencyError = false,
    String? protocolLabel,
    String? endpointLabel,
    bool? isGroup,
    bool? membersSelectable,
    String? parentGroupTag,
    bool clearParentGroupTag = false,
    List<String>? childTags,
    int? childCount,
    String? selectedChildTag,
    bool clearSelectedChildTag = false,
    String? selectedChildName,
    bool clearSelectedChildName = false,
    bool? highlighted,
  }) {
    return AppProxySummary(
      tag: tag ?? this.tag,
      displayName: displayName ?? this.displayName,
      countryCode: countryCode ?? this.countryCode,
      type: type ?? this.type,
      server: server ?? this.server,
      port: port ?? this.port,
      detailText: detailText ?? this.detailText,
      ip: ip ?? this.ip,
      ipChecking: ipChecking ?? this.ipChecking,
      latency: clearLatency ? null : latency ?? this.latency,
      latencyFresh: latencyFresh ?? this.latencyFresh,
      latencyChecking: latencyChecking ?? this.latencyChecking,
      latencyUnavailable: latencyUnavailable ?? this.latencyUnavailable,
      latencyError: clearLatencyError
          ? null
          : latencyError ?? this.latencyError,
      protocolLabel: protocolLabel ?? this.protocolLabel,
      endpointLabel: endpointLabel ?? this.endpointLabel,
      isGroup: isGroup ?? this.isGroup,
      membersSelectable: membersSelectable ?? this.membersSelectable,
      parentGroupTag: clearParentGroupTag
          ? null
          : parentGroupTag ?? this.parentGroupTag,
      childTags: childTags ?? this.childTags,
      childCount: childCount ?? this.childCount,
      selectedChildTag: clearSelectedChildTag
          ? null
          : selectedChildTag ?? this.selectedChildTag,
      selectedChildName: clearSelectedChildName
          ? null
          : selectedChildName ?? this.selectedChildName,
      highlighted: highlighted ?? this.highlighted,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppProxySummary &&
        other.tag == tag &&
        other.displayName == displayName &&
        other.countryCode == countryCode &&
        other.type == type &&
        other.server == server &&
        other.port == port &&
        other.detailText == detailText &&
        other.ip == ip &&
        other.ipChecking == ipChecking &&
        other.latency == latency &&
        other.latencyFresh == latencyFresh &&
        other.latencyChecking == latencyChecking &&
        other.latencyUnavailable == latencyUnavailable &&
        other.latencyError == latencyError &&
        other.protocolLabel == protocolLabel &&
        other.endpointLabel == endpointLabel &&
        other.isGroup == isGroup &&
        other.membersSelectable == membersSelectable &&
        other.parentGroupTag == parentGroupTag &&
        listEquals(other.childTags, childTags) &&
        other.childCount == childCount &&
        other.selectedChildTag == selectedChildTag &&
        other.selectedChildName == selectedChildName &&
        other.highlighted == highlighted;
  }

  @override
  int get hashCode => Object.hashAll([
    tag,
    displayName,
    countryCode,
    type,
    server,
    port,
    detailText,
    ip,
    ipChecking,
    latency,
    latencyFresh,
    latencyChecking,
    latencyUnavailable,
    latencyError,
    protocolLabel,
    endpointLabel,
    isGroup,
    membersSelectable,
    parentGroupTag,
    Object.hashAll(childTags),
    childCount,
    selectedChildTag,
    selectedChildName,
    highlighted,
  ]);
}

enum ProxySort { source, latency, working, name, country }

class TrafficSample {
  const TrafficSample({
    required this.timestamp,
    required this.downlinkBps,
    required this.uplinkBps,
    required this.totalBytes,
  });

  final DateTime timestamp;
  final int downlinkBps;
  final int uplinkBps;
  final int totalBytes;

  @override
  bool operator ==(Object other) {
    return other is TrafficSample &&
        other.timestamp == timestamp &&
        other.downlinkBps == downlinkBps &&
        other.uplinkBps == uplinkBps &&
        other.totalBytes == totalBytes;
  }

  @override
  int get hashCode =>
      Object.hash(timestamp, downlinkBps, uplinkBps, totalBytes);
}

class TrafficDashboardSnapshot {
  const TrafficDashboardSnapshot({
    required this.connected,
    required this.connecting,
    required this.trafficAvailable,
    required this.hideServerIp,
    required this.downlinkBps,
    required this.uplinkBps,
    required this.uplinkTotalBytes,
    required this.downlinkTotalBytes,
    required this.connectedSince,
    required this.activeProfile,
    required this.activeProxy,
    required this.samples,
  });

  static const empty = TrafficDashboardSnapshot(
    connected: false,
    connecting: false,
    trafficAvailable: false,
    hideServerIp: false,
    downlinkBps: 0,
    uplinkBps: 0,
    uplinkTotalBytes: 0,
    downlinkTotalBytes: 0,
    connectedSince: null,
    activeProfile: null,
    activeProxy: null,
    samples: <TrafficSample>[],
  );

  final bool connected;
  final bool connecting;
  final bool trafficAvailable;
  final bool hideServerIp;
  final int downlinkBps;
  final int uplinkBps;
  final int uplinkTotalBytes;
  final int downlinkTotalBytes;
  final DateTime? connectedSince;
  final AppProfileSummary? activeProfile;
  final AppProxySummary? activeProxy;
  final List<TrafficSample> samples;

  int get totalBytes => uplinkTotalBytes + downlinkTotalBytes;

  @override
  bool operator ==(Object other) {
    return other is TrafficDashboardSnapshot &&
        other.connected == connected &&
        other.connecting == connecting &&
        other.trafficAvailable == trafficAvailable &&
        other.hideServerIp == hideServerIp &&
        other.downlinkBps == downlinkBps &&
        other.uplinkBps == uplinkBps &&
        other.uplinkTotalBytes == uplinkTotalBytes &&
        other.downlinkTotalBytes == downlinkTotalBytes &&
        other.connectedSince == connectedSince &&
        other.activeProfile == activeProfile &&
        other.activeProxy == activeProxy &&
        listEquals(other.samples, samples);
  }

  @override
  int get hashCode => Object.hashAll([
    connected,
    connecting,
    trafficAvailable,
    hideServerIp,
    downlinkBps,
    uplinkBps,
    uplinkTotalBytes,
    downlinkTotalBytes,
    connectedSince,
    activeProfile,
    activeProxy,
    Object.hashAll(samples),
  ]);
}
