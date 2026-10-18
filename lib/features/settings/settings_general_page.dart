import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_notification_page.dart';
import 'package:meow_client/features/settings/navigation_preview_gallery.dart';
import 'package:meow_client/features/settings/battery_optimization_tile.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/features/settings/subscription_background_tile.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

/// Static accent colors the user can pick from (after dynamic ones).
const _staticAccentOptions = <_AccentOption>[
  _AccentOption(hex: '2D5BFF', color: Color(0xFF2D5BFF), label: 'Blue'),
  _AccentOption(hex: '7B61FF', color: Color(0xFF7B61FF), label: 'Purple'),
  _AccentOption(hex: 'E91E63', color: Color(0xFFE91E63), label: 'Pink'),
  _AccentOption(hex: 'E53935', color: Color(0xFFE53935), label: 'Red'),
  _AccentOption(hex: 'FF6D00', color: Color(0xFFFF6D00), label: 'Orange'),
  _AccentOption(hex: 'FFC107', color: Color(0xFFFFC107), label: 'Amber'),
  _AccentOption(hex: '0F9D58', color: Color(0xFF0F9D58), label: 'Green'),
  _AccentOption(hex: '009688', color: Color(0xFF009688), label: 'Teal'),
];

/// Build accent options: dynamic Material You colors first, then static.
List<_AccentOption> _buildAccentOptions(ColorScheme? dynamicLightScheme) {
  if (dynamicLightScheme != null) {
    return [
      _AccentOption(
        hex: 'default',
        color: dynamicLightScheme.primary,
        label: 'M3',
        previewColors: [
          dynamicLightScheme.primary,
          dynamicLightScheme.secondary,
          dynamicLightScheme.tertiary,
        ],
      ),
      ..._staticAccentOptions,
    ];
  }
  return [
    const _AccentOption(hex: 'default', color: Color(0xFF6750A4), label: 'M3'),
    ..._staticAccentOptions,
  ];
}

class _AccentOption {
  const _AccentOption({
    required this.hex,
    required this.color,
    required this.label,
    this.previewColors,
  });
  final String hex;
  final Color color;
  final String label;
  final List<Color>? previewColors;
}

class SettingsGeneralPage extends StatefulWidget {
  const SettingsGeneralPage({
    super.key,
    required this.currentLocaleCode,
    required this.currentThemePreference,
    required this.currentAccentColorHex,
    this.dynamicLightScheme,
    required this.currentHapticEnabled,
    required this.currentStatusNotificationEnabled,
    required this.currentNotificationTrafficDisplayMode,
    required this.currentNotificationTrafficRefreshSeconds,
    required this.currentHideServerIp,
    this.currentSendHwidToProviders = true,
    this.onSendHwidToProvidersChanged,
    this.currentAutoConnectOnLaunch = false,
    this.onAutoConnectOnLaunchChanged,
    this.currentHomeNavigationMode = HomeNavigationMode.panel,
    this.onHomeNavigationModeChanged,
    this.currentBottomNavigationStyle = BottomNavigationStyle.floating,
    this.onBottomNavigationStyleChanged,
    this.showQuickSettingsTileAction = false,
    this.onAddQuickSettingsTile,
    this.showBatteryOptimizationSettings = false,
    required this.onLocaleChanged,
    required this.onThemePreferenceChanged,
    required this.onAccentColorChanged,
    required this.onHapticChanged,
    required this.onStatusNotificationChanged,
    required this.onNotificationTrafficDisplayModeChanged,
    required this.onNotificationTrafficRefreshSecondsChanged,
    required this.onHideServerIpChanged,
  });

