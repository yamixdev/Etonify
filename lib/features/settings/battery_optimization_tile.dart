import 'package:flutter/material.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/platform/battery_optimization.dart';

class BatteryOptimizationTile extends StatefulWidget {
  const BatteryOptimizationTile({super.key});

  @override
  State<BatteryOptimizationTile> createState() =>
      _BatteryOptimizationTileState();
}

class _BatteryOptimizationTileState extends State<BatteryOptimizationTile>
    with WidgetsBindingObserver {
  BatteryOptimizationStatus? _status;
  bool _opening = false;
  bool _querying = false;
  bool _refreshQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_querying) {
      _refreshQueued = true;
      return;
    }
    _querying = true;
    try {
      do {
        _refreshQueued = false;
        final status = await BatteryOptimization.getStatus();
        if (!mounted) return;
        if (_status != status) setState(() => _status = status);
      } while (_refreshQueued);
    } finally {
      _querying = false;
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final opened = await BatteryOptimization.openSettings();
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).batteryOptimizationOpenFailed,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusText = switch (_status) {
      BatteryOptimizationStatus.exempt => l10n.batteryOptimizationExempt,
      BatteryOptimizationStatus.restricted =>
        l10n.batteryOptimizationRestricted,
      BatteryOptimizationStatus.unavailable =>
        l10n.batteryOptimizationUnavailable,
      null => l10n.batteryOptimizationChecking,
    };
    return ListTile(
      key: const ValueKey('battery-optimization-settings'),
      leading: SettingsLeadingIcon(
        icon: Icons.battery_saver_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(l10n.batteryOptimizationTitle),
      subtitle: Tooltip(
        message: l10n.batteryOptimizationDescription,
        child: Text(statusText),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: _opening ? null : _open,
    );
  }
}
