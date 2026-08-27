import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/core/security/sensitive_clipboard.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsInboundPage extends StatefulWidget {
  const SettingsInboundPage({
    super.key,
    required this.currentVpnInboundEnabled,
    required this.currentVpnMtu,
    required this.currentVpnStrictRoute,
    required this.currentVpnTunImplementation,
    required this.currentProxyInboundEnabled,
    required this.currentProxyAllowLan,
    required this.currentProxyMixedListen,
    required this.currentProxyMixedPort,
    required this.currentProxyUsername,
    required this.currentProxyPassword,
    required this.onConnectionModeChanged,
    required this.onVpnMtuChanged,
    required this.onVpnStrictRouteChanged,
    required this.onVpnTunImplementationChanged,
    required this.onProxyInboundEnabledChanged,
    required this.onProxyAllowLanChanged,
    required this.onProxyMixedPortChanged,
    required this.onProxyUsernameChanged,
    required this.onProxyPasswordChanged,
  });

  final bool currentVpnInboundEnabled;
  final int currentVpnMtu;
  final bool currentVpnStrictRoute;
  final TunImplementationPreference currentVpnTunImplementation;
  final bool currentProxyInboundEnabled;
  final bool currentProxyAllowLan;
  final String currentProxyMixedListen;
  final int currentProxyMixedPort;
  final String currentProxyUsername;
  final String currentProxyPassword;
  final ValueChanged<InboundConnectionMode> onConnectionModeChanged;
  final ValueChanged<int> onVpnMtuChanged;
  final ValueChanged<bool> onVpnStrictRouteChanged;
  final ValueChanged<TunImplementationPreference> onVpnTunImplementationChanged;
  final ValueChanged<bool> onProxyInboundEnabledChanged;
  final ValueChanged<bool> onProxyAllowLanChanged;
  final ValueChanged<int> onProxyMixedPortChanged;
  final ValueChanged<String> onProxyUsernameChanged;
  final ValueChanged<String> onProxyPasswordChanged;

  @override
  State<SettingsInboundPage> createState() => _SettingsInboundPageState();
}

