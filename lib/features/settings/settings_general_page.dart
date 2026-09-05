import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_notification_page.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
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

class SettingsGeneralPage extends StatelessWidget {
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
    this.currentSendHwidToProviders = false,
    this.onSendHwidToProvidersChanged,
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
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<AppThemePreference> onThemePreferenceChanged;
  final ValueChanged<String> onAccentColorChanged;
  final ValueChanged<bool> onHapticChanged;
  final ValueChanged<bool> onStatusNotificationChanged;
  final ValueChanged<NotificationTrafficDisplayMode>
  onNotificationTrafficDisplayModeChanged;
  final ValueChanged<int> onNotificationTrafficRefreshSecondsChanged;
  final ValueChanged<bool> onHideServerIpChanged;

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
        current: currentLocaleCode,
        items: [
          _RadioItem(value: 'system', label: l10n.languageSystem),
          _RadioItem(value: 'en', label: l10n.languageEnglish),
          _RadioItem(value: 'ru', label: l10n.languageRussian),
        ],
      ),
    );
    if (result != null) onLocaleChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.generalSectionTitle)),
      body: Theme(
        data: settingsTileTheme(context),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            0,
            progressiveHeaderTopPadding(context, 12),
            0,
            appBottomSafePadding(context, 24),
          ),
          children: [
            // ── Language ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SettingsTileGroup(
                children: [
                  ListTile(
                    leading: SettingsLeadingIcon(
                      icon: Icons.language_rounded,
                      color: cs.primary,
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(l10n.languageSettingTitle)),
                        const Gap(12),
                        Text(
                          _localeName(l10n, currentLocaleCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showLanguagePicker(context),
                  ),
                ],
              ),
            ),

            const Gap(settingsSectionGap),

            // ── Appearance — Theme ──
            _SectionLabel(label: l10n.appearanceTitle),
            const Gap(settingsSectionLabelGap),
            SizedBox(
              height: 128,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _ThemePreviewCard(
                    label: l10n.themeSystem,
                    selected:
                        currentThemePreference == AppThemePreference.system,
                    onTap: () =>
                        onThemePreferenceChanged(AppThemePreference.system),
                    child: const _SystemPreview(),
                  ),
                  const Gap(12),
                  _ThemePreviewCard(
                    label: l10n.themeLight,
                    selected:
                        currentThemePreference == AppThemePreference.light,
                    onTap: () =>
                        onThemePreferenceChanged(AppThemePreference.light),
                    child: const _MockUI(isDark: false),
                  ),
                  const Gap(12),
                  _ThemePreviewCard(
                    label: l10n.themeDark,
                    selected: currentThemePreference == AppThemePreference.dark,
                    onTap: () =>
                        onThemePreferenceChanged(AppThemePreference.dark),
                    child: const _MockUI(isDark: true),
                  ),
                  const Gap(12),
                  _ThemePreviewCard(
                    label: l10n.themeAmoled,
                    selected:
                        currentThemePreference == AppThemePreference.amoled,
                    onTap: () =>
                        onThemePreferenceChanged(AppThemePreference.amoled),
                    child: const _MockUI(isDark: true, isAmoled: true),
                  ),
                ],
              ),
            ),

            const Gap(settingsSectionGap),

            // ── Accent color (horizontal scroll) ──
            Builder(
              builder: (context) {
                final accentOptions = _buildAccentOptions(dynamicLightScheme);
                return SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: accentOptions.length,
                    separatorBuilder: (context, index) => const Gap(12),
                    itemBuilder: (context, index) {
                      final option = accentOptions[index];
                      return _AccentSwatch(
                        color: option.color,
                        previewColors: option.previewColors,
                        selected: currentAccentColorHex == option.hex,
                        onTap: () => onAccentColorChanged(option.hex),
                      );
                    },
                  ),
                );
              },
            ),

            const Gap(settingsSectionGap),

            // ── Everyday controls ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SettingsTileGroup(
                children: [
                  SwitchListTile(
                    secondary: SettingsLeadingIcon(
                      icon: Icons.vibration_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.hapticTitle),
                    value: currentHapticEnabled,
                    onChanged: onHapticChanged,
                  ),
                  ListTile(
                    key: const ValueKey('notification-settings-entry'),
                    leading: SettingsLeadingIcon(
                      icon: Icons.notifications_none_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.notificationSettingsTitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => SettingsNotificationPage(
                          currentStatusNotificationEnabled:
                              currentStatusNotificationEnabled,
                          currentTrafficDisplayMode:
                              currentNotificationTrafficDisplayMode,
                          currentTrafficRefreshSeconds:
                              currentNotificationTrafficRefreshSeconds,
                          onStatusNotificationChanged:
                              onStatusNotificationChanged,
                          onTrafficDisplayModeChanged:
                              onNotificationTrafficDisplayModeChanged,
                          onTrafficRefreshSecondsChanged:
                              onNotificationTrafficRefreshSecondsChanged,
                        ),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    secondary: SettingsLeadingIcon(
                      icon: Icons.visibility_off_rounded,
                      color: cs.primary,
                    ),
                    title: Text(l10n.hideServerIpTitle),
                    value: currentHideServerIp,
                    onChanged: onHideServerIpChanged,
                  ),
                  _HwidSharingTile(
                    value: currentSendHwidToProviders,
                    onChanged: onSendHwidToProvidersChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

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

class _RadioItem<T> {
  const _RadioItem({required this.value, required this.label, this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

class _RadioSheet<T> extends StatelessWidget {
  const _RadioSheet({
    required this.title,
    required this.current,
    required this.items,
  });

  final String title;
  final T current;
  final List<_RadioItem<T>> items;

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
