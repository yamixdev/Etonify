import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsNotificationPage extends StatefulWidget {
  const SettingsNotificationPage({
    super.key,
    required this.currentStatusNotificationEnabled,
    required this.currentTrafficDisplayMode,
    required this.currentTrafficRefreshSeconds,
    required this.onStatusNotificationChanged,
    required this.onTrafficDisplayModeChanged,
    required this.onTrafficRefreshSecondsChanged,
  });

  final bool currentStatusNotificationEnabled;
  final NotificationTrafficDisplayMode currentTrafficDisplayMode;
  final int currentTrafficRefreshSeconds;
  final ValueChanged<bool> onStatusNotificationChanged;
  final ValueChanged<NotificationTrafficDisplayMode>
  onTrafficDisplayModeChanged;
  final ValueChanged<int> onTrafficRefreshSecondsChanged;

  @override
  State<SettingsNotificationPage> createState() =>
      _SettingsNotificationPageState();
}

class _SettingsNotificationPageState extends State<SettingsNotificationPage> {
  late bool _enabled;
  late NotificationTrafficDisplayMode _displayMode;

  @override
  void initState() {
    super.initState();
    _enabled = widget.currentStatusNotificationEnabled;
    _displayMode = widget.currentTrafficDisplayMode;
  }

  @override
  void didUpdateWidget(covariant SettingsNotificationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStatusNotificationEnabled !=
        widget.currentStatusNotificationEnabled) {
      _enabled = widget.currentStatusNotificationEnabled;
    }
    if (oldWidget.currentTrafficDisplayMode !=
        widget.currentTrafficDisplayMode) {
      _displayMode = widget.currentTrafficDisplayMode;
    }
  }

  String _displayModeName(AppLocalizations l10n) => switch (_displayMode) {
    NotificationTrafficDisplayMode.speed =>
      l10n.notificationTrafficDisplaySpeed,
    NotificationTrafficDisplayMode.total =>
      l10n.notificationTrafficDisplayTotal,
    NotificationTrafficDisplayMode.both => l10n.notificationTrafficDisplayBoth,
  };

  void _setEnabled(bool value) {
    if (_enabled == value) return;
    setState(() => _enabled = value);
    widget.onStatusNotificationChanged(value);
  }

  Future<void> _showDisplayModePicker() async {
    if (!_enabled) return;
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<NotificationTrafficDisplayMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.notificationTrafficDisplayTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final mode in NotificationTrafficDisplayMode.values)
              ListTile(
                selected: mode == _displayMode,
                title: Text(switch (mode) {
                  NotificationTrafficDisplayMode.speed =>
                    l10n.notificationTrafficDisplaySpeed,
                  NotificationTrafficDisplayMode.total =>
                    l10n.notificationTrafficDisplayTotal,
                  NotificationTrafficDisplayMode.both =>
                    l10n.notificationTrafficDisplayBoth,
                }),
                trailing: mode == _displayMode
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(context).pop(mode),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == _displayMode || !mounted) return;
    setState(() => _displayMode = selected);
    widget.onTrafficDisplayModeChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    final disabledColor = cs.onSurface.withValues(alpha: 0.38);

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.notificationSettingsTitle)),
      body: Theme(
        data: settingsTileTheme(context),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            settingsScreenPadding.left,
            progressiveHeaderTopPadding(context, settingsScreenPadding.top),
            settingsScreenPadding.right,
            appBottomSafePadding(context, settingsScreenPadding.bottom),
          ),
          children: [
            SettingsTileGroup(
              children: [
                SwitchListTile(
                  secondary: SettingsLeadingIcon(
                    icon: Icons.notifications_active_rounded,
                    color: cs.primary,
                  ),
                  title: Text(l10n.statusNotificationTitle),
                  value: _enabled,
                  onChanged: _setEnabled,
                ),
                _NotificationTrafficRefreshSetting(
                  enabled: _enabled,
                  currentSeconds: widget.currentTrafficRefreshSeconds,
                  onChanged: widget.onTrafficRefreshSecondsChanged,
                ),
                Semantics(
                  enabled: _enabled,
                  button: true,
                  child: InkWell(
                    key: const ValueKey('notification-traffic-display-setting'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _enabled ? _showDisplayModePicker : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          SettingsLeadingIcon(
                            icon: Icons.speed_rounded,
                            color: _enabled ? cs.primary : disabledColor,
                          ),
                          const Gap(16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.notificationTrafficDisplayTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: _enabled
                                        ? cs.onSurface
                                        : disabledColor,
                                  ),
                                ),
                                const Gap(4),
                                Text(
                                  _displayModeName(l10n),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: _enabled
                                        ? cs.primary
                                        : disabledColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: _enabled
                                ? cs.onSurfaceVariant
                                : disabledColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTrafficRefreshSetting extends StatefulWidget {
  const _NotificationTrafficRefreshSetting({
    required this.enabled,
    required this.currentSeconds,
    required this.onChanged,
  });

  final bool enabled;
  final int currentSeconds;
  final ValueChanged<int> onChanged;

  @override
  State<_NotificationTrafficRefreshSetting> createState() =>
      _NotificationTrafficRefreshSettingState();
}

class _NotificationTrafficRefreshSettingState
    extends State<_NotificationTrafficRefreshSetting> {
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _seconds = widget.currentSeconds.clamp(1, 10).toInt();
  }

  @override
  void didUpdateWidget(covariant _NotificationTrafficRefreshSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentSeconds != oldWidget.currentSeconds) {
      _seconds = widget.currentSeconds.clamp(1, 10).toInt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final disabledColor = cs.onSurface.withValues(alpha: 0.38);
    final foregroundColor = widget.enabled ? cs.primary : disabledColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsLeadingIcon(
            icon: Icons.timer_outlined,
            color: foregroundColor,
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.notificationTrafficRefreshTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      l10n.notificationTrafficRefreshSeconds(_seconds),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: widget.enabled ? cs.primary : disabledColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Slider(
                  value: _seconds.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: l10n.notificationTrafficRefreshSeconds(_seconds),
                  onChanged: widget.enabled
                      ? (value) {
                          final seconds = value.round().clamp(1, 10).toInt();
                          if (seconds == _seconds) return;
                          setState(() => _seconds = seconds);
                          widget.onChanged(seconds);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
