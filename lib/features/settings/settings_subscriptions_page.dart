import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/subscription/happ_crypt5_local.dart';
import 'package:meow_client/data/subscription/happ_crypto_link.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsSubscriptionsPage extends StatefulWidget {
  const SettingsSubscriptionsPage({
    super.key,
    required this.currentConfig,
    required this.currentLocationLookupLimit,
    required this.currentLocationLookupTimeoutSeconds,
    required this.currentLocationLookupConcurrency,
    required this.onChanged,
    required this.onLocationLookupLimitChanged,
    required this.onLocationLookupTimeoutSecondsChanged,
    required this.onLocationLookupConcurrencyChanged,
    this.androidIdLoader,
    this.happSupportLoader,
  });

  final UrlTestConfig currentConfig;
  final int currentLocationLookupLimit;
  final int currentLocationLookupTimeoutSeconds;
  final int currentLocationLookupConcurrency;
  final ValueChanged<UrlTestConfig> onChanged;
  final ValueChanged<int> onLocationLookupLimitChanged;
  final ValueChanged<int> onLocationLookupTimeoutSecondsChanged;
  final ValueChanged<int> onLocationLookupConcurrencyChanged;
  final Future<String> Function()? androidIdLoader;
  final Future<HappCrypt5Support> Function()? happSupportLoader;

  @override
  State<SettingsSubscriptionsPage> createState() =>
      _SettingsSubscriptionsPageState();
}

