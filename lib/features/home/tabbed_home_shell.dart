import 'package:flutter/material.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

class TabbedHomeShell extends StatefulWidget {
  const TabbedHomeShell({
    super.key,
    required this.homeBuilder,
    required this.proxiesBuilder,
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

  @override
  State<TabbedHomeShell> createState() => _TabbedHomeShellState();
}

class _TabbedHomeShellState extends State<TabbedHomeShell> {
  var _index = 0;
  var _proxiesMounted = false;
  var _serial = 0;
  ({int serial, String? groupTag})? _request;

  void _select(int index) {
    if (index == _index) return;
    FocusScope.of(context).unfocus();
    if (index == 1) widget.onProxiesRequested?.call();
    setState(() {
      _index = index;
      if (index == 1) _proxiesMounted = true;
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
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
        ],
      ),
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: .45,
                    ),
                  ),
                ),
              ),
              child: NavigationBar(
                backgroundColor: theme.scaffoldBackgroundColor,
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
                ],
              ),
            ),
    );
  }
}
