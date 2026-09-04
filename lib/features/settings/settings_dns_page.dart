import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

final _kDnsSingleLineFormatter = FilteringTextInputFormatter.deny(
  RegExp(r'[\r\n]'),
);

String dnsResolverFieldText(String value) {
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

String dnsResolverProtocolLabel(String value) {
  final normalized = normalizeDnsResolverInput(value).toLowerCase();
  if (normalized.startsWith('tcp://')) return 'TCP';
  if (normalized.startsWith('tls://')) return 'TLS';
  if (normalized.startsWith('https://')) return 'HTTPS';
  if (normalized.startsWith('device://')) return 'Android';
  return 'UDP';
}

class SettingsDnsPage extends ConsumerStatefulWidget {
  const SettingsDnsPage({super.key});

  @override
  ConsumerState<SettingsDnsPage> createState() => _SettingsDnsPageState();
}

class _DnsPreset {
  const _DnsPreset({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final String value;
}

String _dnsPresetLabel(AppLocalizations l10n, _DnsPreset preset) {
  return switch (preset.id) {
    'device' => l10n.dnsPresetDevice,
    'custom' => l10n.dnsPresetCustom,
    _ => preset.label,
  };
}

String _dnsPresetSubtitle(AppLocalizations l10n, _DnsPreset preset) {
  if (preset.id == 'device') {
    return l10n.dnsPresetDeviceSubtitle;
  }
  if (preset.id == 'custom') {
    return l10n.dnsPresetCustomSubtitle;
  }
  final value = preset.value;
  if (value.startsWith('udp://')) {
    return l10n.dnsPresetUdpSubtitle;
  }
  if (value.startsWith('tcp://')) {
    return l10n.dnsPresetTcpSubtitle;
  }
  if (value.startsWith('tls://')) {
    return l10n.dnsPresetTlsSubtitle;
  }
  if (value.startsWith('https://')) {
    return l10n.dnsPresetHttpsSubtitle;
  }
  return value;
}

class _SettingsDnsPageState extends ConsumerState<SettingsDnsPage> {
  late final TextEditingController _directController;
  late final TextEditingController _proxyController;
  late final FocusNode _directFocusNode;
  late final FocusNode _proxyFocusNode;
  late final AppSettingsCommands _commands;

  static const _directPresets = <_DnsPreset>[
    _DnsPreset(
      id: 'device',
      label: 'Device network',
      value: 'device://network',
    ),
    _DnsPreset(
      id: 'cloudflare',
      label: 'Cloudflare 1.1.1.1',
      value: 'udp://1.1.1.1',
    ),
    _DnsPreset(
      id: 'cloudflare_dot',
      label: 'Cloudflare DoT',
      value: defaultSecureDnsDirectResolver,
    ),
    _DnsPreset(
      id: 'cloudflare_doh',
      label: 'Cloudflare DoH',
      value: 'https://dns.cloudflare.com/dns-query',
    ),
    _DnsPreset(id: 'custom', label: 'Custom', value: ''),
  ];

  static const _proxyPresets = <_DnsPreset>[
    _DnsPreset(
      id: 'device',
      label: 'Device network',
      value: 'device://network',
    ),
    _DnsPreset(
      id: 'cloudflare',
      label: 'Cloudflare 1.1.1.1',
      value: 'udp://1.1.1.1',
    ),
    _DnsPreset(
      id: 'cloudflare_dot',
      label: 'Cloudflare DoT',
      value: defaultSecureDnsDirectResolver,
    ),
    _DnsPreset(
      id: 'cloudflare_doh',
      label: 'Cloudflare DoH',
      value: 'https://dns.cloudflare.com/dns-query',
    ),
    _DnsPreset(id: 'custom', label: 'Custom', value: ''),
  ];

  @override
  void initState() {
    super.initState();
    _commands = ref.read(appSettingsCommandsProvider);
    final settings = ref.read(appSettingsProvider).controller;
    _directController = TextEditingController(
      text: dnsResolverFieldText(settings.dnsDirectResolver),
    );
    _proxyController = TextEditingController(
      text: dnsResolverFieldText(settings.dnsProxyResolver),
    );
    _directFocusNode = FocusNode(debugLabel: 'dnsDirectResolver')
      ..addListener(_handleDirectFocusChanged);
    _proxyFocusNode = FocusNode(debugLabel: 'dnsProxyResolver')
      ..addListener(_handleProxyFocusChanged);
  }

  void _syncResolverController(
    TextEditingController controller,
    FocusNode focusNode,
    String resolver,
  ) {
    // Traffic updates and other parent rebuilds must not overwrite a DNS draft
    // while the user is typing. The draft is committed when the field loses
    // focus or the keyboard submits it.
    if (focusNode.hasFocus) {
      return;
    }
    if (normalizeDnsResolverInput(controller.text) ==
        normalizeDnsResolverInput(resolver)) {
      return;
    }
    controller.text = dnsResolverFieldText(resolver);
  }

  @override
  void dispose() {
    _directFocusNode
      ..removeListener(_handleDirectFocusChanged)
      ..dispose();
    _proxyFocusNode
      ..removeListener(_handleProxyFocusChanged)
      ..dispose();
    _directController.dispose();
    _proxyController.dispose();
    super.dispose();
  }

  _DnsPreset _presetById(List<_DnsPreset> presets, String id) {
    for (final preset in presets) {
      if (preset.id == id) {
        return preset;
      }
    }
    return presets.last;
  }

  Future<void> _showPresetPicker({
    required BuildContext context,
    required String title,
    required List<_DnsPreset> presets,
    required String current,
    required ValueChanged<_DnsPreset> onSelected,
  }) async {
    final result = await showModalBottomSheet<_DnsPreset>(
      context: context,
      showDragHandle: true,
      builder: (ctx) =>
          _DnsPresetSheet(title: title, current: current, items: presets),
    );
    if (result != null) {
      onSelected(result);
    }
  }

  void _handleDirectFocusChanged() {
    if (!_directFocusNode.hasFocus) {
      _commitDirectResolver();
    }
  }

  void _handleProxyFocusChanged() {
    if (!_proxyFocusNode.hasFocus) {
      _commitProxyResolver();
    }
  }

  void _commitDirectResolver() {
    final value = _directController.text.trim();
    final current = ref.read(appSettingsProvider).controller.dnsDirectResolver;
    if (value.isEmpty) {
      _directController.text = dnsResolverFieldText(current);
      return;
    }
    if (value != current) {
      _commands.setDnsDirectResolver(value);
    }
  }

  void _commitProxyResolver() {
    final value = _proxyController.text.trim();
    final current = ref.read(appSettingsProvider).controller.dnsProxyResolver;
    if (value.isEmpty) {
      _proxyController.text = dnsResolverFieldText(current);
      return;
    }
    if (value != current) {
      _commands.setDnsProxyResolver(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = ref.watch(appSettingsProvider).controller;
    final currentDirectPreset = settings.dnsDirectPreset;
    final currentDirectResolver = settings.dnsDirectResolver;
    final currentProxyPreset = settings.dnsProxyPreset;
    final currentProxyResolver = settings.dnsProxyResolver;
    final currentPreferIpv6 = settings.dnsPreferIpv6;
    final currentSecureOnly = settings.dnsSecureOnly;
    final currentDirectThroughProxy = settings.dnsDirectThroughProxy;

    ref.listen(
      appSettingsProvider.select((s) => s.controller.dnsDirectResolver),
      (_, next) {
        _syncResolverController(_directController, _directFocusNode, next);
      },
    );
    ref.listen(
      appSettingsProvider.select((s) => s.controller.dnsProxyResolver),
      (_, next) {
        _syncResolverController(_proxyController, _proxyFocusNode, next);
      },
    );

    final directPreset = _presetById(_directPresets, currentDirectPreset);
    final proxyPreset = _presetById(_proxyPresets, currentProxyPreset);
    final directIsCustom = directPreset.id == 'custom';
    final proxyIsCustom = proxyPreset.id == 'custom';
    final directPresets = _availablePresets(
      _directPresets,
      secureOnly: currentSecureOnly,
    );
    final proxyPresets = _availablePresets(
      _proxyPresets,
      secureOnly: currentSecureOnly,
    );

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.dnsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          settingsScreenPadding.left,
          progressiveHeaderTopPadding(context, settingsScreenPadding.top),
          settingsScreenPadding.right,
          appBottomSafePadding(context, settingsScreenPadding.bottom),
        ),
        children: [
          _SectionLabel(label: l10n.dnsDirectTitle),
          const Gap(settingsSectionLabelGap),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DnsSelectorTile(
                    icon: Icons.bolt_rounded,
                    iconColor: cs.primary,
                    title: l10n.dnsResolverTitle,
                    subtitle:
                        '${_dnsPresetLabel(l10n, directPreset)} • '
                        '${dnsResolverProtocolLabel(currentDirectResolver)}',
                    onTap: () => _showPresetPicker(
                      context: context,
                      title: l10n.dnsDirectTitle,
                      presets: directPresets,
                      current: currentDirectPreset,
                      onSelected: (preset) {
                        _commands.setDnsDirectPreset(preset.id);
                        if (preset.id != 'custom') {
                          _commands.setDnsDirectResolver(preset.value);
                          _directController.text = dnsResolverFieldText(
                            preset.value,
                          );
                        }
                      },
                    ),
                  ),
                  if (directIsCustom) const Gap(12),
                  if (directIsCustom)
                    TextField(
                      controller: _directController,
                      focusNode: _directFocusNode,
                      textInputAction: TextInputAction.done,
                      onTapOutside: (_) => _directFocusNode.unfocus(),
                      onSubmitted: (_) => _directFocusNode.unfocus(),
                      inputFormatters: [_kDnsSingleLineFormatter],
                      decoration: InputDecoration(
                        labelText: l10n.dnsResolverTitle,
                        helperText: l10n.dnsDirectResolverSubtitle,
                        hintText: '1.1.1.1',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Gap(settingsSectionGap),
          _SectionLabel(label: l10n.dnsProxyTitle),
          const Gap(settingsSectionLabelGap),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DnsSelectorTile(
                    icon: Icons.shield_rounded,
                    iconColor: cs.primary,
                    title: l10n.dnsResolverTitle,
                    subtitle:
                        '${_dnsPresetLabel(l10n, proxyPreset)} • '
                        '${dnsResolverProtocolLabel(currentProxyResolver)}',
                    onTap: () => _showPresetPicker(
                      context: context,
                      title: l10n.dnsProxyTitle,
                      presets: proxyPresets,
                      current: currentProxyPreset,
                      onSelected: (preset) {
                        _commands.setDnsProxyPreset(preset.id);
                        if (preset.id != 'custom') {
                          _commands.setDnsProxyResolver(preset.value);
                          _proxyController.text = dnsResolverFieldText(
                            preset.value,
                          );
                        }
                      },
                    ),
                  ),
                  if (proxyIsCustom) const Gap(12),
                  if (proxyIsCustom)
                    TextField(
                      controller: _proxyController,
                      focusNode: _proxyFocusNode,
                      textInputAction: TextInputAction.done,
                      onTapOutside: (_) => _proxyFocusNode.unfocus(),
                      onSubmitted: (_) => _proxyFocusNode.unfocus(),
                      inputFormatters: [_kDnsSingleLineFormatter],
                      decoration: InputDecoration(
                        labelText: l10n.dnsResolverTitle,
                        helperText: l10n.dnsProxyResolverSubtitle,
                        hintText: 'https://dns.cloudflare.com/dns-query',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Gap(settingsSectionGap),
          _SectionLabel(label: l10n.dnsProtectionTitle),
          const Gap(settingsSectionLabelGap),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  secondary: SettingsLeadingIcon(
                    icon: Icons.enhanced_encryption_rounded,
                    color: cs.primary,
                  ),
                  title: Text(l10n.dnsSecureOnlyTitle),
                  subtitle: Text(l10n.dnsSecureOnlySubtitle),
                  value: currentSecureOnly,
                  onChanged: _commands.setDnsSecureOnly,
                ),
                const Divider(height: 1, indent: 72),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  secondary: SettingsLeadingIcon(
                    icon: Icons.route_rounded,
                    color: cs.primary,
                  ),
                  title: Text(l10n.dnsDirectThroughProxyTitle),
                  subtitle: Text(l10n.dnsDirectThroughProxySubtitle),
                  value: currentDirectThroughProxy,
                  onChanged: _commands.setDnsDirectThroughProxy,
                ),
              ],
            ),
          ),
          const Gap(settingsSectionGap),
          _SectionLabel(label: l10n.dnsIpPreferenceTitle),
          const Gap(settingsSectionLabelGap),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              secondary: SettingsLeadingIcon(
                icon: Icons.swap_horiz_rounded,
                color: cs.primary,
              ),
              title: Text(l10n.dnsPreferIpv6Title),
              subtitle: Text(l10n.dnsPreferIpv6Subtitle),
              value: currentPreferIpv6,
              onChanged: _commands.setDnsPreferIpv6,
            ),
          ),
        ],
      ),
    );
  }

  List<_DnsPreset> _availablePresets(
    List<_DnsPreset> presets, {
    required bool secureOnly,
  }) {
    if (!secureOnly) {
      return presets;
    }
    return presets
        .where(
          (preset) =>
              preset.id == 'custom' || isEncryptedDnsResolver(preset.value),
        )
        .toList(growable: false);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

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
        ),
      ),
    );
  }
}