class _SettingsSubscriptionsPageState extends State<SettingsSubscriptionsPage> {
  late final TextEditingController _urlController;
  String _androidId = '';
  bool _loadingAndroidId = true;
  bool _loadingHappSupport = true;
  bool _happCrypt5Supported = false;
  late int _intervalSeconds;
  late int _timeoutSeconds;
  late int _concurrency;
  late int _unavailableCheckIntervalSeconds;
  late int _locationLookupLimit;
  late int _locationLookupTimeoutSeconds;
  late int _locationLookupConcurrency;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.currentConfig.url ?? '',
    );
    _intervalSeconds = (widget.currentConfig.intervalSeconds ?? 1800)
        .clamp(30, 3600)
        .toInt();
    _timeoutSeconds = (widget.currentConfig.timeoutSeconds ?? 15)
        .clamp(1, 60)
        .toInt();
    _concurrency = (widget.currentConfig.concurrency ?? 8).clamp(1, 8).toInt();
    _unavailableCheckIntervalSeconds =
        (widget.currentConfig.unavailableCheckIntervalSeconds ?? 120)
            .clamp(120, 3600)
            .toInt();
    _locationLookupLimit = widget.currentLocationLookupLimit
        .clamp(0, 50)
        .toInt();
    _locationLookupTimeoutSeconds = widget.currentLocationLookupTimeoutSeconds
        .clamp(2, 30)
        .toInt();
    _locationLookupConcurrency = widget.currentLocationLookupConcurrency
        .clamp(1, 60)
        .toInt();
    _loadAndroidId();
    _loadHappSupport();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadAndroidId() async {
    var androidId = '';
    try {
      androidId =
          await (widget.androidIdLoader?.call() ??
              SingboxRuntime.instance.getAndroidId());
    } catch (error) {
      AppLogStore.warning('device info', 'Unable to read Android ID: $error');
    }
    if (!mounted) return;
    setState(() {
      _androidId = androidId.trim();
      _loadingAndroidId = false;
    });
  }

  Future<void> _loadHappSupport() async {
    late HappCrypt5Support support;
    try {
      support =
          await (widget.happSupportLoader?.call() ??
              HappCryptoLinkDecoder.getCrypt5Support());
    } catch (error) {
      support = HappCrypt5Support(
        supported: false,
        detail: 'Happ crypt5 compatibility check failed: $error',
      );
    }
    if (support.supported) {
      AppLogStore.info('happ crypto', support.detail);
    } else {
      AppLogStore.warning('happ crypto', support.detail);
    }
    if (!mounted) return;
    setState(() {
      _happCrypt5Supported = support.supported;
      _loadingHappSupport = false;
    });
  }

  void _commitUrlTest() {
    final url = _urlController.text.trim();
    widget.onChanged(
      UrlTestConfig(
        url: url.isEmpty ? null : url,
        intervalSeconds: _intervalSeconds,
        timeoutSeconds: _timeoutSeconds,
        concurrency: _concurrency,
        unavailableCheckIntervalSeconds: _unavailableCheckIntervalSeconds,
      ),
    );
  }

  String _urlValue(AppLocalizations l10n) {
    final value = _urlController.text.trim();
    if (value.isEmpty) return l10n.proxyAutomaticSelectionLabel;
    final uri = Uri.tryParse(value);
    final host = uri?.host.trim() ?? '';
    return host.isEmpty ? value : host;
  }

  Future<void> _editUrl() async {
    final l10n = AppLocalizations.of(context);
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _UrlTestEditorSheet(
        initialValue: _urlController.text,
        title: l10n.urlTestUrlTitle,
        description: l10n.urlTestUrlSubtitle,
        saveLabel: l10n.saveAction,
      ),
    );
    if (!mounted || value == null) return;
    final normalized = value.trim();
    if (normalized == _urlController.text.trim()) return;
    setState(() => _urlController.text = normalized);
    _commitUrlTest();
  }

  Future<void> _editNumber({
    required String title,
    required String description,
    required int currentValue,
    required int min,
    required int max,
    required int divisions,
    required String Function(int value) valueLabel,
    required ValueChanged<int> onSelected,
  }) async {
    final l10n = AppLocalizations.of(context);
    final value = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SliderSettingSheet(
        title: title,
        description: description,
        initialValue: currentValue,
        min: min,
        max: max,
        divisions: divisions,
        valueLabel: valueLabel,
        saveLabel: l10n.saveAction,
      ),
    );
    if (!mounted || value == null || value == currentValue) return;
    onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final happStatusColor = _loadingHappSupport
        ? cs.onSurfaceVariant
        : _happCrypt5Supported
        ? const Color(0xFF1F9D63)
        : cs.error;
    final happStatusText = _loadingHappSupport
        ? l10n.loading
        : _happCrypt5Supported
        ? l10n.happCrypt5Supported
        : l10n.happCrypt5Unsupported;

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.settingsProfilesChecksTitle)),
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
            _SettingsSectionLabel(label: l10n.urlTestTitle),
            const Gap(settingsSectionLabelGap),
            SettingsTileGroup(
              dividerIndent: 64,
              children: [
                _CompactSettingTile(
                  key: const ValueKey('urltest-url-setting'),
                  icon: Icons.link_rounded,
                  color: cs.primary,
                  title: l10n.urlTestUrlTitle,
                  value: _urlValue(l10n),
                  onTap: _editUrl,
                ),
                _CompactSettingTile(
                  key: const ValueKey('urltest-interval-setting'),
                  icon: Icons.schedule_rounded,
                  color: cs.primary,
                  title: l10n.urlTestIntervalCompactTitle,
                  value: l10n.settingsSecondsShort(_intervalSeconds),
                  onTap: () => _editNumber(
                    title: l10n.urlTestIntervalTitle,
                    description: l10n.urlTestIntervalSubtitle,
                    currentValue: _intervalSeconds,
                    min: 30,
                    max: 3600,
                    divisions: 119,
                    valueLabel: l10n.settingsSecondsShort,
                    onSelected: (value) {
                      setState(() => _intervalSeconds = value);
                      _commitUrlTest();
                    },
                  ),
                ),
                _CompactSettingTile(
                  key: const ValueKey('urltest-timeout-setting'),
                  icon: Icons.timer_outlined,
                  color: cs.primary,
                  title: l10n.urlTestTimeoutCompactTitle,
                  value: l10n.settingsSecondsShort(_timeoutSeconds),
                  onTap: () => _editNumber(
                    title: l10n.urlTestTimeoutTitle,
                    description: l10n.urlTestTimeoutSubtitle,
                    currentValue: _timeoutSeconds,
                    min: 1,
                    max: 60,
                    divisions: 59,
                    valueLabel: l10n.settingsSecondsShort,
                    onSelected: (value) {
                      setState(() => _timeoutSeconds = value);
                      _commitUrlTest();
                    },
                  ),
                ),
                _CompactSettingTile(
                  key: const ValueKey('urltest-concurrency-setting'),
                  icon: Icons.dynamic_feed_rounded,
                  color: cs.primary,
                  title: l10n.urlTestConcurrencyTitle,
                  value: '$_concurrency',
                  onTap: () => _editNumber(
                    title: l10n.urlTestConcurrencyTitle,
                    description: l10n.urlTestConcurrencySubtitle,
                    currentValue: _concurrency,
                    min: 1,
                    max: 8,
                    divisions: 7,
                    valueLabel: (value) => '$value',
                    onSelected: (value) {
                      setState(() => _concurrency = value);
                      _commitUrlTest();
                    },
                  ),
                ),
                _CompactSettingTile(
                  key: const ValueKey('urltest-retry-setting'),
                  icon: Icons.refresh_rounded,
                  color: cs.primary,
                  title: l10n.urlTestSingleRetestCompactTitle,
                  value: l10n.settingsSecondsShort(
                    _unavailableCheckIntervalSeconds,
                  ),
                  onTap: () => _editNumber(
                    title: l10n.urlTestSingleRetestTitle,
                    description: l10n.urlTestSingleRetestSubtitle,
                    currentValue: _unavailableCheckIntervalSeconds,
                    min: 120,
                    max: 3600,
                    divisions: 58,
                    valueLabel: l10n.settingsSecondsShort,
                    onSelected: (value) {
                      setState(() => _unavailableCheckIntervalSeconds = value);
                      _commitUrlTest();
                    },
                  ),
                ),
              ],
            ),
            const Gap(settingsSectionGap),
            _SettingsSectionLabel(label: l10n.locationLookupTitle),
            const Gap(settingsSectionLabelGap),
            SettingsTileGroup(
              dividerIndent: 64,
              children: [
                _CompactSettingTile(
                  key: const ValueKey('location-limit-setting'),
                  icon: Icons.travel_explore_rounded,
                  color: cs.tertiary,
                  title: l10n.locationLookupLimitTitle,
                  value: _locationLookupLimit == 0
                      ? l10n.disabledLabel
                      : '$_locationLookupLimit',
                  onTap: () => _editNumber(
                    title: l10n.locationLookupLimitTitle,
                    description: l10n.locationLookupLimitSubtitle,
                    currentValue: _locationLookupLimit,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    valueLabel: (value) =>
                        value == 0 ? l10n.disabledLabel : '$value',
                    onSelected: (value) {
                      setState(() => _locationLookupLimit = value);
                      widget.onLocationLookupLimitChanged(value);
                    },
                  ),
                ),
                _CompactSettingTile(
                  key: const ValueKey('location-timeout-setting'),
                  icon: Icons.hourglass_bottom_rounded,
                  color: cs.tertiary,
                  title: l10n.locationLookupTimeoutTitle,
                  value: l10n.settingsSecondsShort(
                    _locationLookupTimeoutSeconds,
                  ),
                  onTap: () => _editNumber(
                    title: l10n.locationLookupTimeoutTitle,
                    description: l10n.locationLookupTimeoutSubtitle,
                    currentValue: _locationLookupTimeoutSeconds,
                    min: 2,
                    max: 30,
                    divisions: 28,
                    valueLabel: l10n.settingsSecondsShort,
                    onSelected: (value) {
                      setState(() => _locationLookupTimeoutSeconds = value);
                      widget.onLocationLookupTimeoutSecondsChanged(value);
                    },
                  ),
                ),
                _CompactSettingTile(
                  key: const ValueKey('location-concurrency-setting'),
                  icon: Icons.hub_rounded,
                  color: cs.tertiary,
                  title: l10n.locationLookupConcurrencyTitle,
                  value: '$_locationLookupConcurrency',
                  onTap: () => _editNumber(
                    title: l10n.locationLookupConcurrencyTitle,
                    description: l10n.locationLookupConcurrencySubtitle,
                    currentValue: _locationLookupConcurrency,
                    min: 1,
                    max: 60,
                    divisions: 59,
                    valueLabel: (value) => '$value',
                    onSelected: (value) {
                      setState(() => _locationLookupConcurrency = value);
                      widget.onLocationLookupConcurrencyChanged(value);
                    },
                  ),
                ),
              ],
            ),
            const Gap(settingsSectionGap),
            const _SettingsSectionLabel(label: 'Happ'),
            const Gap(settingsSectionLabelGap),
            SettingsTileGroup(
              dividerIndent: 64,
              children: [
                _CompactSettingTile(
                  key: const ValueKey('happ-crypt5-status'),
                  icon: Icons.key_rounded,
                  color: cs.secondary,
                  title: 'Crypt5',
                  value: happStatusText,
                  valueColor: happStatusColor,
                  subtitle: !_loadingHappSupport && !_happCrypt5Supported
                      ? l10n.happCrypt5UnsupportedDescription
                      : null,
                ),
                _CompactSettingTile(
                  key: const ValueKey('device-hwid-value'),
                  icon: Icons.fingerprint_rounded,
                  color: cs.secondary,
                  title: l10n.hwidValueTitle,
                  value: _loadingAndroidId
                      ? l10n.loading
                      : (_androidId.isEmpty ? '—' : _androidId),
                  monospaceValue: !_loadingAndroidId && _androidId.isNotEmpty,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CompactSettingTile extends StatelessWidget {
  const _CompactSettingTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.subtitle,
    this.valueColor,
    this.monospaceValue = false,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String? subtitle;
  final Color? valueColor;
  final bool monospaceValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final trailing = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .44,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Tooltip(
              message: value,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: valueColor ?? cs.onSurfaceVariant,
                  fontFamily: monospaceValue ? 'monospace' : null,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          if (onTap != null) ...[
            const Gap(6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      value: value,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.fromLTRB(
          16,
          subtitle == null ? 4 : 8,
          16,
          subtitle == null ? 4 : 8,
        ),
        leading: SettingsLeadingIcon(
          icon: icon,
          color: color,
          size: 36,
          iconSize: 18,
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _SliderSettingSheet extends StatefulWidget {
  const _SliderSettingSheet({
    required this.title,
    required this.description,
    required this.initialValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.saveLabel,
  });

  final String title;
  final String description;
  final int initialValue;
  final int min;
  final int max;
  final int divisions;
  final String Function(int value) valueLabel;
  final String saveLabel;

  @override
  State<_SliderSettingSheet> createState() => _SliderSettingSheetState();
}

class _SliderSettingSheetState extends State<_SliderSettingSheet> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.clamp(widget.min, widget.max).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final roundedValue = _value.round();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Gap(6),
            Text(
              widget.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const Gap(18),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.valueLabel(roundedValue),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const Gap(8),
            Slider(
              key: const ValueKey('compact-setting-slider'),
              value: _value,
              min: widget.min.toDouble(),
              max: widget.max.toDouble(),
              divisions: widget.divisions,
              label: widget.valueLabel(roundedValue),
              onChanged: (value) => setState(() => _value = value),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    widget.valueLabel(widget.min),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.valueLabel(widget.max),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(roundedValue),
                child: Text(widget.saveLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrlTestEditorSheet extends StatefulWidget {
  const _UrlTestEditorSheet({
    required this.initialValue,
    required this.title,
    required this.description,
    required this.saveLabel,
  });

  final String initialValue;
  final String title;
  final String description;
  final String saveLabel;

  @override
  State<_UrlTestEditorSheet> createState() => _UrlTestEditorSheetState();
}

class _UrlTestEditorSheetState extends State<_UrlTestEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Gap(6),
              Text(
                widget.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Gap(16),
              TextField(
                key: const ValueKey('urltest-url-field'),
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                ],
                decoration: InputDecoration(
                  labelText: widget.title,
                  hintText: defaultUrlTestUrl,
                ),
                onSubmitted: (_) => _save(),
              ),
              const Gap(16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(widget.saveLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    Navigator.of(context).pop(_controller.text.trim());
  }
}