class _SettingsInboundPageState extends State<SettingsInboundPage> {
  static const _minimumMtu = 1280;
  static const _maximumMtu = 9000;
  late final TextEditingController _portController;
  late InboundConnectionMode _connectionMode;
  late int _vpnMtu;
  late bool _proxyEnabled;
  late bool _proxyAllowLan;
  late String _proxyUsername;
  late String _proxyPassword;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(
      text: widget.currentProxyMixedPort.toString(),
    );
    _connectionMode = widget.currentVpnInboundEnabled
        ? InboundConnectionMode.vpn
        : InboundConnectionMode.proxy;
    _vpnMtu = widget.currentVpnMtu;
    _proxyEnabled = widget.currentProxyInboundEnabled;
    _proxyAllowLan = widget.currentProxyAllowLan;
    _proxyUsername = normalizeProxyUsername(widget.currentProxyUsername);
    _proxyPassword = widget.currentProxyPassword;
    if (!isValidProxyPassword(_proxyPassword)) {
      _proxyPassword = generateProxyPassword();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onProxyPasswordChanged(_proxyPassword);
      });
    }
  }

  @override
  void didUpdateWidget(covariant SettingsInboundPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _connectionMode = widget.currentVpnInboundEnabled
        ? InboundConnectionMode.vpn
        : InboundConnectionMode.proxy;
    if (widget.currentVpnMtu != oldWidget.currentVpnMtu) {
      _vpnMtu = widget.currentVpnMtu;
    }
    _proxyEnabled = widget.currentProxyInboundEnabled;
    _proxyAllowLan = widget.currentProxyAllowLan;
    if (widget.currentProxyUsername != oldWidget.currentProxyUsername &&
        isValidProxyUsername(widget.currentProxyUsername)) {
      _proxyUsername = widget.currentProxyUsername.trim();
    }
    if (widget.currentProxyPassword != oldWidget.currentProxyPassword &&
        isValidProxyPassword(widget.currentProxyPassword)) {
      _proxyPassword = widget.currentProxyPassword;
    }
    if (widget.currentProxyMixedPort != oldWidget.currentProxyMixedPort &&
        !_portController.selection.isValid) {
      _portController.text = widget.currentProxyMixedPort.toString();
    }
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  String _tunImplementationLabel(
    AppLocalizations l10n,
    TunImplementationPreference value,
  ) {
    return switch (value) {
      TunImplementationPreference.mixed => l10n.tunImplementationMixed,
      TunImplementationPreference.system => l10n.tunImplementationSystem,
      TunImplementationPreference.gvisor => l10n.tunImplementationGvisor,
    };
  }

  String _tunImplementationDescription(
    AppLocalizations l10n,
    TunImplementationPreference value,
  ) {
    return switch (value) {
      TunImplementationPreference.mixed => l10n.tunImplementationMixedSubtitle,
      TunImplementationPreference.system =>
        l10n.tunImplementationSystemSubtitle,
      TunImplementationPreference.gvisor =>
        l10n.tunImplementationGvisorSubtitle,
    };
  }

  bool _isValidMtu(String value) {
    final mtu = int.tryParse(value.trim());
    return mtu != null && mtu >= _minimumMtu && mtu <= _maximumMtu;
  }

  Future<void> _showMtuEditor(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    var draft = _vpnMtu.toString();
    var showError = false;
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void submit() {
            if (!_isValidMtu(draft)) {
              setDialogState(() => showError = true);
              return;
            }
            Navigator.of(dialogContext).pop(int.parse(draft.trim()));
          }

          return AlertDialog(
            title: Text(l10n.mtuTitle),
            content: TextFormField(
              key: const ValueKey('vpn-mtu-input'),
              initialValue: draft,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.mtuTitle,
                helperText: l10n.mtuInputRange,
                errorText: showError ? l10n.mtuInvalidValue : null,
              ),
              onChanged: (value) {
                draft = value;
                if (showError) {
                  setDialogState(() => showError = false);
                }
              },
              onFieldSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(onPressed: submit, child: Text(l10n.saveAction)),
            ],
          );
        },
      ),
    );
    if (!mounted || result == null || result == _vpnMtu) {
      return;
    }
    setState(() => _vpnMtu = result);
    widget.onVpnMtuChanged(result);
  }

  Future<void> _showTunImplementationPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await showModalBottomSheet<TunImplementationPreference>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _RadioSheet<TunImplementationPreference>(
        title: l10n.tunImplementationTitle,
        current: widget.currentVpnTunImplementation,
        items: [
          _RadioItem(
            value: TunImplementationPreference.mixed,
            label: l10n.tunImplementationMixed,
            subtitle: l10n.tunImplementationMixedSubtitle,
          ),
          _RadioItem(
            value: TunImplementationPreference.system,
            label: l10n.tunImplementationSystem,
            subtitle: l10n.tunImplementationSystemSubtitle,
          ),
          _RadioItem(
            value: TunImplementationPreference.gvisor,
            label: l10n.tunImplementationGvisor,
            subtitle: l10n.tunImplementationGvisorSubtitle,
          ),
        ],
      ),
    );
    if (result != null) {
      widget.onVpnTunImplementationChanged(result);
    }
  }

  void _commitPort() {
    final value = int.tryParse(_portController.text.trim());
    if (value == null || value <= 0 || value > 65535) {
      _portController.text = widget.currentProxyMixedPort.toString();
      return;
    }
    if (value == widget.currentProxyMixedPort) {
      return;
    }
    widget.onProxyMixedPortChanged(value);
  }

  void _setConnectionMode(InboundConnectionMode mode) {
    if (_connectionMode == mode) return;
    if (mode == InboundConnectionMode.proxy &&
        !isValidProxyUsername(_proxyUsername)) {
      _proxyUsername = defaultProxyUsername;
      widget.onProxyUsernameChanged(_proxyUsername);
    }
    if (mode == InboundConnectionMode.proxy &&
        !isValidProxyPassword(_proxyPassword)) {
      _proxyPassword = generateProxyPassword();
      widget.onProxyPasswordChanged(_proxyPassword);
    }
    setState(() {
      _connectionMode = mode;
      _proxyEnabled = mode == InboundConnectionMode.proxy;
    });
    widget.onConnectionModeChanged(mode);
  }

  void _setProxyEnabled(bool value) {
    if (value && !isValidProxyUsername(_proxyUsername)) {
      _proxyUsername = defaultProxyUsername;
      widget.onProxyUsernameChanged(_proxyUsername);
    }
    if (value && !isValidProxyPassword(_proxyPassword)) {
      _proxyPassword = generateProxyPassword();
      widget.onProxyPasswordChanged(_proxyPassword);
    }
    setState(() => _proxyEnabled = value);
    widget.onProxyInboundEnabledChanged(value);
  }

  void _setProxyAllowLan(bool value) {
    if (value && !isValidProxyUsername(_proxyUsername)) {
      _proxyUsername = defaultProxyUsername;
      widget.onProxyUsernameChanged(_proxyUsername);
    }
    if (value && !isValidProxyPassword(_proxyPassword)) {
      _proxyPassword = generateProxyPassword();
      widget.onProxyPasswordChanged(_proxyPassword);
    }
    setState(() => _proxyAllowLan = value);
    widget.onProxyAllowLanChanged(value);
  }

  void _regenerateProxyPassword() {
    final password = generateProxyPassword();
    setState(() {
      _proxyPassword = password;
      _passwordVisible = true;
    });
    widget.onProxyPasswordChanged(password);
  }

  Future<void> _editProxyUsername(AppLocalizations l10n) async {
    var draft = _proxyUsername;
    var valid = isValidProxyUsername(draft);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.proxyUsernameTitle),
          content: TextFormField(
            initialValue: draft,
            autofocus: true,
            maxLength: proxyUsernameMaxLength,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[\s:]')),
              LengthLimitingTextInputFormatter(proxyUsernameMaxLength),
            ],
            decoration: InputDecoration(
              labelText: l10n.proxyUsernameTitle,
              helperText: l10n.proxyUsernameSubtitle,
              errorText: valid ? null : l10n.proxyUsernameSubtitle,
            ),
            onChanged: (value) {
              draft = value;
              final nextValid = isValidProxyUsername(value);
              if (nextValid != valid) {
                setDialogState(() => valid = nextValid);
              }
            },
            onFieldSubmitted: (value) {
              if (isValidProxyUsername(value)) {
                Navigator.of(dialogContext).pop(value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: valid
                  ? () => Navigator.of(dialogContext).pop(draft.trim())
                  : null,
              child: Text(l10n.saveAction),
            ),
          ],
        ),
      ),
    );
    if (!mounted ||
        result == null ||
        !isValidProxyUsername(result) ||
        result == _proxyUsername) {
      return;
    }
    setState(() => _proxyUsername = result);
    widget.onProxyUsernameChanged(result);
  }

  Future<void> _copyProxyCredentials(AppLocalizations l10n) async {
    final host = _proxyAllowLan ? l10n.proxyLanAddressHint : '127.0.0.1';
    final buffer = StringBuffer(
      'HTTP/SOCKS: $host:${widget.currentProxyMixedPort}',
    );
    buffer
      ..writeln()
      ..writeln('${l10n.proxyUsernameTitle}: $_proxyUsername')
      ..write('${l10n.proxyPasswordTitle}: $_proxyPassword');
    await SensitiveClipboard.copy(buffer.toString());
    if (!mounted) return;
    AppNotice.show(
      context,
      l10n.proxyCredentialsCopied,
      tone: AppNoticeTone.success,
    );
  }

  Future<void> _copyProxyValue(String value, AppLocalizations l10n) async {
    await SensitiveClipboard.copy(value);
    if (!mounted) return;
    AppNotice.show(
      context,
      l10n.proxyCredentialsCopied,
      tone: AppNoticeTone.success,
    );
  }

  Widget _buildAdvancedTunCard(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colors,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: SettingsLeadingIcon(
          icon: Icons.tune_rounded,
          color: colors.primary,
        ),
        title: Text(l10n.advancedTunTitle),
        subtitle: Text(l10n.advancedTunSubtitle),
        children: [
          ListTile(
            key: const ValueKey('vpn-mtu-setting'),
            leading: SettingsLeadingIcon(
              icon: Icons.swap_vert_rounded,
              color: colors.primary,
            ),
            title: Text(l10n.mtuTitle),
            subtitle: Text('$_vpnMtu • ${l10n.mtuSubtitle}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showMtuEditor(context),
          ),
          SwitchListTile(
            secondary: SettingsLeadingIcon(
              icon: Icons.route_rounded,
              color: colors.primary,
            ),
            title: Text(l10n.strictRouteTitle),
            subtitle: Text(l10n.strictRouteSubtitle),
            value: widget.currentVpnStrictRoute,
            onChanged: widget.onVpnStrictRouteChanged,
          ),
          ListTile(
            leading: SettingsLeadingIcon(
              icon: Icons.memory_rounded,
              color: colors.primary,
            ),
            title: Text(l10n.tunImplementationTitle),
            subtitle: Text(
              '${_tunImplementationLabel(l10n, widget.currentVpnTunImplementation)} • ${_tunImplementationDescription(l10n, widget.currentVpnTunImplementation)}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showTunImplementationPicker(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProxyCard(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colors, {
    required bool optionalInVpn,
  }) {
    final enabled = optionalInVpn ? _proxyEnabled : true;
    final endpointHost = _proxyAllowLan
        ? l10n.proxyLanAddressHint
        : '127.0.0.1';
    final hiddenPassword = List<String>.filled(
      _proxyPassword.length,
      '•',
      growable: false,
    ).join();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (optionalInVpn)
            SwitchListTile(
              secondary: SettingsLeadingIcon(
                icon: Icons.lan_rounded,
                color: colors.primary,
              ),
              title: Text(l10n.localProxyTitle),
              subtitle: Text(l10n.localProxySubtitle),
              value: _proxyEnabled,
              onChanged: _setProxyEnabled,
            )
          else
            ListTile(
              leading: SettingsLeadingIcon(
                icon: Icons.lan_rounded,
                color: colors.primary,
              ),
              title: Text(l10n.localProxyTitle),
              subtitle: Text(l10n.localProxySettingsSubtitle),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: enabled
                ? Column(
                    key: const ValueKey('proxy-controls'),
                    children: [
                      SwitchListTile(
                        secondary: SettingsLeadingIcon(
                          icon: Icons.wifi_tethering_rounded,
                          color: colors.primary,
                        ),
                        title: Text(l10n.allowLanConnectionsTitle),
                        subtitle: Text(l10n.allowLanConnectionsSubtitle),
                        value: _proxyAllowLan,
                        onChanged: _setProxyAllowLan,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: TextField(
                          controller: _portController,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                            _commitPort();
                          },
                          onSubmitted: (_) => _commitPort(),
                          onEditingComplete: () {
                            FocusScope.of(context).unfocus();
                            _commitPort();
                          },
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.portTitle,
                            hintText: '1080',
                            helperText: l10n.proxyPortSubtitle,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: SettingsLeadingIcon(
                          icon: Icons.link_rounded,
                          color: colors.primary,
                        ),
                        title: Text(l10n.proxyEndpointTitle),
                        subtitle: Text(
                          '$endpointHost:${widget.currentProxyMixedPort}',
                        ),
                        trailing: IconButton(
                          tooltip: l10n.copyProxyCredentialsTitle,
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () => _copyProxyCredentials(l10n),
                        ),
                      ),
                      ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.shield_rounded,
                                    color: colors.onSecondaryContainer,
                                  ),
                                  const Gap(12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.lanProxySecurityTitle,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                        const Gap(4),
                                        Text(
                                          l10n.lanProxySecuritySubtitle,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ListTile(
                          title: Text(l10n.proxyUsernameTitle),
                          subtitle: Text(_proxyUsername),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.copyProxyCredentialsTitle,
                                icon: const Icon(Icons.copy_rounded),
                                onPressed: () =>
                                    _copyProxyValue(_proxyUsername, l10n),
                              ),
                              const Icon(Icons.edit_rounded),
                            ],
                          ),
                          onTap: () => _editProxyUsername(l10n),
                        ),
                        ListTile(
                          title: Text(l10n.proxyPasswordTitle),
                          subtitle: Text(
                            _passwordVisible ? _proxyPassword : hiddenPassword,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                                onPressed: () => setState(
                                  () => _passwordVisible = !_passwordVisible,
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.copyProxyCredentialsTitle,
                                icon: const Icon(Icons.copy_rounded),
                                onPressed: () =>
                                    _copyProxyValue(_proxyPassword, l10n),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _regenerateProxyPassword,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(
                                    l10n.regenerateProxyPasswordTitle,
                                  ),
                                ),
                              ),
                              const Gap(8),
                              IconButton.filledTonal(
                                tooltip: l10n.copyProxyCredentialsTitle,
                                onPressed: () => _copyProxyCredentials(l10n),
                                icon: const Icon(Icons.copy_all_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('proxy-disabled')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.inboundTitle)),
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
            _SectionLabel(label: l10n.connectionModeTitle),
            const Gap(settingsSectionLabelGap),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<InboundConnectionMode>(
                      segments: [
                        ButtonSegment(
                          value: InboundConnectionMode.vpn,
                          icon: const Icon(Icons.vpn_lock_rounded),
                          label: Text(l10n.connectionModeVpn),
                        ),
                        ButtonSegment(
                          value: InboundConnectionMode.proxy,
                          icon: const Icon(Icons.lan_rounded),
                          label: Text(l10n.connectionModeProxy),
                        ),
                      ],
                      selected: {_connectionMode},
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty) {
                          _setConnectionMode(selection.first);
                        }
                      },
                    ),
                    const Gap(12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        _connectionMode == InboundConnectionMode.vpn
                            ? l10n.connectionModeVpnSubtitle
                            : l10n.connectionModeProxySubtitle,
                        key: ValueKey(_connectionMode),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(settingsSectionGap),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _connectionMode == InboundConnectionMode.vpn
                  ? Column(
                      key: const ValueKey('vpn-mode-settings'),
                      children: [
                        _buildAdvancedTunCard(context, l10n, colors),
                        const Gap(settingsSectionGap),
                        _buildProxyCard(
                          context,
                          l10n,
                          colors,
                          optionalInVpn: true,
                        ),
                      ],
                    )
                  : _buildProxyCard(
                      context,
                      l10n,
                      colors,
                      optionalInVpn: false,
                    ),
            ),
          ],
        ),
      ),
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
    final mediaQuery = MediaQuery.of(context);
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
                child: RadioGroup<T>(
                  groupValue: current,
                  onChanged: (value) {
                    if (value != null) {
                      Navigator.of(context).pop(value);
                    }
                  },
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in items)
                        RadioListTile<T>(
                          value: item.value,
                          title: Text(item.label),
                          subtitle: item.subtitle == null
                              ? null
                              : Text(item.subtitle!),
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
