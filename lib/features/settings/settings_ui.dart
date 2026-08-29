import 'package:flutter/material.dart';

const settingsScreenPadding = EdgeInsets.fromLTRB(16, 12, 16, 24);
const double settingsIslandGap = 12;
const double settingsSectionGap = 16;
const double settingsSectionLabelGap = 8;

ThemeData settingsTileTheme(BuildContext context) {
  final theme = Theme.of(context);
  return theme.copyWith(
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class SettingsLeadingIcon extends StatelessWidget {
  const SettingsLeadingIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 42,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class SettingsTileGroup extends StatelessWidget {
  const SettingsTileGroup({
    super.key,
    required this.children,
    this.dividerIndent = 74,
  });

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(height: 1, indent: dividerIndent, endIndent: 16),
          ],
        ],
      ),
    );
  }
}
