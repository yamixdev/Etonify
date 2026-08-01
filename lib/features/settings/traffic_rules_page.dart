import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/routing/russia_route_data_service.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class TrafficRulesPage extends StatefulWidget {
  const TrafficRulesPage({
    super.key,
    required this.currentPreset,
    required this.currentStatus,
    required this.onPrepareRuleData,
    required this.onDeleteRuleData,
    required this.onPresetChanged,
  });

  final TrafficRulePreset currentPreset;
  final RussiaRouteDataStatus currentStatus;
  final Future<RussiaRouteDataStatus> Function(TrafficRulePreset preset)
  onPrepareRuleData;
  final Future<RussiaRouteDataStatus> Function() onDeleteRuleData;
  final ValueChanged<TrafficRulePreset> onPresetChanged;

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

  Future<void> _selectPreset(TrafficRulePreset preset) async {
    if (_busy || preset == _currentPreset) {
      return;
    }
    if (preset == TrafficRulePreset.none) {
      widget.onPresetChanged(preset);
      setState(() => _currentPreset = preset);
      return;
    }

    setState(() => _busy = true);
    try {
      var status = _status;
      if (!_hasPreparedData(preset)) {
        status = await widget.onPrepareRuleData(preset);
      }
      if (!mounted) return;
      if (!_hasPreparedDataFor(status, preset)) {
        throw StateError('traffic rule data is incomplete');
      }
      widget.onPresetChanged(preset);
      setState(() {
        _status = status;
        _currentPreset = preset;
      });
    } catch (_) {
      if (mounted) {
        AppNotice.show(
          context,
          AppLocalizations.of(context).trafficRulesPrepareFailed,
          tone: AppNoticeTone.error,
        );
      }
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

  Future<void> _updateRuleData() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final status = await widget.onPrepareRuleData(_currentPreset);
      if (!mounted) return;
      setState(() => _status = status);
    } catch (_) {
      if (mounted) {
        AppNotice.show(
          context,
          AppLocalizations.of(context).trafficRulesPrepareFailed,
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteRuleData() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final status = await widget.onDeleteRuleData();
      if (!mounted) return;
      widget.onPresetChanged(TrafficRulePreset.none);
      setState(() {
        _status = status;
        _currentPreset = TrafficRulePreset.none;
      });
    } catch (_) {
      if (mounted) {
        AppNotice.show(
          context,
          AppLocalizations.of(context).trafficRulesPrepareFailed,
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openDetails(TrafficRulePresetDefinition definition) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _TrafficRuleDetailsPage(
          definition: definition,
          selected: definition.preset == _currentPreset,
          busy: _busy,
          onSelect: () async {
            await _selectPreset(definition.preset);
            if (mounted && definition.preset == _currentPreset) {
              Navigator.of(this.context).pop();
            }
          },
        ),
      ),
    );
  }

  void _showVerifiedInfo() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.trafficRulesVerified,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Gap(8),
              Text(l10n.trafficRulesVerifiedInfo),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final activeDefinition = trafficRulePresetDefinitionFor(_currentPreset);
    final ruleDataReady = _status.available;

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
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: SettingsLeadingIcon(
                  icon: Icons.alt_route_rounded,
                  color: cs.primary,
                ),
                title: Text(l10n.trafficRulesCurrentLabel),
                subtitle: Text(
                  activeDefinition == null
                      ? l10n.trafficRulesNone
                      : _titleFor(l10n, activeDefinition.preset),
                ),
                trailing: activeDefinition == null
                    ? const Icon(Icons.remove_rounded)
                    : IconButton(
                        tooltip: l10n.trafficRulesDetails,
                        onPressed: () => _openDetails(activeDefinition),
                        icon: const Icon(Icons.info_outline_rounded),
                      ),
              ),
            ),
            const Gap(settingsIslandGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.trafficRulesDeveloperSection,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Gap(settingsSectionLabelGap),
            for (final definition in trafficRulePresetDefinitions.values) ...[
              _TrafficRulePresetCard(
                definition: definition,
                title: _titleFor(l10n, definition.preset),
                subtitle: _subtitleFor(l10n, definition.preset),
                selected: definition.preset == _currentPreset,
                onTap: () => _openDetails(definition),
              ),
              const Gap(settingsIslandGap),
            ],
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          ruleDataReady
                              ? Icons.check_circle_outline_rounded
                              : Icons.cloud_download_outlined,
                          color: ruleDataReady
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        const Gap(10),
                        Expanded(
                          child: Text(
                            ruleDataReady
                                ? l10n.trafficRulesDataReady
                                : l10n.trafficRulesDataMissing,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    Text(
                      l10n.trafficRulesAvailableOffline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const Gap(12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _updateRuleData,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: Text(
                            _busy
                                ? l10n.trafficRulesPreparing
                                : l10n.trafficRulesUpdateData,
                          ),
                        ),
                        if (ruleDataReady)
                          TextButton(
                            onPressed: _busy ? null : _deleteRuleData,
                            child: Text(l10n.trafficRulesDeleteData),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Gap(settingsIslandGap),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(l10n.trafficRulesOnlyOne),
                trailing: IconButton(
                  tooltip: l10n.trafficRulesVerified,
                  onPressed: _showVerifiedInfo,
                  icon: const Icon(Icons.verified_outlined),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficRulePresetCard extends StatelessWidget {
  const _TrafficRulePresetCard({
    required this.definition,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final TrafficRulePresetDefinition definition;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsLeadingIcon(
                icon: _iconFor(definition.preset),
                color: selected ? cs.primary : cs.secondary,
              ),
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle_rounded, color: cs.primary),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const Gap(10),
                    Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: cs.primary,
                        ),
                        const Gap(6),
                        Text(
                          'yamixdev',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrafficRuleDetailsPage extends StatelessWidget {
  const _TrafficRuleDetailsPage({
    required this.definition,
    required this.selected,
    required this.busy,
    required this.onSelect,
  });

  final TrafficRulePresetDefinition definition;
  final bool selected;
  final bool busy;
  final Future<void> Function() onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = _titleFor(l10n, definition.preset);
    final subtitle = _subtitleFor(l10n, definition.preset);
    final throughVpn = _throughVpnItems(l10n, definition.preset);
    final direct = _directItems(l10n, definition.preset);

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
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SettingsLeadingIcon(
                                  icon: _iconFor(definition.preset),
                                  color: cs.primary,
                                ),
                                const Gap(12),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Gap(14),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const Gap(14),
                            Row(
                              children: [
                                Icon(Icons.verified_rounded, color: cs.primary),
                                const Gap(8),
                                Expanded(
                                  child: Text(l10n.trafficRulesVerifiedInfo),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(settingsIslandGap),
                    _RuleDirectionCard(
                      title: l10n.trafficRulesVpn,
                      icon: Icons.vpn_lock_rounded,
                      color: cs.primary,
                      items: throughVpn,
                    ),
                    const Gap(settingsIslandGap),
                    _RuleDirectionCard(
                      title: l10n.trafficRulesDirect,
                      icon: Icons.language_rounded,
                      color: cs.secondary,
                      items: direct,
                    ),
                    const Gap(settingsIslandGap),
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.home_work_outlined),
                        title: Text(l10n.trafficRulesLocalNetwork),
                        subtitle: Text(
                          '${l10n.trafficRulesDefaultRoute}: ${_defaultRouteLabel(l10n, definition.defaultRoute)}',
                        ),
                      ),
                    ),
                    const Gap(settingsIslandGap),
                    Text(
                      l10n.trafficRulesOnlyOne,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: selected
                      ? FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: Text(l10n.trafficRulesChosen),
                        )
                      : FilledButton.icon(
                          onPressed: busy ? null : onSelect,
                          icon: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            busy
                                ? l10n.trafficRulesPreparing
                                : l10n.trafficRulesChoose,
                          ),
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

class _RuleDirectionCard extends StatelessWidget {
  const _RuleDirectionCard({
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const Gap(10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Gap(12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $item'),
              ),
          ],
        ),
      ),
    );
  }
}

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

IconData _iconFor(TrafficRulePreset preset) {
  return switch (preset) {
    TrafficRulePreset.none => Icons.remove_rounded,
    TrafficRulePreset.russianServicesDirect => Icons.public_rounded,
    TrafficRulePreset.aiViaVpn => Icons.auto_awesome_rounded,
    TrafficRulePreset.socialViaVpn => Icons.forum_rounded,
  };
}

String _defaultRouteLabel(
  AppLocalizations l10n,
  TrafficRuleDefaultRoute route,
) {
  return route == TrafficRuleDefaultRoute.direct
      ? l10n.trafficRulesDirect
      : l10n.trafficRulesVpn;
}

List<String> _throughVpnItems(AppLocalizations l10n, TrafficRulePreset preset) {
  return switch (preset) {
    TrafficRulePreset.russianServicesDirect => [
      l10n.trafficRulesRuleCount(2),
      l10n.trafficRulesDefaultRoute,
    ],
    TrafficRulePreset.aiViaVpn => ['OpenAI', 'ChatGPT', 'Claude', 'Gemini'],
    TrafficRulePreset.socialViaVpn => [
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
    TrafficRulePreset.none => const <String>[],
  };
}

List<String> _directItems(AppLocalizations l10n, TrafficRulePreset preset) {
  return switch (preset) {
    TrafficRulePreset.russianServicesDirect => [
      'VK',
      'Yandex',
      'Ozon',
      'Wildberries',
      l10n.trafficRulesLocalNetwork,
    ],
    TrafficRulePreset.aiViaVpn || TrafficRulePreset.socialViaVpn => [
      l10n.trafficRulesDefaultRoute,
      l10n.trafficRulesLocalNetwork,
    ],
    TrafficRulePreset.none => const <String>[],
  };
}