  final String currentLocaleCode;
  final AppThemePreference currentThemePreference;
  final String currentAccentColorHex;
  final ColorScheme? dynamicLightScheme;
  final bool currentHapticEnabled;
  final bool currentStatusNotificationEnabled;
  final NotificationTrafficDisplayMode currentNotificationTrafficDisplayMode;
  final int currentNotificationTrafficRefreshSeconds;
  final bool currentHideServerIp;
  final bool currentSendHwidToProviders;
  final ValueChanged<bool>? onSendHwidToProvidersChanged;
  final bool currentAutoConnectOnLaunch;
  final ValueChanged<bool>? onAutoConnectOnLaunchChanged;
  final HomeNavigationMode currentHomeNavigationMode;
  final ValueChanged<HomeNavigationMode>? onHomeNavigationModeChanged;
  final BottomNavigationStyle currentBottomNavigationStyle;
  final ValueChanged<BottomNavigationStyle>? onBottomNavigationStyleChanged;
  final bool showQuickSettingsTileAction;
  final VoidCallback? onAddQuickSettingsTile;
  final bool showBatteryOptimizationSettings;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<AppThemePreference> onThemePreferenceChanged;
  final ValueChanged<String> onAccentColorChanged;
  final ValueChanged<bool> onHapticChanged;
  final ValueChanged<bool> onStatusNotificationChanged;
  final ValueChanged<NotificationTrafficDisplayMode>
  onNotificationTrafficDisplayModeChanged;
  final ValueChanged<int> onNotificationTrafficRefreshSecondsChanged;
  final ValueChanged<bool> onHideServerIpChanged;

  @override
  State<SettingsGeneralPage> createState() => _SettingsGeneralPageState();
}

class _SettingsGeneralPageState extends State<SettingsGeneralPage> {
  final _revision = ValueNotifier(0);
  final _pageStorage = PageStorageBucket();
  late var _localeCode = widget.currentLocaleCode;
  late var _themePreference = widget.currentThemePreference;
  late var _accentColorHex = widget.currentAccentColorHex;
  late var _hapticEnabled = widget.currentHapticEnabled;
  late var _statusNotificationEnabled = widget.currentStatusNotificationEnabled;
  late var _trafficDisplayMode = widget.currentNotificationTrafficDisplayMode;
  late var _trafficRefreshSeconds =
      widget.currentNotificationTrafficRefreshSeconds;
  late var _hideServerIp = widget.currentHideServerIp;
  late var _sendHwid = widget.currentSendHwidToProviders;
  late var _autoConnect = widget.currentAutoConnectOnLaunch;
  late var _homeNavigationMode = widget.currentHomeNavigationMode;
  late var _bottomNavigationStyle = widget.currentBottomNavigationStyle;

