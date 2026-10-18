import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/floating_navigation_insets.dart';

class TabbedHomeShell extends StatefulWidget {
  const TabbedHomeShell({
    super.key,
    required this.homeBuilder,
    required this.proxiesBuilder,
    this.settingsBuilder,
    this.effectsEnabled = true,
    this.bottomNavigationStyle = BottomNavigationStyle.floating,
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
  final BottomNavigationStyle bottomNavigationStyle;

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
    final docked = widget.bottomNavigationStyle == BottomNavigationStyle.docked;
    const barHeight = 60.0;
    final bottom = media.viewPadding.bottom + 8;
    final reserve = keyboardVisible
        ? 0.0
        : docked
        ? barHeight + media.viewPadding.bottom
        : bottom + barHeight + 12;
    final effects =
        widget.effectsEnabled &&
        !media.disableAnimations &&
        !media.highContrast &&
        !media.accessibleNavigation;
    final navigation = _ScrubbableNavigationBar(
      requestSerial: _serial,
      height: barHeight,
      rounded: !docked,
      selectedIndex: _index,
      onDestinationSelected: _select,
      destinations: [
        NavigationDestination(
          key: const ValueKey('home-tab'),
          tooltip: '',
          icon: const Icon(Icons.home_outlined, size: 22),
          selectedIcon: const Icon(Icons.home_rounded, size: 22),
          label: l10n.homeTabTitle,
        ),
        NavigationDestination(
          key: const ValueKey('proxies-tab'),
          tooltip: '',
          icon: const Icon(Icons.dns_outlined, size: 22),
          selectedIcon: const Icon(Icons.dns_rounded, size: 22),
          label: l10n.proxiesTitle,
        ),
        if (widget.settingsBuilder != null)
          NavigationDestination(
            key: const ValueKey('settings-tab'),
            tooltip: '',
            icon: const Icon(Icons.settings_outlined, size: 22),
            selectedIcon: const Icon(Icons.settings_rounded, size: 22),
            label: l10n.settingsTitle,
          ),
      ],
    );
    final surface = Material(
      color: theme.colorScheme.surfaceContainerHigh.withValues(
        alpha: !docked && effects ? .88 : 1,
      ),
      shape: docked
          ? null
          : StadiumBorder(
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
              ),
            ),
      child: Padding(
        padding: EdgeInsets.only(bottom: docked ? media.viewPadding.bottom : 0),
        child: DecoratedBox(
          decoration: docked
              ? BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                )
              : const BoxDecoration(),
          child: Padding(
            padding: EdgeInsets.only(
              left: docked ? media.viewPadding.left : 0,
              right: docked ? media.viewPadding.right : 0,
            ),
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              removeLeft: true,
              removeRight: true,
              child: navigation,
            ),
          ),
        ),
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
                    left: docked ? 0 : media.viewPadding.left + 16,
                    right: docked ? 0 : media.viewPadding.right + 16,
                    bottom: docked ? 0 : bottom,
                    child: docked
                        ? surface
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 288),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  barHeight / 2,
                                ),
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

class _ScrubbableNavigationBar extends StatefulWidget {
  const _ScrubbableNavigationBar({
    required this.requestSerial,
    required this.height,
    required this.rounded,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final double height;
  final bool rounded;
  final int requestSerial;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  State<_ScrubbableNavigationBar> createState() =>
      _ScrubbableNavigationBarState();
}

class _ScrubbableNavigationBarState extends State<_ScrubbableNavigationBar> {
  final _boundsKey = GlobalKey();
  int? _previewIndex;
  var _scrubbing = false;

  @override
  void didUpdateWidget(covariant _ScrubbableNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.requestSerial != widget.requestSerial) {
      _previewIndex = null;
      _scrubbing = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.accessibleNavigationOf(context)) {
      _previewIndex = null;
      _scrubbing = false;
    }
  }

  int? _destinationAt(Offset globalPosition) {
    final box = _boundsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(globalPosition);
    final bounds = Offset.zero & box.size;
    if (!bounds.contains(local)) return null;
    if (widget.rounded &&
        !RRect.fromRectAndRadius(
          bounds,
          Radius.circular(box.size.height / 2),
        ).contains(local)) {
      return null;
    }
    final visualIndex = (local.dx / box.size.width * widget.destinations.length)
        .floor()
        .clamp(0, widget.destinations.length - 1);
    return Directionality.of(context) == TextDirection.rtl
        ? widget.destinations.length - 1 - visualIndex
        : visualIndex;
  }

  void _preview(Offset position) {
    if (!_scrubbing) return;
    final index = _destinationAt(position);
    if (_previewIndex != index) setState(() => _previewIndex = index);
  }

  void _cancel() {
    _scrubbing = false;
    if (_previewIndex != null) setState(() => _previewIndex = null);
  }

  void _commit(Offset position) {
    if (!_scrubbing) return;
    final index = _destinationAt(position);
    _cancel();
    if (index != null) widget.onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accessible = MediaQuery.accessibleNavigationOf(context);
    return Listener(
      onPointerCancel: (_) => _cancel(),
      child: GestureDetector(
        key: _boundsKey,
        excludeFromSemantics: true,
        onLongPressStart: accessible
            ? null
            : (details) {
                _scrubbing = true;
                _preview(details.globalPosition);
              },
        onLongPressMoveUpdate: accessible
            ? null
            : (details) => _preview(details.globalPosition),
        onLongPressEnd: accessible
            ? null
            : (details) => _commit(details.globalPosition),
        onLongPressCancel: _cancel,
        child: NavigationBar(
          height: widget.height,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => theme.textTheme.labelSmall?.copyWith(
              fontSize: 11.5,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          selectedIndex: _previewIndex ?? widget.selectedIndex,
          onDestinationSelected: widget.onDestinationSelected,
          destinations: widget.destinations,
        ),
      ),
    );
  }
}
