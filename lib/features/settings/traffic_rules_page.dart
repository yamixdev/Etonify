import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/network/remote_download_error_message.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/features/settings/developer_profile_sheet.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class TrafficRulesPage extends StatefulWidget {
  const TrafficRulesPage({
    super.key,
    required this.currentPreset,
    required this.currentStatus,
    required this.currentRussiaDnsDirectResolver,
    required this.onPrepareRuleData,
    required this.onPresetChanged,
    required this.onRussiaDnsDirectResolverChanged,
  });

  final TrafficRulePreset currentPreset;
  final RussiaRouteDataStatus currentStatus;
  final String currentRussiaDnsDirectResolver;
  final Future<RussiaRouteDataStatus> Function(TrafficRulePreset preset)
  onPrepareRuleData;
  final ValueChanged<TrafficRulePreset> onPresetChanged;
  final ValueChanged<String> onRussiaDnsDirectResolverChanged;

  @override
  State<TrafficRulesPage> createState() => _TrafficRulesPageState();
}

class _TrafficRulesPageState extends State<TrafficRulesPage> {
  late TrafficRulePreset _currentPreset;
  late RussiaRouteDataStatus _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currentPreset = widget.currentPreset;
    _status = widget.currentStatus;
    if (!_status.available) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _prepareBundledRuleData();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant TrafficRulesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy && !identical(oldWidget.currentStatus, widget.currentStatus)) {
      _status = widget.currentStatus;
    }
    if (!_busy && oldWidget.currentPreset != widget.currentPreset) {
      _currentPreset = widget.currentPreset;
    }
  }

  Future<void> _prepareBundledRuleData() async {
    if (_busy || _status.available) return;
    setState(() => _busy = true);
    try {
      final status = await widget.onPrepareRuleData(TrafficRulePreset.none);
      if (mounted) {
        setState(() => _status = status);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool _hasPreparedData(TrafficRulePreset preset) {
    return switch (preset) {
      TrafficRulePreset.none => true,
      TrafficRulePreset.russianServicesDirect => _status.available,
      TrafficRulePreset.aiViaVpn =>
        _status.available && (_status.aiServicesPath?.isNotEmpty ?? false),
      TrafficRulePreset.socialViaVpn =>
        _status.available && (_status.socialServicesPath?.isNotEmpty ?? false),
    };
  }

  Future<bool> _applyPreset(TrafficRulePreset preset) async {
    if (_busy) return false;
    if (preset == _currentPreset) return true;
    if (preset == TrafficRulePreset.none) {
      widget.onPresetChanged(preset);
      setState(() => _currentPreset = preset);
      return true;
    }

    setState(() => _busy = true);
    try {
      var status = _status;
      if (!_hasPreparedData(preset)) {
        status = await widget.onPrepareRuleData(preset);
      }
      if (!mounted) return false;
      if (!_hasPreparedDataFor(status, preset)) {
        throw StateError('traffic rule data is incomplete');
      }
      widget.onPresetChanged(preset);
      setState(() {
        _status = status;
        _currentPreset = preset;
      });
      return true;
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        AppNotice.show(
          context,
          remoteDownloadErrorMessage(l10n, error) ??
              l10n.trafficRulesPrepareFailed,
          tone: AppNoticeTone.error,
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  static bool _hasPreparedDataFor(
    RussiaRouteDataStatus status,
    TrafficRulePreset preset,
  ) {
    return switch (preset) {
      TrafficRulePreset.none => true,
      TrafficRulePreset.russianServicesDirect => status.available,
      TrafficRulePreset.aiViaVpn =>
        status.available && (status.aiServicesPath?.isNotEmpty ?? false),
      TrafficRulePreset.socialViaVpn =>
        status.available && (status.socialServicesPath?.isNotEmpty ?? false),
    };
  }

  Future<TrafficRulePreset?> _openDetails(
    TrafficRulePresetDefinition definition,
  ) async {
    final result = await Navigator.of(context).push<TrafficRulePreset>(
      _trafficRuleRoute(
        _TrafficRuleDetailsPage(
          definition: definition,
          selectedPreset: _currentPreset,
          onApply: _applyPreset,
          currentRussiaDnsDirectResolver: widget.currentRussiaDnsDirectResolver,
          onRussiaDnsDirectResolverChanged:
              widget.onRussiaDnsDirectResolverChanged,
        ),
      ),
    );
    if (result != null && mounted && result != _currentPreset) {
      setState(() => _currentPreset = result);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final activeDefinition = trafficRulePresetDefinitionFor(_currentPreset);
    final enabled = _currentPreset != TrafficRulePreset.none;

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.trafficRulesTitle)),
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
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                secondary: SettingsLeadingIcon(
                  icon: Icons.alt_route_rounded,
                  color: cs.primary,
                ),
                title: Text(l10n.trafficRulesUsePresetTitle),
                subtitle: Text(
                  activeDefinition == null
                      ? l10n.trafficRulesUsePresetSubtitle
                      : _titleFor(l10n, activeDefinition.preset),
                ),
                value: enabled,
                onChanged: _busy
                    ? null
                    : (value) {
                        if (!value) {
                          _applyPreset(TrafficRulePreset.none);
                        } else {
                          _applyPreset(TrafficRulePreset.russianServicesDirect);
                        }
                      },
              ),
            ),
            if (activeDefinition != null) ...[
              const Gap(settingsIslandGap),
              _ActiveTrafficRuleCard(
                definition: activeDefinition,
                title: _titleFor(l10n, activeDefinition.preset),
                subtitle: _subtitleFor(l10n, activeDefinition.preset),
                onInfoTap: () => _openDetails(activeDefinition),
              ),
            ],
            const Gap(settingsIslandGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.trafficRulesQuickSelection,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Gap(settingsSectionLabelGap),
            for (final definition in trafficRulePresetDefinitions.values) ...[
              _TrafficRuleQuickCard(
                definition: definition,
                title: _titleFor(l10n, definition.preset),
                subtitle: _subtitleFor(l10n, definition.preset),
                selected: definition.preset == _currentPreset,
                busy: _busy,
                onChoose: () => _applyPreset(definition.preset),
                onInfoTap: () => _openDetails(definition),
              ),
              const Gap(settingsIslandGap),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveTrafficRuleCard extends StatelessWidget {
  const _ActiveTrafficRuleCard({
    required this.definition,
    required this.title,
    required this.subtitle,
    required this.onInfoTap,
  });

  final TrafficRulePresetDefinition definition;
  final String title;
  final String subtitle;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = _accentFor(cs, definition.preset);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: .16), cs.surfaceContainerHigh],
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          leading: _PresetGlyph(preset: definition.preset, accent: accent),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: IconButton(
            tooltip: AppLocalizations.of(context).trafficRulesDetails,
            onPressed: onInfoTap,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ),
      ),
    );
  }
}

class _TrafficRuleQuickCard extends StatelessWidget {
  const _TrafficRuleQuickCard({
    required this.definition,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.busy,
    required this.onChoose,
    required this.onInfoTap,
  });

  final TrafficRulePresetDefinition definition;
  final String title;
  final String subtitle;
  final bool selected;
  final bool busy;
  final VoidCallback onChoose;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = _accentFor(cs, definition.preset);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onChoose,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              _PresetGlyph(preset: definition.preset, accent: accent),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle_rounded, color: accent),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).trafficRulesDetails,
                onPressed: onInfoTap,
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrafficRuleDetailsPage extends StatefulWidget {
  const _TrafficRuleDetailsPage({
    required this.definition,
    required this.selectedPreset,
    required this.onApply,
    required this.currentRussiaDnsDirectResolver,
    required this.onRussiaDnsDirectResolverChanged,
  });

  final TrafficRulePresetDefinition definition;
  final TrafficRulePreset selectedPreset;
  final Future<bool> Function(TrafficRulePreset preset) onApply;
  final String currentRussiaDnsDirectResolver;
  final ValueChanged<String> onRussiaDnsDirectResolverChanged;

  @override
  State<_TrafficRuleDetailsPage> createState() =>
      _TrafficRuleDetailsPageState();
}

