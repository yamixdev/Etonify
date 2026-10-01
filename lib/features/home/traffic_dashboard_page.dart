import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/formatting.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';

/// The sheet itself is static. Each section listens only to its displayed data,
/// so traffic samples never rebuild the heading or connection information.
class TrafficDashboardPage extends StatelessWidget {
  const TrafficDashboardPage({
    super.key,
    required this.snapshotListenable,
    this.scrollController,
  });

  final ValueListenable<TrafficDashboardSnapshot> snapshotListenable;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            key: const ValueKey('traffic-dashboard'),
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              math.max(16, (constraints.maxWidth - 720) / 2),
              8,
              math.max(16, (constraints.maxWidth - 720) / 2),
              24,
            ),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: .32,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Gap(16),
              Text(
                l10n.trafficDashboardTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(16),
              _SnapshotSection(
                listenable: snapshotListenable,
                select: (s) => (
                  available: s.connected && s.trafficAvailable,
                  download: s.downlinkBps,
                  upload: s.uplinkBps,
                  samples: s.samples,
                ),
                builder: (context, data) => _SpeedCard(
                  available: data.available,
                  download: data.download,
                  upload: data.upload,
                  samples: data.available ? data.samples : const [],
                ),
              ),
              const Gap(12),
              _SnapshotSection(
                listenable: snapshotListenable,
                select: (s) => (
                  available: s.connected && s.trafficAvailable,
                  download: s.downlinkTotalBytes,
                  upload: s.uplinkTotalBytes,
                  seconds: s.connected && s.connectedSince != null
                      ? math.max(
                          0,
                          DateTime.now()
                              .difference(s.connectedSince!)
                              .inSeconds,
                        )
                      : null,
                ),
                builder: (context, data) => _SessionCard(
                  available: data.available,
                  download: data.download,
                  upload: data.upload,
                  seconds: data.seconds,
                ),
              ),
              const Gap(12),
              _SnapshotSection(
                listenable: snapshotListenable,
                select: (s) => (
                  connected: s.connected,
                  connecting: s.connecting,
                  profile: s.activeProfile?.name,
                  proxy: s.activeProxy?.displayName,
                  country: s.activeProxy?.countryCode,
                  ip: s.activeProxy?.ip.trim() ?? '',
                  hideIp: s.hideServerIp,
                ),
                builder: (context, data) => _ConnectionCard(
                  connected: data.connected,
                  connecting: data.connecting,
                  profile: data.profile,
                  proxy: data.proxy,
                  country: data.country,
                  ip: data.ip,
                  hideIp: data.hideIp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapshotSection<T> extends StatefulWidget {
  const _SnapshotSection({
    required this.listenable,
    required this.select,
    required this.builder,
  });

  final ValueListenable<TrafficDashboardSnapshot> listenable;
  final T Function(TrafficDashboardSnapshot) select;
  final Widget Function(BuildContext, T) builder;

  @override
  State<_SnapshotSection<T>> createState() => _SnapshotSectionState<T>();
}

class _SnapshotSectionState<T> extends State<_SnapshotSection<T>> {
  late T _data;

  @override
  void initState() {
    super.initState();
    _data = widget.select(widget.listenable.value);
    widget.listenable.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _SnapshotSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_changed);
      widget.listenable.addListener(_changed);
    }
    _data = widget.select(widget.listenable.value);
  }

  void _changed() {
    final next = widget.select(widget.listenable.value);
    if (_data != next) setState(() => _data = next);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _data);
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const Gap(8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({
    required this.available,
    required this.download,
    required this.upload,
    required this.samples,
  });

  final bool available;
  final int download;
  final int upload;
  final List<TrafficSample> samples;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final visible = _recentSamples(samples);
    var peak = 0;
    for (final sample in visible) {
      peak = math.max(peak, math.max(sample.downlinkBps, sample.uplinkBps));
    }
    return _DashboardCard(
      children: [
        _SectionTitle(
          icon: Icons.speed_rounded,
          label: l10n.trafficDashboardGraphTitle,
        ),
        const Gap(12),
        _AdaptivePair(
          first: _Metric(
            icon: Icons.arrow_downward_rounded,
            label: l10n.trafficDashboardDownload,
            value: available
                ? formatSpeed(download.toDouble())
                : l10n.notAvailableShort,
            color: theme.colorScheme.primary,
          ),
          second: _Metric(
            icon: Icons.arrow_upward_rounded,
            label: l10n.trafficDashboardUpload,
            value: available
                ? formatSpeed(upload.toDouble())
                : l10n.notAvailableShort,
            color: theme.colorScheme.tertiary,
          ),
        ),
        const Gap(12),
        if (visible.length < 2)
          SizedBox(
            height: 112,
            child: Center(
              child: Text(
                l10n.trafficDashboardNoSamples,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          _TrafficGraph(
            samples: visible,
            maxBps: _roundedGraphScale(math.max(1, peak)),
          ),
        if (available && visible.length >= 2) ...[
          const Gap(8),
          Text(
            l10n.trafficDashboardGraphMax(formatSpeed(peak.toDouble())),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Two columns while both metrics fit, stacked for narrow/large-text layouts.
class _AdaptivePair extends StatelessWidget {
  const _AdaptivePair({required this.first, required this.second});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      if (constraints.maxWidth < 260 * textScale) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const Gap(12), second],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const Gap(16),
          Expanded(child: second),
        ],
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: color),
        ),
        const Gap(8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(2),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.available,
    required this.download,
    required this.upload,
    required this.seconds,
  });
  final bool available;
  final int download;
  final int upload;
  final int? seconds;

  String _uptime(AppLocalizations l10n) {
    final value = seconds;
    if (value == null) return l10n.notAvailableShort;
    if (value >= 3600) {
      return l10n.trafficDashboardUptimeHours(value ~/ 3600, value ~/ 60 % 60);
    }
    if (value >= 60) {
      return l10n.trafficDashboardUptimeMinutes(value ~/ 60, value % 60);
    }
    return l10n.trafficDashboardUptimeSeconds(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _DashboardCard(
      children: [
        _SectionTitle(
          icon: Icons.data_usage_rounded,
          label: l10n.trafficDashboardSessionTraffic,
        ),
        const Gap(12),
        Text(
          available
              ? formatBytes((download + upload).toDouble())
              : l10n.notAvailableShort,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(12),
        _AdaptivePair(
          first: _Metric(
            icon: Icons.arrow_downward_rounded,
            label: l10n.trafficDashboardDownloadTotal,
            value: available
                ? formatBytes(download.toDouble())
                : l10n.notAvailableShort,
            color: theme.colorScheme.primary,
          ),
          second: _Metric(
            icon: Icons.arrow_upward_rounded,
            label: l10n.trafficDashboardUploadTotal,
            value: available
                ? formatBytes(upload.toDouble())
                : l10n.notAvailableShort,
            color: theme.colorScheme.tertiary,
          ),
        ),
        const Gap(12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const Gap(8),
            Expanded(
              child: Text(
                '${l10n.trafficDashboardConnectedFor} · ${_uptime(l10n)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connected,
    required this.connecting,
    required this.profile,
    required this.proxy,
    required this.country,
    required this.ip,
    required this.hideIp,
  });
  final bool connected;
  final bool connecting;
  final String? profile;
  final String? proxy;
  final String? country;
  final String ip;
  final bool hideIp;

  String _displayIp(AppLocalizations l10n) {
    if (ip.isEmpty) return l10n.notAvailableShort;
    if (!hideIp) return ip;
    final parts = ip.split('.');
    if (parts.length == 4) return '${parts[0]}.${parts[1]}.*.*';
    return ip.length > 8 ? '${ip.substring(0, ip.length ~/ 2)}****' : '****';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = connected
        ? l10n.trafficDashboardStateConnected
        : connecting
        ? l10n.trafficDashboardStateConnecting
        : l10n.trafficDashboardStateDisconnected;
    return _DashboardCard(
      children: [
        _SectionTitle(
          icon: Icons.hub_outlined,
          label: l10n.trafficDashboardConnectionState,
        ),
        const Gap(8),
        Text(
          state,
          style: theme.textTheme.labelLarge?.copyWith(
            color: connected || connecting
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(16),
        _InfoRow(
          label: l10n.trafficDashboardCurrentProfile,
          value: profile ?? l10n.notAvailableShort,
        ),
        const Gap(12),
        _InfoRow(
          label: l10n.trafficDashboardActiveProxy,
          value: proxy ?? l10n.notAvailableShort,
          leading: proxy == null
              ? null
              : CountryFlagBadge(countryCode: country ?? '', size: 22),
        ),
        const Gap(12),
        _InfoRow(label: l10n.trafficDashboardServerIp, value: _displayIp(l10n)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.leading});
  final String label;
  final String value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, const Gap(8)],
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

const _graphWindow = Duration(seconds: 90);

List<TrafficSample> _recentSamples(List<TrafficSample> samples) {
  if (samples.isEmpty) return samples;
  final cutoff = samples.last.timestamp.subtract(_graphWindow);
  final firstVisible = samples.indexWhere(
    (sample) => !sample.timestamp.isBefore(cutoff),
  );
  return firstVisible <= 0 ? samples : samples.sublist(firstVisible);
}

int _roundedGraphScale(int value) {
  var magnitude = 1;
  while (value > magnitude * 10) {
    magnitude *= 10;
  }
  for (final factor in const [1, 2, 5, 10]) {
    final candidate = factor * magnitude;
    if (value <= candidate) return candidate;
  }
  return magnitude * 10;
}

/// Animation drives only the painter, not a widget rebuild on every frame.
class _TrafficGraph extends StatefulWidget {
  const _TrafficGraph({required this.samples, required this.maxBps});
  final List<TrafficSample> samples;
  final int maxBps;

  @override
  State<_TrafficGraph> createState() => _TrafficGraphState();
}

class _TrafficGraphState extends State<_TrafficGraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  List<Offset> _download = const [];
  List<Offset> _upload = const [];
  List<Offset> _previousDownload = const [];
  List<Offset> _previousUpload = const [];
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _updatePoints();
    _previousDownload = _download;
    _previousUpload = _upload;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _animation.value = 1;
  }

  void _updatePoints() {
    final first = widget.samples.first.timestamp;
    final elapsed = math.max(
      1,
      widget.samples.last.timestamp.difference(first).inMicroseconds,
    );
    _download = [
      for (final sample in widget.samples)
        Offset(
          sample.timestamp.difference(first).inMicroseconds / elapsed,
          sample.downlinkBps.clamp(0, widget.maxBps) / widget.maxBps,
        ),
    ];
    _upload = [
      for (final sample in widget.samples)
        Offset(
          sample.timestamp.difference(first).inMicroseconds / elapsed,
          sample.uplinkBps.clamp(0, widget.maxBps) / widget.maxBps,
        ),
    ];
  }

  @override
  void didUpdateWidget(covariant _TrafficGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxBps == widget.maxBps &&
        listEquals(oldWidget.samples, widget.samples)) {
      return;
    }
    final progress = Curves.easeOutCubic.transform(_animation.value);
    _previousDownload = _blendPoints(_previousDownload, _download, progress);
    _previousUpload = _blendPoints(_previousUpload, _upload, progress);
    _updatePoints();
    if (_reduceMotion) {
      _animation.value = 1;
    } else {
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: AppLocalizations.of(context).trafficDashboardGraphTitle,
      child: SizedBox(
        height: 112,
        width: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(
            key: const ValueKey('traffic-dashboard-graph'),
            painter: _TrafficChartPainter(
              animation: _animation,
              previousDownload: _previousDownload,
              previousUpload: _previousUpload,
              download: _download,
              upload: _upload,
              downloadColor: scheme.primary,
              uploadColor: scheme.tertiary,
              gridColor: scheme.outlineVariant.withValues(alpha: .35),
            ),
          ),
        ),
      ),
    );
  }
}

List<Offset> _blendPoints(
  List<Offset> previous,
  List<Offset> next,
  double progress,
) {
  if (previous.isEmpty || progress == 1) return next;
  return [
    for (var i = 0; i < next.length; i++)
      Offset.lerp(
        previous[(i + previous.length - next.length).clamp(
          0,
          previous.length - 1,
        )],
        next[i],
        progress,
      )!,
  ];
}

class _TrafficChartPainter extends CustomPainter {
  _TrafficChartPainter({
    required this.animation,
    required this.previousDownload,
    required this.previousUpload,
    required this.download,
    required this.upload,
    required this.downloadColor,
    required this.uploadColor,
    required this.gridColor,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Offset> previousDownload;
  final List<Offset> previousUpload;
  final List<Offset> download;
  final List<Offset> upload;
  final Color downloadColor;
  final Color uploadColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 4, size.width, math.max(1, size.height - 8));
    final progress = Curves.easeOutCubic.transform(animation.value);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = rect.top + rect.height * i / 2;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _drawSeries(
      canvas,
      rect,
      previousDownload,
      download,
      progress,
      downloadColor,
      fill: true,
    );
    _drawSeries(
      canvas,
      rect,
      previousUpload,
      upload,
      progress,
      uploadColor,
      fill: false,
    );
    canvas.restore();
  }

  void _drawSeries(
    Canvas canvas,
    Rect rect,
    List<Offset> previous,
    List<Offset> next,
    double progress,
    Color color, {
    required bool fill,
  }) {
    if (next.isEmpty) return;
    Offset point(int i) {
      final target = next[i];
      final old = previous.isEmpty
          ? target
          : previous[(i + previous.length - next.length).clamp(
              0,
              previous.length - 1,
            )];
      final x = lerpDouble(old.dx, target.dx, progress)!;
      final y = lerpDouble(old.dy, target.dy, progress)!;
      return Offset(rect.left + rect.width * x, rect.bottom - rect.height * y);
    }

    final first = point(0);
    final path = Path()..moveTo(first.dx, first.dy);
    for (var i = 1; i < next.length - 1; i++) {
      final current = point(i);
      final following = point(i + 1);
      path.quadraticBezierTo(
        current.dx,
        current.dy,
        (current.dx + following.dx) / 2,
        (current.dy + following.dy) / 2,
      );
    }
    final last = point(next.length - 1);
    path.lineTo(last.dx, last.dy);
    if (fill) {
      final area = Path.from(path)
        ..lineTo(last.dx, rect.bottom)
        ..lineTo(first.dx, rect.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: .18),
              color.withValues(alpha: .015),
            ],
          ).createShader(rect),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = fill ? 2.5 : 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrafficChartPainter oldDelegate) =>
      oldDelegate.downloadColor != downloadColor ||
      oldDelegate.uploadColor != uploadColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.download != download ||
      oldDelegate.upload != upload ||
      oldDelegate.previousDownload != previousDownload ||
      oldDelegate.previousUpload != previousUpload ||
      oldDelegate.animation != animation;
}
