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

class _BatteryOptimizationTileState extends State<BatteryOptimizationTile> {
  bool _opening = false;

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: const ValueKey('battery-optimization-settings'),
      leading: SettingsLeadingIcon(
        icon: Icons.battery_saver_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(l10n.batteryOptimizationTitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: _opening ? null : _open,
    );
  }
}