class _TrafficRuleDetailsPageState extends State<_TrafficRuleDetailsPage> {
  bool _busy = false;
  late final TextEditingController _russiaDnsController;
  late final FocusNode _russiaDnsFocusNode;

  bool get _selected => widget.selectedPreset == widget.definition.preset;
  bool get _usesRussiaDirectDns =>
      widget.definition.preset == TrafficRulePreset.russianServicesDirect;

  @override
  void initState() {
    super.initState();
    _russiaDnsController = TextEditingController(
      text: _dnsResolverFieldText(widget.currentRussiaDnsDirectResolver),
    );
    _russiaDnsFocusNode = FocusNode(debugLabel: 'russiaTrafficRuleDns')
      ..addListener(_handleRussiaDnsFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _TrafficRuleDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_russiaDnsFocusNode.hasFocus) {
      return;
    }
    final current = normalizeDnsResolverInput(_russiaDnsController.text);
    final updated = normalizeDnsResolverInput(
      widget.currentRussiaDnsDirectResolver,
    );
    if (current != updated) {
      _russiaDnsController.text = _dnsResolverFieldText(
        widget.currentRussiaDnsDirectResolver,
      );
    }
  }

  @override
  void dispose() {
    _russiaDnsFocusNode
      ..removeListener(_handleRussiaDnsFocusChanged)
      ..dispose();
    _russiaDnsController.dispose();
    super.dispose();
  }

