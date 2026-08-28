import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/features/home/home_active_proxy.dart';
import 'package:meow_client/features/home/home_connection_button.dart';
import 'package:meow_client/features/home/home_presentation.dart';
import 'package:meow_client/features/home/home_subscription_card.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/models/proxy_runtime_visual_state.dart';

export 'home_active_proxy.dart';
export 'home_connection_button.dart';

const _kActiveProxyFooterReservedHeight = 82.0;

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.state,
    required this.actions,
    required this.bottomInset,
    this.showActiveProxyFooter = true,
  });

  final HomeViewState state;
  final HomeViewActions actions;
  final double bottomInset;
  final bool showActiveProxyFooter;

  bool get connected => state.connected;
  bool get connecting => state.connecting;
  bool get resolvingProxy => state.resolvingProxy;
  String get connectionStatusLabel => state.connectionStatusLabel;
  AppProfileSummary? get activeProfile => state.activeProfile;
  AppProxySummary? get activeProxy => state.activeProxy;
  ProxyRuntimeVisualStore? get runtimeStates => state.runtimeStates;
  bool get hideServerIp => state.hideServerIp;
  bool get hapticEnabled => state.hapticEnabled;
  double get speedBytesPerSecond => state.speedBytesPerSecond;
  double get trafficBytes => state.trafficBytes;
  ValueListenable<TrafficUiSnapshot>? get trafficListenable =>
      state.trafficListenable;
  bool get activeProfileRefreshing => state.activeProfileRefreshing;
  bool get showActiveProfileRefreshAction =>
      state.showActiveProfileRefreshAction;
  String get brandName => state.brandName;
  String get versionLabel => state.versionLabel;
  bool get prereleaseVersion => state.prereleaseVersion;

  VoidCallback get onToggleConnection => actions.toggleConnection;
  VoidCallback get onRefreshLatency => actions.refreshLatency;
  VoidCallback get onOpenSubscriptions => actions.openSubscriptions;
  VoidCallback get onAddSubscription => actions.addSubscription;
  VoidCallback get onOpenSettings => actions.openSettings;
  VoidCallback get onOpenChangelog => actions.openChangelog;
  VoidCallback? get onOpenTrafficDashboard => actions.openTrafficDashboard;
  VoidCallback? get onRefreshActiveProxyIp => actions.refreshActiveProxyIp;
  Future<void> Function()? get onRefreshActiveSubscription =>
      actions.refreshActiveSubscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor =
        theme.appBarTheme.titleTextStyle?.color ??
        theme.textTheme.titleLarge?.color ??
        theme.colorScheme.onSurface;
    final profile = activeProfile;
    final proxy = activeProxy;
    final connectionOccupied = connected || connecting || resolvingProxy;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 18,
        title: _HomeBrandTitle(
          brandName: brandName,
          versionLabel: versionLabel,
          prereleaseVersion: prereleaseVersion,
          titleColor: titleColor,
          onOpenChangelog: onOpenChangelog,
        ),
        actions: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
            ),
            onPressed: onOpenSettings,
            tooltip: AppLocalizations.of(context).settingsTitle,
            icon: const Icon(Icons.settings_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
              ),
              onPressed: onAddSubscription,
              tooltip: AppLocalizations.of(context).addSubscription,
              icon: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: profile == null
                ? _HomeEmptyState(onAddSubscription: onAddSubscription)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final wideLayout =
                          constraints.maxWidth >= 720 ||
                          (constraints.maxWidth >= 560 &&
                              constraints.maxWidth >
                                  constraints.maxHeight * 1.35);
                      return wideLayout
                          ? _buildWideContent(
                              profile,
                              proxy,
                              constraints.maxWidth,
                            )
                          : _buildCompactContent(
                              profile,
                              proxy,
                              connectionOccupied,
                            );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactContent(
    AppProfileSummary profile,
    AppProxySummary? proxy,
    bool connectionOccupied,
  ) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildSubscriptionTile(
            profile,
            const EdgeInsets.fromLTRB(16, 8, 16, 8),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: _buildConnectionControl(
                      proxy,
                      connectionOccupied: connectionOccupied,
                    ),
                  ),
                ),
                ?_buildActiveProxyFooter(proxy),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWideContent(
    AppProfileSummary profile,
    AppProxySummary? proxy,
    double maxWidth,
  ) {
    final sideWidth = math.min(360.0, maxWidth * .42);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: sideWidth,
            child: Column(
              children: [
                _buildSubscriptionTile(profile, EdgeInsets.zero),
                if (_buildActiveProxyFooter(proxy) case final footer?) ...[
                  const Spacer(),
                  footer,
                ],
              ],
            ),
          ),
          const Gap(24),
          Expanded(
            child: Center(
              child: _buildConnectionControl(proxy, connectionOccupied: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionTile(AppProfileSummary profile, EdgeInsets margin) {
    return HomeSubscriptionCard(
      profile: profile,
      margin: margin,
      onTap: onOpenSubscriptions,
      onOpenTrafficDashboard: onOpenTrafficDashboard,
      onRefresh: onRefreshActiveSubscription,
      refreshing: activeProfileRefreshing,
      showRefreshAction: showActiveProfileRefreshAction,
    );
  }

  Widget _buildConnectionControl(
    AppProxySummary? proxy, {
    required bool connectionOccupied,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          end: connectionOccupied ? 0 : _kActiveProxyFooterReservedHeight / 2,
        ),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, offsetY, child) {
          return Transform.translate(offset: Offset(0, offsetY), child: child);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConnectionButton(
              connected: connected,
              connecting: connecting,
              resolvingProxy: resolvingProxy,
              statusLabel: connectionStatusLabel,
              onTap: onToggleConnection,
            ),
            const Gap(8),
            _buildActiveProxyDelayIndicator(proxy),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveProxyDelayIndicator(AppProxySummary? proxy) {
    Widget buildIndicator(ProxyRuntimeVisualState? state) {
      return ActiveProxyDelayIndicator(
        connected: connected,
        proxy: proxy == null
            ? null
            : applyProxyRuntimeVisualState(proxy, state),
        networkUnavailable: state?.networkUnavailable ?? false,
        onRefresh: onRefreshLatency,
      );
    }

    final states = runtimeStates;
    if (proxy == null || states == null) {
      return buildIndicator(null);
    }
    return ValueListenableBuilder<ProxyRuntimeVisualState?>(
      valueListenable: states.listenableFor(proxy.tag),
      builder: (context, state, _) => buildIndicator(state),
    );
  }

  Widget? _buildActiveProxyFooter(AppProxySummary? proxy) {
    if (!showActiveProxyFooter || proxy == null) {
      return null;
    }
    if (trafficListenable == null) {
      return ActiveProxyFooter(
        connected: connected,
        proxy: proxy,
        hideIp: hideServerIp,
        hapticEnabled: hapticEnabled,
        speedBytesPerSecond: speedBytesPerSecond,
        trafficBytes: trafficBytes,
        unknownText: '—',
        onRefreshIp: onRefreshActiveProxyIp,
      );
    }
    return ValueListenableBuilder<TrafficUiSnapshot>(
      valueListenable: trafficListenable!,
      builder: (context, traffic, _) {
        return ActiveProxyFooter(
          connected: connected,
          proxy: proxy,
          hideIp: hideServerIp,
          hapticEnabled: hapticEnabled,
          speedBytesPerSecond: traffic.speedBytesPerSecond,
          trafficBytes: traffic.trafficBytes,
          unknownText: '—',
          onRefreshIp: onRefreshActiveProxyIp,
        );
      },
    );
  }
}

class _HomeBrandTitle extends StatelessWidget {
  const _HomeBrandTitle({
    required this.brandName,
    required this.versionLabel,
    required this.prereleaseVersion,
    required this.titleColor,
    required this.onOpenChangelog,
  });

  final String brandName;
  final String versionLabel;
  final bool prereleaseVersion;
  final Color titleColor;
  final VoidCallback onOpenChangelog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/images/logo.svg',
          height: 24,
          colorFilter: ColorFilter.mode(titleColor, BlendMode.srcIn),
        ),
        const Gap(9),
        Flexible(
          child: Text(brandName, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const Gap(8),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onOpenChangelog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: .72,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (prereleaseVersion) ...[
                  Tooltip(
                    message: AppLocalizations.of(
                      context,
                    ).updatesPrereleaseVersionTooltip,
                    child: Icon(
                      Icons.science_rounded,
                      size: 14,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                  const Gap(4),
                ],
                Text(
                  versionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({required this.onAddSubscription});

  final VoidCallback onAddSubscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(
                alpha: 0.7,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.cloud_download_rounded,
              size: 42,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const Gap(20),
          Text(
            l10n.noSubscriptions,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(8),
          Text(
            l10n.noSubscriptionsHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(24),
          FilledButton.icon(
            onPressed: onAddSubscription,
            icon: const Icon(Icons.add_link_rounded),
            label: Text(l10n.addSubscription),
          ),
        ],
      ),
    );
  }
}
