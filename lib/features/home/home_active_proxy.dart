import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/formatting.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';
import 'package:meow_client/widgets/ip_refresh_dots.dart';

class ActiveProxyDelayIndicator extends StatelessWidget {
  const ActiveProxyDelayIndicator({
    super.key,
    required this.connected,
    required this.proxy,
    this.networkUnavailable = false,
    required this.onRefresh,
  });

  final bool connected;
  final AppProxySummary? proxy;
  final bool networkUnavailable;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final latency = proxy?.latency;
    final latencyFresh = proxy?.latencyFresh == true;
    final latencyChecking = proxy?.latencyChecking == true;
    final latencyUnavailable = proxy?.latencyUnavailable == true;
    final latencyUnknown = !latencyUnavailable && latency == null;
    final showCheckingIndicator = latencyChecking && !networkUnavailable;
    final hidden = !connected || proxy == null;
    final color = networkUnavailable
        ? theme.colorScheme.onSurfaceVariant
        : latencyChecking
        ? theme.colorScheme.primary
        : latencyUnavailable
        ? theme.colorScheme.onSurfaceVariant
        : !latencyFresh || latency == null
        ? theme.colorScheme.onSurfaceVariant
        : latency < 350
        ? theme.colorScheme.primary
        : latency < 900
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;
    final valueText = networkUnavailable
        ? '—'
        : latencyChecking
        ? l10n.checkingLatencyShort
        : latencyUnavailable
        ? '—'
        : latency != null
        ? '$latency'
        : '—';
    final icon = networkUnavailable
        ? Icon(Icons.wifi_off_rounded, color: color)
        : showCheckingIndicator
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          )
        : latencyUnavailable
        ? Icon(FluentIcons.wifi_warning_24_regular, color: color)
        : !latencyFresh || latencyUnknown
        ? Icon(FluentIcons.history_24_regular, color: color)
        : Icon(FluentIcons.wifi_1_24_regular, color: color);
    final unitText =
        networkUnavailable ||
            latencyChecking ||
            latencyUnavailable ||
            latency == null
        ? ''
        : l10n.millisecondsUnit;
    final tooltip = latencyChecking
        ? l10n.checkingLatency
        : l10n.refreshLatency;

    final content = Tooltip(
      message: tooltip,
      child: Semantics(
        button: !hidden,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: hidden ? null : onRefresh,
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      child: KeyedSubtree(
                        key: ValueKey(
                          networkUnavailable
                              ? 'offline'
                              : showCheckingIndicator
                              ? 'checking'
                              : latencyUnavailable
                              ? 'unavailable'
                              : latencyFresh
                              ? 'fresh'
                              : 'stale',
                        ),
                        child: icon,
                      ),
                    ),
                    const Gap(8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 76),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [...previousChildren, ?currentChild],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: .96,
                                end: 1,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text.rich(
                          key: ValueKey('$valueText$unitText'),
                          TextSpan(
                            children: [
                              TextSpan(
                                text: valueText,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: unitText,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return IgnorePointer(
      ignoring: hidden,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        opacity: hidden ? 0 : 1,
        child: content,
      ),
    );
  }
}

class ActiveProxyFooter extends StatelessWidget {
  const ActiveProxyFooter({
    super.key,
    required this.connected,
    required this.proxy,
    required this.hideIp,
    required this.hapticEnabled,
    required this.speedBytesPerSecond,
    required this.trafficBytes,
    required this.unknownText,
    this.onRefreshIp,
  });

  final bool connected;
  final AppProxySummary proxy;
  final bool hideIp;
  final bool hapticEnabled;
  final double speedBytesPerSecond;
  final double trafficBytes;
  final String unknownText;
  final VoidCallback? onRefreshIp;

  String _maskIp(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.*.*';
    }
    if (ip.length > 8) {
      return '${ip.substring(0, ip.length ~/ 2)}****';
    }
    return ip;
  }

  String get _displayIp {
    if (!connected) return '—';
    final ip = proxy.ip;
    if (ip.isEmpty) return unknownText;
    if (hideIp) return _maskIp(ip);
    return ip;
  }

  void _refreshIp() {
    if (!connected || onRefreshIp == null) return;
    if (hapticEnabled) {
      HapticFeedback.lightImpact();
    }
    onRefreshIp?.call();
  }

  Widget _ipDisplay(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    if (connected && proxy.ipChecking && proxy.ip.trim().isEmpty) {
      return IpRefreshDots(
        key: const ValueKey('ip-refresh-checking'),
        color: color,
      );
    }
    return Text(
      _displayIp,
      key: ValueKey(_displayIp),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speedText = formatSpeed(connected ? speedBytesPerSecond : 0);
    final trafficText = formatBytes(connected ? trafficBytes : 0);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: IgnorePointer(
        ignoring: !connected,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          opacity: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 74),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CountryFlagBadge(countryCode: proxy.countryCode, size: 40),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRect(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.centerLeft,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.12),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                proxy.displayName,
                                key: ValueKey(proxy.displayName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Gap(6),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: connected ? _refreshIp : null,
                          child: SizedBox(
                            height: 24,
                            width: double.infinity,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeOutCubic,
                                layoutBuilder:
                                    (currentChild, previousChildren) {
                                      return Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          ...previousChildren,
                                          ?currentChild,
                                        ],
                                      );
                                    },
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.08),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _ipDisplay(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(12),
                  SizedBox(
                    width: 118,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _FooterStatLine(
                          icon: FluentIcons.arrow_download_20_regular,
                          text: speedText,
                        ),
                        const Gap(8),
                        _FooterStatLine(
                          icon: FluentIcons
                              .arrow_bidirectional_up_down_20_regular,
                          text: trafficText,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterStatLine extends StatelessWidget {
  const _FooterStatLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Gap(6),
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }
}