  void _handleRussiaDnsFocusChanged() {
    if (!_russiaDnsFocusNode.hasFocus) {
      _commitRussiaDnsResolver();
    }
  }

  void _commitRussiaDnsResolver() {
    final value = _russiaDnsController.text.trim();
    if (value.isEmpty) {
      _russiaDnsController.text = _dnsResolverFieldText(
        defaultRussiaDnsDirectResolver,
      );
      widget.onRussiaDnsDirectResolverChanged(defaultRussiaDnsDirectResolver);
      return;
    }
    if (normalizeDnsResolverInput(value) !=
        normalizeDnsResolverInput(widget.currentRussiaDnsDirectResolver)) {
      widget.onRussiaDnsDirectResolverChanged(value);
    }
  }

  Future<void> _apply() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.onApply(widget.definition.preset);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result) {
      Navigator.of(context).pop(widget.definition.preset);
    }
  }

  Future<void> _disable() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.onApply(TrafficRulePreset.none);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result) {
      Navigator.of(context).pop(TrafficRulePreset.none);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = _accentFor(cs, widget.definition.preset);
    final preview = _previewFor(l10n, widget.definition.preset);
    final author = AppDevelopers.yamixdev(l10n);

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.trafficRulesDetails)),
      body: Theme(
        data: settingsTileTheme(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    settingsScreenPadding.left,
                    progressiveHeaderTopPadding(
                      context,
                      settingsScreenPadding.top,
                    ),
                    settingsScreenPadding.right,
                    16,
                  ),
                  children: [
                    _RuleHero(
                      preset: widget.definition.preset,
                      accent: accent,
                      title: _titleFor(l10n, widget.definition.preset),
                      selected: _selected,
                    ),
                    const Gap(settingsIslandGap),
                    _DetailsSection(
                      label: l10n.trafficRulesDescription,
                      child: Text(
                        _subtitleFor(l10n, widget.definition.preset),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.35,
                        ),
                      ),
                    ),
                    const Gap(settingsIslandGap),
                    _DetailsSection(
                      label: l10n.trafficRulesAuthor,
                      child: _DeveloperAuthorButton(
                        profile: author,
                        onTap: () => showDeveloperProfileSheet(context, author),
                      ),
                    ),
                    const Gap(settingsIslandGap),
                    _DetailsSection(
                      label: l10n.trafficRulesRoutingDomains,
                      child: _RuleRoutePreview(
                        title: preview.title,
                        icon: preview.icon,
                        color: accent,
                        items: preview.items,
                      ),
                    ),
                    const Gap(settingsIslandGap),
                    _DetailsSection(
                      label: l10n.trafficRulesSettings,
                      child: Column(
                        children: [
                          _RuleSettingRow(
                            icon: Icons.public_rounded,
                            title: l10n.trafficRulesDefaultRoute,
                            subtitle: _defaultRouteLabel(
                              l10n,
                              widget.definition.defaultRoute,
                            ),
                            enabled: true,
                            accent: accent,
                          ),
                          const Divider(height: 24),
                          _RuleSettingRow(
                            icon: Icons.home_work_outlined,
                            title: l10n.trafficRulesLocalNetwork,
                            subtitle: l10n.trafficRulesDirect,
                            enabled: true,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                    if (_usesRussiaDirectDns) ...[
                      const Gap(settingsIslandGap),
                      _DetailsSection(
                        label: l10n.trafficRulesRuDnsTitle,
                        child: TextField(
                          controller: _russiaDnsController,
                          focusNode: _russiaDnsFocusNode,
                          textInputAction: TextInputAction.done,
                          onTapOutside: (_) => _russiaDnsFocusNode.unfocus(),
                          onSubmitted: (_) => _russiaDnsFocusNode.unfocus(),
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.dnsResolverTitle,
                            helperText: l10n.trafficRulesRuDnsSubtitle,
                            hintText: defaultRussiaDnsDirectResolver,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: _selected
                      ? OutlinedButton.icon(
                          onPressed: _busy ? null : _disable,
                          icon: _busy
                              ? const _ButtonProgress()
                              : const Icon(Icons.power_settings_new_rounded),
                          label: Text(l10n.trafficRulesDisablePreset),
                        )
                      : FilledButton.icon(
                          onPressed: _busy ? null : _apply,
                          icon: _busy
                              ? const _ButtonProgress()
                              : const Icon(Icons.check_rounded),
                          label: Text(l10n.trafficRulesUsePresetAction),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleHero extends StatelessWidget {
  const _RuleHero({
    required this.preset,
    required this.accent,
    required this.title,
    required this.selected,
  });

  final TrafficRulePreset preset;
  final Color accent;
  final String title;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onAccent = _onAccentFor(cs, preset);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: .95),
            accent.withValues(alpha: .64),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .25),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _PresetGlyph(preset: preset, accent: onAccent),
          const Gap(14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: onAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Gap(6),
              Icon(Icons.verified_rounded, color: onAccent, size: 22),
            ],
          ),
          if (selected) ...[
            const Gap(10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: onAccent.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                AppLocalizations.of(context).trafficRulesChosen,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: onAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeveloperAuthorButton extends StatelessWidget {
  const _DeveloperAuthorButton({required this.profile, required this.onTap});

  final DeveloperProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.surfaceContainerHighest,
              backgroundImage: ResizeImage(
                AssetImage(profile.avatarAsset),
                width: 128,
                height: 128,
              ),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Gap(5),
                      Icon(Icons.verified_rounded, color: cs.primary, size: 19),
                    ],
                  ),
                  const Gap(2),
                  Text(
                    profile.role,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: .45,
            ),
          ),
        ),
        const Gap(8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ],
    );
  }
}

class _RuleRoutePreview extends StatelessWidget {
  const _RuleRoutePreview({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const Gap(10),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const Gap(14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(item, style: theme.textTheme.labelLarge),
              ),
          ],
        ),
      ],
    );
  }
}

