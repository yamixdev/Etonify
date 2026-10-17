import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/floating_navigation_insets.dart';

class TabbedHomeShell extends StatefulWidget {
  const TabbedHomeShell({
    super.key,
    required this.homeBuilder,
    required this.proxiesBuilder,
    this.settingsBuilder,
    this.effectsEnabled = true,
    this.onProxiesRequested,
    this.onTabChanged,
  });

  final Widget Function(BuildContext, ValueChanged<String?>) homeBuilder;
  final Widget Function(
    BuildContext,
    bool active,
    VoidCallback backHome,
    ({int serial, String? groupTag})? request,
  )
  proxiesBuilder;
  final VoidCallback? onProxiesRequested;
  final ValueChanged<bool>? onTabChanged;
  final WidgetBuilder? settingsBuilder;
  final bool effectsEnabled;

  @override
  State<TabbedHomeShell> createState() => _TabbedHomeShellState();
}

class _TabbedHomeShellState extends State<TabbedHomeShell> {
  var _index = 0;
  var _proxiesMounted = false;
  var _settingsMounted = false;
  var _serial = 0;
  ({int serial, String? groupTag})? _request;

  void _select(int index) {
    if (index == _index) return;
    FocusScope.of(context).unfocus();
    if (index == 1) widget.onProxiesRequested?.call();
    setState(() {
      _index = index;
      if (index == 1) _proxiesMounted = true;
      if (index == 2) _settingsMounted = true;
    });
    widget.onTabChanged?.call(index == 1);
  }

  void _openProxies(String? groupTag) {
    setState(() => _request = (serial: ++_serial, groupTag: groupTag));
    _select(1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final keyboardVisible = media.viewInsets.bottom > 0;
    final barHeight = 68.0 + (media.textScaler.scale(14) - 14).clamp(0.0, 28.0);
    final bottom = media.viewPadding.bottom + 8;
    final reserve = keyboardVisible ? 0.0 : bottom + barHeight + 12;
    final effects =
        widget.effectsEnabled &&
        !media.disableAnimations &&
        !media.highContrast &&
        !media.accessibleNavigation;
    final navigation = NavigationBar(
      height: barHeight,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      selectedIndex: _index,
      onDestinationSelected: _select,
      destinations: [
        NavigationDestination(
          key: const ValueKey('home-tab'),
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: l10n.homeTabTitle,
        ),
        NavigationDestination(
          key: const ValueKey('proxies-tab'),
          icon: const Icon(Icons.dns_outlined),
          selectedIcon: const Icon(Icons.dns_rounded),
          label: l10n.proxiesTitle,
        ),
        if (widget.settingsBuilder != null)
          NavigationDestination(
            key: const ValueKey('settings-tab'),
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.settingsTitle,
          ),
      ],
    );
    final surface = Material(
      color: theme.colorScheme.surfaceContainerHigh.withValues(
        alpha: effects ? .88 : 1,
      ),
      shape: StadiumBorder(
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
        ),
      ),
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: navigation,
      ),
    );
    return PopScope(
      canPop: _index != 2,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index == 2) _select(0);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: FloatingNavigationInsets(
          bottom: reserve,
          child: Builder(
            builder: (context) => Stack(
              fit: StackFit.expand,
              children: [
                IndexedStack(
                  index: _index,
                  children: [
                    ExcludeFocus(
                      excluding: _index != 0,
                      child: TickerMode(
                        enabled: _index == 0,
                        child: widget.homeBuilder(context, _openProxies),
                      ),
                    ),
                    if (_proxiesMounted)
                      ExcludeFocus(
                        excluding: _index != 1,
                        child: TickerMode(
                          enabled: _index == 1,
                          child: widget.proxiesBuilder(
                            context,
                            _index == 1,
                            () => _select(0),
                            _request,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (_settingsMounted)
                      ExcludeFocus(
                        excluding: _index != 2,
                        child: TickerMode(
                          enabled: _index == 2,
                          child: widget.settingsBuilder!(context),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
                if (!keyboardVisible)
                  Positioned(
                    left: media.viewPadding.left + 16,
                    right: media.viewPadding.right + 16,
                    bottom: bottom,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(barHeight / 2),
                          child: effects
                              ? BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: 14,
                                    sigmaY: 14,
                                  ),
                                  child: surface,
                                )
                              : surface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