  @override
  void didUpdateWidget(covariant SettingsGeneralPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLocaleCode != widget.currentLocaleCode) {
      _localeCode = widget.currentLocaleCode;
    }
    if (oldWidget.currentThemePreference != widget.currentThemePreference) {
      _themePreference = widget.currentThemePreference;
    }
    if (oldWidget.currentAccentColorHex != widget.currentAccentColorHex) {
      _accentColorHex = widget.currentAccentColorHex;
    }
    if (oldWidget.currentHapticEnabled != widget.currentHapticEnabled) {
      _hapticEnabled = widget.currentHapticEnabled;
    }
    if (oldWidget.currentStatusNotificationEnabled !=
        widget.currentStatusNotificationEnabled) {
      _statusNotificationEnabled = widget.currentStatusNotificationEnabled;
    }
    if (oldWidget.currentNotificationTrafficDisplayMode !=
        widget.currentNotificationTrafficDisplayMode) {
      _trafficDisplayMode = widget.currentNotificationTrafficDisplayMode;
    }
    if (oldWidget.currentNotificationTrafficRefreshSeconds !=
        widget.currentNotificationTrafficRefreshSeconds) {
      _trafficRefreshSeconds = widget.currentNotificationTrafficRefreshSeconds;
    }
    if (oldWidget.currentHideServerIp != widget.currentHideServerIp) {
      _hideServerIp = widget.currentHideServerIp;
    }
    if (oldWidget.currentSendHwidToProviders !=
        widget.currentSendHwidToProviders) {
      _sendHwid = widget.currentSendHwidToProviders;
    }
    if (oldWidget.currentAutoConnectOnLaunch !=
        widget.currentAutoConnectOnLaunch) {
      _autoConnect = widget.currentAutoConnectOnLaunch;
    }
    if (oldWidget.currentHomeNavigationMode !=
        widget.currentHomeNavigationMode) {
      _homeNavigationMode = widget.currentHomeNavigationMode;
    }
    if (oldWidget.currentBottomNavigationStyle !=
        widget.currentBottomNavigationStyle) {
      _bottomNavigationStyle = widget.currentBottomNavigationStyle;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revision.value++;
    });
  }

  void _update(VoidCallback change) {
    change();
    _revision.value++;
  }

  @override
  void dispose() {
    _revision.dispose();
    super.dispose();
  }

  String _localeName(AppLocalizations l10n, String code) => switch (code) {
    'en' => l10n.languageEnglish,
    'ru' => l10n.languageRussian,
    _ => l10n.languageSystem,
  };

  Future<void> _showLanguagePicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _RadioSheet<String>(
        title: l10n.languageSettingTitle,
        current: _localeCode,
        items: [
          RadioChoice(value: 'system', label: l10n.languageSystem),
          RadioChoice(value: 'en', label: l10n.languageEnglish),
          RadioChoice(value: 'ru', label: l10n.languageRussian),
        ],
      ),
    );
    if (!mounted || result == null) return;
    _update(() => _localeCode = result);
    widget.onLocaleChanged(result);
  }

  Future<void> _openSection(WidgetBuilder builder) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => ValueListenableBuilder<int>(
            valueListenable: _revision,
            builder: (context, _, child) => builder(context),
          ),
        ),
      );

  Widget _sectionPage(
    BuildContext context,
    String section,
    String title,
    List<Widget> children,
  ) {
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(title)),
      body: Theme(
        data: settingsTileTheme(context),
        child: PageStorage(
          bucket: _pageStorage,
          child: ListView(
            key: PageStorageKey('general-$section-scroll'),
            padding: EdgeInsets.fromLTRB(
              0,
              progressiveHeaderTopPadding(context, 12),
              0,
              appBottomSafePadding(context, 24),
            ),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _group(List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SettingsTileGroup(children: children),
  );

  Widget _entry(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String title,
    String? summary,
    required WidgetBuilder builder,
  }) => ListTile(
    key: ValueKey(key),
    leading: SettingsLeadingIcon(
      icon: icon,
      color: Theme.of(context).colorScheme.primary,
    ),
    title: Text(title),
    subtitle: summary == null ? null : Text(summary),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => _openSection(builder),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _sectionPage(context, 'hub', l10n.generalSectionTitle, [
      _group([
        _entry(
          context,
          key: 'general-appearance-entry',
          icon: Icons.palette_outlined,
          title: l10n.generalAppearanceTitle,
          summary: l10n.generalAppearanceSummary,
          builder: _appearance,
        ),
        _entry(
          context,
          key: 'general-startup-entry',
          icon: Icons.power_settings_new_rounded,
          title: l10n.generalStartupTitle,
          summary: l10n.generalStartupSummary,
          builder: _startup,
        ),
        _entry(
          context,
          key: 'notification-settings-entry',
          icon: Icons.notifications_none_rounded,
          title: l10n.notificationSettingsTitle,
          builder: _notifications,
        ),
        _entry(
          context,
          key: 'general-background-entry',
          icon: Icons.sync_rounded,
          title: l10n.generalBackgroundTitle,
          summary: l10n.generalBackgroundSummary,
          builder: _background,
        ),
        _entry(
          context,
          key: 'general-privacy-entry',
          icon: Icons.shield_outlined,
          title: l10n.generalPrivacyTitle,
          summary: l10n.generalPrivacySummary,
          builder: _privacy,
        ),
      ]),
    ]);
  }

  Widget _appearance(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return _sectionPage(context, 'appearance', l10n.generalAppearanceTitle, [
      _group([
        ListTile(
          leading: SettingsLeadingIcon(
            icon: Icons.language_rounded,
            color: cs.primary,
          ),
          title: Text(l10n.languageSettingTitle),
          subtitle: Text(_localeName(l10n, _localeCode)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _showLanguagePicker(context),
        ),
      ]),

      const Gap(settingsSectionGap),

      // ── Appearance — Theme ──
      _SectionLabel(label: l10n.appearanceTitle),
      const Gap(settingsSectionLabelGap),
      SizedBox(
        height: 128 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
        child: ListView(
          key: const PageStorageKey('general-theme-previews-scroll'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _ThemePreviewCard(
              label: l10n.themeSystem,
              selected: _themePreference == AppThemePreference.system,
              onTap: () => _setTheme(AppThemePreference.system),
              child: const _SystemPreview(),
            ),
            const Gap(12),
            _ThemePreviewCard(
              label: l10n.themeLight,
              selected: _themePreference == AppThemePreference.light,
              onTap: () => _setTheme(AppThemePreference.light),
              child: const _MockUI(isDark: false),
            ),
            const Gap(12),
            _ThemePreviewCard(
              label: l10n.themeDark,
              selected: _themePreference == AppThemePreference.dark,
              onTap: () => _setTheme(AppThemePreference.dark),
              child: const _MockUI(isDark: true),
            ),
            const Gap(12),
            _ThemePreviewCard(
              label: l10n.themeAmoled,
              selected: _themePreference == AppThemePreference.amoled,
              onTap: () => _setTheme(AppThemePreference.amoled),
              child: const _MockUI(isDark: true, isAmoled: true),
            ),
          ],
        ),
      ),

      const Gap(settingsSectionGap),

      // ── Accent color (horizontal scroll) ──
      Builder(
        builder: (context) {
          final accentOptions = _buildAccentOptions(widget.dynamicLightScheme);
          return SizedBox(
            height: 48,
            child: ListView.separated(
              key: const PageStorageKey('general-accent-colors-scroll'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: accentOptions.length,
              separatorBuilder: (context, index) => const Gap(12),
              itemBuilder: (context, index) {
                final option = accentOptions[index];
                return _AccentSwatch(
                  color: option.color,
                  previewColors: option.previewColors,
                  selected: _accentColorHex == option.hex,
                  onTap: () {
                    _update(() => _accentColorHex = option.hex);
                    widget.onAccentColorChanged(option.hex);
                  },
                );
              },
            ),
          );
        },
      ),

      const Gap(settingsSectionGap),

      if (widget.onHomeNavigationModeChanged != null ||
          widget.onBottomNavigationStyleChanged != null) ...[
        _SectionLabel(label: l10n.navigationGalleryTitle),
        const Gap(settingsSectionLabelGap),
        NavigationPreviewGallery(
          mode: _homeNavigationMode,
          style: _bottomNavigationStyle,
          onModeChanged: widget.onHomeNavigationModeChanged == null
              ? null
              : (value) {
                  _update(() => _homeNavigationMode = value);
                  widget.onHomeNavigationModeChanged!(value);
                },
          onStyleChanged: widget.onBottomNavigationStyleChanged == null
              ? null
              : (value) {
                  _update(() => _bottomNavigationStyle = value);
                  widget.onBottomNavigationStyleChanged!(value);
                },
        ),
      ],
    ]);
  }

  void _setTheme(AppThemePreference value) {
    _update(() => _themePreference = value);
    widget.onThemePreferenceChanged(value);
  }

  Widget _startup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return _sectionPage(context, 'startup', l10n.generalStartupTitle, [
      _group([
        _AutoConnectTile(
          value: _autoConnect,
          onChanged: widget.onAutoConnectOnLaunchChanged == null
              ? null
              : (value) {
                  _update(() => _autoConnect = value);
                  widget.onAutoConnectOnLaunchChanged!(value);
                },
        ),
        if (widget.showQuickSettingsTileAction)
          ListTile(
            key: const ValueKey('add-quick-settings-tile'),
            leading: SettingsLeadingIcon(
              icon: Icons.dashboard_customize_rounded,
              color: cs.primary,
            ),
            title: Text(l10n.quickSettingsTileTitle),
            subtitle: Text(l10n.quickSettingsTileDescription),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: widget.onAddQuickSettingsTile,
          ),
        SwitchListTile(
          secondary: SettingsLeadingIcon(
            icon: Icons.vibration_rounded,
            color: cs.primary,
          ),
          title: Text(l10n.hapticTitle),
          value: _hapticEnabled,
          onChanged: (value) {
            _update(() => _hapticEnabled = value);
            widget.onHapticChanged(value);
          },
        ),
      ]),
    ]);
  }

  Widget _notifications(BuildContext context) => SettingsNotificationPage(
    currentStatusNotificationEnabled: _statusNotificationEnabled,
    currentTrafficDisplayMode: _trafficDisplayMode,
    currentTrafficRefreshSeconds: _trafficRefreshSeconds,
    onStatusNotificationChanged: (value) {
      _update(() => _statusNotificationEnabled = value);
      widget.onStatusNotificationChanged(value);
    },
    onTrafficDisplayModeChanged: (value) {
      _update(() => _trafficDisplayMode = value);
      widget.onNotificationTrafficDisplayModeChanged(value);
    },
    onTrafficRefreshSecondsChanged: (value) {
      _update(() => _trafficRefreshSeconds = value);
      widget.onNotificationTrafficRefreshSecondsChanged(value);
    },
  );

  Widget _background(BuildContext context) => _sectionPage(
    context,
    'background',
    AppLocalizations.of(context).generalBackgroundTitle,
    [
      _group([
        if (widget.showBatteryOptimizationSettings)
          const BatteryOptimizationTile(),
        const SubscriptionBackgroundTile(),
      ]),
    ],
  );

  Widget _privacy(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return _sectionPage(context, 'privacy', l10n.generalPrivacyTitle, [
      _group([
        SwitchListTile(
          key: const ValueKey('hide-server-ip'),
          secondary: SettingsLeadingIcon(
            icon: Icons.visibility_off_rounded,
            color: cs.primary,
          ),
          title: Text(l10n.hideServerIpTitle),
          value: _hideServerIp,
          onChanged: (value) {
            _update(() => _hideServerIp = value);
            widget.onHideServerIpChanged(value);
          },
        ),
        _HwidSharingTile(
          value: _sendHwid,
          onChanged: widget.onSendHwidToProvidersChanged == null
              ? null
              : (value) {
                  _update(() => _sendHwid = value);
                  widget.onSendHwidToProvidersChanged!(value);
                },
        ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _AutoConnectTile extends StatefulWidget {
  const _AutoConnectTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<_AutoConnectTile> createState() => _AutoConnectTileState();
}

class _AutoConnectTileState extends State<_AutoConnectTile> {
  late bool _value = widget.value;

  @override
  void didUpdateWidget(covariant _AutoConnectTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SwitchListTile(
      key: const ValueKey('auto-connect-on-launch'),
      secondary: SettingsLeadingIcon(
        icon: Icons.power_settings_new_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(l10n.autoConnectOnLaunchTitle),
      subtitle: Text(l10n.autoConnectOnLaunchDescription),
      value: _value,
      onChanged: widget.onChanged == null
          ? null
          : (value) {
              widget.onChanged!(value);
              setState(() => _value = value);
            },
    );
  }
}

class _HwidSharingTile extends StatefulWidget {
  const _HwidSharingTile({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<_HwidSharingTile> createState() => _HwidSharingTileState();
}

class _HwidSharingTileState extends State<_HwidSharingTile> {
  late bool _value = widget.value;

  @override
  void didUpdateWidget(covariant _HwidSharingTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SwitchListTile(
      key: const ValueKey('send-hwid-to-providers'),
      secondary: SettingsLeadingIcon(
        icon: Icons.phonelink_lock_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(l10n.sendHwidToProvidersTitle),
      subtitle: Text(l10n.sendHwidToProvidersDescription),
      value: _value,
      onChanged: widget.onChanged == null
          ? null
          : (value) {
              widget.onChanged!(value);
              setState(() => _value = value);
            },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme preview card — wide, no radio/checkmark, just border highlight
// ---------------------------------------------------------------------------

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: .35),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: child,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primaryContainer.withValues(alpha: .3)
                    : Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini UI mockup — only header area (status bar + title + card). No VPN
// button, no navbar.
// ---------------------------------------------------------------------------

class _MockUI extends StatelessWidget {
  const _MockUI({required this.isDark, this.isAmoled = false});
  final bool isDark;
  final bool isAmoled;

  @override
  Widget build(BuildContext context) {
    final bg = isAmoled
        ? Colors.black
        : isDark
        ? const Color(0xFF1A1C1E)
        : const Color(0xFFF5F7FA);
    final card = isAmoled
        ? const Color(0xFF0D0D0D)
        : isDark
        ? const Color(0xFF232528)
        : const Color(0xFFE8EBF0);
    final text1 = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A);
    final text2 = isDark ? const Color(0xFF707070) : const Color(0xFF999999);

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status bar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _pill(12, 3, text2),
              const Gap(3),
              _pill(8, 3, text2),
              const Gap(3),
              _pill(16, 3, text2),
            ],
          ),
          const Gap(8),
          // App title
          _pill(48, 6, text1),
          const Gap(10),
          // Subscription card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pill(52, 5, text1),
                const Gap(5),
                _pill(32, 3, text2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(double w, double h, Color c) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(h)),
  );
}

// ---------------------------------------------------------------------------
// System preview — simple diagonal split: left=light, right=dark
// ---------------------------------------------------------------------------

class _SystemPreview extends StatelessWidget {
  const _SystemPreview();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full light background
        const Positioned.fill(child: _MockUI(isDark: false)),
        // Dark half clipped diagonally
        Positioned.fill(
          child: ClipPath(
            clipper: _DiagonalClipper(),
            child: const _MockUI(isDark: true),
          ),
        ),
      ],
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // Clip from top-center to bottom-right
    return Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.5, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ---------------------------------------------------------------------------
// Accent color swatch
// ---------------------------------------------------------------------------

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    this.previewColors,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final List<Color>? previewColors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = previewColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.onSurface : Colors.transparent,
            width: selected ? 3 : 0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: .4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (colors != null && colors.length >= 3)
              Row(
                children: [
                  for (final previewColor in colors.take(3))
                    Expanded(child: ColoredBox(color: previewColor)),
                ],
              ),
            if (selected)
              const Center(
                child: Icon(Icons.check_rounded, color: Colors.white, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Radio bottom sheet (for language)
// ---------------------------------------------------------------------------

class _RadioSheet<T> extends StatelessWidget {
  const _RadioSheet({
    required this.title,
    required this.current,
    required this.items,
  });

  final String title;
  final T current;
  final List<RadioChoice<T>> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: RadioGroup<T>(
        groupValue: current,
        onChanged: (value) => Navigator.of(context).pop(value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            for (final item in items)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(item.label),
                subtitle: item.subtitle == null ? null : Text(item.subtitle!),
                leading: Radio<T>(value: item.value),
                onTap: () => Navigator.of(context).pop(item.value),
              ),
          ],
        ),
      ),
    );
  }
}