class _DnsSelectorTile extends StatefulWidget {
  const _DnsSelectorTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_DnsSelectorTile> createState() => _DnsSelectorTileState();
}

class _DnsSelectorTileState extends State<_DnsSelectorTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        onHighlightChanged: (value) {
          if (_pressed == value) {
            return;
          }
          setState(() => _pressed = value);
        },
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: _pressed
                ? cs.onSurface.withValues(alpha: .06)
                : Colors.transparent,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 20),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize:
                            (theme.textTheme.titleSmall?.fontSize ?? 14) - 1,
                      ),
                    ),
                    const Gap(1),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize:
                            (theme.textTheme.bodyMedium?.fontSize ?? 14) - 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DnsPresetSheet extends StatelessWidget {
  const _DnsPresetSheet({
    required this.title,
    required this.current,
    required this.items,
  });

  final String title;
  final String current;
  final List<_DnsPreset> items;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const Gap(12),
              Flexible(
                child: RadioGroup<String>(
                  groupValue: current,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    for (final item in items) {
                      if (item.id == value) {
                        Navigator.of(context).pop(item);
                        break;
                      }
                    }
                  },
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in items)
                        RadioListTile<String>(
                          value: item.id,
                          title: Text(_dnsPresetLabel(l10n, item)),
                          subtitle: Text(
                            item.value.isEmpty
                                ? _dnsPresetSubtitle(l10n, item)
                                : '${_dnsPresetSubtitle(l10n, item)}\n${item.value}',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
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