class _RuleSettingRow extends StatelessWidget {
  const _RuleSettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(2),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Icon(
          enabled ? Icons.check_box_rounded : Icons.check_box_outline_blank,
          color: enabled ? accent : cs.outline,
        ),
      ],
    );
  }
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

class _PresetGlyph extends StatelessWidget {
  const _PresetGlyph({required this.preset, required this.accent});

  final TrafficRulePreset preset;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final icon = switch (preset) {
      TrafficRulePreset.russianServicesDirect => null,
      TrafficRulePreset.aiViaVpn => Icons.auto_awesome_rounded,
      TrafficRulePreset.socialViaVpn => Icons.share_rounded,
      TrafficRulePreset.none => Icons.remove_rounded,
    };
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: icon == null
          ? const Center(child: Text('🇷🇺', style: TextStyle(fontSize: 28)))
          : Icon(icon, color: accent, size: 28),
    );
  }
}

class _RulePreview {
  const _RulePreview({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;
}

String _dnsResolverFieldText(String value) {
  final trimmed = value.trim();
  if (!trimmed.toLowerCase().startsWith('udp://')) {
    return trimmed;
  }
  final endpoint = trimmed.substring('udp://'.length);
  if (endpoint.startsWith('[') && endpoint.endsWith(']')) {
    return endpoint.substring(1, endpoint.length - 1);
  }
  return endpoint;
}

_RulePreview _previewFor(AppLocalizations l10n, TrafficRulePreset preset) {
  return switch (preset) {
    TrafficRulePreset.russianServicesDirect => _RulePreview(
      title: l10n.trafficRulesDirect,
      icon: Icons.arrow_upward_rounded,
      items: [
        'VK',
        'Yandex',
        'Ozon',
        'Wildberries',
        l10n.trafficRulesLocalNetwork,
      ],
    ),
    TrafficRulePreset.aiViaVpn => _RulePreview(
      title: l10n.trafficRulesVpn,
      icon: Icons.vpn_lock_rounded,
      items: ['OpenAI', 'ChatGPT', 'Claude', 'Gemini'],
    ),
    TrafficRulePreset.socialViaVpn => _RulePreview(
      title: l10n.trafficRulesVpn,
      icon: Icons.vpn_lock_rounded,
      items: [
        'Telegram',
        'WhatsApp',
        'Discord',
        'TikTok',
        'Meta',
        'Google',
        'GitHub',
        'Spotify',
        'VK',
      ],
    ),
    TrafficRulePreset.none => const _RulePreview(
      title: '',
      icon: Icons.remove_rounded,
      items: <String>[],
    ),
  };
}

Color _accentFor(ColorScheme cs, TrafficRulePreset preset) => switch (preset) {
  TrafficRulePreset.russianServicesDirect => const Color(0xFF2F63CC),
  TrafficRulePreset.aiViaVpn => cs.tertiary,
  TrafficRulePreset.socialViaVpn => cs.secondary,
  TrafficRulePreset.none => cs.outline,
};

Color _onAccentFor(ColorScheme cs, TrafficRulePreset preset) =>
    switch (preset) {
      TrafficRulePreset.russianServicesDirect => Colors.white,
      TrafficRulePreset.aiViaVpn => cs.onTertiary,
      TrafficRulePreset.socialViaVpn => cs.onSecondary,
      TrafficRulePreset.none => cs.onSurface,
    };

String _titleFor(AppLocalizations l10n, TrafficRulePreset preset) {
  return switch (preset) {
    TrafficRulePreset.none => l10n.trafficRulesNone,
    TrafficRulePreset.russianServicesDirect => l10n.trafficRulesRussianTitle,
    TrafficRulePreset.aiViaVpn => l10n.trafficRulesAiTitle,
    TrafficRulePreset.socialViaVpn => l10n.trafficRulesSocialTitle,
  };
}

String _subtitleFor(AppLocalizations l10n, TrafficRulePreset preset) {
  return switch (preset) {
    TrafficRulePreset.none => l10n.trafficRulesNone,
    TrafficRulePreset.russianServicesDirect => l10n.trafficRulesRussianSubtitle,
    TrafficRulePreset.aiViaVpn => l10n.trafficRulesAiSubtitle,
    TrafficRulePreset.socialViaVpn => l10n.trafficRulesSocialSubtitle,
  };
}

String _defaultRouteLabel(
  AppLocalizations l10n,
  TrafficRuleDefaultRoute route,
) => route == TrafficRuleDefaultRoute.direct
    ? l10n.trafficRulesDirect
    : l10n.trafficRulesVpn;

PageRoute<T> _trafficRuleRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, _, _) => page,
  transitionDuration: const Duration(milliseconds: 260),
  reverseTransitionDuration: const Duration(milliseconds: 200),
  transitionsBuilder: (_, animation, secondaryAnimation, child) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: ScaleTransition(
        scale: Tween<double>(begin: .985, end: 1).animate(curve),
        child: child,
      ),
    );
  },
);
