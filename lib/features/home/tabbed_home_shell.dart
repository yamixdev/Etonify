import 'dart:math' as math;
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

class _TabbedHomeShellState extends State<TabbedHomeShell>
    with SingleTickerProviderStateMixin {
  late final _contentTransition = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 120),
  );
  late final _contentOpacity = _contentTransition
      .drive(CurveTween(curve: Curves.easeOutCubic))
      .drive(Tween<double>(begin: .75, end: 1));
  var _index = 0;
  var _proxiesMounted = false;
  var _settingsMounted = false;
  var _serial = 0;
  ({int serial, String? groupTag})? _request;

  @override
  void dispose() {
    _contentTransition.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _contentTransition.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant TabbedHomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index == 2 &&
        (widget.bottomNavigationStyle == BottomNavigationStyle.docked ||
            widget.settingsBuilder == null)) {
      _index = 0;
    }
    if (widget.settingsBuilder == null) _settingsMounted = false;
  }

  void _select(int index) {
    if (index == _index) return;
    FocusScope.of(context).unfocus();
    if (index == 1) widget.onProxiesRequested?.call();
    setState(() {
      _index = index;
      if (index == 1) _proxiesMounted = true;
      if (index == 2) _settingsMounted = true;
    });
    if (widget.effectsEnabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context)) {
      _contentTransition.forward(from: 0);
    } else {
      _contentTransition.value = 1;
    }
    widget.onTabChanged?.call(index == 1);
  }

  void _openProxies(String? groupTag) {
    setState(() => _request = (serial: ++_serial, groupTag: groupTag));
    _select(1);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _buildShell);

  Widget _buildShell(BuildContext context, BoxConstraints constraints) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final keyboardVisible = media.viewInsets.bottom > 0;
    final docked = widget.bottomNavigationStyle == BottomNavigationStyle.docked;
    final bottom = media.viewPadding.bottom + 8;
    final effects =
        widget.effectsEnabled &&
        !media.disableAnimations &&
        !media.highContrast &&
        !media.accessibleNavigation;
    final destinations = [
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
      if (!docked && widget.settingsBuilder != null)
        NavigationDestination(
          key: const ValueKey('settings-tab'),
          tooltip: '',
          icon: const Icon(Icons.settings_outlined, size: 22),
          selectedIcon: const Icon(Icons.settings_rounded, size: 22),
          label: l10n.settingsTitle,
        ),
    ];
    final floatingLayout = docked
        ? null
        : _FloatingNavigationLayout.measure(
            context,
            math.max(
              0,
              constraints.maxWidth - media.viewPadding.horizontal - 32,
            ),
            destinations,
          );
    final barHeight = floatingLayout?.height ?? 60;
    final reserve = keyboardVisible || docked ? 0.0 : bottom + barHeight + 12;
    final navigation = _ScrubbableNavigationBar(
      requestSerial: _serial,
      height: barHeight,
      rounded: !docked,
      selectedIndex: _index,
      onDestinationSelected: _select,
      destinations: destinations,
      floatingLayout: floatingLayout,
    );
    final surface = Material(
      color: docked
          ? theme.scaffoldBackgroundColor
          : Color.alphaBlend(
              theme.colorScheme.onSurface.withValues(alpha: .025),
              theme.scaffoldBackgroundColor,
            ).withValues(alpha: effects ? .94 : 1),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: docked
          ? null
          : StadiumBorder(
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: media.highContrast ? .6 : .08,
                ),
              ),
            ),
      child: Padding(
        padding: EdgeInsets.only(bottom: docked ? media.viewPadding.bottom : 0),
        child: Padding(
          padding: EdgeInsets.only(
            left: docked ? media.viewPadding.left : 0,
            right: docked ? media.viewPadding.right : 0,
          ),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            removeLeft: true,
            removeRight: true,
            child: navigation,
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
        bottomNavigationBar: docked && !keyboardVisible ? surface : null,
        body: FloatingNavigationInsets(
          bottom: reserve,
          child: Builder(
            builder: (context) => Stack(
              fit: StackFit.expand,
              children: [
                FadeTransition(
                  key: const ValueKey('home-tab-content-transition'),
                  opacity: _contentOpacity,
                  alwaysIncludeSemantics: true,
                  child: IndexedStack(
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
                ),
                if (!docked && !keyboardVisible)
                  Positioned(
                    left: media.viewPadding.left + 16,
                    right: media.viewPadding.right + 16,
                    bottom: bottom,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: floatingLayout!.width,
                        ),
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

class _ScrubbableNavigationBar extends StatefulWidget {
  const _ScrubbableNavigationBar({
    required this.requestSerial,
    required this.height,
    required this.rounded,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.floatingLayout,
  });

  final double height;
  final bool rounded;
  final int requestSerial;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final _FloatingNavigationLayout? floatingLayout;

  @override
  State<_ScrubbableNavigationBar> createState() =>
      _ScrubbableNavigationBarState();
}

class _ScrubbableNavigationBarState extends State<_ScrubbableNavigationBar> {
  final _boundsKey = GlobalKey();
  final _destinationKeys = <int, GlobalKey>{};
  int? _previewIndex;
  var _scrubbing = false;

  @override
  void didUpdateWidget(covariant _ScrubbableNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.requestSerial != widget.requestSerial ||
        oldWidget.destinations.length != widget.destinations.length) {
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
    if (widget.floatingLayout != null) {
      for (var index = 0; index < widget.destinations.length; index++) {
        final target =
            _destinationKeys[index]?.currentContext?.findRenderObject()
                as RenderBox?;
        if (target != null &&
            target.hasSize &&
            (Offset.zero & target.size).contains(
              target.globalToLocal(globalPosition),
            )) {
          return index;
        }
      }
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
        child: widget.floatingLayout != null
            ? _buildFloating(context)
            : NavigationBar(
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

  Widget _buildFloating(BuildContext context) {
    final layout = widget.floatingLayout!;
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final selected = _previewIndex ?? widget.selectedIndex;
    final duration = media.disableAnimations || media.accessibleNavigation
        ? Duration.zero
        : const Duration(milliseconds: 150);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final selectedWidth = layout.activeWidths[selected];
    final selectedInactiveWidth =
        (layout.width - 8 - selectedWidth) / (widget.destinations.length - 1);
    final targetBounds = Rect.fromLTWH(
      selected * selectedInactiveWidth,
      0,
      selectedWidth,
      layout.height,
    );
    return SizedBox(
      key: const ValueKey('floating-bottom-navigation'),
      width: layout.width,
      height: layout.height,
      child: TweenAnimationBuilder<Rect?>(
        tween: RectTween(begin: targetBounds, end: targetBounds),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, animatedBounds, _) {
          final bounds = animatedBounds!;
          final inactiveWidth =
              (layout.width - 8 - bounds.width) /
              (widget.destinations.length - 1);
          final position = bounds.left / inactiveWidth;
          return Stack(
            children: [
              Positioned(
                left: rtl ? layout.width - bounds.right : bounds.left + 8,
                top: 4,
                bottom: 4,
                width: bounds.width - 8,
                child: DecoratedBox(
                  key: const ValueKey('floating-navigation-indicator'),
                  decoration: ShapeDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < widget.destinations.length;
                      index++
                    )
                      SizedBox(
                        key: _destinationKeys.putIfAbsent(index, GlobalKey.new),
                        width:
                            inactiveWidth +
                            (bounds.width - inactiveWidth) *
                                (1 - (position - index).abs()).clamp(0.0, 1.0),
                        height: layout.height,
                        child: _FloatingNavigationDestination(
                          destination: widget.destinations[index],
                          selected: index == selected,
                          labelWidth: layout.activeWidths[index] - 62,
                          labelStyle: layout.labelStyle,
                          onTap: () => widget.onDestinationSelected(index),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FloatingNavigationLayout {
  const _FloatingNavigationLayout({
    required this.width,
    required this.height,
    required this.activeWidths,
    required this.labelStyle,
  });

  final double width;
  final double height;
  final List<double> activeWidths;
  final TextStyle labelStyle;

  factory _FloatingNavigationLayout.measure(
    BuildContext context,
    double availableWidth,
    List<NavigationDestination> destinations,
  ) {
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
    );
    double textWidth = 0;
    final textWidths = <double>[];
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    for (final destination in destinations) {
      painter.text = TextSpan(text: destination.label, style: style);
      painter.layout();
      textWidths.add(painter.width);
      textWidth = math.max(textWidth, painter.width);
    }
    final inactiveTotal = 48.0 * (destinations.length - 1);
    final width = math.min(
      availableWidth,
      math.max(288.0, textWidth + 62 + inactiveTotal + 8),
    );
    final activeWidths = <double>[
      for (final textWidth in textWidths)
        math.min(width - 8 - inactiveTotal, math.max(62.0, textWidth + 62)),
    ];
    double textHeight = 0;
    for (var index = 0; index < destinations.length; index++) {
      painter.text = TextSpan(text: destinations[index].label, style: style);
      painter.layout(maxWidth: math.max(1, activeWidths[index] - 62));
      textHeight = math.max(textHeight, painter.height);
    }
    painter.dispose();
    return _FloatingNavigationLayout(
      width: width,
      height: math.max(56, textHeight + 24),
      activeWidths: activeWidths,
      labelStyle: style,
    );
  }
}

class _FloatingNavigationDestination extends StatefulWidget {
  const _FloatingNavigationDestination({
    required this.destination,
    required this.selected,
    required this.labelWidth,
    required this.labelStyle,
    required this.onTap,
  });

  final NavigationDestination destination;
  final bool selected;
  final double labelWidth;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  State<_FloatingNavigationDestination> createState() =>
      _FloatingNavigationDestinationState();
}

class _FloatingNavigationDestinationState
    extends State<_FloatingNavigationDestination> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final selected = widget.selected;
    final onTap = widget.onTap;
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Semantics(
      key: destination.key,
      label: destination.label,
      button: true,
      selected: selected,
      focused: _focused,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          focusColor: colors.primary.withValues(alpha: .2),
          onFocusChange: (value) => setState(() => _focused = value),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: StadiumBorder(
                side: BorderSide(
                  width: 2,
                  color: _focused ? colors.onSurface : Colors.transparent,
                ),
              ),
            ),
            child: ClipRect(
              child: OverflowBox(
                minWidth: 0,
                maxWidth: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTheme(
                      data: IconThemeData(color: foreground, size: 22),
                      child: selected
                          ? destination.selectedIcon ?? destination.icon
                          : destination.icon,
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: widget.labelWidth,
                        child: Text(
                          destination.label,
                          textAlign: TextAlign.center,
                          style: widget.labelStyle.copyWith(color: foreground),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
