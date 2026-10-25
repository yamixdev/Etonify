import 'package:flutter/material.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/home/tabbed_home_shell.dart';
import 'package:meow_client/features/home/home_page.dart';
import 'package:meow_client/features/home/home_presentation.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/app_view_models.dart';
import 'package:meow_client/widgets/floating_navigation_insets.dart';

class NavigationPreviewGallery extends StatelessWidget {
  const NavigationPreviewGallery({
    super.key,
    required this.mode,
    required this.style,
    this.onModeChanged,
    this.onStyleChanged,
  });

  final HomeNavigationMode mode;
  final BottomNavigationStyle style;
  final ValueChanged<HomeNavigationMode>? onModeChanged;
  final ValueChanged<BottomNavigationStyle>? onStyleChanged;

  bool _canSelect(
    HomeNavigationMode nextMode,
    BottomNavigationStyle nextStyle,
  ) =>
      (mode == nextMode || onModeChanged != null) &&
      (nextMode == HomeNavigationMode.panel ||
          style == nextStyle ||
          onStyleChanged != null);

  void _select(HomeNavigationMode nextMode, BottomNavigationStyle nextStyle) {
    if (nextMode == HomeNavigationMode.tabs && style != nextStyle) {
      onStyleChanged?.call(nextStyle);
    }
    if (mode != nextMode) onModeChanged?.call(nextMode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scale = MediaQuery.textScalerOf(context);
    return SizedBox(
      height: 300 + (scale.scale(14) - 14).clamp(0, 100) * 5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 32).clamp(140.0, 180.0);
          return SingleChildScrollView(
            key: const PageStorageKey('navigation-gallery-scroll'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in [
                  (
                    id: 'panel',
                    label: l10n.homeNavigationPanel,
                    mode: HomeNavigationMode.panel,
                    style: style,
                  ),
                  (
                    id: 'docked',
                    label: l10n.navigationGalleryDocked,
                    mode: HomeNavigationMode.tabs,
                    style: BottomNavigationStyle.docked,
                  ),
                  (
                    id: 'floating',
                    label: l10n.navigationGalleryFloating,
                    mode: HomeNavigationMode.tabs,
                    style: BottomNavigationStyle.floating,
                  ),
                ]) ...[
                  if (option.id != 'panel') const SizedBox(width: 12),
                  _NavigationCard(
                    key: ValueKey('navigation-preview-${option.id}'),
                    width: width,
                    label: option.label,
                    badge: option.id == 'floating'
                        ? l10n.navigationExperimentalBadge
                        : null,
                    selected:
                        mode == option.mode &&
                        (mode == HomeNavigationMode.panel ||
                            style == option.style),
                    onTap: _canSelect(option.mode, option.style)
                        ? () => _select(option.mode, option.style)
                        : null,
                    child: _NavigationMiniature(
                      panel: option.mode == HomeNavigationMode.panel,
                      style: option.style,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    super.key,
    required this.width,
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final double width;
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      inMutuallyExclusiveGroup: true,
      label: badge == null ? label : '$label, $badge',
      child: SizedBox(
        width: width,
        child: Material(
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: child),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: selected ? cs.primary : cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (badge != null)
                          Tooltip(
                            message: badge!,
                            child: Icon(
                              Icons.science_outlined,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
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

class _NavigationMiniature extends StatelessWidget {
  const _NavigationMiniature({required this.panel, required this.style});

  final bool panel;
  final BottomNavigationStyle style;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ExcludeFocus(
      child: IgnorePointer(
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              height: 720,
              child: MediaQuery(
                data: media.copyWith(
                  size: const Size(360, 720),
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                  viewInsets: EdgeInsets.zero,
                ),
                child: panel
                    ? const _PreviewHome(showSettings: true, panel: true)
                    : TabbedHomeShell(
                        effectsEnabled: false,
                        bottomNavigationStyle: style,
                        homeBuilder: (_, openProxies) => _PreviewHome(
                          showSettings: style == BottomNavigationStyle.docked,
                        ),
                        proxiesBuilder: (_, active, backHome, request) =>
                            const SizedBox.shrink(),
                        settingsBuilder: (_) => const SizedBox.shrink(),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewHome extends StatelessWidget {
  const _PreviewHome({required this.showSettings, this.panel = false});

  final bool showSettings;
  final bool panel;

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        HomePage(
          state: HomeViewState(
            connected: false,
            connecting: false,
            resolvingProxy: false,
            connectionStatusLabel: l10n.tapToConnect,
            activeProfile: AppProfileSummary(
              id: 'navigation-preview',
              name: l10n.subscriptionsTitle,
              consumed: 0,
              total: 0,
              remainingDays: null,
              outboundsCount: 1,
              sourceLabel: l10n.subscriptionLocalFile,
            ),
            activeProxy: AppProxySummary(
              tag: 'navigation-preview',
              displayName: l10n.proxiesTitle,
              countryCode: '',
              type: 'vless',
              server: '',
              port: 0,
              detailText: '',
              ip: '',
              latency: null,
              latencyFresh: false,
              latencyChecking: false,
              latencyUnavailable: false,
              latencyError: null,
              protocolLabel: 'VLESS',
              endpointLabel: '',
            ),
            hideServerIp: true,
            hapticEnabled: false,
            speedBytesPerSecond: 0,
            trafficBytes: 0,
            brandName: 'Etonify',
            versionLabel: '',
          ),
          actions: const HomeViewActions(
            toggleConnection: _noop,
            refreshLatency: _noop,
            openSubscriptions: _noop,
            addSubscription: _noop,
            openSettings: _noop,
            openChangelog: _noop,
            openProxies: _noop,
          ),
          showSettingsAction: showSettings,
          showActiveProxyFooter: !panel,
          bottomInset: panel ? 72 : FloatingNavigationInsets.of(context),
        ),
        if (panel)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
